defmodule Angelus.Ephemeris.BodyPositionTest do
  use ExUnit.Case, async: true

  alias Angelus.Ephemeris.BodyPosition

  test "struct has all required v0.1 fields" do
    pos = %BodyPosition{}

    fields = Map.keys(pos) -- [:__struct__]

    expected = [
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

    Enum.each(expected, fn f ->
      assert f in fields, "missing field #{f}"
    end)
  end

  test "all fields default to nil" do
    pos = %BodyPosition{}
    assert pos.body == nil
    assert pos.longitude == nil
    assert pos.metadata == nil
  end

  test "can be constructed with keyword values" do
    pos = %BodyPosition{
      body: :sun,
      spice_target: "SUN",
      spice_id: 10,
      target_kind: :body_center,
      longitude: 63.25,
      latitude: 0.01,
      distance_au: 1.012
    }

    assert pos.body == :sun
    assert pos.longitude == 63.25
    assert pos.distance_au == 1.012
  end
end
