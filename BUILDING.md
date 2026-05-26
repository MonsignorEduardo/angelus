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

When `mix deps.compile` runs, `elixir_make` will:

1. Detect your platform (`aarch64-apple-darwin` or `x86_64-linux-gnu`)
2. Download the precompiled `spice_worker` binary from GitHub Releases
3. Verify its SHA-256 checksum against `checksum-angelus.exs`
4. Install it to `priv/spice_worker`

No C compiler or CSPICE installation is needed.

**Supported platforms (v0.1):**

| Platform              | Target triplet           |
|-----------------------|--------------------------|
| macOS (Apple Silicon) | `aarch64-apple-darwin`   |
| Linux glibc x86_64    | `x86_64-linux-gnu`       |

If your platform is not listed, see [Local dev build](#local-dev-build).

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
just build             # downloads CSPICE + jsmn → native/libs/, compiles spice_worker
just test              # 54 unit tests (no CSPICE required at test time)
just test-integration  # build + mix test --include spice_integration
```

### Manual build (without just)

```bash
mix deps.get
mix compile
# The Makefile auto-downloads CSPICE N0067 to native/libs/cspice/
# and jsmn to native/libs/jsmn/ on first run.
# make_force_build: true is set for :dev/:test in mix.exs,
# so mix compile always builds from source in those envs.
```

### Stub build (no CSPICE — unit tests only)

```bash
mix deps.get
mix compile            # stub worker — SPICE ops return an error
mix test               # 54 tests, all pass
```

The stub build is the default when `SKIP_CSPICE=1` is passed to `make`.
In `:dev` and `:test` envs, `mix compile` always builds from source
(`make_force_build: true` in `mix.exs`).

### Re-downloading native libs

```bash
just clean-libs        # removes native/libs/ entirely
just build             # re-downloads CSPICE + jsmn and recompiles
# or without just:
cd native/spice_worker && make clean-libs && cd ../..
mix compile
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

The GitHub Actions workflow (`.github/workflows/release.yml`) triggers on `v*` tags:

1. **`precompile-macos`** — runs on `macos-14` (M1), caches `native/libs/` keyed on
   `native_sources.lock`, calls `mix elixir_make.precompile`, uploads `cache/*.tar.gz`.
2. **`precompile-linux`** — same on `ubuntu-22.04` for `x86_64-linux-gnu`.
3. **`checksum`** — after both jobs finish, fetches all artefacts from the release,
   generates `checksum-angelus.exs`, and uploads it to the same release.

The Makefile handles CSPICE download in CI exactly as it does locally — no duplicate
download logic in the workflow file.

### Releasing a new version

```bash
# 1. Bump @version in mix.exs
# 2. Commit and tag
git tag v0.1.0
git push origin v0.1.0

# 3. CI runs automatically (see .github/workflows/release.yml)

# 4. After CI: pull the generated checksum file
curl -fsSL https://github.com/angelus-astro/angelus/releases/download/v0.1.0/checksum-angelus.exs \
  -o checksum-angelus.exs

# 5. Publish to Hex (checksum file must be present)
mix hex.publish
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

---

## File layout

```
native/
  native_sources.lock        — pinned versions + SHA-256 for CSPICE and jsmn
  libs/                      — downloaded at build time (gitignored)
    cspice/
      include/               — CSPICE headers
      lib/cspice.a           — CSPICE static archive
    jsmn/
      jsmn.h                 — single-header JSON tokenizer
  spice_worker/
    src/                     — C source files
      main.c                 — dispatcher, entry point
      protocol.{h,c}         — packet:4 framing
      cspice_ops.{h,c}       — CSPICE wrappers (stub without CSPICE)
    build/                   — object files (gitignored)
    patches/                 — reserved for CSPICE build patches
    Makefile                 — all, fetch-cspice, fetch-jsmn,
                               download-precompiled, clean, clean-libs

priv/
  spice_worker               — compiled/downloaded binary (gitignored)

checksum-angelus.exs         — generated by `mix elixir_make.checksum`
                               required for Hex publish; do not gitignore
```
