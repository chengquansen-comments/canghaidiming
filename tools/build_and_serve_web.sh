#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUTPUT_DIR="${1:-$PROJECT_ROOT/build/web}"
PORT="${2:-8060}"
HOST="${3:-127.0.0.1}"

"$PROJECT_ROOT/tools/export_web_build.sh" "$OUTPUT_DIR"

INDEX_FILE="$OUTPUT_DIR/index.html"
JS_COUNT="$(find "$OUTPUT_DIR" -maxdepth 1 -type f -name '*.js' | wc -l | tr -d ' ')"
WASM_COUNT="$(find "$OUTPUT_DIR" -maxdepth 1 -type f -name '*.wasm' | wc -l | tr -d ' ')"
PCK_COUNT="$(find "$OUTPUT_DIR" -maxdepth 1 -type f -name '*.pck' | wc -l | tr -d ' ')"

if [[ ! -f "$INDEX_FILE" ]]; then
  echo "[web-preview] ERROR: missing index.html in $OUTPUT_DIR" >&2
  exit 1
fi
if [[ "$JS_COUNT" -lt 1 || "$WASM_COUNT" -lt 1 || "$PCK_COUNT" -lt 1 ]]; then
  echo "[web-preview] ERROR: incomplete web bundle in $OUTPUT_DIR" >&2
  echo "[web-preview] expected at least one .js, .wasm and .pck next to index.html" >&2
  exit 1
fi

echo "[web-preview] bundle validated: $OUTPUT_DIR"
python3 "$PROJECT_ROOT/tools/report_web_bundle.py" "$OUTPUT_DIR"
echo "[web-preview] opening at http://$HOST:$PORT"
python3 "$PROJECT_ROOT/tools/run_web_preview.py" --dir "$OUTPUT_DIR" --host "$HOST" --port "$PORT"
