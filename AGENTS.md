# AGENTS.md

## Project Shape

- Angelus is an Elixir `~> 1.20.2` library backed by a native C `angelus_worker` port for NAIF CSPICE/JPL ephemerides.
- Public APIs are `Angelus.get_ephemeride/1` and `Angelus.get_ephemeride/2`. The latter accepts kernel options and an optional, strictly validated `observer:` keyword list. The result model is `lib/angelus/ephemeride.ex`; internal SPICE access is in `lib/angelus/astro.ex`, `lib/angelus/motor.ex`, and `lib/angelus/motor/server.ex`.
- Results use `schema_version: 2`: physical bodies always expose `solutions.geocentric` and add `solutions.topocentric` only for an observer. Mathematical points remain geocentric and have no invented distance or physical state. Do not reintroduce zodiac signs or formatted longitude strings into the API.
- Topocentric observers are geodetic latitude, east-positive longitude, and ellipsoidal height. They require `ITRF93`; obtain actual coverage from loaded binary PCKs with `pckcov_c`, reject requests outside coverage, and never silently fall back to `IAU_EARTH`.
- `mix compile` drives the native build through `elixir_make` -> `native/Makefile` -> `native/meson.build`; do not run `make` or `meson` directly unless debugging that layer.
- The worker protocol is JSON over an Erlang port opened with `{:packet, 4}`; protocol v2 carries an optional surface observer. Elixir encoding/decoding lives in `Angelus.Motor.WorkerProtocol`, native request/response handling in `native/src/io/*`.
- `docs/BUILDING.md` has stale native target/path details; prefer `mix.exs`, `justfile`, `native/meson.build`, and CI workflows when they disagree.

## Commands

- Setup: `mix deps.get` or `mix setup`.
- Fast unit tests: `mix test test/unit` or `just test`.
- Single test file: `mix test test/unit/path/to_test.exs`; add `:line` for a focused ExUnit test.
- Force a local CSPICE/ERFA source build: `ANGELUS_FORCE_BUILD=1 mix compile` or `just build`.
- CI-equivalent order is `mix format --check-formatted`, `ANGELUS_FORCE_BUILD=1 mix compile --warnings-as-errors`, `mix credo --strict --ignore todo`, `mix dialyzer --format github`, then `mix test test/unit`.
- `mix consistency` is a local shortcut only: it forces Elixir recompilation, runs `mix credo -A`, Dialyzer with `--format dialyxir`, and unit tests, but skips format check and CI's warnings-as-errors/strict Credo settings.
- `just credo` runs `mix credo --strict` without CI's `--ignore todo`; `just dialyzer` uses `--format dialyxir`, while CI uses `--format github`.
- `just test-integration` / `just test-e2e` runs `just build` first, then `mix test test/e2e --include e2e`.
- `just clean` removes `_build`, `native/build`, and `native/lib`; `just check-leaks` builds/runs the Valgrind Docker image.

## Native Build And Kernels

- Source builds need a C compiler, Meson `>= 1.11.1`, Ninja, `curl`, `jq`, and system `libcjson`/`cjson` headers; CI installs Meson with `pip` because Ubuntu's package is too old.
- Meson fetches CSPICE and ERFA through `native/subprojects/*.wrap`; the worker installs to the compiled app's `priv/angelus_worker` via `MIX_APP_PATH`.
- Runtime resources are not bundled in Hex packages; `mix angelus.prepare` downloads the required generic kernels and the pinned Quirón SPK, then verifies its SHA-256 checksum.
- Kernel files land in `priv/kernels/`; both public ephemeris calls load them internally. The Earth binary PCK provides ITRF93 orientation data; geocentric requests remain available outside its coverage when the SPK coverage permits.

## Tests And Fixtures

- `test/test_helper.exs` excludes `:e2e` by default, so plain `mix test` will skip e2e tests.
- Unit tests exercise the ephemeris result model without CSPICE.
- E2E tests require the compiled real worker and downloaded kernels; use `mix test test/e2e --include e2e`.

## Release Notes

- Release tags are `v*`; `.github/workflows/release.yml` rejects a tag if `mix.exs` `@version` does not equal the tag without the leading `v`. The retained runtime-kernel release is `kernels-v0.2` because it hosts the pinned Quirón SPK.
- Precompiled workers are configured in `mix.exs` via `cc_precompiler`; current listed targets are `aarch64-apple-darwin`, `x86_64-linux-gnu`, and `aarch64-linux-gnu`.

## Agent Skills

- Issues and PRDs are tracked in GitHub Issues using the `gh` CLI. See `docs/agents/issue-tracker.md`.
- The triage label vocabulary uses the five default canonical labels. See `docs/agents/triage-labels.md`.
- This repo uses a single-context domain docs layout. See `docs/agents/domain.md`.
