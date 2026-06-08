defmodule Angelus.Astro.BodyTest do
  use ExUnit.Case, async: true

  alias Angelus.Astro.Body

  test "struct has all required v0.1 fields" do
    body = %Body{}
    fields = Map.keys(body) -- [:__struct__]

    expected = [
      :body,
      :position_km,
      :velocity_km_s,
      :distance_au,
      :light_time_seconds,
      :et_seconds,
      :metadata
    ]

    Enum.each(expected, fn field ->
      assert field in fields, "missing field #{field}"
    end)
  end

  test "all fields default to nil" do
    body = %Body{}
    assert body.body == nil
    assert body.position_km == nil
    assert body.metadata == nil
  end

  test "can be constructed with keyword values" do
    body = %Body{
      body: :sun,
      position_km: {1.0, 2.0, 3.0},
      velocity_km_s: {0.1, 0.2, 0.3},
      distance_au: 1.012,
      light_time_seconds: 499.0,
      et_seconds: 64.184
    }

    assert body.body == :sun
    assert body.position_km == {1.0, 2.0, 3.0}
    assert body.velocity_km_s == {0.1, 0.2, 0.3}
    assert body.distance_au == 1.012
    assert body.light_time_seconds == 499.0
    assert body.et_seconds == 64.184
  end
end
