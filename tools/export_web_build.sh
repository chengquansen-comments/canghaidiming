#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUTPUT_DIR="${1:-$PROJECT_ROOT/build/web}"
PRESET_NAME="Web"
INDEX_NAME="index.html"
EXPORT_PRESETS_FILE="$PROJECT_ROOT/export_presets.cfg"
CUSTOM_SHELL_FILE="$PROJECT_ROOT/web_shell.html"

mkdir -p "$OUTPUT_DIR"

echo "[web-export] project: $PROJECT_ROOT"
echo "[web-export] output : $OUTPUT_DIR/$INDEX_NAME"

if [[ ! -f "$EXPORT_PRESETS_FILE" ]]; then
  echo "[web-export] ERROR: missing export_presets.cfg" >&2
  exit 1
fi
if ! grep -q 'name="Web"' "$EXPORT_PRESETS_FILE"; then
  echo "[web-export] ERROR: export preset 'Web' not found in export_presets.cfg" >&2
  exit 1
fi
if grep -q 'html/custom_html_shell="res://web_shell.html"' "$EXPORT_PRESETS_FILE" && [[ ! -f "$CUSTOM_SHELL_FILE" ]]; then
  echo "[web-export] ERROR: custom web shell file missing: $CUSTOM_SHELL_FILE" >&2
  exit 1
fi
if ! command -v godot >/dev/null 2>&1 && ! command -v godot4 >/dev/null 2>&1; then
  echo "[web-export] ERROR: godot/godot4 command not found" >&2
  exit 1
fi

if [[ -z "$OUTPUT_DIR" || "$OUTPUT_DIR" == "/" || "$OUTPUT_DIR" == "$PROJECT_ROOT" || "$OUTPUT_DIR" == "$PROJECT_ROOT/" ]]; then
  echo "[web-export] ERROR: refusing to clear unsafe output directory: $OUTPUT_DIR" >&2
  exit 1
fi

GODOT_BIN="$(command -v godot4 || command -v godot)"

rm -rf -- "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"

"$GODOT_BIN" --headless --path "$PROJECT_ROOT" --export-release "$PRESET_NAME" "$OUTPUT_DIR/$INDEX_NAME"

echo "[web-export] done"
