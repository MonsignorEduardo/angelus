defmodule Angelus do
  @moduledoc """
  Geocentric tropical ephemerides backed by SPICE/JPL.

      {:ok, ephemeride} = Angelus.get_ephemeride(~U[1998-01-01 00:00:00Z])
  """

  @doc """
  Returns the fixed 14-body geocentric tropical ephemeris for `datetime`.

  The supplied instant is normalized to UTC. A `NaiveDateTime` is rejected,
  because it has no offset from which UTC can be determined. Kernel loading is
  managed internally; run `mix angelus.prepare` once to install runtime data.
  """
  @spec get_ephemeride(DateTime.t()) :: {:ok, Angelus.Ephemeride.t()} | {:error, term()}
  def get_ephemeride(%DateTime{} = datetime) do
    utc = DateTime.from_unix!(DateTime.to_unix(datetime, :microsecond), :microsecond)
    previous_utc = DateTime.add(utc, -86_400, :second)

    with :ok <- ensure_kernels_loaded(),
         {:ok, positions} <-
           Angelus.Astro.get_positions(source_bodies(), utc, Angelus.Astro.Adapters.Spice),
         {:ok, previous_positions} <-
           Angelus.Astro.get_positions(
             source_bodies(),
             previous_utc,
             Angelus.Astro.Adapters.Spice
           ) do
      {:ok, Angelus.Ephemeride.from_positions(utc, positions, previous_positions)}
    end
  end

  def get_ephemeride(_datetime), do: {:error, :datetime_must_include_offset}

  defp source_bodies do
    Angelus.Ephemeride.bodies()
    |> List.delete(:south_node)
    |> Enum.map(fn
      :north_node -> :true_node
      body -> body
    end)
  end

  defp ensure_kernels_loaded do
    case Angelus.Motor.load_kernels() do
      {:ok, _metadata} -> :ok
      {:error, :kernels_already_loaded} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end
end
