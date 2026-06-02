# AGENTS.md

## Project Shape

- Angelus is an Elixir `~> 1.19` library backed by a native C `angelus_worker` port for NAIF CSPICE/JPL ephemerides.
- Public Elixir API starts in `lib/angelus.ex`; position validation and body shaping live in `lib/angelus/ephemeris.ex`; native worker ownership lives in `lib/angelus/motor/server.ex`.
- The native worker is built by `elixir_make`: `mix compile` calls `native/Makefile`, which drives Meson in `native/meson.build`. Do not invoke `make` or `meson` directly unless debugging the build layer.
- Native protocol uses Erlang ports with `{:packet, 4}` framing and JSON encode/decode in `Angelus.Motor.WorkerProtocol` plus `native/src/protocol/*`.

## Commands

- Setup: `mix deps.get` or `mix setup`.
- Fast unit tests: `mix test test/unit` or `just test`.
- Single test file: `mix test test/unit/path/to_test.exs`.
- Force a local CSPICE/ERFA source build: `ANGELUS_FORCE_BUILD=1 mix compile` or `just build`.
- CI-equivalent order is `mix format --check-formatted`, `ANGELUS_FORCE_BUILD=1 mix compile --warnings-as-errors`, `mix credo --strict --ignore todo`, `mix dialyzer --format github`, then `mix test test/unit`.
- Local shortcut `mix consistency` runs forced Elixir compile, Credo, Dialyzer, and unit tests, but it is not identical to CI because CI also runs format check, warnings-as-errors, and strict Credo with `--ignore todo`.
- `just test-integration` / `just test-e2e` runs `just build` first, then `mix test test/e2e --include e2e`.
- `just clean` removes `_build`, `native/build`, and `native/lib`.

## Native Build And Kernels

- Source builds need a C compiler, Meson, Ninja, `curl`, `jq`, and system `libcjson`/`cjson` headers; CI installs `build-essential curl jq meson ninja-build libcjson-dev`.
- Meson fetches CSPICE and ERFA through `native/subprojects/*.wrap`; build output is installed as `priv/angelus_worker` under the compiled Mix app path.
- Kernel files are not bundled in Hex artifacts except the Chiron SPK copied by `mix angelus.kernels`; download/install the single supported kernel set with `mix angelus.kernels`.
- Kernel files land in `priv/kernels/`, but runtime code must still call `Angelus.load_kernels/0` or `Angelus.load_kernels/1`; kernels are never loaded implicitly.

## Tests And Fixtures

- `test/test_helper.exs` excludes `:e2e` by default, so plain `mix test` will skip e2e tests.
- Unit tests should avoid real CSPICE when possible by passing `adapter: Angelus.CPortStub` from `test/support/spice_stub.ex`.
- E2E tests require the compiled real worker, downloaded kernels, and `test/support/fixtures/horizons/de442_positions.json` containing real JPL Horizons data.
- Do not hand-write or placeholder Horizons positions; `test/support/fixtures/horizons/README.md` explicitly forbids fake fixture values.

## Release Notes

- Release tags are `v*`; `.github/workflows/release.yml` rejects a tag if `mix.exs` `@version` does not equal the tag without the leading `v`.
- Precompiled workers are configured in `mix.exs` via `cc_precompiler`; current listed targets are `aarch64-apple-darwin`, `x86_64-linux-gnu`, and `aarch64-linux-gnu`.

## Agent Skills

- Issues and PRDs are tracked in GitHub Issues using the `gh` CLI. See `docs/agents/issue-tracker.md`.
- The triage label vocabulary uses the five default canonical labels. See `docs/agents/triage-labels.md`.
- This repo uses a single-context domain docs layout. See `docs/agents/domain.md`.
