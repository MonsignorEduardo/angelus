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
  """
  @spec load_kernels() :: {:ok, map()} | {:error, term()}
  def load_kernels, do: load_kernels([])

  @doc """
  Loads SPICE kernels from explicit paths or using options.
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
  """
  @spec load_kernels([String.t()], keyword()) :: {:ok, map()} | {:error, term()}
  def load_kernels(paths, opts) when is_list(paths) and is_list(opts) do
    with :ok <- reject_unknown_options(opts, [:replace]) do
      Server.load_kernels(paths, replace: Keyword.get(opts, :replace, false))
    end
  end

  @doc """
  Returns the combined UTC -> ET -> state (position, velocity, ecliptic coords)
  result in a single round-trip to the native worker.

  `target` must be a SPICE target name string. `utc` must be a `%DateTime{}`.

  Options (v0.2):
    * `:units` — `"deg"` (default) or `"rad"` to control longitude/latitude units

  ## Returns

    * `{:ok, map()}` — state map with position/velocity/ecliptic keys.
    * `{:error, :invalid_args}` when arguments are invalid.
    * `{:error, :kernels_not_loaded}` if no kernels have been loaded.
  """
  @spec ephemeride(String.t(), DateTime.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def ephemeride(target, %DateTime{} = utc, opts) when is_binary(target) and is_list(opts) do
    with :ok <- validate_state_options(opts) do
      Server.ephemeride(target, utc, opts)
    end
  end

  def ephemeride(_target, _utc, _opts), do: {:error, :invalid_args}

  @doc """
  Computes the ecliptic longitude of the Moon's ascending node using ERFA
  (IAU SOFA algorithms).

  `calculation` must be one of `:mean_lunar_node` or `:true_lunar_node`.
  Accepts a `%DateTime{}` and optional opts (e.g., `units: "rad"`).
  """
  @spec lunar_node(:mean_lunar_node | :true_lunar_node, DateTime.t(), keyword()) ::
          {:ok, map()} | {:error, term()}
  def lunar_node(calculation, utc, opts \\ [])

  def lunar_node(calculation, %DateTime{} = utc, opts)
      when calculation in [:mean_lunar_node, :true_lunar_node] and is_list(opts),
      do: Server.lunar_node(calculation, utc, opts)

  def lunar_node(_calculation, _utc, _opts), do: {:error, :invalid_args}

  @doc """
  Returns the metadata map for the currently loaded kernel set, or `nil` if no
  kernels have been loaded.
  """
  @spec metadata() :: {:ok, map() | nil}
  def metadata, do: Server.metadata()

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
