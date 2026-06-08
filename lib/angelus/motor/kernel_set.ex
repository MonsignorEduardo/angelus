defmodule Angelus.Motor.KernelSet do
  @moduledoc "Validation and metadata for the v0.1 JPL/NAIF kernel set."

  alias Angelus.Astro.Catalog

  @ephemeris :de442
  @kernel_policy :default
  @public_range %{from: ~D[1900-01-01], to: ~D[2100-01-24]}

  @doc "Validates that `paths` contain exactly the supported v0.1 kernel set."
  @spec validate([String.t()]) :: {:ok, map()} | {:error, term()}
  @spec validate(term()) :: {:error, {:invalid_kernel_set, :invalid_paths}}
  def validate(paths) when is_list(paths) do
    with :ok <- validate_strings(paths),
         basenames = Enum.map(paths, &Path.basename/1),
         :ok <- validate_whitelist(basenames),
         :ok <- validate_tls(basenames),
         :ok <- validate_required_files(basenames),
         :ok <- validate_exact_files(basenames),
         :ok <- validate_files(paths) do
      {:ok, metadata(paths)}
    end
  end

  def validate(_paths), do: {:error, {:invalid_kernel_set, :invalid_paths}}

  defp validate_strings(paths) do
    if Enum.all?(paths, &is_binary/1),
      do: :ok,
      else: {:error, {:invalid_kernel_set, :invalid_paths}}
  end

  defp validate_whitelist(basenames) do
    case Enum.find(basenames, &(&1 not in required_files())) do
      nil -> :ok
      file -> {:error, {:unsupported_kernel, file}}
    end
  end

  defp validate_tls(basenames) do
    case Enum.count(basenames, &String.ends_with?(&1, ".tls")) do
      0 -> {:error, {:invalid_kernel_set, :missing_tls}}
      1 -> :ok
      _count -> {:error, {:invalid_kernel_set, :multiple_tls}}
    end
  end

  defp validate_required_files(basenames) do
    with :ok <- validate_required_tpcs(basenames),
         do: validate_required_bsp_files(basenames)
  end

  defp validate_required_tpcs(basenames) do
    case Enum.find(files_by_type(:pck), &(&1 not in basenames)) do
      nil -> :ok
      file -> {:error, {:invalid_kernel_set, {:missing_tpc, file}}}
    end
  end

  defp validate_required_bsp_files(basenames) do
    cond do
      not Enum.any?(basenames, &String.ends_with?(&1, ".bsp")) ->
        {:error, {:invalid_kernel_set, :missing_bsp}}

      missing = Enum.find(files_by_type(:spk), &(&1 not in basenames)) ->
        {:error, {:invalid_kernel_set, {:missing_bsp, missing}}}

      true ->
        :ok
    end
  end

  defp validate_exact_files(basenames) do
    if Enum.sort(basenames) == Enum.sort(required_files()) do
      :ok
    else
      {:error, {:invalid_kernel_set, :invalid_files}}
    end
  end

  defp validate_files(paths) do
    case Enum.find(paths, &(not File.exists?(&1))) do
      nil -> :ok
      path -> {:error, {:kernel_file_missing, path}}
    end
  end

  defp required_files, do: Enum.map(Catalog.get_kernel(), & &1.file)

  defp files_by_type(type) do
    Catalog.get_kernel()
    |> Enum.filter(&(&1.type == type))
    |> Enum.map(& &1.file)
  end

  defp metadata(paths) do
    by_file = Map.new(paths, fn path -> {Path.basename(path), path} end)

    %{ephemeris: @ephemeris, kernel_policy: @kernel_policy, public_range: @public_range}
    |> Map.put(
      :kernels,
      Enum.map(Catalog.get_kernel(), &kernel_metadata(&1, Map.fetch!(by_file, &1.file)))
    )
  end

  defp kernel_metadata(kernel, path) do
    kernel
    |> Map.drop([:source])
    |> Map.put(:path, path)
  end
end
