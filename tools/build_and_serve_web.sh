#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUTPUT_DIR="${1:-$PROJECT_ROOT/build/web}"
PORT="${2:-8060}"

"$PROJECT_ROOT/tools/export_web_build.sh" "$OUTPUT_DIR"
python3 "$PROJECT_ROOT/tools/run_web_preview.py" --dir "$OUTPUT_DIR" --port "$PORT"
