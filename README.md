# Angelus

Angelus is an Elixir astrology library backed by CSPICE and JPL kernels.

The v0.1 scope is intentionally limited to ephemeris generation for Sun, Moon,
Mercury, Venus, Mars, Jupiter, Saturn, Uranus, Neptune, Pluto, True Node, Mean
Node, Chiron, and Lilith/Dark Moon (Lunar Apogee). Natal charts, houses,
aspects, orbs, and other chart-level features are out of scope for v0.1.

## Licensing

Angelus source code is MIT licensed. Native artefacts include components from NAIF CSPICE, distributed under its respective terms.

Angelus does not include third-party astrological ephemeris code or data. JPL/NAIF kernels are downloaded separately and distributed under their respective terms.

Angelus is not affiliated with or endorsed by NASA, JPL, NAIF, IAU, or SOFA.

## Basic Usage

Download the v0.1 data kernels:

```bash
mix angelus.kernels
```

This downloads data kernels only. It does not load them at runtime.

Load kernels explicitly before calculating positions:

```elixir
Angelus.Spice.load_kernels()
Angelus.Ephemeris.positions([:sun, :moon], ~U[1990-05-24 06:30:00Z])
```

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `angelus` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:angelus, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/angelus>.
