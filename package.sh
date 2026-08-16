#!/usr/bin/env bash
# Builds the single-archive .plasmoid for KDE Store installs. The archive name
# is derived from metadata.json so it cannot drift from the declared version.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
VERSION=$(sed -n 's/.*"Version": *"\([^"]*\)".*/\1/p' "$ROOT/package/metadata.json" | head -1)
OUT="$ROOT/dynamicisland-$VERSION.plasmoid"

rm -f "$OUT"
(cd "$ROOT/package" && zip -r -q "$OUT" . -x '.*' -x '*/.*')
echo "Built $OUT"
