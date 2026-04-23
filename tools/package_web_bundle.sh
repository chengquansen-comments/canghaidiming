#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUTPUT_DIR="${1:-$PROJECT_ROOT/build/web}"
ZIP_PATH="${2:-${OUTPUT_DIR%/}.zip}"

INDEX_FILE="$OUTPUT_DIR/index.html"
JS_COUNT="$(find "$OUTPUT_DIR" -maxdepth 1 -type f -name '*.js' | wc -l | tr -d ' ')"
WASM_COUNT="$(find "$OUTPUT_DIR" -maxdepth 1 -type f -name '*.wasm' | wc -l | tr -d ' ')"
PCK_COUNT="$(find "$OUTPUT_DIR" -maxdepth 1 -type f -name '*.pck' | wc -l | tr -d ' ')"

if [[ ! -d "$OUTPUT_DIR" ]]; then
  echo "[web-package] ERROR: bundle directory not found: $OUTPUT_DIR" >&2
  exit 1
fi
if [[ ! -f "$INDEX_FILE" ]]; then
  echo "[web-package] ERROR: missing index.html in $OUTPUT_DIR" >&2
  exit 1
fi
if [[ "$JS_COUNT" -lt 1 || "$WASM_COUNT" -lt 1 || "$PCK_COUNT" -lt 1 ]]; then
  echo "[web-package] ERROR: incomplete web bundle in $OUTPUT_DIR" >&2
  echo "[web-package] expected at least one .js, .wasm and .pck next to index.html" >&2
  exit 1
fi

rm -f "$ZIP_PATH"
(
  cd "$OUTPUT_DIR"
  zip -qr "$ZIP_PATH" .
)

echo "[web-package] packaged: $ZIP_PATH"
