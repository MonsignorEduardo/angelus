defmodule Angelus.EphemerisTest do
  use ExUnit.Case, async: false

  @spice_mock Angelus.SpiceStub

  test "position accepts only an atom body" do
    assert Angelus.Ephemeris.position([:sun], ~U[1990-05-24 06:30:00Z], adapter: @spice_mock) ==
             {:error, :invalid_body}
  end

  test "positions validates unsupported options first" do
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
    assert Angelus.Ephemeris.positions(:sun, ~N[1990-05-24 06:30:00], adapter: @spice_mock) ==
             {:error, :invalid_datetime}
  end

  test "positions validates list shape" do
    assert Angelus.Ephemeris.positions([], ~U[1990-05-24 06:30:00Z], adapter: @spice_mock) ==
             {:error, :empty_body_list}

    assert Angelus.Ephemeris.positions(:sun, ~U[1990-05-24 06:30:00Z], adapter: @spice_mock) ==
             {:error, :invalid_body_list}

    assert Angelus.Ephemeris.positions(["sun"], ~U[1990-05-24 06:30:00Z], adapter: @spice_mock) ==
             {:error, :invalid_body_list}
  end

  test "positions rejects duplicates and unsupported bodies atomically" do
    assert Angelus.Ephemeris.positions([:sun, :sun], ~U[1990-05-24 06:30:00Z],
             adapter: @spice_mock
           ) ==
             {:error, {:duplicate_body, :sun}}

    assert Angelus.Ephemeris.positions([:sun, :ceres], ~U[1990-05-24 06:30:00Z],
             adapter: @spice_mock
           ) ==
             {:error, {:unsupported_body, :ceres}}
  end

  test "positions rejects out of range datetimes before native calls" do
    assert Angelus.Ephemeris.positions([:sun], ~U[1800-01-01 00:00:00Z], adapter: @spice_mock) ==
             {:error, {:datetime_out_of_range, %{from: ~D[1900-01-01], to: ~D[2100-01-24]}}}
  end

  test "positions propagates mock adapter errors" do
    assert Angelus.Ephemeris.positions([:sun], ~U[2000-01-01 00:00:00Z], adapter: @spice_mock) ==
             {:error, {:stub_unknown_datetime, ~U[2000-01-01 00:00:00Z]}}
  end

  test "positions builds public body positions with the SPICE mock" do
    assert {:ok, %{sun: position}} =
             Angelus.Ephemeris.positions([:sun], ~U[1990-05-24 06:30:00Z], adapter: @spice_mock)

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
end
