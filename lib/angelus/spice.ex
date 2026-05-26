defmodule Angelus.Spice do
  @moduledoc "Public SPICE facade with v0.1 kernel policy validation."

  alias Angelus.Spice.KernelSet
  alias Angelus.Spice.Server

  @doc """
  Returns the list of body atoms supported by the v0.1 SPICE engine.

  ## Examples

      iex> :sun in Angelus.Spice.supported_bodies()
      true
  """
  @spec supported_bodies() :: [atom()]
  def supported_bodies, do: Angelus.Spice.BodyTargets.supported_bodies()

  @doc """
  Returns the list of kernel filenames required by the default v0.1 kernel set.
  """
  @spec default_kernel_files() :: [String.t()]
  def default_kernel_files, do: KernelSet.required_files()

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

  defp load_default_kernels(opts) do
    base_path = Keyword.get(opts, :base_path, Path.join([File.cwd!(), "priv", "kernels"]))
    replace? = Keyword.get(opts, :replace, false)

    opts
    |> reject_unknown_options([:base_path, :replace])
    |> case do
      :ok -> Server.load_kernels(KernelSet.default_paths(base_path), replace: replace?)
      {:error, reason} -> {:error, reason}
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
  Returns the SPICE state (position, velocity, ecliptic coordinates) for a body.

  `body` must be an atom recognised by `supported_bodies/0`. `et` is ephemeris
  time in seconds past J2000 as returned by `utc_to_et/1`. Requires kernels to
  be loaded.

  ## Options

  All state options are fixed to the v0.1 defaults in this release. Passing
  non-default values returns `{:error, {:unsupported_option, option}}`.

  ## Returns

    * `{:ok, map()}` — state map with position/velocity/ecliptic keys.
    * `{:error, :invalid_et}` when `et` is not a number.
    * `{:error, {:unsupported_body, atom()}}` for unrecognised or non-atom bodies.
    * `{:error, :kernels_not_loaded}` if no kernels have been loaded.
  """
  @spec state(atom(), float(), keyword()) :: {:ok, map()} | {:error, term()}
  def state(body, et, opts \\ [])

  def state(body, et, opts) when is_atom(body) and is_number(et) and is_list(opts) do
    with :ok <- validate_state_options(opts) do
      Server.state(body, et * 1.0, opts)
    end
  end

  def state(body, _et, _opts) when is_atom(body), do: {:error, :invalid_et}
  def state(body, _et, _opts), do: {:error, {:unsupported_body, body}}

  @doc """
  Returns the metadata map for the currently loaded kernel set, or `nil` if no
  kernels have been loaded.

  ## Returns

    * `{:ok, map() | nil}`
  """
  @spec metadata() :: {:ok, map() | nil}
  def metadata, do: Server.metadata()

  @doc """
  Returns the SPICE target metadata for the given body atom.

  ## Returns

    * `{:ok, map()}` — target map with `:spice_target`, `:spice_id`, and
      `:target_kind` keys.
    * `{:error, {:unsupported_body, atom()}}` when the body is not recognised.
  """
  @spec body_target(atom()) :: {:ok, map()} | {:error, {:unsupported_body, atom()}}
  def body_target(body), do: Angelus.Spice.BodyTargets.fetch(body)

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
