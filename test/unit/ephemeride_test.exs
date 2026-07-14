defmodule Angelus.EphemerideTest do
  use ExUnit.Case, async: true

  alias Angelus.Astro.Body
  alias Angelus.Astro.Point
  alias Angelus.Ephemeride

  test "returns the fixed ordered body set with scientific coordinates" do
    datetime = ~U[2000-01-01 12:00:00Z]

    positions = %{
      sun: %Body{longitude: 10.0, latitude: 1.5, declination: 5.0},
      moon: %Body{longitude: 20.0, latitude: 0.0, declination: 0.0},
      mercury: %Body{longitude: 30.0, latitude: 0.0, declination: 0.0},
      venus: %Body{longitude: 40.0, latitude: 0.0, declination: 0.0},
      mars: %Body{longitude: 50.0, latitude: 0.0, declination: 0.0},
      jupiter: %Body{longitude: 60.0, latitude: 0.0, declination: 0.0},
      saturn: %Body{longitude: 70.0, latitude: 0.0, declination: 0.0},
      uranus: %Body{longitude: 80.0, latitude: 0.0, declination: 0.0},
      neptune: %Body{longitude: 90.0, latitude: 0.0, declination: 0.0},
      pluto: %Body{longitude: 100.0, latitude: 0.0, declination: 0.0},
      true_node: %Point{longitude_rad: :math.pi() / 2, declination: 23.4},
      lilith: %Point{longitude_rad: :math.pi(), declination: 0.0},
      chiron: %Body{longitude: 190.0, latitude: 0.0, declination: 0.0}
    }

    previous_positions = Map.update!(positions, :sun, &%{&1 | longitude: 9.0})
    ephemeride = Ephemeride.from_positions(datetime, positions, previous_positions)

    assert Enum.map(ephemeride.positions, & &1.body) == Ephemeride.bodies()
    assert ephemeride.datetime == datetime
    assert ephemeride.weekday == :saturday
    assert %{hour: 18, minute: 41, second: 51} = ephemeride.sidereal_time

    assert %{
             observer: :earth_center,
             earth: %{
               shape: :oblate_spheroid,
               equatorial_radius_km: 6378.1366,
               polar_radius_km: 6356.7519,
               flattening: flattening
             },
             coordinate_frame: :true_ecliptic_of_date,
             aberration_correction: "CN+S"
           } = ephemeride.reference

    assert_in_delta flattening, 0.0033528131084554717, 1.0e-15

    assert %{body: :sun, lat: 1.5, decl: 5.0, motion: :direct} = hd(ephemeride.positions)

    north_node = Enum.find(ephemeride.positions, &(&1.body == :north_node))
    south_node = Enum.find(ephemeride.positions, &(&1.body == :south_node))
    assert north_node.lat == 0.0
    assert south_node.lat == 0.0
    assert north_node.decl == 23.4
    assert south_node.decl == -23.4
  end
end
