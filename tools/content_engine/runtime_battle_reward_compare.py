#!/usr/bin/env python3
"""v0.9b battle_reward single-domain read-only compare report generator."""

from __future__ import annotations

import argparse
import csv
import json
import subprocess
from pathlib import Path


REPORT_TSV = Path("data/design/generated_runtime_battle_reward_compare_report.tsv")
REPORT_MD = Path("data/design/generated_runtime_battle_reward_compare_report.md")
MANIFEST_PATH = Path("data/runtime/content_engine/runtime_manifest.json")
CONFIG_PATH = Path("data/runtime/content_engine/runtime_loader_config.json")
RUNTIME_BATTLE_REWARD_PATH = Path("data/runtime/content_engine/battle_reward.json")
ALLOWED_RUNTIME_FILES = {
    "card_pool.json",
    "battle_reward.json",
    "runtime_manifest.json",
    "runtime_loader_config.json",
}
FIELDS = [
    "runtime_domain",
    "artifact_id",
    "runtime_path",
    "runtime_loaded",
    "runtime_record_count",
    "runtime_field_count",
    "legacy_source_status",
    "legacy_source_path",
    "legacy_record_count",
    "legacy_field_count",
    "compare_scope",
    "comparable",
    "schema_match_status",
    "record_count_match_status",
    "field_count_match_status",
    "missing_in_runtime_count",
    "extra_in_runtime_count",
    "changed_record_count",
    "read_only",
    "formal_data_source_replaced",
    "integration_status",
    "risk_level",
    "blocked_reason",
    "notes",
]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Generate runtime battle_reward read-only compare report.")
    parser.add_argument("--manifest", default=str(MANIFEST_PATH))
    parser.add_argument("--config", default=str(CONFIG_PATH))
    parser.add_argument("--runtime-battle-reward", default=str(RUNTIME_BATTLE_REWARD_PATH))
    parser.add_argument("--out", default=str(REPORT_TSV))
    parser.add_argument("--out-md", default=str(REPORT_MD))
    return parser.parse_args()


def read_json(path: Path) -> dict:
    data = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(data, dict):
        raise ValueError(f"{path} must be a JSON object")
    return data


def read_tsv_rows(path: Path) -> tuple[int, int]:
    with path.open("r", encoding="utf-8", newline="") as f:
        reader = csv.DictReader(f, delimiter="\t")
        rows = list(reader)
        fieldnames = reader.fieldnames or []
    return len(rows), len(fieldnames)


def detect_formal_source_replaced() -> bool:
    out = subprocess.check_output(["git", "status", "--porcelain"], text=True)
    changed = [line[3:] for line in out.splitlines() if len(line) > 3]
    high_risk = {
        "scripts/card_data.gd",
        "scripts/battle_state_machine.gd",
        "scripts/combat_resolver.gd",
    }
    if any(path in high_risk for path in changed):
        return True
    if any(path.startswith("scenes/") and path.endswith(".tscn") for path in changed):
        return True
    if any(path.startswith("data/story_battles/") and path.endswith(".tsv") for path in changed):
        return True
    return False


def match_status(eq: bool, comparable: bool) -> str:
    if not comparable:
        return "not_comparable"
    return "matched" if eq else "mismatched"


def main() -> int:
    args = parse_args()
    manifest_path = Path(args.manifest)
    config_path = Path(args.config)
    runtime_path = Path(args.runtime_battle_reward)
    out_tsv = Path(args.out)
    out_md = Path(args.out_md)

    blocked: list[str] = []

    # Required inputs
    if not manifest_path.exists():
        raise FileNotFoundError(f"Missing manifest: {manifest_path}")
    if not config_path.exists():
        raise FileNotFoundError(f"Missing config: {config_path}")
    if not runtime_path.exists():
        raise FileNotFoundError(f"Missing runtime battle_reward json: {runtime_path}")

    manifest = read_json(manifest_path)
    _config = read_json(config_path)
    runtime_payload = read_json(runtime_path)

    runtime_root = Path("data/runtime/content_engine")
    runtime_names = {p.name for p in runtime_root.iterdir() if p.is_file()} if runtime_root.exists() else set()
    if runtime_names != ALLOWED_RUNTIME_FILES:
        blocked.append("runtime_dir_not_allowlisted")

    files = manifest.get("files", [])
    if not isinstance(files, list):
        raise ValueError("runtime_manifest.json files must be list")

    battle_entries = [
        x for x in files
        if isinstance(x, dict)
        and str(x.get("runtime_domain", "")) == "battle_reward"
        and str(x.get("file_name", "")) == "battle_reward.json"
    ]
    if len(battle_entries) != 1:
        raise ValueError(f"manifest battle_reward entry count must be 1, got {len(battle_entries)}")
    entry = battle_entries[0]

    runtime_domain = "battle_reward"
    artifact_id = str(entry.get("artifact_id", ""))
    runtime_loaded = True
    runtime_record_count = int(runtime_payload.get("record_count", 0))
    runtime_field_count = int(runtime_payload.get("field_count", 0))

    # Legacy source discovery: first use manifest source_design_path, then fallback scan.
    source_design_path = str(entry.get("source_design_path", ""))
    candidate_paths: list[Path] = []
    if source_design_path:
        candidate_paths.append(Path(source_design_path))
    candidate_paths.extend(sorted(Path("data/design").glob("*battle_reward*plan*.tsv")))

    existing_candidates: list[Path] = []
    seen = set()
    for p in candidate_paths:
        key = p.as_posix()
        if key in seen:
            continue
        seen.add(key)
        if p.exists():
            existing_candidates.append(p)

    legacy_source_status = "not_found"
    legacy_source_path = ""
    legacy_record_count = 0
    legacy_field_count = 0
    compare_scope = "runtime_only"
    comparable = False

    if source_design_path and Path(source_design_path).exists():
        legacy_source_status = "found"
        legacy_source_path = source_design_path
        legacy_record_count, legacy_field_count = read_tsv_rows(Path(source_design_path))
        compare_scope = "runtime_vs_legacy"
        comparable = True
    elif len(existing_candidates) == 1:
        legacy_source_status = "found"
        legacy_source_path = existing_candidates[0].as_posix()
        legacy_record_count, legacy_field_count = read_tsv_rows(existing_candidates[0])
        compare_scope = "runtime_vs_legacy"
        comparable = True
    elif len(existing_candidates) > 1:
        legacy_source_status = "ambiguous"
        legacy_source_path = ";".join(p.as_posix() for p in existing_candidates)
        compare_scope = "legacy_source_ambiguous"
        blocked.append("legacy_source_ambiguous")
    else:
        legacy_source_status = "not_found"
        compare_scope = "runtime_only"
        blocked.append("legacy_source_not_found")

    schema_match_status = match_status(runtime_payload.get("schema_fingerprint", "") != "", comparable)
    record_count_match_status = match_status(runtime_record_count == legacy_record_count, comparable)
    field_count_match_status = match_status(runtime_field_count == legacy_field_count, comparable)

    missing_in_runtime_count = legacy_record_count if comparable and runtime_record_count < legacy_record_count else 0
    extra_in_runtime_count = runtime_record_count - legacy_record_count if comparable and runtime_record_count > legacy_record_count else 0
    changed_record_count = min(runtime_record_count, legacy_record_count) if comparable and runtime_record_count != legacy_record_count else 0

    formal_data_source_replaced = detect_formal_source_replaced()
    if formal_data_source_replaced:
        blocked.append("formal_data_source_replaced")

    read_only = True
    integration_status = "compare_only"
    risk_level = "low"
    if blocked:
        # legacy source ambiguity/not_found are non-blocking for v0.9b, keep medium.
        if any(x in {"runtime_dir_not_allowlisted", "formal_data_source_replaced"} for x in blocked):
            risk_level = "high"
        else:
            risk_level = "medium"

    row = {
        "runtime_domain": runtime_domain,
        "artifact_id": artifact_id,
        "runtime_path": runtime_path.as_posix(),
        "runtime_loaded": "true" if runtime_loaded else "false",
        "runtime_record_count": str(runtime_record_count),
        "runtime_field_count": str(runtime_field_count),
        "legacy_source_status": legacy_source_status,
        "legacy_source_path": legacy_source_path,
        "legacy_record_count": str(legacy_record_count),
        "legacy_field_count": str(legacy_field_count),
        "compare_scope": compare_scope,
        "comparable": "true" if comparable else "false",
        "schema_match_status": schema_match_status,
        "record_count_match_status": record_count_match_status,
        "field_count_match_status": field_count_match_status,
        "missing_in_runtime_count": str(missing_in_runtime_count),
        "extra_in_runtime_count": str(extra_in_runtime_count),
        "changed_record_count": str(changed_record_count),
        "read_only": "true",
        "formal_data_source_replaced": "true" if formal_data_source_replaced else "false",
        "integration_status": integration_status,
        "risk_level": risk_level,
        "blocked_reason": ",".join(sorted(set(blocked))),
        "notes": "v0.9b compare-only report; no reward logic replacement and no main-flow integration.",
    }

    out_tsv.parent.mkdir(parents=True, exist_ok=True)
    with out_tsv.open("w", encoding="utf-8", newline="") as f:
        w = csv.DictWriter(f, fieldnames=FIELDS, delimiter="\t", lineterminator="\n")
        w.writeheader()
        w.writerow(row)

    lines = [
        "# Runtime Battle Reward Compare Report",
        "",
        "- Stage: v0.9b battle_reward single-domain read-only compare",
        f"- runtime_domain: {row['runtime_domain']}",
        f"- runtime_loaded: {row['runtime_loaded']}",
        f"- legacy_source_status: {row['legacy_source_status']}",
        f"- compare_scope: {row['compare_scope']}",
        f"- comparable: {row['comparable']}",
        f"- blocked_reason: {row['blocked_reason'] or 'none'}",
        "",
        "## Compare Row",
        "",
        "| Runtime Domain | Artifact ID | Runtime Record Count | Runtime Field Count | Legacy Source Status | Legacy Source Path | Legacy Record Count | Legacy Field Count | Comparable |",
        "|---|---|---|---|---|---|---|---|---|",
        (
            f"| {row['runtime_domain']} | {row['artifact_id']} | {row['runtime_record_count']} | {row['runtime_field_count']} | "
            f"{row['legacy_source_status']} | {row['legacy_source_path']} | {row['legacy_record_count']} | {row['legacy_field_count']} | {row['comparable']} |"
        ),
        "",
        "## Diff Summary",
        "",
        f"- schema_match_status: {row['schema_match_status']}",
        f"- record_count_match_status: {row['record_count_match_status']}",
        f"- field_count_match_status: {row['field_count_match_status']}",
        f"- missing_in_runtime_count: {row['missing_in_runtime_count']}",
        f"- extra_in_runtime_count: {row['extra_in_runtime_count']}",
        f"- changed_record_count: {row['changed_record_count']}",
        "",
    ]
    out_md.parent.mkdir(parents=True, exist_ok=True)
    out_md.write_text("\n".join(lines), encoding="utf-8")

    print(f"Wrote {out_tsv} and {out_md}.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
