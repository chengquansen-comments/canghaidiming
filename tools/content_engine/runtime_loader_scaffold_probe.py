#!/usr/bin/env python3
"""Static probe for v0.8e read-only Godot loader scaffold."""

from __future__ import annotations

import argparse
import csv
import json
from pathlib import Path

from runtime_export_manifest import MANIFEST_JSON
from runtime_exporter import RUNTIME_DIR


OUTPUT_TSV = "generated_runtime_loader_scaffold_report.tsv"
OUTPUT_MD = "generated_runtime_loader_scaffold_report.md"
OUTPUT_FIELDS = [
    "scaffold_file",
    "manifest_path",
    "allowed_runtime_files",
    "manifest_first",
    "direct_runtime_read_disallowed",
    "fail_closed",
    "write_api_present",
    "existing_gd_reference_count",
    "integration_status",
    "runtime_dir_file_count",
    "runtime_dir_allowed_only",
    "risk_level",
    "blocked_reason",
    "notes",
]
SCAFFOLD_PATH = Path("scripts/content_engine_runtime_loader.gd")
MANIFEST_PATH = Path(f"data/runtime/content_engine/{MANIFEST_JSON}")
ALLOWED_RUNTIME_FILES = {"card_pool.json", "battle_reward.json", MANIFEST_JSON, "runtime_loader_config.json"}
WRITE_API_TOKENS = ["FileAccess.WRITE", "store_string", "store_var", "DirAccess.make_dir_recursive"]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Probe runtime loader scaffold constraints.")
    parser.add_argument("--scaffold", default=str(SCAFFOLD_PATH))
    parser.add_argument("--manifest", default=str(MANIFEST_PATH))
    parser.add_argument("--runtime-dir", default=str(RUNTIME_DIR))
    parser.add_argument("--out", default=f"data/design/{OUTPUT_TSV}")
    parser.add_argument("--out-md", default=f"data/design/{OUTPUT_MD}")
    return parser.parse_args()


def bool_text(flag: bool) -> str:
    return "true" if flag else "false"


def count_existing_gd_references(scaffold_name: str, scripts_dir: Path) -> int:
    count = 0
    for gd_file in scripts_dir.glob("*.gd"):
        if gd_file.name == scaffold_name:
            continue
        text = gd_file.read_text(encoding="utf-8")
        if scaffold_name in text or "ContentEngineRuntimeLoader" in text:
            count += 1
    return count


def main() -> int:
    args = parse_args()
    scaffold = Path(args.scaffold)
    manifest = Path(args.manifest)
    runtime_dir = Path(args.runtime_dir)
    out_tsv = Path(args.out)
    out_md = Path(args.out_md)

    blocked_reasons: list[str] = []
    notes: list[str] = []

    if not scaffold.exists():
        blocked_reasons.append("scaffold_missing")
        scaffold_text = ""
    else:
        scaffold_text = scaffold.read_text(encoding="utf-8")

    manifest_first = "load_manifest()" in scaffold_text and "validate_manifest(" in scaffold_text and "load_runtime_bundle()" in scaffold_text
    if not manifest_first:
        blocked_reasons.append("manifest_first_missing")

    direct_runtime_read_disallowed = (
        "res://data/runtime/content_engine/card_pool.json" not in scaffold_text
        and "res://data/runtime/content_engine/battle_reward.json" not in scaffold_text
    )
    if not direct_runtime_read_disallowed:
        blocked_reasons.append("direct_runtime_read_detected")

    fail_closed = "\"ok\": false" in scaffold_text and "return {\"ok\": false" in scaffold_text
    if not fail_closed:
        blocked_reasons.append("fail_closed_missing")

    write_api_present = any(token in scaffold_text for token in WRITE_API_TOKENS)
    if write_api_present:
        blocked_reasons.append("write_api_present")

    if not manifest.exists():
        blocked_reasons.append("manifest_missing")

    allowed_runtime_files = "card_pool.json,battle_reward.json,runtime_manifest.json,runtime_loader_config.json"

    scripts_dir = Path("scripts")
    reference_count = count_existing_gd_references(scaffold.name, scripts_dir)
    if reference_count > 0:
        blocked_reasons.append("existing_gd_references_found")

    runtime_file_names = {entry.name for entry in runtime_dir.iterdir() if entry.is_file()} if runtime_dir.exists() else set()
    runtime_dir_file_count = len(runtime_file_names)
    runtime_dir_allowed_only = runtime_file_names == ALLOWED_RUNTIME_FILES
    if not runtime_dir_allowed_only:
        blocked_reasons.append("runtime_dir_not_allowlisted")

    integration_status = "not_integrated"
    risk_level = "low" if not blocked_reasons else "medium"

    row = {
        "scaffold_file": scaffold.as_posix(),
        "manifest_path": manifest.as_posix(),
        "allowed_runtime_files": allowed_runtime_files,
        "manifest_first": bool_text(manifest_first),
        "direct_runtime_read_disallowed": bool_text(direct_runtime_read_disallowed),
        "fail_closed": bool_text(fail_closed),
        "write_api_present": bool_text(write_api_present),
        "existing_gd_reference_count": str(reference_count),
        "integration_status": integration_status,
        "runtime_dir_file_count": str(runtime_dir_file_count),
        "runtime_dir_allowed_only": bool_text(runtime_dir_allowed_only),
        "risk_level": risk_level,
        "blocked_reason": ",".join(sorted(set(blocked_reasons))),
        "notes": "; ".join(notes) or "v0.8e scaffold is read-only and not integrated into main battle flow.",
    }

    out_tsv.parent.mkdir(parents=True, exist_ok=True)
    with out_tsv.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=OUTPUT_FIELDS, delimiter="\t", lineterminator="\n")
        writer.writeheader()
        writer.writerow(row)

    lines = [
        "# Runtime Loader Scaffold Report",
        "",
        "- Stage: v0.8e read-only loader scaffold",
        f"- integration_status: {integration_status}",
        f"- blocked_reason: {row['blocked_reason']}",
        "",
        "## Probe Result",
        "",
        "| Scaffold File | Manifest First | Direct Runtime Read Disallowed | Fail Closed | Write API Present | Existing GD Reference Count | Integration Status | Runtime Dir Allowed Only |",
        "|---|---|---|---|---|---|---|---|",
        (
            f"| {row['scaffold_file']} | {row['manifest_first']} | {row['direct_runtime_read_disallowed']} | "
            f"{row['fail_closed']} | {row['write_api_present']} | {row['existing_gd_reference_count']} | "
            f"{row['integration_status']} | {row['runtime_dir_allowed_only']} |"
        ),
        "",
    ]
    out_md.parent.mkdir(parents=True, exist_ok=True)
    out_md.write_text("\n".join(lines), encoding="utf-8")

    print(f"Wrote {out_tsv} and {out_md}.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
