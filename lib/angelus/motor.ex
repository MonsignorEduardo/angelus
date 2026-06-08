defmodule Angelus.Motor do
  @moduledoc "Public SPICE facade with v0.1 kernel policy validation."

  alias Angelus.Astro.Catalog
  alias Angelus.Motor.Server

  @typedoc """
  Reference frame accepted by `body/3`.

  Valid values are `:eclipj2000`, `:j2000`, `:icrf`, and `:gcrs`.
  """
  @type frame :: :eclipj2000 | :j2000 | :icrf | :gcrs

  @typedoc """
  Aberration correction accepted by `body/3`.

  Valid values are `:none`, `:lt`, `:lt_s`, `:cn`, and `:cn_s`.
  """
  @type abcorr :: :none | :lt | :lt_s | :cn | :cn_s

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

  @typedoc """
  Keyword option accepted by `body/3`.

  Valid entries are:

    * `{:state, :geocentric}` — geocentric state vector.
    * `{:observer, :earth}` — Earth as the observing body.
    * `{:frame, frame}` — one of the frames in `t:frame/0`.
    * `{:abcorr, abcorr}` — one of the aberration corrections in `t:abcorr/0`.

  Defaults are `state: :geocentric`, `observer: :earth`,
  `frame: :eclipj2000`, and `abcorr: :lt_s`.

  Unsupported options return `{:error, {:unsupported_option, option}}`.
  """
  @type body_option ::
          {:state, :geocentric}
          | {:observer, :earth}
          | {:frame, frame()}
          | {:abcorr, abcorr()}

  @doc """
  Returns the list of kernel filenames required by the default v0.1 kernel set.
  """
  @spec default_kernel_files() :: [String.t()]
  def default_kernel_files, do: Enum.map(Catalog.get_kernel(), & &1.file)

  @doc """
  Loads the default v0.1 SPICE kernel set from `priv/kernels/`.

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
    with :ok <- reject_unknown_options(opts, [:replace]) do
      Server.load_kernels(paths, replace: Keyword.get(opts, :replace, false))
    end
  end

  @doc """
  Returns the combined UTC -> ET -> body state vector result in a single round-trip
  to the native worker.

  `target` must be a SPICE target name string. `utc` must be a `%DateTime{}`.

  ## Options

    * `:state` — `:geocentric` only for now.
    * `:observer` — `:earth` only for now.
    * `:frame` — `:eclipj2000`, `:j2000`, `:icrf`, or `:gcrs`.
    * `:abcorr` — `:none`, `:lt`, `:lt_s`, `:cn`, or `:cn_s`.

  See `t:body_option/0` for the accepted keyword entries.

  ## Returns

    * `{:ok, map()}` — state map with position, velocity and distance keys.
    * `{:error, :invalid_args}` when arguments are invalid.
    * `{:error, :kernels_not_loaded}` if no kernels have been loaded.
    * `{:error, {:unsupported_option, term()}}` for unknown options or values.
  """
  @spec body(String.t(), DateTime.t(), [body_option()]) :: {:ok, map()} | {:error, term()}
  def body(target, %DateTime{} = utc, opts) when is_binary(target) and is_list(opts) do
    with :ok <- validate_state_options(opts) do
      Server.body(target, utc, opts)
    end
  end

  def body(_target, _utc, _opts), do: {:error, :invalid_args}

  @doc "Returns a mathematical point longitude/speed result from the native worker."
  @spec math_point(String.t(), DateTime.t()) :: {:ok, map()} | {:error, term()}
  def math_point(point, %DateTime{} = utc) when is_binary(point),
    do: Server.math_point(point, utc)

  def math_point(_point, _utc), do: {:error, :invalid_args}

  @doc """
  Returns the metadata map for the currently loaded kernel set, or `nil` if no
  kernels have been loaded.
  """
  @spec metadata() :: {:ok, map() | nil}
  def metadata, do: Server.metadata()

  defp load_default_kernels(opts) do
    base_path = Keyword.get(opts, :base_path, Path.join([File.cwd!(), "priv", "kernels"]))
    replace? = Keyword.get(opts, :replace, false)

    opts
    |> reject_unknown_options([:base_path, :replace])
    |> case do
      :ok ->
        Server.load_kernels(default_paths(base_path), replace: replace?)

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

  defp default_paths(base_path) when is_binary(base_path) do
    Catalog.get_kernel()
    |> Enum.map(&Path.join(base_path, &1.file))
  end

  defp validate_state_options(opts) do
    [
      fn -> reject_unknown_options(opts, [:state, :observer, :frame, :abcorr]) end,
      fn -> validate_option(opts, :state, [:geocentric]) end,
      fn -> validate_option(opts, :observer, [:earth]) end,
      fn -> validate_option(opts, :frame, [:eclipj2000, :j2000, :icrf, :gcrs]) end,
      fn -> validate_option(opts, :abcorr, [:none, :lt, :lt_s, :cn, :cn_s]) end
    ]
    |> Enum.reduce_while(:ok, fn validate, :ok ->
      case validate.() do
        :ok -> {:cont, :ok}
        {:error, _reason} = error -> {:halt, error}
      end
    end)
  end

  defp validate_option(opts, key, allowed_values) do
    case Keyword.fetch(opts, key) do
      {:ok, value} ->
        if Enum.member?(allowed_values, value),
          do: :ok,
          else: {:error, {:unsupported_option, {key, value}}}

      :error ->
        :ok
    end
  end
end
