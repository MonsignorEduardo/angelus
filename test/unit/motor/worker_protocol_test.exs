defmodule Angelus.Motor.WorkerProtocolTest do
  use ExUnit.Case, async: true

  alias Angelus.Motor.WorkerProtocol
  alias Angelus.Observer

  test "encodes a geocentric protocol v2 body request without an observer field" do
    request =
      WorkerProtocol.encode_body(1, "MARS", "2000-01-01T12:00:00Z", nil)
      |> Jason.decode!()

    assert request == %{
             "protocol_version" => 2,
             "id" => 1,
             "op" => "body",
             "target" => "MARS",
             "utc" => "2000-01-01T12:00:00Z"
           }
  end

  test "encodes a normalized surface observer in radians and kilometers" do
    {:ok, observer} =
      Observer.validate(latitude_deg: 40.4168, longitude_deg: -3.7038, height_m: 667)

    request =
      WorkerProtocol.encode_body(7, "MOON", "2000-01-01T12:00:00Z", observer)
      |> Jason.decode!()

    assert request["protocol_version"] == WorkerProtocol.protocol_version()
    assert request["observer"]["kind"] == "surface"
    assert request["observer"]["body_fixed_frame"] == "ITRF93"
    assert_in_delta request["observer"]["latitude_rad"], observer.latitude_rad, 1.0e-15
    assert_in_delta request["observer"]["longitude_rad"], observer.longitude_rad, 1.0e-15
    assert request["observer"]["height_km"] == 0.667
  end

  test "decodes geocentric and topocentric protocol v2 solutions" do
    state = %{
      "state_km" => [1, 2, 3, 4, 5, 6],
      "light_time_seconds" => 7,
      "longitude_rad" => 0.1,
      "latitude_rad" => 0.2,
      "declination_rad" => 0.3,
      "right_ascension_rad" => 0.4,
      "longitude_rate_rad_day" => 0.5,
      "latitude_rate_rad_day" => 0.6,
      "right_ascension_rate_rad_day" => 0.7,
      "declination_rate_rad_day" => 0.8,
      "direction_j2000" => [0.1, 0.2, 0.3],
      "distance_au" => 1.0,
      "radial_velocity_km_s" => 2.0,
      "frame" => "ECLIPJ2000",
      "observer" => "EARTH_CENTER",
      "abcorr" => "CN+S"
    }

    assert {:ok, %{geocentric: geocentric, topocentric: topocentric}} =
             WorkerProtocol.coerce_body(%{
               "protocol_version" => 2,
               "et_seconds" => 42,
               "geocentric" => state,
               "topocentric" => %{
                 "state_km" => [10, 20, 30, 40, 50, 60],
                 "light_time_seconds" => 8,
                 "frame" => "TOPOCENTRIC_ENU",
                 "observer" => "SURFACE_LOCATION",
                 "observer_frame" => "ITRF93",
                 "abcorr" => "CN+S"
               }
             })

    assert geocentric.position_km == {1.0, 2.0, 3.0}
    assert geocentric.et_seconds == 42.0
    assert topocentric.position_km == {10.0, 20.0, 30.0}
    assert topocentric.velocity_km_s == {40.0, 50.0, 60.0}
    assert topocentric.frame == :topocentric_enu
  end
end
