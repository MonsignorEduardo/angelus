defmodule Angelus.Astro.LocationTest do
  use ExUnit.Case, async: true

  alias Angelus.Astro.Location

  test "builds a location with mean-sea-level elevation" do
    assert {:ok, location} =
             Location.new(
               latitude: 40.4168,
               longitude: -3.7038,
               elevation_msl_m: 657
             )

    assert location.latitude == 40.4168
    assert location.longitude == -3.7038
    assert location.elevation_msl_m == 657
  end

  test "defaults elevation to mean sea level" do
    assert {:ok, location} = Location.new(latitude: 0.0, longitude: 0.0)
    assert location.elevation_msl_m == 0.0
  end

  test "accepts coordinate boundaries" do
    assert {:ok, _location} = Location.new(latitude: -90, longitude: -180)
    assert {:ok, _location} = Location.new(latitude: 90, longitude: 180)
  end

  test "rejects missing, malformed, and unsupported options" do
    assert Location.new(longitude: 0) == {:error, :invalid_location}
    assert Location.new([:latitude]) == {:error, :invalid_location}
    assert Location.new("Madrid") == {:error, :invalid_location}

    assert Location.new(latitude: 0, longitude: 0, altitude: 10) ==
             {:error, {:unsupported_location_option, :altitude}}
  end

  test "rejects invalid values and out-of-range coordinates" do
    assert Location.new(latitude: "40", longitude: 0) == {:error, :invalid_location}

    assert Location.new(latitude: 91, longitude: 0) ==
             {:error, {:latitude_out_of_range, 91}}

    assert Location.new(latitude: 0, longitude: -181) ==
             {:error, {:longitude_out_of_range, -181}}
  end

  test "validates structs constructed without the constructor" do
    assert Location.validate(%Location{latitude: 0, longitude: 0}) ==
             {:ok, %Location{latitude: 0, longitude: 0}}

    assert Location.validate(%Location{latitude: nil, longitude: 0}) ==
             {:error, :invalid_location}
  end
end
