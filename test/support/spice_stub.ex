defmodule Angelus.CPortStub do
  @moduledoc """
  Stub adapter for `Angelus.Ephemeris` tests that do not require a compiled
  `priv/angelus_worker` binary or downloaded kernels.

  Usage in tests:

      Angelus.Ephemeris.positions([:sun], datetime, adapter: Angelus.CPortStub)

  The stub returns synthetic but structurally valid responses using canned
  data keyed by `{body, datetime}`.  Any unknown combination returns an error.
  """

  @behaviour Angelus.Ephemeris.Adapter

  @kernel_metadata %{
    ephemeris: :de442,
    kernel_policy: :default_modern,
    public_range: %{from: ~D[1900-01-01], to: ~D[2100-01-24]},
    kernels: []
  }

  # Canned ET values keyed by datetime
  @et_map %{
    ~U[1990-05-24 06:30:00Z] => -302_378_400.0,
    ~U[2000-01-01 12:00:00Z] => 0.0,
    ~U[2026-01-01 00:00:00Z] => 820_454_469.184,
    ~U[1900-06-01 00:00:00Z] => -3_155_630_400.0
  }

  # Canned state data keyed by {body, et}
  @state_map %{
    {:sun, -302_378_400.0} => %{
      spice_target: "SUN",
      spice_id: 10,
      target_kind: :body_center,
      position_km: {-7.0e7, 1.2e8, 4.0e4},
      velocity_km_s: {-25.0, -14.0, 0.0},
      light_time_seconds: 499.0,
      ecliptic_longitude: 63.25,
      ecliptic_latitude: 0.0002,
      distance_au: 1.012
    },
    {:moon, -302_378_400.0} => %{
      spice_target: "MOON",
      spice_id: 301,
      target_kind: :body_center,
      position_km: {3.2e5, -2.1e5, 1.0e4},
      velocity_km_s: {0.9, 0.9, 0.0},
      light_time_seconds: 1.3,
      ecliptic_longitude: 197.88,
      ecliptic_latitude: -3.1,
      distance_au: 0.002_572
    },
    {:jupiter, -302_378_400.0} => %{
      spice_target: "JUPITER",
      spice_id: 599,
      target_kind: :body_center,
      position_km: {5.2e8, 3.1e8, -1.2e7},
      velocity_km_s: {-7.4, 10.2, 0.2},
      light_time_seconds: 2_760.0,
      ecliptic_longitude: 102.1,
      ecliptic_latitude: 0.9,
      distance_au: 4.98
    },
    # Lunar node stubs at J2000.0 (ET = 0.0).
    # Mean node: eraFaom03(0) = 450160.398036 arcsec in (0, 1296000]
    # => 125.04455 degrees.
    # True node: mean node + nutation correction ≈ 125.08 degrees.
    # These values are rounded to the nearest 0.01° for stub purposes.
    {:mean_node, 0.0} => %{
      spice_target: nil,
      spice_id: nil,
      target_kind: :lunar_node,
      calculation: :mean_lunar_node,
      position_km: {0.0, 0.0, 0.0},
      velocity_km_s: {0.0, 0.0, 0.0},
      light_time_seconds: 0.0,
      ecliptic_longitude: 125.04,
      ecliptic_latitude: 0.0,
      distance_au: 0.0
    },
    {:true_node, 0.0} => %{
      spice_target: nil,
      spice_id: nil,
      target_kind: :lunar_node,
      calculation: :true_lunar_node,
      position_km: {0.0, 0.0, 0.0},
      velocity_km_s: {0.0, 0.0, 0.0},
      light_time_seconds: 0.0,
      ecliptic_longitude: 125.08,
      ecliptic_latitude: 0.0,
      distance_au: 0.0
    }
  }

  @impl true
  def get_ephemeride(%DateTime{} = datetime, body, opts) when is_list(opts) do
    case Map.fetch(@et_map, datetime) do
      {:ok, et} ->
        case Map.fetch(@state_map, {body, et}) do
          {:ok, data} ->
            data = Map.put(data, :kernel_metadata, @kernel_metadata)

            # Convert angles to radians when :rad present in opts
            data =
              if :rad in opts do
                Map.update!(data, :ecliptic_longitude, fn deg -> deg * :math.pi() / 180.0 end)
                |> Map.update!(:ecliptic_latitude, fn deg -> deg * :math.pi() / 180.0 end)
              else
                data
              end

            {:ok, Map.put(data, :et, et)}

          :error ->
            {:error, {:stub_unknown_state, {body, et}}}
        end

      :error ->
        {:error, {:stub_unknown_datetime, datetime}}
    end
  end
end
