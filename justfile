# Show available recipes
help:
    @just --list

# Download CSPICE + jsmn and compile spice_worker with real CSPICE support
build:
    rm -f priv/spice_worker
    mix compile

# Compile stub worker only (no CSPICE download, for CI unit tests)
build-stub:
    rm -f priv/spice_worker
    mix compile -- SKIP_CSPICE=1

# Remove compiled worker (forces recompile on next build)
clean:
    cd native/spice_worker && make clean MIX_APP_PATH=$(mix run --no-start -e 'IO.puts Mix.Project.app_path()' 2>/dev/null)

# Remove downloaded native libs (CSPICE + jsmn) — forces re-download on next build
clean-libs:
    cd native/spice_worker && make clean-libs

# Run unit tests (no CSPICE required)
test:
    mix test

# Run integration tests (requires CSPICE worker)
test-integration: build
    mix test --include spice_integration
