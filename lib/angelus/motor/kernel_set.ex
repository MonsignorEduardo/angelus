defmodule Angelus.Motor.KernelSet do
  @moduledoc "Validation and metadata for the v0.1 JPL/NAIF kernel set."

  alias Angelus.Ephemeris.BodyCatalog

  @doc "Returns the required leap-seconds kernel filename."
  @spec lsk() :: String.t()
  def lsk, do: BodyCatalog.lsks() |> List.first()

  @doc "Returns the required text planetary-constants kernel filenames."
  @spec tpcs() :: [String.t()]
  def tpcs, do: BodyCatalog.tpcs()

  @doc "Returns the required SPK kernel filenames."
  @spec spks() :: [String.t()]
  def spks, do: BodyCatalog.spks()

  @doc "Returns every kernel filename required by the default v0.1 kernel set."
  @spec required_files() :: [String.t()]
  def required_files, do: BodyCatalog.required_files()

  @doc "Builds absolute kernel paths under `base_path` for the default v0.1 kernel set."
  @spec default_paths(String.t()) :: [String.t()]
  def default_paths(base_path) when is_binary(base_path),
    do: BodyCatalog.default_paths(base_path)

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

  @doc "Builds structured metadata for a validated v0.1 kernel path list."
  @spec metadata([String.t()]) :: map()
  def metadata(paths), do: BodyCatalog.metadata(paths)

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
         :ok <- validate_required_bsp_files(basenames) do
      :ok
    end
  end

  defp validate_required_tpcs(basenames) do
    case Enum.find(tpcs(), &(&1 not in basenames)) do
      nil -> :ok
      file -> {:error, {:invalid_kernel_set, {:missing_tpc, file}}}
    end
  end

  defp validate_required_bsp_files(basenames) do
    cond do
      not Enum.any?(basenames, &String.ends_with?(&1, ".bsp")) ->
        {:error, {:invalid_kernel_set, :missing_bsp}}

      missing = Enum.find(spks(), &(&1 not in basenames)) ->
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
end
