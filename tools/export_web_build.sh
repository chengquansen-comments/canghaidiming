#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUTPUT_DIR="${1:-$PROJECT_ROOT/build/web}"
PRESET_NAME="Web"
INDEX_NAME="index.html"

mkdir -p "$OUTPUT_DIR"

echo "[web-export] project: $PROJECT_ROOT"
echo "[web-export] output : $OUTPUT_DIR/$INDEX_NAME"

if ! command -v godot >/dev/null 2>&1 && ! command -v godot4 >/dev/null 2>&1; then
  echo "[web-export] ERROR: godot/godot4 command not found" >&2
  exit 1
fi

GODOT_BIN="$(command -v godot4 || command -v godot)"

"$GODOT_BIN" --headless --path "$PROJECT_ROOT" --export-release "$PRESET_NAME" "$OUTPUT_DIR/$INDEX_NAME"

echo "[web-export] done"
