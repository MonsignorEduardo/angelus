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

  test "encode_body includes target, utc and configured params" do
    json =
      WorkerProtocol.encode_body(4, "JUPITER", "1990-05-24T06:30:00Z", %{
        observer: "EARTH",
        frame: "ECLIPJ2000",
        abcorr: "LT+S"
      })

    assert {:ok, decoded} = Jason.decode(json)
    assert decoded["id"] == 4
    assert decoded["op"] == "body"
    assert decoded["target"] == "JUPITER"
    assert decoded["observer"] == "EARTH"
    assert decoded["frame"] == "ECLIPJ2000"
    assert decoded["abcorr"] == "LT+S"
    assert decoded["utc"] == "1990-05-24T06:30:00Z"
    refute Map.has_key?(decoded, "units")
  end

  test "encode_body supports alternative frame and aberration correction" do
    json =
      WorkerProtocol.encode_body(5, "MARS", "1990-05-24T06:30:00Z", %{
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

  test "encode_math_point includes point and utc" do
    json = WorkerProtocol.encode_math_point(6, "TRUE_NODE", "2000-01-01T12:00:00Z")

    assert {:ok, decoded} = Jason.decode(json)
    assert decoded["id"] == 6
    assert decoded["op"] == "math_point"
    assert decoded["point"] == "TRUE_NODE"
    assert decoded["utc"] == "2000-01-01T12:00:00Z"
    refute Map.has_key?(decoded, "target")
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

  # ── coerce_body ─────────────────────────────────────────────────────────

  test "coerce_body converts string-keyed map to typed atom-keyed map" do
    raw = %{
      "state_km" => [1.0, 2.0, 3.0, 0.1, 0.2, 0.3],
      "light_time_seconds" => 499.0,
      "et_seconds" => 64.184
    }

    assert {:ok, coerced} = WorkerProtocol.coerce_body(raw)
    assert coerced.position_km == {1.0, 2.0, 3.0}
    assert coerced.velocity_km_s == {0.1, 0.2, 0.3}
    assert_in_delta coerced.distance_au, :math.sqrt(14.0) / 149_597_870.7, 1.0e-18
    assert coerced.light_time_seconds == 499.0
    assert coerced.et_seconds == 64.184
  end

  test "coerce_body returns error on invalid map" do
    assert {:error, :invalid_body_result} = WorkerProtocol.coerce_body(%{"wrong" => "data"})
    assert {:error, :invalid_body_result} = WorkerProtocol.coerce_body("not a map")
  end

  test "coerce_point converts string-keyed map to typed atom-keyed map" do
    raw = %{
      "longitude_rad" => 1.2,
      "speed_rad_day" => -0.01,
      "et_seconds" => 64.184
    }

    assert {:ok, coerced} = WorkerProtocol.coerce_point(raw)
    assert coerced.longitude_rad == 1.2
    assert coerced.speed_rad_day == -0.01
    assert coerced.et_seconds == 64.184
  end

  test "coerce_point returns error on invalid map" do
    assert {:error, :invalid_point_result} = WorkerProtocol.coerce_point(%{"wrong" => "data"})
    assert {:error, :invalid_point_result} = WorkerProtocol.coerce_point("not a map")
  end
end
