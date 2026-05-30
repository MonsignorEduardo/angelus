defmodule Angelus.Motor do
  @moduledoc "Public SPICE facade with v0.1 kernel policy validation."

  alias Angelus.Motor.KernelSet
  alias Angelus.Motor.Server

  @doc """
  Returns the list of kernel filenames required by the default v0.1 kernel set.
  """
  @spec default_kernel_files() :: [String.t()]
  def default_kernel_files, do: KernelSet.required_files()

  @doc """
  Returns the list of kernel filenames required by a supported v0.1 kernel profile.
  """
  @spec default_kernel_files(:core | :full) :: [String.t()]
  def default_kernel_files(profile), do: KernelSet.required_files(profile)

  @doc """
  Loads the default v0.1 SPICE kernel set from `priv/kernels/`.

  Equivalent to `load_kernels([])`.

  ## Returns

    * `{:ok, metadata}` on success, where `metadata` is a map describing the
      loaded kernel set.
    * `{:error, :worker_not_available}` if the native binary has not been compiled.
    * `{:error, :kernels_already_loaded}` if kernels are already loaded and
      `:replace` was not set.
  """
  @spec load_kernels() :: {:ok, map()} | {:error, term()}
  def load_kernels, do: load_kernels([])

  @doc """
  Loads SPICE kernels from explicit paths or using options.

  ## Variants

  ### `load_kernels(opts)` — load default kernel set with options

  `opts` is a keyword list. Supported keys:

    * `:base_path` — directory containing the kernel files (default:
      `"\#{File.cwd!()}/priv/kernels"`).
    * `:profile` — kernel profile to load, either `:full` or `:core`
      (default: `:full`).
    * `:replace` — when `true`, clears any previously loaded kernels before
      loading (default: `false`).

  ### `load_kernels(paths)` — load explicit kernel file paths

  `paths` is a list of absolute file path strings. Use `load_kernels/2` to
  pass options alongside explicit paths.

  ## Returns

    * `{:ok, metadata}` on success.
    * `{:error, {:invalid_kernel_set, reason}}` for invalid paths or missing files.
    * `{:error, :worker_not_available}` if the native binary has not been compiled.
    * `{:error, :kernels_already_loaded}` if kernels are already loaded and
      `:replace` was not set.
    * `{:error, {:unsupported_option, option}}` for unknown options.
  """
  @spec load_kernels(keyword() | [String.t()]) :: {:ok, map()} | {:error, term()}
  def load_kernels(paths_or_opts) when is_list(paths_or_opts) do
    if paths_or_opts == [] or Keyword.keyword?(paths_or_opts) do
      load_default_kernels(paths_or_opts)
    else
      load_kernels(paths_or_opts, [])
    end
  end

  def load_kernels(_paths_or_opts), do: {:error, {:invalid_kernel_set, :invalid_paths}}

  @doc """
  Loads SPICE kernels from explicit paths with options.

  `paths` must be a list of absolute file path strings that form a valid v0.1
  kernel set. `opts` supports `:replace` (boolean, default `false`).

  ## Returns

    * `{:ok, metadata}` on success.
    * `{:error, {:invalid_kernel_set, reason}}` for invalid paths or missing files.
    * `{:error, :kernels_already_loaded}` if kernels are loaded and `:replace` is false.
    * `{:error, {:unsupported_option, option}}` for unknown options.
  """
  @spec load_kernels([String.t()], keyword()) :: {:ok, map()} | {:error, term()}
  def load_kernels(paths, opts) when is_list(paths) and is_list(opts) do
    with :ok <- reject_unknown_options(opts, [:replace]) do
      Server.load_kernels(paths, replace: Keyword.get(opts, :replace, false))
    end
  end

  @doc """
  Converts a UTC `%DateTime{}` to an ephemeris time (ET) seconds-past-J2000 float.

  Requires kernels to be loaded via `load_kernels/0`.

  ## Returns

    * `{:ok, float()}` — ET value in seconds past J2000.
    * `{:error, :invalid_datetime}` if the argument is not a `%DateTime{}`.
    * `{:error, :kernels_not_loaded}` if no kernels have been loaded.
  """
  @spec utc_to_et(DateTime.t()) :: {:ok, float()} | {:error, term()}
  def utc_to_et(%DateTime{} = datetime), do: Server.utc_to_et(datetime)
  def utc_to_et(_datetime), do: {:error, :invalid_datetime}

  @doc """
  Returns the SPICE state (position, velocity, ecliptic coordinates) for a target.

  `target` must be a SPICE target name string. `et` is ephemeris time in seconds
  past J2000 as returned by `utc_to_et/1`. Requires kernels to be loaded.

  ## Options

  All state options are fixed to the v0.1 defaults in this release. Passing
  non-default values returns `{:error, {:unsupported_option, option}}`.

  ## Returns

    * `{:ok, map()}` — state map with position/velocity/ecliptic keys.
    * `{:error, :invalid_et}` when `et` is not a number.
    * `{:error, :invalid_target}` when `target` is not a binary.
    * `{:error, :kernels_not_loaded}` if no kernels have been loaded.
  """
  @spec state(String.t(), float(), keyword()) :: {:ok, map()} | {:error, term()}
  def state(target, et, opts \\ [])

  def state(target, et, opts) when is_binary(target) and is_number(et) and is_list(opts) do
    with :ok <- validate_state_options(opts) do
      Server.state(target, et * 1.0, opts)
    end
  end

  def state(target, _et, _opts) when is_binary(target), do: {:error, :invalid_et}
  def state(_target, _et, _opts), do: {:error, :invalid_target}

  @doc """
  Returns the metadata map for the currently loaded kernel set, or `nil` if no
  kernels have been loaded.

  ## Returns

    * `{:ok, map() | nil}`
  """
  @spec metadata() :: {:ok, map() | nil}
  def metadata, do: Server.metadata()

  @doc """
  Computes the ecliptic longitude of the Moon's ascending node using ERFA
  (IAU SOFA algorithms). Does not require planetary kernels beyond the
  mandatory leap-second (LSK) and Earth orientation (PCK) kernels.

  `calculation` must be one of:
    * `:mean_lunar_node` — IAU IERS 2003 polynomial (eraFaom03). Fast,
      smooth, no periodic terms.
    * `:true_lunar_node` — mean node corrected with IAU 2006/2000A nutation
      in longitude (eraNut06a + eraObl06). Matches the "True Ascending Node"
      in astrology software and JPL Horizons.

  `et` is ephemeris time in seconds past J2000 as returned by `utc_to_et/1`.
  Requires kernels to be loaded (at minimum the leap-second kernel).

  ## Returns

    * `{:ok, map()}` — result map with `:ecliptic_longitude` in degrees
      [0, 360), `:ecliptic_latitude` = 0.0, `:distance_au` = 0.0, and the
      same coordinate keys as a standard state result.
    * `{:error, :invalid_et}` when `et` is not a number.
    * `{:error, :kernels_not_loaded}` if no kernels have been loaded.
    * `{:error, {:unsupported_calculation, atom()}}` for unknown calculation types.
  """
  @spec lunar_node(:mean_lunar_node | :true_lunar_node, float()) ::
          {:ok, map()} | {:error, term()}
  def lunar_node(calculation, et)
      when calculation in [:mean_lunar_node, :true_lunar_node] and is_number(et),
      do: Server.lunar_node(calculation, et * 1.0)

  def lunar_node(_calculation, et) when is_number(et),
    do: {:error, {:unsupported_calculation, :unknown}}

  def lunar_node(_calculation, _et), do: {:error, :invalid_et}

  defp load_default_kernels(opts) do
    base_path = Keyword.get(opts, :base_path, Path.join([File.cwd!(), "priv", "kernels"]))
    profile = Keyword.get(opts, :profile, :full)
    replace? = Keyword.get(opts, :replace, false)

    opts
    |> reject_unknown_options([:base_path, :profile, :replace])
    |> case do
      :ok ->
        if profile in KernelSet.profiles() do
          Server.load_kernels(KernelSet.default_paths(base_path, profile), replace: replace?)
        else
          {:error, {:unsupported_option, {:profile, profile}}}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp reject_unknown_options(opts, supported) do
    case Enum.find(opts, fn {key, _value} -> key not in supported end) do
      nil -> :ok
      option -> {:error, {:unsupported_option, option}}
    end
  end

  defp validate_state_options(opts) do
    allowed = [observer: :earth, frame: "ECLIPJ2000", abcorr: "LT+S"]

    case Enum.find(opts, fn {key, value} -> Keyword.get(allowed, key, :unsupported) != value end) do
      nil -> :ok
      option -> {:error, {:unsupported_option, option}}
    end
  end
end
