defmodule Angelus.EphemerideIntegrationTest do
  use ExUnit.Case, async: false

  @moduletag :e2e

  test "returns the fixed ephemeris for an offset datetime in UTC" do
    {:ok, datetime, _offset} = DateTime.from_iso8601("2000-01-01T07:00:00-05:00")

    assert {:ok, ephemeride} = Angelus.get_ephemeride(datetime)
    assert DateTime.compare(ephemeride.time.utc, ~U[2000-01-01 12:00:00Z]) == :eq
    assert ephemeride.schema_version == 2
    assert Enum.map(ephemeride.bodies, & &1.id) == Enum.take(Angelus.Ephemeride.bodies(), 11)
    assert Enum.map(ephemeride.points, & &1.id) == [:north_node, :south_node, :lilith]

    assert Enum.all?(ephemeride.bodies, fn body ->
             solution = body.solutions.geocentric

             solution.ecliptic.latitude_rad >= -:math.pi() / 2 and
               solution.ecliptic.latitude_rad <= :math.pi() / 2 and
               solution.equatorial.declination_rad >= -:math.pi() / 2 and
               solution.equatorial.declination_rad <= :math.pi() / 2
           end)
  end
end
