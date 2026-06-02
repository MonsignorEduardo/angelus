# Angelus

Angelus is an Elixir ephemeris library backed by NAIF CSPICE and JPL kernels.
It provides geocentric ecliptic positions for a small, explicit set of
astrological bodies while keeping kernel loading and native SPICE integration
visible to the caller.

The v0.1 scope is intentionally limited to ephemeris generation. Natal charts,
houses, aspects, orbs, dignities, transits, and other chart-level features are
out of scope for this release.

## Features

- Geocentric positions in the `ECLIPJ2000` frame.
- Ecliptic longitude, latitude, distance in AU, position vectors, velocity
  vectors, and light-time metadata.
- Default v0.1 JPL/NAIF kernel policy using DE442 and companion body-center
  kernels.
- Explicit runtime kernel loading; kernels are not loaded implicitly.
- Native SPICE worker distributed as precompiled release artefacts for supported platforms.

## Supported Bodies

Angelus v0.1 supports these public body atoms:

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
  :true_node,
  :lilith,
  :chiron,
  :ceres,
  :pallas,
  :juno,
  :vesta,
  :eris
]
```

The public datetime range is `1900-01-01` through `2100-01-24`, inclusive.

## Installation

Angelus is not yet published to Hex. Add it from Git while the package is under
development:

```elixir
def deps do
  [
    {:angelus, github: "MonsignorEduardo/angelus", tag: "v0.0.2"}
  ]
end
```

When published to Hex, the dependency will be:

```elixir
def deps do
  [
    {:angelus, "~> 0.0.2"}
  ]
end
```

## Requirements

- Elixir `~> 1.19`.
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

Install the single supported v0.1 kernel set:

```bash
mix angelus.kernels
```

This downloads the generic JPL/NAIF kernels and copies the bundled JPL Horizons
minor-planet SPKs into `priv/kernels/`. It does not load them at runtime.

Load kernels explicitly before calculating positions:

```elixir
{:ok, _metadata} = Angelus.load_kernels()

{:ok, positions} = Angelus.positions([:sun, :moon], ~U[1990-05-24 06:30:00Z])

positions.sun.longitude
positions.moon.distance_au
```

Pass `:rad` to return longitude and latitude in radians instead of degrees:

```elixir
{:ok, positions} =
  Angelus.positions([:sun, :moon], ~U[1990-05-24 06:30:00Z], [:rad])
```

Query one body at a time with `Angelus.position/3`:

```elixir
{:ok, sun} = Angelus.position(:sun, ~U[2000-01-01 12:00:00Z])

sun.longitude
```

Generate a CSV-style ephemeris for all supported bodies from the Mix task:

```bash
mix angelus.ephemeridde 1998-07-18T05:00:00Z
```

## Kernel Loading

`Angelus.load_kernels/0` loads the single supported kernel set from
`priv/kernels/`.

Use `:base_path` when kernels live somewhere else:

```elixir
Angelus.load_kernels(base_path: "/opt/angelus/kernels")
```

Use `:replace` to clear an already-loaded kernel set before loading another
one:

```elixir
Angelus.load_kernels(base_path: "/opt/angelus/kernels", replace: true)
```

You can also pass explicit absolute kernel paths:

```elixir
Angelus.load_kernels([
  "/opt/angelus/kernels/naif0012.tls",
  "/opt/angelus/kernels/pck00011.tpc",
  "/opt/angelus/kernels/gm_de440.tpc",
  "/opt/angelus/kernels/de442.bsp",
  "/opt/angelus/kernels/mar099.bsp",
  "/opt/angelus/kernels/jup349.bsp",
  "/opt/angelus/kernels/sat459.bsp",
  "/opt/angelus/kernels/ura184_part-1.bsp",
  "/opt/angelus/kernels/ura184_part-2.bsp",
  "/opt/angelus/kernels/ura184_part-3.bsp",
  "/opt/angelus/kernels/nep105.bsp",
  "/opt/angelus/kernels/plu060.bsp",
  "/opt/angelus/kernels/20002060.bsp",
  "/opt/angelus/kernels/20000001.bsp",
  "/opt/angelus/kernels/20000002.bsp",
  "/opt/angelus/kernels/20000003.bsp",
  "/opt/angelus/kernels/20000004.bsp",
  "/opt/angelus/kernels/20136199.bsp"
])
```

Explicit paths must form the exact supported v0.1 kernel set. See
`Angelus.Motor.default_kernel_files/0` for the filenames.

## Return Values

Position APIs return tagged tuples:

```elixir
{:ok, %Angelus.Ephemeris.BodyPosition{}}
{:ok, %{sun: %Angelus.Ephemeris.BodyPosition{}, moon: %Angelus.Ephemeris.BodyPosition{}}}
{:error, reason}
```

`Angelus.Ephemeris.BodyPosition` includes:

- `:longitude` - geocentric ecliptic longitude in degrees, normalized to
  `[0, 360)`.
- `:latitude` - geocentric ecliptic latitude in degrees.
- `:distance_au` - distance from Earth in astronomical units.
- `:position_km` and `:velocity_km_s` - SPICE state vectors.
- `:light_time_seconds` - one-way light travel time from target to observer.
- `:body`, `:spice_target`, `:spice_id`, and `:target_kind` - body catalog
  metadata.
- `:metadata` - engine, kernel, target, observer, frame, and version metadata.

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
just test-integration  # build with CSPICE and run e2e Horizons validation tests
just test-e2e          # alias for test-integration
just clean             # remove local build outputs and downloaded native libraries
```

Unit tests live under `test/unit` and run without CSPICE by using validation-only paths or `Angelus.CPortStub`. E2e tests live under `test/e2e` and require the real CSPICE worker, downloaded kernels, and a real JPL Horizons fixture at `test/fixtures/horizons/de442_positions.json`.

## Kernel and Data Licensing

Angelus does not include third-party astrological ephemeris code. Generic
JPL/NAIF kernels are downloaded separately. JPL Horizons minor-planet SPKs are
bundled as data resources. All kernels remain subject to their respective
terms.

The source code in this repository is MIT licensed. Native artefacts include
components from NAIF CSPICE, distributed under NAIF's respective terms.

Angelus is not affiliated with or endorsed by NASA, JPL, NAIF, IAU, or SOFA.
