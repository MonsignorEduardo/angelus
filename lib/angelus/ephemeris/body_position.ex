defmodule Angelus.Ephemeris.BodyPosition do
  @moduledoc "Position of a supported astrological body in the v0.1 public API."

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
