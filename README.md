# Angelus [![Hex Version](https://img.shields.io/hexpm/v/angelus.svg)](https://hex.pm/packages/angelus) [![Hex Docs](https://img.shields.io/badge/docs-hexpm-blue.svg)](https://angelus.hexdocs.pm/readme.html)

Angelus is an Elixir library backed by NAIF CSPICE/JPL kernels. It returns a
scientific tropical ephemeris with an always-present geocentric solution and,
when requested, a separate topocentric solution for a terrestrial observer.

## Supported Bodies

The physical bodies are returned in `ephemeride.bodies`:

```elixir
[
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
```

`ephemeride.points` contains `:north_node`, `:south_node`, and `:lilith` as
geocentric mathematical constructions. They never receive a fabricated
topocentric distance or Cartesian state.

The public datetime range is `1900-01-01` through `2100-01-24`, inclusive.
Topocentric calculations additionally require loaded `ITRF93` Earth-orientation
data. The bundled Earth binary PCK starts in 1962, so topocentric requests
before its actual coverage return an explicit error; Angelus never falls back
silently to `IAU_EARTH`.

## Installation

Angelus is not yet published to Hex. Add it from Git:

```elixir
def deps do
  [
    {:angelus, github: "MonsignorEduardo/angelus", branch: "master"}
  ]
end
```

## Requirements

- Elixir `~> 1.20.2` on Erlang/OTP `29.0.3`.
- For supported platforms, no local C compiler or CSPICE installation is required when installing from Hex.
- Local source builds require a C compiler available as `cc`, plus Meson, Ninja,
  and the native dependencies used by the Meson subprojects.

Precompiled CSPICE-enabled native workers are provided for macOS Apple Silicon
(`aarch64-apple-darwin`), Linux glibc x86_64 (`x86_64-linux-gnu`), and Linux
glibc arm64 (`aarch64-linux-gnu`).

## Quick Start

Fetch dependencies and compile the native worker:

```bash
mix deps.get
mix compile
```

When installed from Hex on one of those supported platforms, compilation downloads the matching precompiled `angelus_worker`. Local development in this repository can force a source build with `ANGELUS_FORCE_BUILD=1` or `just build`.

Install the complete Angelus runtime data:

```bash
mix angelus.prepare
```

This downloads the JPL/NAIF kernels and the pinned Quirón SPK into
`priv/kernels/`. The pinned SPK is verified against its catalogued SHA-256
checksum.

Calculate an ephemeris. Kernels load automatically on the first call:

```elixir
{:ok, ephemeride} = Angelus.get_ephemeride(~U[1990-05-24 06:30:00Z])

ephemeride.schema_version
# => 2

ephemeride.time.utc
ephemeride.bodies
```

Each physical entry has `solutions.geocentric`. A solution declares its
Cartesian state in km and km/s (`ECLIPJ2000`), normalized direction (`J2000`),
true ecliptic and equatorial coordinates of date, instantaneous angular rates,
distance in AU, radial velocity, light time, observer, and aberration
correction. Angles and rates are radians and radians/day unless a field states
otherwise.

### Topocentric observer

Pass geodetic latitude, east-positive longitude, and ellipsoidal height in
meters to obtain both solutions for every physical body:

```elixir
{:ok, ephemeride} =
  Angelus.get_ephemeride(
    ~U[1990-05-24 06:30:00Z],
    observer: [
      latitude_deg: 40.4168,
      longitude_deg: -3.7038,
      height_m: 667.0
    ]
  )

ephemeride.bodies |> hd() |> Map.fetch!(:solutions)
# => %{geocentric: ..., topocentric: ...}
```

All three observer fields are required. Latitude is limited to `[-90, 90]`,
longitude to `[-180, 180]`, and height to `[-500, 100000]` meters. Longitude
`180` is normalized to `-180`.

## Result Schema

Every response has `schema_version: 2`. This is the complete shape when an
observer is supplied. Numeric values below are illustrative.

```elixir
%Angelus.Ephemeride{
  schema_version: 2,
  time: %{
    utc: ~U[2000-01-01 12:00:00Z],
    julian_date_utc: 2_451_545.0,
    julian_date_tt: 2_451_545.000_742_9,
    julian_date_tdb: 2_451_545.000_742_9,
    ephemeris_time_seconds: 64.183927,
    julian_date_ut1: 2_451_545.0,
    dut1_seconds: 0.0,
    delta_t_seconds: 64.183921,
    quality: :modelled
  },
  earth_orientation: %{
    era_rad: 4.894961,
    gmst_rad: 4.894961,
    gast_rad: 4.894961,
    mean_obliquity_rad: 0.409093,
    true_obliquity_rad: 0.409093,
    nutation_longitude_rad: 0.0,
    nutation_obliquity_rad: 0.0,
    model: :iau_2006_2000a
  },
  reference: %{
    vector_frame: :eclipj2000,
    angular_frame: :true_ecliptic_of_date,
    equatorial_frame: :true_equatorial_of_date,
    observers: %{
      geocentric: %{origin: :earth_center},
      topocentric: %{
        latitude_deg: 40.4168,
        longitude_deg: -3.7038,
        height_m: 667.0,
        body_fixed_frame: :itrf93,
        ellipsoid: :pck_earth
      }
    }
  },
  bodies: [
    %{
      id: :moon,
      kind: :body,
      solutions: %{
        geocentric: %{
          state: %{
            position_km: %{x: -291_543.31, y: -275_002.44, z: 36_267.41},
            velocity_km_s: %{x: 0.6436, y: -0.7308, z: -0.0115},
            frame: :eclipj2000
          },
          direction: %{x: -0.7245, y: -0.6628, z: -0.1891, frame: :j2000},
          ecliptic: %{
            longitude_rad: 3.897736,
            latitude_rad: 0.090246,
            longitude_rate_rad_day: 0.209812,
            latitude_rate_rad_day: -0.003107,
            frame: :true_ecliptic_of_date
          },
          equatorial: %{
            right_ascension_rad: 3.882524,
            declination_rad: -0.190252,
            right_ascension_rate_rad_day: 0.202416,
            declination_rate_rad_day: -0.064544,
            frame: :true_equatorial_of_date
          },
          distance_au: 0.002690,
          radial_velocity_km_s: 0.032164,
          light_time_seconds: 1.342318,
          calculation: %{
            observer: :earth_center,
            observer_frame: nil,
            aberration_correction: :converged_newtonian_stellar,
            geometric?: false
          }
        },
        topocentric: %{
          state: %{
            position_km: %{x: -289_000.0, y: -277_000.0, z: 35_000.0},
            velocity_km_s: %{x: 0.60, y: -0.90, z: -0.01},
            frame: :eclipj2000
          },
          direction: %{x: -0.72, y: -0.66, z: -0.20, frame: :j2000},
          ecliptic: %{
            longitude_rad: 3.891664,
            latitude_rad: 0.076419,
            longitude_rate_rad_day: 0.164745,
            latitude_rate_rad_day: -0.003,
            frame: :true_ecliptic_of_date
          },
          equatorial: %{
            right_ascension_rad: 3.872472,
            declination_rad: -0.201669,
            right_ascension_rate_rad_day: 0.158,
            declination_rate_rad_day: -0.07,
            frame: :true_equatorial_of_date
          },
          distance_au: 0.002677,
          radial_velocity_km_s: 0.310626,
          light_time_seconds: 1.335,
          calculation: %{
            observer: :surface_location,
            observer_frame: :itrf93,
            aberration_correction: :converged_newtonian_stellar,
            geometric?: false
          }
        }
      }
    }
  ],
  points: [
    %{
      id: :north_node,
      kind: :mathematical_point,
      definition: :true_osculating_lunar_node,
      solutions: %{
        geocentric: %{
          direction: %{x: -0.56, y: 0.83, z: 0.0, frame: :j2000},
          ecliptic: %{
            longitude_rad: 2.1634,
            latitude_rad: 0.0,
            longitude_rate_rad_day: -0.00095,
            frame: :true_ecliptic_of_date
          },
          equatorial: %{
            right_ascension_rad: 2.1634,
            declination_rad: 0.3362,
            frame: :true_equatorial_of_date
          },
          calculation: %{
            observer: :earth_center,
            aberration_correction: :none,
            geometric?: true
          }
        }
      }
    }
  ]
}
```

Without `observer:`, `reference.observers` has only `:geocentric` and every
physical body's `solutions` map has only `:geocentric`. `:north_node`,
`:south_node`, and `:lilith` always have only a geocentric solution.

Print the same result in a terminal with an ISO 8601 instant:

```bash
mix angelus.ephemeride 2000-01-01T07:00:00-05:00
```

Pass an observer to print physical bodies topocentrically while preserving the
geocentric mathematical points:

```bash
mix angelus.ephemeride 2000-01-01T07:00:00-05:00 \
  --latitude 40.4168 \
  --longitude -3.7038 \
  --height 667
```

The CLI prints ecliptic longitude/latitude, right ascension, declination,
longitude rate, distance, and radial velocity.

## Development

Common commands:

```bash
mix setup
mix compile
mix test test/unit
mix consistency
```

By default, `mix compile` may use a published precompiled worker. To force a local source build while working on this repository:

```bash
ANGELUS_FORCE_BUILD=1 mix compile
```

If you have `just` installed, the repository also provides:

```bash
just build             # compile with CSPICE support
just build-stub        # compile stub worker only, no CSPICE download
just test              # run test/unit only
just test-integration  # build with CSPICE and run e2e tests
just test-e2e          # alias for test-integration
just clean             # remove local build outputs and downloaded native libraries
```

Unit tests live under `test/unit`. Integration tests require the real CSPICE
worker and downloaded kernels.

## Kernel and Data Licensing

Angelus does not include third-party ephemeris data. JPL/NAIF kernels and the
Quirón SPK are downloaded separately and remain subject to their respective terms.

The source code in this repository is MIT licensed. Native artefacts include
components from NAIF CSPICE, distributed under NAIF's respective terms.

Angelus is not affiliated with or endorsed by NASA, JPL, NAIF, IAU, or SOFA.
