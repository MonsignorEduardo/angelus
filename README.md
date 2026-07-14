# Angelus [![Hex Version](https://img.shields.io/hexpm/v/angelus.svg)](https://hex.pm/packages/angelus) [![Hex Docs](https://img.shields.io/badge/docs-hexpm-blue.svg)](https://angelus.hexdocs.pm/readme.html)

Angelus is an Elixir library that returns one geocentric tropical ephemeris for
a supplied instant. Its only public API is `Angelus.get_ephemeride/1`.

## Supported Bodies

Angelus 1.0.0 returns these body atoms in a fixed order:

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
  :north_node,
  :south_node,
  :lilith,
  :chiron
]
```

The public datetime range is `1900-01-01` through `2100-01-24`, inclusive.

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

ephemeride.sidereal_time
ephemeride.positions
```

Each result includes the UTC instant, weekday, Greenwich sidereal time, and
the positions in this fixed order. Every position contains ecliptic latitude
(`lat`), true-equatorial declination (`decl`), and direct/retrograde/stationary
motion. All angular values are expressed in degrees; Angelus does not expose
zodiac signs or formatted ecliptic longitudes.
`ephemeride.reference` identifies Earth as the geocentric observer and supplies
the PCK ellipsoid radii in km, flattening, coordinate frame, and aberration
correction used by the calculation.

Print the same result in a terminal with an ISO 8601 instant:

```bash
mix angelus.ephemeride 2000-01-01T07:00:00-05:00
```

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
