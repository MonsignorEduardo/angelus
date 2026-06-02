defmodule Angelus.Motor.EphemerideTest do
  use ExUnit.Case, async: false

  @moduletag :e2e

  @minor_planet_targets ["20002060", "20000001", "20000002", "20000003", "20000004", "20136199"]

  setup_all do
    assert {:ok, _metadata} = Angelus.Motor.load_kernels(replace: true)
    :ok
  end

  test "returns geocentric state in radians with configurable frame and aberration" do
    assert {:ok, state} =
             Angelus.Motor.ephemeride("SUN", ~U[2000-01-01 12:00:00Z],
               state: :geocentric,
               observer: :earth,
               frame: :eclipj2000,
               abcorr: :lt_s
             )

    assert {x, y, z} = state.position_km
    assert {vx, vy, vz} = state.velocity_km_s

    assert is_float(x)
    assert is_float(y)
    assert is_float(z)
    assert is_float(vx)
    assert is_float(vy)
    assert is_float(vz)

    assert state.distance_km > 0.0
    assert state.distance_au > 0.0
    assert state.ecliptic_longitude_rad >= 0.0
    assert state.ecliptic_longitude_rad < 2.0 * :math.pi()
    assert state.ecliptic_latitude_rad >= -:math.pi() / 2.0
    assert state.ecliptic_latitude_rad <= :math.pi() / 2.0
    assert state.light_time_seconds > 0.0
    assert state.frame == "ECLIPJ2000"
    assert state.abcorr == "LT+S"
    assert state.observer == "EARTH"
    assert state.state == :geocentric
  end

  test "supports geometric state without aberration correction" do
    assert {:ok, apparent} =
             Angelus.Motor.ephemeride("SUN", ~U[2000-01-01 12:00:00Z], abcorr: :lt_s)

    assert {:ok, geometric} =
             Angelus.Motor.ephemeride("SUN", ~U[2000-01-01 12:00:00Z], abcorr: :none)

    assert apparent.abcorr == "LT+S"
    assert geometric.abcorr == "NONE"
    assert apparent.position_km != geometric.position_km
  end

  test "resolves bundled Horizons minor planet SPK targets" do
    Enum.each(@minor_planet_targets, fn target ->
      assert {:ok, state} = Angelus.Motor.ephemeride(target, ~U[2000-01-01 12:00:00Z], [])
      assert state.distance_au > 0.0
      assert state.light_time_seconds > 0.0
    end)
  end
end
