defmodule Angelus.Spice.WorkerProtocolTest do
  use ExUnit.Case, async: true

  alias Angelus.Spice.WorkerProtocol

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

  test "encode_utc_to_et includes utc field" do
    json = WorkerProtocol.encode_utc_to_et(4, "1990-05-24T06:30:00Z")

    assert {:ok, %{"id" => 4, "op" => "utc_to_et", "utc" => "1990-05-24T06:30:00Z"}} =
             Jason.decode(json)
  end

  test "encode_state includes all required fields with v0.1 fixed params" do
    json = WorkerProtocol.encode_state(5, "JUPITER", -302_378_400.0)
    assert {:ok, decoded} = Jason.decode(json)
    assert decoded["id"] == 5
    assert decoded["op"] == "state"
    assert decoded["target"] == "JUPITER"
    assert decoded["observer"] == "EARTH"
    assert decoded["frame"] == "ECLIPJ2000"
    assert decoded["abcorr"] == "LT+S"
    assert decoded["et"] == -302_378_400.0
  end

  test "encode_lunar_node encodes mean_lunar_node correctly" do
    json = WorkerProtocol.encode_lunar_node(6, :mean_lunar_node, 0.0)
    assert {:ok, decoded} = Jason.decode(json)
    assert decoded["id"] == 6
    assert decoded["op"] == "lunar_node"
    assert decoded["calculation"] == "mean_lunar_node"
    assert decoded["et"] == 0.0
  end

  test "encode_lunar_node encodes true_lunar_node correctly" do
    json = WorkerProtocol.encode_lunar_node(7, :true_lunar_node, -302_378_400.0)
    assert {:ok, decoded} = Jason.decode(json)
    assert decoded["id"] == 7
    assert decoded["op"] == "lunar_node"
    assert decoded["calculation"] == "true_lunar_node"
    assert decoded["et"] == -302_378_400.0
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
      "distance_au" => 1.012,
      "ecliptic_longitude" => 63.25,
      "ecliptic_latitude" => 0.01,
      "light_time_seconds" => 499.0,
      "et" => -302_378_400.0
    }

    assert {:ok, coerced} = WorkerProtocol.coerce_state(raw)
    assert coerced.position_km == {1.0, 2.0, 3.0}
    assert coerced.velocity_km_s == {0.1, 0.2, 0.3}
    assert coerced.distance_au == 1.012
    assert coerced.ecliptic_longitude == 63.25
    assert coerced.ecliptic_latitude == 0.01
    assert coerced.light_time_seconds == 499.0
    assert coerced.et == -302_378_400.0
  end

  test "coerce_state returns error on invalid map" do
    assert {:error, :invalid_state_result} = WorkerProtocol.coerce_state(%{"wrong" => "data"})
    assert {:error, :invalid_state_result} = WorkerProtocol.coerce_state("not a map")
  end
end
