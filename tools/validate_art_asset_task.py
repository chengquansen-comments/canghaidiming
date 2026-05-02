#!/usr/bin/env python3
from __future__ import annotations

import argparse

from art_asset_pipeline import (
    describe_runtime,
    detect_godot_import,
    get_manifest_entry,
    godot_import_is_stale,
    note,
    ok,
    parse_import_destinations,
    summarize_status,
    update_manifest_status,
    validate_compiled_value,
    validate_hook_table_value,
    validate_runtime_image,
)


def main() -> int:
    parser = argparse.ArgumentParser(description="Validate one art asset task from runtime file through compiled hook output.")
    parser.add_argument("asset_id", help="tables/art_asset_manifest.tsv asset_id")
    parser.add_argument("--require-import", action="store_true", help="Fail unless Godot .import and .ctex files already exist.")
    args = parser.parse_args()

    _, _, _, row, _ = get_manifest_entry(args.asset_id)
    _, runtime_path, _ = describe_runtime(row)
    width, height, mode = validate_runtime_image(row, runtime_path)
    validate_hook_table_value(row, runtime_path)
    compiled_path = validate_compiled_value(row, runtime_path)

    imported, import_path, ctex_matches = detect_godot_import(runtime_path)
    if args.require_import and not imported:
        raise SystemExit(
            f"[art-asset-pipeline] ERROR: Godot import artifacts missing for {runtime_path.name}; "
            "run: godot --headless --import --quit"
        )

    target_status = "GODOT_IMPORTED" if imported else "COMPILED"
    previous, current = update_manifest_status(args.asset_id, target_status)
    note(f"runtime OK: {runtime_path} {width}x{height} {mode}")
    note(f"compiled OK: {compiled_path}")
    if imported:
        note(f"godot import OK: {import_path} ({len(ctex_matches)} ctex)")
        for dest in parse_import_destinations(import_path):
            note(f"  {dest}")
        if godot_import_is_stale(runtime_path, ctex_matches):
            note("godot import warning: import artifacts are older than the runtime PNG; rerun `godot --headless --import --quit` if the image content changed")
    else:
        note("godot import pending: run `godot --headless --import --quit` to advance to GODOT_IMPORTED")
    ok(summarize_status(args.asset_id, previous, current))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
