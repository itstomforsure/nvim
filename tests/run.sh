#!/usr/bin/env bash
# Test runner used both locally and in CI.
# Usage: tests/run.sh [unit|integration]   (default: both)

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEPS="$ROOT/tests/.deps"
PLENARY="$DEPS/plenary.nvim"

mkdir -p "$DEPS"
if [ ! -d "$PLENARY" ]; then
	git clone --depth 1 https://github.com/nvim-lua/plenary.nvim "$PLENARY"
fi

target="${1:-all}"
case "$target" in
	unit)        dirs=("tests/unit") ;;
	integration) dirs=("tests/integration") ;;
	all)         dirs=("tests/unit" "tests/integration") ;;
	*) echo "unknown target: $target" >&2; exit 2 ;;
esac

for dir in "${dirs[@]}"; do
	if [ ! -d "$ROOT/$dir" ]; then continue; fi
	echo "==> $dir"
	nvim --headless --noplugin -u tests/minimal_init.lua \
		-c "PlenaryBustedDirectory $dir { minimal_init = 'tests/minimal_init.lua' }"
done
