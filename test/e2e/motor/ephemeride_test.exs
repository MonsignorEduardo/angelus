defmodule Angelus.Motor.EphemerideTest do
  use ExUnit.Case, async: false

  alias Angelus.Astro.Location

  @moduletag :e2e

  @minor_planet_targets [
    "20002060",
    "20000001",
    "20000002",
    "20000003",
    "20000004",
    "20136199"
  ]

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

  test "returns a topocentric Moon state for a mean-sea-level location" do
    assert {:ok, location} =
             Location.new(
               latitude: 40.4168,
               longitude: -3.7038,
               elevation_msl_m: 657
             )

    assert {:ok, adapter} = Angelus.load_kernels(replace: true)

    assert {:ok, moon} =
             Angelus.get_position(:moon, ~U[2000-01-01 12:00:00Z], location, adapter)

    assert moon.distance_au > 0.0
    assert moon.metadata.state == :topocentric
    assert moon.metadata.observer.geoid == :egm2008_2_5
    assert_in_delta moon.metadata.observer.ellipsoidal_height_m, 708.666, 0.001
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
