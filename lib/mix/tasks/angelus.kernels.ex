defmodule Mix.Tasks.Angelus.Kernels do
  @moduledoc "Downloads the v0.1 JPL/NAIF kernel set."

  use Mix.Task

  alias Angelus.Spice.KernelSet

  @shortdoc "Downloads Angelus v0.1 kernels"

  @urls %{
    "latest_leapseconds.tls" =>
      "https://naif.jpl.nasa.gov/pub/naif/generic_kernels/lsk/latest_leapseconds.tls",
    "pck00011.tpc" => "https://naif.jpl.nasa.gov/pub/naif/generic_kernels/pck/pck00011.tpc",
    "gm_de440.tpc" => "https://naif.jpl.nasa.gov/pub/naif/generic_kernels/pck/gm_de440.tpc",
    "de442.bsp" => "https://naif.jpl.nasa.gov/pub/naif/generic_kernels/spk/planets/de442.bsp",
    "mar099.bsp" =>
      "https://naif.jpl.nasa.gov/pub/naif/generic_kernels/spk/satellites/mar099.bsp",
    "jup349.bsp" =>
      "https://naif.jpl.nasa.gov/pub/naif/generic_kernels/spk/satellites/jup349.bsp",
    "sat459.bsp" =>
      "https://naif.jpl.nasa.gov/pub/naif/generic_kernels/spk/satellites/sat459.bsp",
    "ura184_part-1.bsp" =>
      "https://naif.jpl.nasa.gov/pub/naif/generic_kernels/spk/satellites/ura184_part-1.bsp",
    "ura184_part-2.bsp" =>
      "https://naif.jpl.nasa.gov/pub/naif/generic_kernels/spk/satellites/ura184_part-2.bsp",
    "ura184_part-3.bsp" =>
      "https://naif.jpl.nasa.gov/pub/naif/generic_kernels/spk/satellites/ura184_part-3.bsp",
    "nep105.bsp" =>
      "https://naif.jpl.nasa.gov/pub/naif/generic_kernels/spk/satellites/nep105.bsp",
    "plu060.bsp" => "https://naif.jpl.nasa.gov/pub/naif/generic_kernels/spk/satellites/plu060.bsp"
  }

  @impl true
  def run(args) do
    {opts, rest, invalid} = OptionParser.parse(args, strict: [force: :boolean])

    if rest != [] or invalid != [] do
      Mix.raise("unsupported options. Usage: mix angelus.kernels [--force]")
    end

    force? = Keyword.get(opts, :force, false)
    base_path = Path.join([File.cwd!(), "priv", "kernels"])

    {:ok, _apps} = Application.ensure_all_started(:req)

    Mix.shell().info(
      "Angelus downloads JPL/NAIF kernels from external sources subject to their own terms."
    )

    File.mkdir_p!(base_path)

    planned = plan_downloads(base_path, force?)
    validate_existing!(base_path, planned, force?)

    temporaries = Enum.map(planned, &download_to_temp!(base_path, &1))

    final_paths =
      KernelSet.required_files()
      |> Enum.map(&Path.join(base_path, &1))

    validate_downloads!(temporaries)

    Enum.each(temporaries, fn {tmp_path, final_path} -> File.rename!(tmp_path, final_path) end)

    case KernelSet.validate(final_paths) do
      {:ok, _metadata} -> Mix.shell().info("Angelus kernels are ready in #{base_path}")
      {:error, reason} -> Mix.raise("invalid kernel set: #{inspect(reason)}")
    end
  rescue
    exception ->
      cleanup_temporaries(Path.join([File.cwd!(), "priv", "kernels"]))
      reraise exception, __STACKTRACE__
  end

  defp plan_downloads(base_path, true),
    do: Enum.map(KernelSet.required_files(), &{&1, Path.join(base_path, &1)})

  defp plan_downloads(base_path, false) do
    KernelSet.required_files()
    |> Enum.map(&{&1, Path.join(base_path, &1)})
    |> Enum.reject(fn {_file, path} -> File.exists?(path) end)
  end

  defp validate_existing!(base_path, planned, force?) do
    planned_files = MapSet.new(Enum.map(planned, fn {file, _path} -> file end))

    KernelSet.required_files()
    |> Enum.reject(&MapSet.member?(planned_files, &1))
    |> Enum.each(fn file -> validate_file!(Path.join(base_path, file), force?) end)
  end

  defp download_to_temp!(base_path, {file, final_path}) do
    tmp_path = Path.join(base_path, ".#{file}.tmp")
    File.rm(tmp_path)

    Mix.shell().info("Downloading #{file}")

    response = Req.get!(url: Map.fetch!(@urls, file), into: File.stream!(tmp_path))

    unless response.status in 200..299 do
      File.rm(tmp_path)
      Mix.raise("failed to download #{file}: HTTP #{response.status}")
    end

    validate_file!(tmp_path, true)
    {tmp_path, final_path}
  end

  defp validate_downloads!(temporaries),
    do: Enum.each(temporaries, fn {tmp_path, _final_path} -> validate_file!(tmp_path, true) end)

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
end
