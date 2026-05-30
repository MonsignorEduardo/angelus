defmodule Angelus.Motor.KernelSet do
  @moduledoc "Validation and metadata for the v0.1 JPL/NAIF kernel set."

  @lsk "naif0012.tls"
  @tpcs ["pck00011.tpc", "gm_de440.tpc"]
  @core_spks ["de442.bsp"]
  @companion_spks [
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
  @core_required [@lsk | @tpcs ++ @core_spks]
  @full_required [@lsk | @tpcs ++ @companion_spks]
  @profiles [:core, :full]

  @doc "Returns the required leap-seconds kernel filename."
  @spec lsk() :: String.t()
  def lsk, do: @lsk

  @doc "Returns the required text planetary-constants kernel filenames."
  @spec tpcs() :: [String.t()]
  def tpcs, do: @tpcs

  @doc "Returns the required SPK kernel filenames."
  @spec spks() :: [String.t()]
  def spks, do: @companion_spks

  @doc "Returns supported kernel profile atoms."
  @spec profiles() :: [:core | :full]
  def profiles, do: @profiles

  @doc "Returns every kernel filename required by the default v0.1 kernel set."
  @spec required_files() :: [String.t()]
  def required_files, do: required_files(:full)

  @doc "Returns every kernel filename required by a supported v0.1 kernel profile."
  @spec required_files(:core | :full) :: [String.t()]
  def required_files(:core), do: @core_required
  def required_files(:full), do: @full_required

  @doc "Builds absolute kernel paths under `base_path` for the default v0.1 kernel set."
  @spec default_paths(String.t()) :: [String.t()]
  def default_paths(base_path) when is_binary(base_path), do: default_paths(base_path, :full)

  @doc "Builds absolute kernel paths under `base_path` for a supported v0.1 kernel profile."
  @spec default_paths(String.t(), :core | :full) :: [String.t()]
  def default_paths(base_path, profile) when is_binary(base_path) do
    Enum.map(required_files(profile), &Path.join(base_path, &1))
  end

  @doc "Validates that `paths` contain exactly the supported v0.1 kernel set."
  @spec validate([String.t()]) :: {:ok, map()} | {:error, term()}
  @spec validate(term()) :: {:error, {:invalid_kernel_set, :invalid_paths}}
  def validate(paths) when is_list(paths) do
    with :ok <- validate_strings(paths),
         basenames = Enum.map(paths, &Path.basename/1),
         :ok <- validate_whitelist(basenames),
         :ok <- validate_tls(basenames),
         {:ok, profile} <- detect_profile(basenames),
         :ok <- validate_files(paths) do
      {:ok, metadata(paths, profile)}
    end
  end

  def validate(_paths), do: {:error, {:invalid_kernel_set, :invalid_paths}}

  @doc "Builds structured metadata for a validated v0.1 kernel path list."
  @spec metadata([String.t()]) :: map()
  def metadata(paths), do: metadata(paths, detect_profile!(Enum.map(paths, &Path.basename/1)))

  @doc "Builds structured metadata for a validated v0.1 kernel path list and profile."
  @spec metadata([String.t()], :core | :full) :: map()
  def metadata(paths, profile) do
    by_file = Map.new(paths, fn path -> {Path.basename(path), path} end)
    required = required_files(profile)

    %{
      ephemeris: :de442,
      kernel_policy: kernel_policy(profile),
      public_range: %{from: ~D[1900-01-01], to: ~D[2100-01-24]},
      profile: profile,
      kernels: Enum.map(required, &kernel_metadata(&1, Map.fetch!(by_file, &1)))
    }
  end

  defp validate_strings(paths) do
    if Enum.all?(paths, &is_binary/1),
      do: :ok,
      else: {:error, {:invalid_kernel_set, :invalid_paths}}
  end

  defp validate_whitelist(basenames) do
    case Enum.find(basenames, &(&1 not in @full_required)) do
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

  defp detect_profile(basenames) do
    cond do
      Enum.sort(basenames) == Enum.sort(@core_required) -> {:ok, :core}
      Enum.sort(basenames) == Enum.sort(@full_required) -> {:ok, :full}
      true -> validate_required_files(basenames)
    end
  end

  defp detect_profile!(basenames) do
    case detect_profile(basenames) do
      {:ok, profile} -> profile
      {:error, reason} -> raise ArgumentError, "invalid kernel set: #{inspect(reason)}"
    end
  end

  defp validate_required_files(basenames) do
    with :ok <- validate_required_tpcs(basenames),
         :ok <- validate_required_spks(basenames) do
      {:error, {:invalid_kernel_set, :unsupported_profile}}
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

      missing = Enum.find(@core_spks, &(&1 not in basenames)) ->
        {:error, {:invalid_kernel_set, {:missing_bsp, missing}}}

      Enum.any?(basenames, &(&1 in (@companion_spks -- @core_spks))) ->
        case Enum.find(@companion_spks, &(&1 not in basenames)) do
          nil -> :ok
          missing -> {:error, {:invalid_kernel_set, {:missing_bsp, missing}}}
        end

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

  defp kernel_metadata("naif0012.tls", path), do: %{type: :lsk, file: "naif0012.tls", path: path}

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

  defp kernel_policy(:core), do: :core
  defp kernel_policy(:full), do: :default_modern

  defp target("mar099.bsp"), do: %{target: "MARS", spice_id: 499}
  defp target("jup349.bsp"), do: %{target: "JUPITER", spice_id: 599}
  defp target("sat459.bsp"), do: %{target: "SATURN", spice_id: 699}
  defp target("ura184_part-" <> _), do: %{target: "URANUS", spice_id: 799}
  defp target("nep105.bsp"), do: %{target: "NEPTUNE", spice_id: 899}
  defp target("plu060.bsp"), do: %{target: "PLUTO", spice_id: 999}
end
