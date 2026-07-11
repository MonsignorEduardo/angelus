defmodule Angelus.AstroTest do
  use ExUnit.Case, async: false
  import Mox

  setup :verify_on_exit!

  @spice_mock Angelus.Astro.AdapterMock

  test "get_position accepts only an atom body" do
    assert Angelus.get_position([:sun], ~U[1990-05-24 06:30:00Z], @spice_mock) ==
             {:error, :invalid_body}
  end

  test "get_position returns the single result from get_positions" do
    datetime = ~U[1990-05-24 06:30:00Z]
    body = canned_body(:sun)

    expect(@spice_mock, :get_position, fn ^datetime, :sun ->
      {:ok, body}
    end)

    assert Angelus.get_position(:sun, datetime, @spice_mock) == {:ok, body}
  end

  test "get_positions validates injected adapters" do
    assert Angelus.Astro.get_positions([:sun], ~U[1990-05-24 06:30:00Z], SomeAdapter) ==
             {:error, {:invalid_adapter, SomeAdapter}}
  end

  test "get_positions with coordinates validates injected adapters" do
    assert Angelus.Astro.get_positions(
             [:sun],
             ~U[1990-05-24 06:30:00Z],
             {40.4, -3.7, 667},
             SomeAdapter
           ) ==
             {:error, {:invalid_adapter, SomeAdapter}}
  end

  test "get_positions calls the adapter without ephemeris options" do
    datetime = ~U[1990-05-24 06:30:00Z]

    expect(@spice_mock, :get_position, fn ^datetime, :sun ->
      {:ok, canned_body(:sun)}
    end)

    assert {:ok, %{sun: %Angelus.Astro.Body{}}} =
             Angelus.Astro.get_positions([:sun], datetime, @spice_mock)
  end

  test "get_positions with coordinates calls the adapter with observer coordinates" do
    datetime = ~U[1990-05-24 06:30:00Z]
    coordinates = {40.4, -3.7, 667}

    expect(@spice_mock, :get_position, fn ^datetime, :sun, ^coordinates ->
      {:ok, canned_body(:sun)}
    end)

    assert {:ok, %{sun: %Angelus.Astro.Body{}}} =
             Angelus.Astro.get_positions([:sun], datetime, coordinates, @spice_mock)
  end

  test "get_positions validates datetime before body list" do
    expect_no_adapter_call()

    assert Angelus.Astro.get_positions(:sun, ~N[1990-05-24 06:30:00], @spice_mock) ==
             {:error, :invalid_datetime}
  end

  test "get_positions validates list shape" do
    expect_no_adapter_call()

    assert Angelus.Astro.get_positions([], ~U[1990-05-24 06:30:00Z], @spice_mock) ==
             {:error, :empty_body_list}

    assert Angelus.Astro.get_positions(:sun, ~U[1990-05-24 06:30:00Z], @spice_mock) ==
             {:error, :invalid_body_list}

    assert Angelus.Astro.get_positions(["sun"], ~U[1990-05-24 06:30:00Z], @spice_mock) ==
             {:error, :invalid_body_list}
  end

  test "get_positions with coordinates validates coordinate shape" do
    expect_no_adapter_call(3)

    assert Angelus.Astro.get_positions(
             [:sun],
             ~U[1990-05-24 06:30:00Z],
             [40.4, -3.7, 667],
             @spice_mock
           ) ==
             {:error, :invalid_coordinates}

    assert Angelus.Astro.get_positions(
             [:sun],
             ~U[1990-05-24 06:30:00Z],
             {"40.4", -3.7, 667},
             @spice_mock
           ) ==
             {:error, :invalid_coordinates}
  end

  test "get_positions with coordinates validates latitude and longitude ranges" do
    expect_no_adapter_call(3)

    assert Angelus.Astro.get_positions(
             [:sun],
             ~U[1990-05-24 06:30:00Z],
             {91, -3.7, 667},
             @spice_mock
           ) ==
             {:error, {:latitude_out_of_range, 91}}

    assert Angelus.Astro.get_positions(
             [:sun],
             ~U[1990-05-24 06:30:00Z],
             {40.4, -181, 667},
             @spice_mock
           ) ==
             {:error, {:longitude_out_of_range, -181}}
  end

  test "get_positions rejects duplicates before adapter calls" do
    expect_no_adapter_call()

    assert Angelus.Astro.get_positions([:sun, :sun], ~U[1990-05-24 06:30:00Z], @spice_mock) ==
             {:error, {:duplicate_body, :sun}}
  end

  test "get_positions propagates unsupported bodies from the adapter" do
    expect(@spice_mock, :get_position, fn ~U[1990-05-24 06:30:00Z], :sun ->
      {:ok, canned_body(:sun)}
    end)

    expect(@spice_mock, :get_position, fn ~U[1990-05-24 06:30:00Z], :sedna ->
      {:error, {:unsupported_body, :sedna}}
    end)

    assert Angelus.Astro.get_positions([:sun, :sedna], ~U[1990-05-24 06:30:00Z], @spice_mock) ==
             {:error, {:unsupported_body, :sedna}}

    expect(@spice_mock, :get_position, fn ~U[2000-01-01 12:00:00Z], :mean_node ->
      {:error, {:unsupported_body, :mean_node}}
    end)

    assert Angelus.Astro.get_positions([:mean_node], ~U[2000-01-01 12:00:00Z], @spice_mock) ==
             {:error, {:unsupported_body, :mean_node}}
  end

  test "get_positions rejects out of range datetimes before native calls" do
    expect_no_adapter_call()

    assert Angelus.Astro.get_positions([:sun], ~U[1800-01-01 00:00:00Z], @spice_mock) ==
             {:error, {:datetime_out_of_range, %{from: ~D[1900-01-01], to: ~D[2100-01-24]}}}
  end

  test "get_positions propagates mock adapter errors" do
    datetime = ~U[2000-01-01 00:00:00Z]

    expect(@spice_mock, :get_position, fn ^datetime, :sun ->
      {:error, {:adapter_error, datetime}}
    end)

    assert Angelus.Astro.get_positions([:sun], datetime, @spice_mock) ==
             {:error, {:adapter_error, datetime}}
  end

  test "get_positions with coordinates propagates mock adapter errors" do
    datetime = ~U[2000-01-01 00:00:00Z]
    coordinates = {40.4, -3.7, 667}

    expect(@spice_mock, :get_position, fn ^datetime, :sun, ^coordinates ->
      {:error, {:adapter_error, datetime}}
    end)

    assert Angelus.Astro.get_positions([:sun], datetime, coordinates, @spice_mock) ==
             {:error, {:adapter_error, datetime}}
  end

  test "SPICE adapter marks topocentric positions as unsupported until native support exists" do
    assert Angelus.Astro.Adapters.Spice.get_position(
             ~U[1990-05-24 06:30:00Z],
             :sun,
             {40.4, -3.7, 667}
           ) == {:error, :topocentric_not_supported}
  end

  test "get_positions builds public body positions with the SPICE mock" do
    datetime = ~U[1990-05-24 06:30:00Z]

    expect(@spice_mock, :get_position, fn ^datetime, :sun ->
      {:ok, canned_body(:sun)}
    end)

    assert {:ok, %{sun: position}} =
             Angelus.Astro.get_positions([:sun], datetime, @spice_mock)

    assert %Angelus.Astro.Body{} = position
    assert position.body == :sun
    assert position.position_km == {-7.0e7, 1.2e8, 4.0e4}
    assert position.velocity_km_s == {-25.0, -14.0, 0.0}
    assert position.distance_au == 1.012
    assert position.metadata.adapter == @spice_mock
    assert position.metadata.engine == :spice
    assert position.metadata.observer == "EARTH"
    assert position.metadata.abcorr == "CN+S"
    assert position.metadata.frame_base == "ECLIPJ2000"
    assert position.metadata.ephemeris == :de442
    assert position.metadata.public_range == %{from: ~D[1900-01-01], to: ~D[2100-01-24]}
  end

  test "get_positions returns true_node as a mathematical point" do
    datetime = ~U[2000-01-01 12:00:00Z]

    expect(@spice_mock, :get_position, fn ^datetime, :true_node ->
      {:ok, canned_point(:true_node)}
    end)

    assert {:ok, %{true_node: position}} =
             Angelus.Astro.get_positions([:true_node], datetime, @spice_mock)

    assert %Angelus.Astro.Point{} = position
    assert position.point == :true_node
    assert position.longitude_rad == 1.2
    assert position.speed_rad_day == -0.01
    assert position.metadata.point == "TRUE_NODE"
  end

  test "get_positions returns lilith as a mathematical point" do
    datetime = ~U[2000-01-01 12:00:00Z]

    expect(@spice_mock, :get_position, fn ^datetime, :lilith ->
      {:ok, canned_point(:lilith)}
    end)

    assert {:ok, %{lilith: position}} =
             Angelus.Astro.get_positions([:lilith], datetime, @spice_mock)

    assert %Angelus.Astro.Point{} = position
    assert position.point == :lilith
    assert position.longitude_rad == 4.3
    assert position.speed_rad_day == -0.02
    assert position.metadata.point == "LILITH"
  end

  test "get_positions can request special ephemerides and chiron together" do
    datetime = ~U[2000-01-01 12:00:00Z]

    expect(@spice_mock, :get_position, 3, fn ^datetime, body ->
      case body do
        point when point in [:true_node, :lilith] -> {:ok, canned_point(point)}
        body -> {:ok, canned_body(body)}
      end
    end)

    assert {:ok, %{true_node: true_pos, lilith: lilith_pos, chiron: chiron_pos}} =
             Angelus.Astro.get_positions(
               [:true_node, :lilith, :chiron],
               datetime,
               @spice_mock
             )

    assert true_pos.point == :true_node
    assert lilith_pos.point == :lilith
    assert chiron_pos.body == :chiron
  end

  defp expect_no_adapter_call do
    expect(@spice_mock, :get_position, 0, fn _, _ ->
      flunk("adapter should not be called")
    end)
  end

  defp expect_no_adapter_call(3) do
    expect(@spice_mock, :get_position, 0, fn _, _, _ ->
      flunk("adapter should not be called")
    end)
  end

  defp canned_body(:sun) do
    %Angelus.Astro.Body{
      body: :sun,
      position_km: {-7.0e7, 1.2e8, 4.0e4},
      velocity_km_s: {-25.0, -14.0, 0.0},
      distance_au: 1.012,
      metadata: metadata(%{observer: "EARTH", abcorr: "CN+S", frame_base: "ECLIPJ2000"})
    }
  end

  defp canned_body(:chiron) do
    %Angelus.Astro.Body{
      body: :chiron,
      position_km: {1.7e9, -1.2e9, -2.0e8},
      velocity_km_s: {4.0, 7.1, 0.4},
      distance_au: 17.82,
      metadata: metadata(%{observer: "EARTH", abcorr: "CN+S", frame_base: "ECLIPJ2000"})
    }
  end

  defp canned_point(:true_node) do
    %Angelus.Astro.Point{
      point: :true_node,
      longitude_rad: 1.2,
      speed_rad_day: -0.01,
      et_seconds: 64.184,
      metadata: metadata(%{point: "TRUE_NODE"})
    }
  end

  defp canned_point(:lilith) do
    %Angelus.Astro.Point{
      point: :lilith,
      longitude_rad: 4.3,
      speed_rad_day: -0.02,
      et_seconds: 64.184,
      metadata: metadata(%{point: "LILITH"})
    }
  end

  defp metadata(extra) do
    %{
      engine: :spice,
      adapter: @spice_mock,
      ephemeris: :de442,
      kernel_policy: :default,
      public_range: %{from: ~D[1900-01-01], to: ~D[2100-01-24]},
      kernels: []
    }
    |> Map.merge(extra)
  end
end
