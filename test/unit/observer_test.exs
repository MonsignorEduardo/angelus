defmodule Angelus.ObserverTest do
  use ExUnit.Case, async: true

  alias Angelus.Observer

  test "normalizes a complete observer and converts its units" do
    assert {:ok, observer} =
             Observer.validate(latitude_deg: 40.4168, longitude_deg: 180.0, height_m: 667)

    assert observer.latitude_deg == 40.4168
    assert observer.longitude_deg == -180.0
    assert observer.height_m == 667.0
    assert_in_delta observer.latitude_rad, 0.705406, 0.000001
    assert_in_delta observer.longitude_rad, -:math.pi(), 1.0e-15
    assert observer.height_km == 0.667
  end

  test "requires exactly the three supported observer fields" do
    assert {:error, {:invalid_observer, {:missing_fields, [:height_m]}}} =
             Observer.validate(latitude_deg: 0, longitude_deg: 0)

    assert {:error, {:invalid_observer, {:duplicate_field, :latitude_deg}}} =
             Observer.validate(latitude_deg: 0, latitude_deg: 1, longitude_deg: 0, height_m: 0)

    assert {:error, {:invalid_observer, {:unsupported_field, :name}}} =
             Observer.validate(latitude_deg: 0, longitude_deg: 0, height_m: 0, name: "Madrid")

    assert {:error, {:invalid_observer, :expected_keyword_list}} =
             Observer.validate(%{latitude_deg: 0, longitude_deg: 0, height_m: 0})
  end

  test "rejects invalid coordinates and height" do
    assert {:error, {:invalid_observer, {:latitude_out_of_range, 90.1}}} =
             Observer.validate(latitude_deg: 90.1, longitude_deg: 0, height_m: 0)

    assert {:error, {:invalid_observer, {:longitude_out_of_range, -180.1}}} =
             Observer.validate(latitude_deg: 0, longitude_deg: -180.1, height_m: 0)

    assert {:error, {:invalid_observer, {:height_out_of_range, 100_000.1}}} =
             Observer.validate(latitude_deg: 0, longitude_deg: 0, height_m: 100_000.1)

    assert {:error, {:invalid_observer, {:height_out_of_range, "667"}}} =
             Observer.validate(latitude_deg: 0, longitude_deg: 0, height_m: "667")
  end

  test "accepts the documented coordinate and height limits" do
    assert {:ok, _} = Observer.validate(latitude_deg: -90, longitude_deg: -180, height_m: -500)
    assert {:ok, _} = Observer.validate(latitude_deg: 90, longitude_deg: 180, height_m: 100_000)
  end
end
