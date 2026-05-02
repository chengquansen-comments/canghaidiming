#!/usr/bin/env python3
from __future__ import annotations

import argparse

from art_asset_pipeline import (
    describe_runtime,
    export_runtime_image,
    note,
    ok,
    summarize_status,
    update_hook_table,
    update_manifest_status,
    validate_source_exists,
    get_manifest_entry,
    rel,
)


def main() -> int:
    parser = argparse.ArgumentParser(description="Promote one art asset from final source into runtime and hook tables.")
    parser.add_argument("asset_id", help="tables/art_asset_manifest.tsv asset_id")
    args = parser.parse_args()

    _, _, _, row, _ = get_manifest_entry(args.asset_id)
    source_path, runtime_path, profile = describe_runtime(row)
    validate_source_exists(source_path)
    output = export_runtime_image(source_path, runtime_path, profile)
    note(f"wrote {rel(runtime_path)} {output.width}x{output.height} {output.mode}")
    update_hook_table(row, runtime_path)
    previous, current = update_manifest_status(args.asset_id, "WIRED" if row.get("hook_table", "").strip() else "EXPORTED")
    ok(summarize_status(args.asset_id, previous, current))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
