#!/usr/bin/env sh
# fetch-libs.sh - download CSPICE and jsmn as specified in native_sources.lock
#
# Usage (from native/spice_worker/):
#   ./fetch-libs.sh cspice <dest_dir>
#   ./fetch-libs.sh jsmn   <dest_dir>
#
# Requires: curl, tar, jq

set -eu

LOCK="$(cd "$(dirname "$0")/.." && pwd)/native_sources.lock"

die() { echo "ERROR: $*" >&2; exit 1; }

command -v jq   >/dev/null 2>&1 || die "jq is required (brew install jq / apt install jq)"
command -v curl >/dev/null 2>&1 || die "curl is required"

sha256() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  else
    shasum -a 256 "$1" | awk '{print $1}'
  fi
}

# fetch cspice
fetch_cspice() {
  DEST="$1"

  if [ -d "$DEST/include" ] && [ -f "$DEST/lib/cspice.a" ]; then
    echo "CSPICE already present at $DEST - skipping."
    return
  fi

  TARGET="${CC_PRECOMPILER_CURRENT_TARGET:-}"

  if [ -z "$TARGET" ] && [ -n "${TARGET_ARCH:-}" ] && [ -n "${TARGET_OS:-}" ] && [ -n "${TARGET_ABI:-}" ]; then
    TARGET="$TARGET_ARCH-$TARGET_OS-$TARGET_ABI"
  fi

  if [ -z "$TARGET" ]; then
    case "$(uname -s)/$(uname -m)" in
      Darwin/arm64) TARGET="aarch64-apple-darwin" ;;
      Linux/x86_64) TARGET="x86_64-linux-gnu" ;;
      *) die "unsupported platform $(uname -s)/$(uname -m) - supported: aarch64-apple-darwin, x86_64-linux-gnu" ;;
    esac
  fi

  case "$TARGET" in
    aarch64-apple-darwin)
      URL="$(      jq -r '.cspice.url_macos_arm64'   "$LOCK")"
      EXPECTED="$( jq -r '.cspice.sha256_macos_arm64' "$LOCK")"
      ;;
    x86_64-linux-gnu)
      URL="$(      jq -r '.cspice.url_linux_x86_64'   "$LOCK")"
      EXPECTED="$( jq -r '.cspice.sha256_linux_x86_64' "$LOCK")"
      ;;
    *)
      die "unsupported target $TARGET - supported: aarch64-apple-darwin, x86_64-linux-gnu"
      ;;
  esac

  VERSION="$(jq -r '.cspice.version' "$LOCK")"
  echo "Downloading CSPICE $VERSION for $TARGET ..."
  curl -fsSL "$URL" -o /tmp/cspice.tar.Z

  echo "Verifying checksum ..."
  ACTUAL="$(sha256 /tmp/cspice.tar.Z)"
  if [ "$ACTUAL" != "$EXPECTED" ]; then
    rm -f /tmp/cspice.tar.Z
    die "checksum mismatch!\n  expected: $EXPECTED\n  actual:   $ACTUAL"
  fi
  echo "Checksum OK."

  echo "Extracting to $DEST ..."
  mkdir -p /tmp/cspice_extract "$DEST"
  tar -xf /tmp/cspice.tar.Z -C /tmp/cspice_extract
  cp -r /tmp/cspice_extract/cspice/include "$DEST/include"
  cp -r /tmp/cspice_extract/cspice/lib "$DEST/lib"

  rm -rf /tmp/cspice_extract /tmp/cspice.tar.Z
  echo "CSPICE installed to $DEST."
}

# fetch jsmn
fetch_jsmn() {
  DEST="$1"
  OUT="$DEST/jsmn.h"

  if [ -f "$OUT" ]; then
    echo "jsmn.h already present - skipping."
    return
  fi

  URL="$(jq -r '.jsmn.url' "$LOCK")"
  mkdir -p "$DEST"
  echo "Downloading jsmn.h ..."
  curl -fsSL "$URL" -o "$OUT"
  echo "jsmn.h installed to $OUT."
}

# dispatch
CMD="${1:-}"
DEST="${2:-}"

[ -n "$CMD" ] && [ -n "$DEST" ] || die "Usage: $0 cspice|jsmn <dest_dir>"

case "$CMD" in
  cspice) fetch_cspice "$DEST" ;;
  jsmn)   fetch_jsmn   "$DEST" ;;
  *)      die "unknown command '$CMD'" ;;
esac
