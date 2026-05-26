defmodule Angelus.EphemerisTest do
  use ExUnit.Case, async: false

  defmodule FakeAdapter do
    @behaviour Angelus.Ephemeris.Adapter

    @impl true
    def utc_to_et(~U[1990-05-24 06:30:00Z]), do: {:ok, -302_378_400.0}

    @impl true
    def state(:sun, -302_378_400.0) do
      {:ok,
       %{
         spice_target: "SUN",
         spice_id: 10,
         target_kind: :body_center,
         position_km: [1.0, 2.0, 3.0],
         velocity_km_s: [0.1, 0.2, 0.3],
         light_time_seconds: 499.0,
         ecliptic_longitude: 63.25,
         ecliptic_latitude: 0.01,
         distance_au: 1.0,
         kernel_metadata: %{
           ephemeris: :de442,
           kernel_policy: :default_modern,
           public_range: %{from: ~D[1900-01-01], to: ~D[2100-01-24]},
           kernels: []
         }
       }}
    end
  end

  test "position accepts only an atom body" do
    assert Angelus.Ephemeris.position([:sun], ~U[1990-05-24 06:30:00Z]) == {:error, :invalid_body}
  end

  test "positions validates unsupported options first" do
    assert Angelus.Ephemeris.positions([:sun], ~U[1990-05-24 06:30:00Z], zodiac: :tropical) ==
             {:error, {:unsupported_option, {:zodiac, :tropical}}}

    assert Angelus.Ephemeris.positions([:sun], ~U[1990-05-24 06:30:00Z], zodiac: :sidereal) ==
             {:error, {:unsupported_option, {:zodiac, :sidereal}}}

    assert Angelus.Ephemeris.positions([:sun], ~U[1990-05-24 06:30:00Z], foo: :bar) ==
             {:error, {:unsupported_option, {:foo, :bar}}}
  end

  test "positions validates injected adapters" do
    assert Angelus.Ephemeris.positions([:sun], ~U[1990-05-24 06:30:00Z], adapter: SomeAdapter) ==
             {:error, {:invalid_adapter, SomeAdapter}}
  end

  test "positions validates datetime before body list" do
    assert Angelus.Ephemeris.positions(:sun, ~N[1990-05-24 06:30:00]) ==
             {:error, :invalid_datetime}
  end

  test "positions validates list shape" do
    assert Angelus.Ephemeris.positions([], ~U[1990-05-24 06:30:00Z]) == {:error, :empty_body_list}

    assert Angelus.Ephemeris.positions(:sun, ~U[1990-05-24 06:30:00Z]) ==
             {:error, :invalid_body_list}

    assert Angelus.Ephemeris.positions(["sun"], ~U[1990-05-24 06:30:00Z]) ==
             {:error, :invalid_body_list}
  end

  test "positions rejects duplicates and unsupported bodies atomically" do
    assert Angelus.Ephemeris.positions([:sun, :sun], ~U[1990-05-24 06:30:00Z]) ==
             {:error, {:duplicate_body, :sun}}

    assert Angelus.Ephemeris.positions([:sun, :ceres], ~U[1990-05-24 06:30:00Z]) ==
             {:error, {:unsupported_body, :ceres}}
  end

  test "positions rejects out of range datetimes before native calls" do
    assert Angelus.Ephemeris.positions([:sun], ~U[1800-01-01 00:00:00Z]) ==
             {:error, {:datetime_out_of_range, %{from: ~D[1900-01-01], to: ~D[2100-01-24]}}}
  end

  test "positions requires kernels for valid requests" do
    assert Angelus.Ephemeris.positions([:sun], ~U[1990-05-24 06:30:00Z]) ==
             {:error, :kernels_not_loaded}
  end

  test "positions builds public body positions with an injected adapter" do
    assert {:ok, %{sun: position}} =
             Angelus.Ephemeris.positions([:sun], ~U[1990-05-24 06:30:00Z], adapter: FakeAdapter)

    assert %Angelus.Ephemeris.BodyPosition{} = position
    assert position.body == :sun
    assert position.spice_target == "SUN"
    assert position.spice_id == 10
    assert position.target_kind == :body_center
    assert position.longitude == 63.25
    assert position.latitude == 0.01
    assert position.distance_au == 1.0
    assert position.metadata.adapter == FakeAdapter
    assert position.metadata.engine == :spice
    assert position.metadata.ephemeris == :de442
    assert position.metadata.public_range == %{from: ~D[1900-01-01], to: ~D[2100-01-24]}
  end
end
