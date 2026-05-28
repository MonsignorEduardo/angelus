# Show available recipes
help:
    @just --list

# Download CSPICE + jsmn and compile spice_worker into _build/*/lib/angelus/priv
build:
    ANGELUS_FORCE_BUILD=1 mix compile

# Compile stub worker only (no CSPICE download, for fast local tests)
build-stub:
    ANGELUS_FORCE_BUILD=1 mix compile -- SKIP_CSPICE=1

# Check Elixir formatting
format-check:
    mix format --check-formatted

# Run Credo with strict settings
credo:
    mix credo --strict

# Run Dialyzer with GitHub output
dialyzer:
    mix dialyzer --format dialyxir

# Remove compiled worker and downloaded native libs
clean:
    rm -rf _build
    rm -rf native/spice_worker/build
    rm -rf native/libs

# Run unit tests (no CSPICE required)
test:
    mix test test/unit

# Run e2e tests against CSPICE and the JPL Horizons fixture
test-integration: build
    mix test test/e2e --include e2e

# Run e2e tests against CSPICE and the JPL Horizons fixture
test-e2e: test-integration
