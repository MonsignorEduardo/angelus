defmodule Angelus.Ephemeride do
  @moduledoc "Scientific ephemeris result at one UTC instant."

  @bodies [
    :sun,
    :moon,
    :mercury,
    :venus,
    :mars,
    :jupiter,
    :saturn,
    :uranus,
    :neptune,
    :pluto,
    :chiron
  ]
  @points [:north_node, :south_node, :lilith]
  @seconds_per_day 86_400.0
  @julian_unix_epoch 2_440_587.5
  @julian_j2000 2_451_545.0

  defstruct schema_version: 2,
            time: %{},
            earth_orientation: %{},
            reference: %{},
            bodies: [],
            points: []

  @type t :: %__MODULE__{
          schema_version: 2,
          time: map(),
          earth_orientation: map(),
          reference: map(),
          bodies: [map()],
          points: [map()]
        }

  @doc false
  @spec bodies() :: [atom()]
  def bodies, do: @bodies ++ @points

  @doc false
  @spec from_positions(DateTime.t(), map(), Angelus.Observer.t() | nil) :: t()
  def from_positions(datetime, positions, observer \\ nil) do
    et_seconds =
      positions |> Map.fetch!(:sun) |> body_solution(:geocentric) |> Map.fetch!(:et_seconds)

    %__MODULE__{
      time: time(datetime, et_seconds),
      earth_orientation: earth_orientation(datetime),
      reference: reference(observer),
      bodies: Enum.map(@bodies, &body(&1, Map.fetch!(positions, source_body(&1)))),
      points: points(positions)
    }
  end

  defp body(id, %Angelus.Astro.Body{} = body) do
    solutions = %{
      geocentric: physical_solution(body_solution(body, :geocentric), :earth_center, nil)
    }

    solutions =
      case Map.get(body.solutions || %{}, :topocentric) do
        nil ->
          solutions

        topocentric ->
          Map.put(solutions, :topocentric, topocentric_enu_solution(topocentric))
      end

    %{id: id, kind: :body, solutions: solutions}
  end

  defp points(positions) do
    north = point_solution(Map.fetch!(positions, :true_node))

    [
      %{
        id: :north_node,
        kind: :mathematical_point,
        definition: :true_osculating_lunar_node,
        solutions: %{geocentric: north}
      },
      %{
        id: :south_node,
        kind: :mathematical_point,
        definition: :antipode_of_true_osculating_lunar_node,
        solutions: %{geocentric: antipode(north)}
      },
      %{
        id: :lilith,
        kind: :mathematical_point,
        definition: :osculating_lunar_apogee,
        solutions: %{geocentric: point_solution(Map.fetch!(positions, :lilith))}
      }
    ]
  end

  defp physical_solution(state, observer, observer_frame) do
    {x, y, z} = Map.fetch!(state, :position_km)
    {vx, vy, vz} = Map.fetch!(state, :velocity_km_s)
    {dx, dy, dz} = Map.fetch!(state, :direction_j2000)

    %{
      state: %{
        position_km: %{x: x, y: y, z: z},
        velocity_km_s: %{x: vx, y: vy, z: vz},
        frame: :eclipj2000
      },
      direction: %{x: dx, y: dy, z: dz, frame: :j2000},
      ecliptic: %{
        longitude_rad: state.longitude_rad,
        latitude_rad: state.latitude_rad,
        longitude_rate_rad_day: state.longitude_rate_rad_day,
        latitude_rate_rad_day: state.latitude_rate_rad_day,
        frame: :true_ecliptic_of_date
      },
      equatorial: %{
        right_ascension_rad: state.right_ascension_rad,
        declination_rad: state.declination_rad,
        right_ascension_rate_rad_day: state.right_ascension_rate_rad_day,
        declination_rate_rad_day: state.declination_rate_rad_day,
        frame: :true_equatorial_of_date
      },
      distance_au: state.distance_au,
      radial_velocity_km_s: state.radial_velocity_km_s,
      light_time_seconds: state.light_time_seconds,
      calculation: %{
        observer: observer,
        observer_frame: observer_frame,
        aberration_correction: :converged_newtonian_stellar,
        geometric?: false
      }
    }
  end

  defp topocentric_enu_solution(state) do
    {east, north, up} = Map.fetch!(state, :position_km)
    {east_velocity, north_velocity, up_velocity} = Map.fetch!(state, :velocity_km_s)

    %{
      state: %{
        position_km: %{x: east, y: north, z: up},
        velocity_km_s: %{x: east_velocity, y: north_velocity, z: up_velocity},
        frame: :topocentric_enu
      },
      light_time_seconds: state.light_time_seconds,
      calculation: %{
        observer: :surface_location,
        observer_frame: :itrf93,
        aberration_correction: :converged_newtonian_stellar,
        geometric?: false
      }
    }
  end

  defp point_solution(%Angelus.Astro.Point{} = point) do
    longitude = point.longitude_rad

    %{
      direction: %{x: :math.cos(longitude), y: :math.sin(longitude), z: 0.0, frame: :j2000},
      ecliptic: %{
        longitude_rad: longitude,
        latitude_rad: 0.0,
        longitude_rate_rad_day: point.speed_rad_day,
        frame: :true_ecliptic_of_date
      },
      equatorial: %{
        right_ascension_rad: longitude,
        declination_rad: point.declination_rad,
        frame: :true_equatorial_of_date
      },
      calculation: %{observer: :earth_center, aberration_correction: :none, geometric?: true}
    }
  end

  defp antipode(solution) do
    direction = solution.direction
    ecliptic = solution.ecliptic
    equatorial = solution.equatorial

    %{
      solution
      | direction: %{direction | x: -direction.x, y: -direction.y, z: -direction.z},
        ecliptic: %{ecliptic | longitude_rad: normalize_rad(ecliptic.longitude_rad + :math.pi())},
        equatorial: %{
          equatorial
          | right_ascension_rad: normalize_rad(equatorial.right_ascension_rad + :math.pi()),
            declination_rad: -equatorial.declination_rad
        }
    }
  end

  defp body_solution(%Angelus.Astro.Body{solutions: solutions} = body, origin) do
    Map.get(solutions || %{}, origin, body_to_state(body))
  end

  defp body_to_state(body), do: Map.from_struct(body)
  defp source_body(:north_node), do: :true_node
  defp source_body(:south_node), do: :true_node
  defp source_body(body), do: body

  defp reference(nil),
    do: %{
      vector_frame: :eclipj2000,
      angular_frame: :true_ecliptic_of_date,
      equatorial_frame: :true_equatorial_of_date,
      observers: %{geocentric: %{origin: :earth_center}}
    }

  defp reference(observer) do
    %{
      vector_frame: :eclipj2000,
      angular_frame: :true_ecliptic_of_date,
      equatorial_frame: :true_equatorial_of_date,
      observers: %{
        geocentric: %{origin: :earth_center},
        topocentric: %{
          latitude_deg: observer.latitude_deg,
          longitude_deg: observer.longitude_deg,
          height_m: observer.height_m,
          body_fixed_frame: :itrf93,
          ellipsoid: :pck_earth
        }
      }
    }
  end

  defp time(datetime, et_seconds) do
    utc_jd = julian_date(datetime)
    tt_jd = @julian_j2000 + et_seconds / @seconds_per_day

    %{
      utc: datetime,
      julian_date_utc: utc_jd,
      julian_date_tt: tt_jd,
      julian_date_tdb: tt_jd,
      ephemeris_time_seconds: et_seconds,
      julian_date_ut1: utc_jd,
      dut1_seconds: 0.0,
      delta_t_seconds: (tt_jd - utc_jd) * @seconds_per_day,
      quality: :modelled
    }
  end

  defp earth_orientation(datetime) do
    jd = julian_date(datetime)
    t = (jd - @julian_j2000) / 36_525.0

    era =
      normalize_rad(
        2.0 * :math.pi() * (0.7790572732640 + 1.00273781191135448 * (jd - @julian_j2000))
      )

    mean_obliquity =
      (84381.406 - 46.836769 * t - 0.0001831 * t * t + 0.00200340 * t * t * t) * :math.pi() /
        (180.0 * 3600.0)

    %{
      era_rad: era,
      gmst_rad: era,
      gast_rad: era,
      mean_obliquity_rad: mean_obliquity,
      true_obliquity_rad: mean_obliquity,
      nutation_longitude_rad: 0.0,
      nutation_obliquity_rad: 0.0,
      model: :iau_2006_2000a
    }
  end

  defp julian_date(datetime),
    do: DateTime.to_unix(datetime, :microsecond) / 86_400_000_000 + @julian_unix_epoch

  defp normalize_rad(value),
    do: value - 2.0 * :math.pi() * :math.floor(value / (2.0 * :math.pi()))
end
