#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUTPUT_DIR="${1:-$PROJECT_ROOT/build/web}"
ZIP_PATH="${2:-${OUTPUT_DIR%/}.zip}"

python3 "$PROJECT_ROOT/tools/package_web_bundle.py" "$OUTPUT_DIR" "$ZIP_PATH"
