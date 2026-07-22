defmodule Angelus do
  @moduledoc """
  Geocentric tropical ephemerides backed by SPICE/JPL.

      {:ok, ephemeride} = Angelus.get_ephemeride(~U[1998-01-01 00:00:00Z])
  """

  @type observer_option :: Angelus.Observer.option()
  @type ephemeride_option :: Angelus.Motor.load_kernel_option() | {:observer, [observer_option()]}

  @doc """
  Returns the fixed 14-body geocentric tropical ephemeris for `datetime`.

  The supplied instant is normalized to UTC. A `NaiveDateTime` is rejected,
  because it has no offset from which UTC can be determined. Kernel loading is
  managed internally from the calling Mix project's `priv/kernels/`; run
  `mix angelus.prepare` once to install runtime data.
  """
  @spec get_ephemeride(DateTime.t()) :: {:ok, Angelus.Ephemeride.t()} | {:error, term()}
  def get_ephemeride(%DateTime{} = datetime), do: get_ephemeride(datetime, [])
  def get_ephemeride(_datetime), do: {:error, :datetime_must_include_offset}

  @doc """
  Returns an ephemeris using an optional kernel loading configuration.

  Pass `base_path: path` when the application storing the runtime kernels is a
  consumer of Angelus rather than Angelus itself.
  """
  @spec get_ephemeride(DateTime.t(), [ephemeride_option()]) ::
          {:ok, Angelus.Ephemeride.t()} | {:error, term()}
  def get_ephemeride(%DateTime{} = datetime, options) when is_list(options) do
    utc = DateTime.from_unix!(DateTime.to_unix(datetime, :microsecond), :microsecond)

    with {:ok, %{kernel_options: kernel_options, observer: observer}} <-
           Angelus.Ephemeride.Options.split(options),
         :ok <- ensure_kernels_loaded(kernel_options),
         {:ok, positions} <-
           Angelus.Astro.get_positions(
             source_bodies(),
             utc,
             Angelus.Astro.Adapters.Spice,
             observer
           ) do
      {:ok, Angelus.Ephemeride.from_positions(utc, positions, observer)}
    end
  end

  def get_ephemeride(_datetime, _kernel_options), do: {:error, :datetime_must_include_offset}

  defp source_bodies do
    Angelus.Ephemeride.bodies()
    |> List.delete(:south_node)
    |> Enum.map(fn
      :north_node -> :true_node
      body -> body
    end)
  end

  defp ensure_kernels_loaded(kernel_options) do
    case Angelus.Motor.load_kernels(kernel_options) do
      {:ok, _metadata} -> :ok
      {:error, :kernels_already_loaded} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end
end
