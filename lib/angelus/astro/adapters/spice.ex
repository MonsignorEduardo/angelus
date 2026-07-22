defmodule Angelus.Astro.Adapters.Spice do
  @moduledoc false

  @behaviour Angelus.Astro.Adapter

  alias Angelus.Astro.Body
  alias Angelus.Astro.Catalog
  alias Angelus.Astro.Point

  @range_from ~D[1900-01-01]
  @range_to ~D[2100-01-24]

  @doc "Returns a public ephemeris result for a UTC datetime."
  @impl true
  @spec get_position(DateTime.t(), atom()) ::
          {:ok, Body.t() | Point.t()} | {:error, term()}
  def get_position(%DateTime{} = utc, target), do: get_position(utc, target, nil)

  @impl true
  @spec get_position(DateTime.t(), atom(), Angelus.Observer.t() | nil) ::
          {:ok, Body.t() | Point.t()} | {:error, term()}
  def get_position(%DateTime{} = utc, target, observer) do
    with {:ok, metadata} <- Catalog.get_metadata(target) do
      case metadata.target_kind do
        kind when kind in [:body_center, :minor_planet] ->
          fetch_body(utc, target, metadata, observer)

        kind when kind in [:lunar_node, :lunar_apogee] ->
          fetch_point(utc, target, metadata)
      end
    end
  end

  defp fetch_body(utc, body, target, observer) do
    with {:ok, state} <- Angelus.Motor.get_body(target.spice_target, utc, observer) do
      {:ok, build_body(body, state)}
    end
  end

  defp fetch_point(utc, point, target) do
    with {:ok, state} <- Angelus.Motor.get_math_point(target.spice_target, utc) do
      {:ok, build_point(point, state)}
    end
  end

  defp build_body(body, state) do
    geocentric = Map.get(state, :geocentric, state)

    solutions =
      if Map.has_key?(state, :geocentric),
        do: Map.take(state, [:geocentric, :topocentric]),
        else: %{geocentric: geocentric}

    %Body{
      body: body,
      position_km: Map.get(geocentric, :position_km),
      velocity_km_s: Map.get(geocentric, :velocity_km_s),
      distance_au: Map.get(geocentric, :distance_au),
      light_time_seconds: Map.get(geocentric, :light_time_seconds),
      et_seconds: Map.get(geocentric, :et_seconds),
      longitude: Map.get(geocentric, :longitude),
      latitude: Map.get(geocentric, :latitude),
      longitude_rad: Map.get(geocentric, :longitude_rad),
      latitude_rad: Map.get(geocentric, :latitude_rad),
      declination: Map.get(geocentric, :declination),
      declination_rad: Map.get(geocentric, :declination_rad),
      right_ascension_rad: Map.get(geocentric, :right_ascension_rad),
      longitude_rate_rad_day: Map.get(geocentric, :longitude_rate_rad_day),
      latitude_rate_rad_day: Map.get(geocentric, :latitude_rate_rad_day),
      right_ascension_rate_rad_day: Map.get(geocentric, :right_ascension_rate_rad_day),
      declination_rate_rad_day: Map.get(geocentric, :declination_rate_rad_day),
      direction_j2000: Map.get(geocentric, :direction_j2000),
      radial_velocity_km_s: Map.get(geocentric, :radial_velocity_km_s),
      solutions: solutions,
      metadata: metadata(geocentric)
    }
  end

  defp build_point(point, state) do
    %Point{
      point: point,
      longitude_rad: Map.get(state, :longitude_rad),
      declination: Map.get(state, :declination),
      declination_rad: Map.get(state, :declination_rad),
      speed_rad_day: Map.get(state, :speed_rad_day),
      et_seconds: Map.get(state, :et_seconds),
      metadata: metadata(state)
    }
  end

  defp metadata(state) do
    kernel_metadata = Map.get(state, :kernel_metadata) || %{}

    %{
      engine: :spice,
      adapter: __MODULE__,
      ephemeris: Map.get(kernel_metadata, :ephemeris),
      kernel_policy: Map.get(kernel_metadata, :kernel_policy),
      kernels: Map.get(kernel_metadata, :kernels),
      public_range: Map.get(kernel_metadata, :public_range, %{from: @range_from, to: @range_to}),
      observer: Map.get(state, :observer),
      state: Map.get(state, :state),
      origin: Map.get(state, :origin, Map.get(state, :state)),
      abcorr: Map.get(state, :abcorr),
      frame_base: Map.get(state, :frame_base),
      coordinate_frame: Map.get(state, :coordinate_frame),
      point: Map.get(state, :point),
      angelus_version: Mix.Project.config()[:version]
    }
  end
end
