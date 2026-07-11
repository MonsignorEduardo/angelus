defmodule Angelus.Motor.EphemerideTest do
  use ExUnit.Case, async: false

  @moduletag :e2e

  @minor_planet_targets ["2002060", "2000001", "2000002", "2000003", "2000004", "2136199"]

  setup_all do
    assert {:ok, _metadata} = Angelus.Motor.load_kernels(replace: true)
    :ok
  end

  test "returns geocentric state vector with fixed native defaults" do
    assert {:ok, state} = Angelus.Motor.get_body("SUN", ~U[2000-01-01 12:00:00Z])

    assert {x, y, z} = state.position_km
    assert {vx, vy, vz} = state.velocity_km_s

    assert is_float(x)
    assert is_float(y)
    assert is_float(z)
    assert is_float(vx)
    assert is_float(vy)
    assert is_float(vz)

    assert state.distance_au > 0.0
    assert state.frame_base == "ECLIPJ2000"
    assert state.abcorr == "CN+S"
    assert state.observer == "EARTH"
    assert state.state == :geocentric
  end

  test "resolves Horizons minor planet SPK targets" do
    Enum.each(@minor_planet_targets, fn target ->
      assert {:ok, state} = Angelus.Motor.get_body(target, ~U[2000-01-01 12:00:00Z])
      assert state.distance_au > 0.0
    end)
  end

  test "returns mathematical point longitude and speed" do
    assert {:ok, point} = Angelus.Motor.get_math_point("TRUE_NODE", ~U[2000-01-01 12:00:00Z])

    assert is_float(point.longitude_rad)
    assert is_float(point.speed_rad_day)
    assert is_float(point.et_seconds)
    assert point.point == "TRUE_NODE"
  end
end
