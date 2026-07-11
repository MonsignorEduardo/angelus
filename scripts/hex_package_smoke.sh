#!/bin/sh

set -eu

project_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
smoke_dir=$(mktemp -d "${TMPDIR:-/tmp}/angelus-hex-smoke.XXXXXX")
trap 'rm -rf "$smoke_dir"' EXIT HUP INT TERM

cd "$project_dir"
mix hex.build

set -- "$project_dir"/angelus-*.tar
if [ "$#" -ne 1 ] || [ ! -f "$1" ]; then
  echo "Expected exactly one Angelus package tarball" >&2
  exit 1
fi

package_dir="$smoke_dir/package"
mkdir "$package_dir"
tar -xOf "$1" contents.tar.gz | tar -xz -C "$package_dir"

cd "$smoke_dir"
ANGELUS_FORCE_BUILD=1 ANGELUS_PACKAGE_PATH="$package_dir" MIX_ENV=prod \
  elixir -e 'Mix.install([{:angelus, path: System.fetch_env!("ANGELUS_PACKAGE_PATH")}]); Code.ensure_loaded!(Angelus)'
