defmodule Angelus.EphemerideIntegrationTest do
  use ExUnit.Case, async: false

  @moduletag :e2e

  test "returns the fixed ephemeris for an offset datetime in UTC" do
    {:ok, datetime, _offset} = DateTime.from_iso8601("2000-01-01T07:00:00-05:00")

    assert {:ok, ephemeride} = Angelus.get_ephemeride(datetime)
    assert DateTime.compare(ephemeride.datetime, ~U[2000-01-01 12:00:00Z]) == :eq
    assert length(ephemeride.positions) == 14
    assert Enum.map(ephemeride.positions, & &1.body) == Angelus.Ephemeride.bodies()

    assert Enum.all?(ephemeride.positions, fn position ->
             position.lat >= -90.0 and position.lat <= 90.0 and
               position.decl >= -90.0 and position.decl <= 90.0
           end)
  end
end
