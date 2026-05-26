defmodule Angelus.Ephemeris.BodyPosition do
  @moduledoc "Position of a supported astrological body in the v0.1 public API."

  @typedoc """
  Geocentric ecliptic position of a celestial body.

  Fields:

  * `:body` — the body atom (e.g. `:sun`, `:moon`).
  * `:spice_target` — SPICE target name string (e.g. `"SUN"`).
  * `:spice_id` — SPICE integer ID for the target.
  * `:target_kind` — one of `:body_center`, `:lunar_node`, `:lunar_apogee`,
    or `:minor_planet`.
  * `:position_km` — `{x, y, z}` position vector in km (ECLIPJ2000 frame).
  * `:velocity_km_s` — `{vx, vy, vz}` velocity vector in km/s.
  * `:light_time_seconds` — one-way light travel time from target to observer.
  * `:longitude` — geocentric ecliptic longitude in degrees `[0, 360)`.
  * `:latitude` — geocentric ecliptic latitude in degrees.
  * `:distance_au` — distance from Earth to the body in astronomical units.
  * `:metadata` — internal metadata map (engine, kernels, SPICE settings, etc.).
  """
  @type t() :: %__MODULE__{
          body: atom(),
          spice_target: String.t() | nil,
          spice_id: non_neg_integer() | nil,
          target_kind: :body_center | :lunar_node | :lunar_apogee | :minor_planet | nil,
          position_km: {float(), float(), float()} | nil,
          velocity_km_s: {float(), float(), float()} | nil,
          light_time_seconds: float() | nil,
          longitude: float() | nil,
          latitude: float() | nil,
          distance_au: float() | nil,
          metadata: map() | nil
        }

  defstruct [
    :body,
    :spice_target,
    :spice_id,
    :target_kind,
    :position_km,
    :velocity_km_s,
    :light_time_seconds,
    :longitude,
    :latitude,
    :distance_au,
    :metadata
  ]
end
