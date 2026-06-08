defmodule Angelus.Astro.PointTest do
  use ExUnit.Case, async: true

  alias Angelus.Astro.Point

  test "struct has all required v0.1 fields" do
    point = %Point{}
    fields = Map.keys(point) -- [:__struct__]

    expected = [
      :point,
      :longitude_rad,
      :speed_rad_day,
      :et_seconds,
      :metadata
    ]

    Enum.each(expected, fn field ->
      assert field in fields, "missing field #{field}"
    end)
  end

  test "all fields default to nil" do
    point = %Point{}
    assert point.point == nil
    assert point.longitude_rad == nil
    assert point.metadata == nil
  end

  test "can be constructed with keyword values" do
    point = %Point{
      point: :true_node,
      longitude_rad: 1.2,
      speed_rad_day: -0.01,
      et_seconds: 64.184
    }

    assert point.point == :true_node
    assert point.longitude_rad == 1.2
    assert point.speed_rad_day == -0.01
    assert point.et_seconds == 64.184
  end
end
