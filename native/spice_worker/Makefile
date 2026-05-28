# Makefile — thin wrapper over Meson for elixir_make / cc_precompiler
#
# Layout:
#   src/       — C source files
#   build/     — meson build dirs, one per target (gitignored)
#   patches/   — reserved for CSPICE build patches
#   ../libs/   — downloaded deps: cspice/, jsmn/ (gitignored)
#
# Invocation:
#   This Makefile is called by elixir_make. Use `mix compile`, `just build`,
#   or the release workflow rather than invoking `make` directly.

# ── Paths ─────────────────────────────────────────────────────────────────
WORKER_DIR   := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
LIBS_DIR     := $(WORKER_DIR)../libs
BUILD_TARGET := $(if $(CC_PRECOMPILER_CURRENT_TARGET),$(CC_PRECOMPILER_CURRENT_TARGET),native)
BUILD_DIR    := $(WORKER_DIR)build/$(BUILD_TARGET)
FETCH_SCRIPT := $(WORKER_DIR)fetch-libs.sh

.PHONY: all fetch-cspice fetch-jsmn require-mix-app-path clean

all: require-mix-app-path fetch-jsmn fetch-cspice $(BUILD_DIR)/build.ninja
	meson compile -C $(BUILD_DIR)
	meson install -C $(BUILD_DIR) --no-rebuild

require-mix-app-path:
	@if [ -z "$(MIX_APP_PATH)" ]; then \
	  echo "ERROR: MIX_APP_PATH is required; run through mix/elixir_make or pass MIX_APP_PATH explicitly"; \
	  exit 1; \
	fi

$(BUILD_DIR)/build.ninja: require-mix-app-path
	@mkdir -p $(MIX_APP_PATH)/priv
	meson setup $(BUILD_DIR) $(WORKER_DIR) --prefix /

fetch-jsmn:
	@sh $(FETCH_SCRIPT) jsmn $(LIBS_DIR)/jsmn

fetch-cspice:
	@sh $(FETCH_SCRIPT) cspice $(LIBS_DIR)/spice

clean:
	rm -rf $(BUILD_DIR)
