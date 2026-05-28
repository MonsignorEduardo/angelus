# Makefile — internal elixir_make build for Angelus priv/spice_worker
#
# Layout:
#   src/       — C source files
#   build/     — object files (gitignored)
#   patches/   — reserved for CSPICE build patches
#   ../libs/   — downloaded deps: cspice/, jsmn/ (gitignored)
#
# Invocation:
#
#   This Makefile is called by elixir_make. Use `mix compile`, `just build`,
#   or the release workflow rather than invoking `make` directly.
#
# Build modes used by elixir_make:
#
#   1. Full build with CSPICE (auto-downloads if needed):
#        mix compile with ANGELUS_FORCE_BUILD=1
#
#   2. Stub build (no CSPICE):
#        mix compile -- SKIP_CSPICE=1 with ANGELUS_FORCE_BUILD=1
#      Returns an error for all SPICE ops. Used for unit tests.
#
# Targets:
#   all                  — fetch deps + compile (default)
#   fetch-cspice         — download + verify CSPICE to ../libs/cspice/
#   fetch-jsmn           — download jsmn.h to ../libs/jsmn/

# ── Compiler ──────────────────────────────────────────────────────────────
CC     ?= cc
CFLAGS ?= -O2 -Wall -Wextra -std=c11

# ── Paths ─────────────────────────────────────────────────────────────────
WORKER_DIR   := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
LIBS_DIR     := $(WORKER_DIR)../libs
SRC_DIR      := $(WORKER_DIR)src
BUILD_TARGET := $(if $(CC_PRECOMPILER_CURRENT_TARGET),$(CC_PRECOMPILER_CURRENT_TARGET),native)
BUILD_DIR    := $(WORKER_DIR)build/$(BUILD_TARGET)
FETCH_SCRIPT := $(WORKER_DIR)fetch-libs.sh
MODE_STAMP   := $(BUILD_DIR)/.cspice-mode

CSPICE_DIR ?= $(LIBS_DIR)/cspice/$(BUILD_TARGET)
JSMN_DIR   := $(LIBS_DIR)/jsmn
JSMN_H     := $(JSMN_DIR)/jsmn.h

PRIV_DIR   := $(MIX_APP_PATH)/priv
TARGET     := $(PRIV_DIR)/spice_worker

SOURCES := $(SRC_DIR)/main.c $(SRC_DIR)/protocol.c $(SRC_DIR)/cspice_ops.c
OBJECTS := $(patsubst $(SRC_DIR)/%.c,$(BUILD_DIR)/%.o,$(SOURCES))

# ── CSPICE linkage ────────────────────────────────────────────────────────
ifndef SKIP_CSPICE
  CFLAGS    += -DHAVE_CSPICE -I$(CSPICE_DIR)/include
  # Link static archive directly — avoids -lcspice resolution issues on macOS
  LDFLAGS   += $(CSPICE_DIR)/lib/cspice.a -lm
  CSPICE_DEP := fetch-cspice
  CSPICE_MODE := full
else
  LDFLAGS    += -lm
  CSPICE_DEP :=
  CSPICE_MODE := stub
endif

.PHONY: all fetch-cspice fetch-jsmn priv require-mix-app-path force

all: require-mix-app-path $(CSPICE_DEP) fetch-jsmn priv $(TARGET)

require-mix-app-path:
	@if [ -z "$(MIX_APP_PATH)" ]; then \
	  echo "ERROR: MIX_APP_PATH is required; run through mix/elixir_make or pass MIX_APP_PATH explicitly"; \
	  exit 1; \
	fi

priv: require-mix-app-path
	@mkdir -p $(PRIV_DIR)

# ── Fetch jsmn ────────────────────────────────────────────────────────────
fetch-jsmn:
	@sh $(FETCH_SCRIPT) jsmn $(JSMN_DIR)

# ── Fetch CSPICE ──────────────────────────────────────────────────────────
fetch-cspice:
	@sh $(FETCH_SCRIPT) cspice $(CSPICE_DIR)

# ── Compile ───────────────────────────────────────────────────────────────
$(TARGET): $(OBJECTS)
	@mkdir -p $(PRIV_DIR)
	$(CC) $(OBJECTS) $(LDFLAGS) -o $@

$(MODE_STAMP): force
	@mkdir -p $(BUILD_DIR)
	@if [ ! -f $@ ] || [ "$$(cat $@)" != "$(CSPICE_MODE)" ]; then \
	  printf '%s' "$(CSPICE_MODE)" > $@; \
	fi

force:

$(BUILD_DIR)/%.o: $(SRC_DIR)/%.c $(SRC_DIR)/protocol.h $(SRC_DIR)/cspice_ops.h $(JSMN_H) $(MODE_STAMP)
	@mkdir -p $(BUILD_DIR)
	$(CC) $(CFLAGS) -DJSMN_STATIC -I$(JSMN_DIR) -I$(SRC_DIR) -c $< -o $@
