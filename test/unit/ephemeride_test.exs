defmodule Angelus.EphemerideTest do
  use ExUnit.Case, async: true

  alias Angelus.Astro.Body
  alias Angelus.Astro.Point
  alias Angelus.Ephemeride

  test "builds schema version 2 with separate physical and mathematical entries" do
    datetime = ~U[2000-01-01 12:00:00Z]

    positions =
      Map.new(
        [
          :sun,
          :moon,
          :mercury,
          :venus,
          :mars,
          :jupiter,
          :saturn,
          :uranus,
          :neptune,
          :pluto,
          :chiron
        ],
        &{&1, body()}
      )

    positions = Map.merge(positions, %{true_node: point(:true_node), lilith: point(:lilith)})

    ephemeride = Ephemeride.from_positions(datetime, positions)

    assert ephemeride.schema_version == 2
    assert ephemeride.time.utc == datetime
    assert ephemeride.time.quality == :modelled
    assert ephemeride.reference.observers == %{geocentric: %{origin: :earth_center}}

    assert Enum.map(ephemeride.bodies, & &1.id) == [
             :sun,
             :moon,
             :mercury,
             :venus,
             :mars,
             :jupiter,
             :saturn,
             :uranus,
             :neptune,
             :pluto,
             :chiron
           ]

    assert Enum.map(ephemeride.points, & &1.id) == [:north_node, :south_node, :lilith]

    solution = hd(ephemeride.bodies).solutions.geocentric
    assert solution.state.frame == :eclipj2000
    assert solution.direction.frame == :j2000
    assert solution.ecliptic.frame == :true_ecliptic_of_date
    assert solution.equatorial.frame == :true_equatorial_of_date
    assert solution.calculation.observer == :earth_center

    north = hd(ephemeride.points).solutions.geocentric
    south = Enum.at(ephemeride.points, 1).solutions.geocentric
    assert_in_delta north.direction.x, -south.direction.x, 1.0e-15
    assert_in_delta north.equatorial.declination_rad, -south.equatorial.declination_rad, 1.0e-15
  end

  defp body do
    %Body{
      position_km: {1.0, 2.0, 3.0},
      velocity_km_s: {4.0, 5.0, 6.0},
      distance_au: 1.0,
      radial_velocity_km_s: 2.0,
      light_time_seconds: 3.0,
      et_seconds: 0.0,
      longitude_rad: 0.1,
      latitude_rad: 0.2,
      declination_rad: 0.3,
      right_ascension_rad: 0.4,
      longitude_rate_rad_day: 0.5,
      latitude_rate_rad_day: 0.6,
      right_ascension_rate_rad_day: 0.7,
      declination_rate_rad_day: 0.8,
      direction_j2000: {0.1, 0.2, 0.3}
    }
  end

  defp point(id),
    do: %Point{point: id, longitude_rad: 0.1, declination_rad: 0.2, speed_rad_day: 0.3}
end
