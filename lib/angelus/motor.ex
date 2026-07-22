defmodule Angelus.Motor do
  @moduledoc false

  alias Angelus.Astro.Catalog
  alias Angelus.Motor.Server

  @typedoc """
  Keyword option accepted when loading the default v0.1 kernel set.

  Valid entries are:

    * `{:base_path, path}` — base directory containing the default kernel files.
    * `{:replace, boolean}` — whether to clear an already-loaded kernel set
      before loading the new one.

  Unsupported options return `{:error, {:unsupported_option, option}}`.
  """
  @type load_kernel_option :: {:base_path, Path.t()} | {:replace, boolean()}

  @typedoc """
  Keyword option accepted when loading explicit kernel paths.

  Valid entries are:

    * `{:replace, boolean}` — whether to clear an already-loaded kernel set
      before loading the new one.

  Unsupported options return `{:error, {:unsupported_option, option}}`.
  """
  @type explicit_kernel_option :: {:replace, boolean()}

  @doc """
  Returns the list of kernel filenames required by the default v0.1 kernel set.
  """
  @spec default_kernel_files() :: [String.t()]
  def default_kernel_files, do: Enum.map(Catalog.get_kernel(), & &1.file)

  @doc """
  Loads the default v0.1 SPICE kernel set from the calling Mix project's
  `priv/kernels/` directory.

  Equivalent to `load_kernels([])`.
  """
  @spec load_kernels() :: {:ok, map()} | {:error, term()}
  def load_kernels, do: load_kernels([])

  @doc """
  Loads SPICE kernels from explicit paths or using options.

  See `t:load_kernel_option/0` for the accepted keyword entries when loading
  the default kernel set.
  """
  @spec load_kernels([load_kernel_option()] | [String.t()]) :: {:ok, map()} | {:error, term()}
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

  See `t:explicit_kernel_option/0` for the accepted keyword entries.
  """
  @spec load_kernels([String.t()], [explicit_kernel_option()]) :: {:ok, map()} | {:error, term()}
  def load_kernels(paths, opts) when is_list(paths) and is_list(opts) do
    with :ok <- validate_keyword_options(opts),
         :ok <- reject_unknown_options(opts, [:replace]),
         :ok <- validate_boolean_option(opts, :replace) do
      Server.load_kernels(paths, replace: Keyword.get(opts, :replace, false))
    end
  end

  def load_kernels(_paths, _opts), do: {:error, {:invalid_kernel_set, :invalid_paths}}

  @doc """
  Returns the combined UTC -> ET -> body state vector result in a single round-trip
  to the native worker.

  `target` must be a SPICE target name string. `utc` must be a `%DateTime{}`.
  Native position requests always use Earth as observer, geocentric state,
  the `ECLIPJ2000` frame, and converged Newtonian stellar aberration (`CN+S`).

  ## Returns

    * `{:ok, map()}` — state map with position, velocity and distance keys.
    * `{:error, :invalid_args}` when arguments are invalid.
    * `{:error, :kernels_not_loaded}` if no kernels have been loaded.
  """
  @spec get_body(String.t(), DateTime.t()) :: {:ok, map()} | {:error, term()}
  def get_body(target, %DateTime{} = utc) when is_binary(target), do: get_body(target, utc, nil)

  def get_body(_target, _utc), do: {:error, :invalid_args}

  @doc false
  @spec get_body(String.t(), DateTime.t(), Angelus.Observer.t() | nil) ::
          {:ok, map()} | {:error, term()}
  def get_body(target, %DateTime{} = utc, observer)
      when is_binary(target) and (is_map(observer) or is_nil(observer)),
      do: Server.get_body(target, utc, observer)

  def get_body(_target, _utc, _observer), do: {:error, :invalid_args}

  @doc "Returns a mathematical point longitude/speed result from the native worker."
  @spec get_math_point(String.t(), DateTime.t()) :: {:ok, map()} | {:error, term()}
  def get_math_point(point, %DateTime{} = utc) when is_binary(point),
    do: Server.get_math_point(point, utc)

  def get_math_point(_point, _utc), do: {:error, :invalid_args}

  @doc """
  Returns the metadata map for the currently loaded kernel set, or `nil` if no
  kernels have been loaded.
  """
  @spec metadata() :: {:ok, map() | nil}
  def metadata, do: Server.metadata()

  defp load_default_kernels(opts) do
    with :ok <- validate_keyword_options(opts),
         :ok <- reject_unknown_options(opts, [:base_path, :replace]),
         :ok <- validate_path_option(opts, :base_path),
         :ok <- validate_boolean_option(opts, :replace),
         {:ok, default_base_path} <- default_kernel_path() do
      base_path = Keyword.get(opts, :base_path, default_base_path)
      Server.load_kernels(default_paths(base_path), replace: Keyword.get(opts, :replace, false))
    end
  end

  defp validate_keyword_options(opts) do
    if Keyword.keyword?(opts),
      do: :ok,
      else: {:error, {:invalid_options, :expected_keyword_list}}
  end

  defp reject_unknown_options(opts, supported) do
    case Enum.find(opts, fn {key, _value} -> key not in supported end) do
      nil -> :ok
      option -> {:error, {:unsupported_option, option}}
    end
  end

  defp validate_boolean_option(opts, key) do
    case Keyword.fetch(opts, key) do
      :error -> :ok
      {:ok, value} when is_boolean(value) -> :ok
      {:ok, value} -> {:error, {:invalid_option, {key, value}}}
    end
  end

  defp validate_path_option(opts, key) do
    case Keyword.fetch(opts, key) do
      :error -> :ok
      {:ok, value} when is_binary(value) and value != "" -> :ok
      {:ok, value} -> {:error, {:invalid_option, {key, value}}}
    end
  end

  defp default_kernel_path, do: {:ok, Path.join([File.cwd!(), "priv", "kernels"])}

  defp default_paths(base_path) when is_binary(base_path) do
    Catalog.get_kernel()
    |> Enum.map(&Path.join(base_path, &1.file))
  end
end
