# Makefile — builds priv/spice_worker
#
# Layout:
#   src/       — C source files
#   build/     — object files (gitignored)
#   patches/   — reserved for CSPICE build patches
#   ../libs/   — downloaded deps: cspice/, jsmn/ (gitignored)
#
# Build modes:
#
#   1. Full build with CSPICE (auto-downloads if needed):
#        make
#
#   2. Stub build (no CSPICE):
#        make SKIP_CSPICE=1
#      Returns an error for all SPICE ops. Used for unit tests.
#
#   3. Download precompiled binary from GitHub Releases:
#        make download-precompiled
#      Called by elixir_make/cc_precompiler when a release exists.
#
# Targets:
#   all                  — fetch deps + compile (default)
#   fetch-cspice         — download + verify CSPICE to ../libs/cspice/
#   fetch-jsmn           — download jsmn.h to ../libs/jsmn/
#   download-precompiled — download binary from GitHub Releases
#   clean                — remove build/ objects and priv/spice_worker
#   clean-libs           — remove ../libs/ (forces re-download)

# ── Compiler ──────────────────────────────────────────────────────────────
CC     ?= cc
CFLAGS ?= -O2 -Wall -Wextra -std=c11

# ── Paths ─────────────────────────────────────────────────────────────────
WORKER_DIR   := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
LIBS_DIR     := $(WORKER_DIR)../libs
SRC_DIR      := $(WORKER_DIR)src
BUILD_DIR    := $(WORKER_DIR)build
FETCH_SCRIPT := $(WORKER_DIR)fetch-libs.sh

CSPICE_DIR ?= $(LIBS_DIR)/cspice
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
else
  LDFLAGS    += -lm
  CSPICE_DEP :=
endif

.PHONY: all clean clean-libs fetch-cspice fetch-jsmn priv download-precompiled

all: $(CSPICE_DEP) fetch-jsmn priv $(TARGET)

priv:
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

$(BUILD_DIR)/%.o: $(SRC_DIR)/%.c $(SRC_DIR)/protocol.h $(SRC_DIR)/cspice_ops.h $(JSMN_H)
	@mkdir -p $(BUILD_DIR)
	$(CC) $(CFLAGS) -DJSMN_STATIC -I$(JSMN_DIR) -I$(SRC_DIR) -c $< -o $@

# ── Precompiled binary download ───────────────────────────────────────────
# Called by elixir_make/cc_precompiler when ELIXIR_MAKE_PRECOMPILE_URL is set.
download-precompiled:
	@mkdir -p $(PRIV_DIR)
	@if [ -z "$(ELIXIR_MAKE_PRECOMPILE_URL)" ]; then \
	  echo "ERROR: ELIXIR_MAKE_PRECOMPILE_URL is not set"; exit 1; \
	fi
	@echo "Downloading precompiled spice_worker from $(ELIXIR_MAKE_PRECOMPILE_URL) ..."
	@curl -fsSL "$(ELIXIR_MAKE_PRECOMPILE_URL)" -o /tmp/spice_worker_precompiled.tar.gz
	@tar -xzf /tmp/spice_worker_precompiled.tar.gz -C $(PRIV_DIR)
	@chmod +x $(TARGET)
	@rm -f /tmp/spice_worker_precompiled.tar.gz
	@echo "spice_worker installed to $(TARGET)"

# ── Clean ─────────────────────────────────────────────────────────────────
clean:
	rm -rf $(BUILD_DIR) $(TARGET)

clean-libs:
	rm -rf $(LIBS_DIR)
	@echo "Removed $(LIBS_DIR)"
