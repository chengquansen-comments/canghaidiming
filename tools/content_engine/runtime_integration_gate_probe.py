#!/usr/bin/env python3
"""用于 Content Engine v0.9a 只读 integration gate 的静态/文本探针。"""

from __future__ import annotations

import argparse
import csv
import json
import subprocess
from pathlib import Path


REPORT_TSV = Path("data/design/generated_runtime_integration_gate_report.tsv")
REPORT_MD = Path("data/design/generated_runtime_integration_gate_report.md")
CONFIG_PATH = Path("data/runtime/content_engine/runtime_loader_config.json")
GATE_SCRIPT = Path("scripts/content_engine_runtime_gate.gd")
RUNTIME_ROOT = Path("data/runtime/content_engine")
ALLOWED_RUNTIME_FILES = {
    "card_pool.json",
    "battle_reward.json",
    "runtime_manifest.json",
    "runtime_loader_config.json",
}
FORBIDDEN_WRITE_TOKENS = [
    "FileAccess.WRITE",
    "store_string",
    "store_var",
    "DirAccess.make_dir_recursive",
]
REPORT_FIELDS = [
    "config_path",
    "gate_script",
    "content_engine_runtime_enabled",
    "read_only_probe_enabled",
    "integration_mode",
    "fallback_mode",
    "gate_status",
    "gate_default_disabled",
    "write_api_present",
    "existing_gd_reference_count",
    "formal_data_source_replaced",
    "runtime_dir_allowed_only",
    "risk_level",
    "blocked_reason",
    "notes",
]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="探测 v0.9a runtime integration gate 约束。")
    parser.add_argument("--config", default=str(CONFIG_PATH))
    parser.add_argument("--gate", default=str(GATE_SCRIPT))
    parser.add_argument("--runtime-dir", default=str(RUNTIME_ROOT))
    parser.add_argument("--out", default=str(REPORT_TSV))
    parser.add_argument("--out-md", default=str(REPORT_MD))
    return parser.parse_args()


def bool_text(flag: bool) -> str:
    return "true" if flag else "false"


def count_existing_gd_references(gate_script_name: str) -> int:
    scripts_dir = Path("scripts")
    count = 0
    for gd_file in scripts_dir.glob("*.gd"):
        if gd_file.name == gate_script_name:
            continue
        text = gd_file.read_text(encoding="utf-8")
        if gate_script_name in text or "ContentEngineRuntimeGate" in text:
            count += 1
    return count


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


def main() -> int:
    args = parse_args()
    config_path = Path(args.config)
    gate_script = Path(args.gate)
    runtime_dir = Path(args.runtime_dir)
    out_tsv = Path(args.out)
    out_md = Path(args.out_md)

    blocked_reasons: list[str] = []

    config = {}
    if not config_path.exists():
        blocked_reasons.append("config_missing")
    else:
        try:
            parsed = json.loads(config_path.read_text(encoding="utf-8"))
            if isinstance(parsed, dict):
                config = parsed
            else:
                blocked_reasons.append("config_not_object")
        except json.JSONDecodeError:
            blocked_reasons.append("config_parse_failed")

    content_engine_runtime_enabled = bool(config.get("content_engine_runtime_enabled", False))
    read_only_probe_enabled = bool(config.get("read_only_probe_enabled", False))
    integration_mode = str(config.get("integration_mode", ""))
    fallback_mode = str(config.get("fallback_mode", ""))

    gate_default_disabled = (
        (content_engine_runtime_enabled is False)
        and (read_only_probe_enabled is False)
        and integration_mode == "disabled"
        and fallback_mode == "existing_data_source"
    )
    if not gate_default_disabled:
        blocked_reasons.append("default_disabled_contract_broken")

    gate_text = ""
    if not gate_script.exists():
        blocked_reasons.append("gate_script_missing")
    else:
        gate_text = gate_script.read_text(encoding="utf-8")

    write_api_present = any(token in gate_text for token in FORBIDDEN_WRITE_TOKENS)
    if write_api_present:
        blocked_reasons.append("write_api_present")

    reference_count = count_existing_gd_references(gate_script.name)
    if reference_count != 0:
        blocked_reasons.append("existing_gd_references_found")

    runtime_names = {p.name for p in runtime_dir.iterdir() if p.is_file()} if runtime_dir.exists() else set()
    runtime_dir_allowed_only = runtime_names == ALLOWED_RUNTIME_FILES
    if not runtime_dir_allowed_only:
        blocked_reasons.append("runtime_dir_not_allowlisted")

    formal_data_source_replaced = detect_formal_source_replaced()
    if formal_data_source_replaced:
        blocked_reasons.append("formal_data_source_replaced")

    gate_status = "disabled" if gate_default_disabled else "blocked"
    risk_level = "low" if not blocked_reasons else "medium"
    notes = (
        "v0.9a gate scaffold is read-only, default disabled, and not integrated into main battle flow."
    )

    row = {
        "config_path": config_path.as_posix(),
        "gate_script": gate_script.as_posix(),
        "content_engine_runtime_enabled": bool_text(content_engine_runtime_enabled),
        "read_only_probe_enabled": bool_text(read_only_probe_enabled),
        "integration_mode": integration_mode,
        "fallback_mode": fallback_mode,
        "gate_status": gate_status,
        "gate_default_disabled": bool_text(gate_default_disabled),
        "write_api_present": bool_text(write_api_present),
        "existing_gd_reference_count": str(reference_count),
        "formal_data_source_replaced": bool_text(formal_data_source_replaced),
        "runtime_dir_allowed_only": bool_text(runtime_dir_allowed_only),
        "risk_level": risk_level,
        "blocked_reason": ",".join(sorted(set(blocked_reasons))),
        "notes": notes,
    }

    out_tsv.parent.mkdir(parents=True, exist_ok=True)
    with out_tsv.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=REPORT_FIELDS, delimiter="\t", lineterminator="\n")
        writer.writeheader()
        writer.writerow(row)

    lines = [
        "# Runtime Integration Gate 报告",
        "",
        "- 阶段：v0.9a 只读 integration gate",
        f"- gate_status: {row['gate_status']}",
        f"- gate_default_disabled: {row['gate_default_disabled']}",
        f"- runtime_dir_allowed_only: {row['runtime_dir_allowed_only']}",
        f"- blocked_reason: {row['blocked_reason'] or 'none'}",
        "",
        "## Gate 结果行",
        "",
        "| Config Path | Gate Script | Runtime Enabled | Probe Enabled | Integration Mode | Fallback Mode | Gate Status | Write API Present | Existing GD Reference Count |",
        "|---|---|---|---|---|---|---|---|---|",
        (
            f"| {row['config_path']} | {row['gate_script']} | {row['content_engine_runtime_enabled']} | "
            f"{row['read_only_probe_enabled']} | {row['integration_mode']} | {row['fallback_mode']} | "
            f"{row['gate_status']} | {row['write_api_present']} | {row['existing_gd_reference_count']} |"
        ),
        "",
    ]
    out_md.parent.mkdir(parents=True, exist_ok=True)
    out_md.write_text("\n".join(lines), encoding="utf-8")

    print(f"Wrote {out_tsv} and {out_md}.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
