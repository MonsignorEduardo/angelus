defmodule Angelus.Astro.Body do
  @moduledoc "State of a physical astronomical body in the v0.1 public API."

  defstruct [
    :body,
    :position_km,
    :velocity_km_s,
    :distance_au,
    :light_time_seconds,
    :et_seconds,
    :longitude,
    :latitude,
    :longitude_rad,
    :latitude_rad,
    :declination,
    :declination_rad,
    :right_ascension_rad,
    :longitude_rate_rad_day,
    :latitude_rate_rad_day,
    :right_ascension_rate_rad_day,
    :declination_rate_rad_day,
    :direction_j2000,
    :radial_velocity_km_s,
    :solutions,
    :metadata
  ]

  @typedoc """
  Physical body state.

  Fields:

  * `:body` - the body atom (e.g. `:sun`, `:moon`).
  * `:position_km` - `{x, y, z}` position vector in km.
  * `:velocity_km_s` - `{vx, vy, vz}` velocity vector in km/s.
  * `:distance_au` - distance from Earth to the body in astronomical units.
  * `:light_time_seconds` - one-way light time from target to observer.
  * `:et_seconds` - ephemeris time / TDB seconds past J2000.
  * `:longitude` and `:latitude` - tropical true-ecliptic coordinates of date in degrees.
   * `:longitude_rad` and `:latitude_rad` - the same coordinates in radians.
   * `:declination` and `:declination_rad` - true-equatorial declination of date.
  """
  @type t() :: %__MODULE__{
          body: atom(),
          position_km: {float(), float(), float()} | nil,
          velocity_km_s: {float(), float(), float()} | nil,
          distance_au: float() | nil,
          light_time_seconds: float() | nil,
          et_seconds: float() | nil,
          longitude: float() | nil,
          latitude: float() | nil,
          longitude_rad: float() | nil,
          latitude_rad: float() | nil,
          declination: float() | nil,
          declination_rad: float() | nil,
          right_ascension_rad: float() | nil,
          longitude_rate_rad_day: float() | nil,
          latitude_rate_rad_day: float() | nil,
          right_ascension_rate_rad_day: float() | nil,
          declination_rate_rad_day: float() | nil,
          direction_j2000: {float(), float(), float()} | nil,
          radial_velocity_km_s: float() | nil,
          solutions: %{optional(:geocentric | :topocentric) => map()} | nil,
          metadata: map() | nil
        }
end
