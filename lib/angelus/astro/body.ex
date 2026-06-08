defmodule Angelus.Astro.Body do
  @moduledoc "State of a physical astronomical body in the v0.1 public API."

  defstruct [
    :body,
    :position_km,
    :velocity_km_s,
    :distance_au,
    :light_time_seconds,
    :et_seconds,
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
  * `:metadata` - internal metadata map (engine, kernels, SPICE settings, etc.).
  """
  @type t() :: %__MODULE__{
          body: atom(),
          position_km: {float(), float(), float()} | nil,
          velocity_km_s: {float(), float(), float()} | nil,
          distance_au: float() | nil,
          light_time_seconds: float() | nil,
          et_seconds: float() | nil,
          metadata: map() | nil
        }
end
