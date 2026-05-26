defmodule Angelus.Spice.KernelSet do
  @moduledoc false

  @lsk "latest_leapseconds.tls"
  @tpcs ["pck00011.tpc", "gm_de440.tpc"]
  @spks [
    "de442.bsp",
    "mar099.bsp",
    "jup349.bsp",
    "sat459.bsp",
    "ura184_part-1.bsp",
    "ura184_part-2.bsp",
    "ura184_part-3.bsp",
    "nep105.bsp",
    "plu060.bsp"
  ]
  @required [@lsk | @tpcs ++ @spks]

  @doc false
  @spec lsk() :: String.t()
  def lsk, do: @lsk

  @doc false
  @spec tpcs() :: [String.t()]
  def tpcs, do: @tpcs

  @doc false
  @spec spks() :: [String.t()]
  def spks, do: @spks

  @doc false
  @spec required_files() :: [String.t()]
  def required_files, do: @required

  @doc false
  @spec default_paths(String.t()) :: [String.t()]
  def default_paths(base_path) when is_binary(base_path) do
    Enum.map(@required, &Path.join(base_path, &1))
  end

  @doc false
  @spec validate([String.t()]) :: {:ok, map()} | {:error, term()}
  @spec validate(term()) :: {:error, {:invalid_kernel_set, :invalid_paths}}
  def validate(paths) when is_list(paths) do
    with :ok <- validate_strings(paths),
         basenames = Enum.map(paths, &Path.basename/1),
         :ok <- validate_whitelist(basenames),
         :ok <- validate_tls(basenames),
         :ok <- validate_required_tpcs(basenames),
         :ok <- validate_required_spks(basenames),
         :ok <- validate_files(paths) do
      {:ok, metadata(paths)}
    end
  end

  def validate(_paths), do: {:error, {:invalid_kernel_set, :invalid_paths}}

  @doc false
  @spec metadata([String.t()]) :: map()
  def metadata(paths) do
    by_file = Map.new(paths, fn path -> {Path.basename(path), path} end)

    %{
      ephemeris: :de442,
      kernel_policy: :default_modern,
      public_range: %{from: ~D[1900-01-01], to: ~D[2100-01-24]},
      kernels: Enum.map(@required, &kernel_metadata(&1, Map.fetch!(by_file, &1)))
    }
  end

  defp validate_strings(paths) do
    if Enum.all?(paths, &is_binary/1),
      do: :ok,
      else: {:error, {:invalid_kernel_set, :invalid_paths}}
  end

  defp validate_whitelist(basenames) do
    case Enum.find(basenames, &(&1 not in @required)) do
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

  defp validate_required_tpcs(basenames) do
    case Enum.find(@tpcs, &(&1 not in basenames)) do
      nil -> :ok
      file -> {:error, {:invalid_kernel_set, {:missing_tpc, file}}}
    end
  end

  defp validate_required_spks(basenames) do
    cond do
      not Enum.any?(basenames, &String.ends_with?(&1, ".bsp")) ->
        {:error, {:invalid_kernel_set, :missing_bsp}}

      missing = Enum.find(@spks, &(&1 not in basenames)) ->
        {:error, {:invalid_kernel_set, {:missing_bsp, missing}}}

      true ->
        :ok
    end
  end

  defp validate_files(paths) do
    case Enum.find(paths, &(not File.exists?(&1))) do
      nil -> :ok
      path -> {:error, {:kernel_file_missing, path}}
    end
  end

  defp kernel_metadata("latest_leapseconds.tls", path),
    do: %{type: :lsk, file: "latest_leapseconds.tls", path: path}

  defp kernel_metadata("pck00011.tpc", path), do: %{type: :pck, file: "pck00011.tpc", path: path}
  defp kernel_metadata("gm_de440.tpc", path), do: %{type: :pck, file: "gm_de440.tpc", path: path}

  defp kernel_metadata("de442.bsp", path) do
    %{
      type: :spk,
      file: "de442.bsp",
      path: path,
      ephemeris: :de442,
      policy: :default_modern,
      range: {~D[1549-12-31], ~D[2650-01-25]}
    }
  end

  defp kernel_metadata(file, path),
    do: Map.merge(%{type: :spk, file: file, path: path, role: :body_center_chain}, target(file))

  defp target("mar099.bsp"), do: %{target: "MARS", spice_id: 499}
  defp target("jup349.bsp"), do: %{target: "JUPITER", spice_id: 599}
  defp target("sat459.bsp"), do: %{target: "SATURN", spice_id: 699}
  defp target("ura184_part-" <> _), do: %{target: "URANUS", spice_id: 799}
  defp target("nep105.bsp"), do: %{target: "NEPTUNE", spice_id: 899}
  defp target("plu060.bsp"), do: %{target: "PLUTO", spice_id: 999}
end
