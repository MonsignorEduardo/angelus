# Building Angelus

This document covers three scenarios:

1. [End-user install](#end-user-install) — using Hex.pm with precompiled binaries
2. [Local dev build](#local-dev-build) — building with CSPICE locally
3. [CI / Release](#ci--release) — how precompiled binaries are produced

---

## End-user install

Add `angelus` to `mix.exs`:

```elixir
{:angelus, "~> 0.1"}
```

When `mix deps.compile` runs on a supported release target, `elixir_make` will:

1. Detect your platform (`aarch64-apple-darwin` or `x86_64-linux-gnu`)
2. Download the precompiled `spice_worker` binary from GitHub Releases
3. Verify its SHA-256 checksum against `checksum.exs`
4. Install it to the compiled app's `priv/spice_worker`

No C compiler or CSPICE installation is needed.

**Supported CSPICE release platforms (v0.1):**

| Platform              | Target triplet           |
|-----------------------|--------------------------|
| macOS (Apple Silicon) | `aarch64-apple-darwin`   |
| Linux glibc x86_64    | `x86_64-linux-gnu`       |

Only the targets listed here receive released, CSPICE-enabled precompiled workers.
Platforms not listed here, including Linux ARM64, are not supported by the bundled
CSPICE build.

---

## Local dev build

### Prerequisites

- C compiler (`cc` / `gcc` / `clang`)
- `curl`, `tar` — for downloading CSPICE and jsmn
- `jq` — for parsing `native_sources.lock` (`brew install jq` / `apt install jq`)
- `just` — optional but recommended (`brew install just` / `cargo install just`)

### Quickstart with just

```bash
mix deps.get
just build             # ANGELUS_FORCE_BUILD=1; downloads CSPICE + jsmn and compiles spice_worker
just test              # unit tests (no CSPICE required at test time)
just test-integration  # build + mix test --include spice_integration
```

### Manual build (without just)

```bash
mix deps.get
ANGELUS_FORCE_BUILD=1 mix compile
# The Makefile auto-downloads CSPICE N0067 to native/libs/cspice/
# and jsmn to native/libs/jsmn/ on first run.
```

### Stub build (no CSPICE — unit tests only)

```bash
mix deps.get
ANGELUS_FORCE_BUILD=1 mix compile -- SKIP_CSPICE=1
mix test               # unit tests, all pass
```

`ANGELUS_FORCE_BUILD=1` makes `elixir_make` call the local Makefile instead of downloading a precompiled worker. `SKIP_CSPICE=1` then tells that Makefile to compile the stub worker.

### Re-downloading native libs

```bash
just clean             # removes _build, native/spice_worker/build, and native/libs
just build             # re-downloads CSPICE + jsmn and recompiles
```

### Run integration tests (requires kernel files)

```bash
just test-integration
# or:
mix test --include spice_integration
```

---

## CI / Release

### How it works

The pull request CI workflow (`.github/workflows/ci.yml`) runs on
`ubuntu-24.04` with `ANGELUS_FORCE_BUILD=1` and `SKIP_CSPICE=1`, so it builds
the stub worker and does not download or build CSPICE. It checks formatting,
compiles, then runs Credo, Dialyzer, and tests.

The release workflow (`.github/workflows/release.yml`) triggers on `v*` tags and
manual dispatch. It validates the release tag, runs the same CI, runs integration
tests on `ubuntu-24.04`, then builds CSPICE-enabled release artefacts only for
macOS Apple Silicon and Linux glibc x86_64:

1. **`precompile-macos`** — runs on `macos-14` (M1), caches `native/libs/` keyed on
   `native_sources.lock`, calls `mix elixir_make.precompile`, uploads `_build/precompiled/*.tar.gz`.
2. **`precompile-linux`** — same on `ubuntu-24.04` for `x86_64-linux-gnu`.
3. **`checksum`** — after all precompile jobs finish, fetches all artefacts from the release,
   generates `checksum.exs`, and uploads it to the same release.
4. **`publish`** — downloads the generated checksum and publishes the package to Hex.pm.

The Makefile handles CSPICE download in CI exactly as it does locally. The workflow only selects the target and output directory.

### Releasing a new version

```bash
# 1. Bump @version in mix.exs
# 2. Commit and tag
git tag v0.1.0
git push origin v0.1.0

# 3. Release CI runs automatically (see .github/workflows/release.yml)
# 4. The workflow uploads precompiled artefacts, generates the checksum file,
#    and publishes to Hex.pm using HEX_API_KEY.
```

### Artefact naming

`elixir_make` + `cc_precompiler` produce tarballs named:

```
angelus-port-<target>-<version>.tar.gz
```

Examples:
```
angelus-port-aarch64-apple-darwin-0.1.0.tar.gz
angelus-port-x86_64-linux-gnu-0.1.0.tar.gz
```

Each tarball contains only `priv/spice_worker`, as configured by
`make_precompiler_priv_paths: ["spice_worker"]` in `mix.exs`.

### Kernel data files

SPICE kernel files (`.bsp`, `.tls`, `.tpc`) are **not** bundled in the Hex package.
They are large data files distributed separately. See `README.md` for how to acquire
and configure the v0.1 kernel set.
