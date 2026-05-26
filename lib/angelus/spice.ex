defmodule Angelus.Spice do
  @moduledoc "Public SPICE facade with v0.1 kernel policy validation."

  alias Angelus.Spice.KernelSet
  alias Angelus.Spice.Server

  def supported_bodies, do: Angelus.Spice.BodyTargets.supported_bodies()
  def default_kernel_files, do: KernelSet.required_files()

  def load_kernels, do: load_kernels([])

  def load_kernels(paths_or_opts) when is_list(paths_or_opts) do
    if paths_or_opts == [] or Keyword.keyword?(paths_or_opts) do
      load_default_kernels(paths_or_opts)
    else
      load_kernels(paths_or_opts, [])
    end
  end

  def load_kernels(_paths_or_opts), do: {:error, {:invalid_kernel_set, :invalid_paths}}

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

  def utc_to_et(%DateTime{} = datetime), do: Server.utc_to_et(datetime)
  def utc_to_et(_datetime), do: {:error, :invalid_datetime}

  def state(body, et, opts \\ [])

  def state(body, et, opts) when is_atom(body) and is_number(et) and is_list(opts) do
    with :ok <- validate_state_options(opts) do
      Server.state(body, et * 1.0, opts)
    end
  end

  def state(body, _et, _opts) when is_atom(body), do: {:error, :invalid_et}
  def state(body, _et, _opts), do: {:error, {:unsupported_body, body}}

  def metadata, do: Server.metadata()

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
