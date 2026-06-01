# Makefile — thin wrapper over Meson for elixir_make / cc_precompiler
#
# Layout:
#   src/          — C source files grouped by concern
#   src/astro/    — CSPICE / ERFA operation wrappers and shared result types
#   src/io/       — packet:4 stdin/stdout framing
#   src/kernels/  — kernel set path construction
#   src/protocol/ — JSON request dispatch and response serialization
#   subprojects/  — Meson wrap files for third-party libraries
#   build/        — Meson build dirs, one per target (gitignored)
#
# Invocation:
#   This Makefile is called by elixir_make. Use `mix compile`, `just build`,
#   or the release workflow rather than invoking `make` directly.

# ── Paths ─────────────────────────────────────────────────────────────────
NATIVE_DIR   := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
BUILD_TARGET := $(if $(CC_PRECOMPILER_CURRENT_TARGET),$(CC_PRECOMPILER_CURRENT_TARGET),native)
BUILD_DIR    := $(NATIVE_DIR)build/$(BUILD_TARGET)
CLANG_FORMAT := $(shell command -v clang-format 2>/dev/null || xcrun --find clang-format 2>/dev/null)
FORMAT_FILES := $(wildcard \
  $(NATIVE_DIR)src/*.c \
  $(NATIVE_DIR)src/*.h \
  $(NATIVE_DIR)src/astro/*.c \
  $(NATIVE_DIR)src/astro/*.h \
  $(NATIVE_DIR)src/io/*.c \
  $(NATIVE_DIR)src/io/*.h \
  $(NATIVE_DIR)src/kernels/*.c \
  $(NATIVE_DIR)src/kernels/*.h \
  $(NATIVE_DIR)src/protocol/*.c \
  $(NATIVE_DIR)src/protocol/*.h)

.PHONY: all require-mix-app-path format clean

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

format:
	@if [ -z "$(CLANG_FORMAT)" ]; then \
	  echo "ERROR: clang-format is required to format native sources"; \
	  exit 1; \
	fi
	$(CLANG_FORMAT) -i $(FORMAT_FILES)

clean:
	rm -rf $(BUILD_DIR)
