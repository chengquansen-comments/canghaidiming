#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUTPUT_DIR="${1:-$PROJECT_ROOT/build/web}"
ZIP_PATH="${2:-${OUTPUT_DIR%/}.zip}"

"$PROJECT_ROOT/tools/export_web_build.sh" "$OUTPUT_DIR"
python3 "$PROJECT_ROOT/tools/validate_web_bundle.py" "$OUTPUT_DIR"
python3 "$PROJECT_ROOT/tools/report_web_bundle.py" "$OUTPUT_DIR"
python3 "$PROJECT_ROOT/tools/write_web_bundle_manifest.py" "$OUTPUT_DIR"
"$PROJECT_ROOT/tools/package_web_bundle.sh" "$OUTPUT_DIR" "$ZIP_PATH"
python3 "$PROJECT_ROOT/tools/write_web_bundle_checksums.py" "$OUTPUT_DIR" --zip "$ZIP_PATH"

echo "[web-build] bundle ready: $OUTPUT_DIR"
echo "[web-build] package ready: $ZIP_PATH"
