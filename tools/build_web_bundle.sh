#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUTPUT_DIR="${1:-$PROJECT_ROOT/build/web}"
ZIP_PATH="${2:-${OUTPUT_DIR%/}.zip}"
TOTAL_BUDGET_MB="${CANGHAI_WEB_TOTAL_BUDGET_MB:-64}"
PCK_BUDGET_MB="${CANGHAI_WEB_PCK_BUDGET_MB:-16}"
WASM_BUDGET_MB="${CANGHAI_WEB_WASM_BUDGET_MB:-40}"
SMOKE_PORT="${CANGHAI_WEB_SMOKE_PORT:-0}"

python3 "$PROJECT_ROOT/scripts/compile_tables.py"
python3 "$PROJECT_ROOT/tools/validate_performance_tracks.py"
godot --headless --path "$PROJECT_ROOT" --script "$PROJECT_ROOT/tools/smoke_battle_hud_helper.gd"
godot --headless --path "$PROJECT_ROOT" --script "$PROJECT_ROOT/tools/smoke_battle_round_core.gd"
"$PROJECT_ROOT/tools/export_web_build.sh" "$OUTPUT_DIR"
python3 "$PROJECT_ROOT/tools/validate_web_bundle.py" "$OUTPUT_DIR"
python3 "$PROJECT_ROOT/tools/report_web_bundle.py" "$OUTPUT_DIR"
python3 "$PROJECT_ROOT/tools/check_web_bundle_budget.py" "$OUTPUT_DIR" \
  --total-budget-mb "$TOTAL_BUDGET_MB" \
  --pck-budget-mb "$PCK_BUDGET_MB" \
  --wasm-budget-mb "$WASM_BUDGET_MB"
python3 "$PROJECT_ROOT/tools/write_web_bundle_manifest.py" "$OUTPUT_DIR"
"$PROJECT_ROOT/tools/package_web_bundle.sh" "$OUTPUT_DIR" "$ZIP_PATH"
python3 "$PROJECT_ROOT/tools/write_web_bundle_checksums.py" "$OUTPUT_DIR" --zip "$ZIP_PATH"
python3 "$PROJECT_ROOT/tools/smoke_test_web_bundle.py" "$OUTPUT_DIR" --zip "$ZIP_PATH" --port "$SMOKE_PORT"

echo "[web-build] bundle ready: $OUTPUT_DIR"
echo "[web-build] package ready: $ZIP_PATH"
