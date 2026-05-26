defmodule Angelus.CoordinatesTest do
  use ExUnit.Case, async: true

  alias Angelus.Coordinates

  test "normalize_ecliptic normalizes longitude to [0, 360)" do
    assert {:ok, %{ecliptic_longitude: 350.0, ecliptic_latitude: -5.0}} =
             Coordinates.normalize_ecliptic(%{ecliptic_longitude: -10.0, ecliptic_latitude: -5.0})

    assert {:ok, result} =
             Coordinates.normalize_ecliptic(%{ecliptic_longitude: 360.0, ecliptic_latitude: 1.5})

    assert abs(result.ecliptic_longitude) < 1.0e-10
    assert result.ecliptic_latitude == 1.5

    assert {:ok, result721} =
             Coordinates.normalize_ecliptic(%{ecliptic_longitude: 721.0, ecliptic_latitude: 0.0})

    assert result721.ecliptic_longitude == 1.0
    assert abs(result721.ecliptic_latitude) < 1.0e-10
  end

  test "normalize_ecliptic preserves latitude sign" do
    assert {:ok, %{ecliptic_latitude: -3.5}} =
             Coordinates.normalize_ecliptic(%{ecliptic_longitude: 45.0, ecliptic_latitude: -3.5})
  end

  test "normalize_ecliptic preserves extra fields in the map" do
    input = %{ecliptic_longitude: 400.0, ecliptic_latitude: 1.0, body: :sun}
    assert {:ok, %{body: :sun, ecliptic_longitude: 40.0}} = Coordinates.normalize_ecliptic(input)
  end

  test "normalize_ecliptic returns error on invalid data" do
    assert {:error, :invalid_coordinates} = Coordinates.normalize_ecliptic(%{})
    assert {:error, :invalid_coordinates} = Coordinates.normalize_ecliptic("bad")

    assert {:error, :invalid_coordinates} =
             Coordinates.normalize_ecliptic(%{ecliptic_longitude: "x", ecliptic_latitude: 0.0})
  end
end
