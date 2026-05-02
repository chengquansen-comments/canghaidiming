#!/usr/bin/env python3
from __future__ import annotations

import argparse
from pathlib import Path

from art_asset_pipeline import (
    MANIFEST_PATH,
    advance_status,
    fail,
    get_asset_type_spec,
    load_manifest,
    normalize_repo_path,
    ok,
    read_delimited,
    rel,
    save_manifest,
)


ROOT = Path(__file__).resolve().parents[1]
PROMPT_MANIFEST_PATH = ROOT / "tables" / "art_prompt_manifest.tsv"
BACKLOG_PATH = ROOT / "tables" / "art_backlog.tsv"


def load_prompt_entry(asset_id: str) -> dict[str, str]:
    if not PROMPT_MANIFEST_PATH.exists():
        fail(f"missing prompt manifest: {rel(PROMPT_MANIFEST_PATH)}")
    _, rows, _ = read_delimited(PROMPT_MANIFEST_PATH)
    for row in rows:
        if row.get("asset_id", "") == asset_id:
            return row
    fail(f"asset_id not found in {rel(PROMPT_MANIFEST_PATH)}: {asset_id}")


def load_backlog_entry(asset_id: str) -> dict[str, str] | None:
    if not BACKLOG_PATH.exists():
        return None
    _, rows, _ = read_delimited(BACKLOG_PATH)
    for row in rows:
        if row.get("asset_id", "") == asset_id:
            return row
    return None


def derive_source_path(runtime_path: str) -> str:
    path = normalize_repo_path(runtime_path)
    try:
        relative = path.relative_to(ROOT / "assets")
    except ValueError as exc:
        fail(f"target_output must live under assets/: {runtime_path} ({exc})")
    return str(Path("art_reference") / "final" / relative)


def derive_asset_row(prompt_row: dict[str, str]) -> dict[str, str]:
    asset_id = prompt_row.get("asset_id", "").strip()
    asset_type = prompt_row.get("prompt_type", "").strip()
    target_hook = prompt_row.get("target_hook", "").strip()
    runtime_path = prompt_row.get("target_output", "").strip()
    if asset_id == "" or asset_type == "" or target_hook == "" or runtime_path == "":
        fail(f"prompt row is incomplete for asset_id={asset_id or '<empty>'}")
    spec = get_asset_type_spec(asset_type)
    backlog_row = load_backlog_entry(asset_id)
    if backlog_row is not None:
        runtime_path = backlog_row.get("planned_runtime_path", "").strip() or runtime_path
        target_hook = backlog_row.get("target_id", "").strip() or target_hook
        source_path = backlog_row.get("planned_source_path", "").strip() or derive_source_path(runtime_path)
        hook_table = backlog_row.get("hook_table", "").strip() or spec.hook_table
        hook_key_field = backlog_row.get("hook_key_field", "").strip() or spec.hook_key_field
        hook_field = backlog_row.get("hook_field", "").strip() or spec.hook_field
    else:
        source_path = derive_source_path(runtime_path)
        hook_table = spec.hook_table
        hook_key_field = spec.hook_key_field
        hook_field = spec.hook_field
    status = "SOURCE_READY" if normalize_repo_path(source_path).exists() else "PROMPT_READY"
    note = prompt_row.get("note", "").strip() or f"Auto-created from {PROMPT_MANIFEST_PATH.name}"
    return {
        "asset_id": asset_id,
        "type": asset_type,
        "source_path": source_path,
        "runtime_path": runtime_path,
        "hook_table": hook_table,
        "hook_key_field": hook_key_field,
        "hook_id": target_hook,
        "hook_field": hook_field,
        "status": status,
        "note": note,
    }


def upsert_asset_row(asset_row: dict[str, str], update: bool) -> tuple[str, str]:
    fieldnames, rows, delimiter = load_manifest()
    asset_id = asset_row["asset_id"]
    for index, row in enumerate(rows):
        if row.get("asset_id", "") != asset_id:
            continue
        if not update:
            fail(
                f"asset_id already exists in {rel(MANIFEST_PATH)}: {asset_id} "
                "(rerun with --update to refresh it from art_prompt_manifest.tsv)"
            )
        asset_row["status"] = advance_status(row.get("status", "").strip(), asset_row.get("status", "").strip())
        rows[index] = {field: asset_row.get(field, "") for field in fieldnames}
        save_manifest(fieldnames, rows, delimiter)
        return "updated", asset_id

    rows.append({field: asset_row.get(field, "") for field in fieldnames})
    save_manifest(fieldnames, rows, delimiter)
    return "created", asset_id


def main() -> int:
    parser = argparse.ArgumentParser(description="Create or update one art asset task from tables/art_prompt_manifest.tsv.")
    parser.add_argument("asset_id", help="Prompt/asset id")
    parser.add_argument("--update", action="store_true", help="Refresh an existing asset task instead of failing")
    args = parser.parse_args()

    prompt_row = load_prompt_entry(args.asset_id)
    asset_row = derive_asset_row(prompt_row)
    action, asset_id = upsert_asset_row(asset_row, args.update)
    ok(
        f"{action} {asset_id}: "
        f"{asset_row['source_path']} -> {asset_row['runtime_path']} "
        f"hook {asset_row['hook_table']}:{asset_row['hook_key_field']}={asset_row['hook_id']}.{asset_row['hook_field']} "
        f"status={asset_row['status']}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
