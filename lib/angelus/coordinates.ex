defmodule Angelus.Coordinates do
  @moduledoc "Coordinate facade reserved for native CSPICE results in v0.1."

  @doc """
  Normalizes the `ecliptic_longitude` field of an ecliptic coordinate map to
  `[0.0, 360.0)` while preserving all other fields.

  The input map must include numeric `:ecliptic_longitude` and
  `:ecliptic_latitude` keys.  Returns `{:error, :invalid_coordinates}` for any
  other input.

  ## Examples

      iex> Angelus.Coordinates.normalize_ecliptic(%{ecliptic_longitude: 370.0, ecliptic_latitude: -5.0})
      {:ok, %{ecliptic_longitude: 10.0, ecliptic_latitude: -5.0}}
  """
  @spec normalize_ecliptic(map()) :: {:ok, map()} | {:error, :invalid_coordinates}
  def normalize_ecliptic(%{ecliptic_longitude: longitude, ecliptic_latitude: latitude} = data)
      when is_number(longitude) and is_number(latitude) do
    {:ok,
     %{data | ecliptic_longitude: Angelus.Angle.normalize(longitude), ecliptic_latitude: latitude}}
  end

  def normalize_ecliptic(_data), do: {:error, :invalid_coordinates}
end
