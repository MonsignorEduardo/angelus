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

  Options:
    * `:state` — `:geocentric` only for now.
    * `:observer` — `:earth` only for now.
    * `:frame` — `:eclipj2000`, `:j2000`, `:icrf`, or `:gcrs`.
    * `:abcorr` — `:none`, `:lt`, `:lt_s`, `:cn`, or `:cn_s`.

  The native worker returns angular fields in radians. Higher-level Elixir APIs
  perform public unit conversion.

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
        Server.load_kernels(KernelSet.default_paths(base_path), replace: replace?)

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
