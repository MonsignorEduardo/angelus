defmodule Angelus.Astro.Point do
  @moduledoc "State of a mathematical astronomical point in the v0.1 public API."

  defstruct [
    :point,
    :longitude_rad,
    :speed_rad_day,
    :et_seconds,
    :metadata
  ]

  @typedoc """
  Mathematical point state.

  Fields:

  * `:point` - the point atom (e.g. `:true_node`, `:lilith`).
  * `:longitude_rad` - ecliptic longitude in radians.
  * `:speed_rad_day` - longitude speed in radians per day.
  * `:et_seconds` - ephemeris time / TDB seconds past J2000.
  * `:metadata` - internal metadata map (engine, kernels, source point, etc.).
  """
  @type t() :: %__MODULE__{
          point: atom(),
          longitude_rad: float() | nil,
          speed_rad_day: float() | nil,
          et_seconds: float() | nil,
          metadata: map() | nil
        }
end
