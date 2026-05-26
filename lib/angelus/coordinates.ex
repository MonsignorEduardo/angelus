defmodule Angelus.Coordinates do
  @moduledoc "Coordinate facade reserved for native CSPICE results in v0.1."

  def normalize_ecliptic(%{ecliptic_longitude: longitude, ecliptic_latitude: latitude} = data)
      when is_number(longitude) and is_number(latitude) do
    {:ok,
     %{data | ecliptic_longitude: Angelus.Angle.normalize(longitude), ecliptic_latitude: latitude}}
  end

  def normalize_ecliptic(_data), do: {:error, :invalid_coordinates}
end
