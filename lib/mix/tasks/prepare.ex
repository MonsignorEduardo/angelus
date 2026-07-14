defmodule Mix.Tasks.Angelus.Prepare do
  @moduledoc "Downloads and validates Angelus runtime kernels."

  use Mix.Task

  alias Angelus.Astro.Catalog
  alias Angelus.Motor.KernelSet

  @download_step_bytes 1_000_000

  @doc "Downloads and validates the kernels required by `Angelus.get_ephemeride/1`."
  @impl true
  @spec run([String.t()]) :: :ok | no_return()
  def run(args) do
    Logger.configure(level: :warning)

    {opts, rest, invalid} = OptionParser.parse(args, strict: [force: :boolean])

    if rest != [] or invalid != [] do
      Mix.raise("unsupported options. Usage: mix angelus.prepare [--force]")
    end

    force? = Keyword.get(opts, :force, false)
    base_path = Path.join([File.cwd!(), "priv", "kernels"])

    {:ok, _apps} = Application.ensure_all_started(:req)
    {:ok, _apps} = Application.ensure_all_started(:owl)

    Owl.IO.puts(Owl.Data.tag("Angelus kernel downloader", :cyan))

    Owl.IO.puts(
      "JPL/NAIF kernels are downloaded from external sources subject to their own terms."
    )

    File.mkdir_p!(base_path)

    kernels = Catalog.get_kernel()
    required = Enum.map(kernels, & &1.file)
    planned = plan_downloads(base_path, kernels, force?)
    validate_existing!(base_path, planned, force?)
    planned = with_content_lengths(planned)
    print_download_plan(base_path, required, planned, force?)

    temporaries = download_all_to_temp!(base_path, planned)

    final_paths =
      required
      |> Enum.map(&Path.join(base_path, &1))

    validate_downloads!(temporaries)

    Enum.each(temporaries, fn {tmp_path, final_path} -> File.rename!(tmp_path, final_path) end)

    case KernelSet.validate(final_paths) do
      {:ok, _metadata} ->
        Owl.IO.puts([
          Owl.Data.tag("ready", :green),
          " Angelus kernels in #{base_path}"
        ])

      {:error, reason} ->
        Mix.raise("invalid kernel set: #{inspect(reason)}")
    end
  rescue
    exception ->
      cleanup_temporaries(Path.join([File.cwd!(), "priv", "kernels"]))
      reraise exception, __STACKTRACE__
  end

  defp plan_downloads(base_path, kernels, true),
    do: Enum.map(kernels, &download_item(base_path, &1))

  defp plan_downloads(base_path, kernels, false) do
    kernels
    |> Enum.map(&download_item(base_path, &1))
    |> Enum.reject(fn %{path: path} -> File.exists?(path) end)
  end

  defp download_item(base_path, kernel),
    do: %{file: kernel.file, source: kernel.source, path: Path.join(base_path, kernel.file)}

  defp validate_existing!(base_path, planned, force?) do
    planned_files = MapSet.new(Enum.map(planned, fn %{file: file} -> file end))

    Catalog.get_kernel()
    |> Enum.map(& &1.file)
    |> Enum.reject(&MapSet.member?(planned_files, &1))
    |> Enum.each(fn file -> validate_file!(Path.join(base_path, file), force?) end)
  end

  defp download_to_temp!(base_path, %{file: file, source: source, path: final_path}, progress_pid) do
    case source do
      %{kind: :url, url: url, sha256: sha256} ->
        download_to_temp!(base_path, file, final_path, url, sha256, progress_pid)

      %{kind: :url, url: url} ->
        download_to_temp!(base_path, file, final_path, url, progress_pid)
    end
  end

  defp download_to_temp!(base_path, file, final_path, url, progress_pid) do
    tmp_path = Path.join(base_path, ".#{file}.tmp")
    File.rm(tmp_path)

    response = stream_download!(url, tmp_path, progress_pid)

    unless response.status in 200..299 do
      File.rm(tmp_path)
      Mix.raise("failed to download #{file}: HTTP #{response.status}")
    end

    validate_file!(tmp_path, true)
    send(progress_pid, {:file_done, file})
    {tmp_path, final_path}
  end

  defp download_to_temp!(base_path, file, final_path, url, sha256, progress_pid) do
    {tmp_path, final_path} = download_to_temp!(base_path, file, final_path, url, progress_pid)
    validate_checksum!(tmp_path, sha256)
    {tmp_path, final_path}
  end

  defp download_all_to_temp!(_base_path, []), do: []

  defp download_all_to_temp!(base_path, planned) do
    progress_pid = start_progress(planned)

    temporaries =
      planned
      |> Task.async_stream(&download_to_temp!(base_path, &1, progress_pid),
        max_concurrency: length(planned),
        ordered: true,
        timeout: :infinity
      )
      |> Enum.map(fn
        {:ok, temporary} -> temporary
        {:exit, reason} -> Mix.raise("failed to download kernels: #{inspect(reason)}")
      end)

    send(progress_pid, :done)
    await_progress(progress_pid)
    temporaries
  end

  defp await_progress(progress_pid) do
    ref = Process.monitor(progress_pid)

    receive do
      {:DOWN, ^ref, :process, ^progress_pid, _reason} -> :ok
    end
  end

  defp stream_download!(url, tmp_path, progress_pid) do
    File.open!(tmp_path, [:write, :binary], fn io_device ->
      Req.get!(
        url: url,
        into: fn {:data, data}, {req, resp} ->
          IO.binwrite(io_device, data)
          send(progress_pid, {:bytes, byte_size(data)})
          {:cont, {req, resp}}
        end
      )
    end)
  end

  defp start_progress(planned) do
    files_total = length(planned)
    bytes_total = planned |> Enum.map(& &1.bytes) |> Enum.sum()
    units_total = planned |> Enum.map(& &1.units) |> Enum.sum()

    Owl.ProgressBar.start(
      id: :angelus_kernels,
      label: "Downloading kernels",
      total: max(units_total, files_total),
      timer: true,
      absolute_values: true,
      filled_symbol: Owl.Data.tag("=", :green),
      empty_symbol: Owl.Data.tag("-", :light_black)
    )

    parent = self()

    spawn_link(fn ->
      Process.flag(:trap_exit, true)

      render_progress(%{
        parent: parent,
        files_done: 0,
        files_total: files_total,
        bytes_done: 0,
        bytes_total: bytes_total,
        units_done: 0,
        units_total: units_total
      })
    end)
  end

  defp render_progress(state) do
    receive do
      {:bytes, bytes} ->
        state
        |> Map.update!(:bytes_done, &(&1 + bytes))
        |> sync_progress_bar()
        |> render_progress()

      {:file_done, file} ->
        state
        |> Map.update!(:files_done, &(&1 + 1))
        |> maybe_inc_file_progress()
        |> print_file_done(file)
        |> render_progress()

      :done ->
        state
        |> complete_progress()
        |> finish_progress_bar()

      {:EXIT, parent, _reason} when parent == state.parent ->
        :ok
    end
  end

  defp complete_progress(state) do
    %{
      state
      | files_done: state.files_total,
        bytes_done: max(state.bytes_done, state.bytes_total),
        units_done: max(state.units_done, state.units_total)
    }
  end

  defp sync_progress_bar(%{units_total: 0} = state), do: state

  defp sync_progress_bar(state) do
    units_done = min(div(state.bytes_done, @download_step_bytes), state.units_total)
    increment_progress_bar(units_done - state.units_done)
    %{state | units_done: units_done}
  end

  defp maybe_inc_file_progress(%{units_total: 0} = state) do
    Owl.ProgressBar.inc(id: :angelus_kernels)
    state
  end

  defp maybe_inc_file_progress(state), do: state

  defp finish_progress_bar(state) do
    if state.units_total > 0 do
      increment_progress_bar(state.units_total - state.units_done)
    end

    if live_screen_available?(), do: Owl.LiveScreen.await_render()
    state
  end

  defp increment_progress_bar(count) when count > 0 do
    Enum.each(1..count, fn _ -> Owl.ProgressBar.inc(id: :angelus_kernels) end)
  end

  defp increment_progress_bar(_count), do: :ok

  defp print_file_done(state, file) do
    print = fn ->
      Owl.IO.puts([Owl.Data.tag("downloaded", :green), " ", file])
    end

    if live_screen_available?(), do: Owl.LiveScreen.capture_stdio(print), else: print.()

    state
  end

  defp live_screen_available?, do: is_pid(Process.whereis(Owl.LiveScreen))

  defp with_content_lengths(planned) do
    Enum.map(planned, fn %{source: source} = item ->
      bytes = content_length!(source)
      Map.merge(item, %{bytes: bytes, units: progress_units(bytes)})
    end)
  end

  defp progress_units(bytes) when bytes > 0, do: max(ceil(bytes / @download_step_bytes), 1)
  defp progress_units(_bytes), do: 0

  defp print_download_plan(base_path, required, planned, force?) do
    skipped = length(required) - length(planned)
    bytes_total = planned |> Enum.map(& &1.bytes) |> Enum.sum()

    Owl.IO.puts([
      Owl.Data.tag("set", :light_black),
      " default  ",
      Owl.Data.tag("path", :light_black),
      " #{base_path}"
    ])

    Owl.IO.puts([
      Owl.Data.tag("files", :light_black),
      " #{length(planned)} to download, #{skipped} already present",
      if(force?, do: " (force enabled)", else: "")
    ])

    if planned == [] do
      Owl.IO.puts(Owl.Data.tag("All required kernels are already present.", :green))
    else
      Owl.IO.puts([Owl.Data.tag("size", :light_black), " #{format_bytes(bytes_total)} estimated"])

      Enum.each(planned, fn %{file: file, bytes: bytes} ->
        Owl.IO.puts("  #{String.pad_trailing(file, 24)} #{format_bytes(bytes)}")
      end)
    end
  end

  defp content_length!(source) do
    case source do
      %{kind: :url, url: url} ->
        response = Req.head!(url: url)

        response.headers
        |> Map.get("content-length", ["0"])
        |> List.first()
        |> Integer.parse()
        |> case do
          {bytes, ""} -> bytes
          _other -> 0
        end
    end
  end

  defp format_bytes(bytes) when bytes >= 1_000_000_000,
    do: :io_lib.format("~.1f GB", [bytes / 1_000_000_000]) |> IO.iodata_to_binary()

  defp format_bytes(bytes) when bytes >= 1_000_000,
    do: :io_lib.format("~.1f MB", [bytes / 1_000_000]) |> IO.iodata_to_binary()

  defp format_bytes(bytes) when bytes >= 1_000,
    do: :io_lib.format("~.1f KB", [bytes / 1_000]) |> IO.iodata_to_binary()

  defp format_bytes(bytes), do: "#{bytes} B"

  defp validate_downloads!(temporaries),
    do: Enum.each(temporaries, fn {tmp_path, _final_path} -> validate_file!(tmp_path, true) end)

  defp validate_checksum!(path, expected) do
    actual =
      path |> File.read!() |> then(&:crypto.hash(:sha256, &1)) |> Base.encode16(case: :lower)

    if actual != expected do
      Mix.raise(
        "checksum mismatch for #{Path.basename(path)}: expected #{expected}, got #{actual}"
      )
    end
  end

  defp validate_file!(path, _force?) do
    cond do
      not File.exists?(path) ->
        Mix.raise("kernel file is missing: #{path}")

      File.stat!(path).size == 0 ->
        Mix.raise("kernel file is empty: #{path}")

      String.ends_with?(path, ".bsp") and File.stat!(path).size < 1_000_000 ->
        Mix.raise("kernel BSP file looks incomplete: #{path}")

      true ->
        :ok
    end
  end

  defp cleanup_temporaries(base_path) do
    if File.dir?(base_path) do
      base_path
      |> Path.join(".*.tmp")
      |> Path.wildcard()
      |> Enum.each(&File.rm/1)
    end
  end

  @shortdoc "Prepares Angelus runtime kernels"
end
