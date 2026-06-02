defmodule Angelus.Motor.WorkerProtocolTest do
  use ExUnit.Case, async: true

  alias Angelus.Motor.WorkerProtocol

  # ── Encoding ────────────────────────────────────────────────────────────

  test "encode_ping produces valid JSON with id and op" do
    json = WorkerProtocol.encode_ping(1)
    assert {:ok, %{"id" => 1, "op" => "ping"}} = Jason.decode(json)
  end

  test "encode_clear_kernels produces correct op" do
    json = WorkerProtocol.encode_clear_kernels(2)
    assert {:ok, %{"id" => 2, "op" => "clear_kernels"}} = Jason.decode(json)
  end

  test "encode_load_kernels includes paths list" do
    paths = ["/a/naif0012.tls", "/a/de442.bsp"]
    json = WorkerProtocol.encode_load_kernels(3, paths)
    assert {:ok, %{"id" => 3, "op" => "load_kernels", "paths" => ^paths}} = Jason.decode(json)
  end

  test "encode_ephemeride includes target, utc and configured params" do
    json =
      WorkerProtocol.encode_ephemeride(4, "JUPITER", "1990-05-24T06:30:00Z", %{
        observer: "EARTH",
        frame: "ECLIPJ2000",
        abcorr: "LT+S"
      })

    assert {:ok, decoded} = Jason.decode(json)
    assert decoded["id"] == 4
    assert decoded["op"] == "ephemeride"
    assert decoded["target"] == "JUPITER"
    assert decoded["observer"] == "EARTH"
    assert decoded["frame"] == "ECLIPJ2000"
    assert decoded["abcorr"] == "LT+S"
    assert decoded["utc"] == "1990-05-24T06:30:00Z"
    refute Map.has_key?(decoded, "units")
  end

  test "encode_ephemeride supports alternative frame and aberration correction" do
    json =
      WorkerProtocol.encode_ephemeride(5, "MARS", "1990-05-24T06:30:00Z", %{
        observer: "EARTH",
        frame: "J2000",
        abcorr: "NONE"
      })

    assert {:ok, decoded} = Jason.decode(json)
    assert decoded["id"] == 5
    assert decoded["target"] == "MARS"
    assert decoded["observer"] == "EARTH"
    assert decoded["frame"] == "J2000"
    assert decoded["abcorr"] == "NONE"
  end

  test "encode_ephemeride is also used for special ephemeride targets" do
    json =
      WorkerProtocol.encode_ephemeride(6, "TRUE_NODE", "2000-01-01T12:00:00Z", %{
        observer: "EARTH",
        frame: "ECLIPJ2000",
        abcorr: "LT+S"
      })

    assert {:ok, decoded} = Jason.decode(json)
    assert decoded["id"] == 6
    assert decoded["op"] == "ephemeride"
    assert decoded["target"] == "TRUE_NODE"
    assert decoded["utc"] == "2000-01-01T12:00:00Z"
    refute Map.has_key?(decoded, "calculation")
  end

  # ── Decoding ────────────────────────────────────────────────────────────

  test "decode returns ok tuple on success response" do
    json = ~s({"id":1,"ok":true,"result":"pong"})
    assert {:ok, 1, "pong"} = WorkerProtocol.decode(json)
  end

  test "decode returns error tuple on error response" do
    json = ~s({"id":2,"ok":false,"error":"CSPICE not available"})
    assert {:error, 2, "CSPICE not available"} = WorkerProtocol.decode(json)
  end

  test "decode returns decode_error on malformed JSON" do
    assert {:error, :decode_error, _} = WorkerProtocol.decode("not json {{{")
  end

  test "decode returns decode_error on unexpected structure" do
    assert {:error, :decode_error, _} = WorkerProtocol.decode(~s({"wrong":"keys"}))
  end

  # ── coerce_state ────────────────────────────────────────────────────────

  test "coerce_state converts string-keyed map to typed atom-keyed map" do
    raw = %{
      "state_km" => [1.0, 2.0, 3.0, 0.1, 0.2, 0.3],
      "distance_km" => 151_400_000.0,
      "distance_au" => 1.012,
      "right_ascension_rad" => 1.2,
      "declination_rad" => 0.3,
      "ecliptic_longitude_rad" => 1.103_011,
      "ecliptic_latitude_rad" => 0.000_174,
      "radial_velocity_km_s" => -0.2,
      "ecliptic_longitude_speed_rad_day" => 0.01,
      "ecliptic_latitude_speed_rad_day" => 0.001,
      "distance_speed_km_s" => 0.3,
      "light_time_seconds" => 499.0,
      "et_seconds" => -302_378_400.0,
      "frame" => "J2000",
      "abcorr" => "LT+S"
    }

    assert {:ok, coerced} = WorkerProtocol.coerce_state(raw)
    assert coerced.position_km == {1.0, 2.0, 3.0}
    assert coerced.velocity_km_s == {0.1, 0.2, 0.3}
    assert coerced.distance_km == 151_400_000.0
    assert coerced.distance_au == 1.012
    assert coerced.right_ascension_rad == 1.2
    assert coerced.declination_rad == 0.3
    assert coerced.ecliptic_longitude_rad == 1.103_011
    assert coerced.ecliptic_latitude_rad == 0.000_174
    assert coerced.ecliptic_longitude == 1.103_011
    assert coerced.ecliptic_latitude == 0.000_174
    assert coerced.radial_velocity_km_s == -0.2
    assert coerced.ecliptic_longitude_speed_rad_day == 0.01
    assert coerced.ecliptic_latitude_speed_rad_day == 0.001
    assert coerced.distance_speed_km_s == 0.3
    assert coerced.light_time_seconds == 499.0
    assert coerced.et_seconds == -302_378_400.0
    assert coerced.et == -302_378_400.0
    assert coerced.frame == "J2000"
    assert coerced.abcorr == "LT+S"
  end

  test "coerce_state returns error on invalid map" do
    assert {:error, :invalid_state_result} = WorkerProtocol.coerce_state(%{"wrong" => "data"})
    assert {:error, :invalid_state_result} = WorkerProtocol.coerce_state("not a map")
  end
end
