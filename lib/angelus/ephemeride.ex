defmodule Angelus.Ephemeride do
  @moduledoc """
  A geocentric tropical ephemeris at one UTC instant.

  This module is the return value of `Angelus.get_ephemeride/1`.
  """

  @bodies [
    :sun,
    :moon,
    :mercury,
    :venus,
    :mars,
    :jupiter,
    :saturn,
    :uranus,
    :neptune,
    :pluto,
    :north_node,
    :south_node,
    :lilith,
    :chiron
  ]

  @earth_equatorial_radius_km 6378.1366
  @earth_polar_radius_km 6356.7519

  defstruct [:datetime, :day, :weekday, :sidereal_time, :reference, positions: []]

  @type motion :: :direct | :retrograde | :stationary

  @type position :: %{
          body: atom(),
          lat: float(),
          decl: float(),
          motion: motion()
        }

  @type calculation_reference :: %{
          observer: :earth_center,
          earth: %{
            shape: :oblate_spheroid,
            equatorial_radius_km: float(),
            polar_radius_km: float(),
            flattening: float()
          },
          coordinate_frame: :true_ecliptic_of_date,
          aberration_correction: String.t()
        }

  @type t :: %__MODULE__{
          datetime: DateTime.t(),
          day: Date.t(),
          weekday: atom(),
          sidereal_time: %{
            hour: non_neg_integer(),
            minute: non_neg_integer(),
            second: non_neg_integer()
          },
          reference: calculation_reference(),
          positions: [position()]
        }

  @doc false
  @spec bodies() :: [atom()]
  def bodies, do: @bodies

  @doc false
  @spec from_positions(DateTime.t(), map(), map()) :: t()
  def from_positions(datetime, positions, previous_positions) do
    %__MODULE__{
      datetime: datetime,
      day: DateTime.to_date(datetime),
      weekday: Date.day_of_week(DateTime.to_date(datetime)) |> weekday(),
      sidereal_time: sidereal_time(datetime),
      reference: reference(),
      positions: build_positions(positions, previous_positions)
    }
  end

  defp reference do
    %{
      observer: :earth_center,
      earth: %{
        shape: :oblate_spheroid,
        equatorial_radius_km: @earth_equatorial_radius_km,
        polar_radius_km: @earth_polar_radius_km,
        flattening:
          (@earth_equatorial_radius_km - @earth_polar_radius_km) / @earth_equatorial_radius_km
      },
      coordinate_frame: :true_ecliptic_of_date,
      aberration_correction: "CN+S"
    }
  end

  defp build_positions(positions, previous_positions) do
    for body <- @bodies do
      {_longitude, motion} = longitude_and_motion(body, positions, previous_positions)
      position = Map.fetch!(positions, source_body(body))
      {lat, decl} = coordinates(body, position)

      %{
        body: body,
        lat: lat,
        decl: decl,
        motion: motion
      }
    end
  end

  defp longitude_and_motion(:south_node, positions, previous_positions) do
    {longitude, motion} = longitude_and_motion(:north_node, positions, previous_positions)
    {normalize(longitude + 180.0), motion}
  end

  defp longitude_and_motion(body, positions, previous_positions) do
    position = Map.fetch!(positions, source_body(body))
    previous = Map.fetch!(previous_positions, source_body(body))
    longitude = longitude(position)
    {longitude, motion(longitude, longitude(previous))}
  end

  defp source_body(:north_node), do: :true_node
  defp source_body(:south_node), do: :true_node
  defp source_body(body), do: body

  defp longitude(%Angelus.Astro.Body{longitude: longitude}), do: longitude
  defp longitude(%Angelus.Astro.Point{longitude_rad: longitude}), do: rad_to_deg(longitude)

  defp latitude(%Angelus.Astro.Body{latitude: latitude}), do: latitude
  defp latitude(%Angelus.Astro.Point{}), do: 0.0

  defp declination(%Angelus.Astro.Body{declination: declination}), do: declination
  defp declination(%Angelus.Astro.Point{declination: declination}), do: declination

  defp coordinates(:south_node, position), do: {-latitude(position), -declination(position)}
  defp coordinates(_body, position), do: {latitude(position), declination(position)}

  defp motion(current, previous) do
    case signed_delta(current, previous) do
      delta when delta > 1.0e-6 -> :direct
      delta when delta < -1.0e-6 -> :retrograde
      _delta -> :stationary
    end
  end

  # Greenwich mean sidereal time, expressed in civil hours. UT1 is approximated
  # by UTC because this public API receives a UTC instant and has no EOP source.
  defp sidereal_time(datetime) do
    julian_date = DateTime.to_unix(datetime, :microsecond) / 86_400_000_000 + 2_440_587.5
    centuries = (julian_date - 2_451_545.0) / 36_525.0

    degrees =
      normalize(
        280.460_618_37 + 360.985_647_366_29 * (julian_date - 2_451_545.0) +
          0.000_387_933 * centuries * centuries - centuries * centuries * centuries / 38_710_000
      )

    total_seconds = round(degrees / 15.0 * 3600)

    %{
      hour: div(total_seconds, 3600) |> rem(24),
      minute: total_seconds |> rem(3600) |> div(60),
      second: rem(total_seconds, 60)
    }
  end

  defp weekday(1), do: :monday
  defp weekday(2), do: :tuesday
  defp weekday(3), do: :wednesday
  defp weekday(4), do: :thursday
  defp weekday(5), do: :friday
  defp weekday(6), do: :saturday
  defp weekday(7), do: :sunday

  defp signed_delta(current, previous) do
    delta = normalize(current - previous)
    if delta > 180.0, do: delta - 360.0, else: delta
  end

  defp normalize(degrees) do
    degrees = rem_float(degrees, 360.0)
    if degrees < 0.0, do: degrees + 360.0, else: degrees
  end

  defp rem_float(value, divisor), do: value - divisor * :math.floor(value / divisor)
  defp rad_to_deg(radians), do: radians * 180.0 / :math.pi()
end
