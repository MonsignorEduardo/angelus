# Makefile — thin wrapper over Meson for elixir_make / cc_precompiler
#
# Layout:
#   src/          — C source files
#   include/      — third-party headers
#   subprojects/  — Meson wrap files (cspice.wrap — built from source)
#   vendor/       — bundled third-party source (erfa)
#   build/        — meson build dirs, one per target (gitignored)
#   patches/      — reserved for build patches
#
# Invocation:
#   This Makefile is called by elixir_make. Use `mix compile`, `just build`,
#   or the release workflow rather than invoking `make` directly.

# ── Paths ─────────────────────────────────────────────────────────────────
NATIVE_DIR   := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
BUILD_TARGET := $(if $(CC_PRECOMPILER_CURRENT_TARGET),$(CC_PRECOMPILER_CURRENT_TARGET),native)
BUILD_DIR    := $(NATIVE_DIR)build/$(BUILD_TARGET)

.PHONY: all require-mix-app-path clean

all: require-mix-app-path $(BUILD_DIR)/build.ninja
	meson compile -C $(BUILD_DIR)
	meson install -C $(BUILD_DIR) --no-rebuild --skip-subprojects

require-mix-app-path:
	@if [ -z "$(MIX_APP_PATH)" ]; then \
	  echo "ERROR: MIX_APP_PATH is required; run through mix/elixir_make or pass MIX_APP_PATH explicitly"; \
	  exit 1; \
	fi

$(BUILD_DIR)/build.ninja: require-mix-app-path
	@mkdir -p $(MIX_APP_PATH)/priv
	meson setup $(BUILD_DIR) $(NATIVE_DIR) --prefix /

clean:
	rm -rf $(BUILD_DIR)
