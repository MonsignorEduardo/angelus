defmodule Angelus.EphemerisTest do
  use ExUnit.Case, async: false
  import Mox

  setup :verify_on_exit!

  @spice_mock Angelus.Ephemeris.AdapterMock

  test "position accepts only an atom body" do
    assert Angelus.Ephemeris.position([:sun], ~U[1990-05-24 06:30:00Z], adapter: @spice_mock) ==
             {:error, :invalid_body}
  end

  test "positions validates unsupported options first" do
    expect_no_adapter_call()

    assert Angelus.Ephemeris.positions([:sun], ~U[1990-05-24 06:30:00Z],
             zodiac: :tropical,
             adapter: @spice_mock
           ) ==
             {:error, {:unsupported_option, {:zodiac, :tropical}}}

    assert Angelus.Ephemeris.positions([:sun], ~U[1990-05-24 06:30:00Z],
             zodiac: :sidereal,
             adapter: @spice_mock
           ) ==
             {:error, {:unsupported_option, {:zodiac, :sidereal}}}

    assert Angelus.Ephemeris.positions([:sun], ~U[1990-05-24 06:30:00Z],
             foo: :bar,
             adapter: @spice_mock
           ) ==
             {:error, {:unsupported_option, {:foo, :bar}}}
  end

  test "positions validates injected adapters" do
    assert Angelus.Ephemeris.positions([:sun], ~U[1990-05-24 06:30:00Z], adapter: SomeAdapter) ==
             {:error, {:invalid_adapter, SomeAdapter}}
  end

  test "positions validates datetime before body list" do
    expect_no_adapter_call()

    assert Angelus.Ephemeris.positions(:sun, ~N[1990-05-24 06:30:00], adapter: @spice_mock) ==
             {:error, :invalid_datetime}
  end

  test "positions validates list shape" do
    expect_no_adapter_call()

    assert Angelus.Ephemeris.positions([], ~U[1990-05-24 06:30:00Z], adapter: @spice_mock) ==
             {:error, :empty_body_list}

    assert Angelus.Ephemeris.positions(:sun, ~U[1990-05-24 06:30:00Z], adapter: @spice_mock) ==
             {:error, :invalid_body_list}

    assert Angelus.Ephemeris.positions(["sun"], ~U[1990-05-24 06:30:00Z], adapter: @spice_mock) ==
             {:error, :invalid_body_list}
  end

  test "positions rejects duplicates and unsupported bodies atomically" do
    expect_no_adapter_call()

    assert Angelus.Ephemeris.positions([:sun, :sun], ~U[1990-05-24 06:30:00Z],
             adapter: @spice_mock
           ) ==
             {:error, {:duplicate_body, :sun}}

    assert Angelus.Ephemeris.positions([:sun, :sedna], ~U[1990-05-24 06:30:00Z],
             adapter: @spice_mock
           ) ==
             {:error, {:unsupported_body, :sedna}}

    assert Angelus.Ephemeris.positions([:mean_node], ~U[2000-01-01 12:00:00Z],
             adapter: @spice_mock
           ) ==
             {:error, {:unsupported_body, :mean_node}}
  end

  test "positions rejects out of range datetimes before native calls" do
    expect_no_adapter_call()

    assert Angelus.Ephemeris.positions([:sun], ~U[1800-01-01 00:00:00Z], adapter: @spice_mock) ==
             {:error, {:datetime_out_of_range, %{from: ~D[1900-01-01], to: ~D[2100-01-24]}}}
  end

  test "positions propagates mock adapter errors" do
    datetime = ~U[2000-01-01 00:00:00Z]

    expect(@spice_mock, :get_ephemeride, fn ^datetime, :sun, opts ->
      assert Keyword.get(opts, :adapter) == @spice_mock
      {:error, {:adapter_error, datetime}}
    end)

    assert Angelus.Ephemeris.positions([:sun], datetime, adapter: @spice_mock) ==
             {:error, {:adapter_error, datetime}}
  end

  test "positions builds public body positions with the SPICE mock" do
    datetime = ~U[1990-05-24 06:30:00Z]

    expect(@spice_mock, :get_ephemeride, fn ^datetime, :sun, opts ->
      assert Keyword.get(opts, :adapter) == @spice_mock
      {:ok, canned_state(:sun)}
    end)

    assert {:ok, %{sun: position}} =
             Angelus.Ephemeris.positions([:sun], datetime, adapter: @spice_mock)

    assert %Angelus.Ephemeris.BodyPosition{} = position
    assert position.body == :sun
    assert position.spice_target == "SUN"
    assert position.spice_id == 10
    assert position.target_kind == :body_center
    assert position.longitude == 63.25
    assert position.latitude == 0.0002
    assert position.distance_au == 1.012
    assert position.metadata.adapter == @spice_mock
    assert position.metadata.engine == :spice
    assert position.metadata.ephemeris == :de442
    assert position.metadata.public_range == %{from: ~D[1900-01-01], to: ~D[2100-01-24]}
  end

  test "positions returns true_node with ecliptic longitude and zero latitude/distance" do
    datetime = ~U[2000-01-01 12:00:00Z]

    expect(@spice_mock, :get_ephemeride, fn ^datetime, :true_node, opts ->
      assert Keyword.get(opts, :adapter) == @spice_mock
      {:ok, canned_state(:true_node)}
    end)

    assert {:ok, %{true_node: position}} =
             Angelus.Ephemeris.positions([:true_node], datetime, adapter: @spice_mock)

    assert %Angelus.Ephemeris.BodyPosition{} = position
    assert position.body == :true_node
    assert position.spice_target == "TRUE_NODE"
    assert position.target_kind == :lunar_node
    assert position.latitude == 0.0
    assert position.distance_au == 0.0
    # True node at J2000.0 ≈ 125.08° (rounded stub value)
    assert_in_delta position.longitude, 125.08, 0.01
  end

  test "positions returns lilith with ecliptic longitude and zero latitude/distance" do
    datetime = ~U[2000-01-01 12:00:00Z]

    expect(@spice_mock, :get_ephemeride, fn ^datetime, :lilith, opts ->
      assert Keyword.get(opts, :adapter) == @spice_mock
      {:ok, canned_state(:lilith)}
    end)

    assert {:ok, %{lilith: position}} =
             Angelus.Ephemeris.positions([:lilith], datetime, adapter: @spice_mock)

    assert %Angelus.Ephemeris.BodyPosition{} = position
    assert position.body == :lilith
    assert position.spice_target == "LILITH"
    assert position.target_kind == :lunar_apogee
    assert position.latitude == 0.0
    assert position.distance_au == 0.0
    assert_in_delta position.longitude, 305.04, 0.01
  end

  test "positions can request special ephemerides and chiron together" do
    datetime = ~U[2000-01-01 12:00:00Z]

    expect(@spice_mock, :get_ephemeride, 3, fn ^datetime, body, opts ->
      assert Keyword.get(opts, :adapter) == @spice_mock
      {:ok, canned_state(body)}
    end)

    assert {:ok, %{true_node: true_pos, lilith: lilith_pos, chiron: chiron_pos}} =
             Angelus.Ephemeris.positions(
               [:true_node, :lilith, :chiron],
               datetime,
               adapter: @spice_mock
             )

    assert true_pos.target_kind == :lunar_node
    assert lilith_pos.target_kind == :lunar_apogee
    assert chiron_pos.target_kind == :minor_planet
  end

  defp expect_no_adapter_call do
    expect(@spice_mock, :get_ephemeride, 0, fn _, _, _ ->
      flunk("adapter should not be called")
    end)
  end

  defp canned_state(:sun) do
    %{
      spice_target: "SUN",
      spice_id: 10,
      target_kind: :body_center,
      position_km: {-7.0e7, 1.2e8, 4.0e4},
      velocity_km_s: {-25.0, -14.0, 0.0},
      light_time_seconds: 499.0,
      ecliptic_longitude: 63.25,
      ecliptic_latitude: 0.0002,
      distance_au: 1.012,
      kernel_metadata: kernel_metadata(),
      et: -302_378_400.0
    }
  end

  defp canned_state(:true_node) do
    %{
      spice_target: "TRUE_NODE",
      spice_id: nil,
      target_kind: :lunar_node,
      calculation: :true_lunar_node,
      position_km: {0.0, 0.0, 0.0},
      velocity_km_s: {0.0, 0.0, 0.0},
      light_time_seconds: 0.0,
      ecliptic_longitude: 125.08,
      ecliptic_latitude: 0.0,
      distance_au: 0.0,
      kernel_metadata: kernel_metadata(),
      et: 0.0
    }
  end

  defp canned_state(:lilith) do
    %{
      spice_target: "LILITH",
      spice_id: nil,
      target_kind: :lunar_apogee,
      calculation: :mean_lunar_apogee,
      position_km: {0.0, 0.0, 0.0},
      velocity_km_s: {0.0, 0.0, 0.0},
      light_time_seconds: 0.0,
      ecliptic_longitude: 305.04,
      ecliptic_latitude: 0.0,
      distance_au: 0.0,
      kernel_metadata: kernel_metadata(),
      et: 0.0
    }
  end

  defp canned_state(:chiron) do
    %{
      spice_target: "20002060",
      spice_id: 20_002_060,
      target_kind: :minor_planet,
      position_km: {1.7e9, -1.2e9, -2.0e8},
      velocity_km_s: {4.0, 7.1, 0.4},
      light_time_seconds: 8_900.0,
      ecliptic_longitude: 289.1,
      ecliptic_latitude: -6.6,
      distance_au: 17.82,
      kernel_metadata: kernel_metadata(),
      et: 0.0
    }
  end

  defp kernel_metadata do
    %{
      ephemeris: :de442,
      kernel_policy: :default,
      public_range: %{from: ~D[1900-01-01], to: ~D[2100-01-24]},
      kernels: []
    }
  end
end
