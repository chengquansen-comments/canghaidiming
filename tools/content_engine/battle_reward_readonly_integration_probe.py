#!/usr/bin/env python3
"""运行 battle_reward 受控只读接入试验并生成报告。"""

from __future__ import annotations

import argparse
import csv
import json
import subprocess
from pathlib import Path


BEGIN_MARKER = "BATTLE_REWARD_READONLY_INTEGRATION_PROBE_JSON_BEGIN"
END_MARKER = "BATTLE_REWARD_READONLY_INTEGRATION_PROBE_JSON_END"
PROBE_SCRIPT = "tools/content_engine/battle_reward_readonly_integration_probe.gd"
REPORT_TSV = Path("data/design/generated_battle_reward_readonly_integration_probe_report.tsv")
REPORT_MD = Path("data/design/generated_battle_reward_readonly_integration_probe_report.md")
FIELDS = [
    "runtime_domain",
    "godot_exit_code",
    "probe_ok",
    "manifest_loaded",
    "manifest_valid",
    "runtime_loaded",
    "runtime_record_count",
    "legacy_record_count",
    "record_count_match_status",
    "field_count_match_status",
    "missing_in_runtime_count",
    "extra_in_runtime_count",
    "changed_record_count",
    "config_enabled",
    "integration_mode",
    "read_only",
    "formal_data_source_replaced",
    "combat_flow_touched",
    "battle_state_touched",
    "card_pool_out_of_scope",
    "existing_gd_reference_count",
    "integration_status",
    "risk_level",
    "blocked_reason",
    "notes",
]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="运行 battle_reward 受控只读接入试验并产出报告。")
    parser.add_argument("--godot-cmd", default="godot")
    parser.add_argument("--probe-script", default=PROBE_SCRIPT)
    parser.add_argument("--out", default=str(REPORT_TSV))
    parser.add_argument("--out-md", default=str(REPORT_MD))
    return parser.parse_args()


def parse_marker_payload(stdout: str) -> dict[str, object]:
    start = stdout.find(BEGIN_MARKER)
    end = stdout.find(END_MARKER)
    if start < 0 or end < 0 or end <= start:
        raise ValueError("probe output missing JSON marker")
    payload_text = stdout[start + len(BEGIN_MARKER):end].strip()
    payload = json.loads(payload_text)
    if not isinstance(payload, dict):
        raise ValueError("probe payload must be JSON object")
    return payload


def bool_text(flag: object) -> str:
    return "true" if bool(flag) else "false"


def safe_int(value: object) -> int:
    try:
        return int(value)
    except (TypeError, ValueError):
        return 0


def count_existing_gd_references() -> int:
    targets = [
        "content_engine_runtime_loader.gd",
        "ContentEngineRuntimeLoader",
        "content_engine_runtime_gate.gd",
        "ContentEngineRuntimeGate",
        "content_engine_battle_reward_probe.gd",
        "CONTENT_ENGINE_BATTLE_REWARD_PROBE_JSON_BEGIN",
        "battle_reward_readonly_integration_probe.gd",
        "BATTLE_REWARD_READONLY_INTEGRATION_PROBE_JSON_BEGIN",
    ]
    excluded = {"content_engine_runtime_loader.gd", "content_engine_runtime_gate.gd"}
    count = 0
    for gd in Path("scripts").glob("*.gd"):
        if gd.name in excluded:
            continue
        text = gd.read_text(encoding="utf-8")
        if any(token in text for token in targets):
            count += 1
    return count


def compute_blocked_reason(row: dict[str, str]) -> list[str]:
    blocked: list[str] = []
    if row["godot_exit_code"] != "0":
        blocked.append("godot_exit_nonzero")
    if row["probe_ok"] != "true":
        blocked.append("probe_not_ok")
    if row["manifest_loaded"] != "true":
        blocked.append("manifest_not_loaded")
    if row["manifest_valid"] != "true":
        blocked.append("manifest_invalid")
    if row["runtime_loaded"] != "true":
        blocked.append("runtime_not_loaded")
    if row["record_count_match_status"] != "matched":
        blocked.append("record_count_mismatched")
    if row["field_count_match_status"] != "matched":
        blocked.append("field_count_mismatched")
    if row["missing_in_runtime_count"] != "0":
        blocked.append("missing_in_runtime")
    if row["extra_in_runtime_count"] != "0":
        blocked.append("extra_in_runtime")
    if row["config_enabled"] != "false":
        blocked.append("config_enabled")
    if row["integration_mode"] != "disabled":
        blocked.append("integration_mode_not_disabled")
    if row["read_only"] != "true":
        blocked.append("read_only_false")
    if row["formal_data_source_replaced"] != "false":
        blocked.append("formal_data_source_replaced")
    if row["combat_flow_touched"] != "false":
        blocked.append("combat_flow_touched")
    if row["battle_state_touched"] != "false":
        blocked.append("battle_state_touched")
    if row["card_pool_out_of_scope"] != "true":
        blocked.append("card_pool_scope_invalid")
    if row["existing_gd_reference_count"] != "0":
        blocked.append("existing_gd_references_found")
    if row["integration_status"] != "readonly_probe_only":
        blocked.append("integration_status_invalid")
    return blocked


def write_tsv(path: Path, row: dict[str, str]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=FIELDS, delimiter="\t", lineterminator="\n")
        writer.writeheader()
        writer.writerow(row)


def write_md(path: Path, row: dict[str, str]) -> None:
    lines = [
        "# Battle Reward 受控只读接入试验报告",
        "",
        "- 阶段：battle_reward_readonly_integration_probe",
        f"- godot_exit_code: {row['godot_exit_code']}",
        f"- probe_ok: {row['probe_ok']}",
        f"- runtime_record_count: {row['runtime_record_count']}",
        f"- legacy_record_count: {row['legacy_record_count']}",
        f"- record_count_match_status: {row['record_count_match_status']}",
        f"- field_count_match_status: {row['field_count_match_status']}",
        f"- blocked_reason: {row['blocked_reason'] or 'none'}",
        "",
        "## 关键边界",
        "",
        f"- config_enabled: {row['config_enabled']}",
        f"- integration_mode: {row['integration_mode']}",
        f"- read_only: {row['read_only']}",
        f"- formal_data_source_replaced: {row['formal_data_source_replaced']}",
        f"- combat_flow_touched: {row['combat_flow_touched']}",
        f"- battle_state_touched: {row['battle_state_touched']}",
        f"- card_pool_out_of_scope: {row['card_pool_out_of_scope']}",
        f"- existing_gd_reference_count: {row['existing_gd_reference_count']}",
        f"- integration_status: {row['integration_status']}",
        "",
        "## 结论",
        "",
        f"- {row['notes']}",
        "",
    ]
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(lines), encoding="utf-8")


def main() -> int:
    args = parse_args()
    cmd = [args.godot_cmd, "--headless", "--path", ".", "--script", args.probe_script]
    proc = subprocess.run(cmd, capture_output=True, text=True)

    parse_error = ""
    try:
        payload = parse_marker_payload(proc.stdout)
    except (ValueError, json.JSONDecodeError) as exc:
        parse_error = str(exc)
        payload = {
            "ok": False,
            "runtime_domain": "battle_reward",
            "runtime_record_count": 0,
            "legacy_record_count": 0,
            "record_count_match_status": "mismatched",
            "field_count_match_status": "mismatched",
            "missing_in_runtime_count": 0,
            "extra_in_runtime_count": 0,
            "changed_record_count": 0,
            "manifest_loaded": False,
            "manifest_valid": False,
            "runtime_loaded": False,
            "config_enabled": False,
            "integration_mode": "disabled",
            "read_only": True,
            "formal_data_source_replaced": False,
            "combat_flow_touched": False,
            "battle_state_touched": False,
            "card_pool_out_of_scope": True,
            "integration_status": "readonly_probe_only",
            "error_count": 1,
            "errors": [f"probe_parse_error:{exc}"],
        }

    row = {
        "runtime_domain": str(payload.get("runtime_domain", "battle_reward")),
        "godot_exit_code": str(proc.returncode),
        "probe_ok": bool_text(payload.get("ok", False)),
        "manifest_loaded": bool_text(payload.get("manifest_loaded", False)),
        "manifest_valid": bool_text(payload.get("manifest_valid", False)),
        "runtime_loaded": bool_text(payload.get("runtime_loaded", False)),
        "runtime_record_count": str(safe_int(payload.get("runtime_record_count", 0))),
        "legacy_record_count": str(safe_int(payload.get("legacy_record_count", 0))),
        "record_count_match_status": str(payload.get("record_count_match_status", "mismatched")),
        "field_count_match_status": str(payload.get("field_count_match_status", "mismatched")),
        "missing_in_runtime_count": str(safe_int(payload.get("missing_in_runtime_count", 0))),
        "extra_in_runtime_count": str(safe_int(payload.get("extra_in_runtime_count", 0))),
        "changed_record_count": str(safe_int(payload.get("changed_record_count", 0))),
        "config_enabled": bool_text(payload.get("config_enabled", False)),
        "integration_mode": str(payload.get("integration_mode", "disabled")),
        "read_only": bool_text(payload.get("read_only", False)),
        "formal_data_source_replaced": bool_text(payload.get("formal_data_source_replaced", False)),
        "combat_flow_touched": bool_text(payload.get("combat_flow_touched", False)),
        "battle_state_touched": bool_text(payload.get("battle_state_touched", False)),
        "card_pool_out_of_scope": bool_text(payload.get("card_pool_out_of_scope", False)),
        "existing_gd_reference_count": str(count_existing_gd_references()),
        "integration_status": str(payload.get("integration_status", "readonly_probe_only")),
        "risk_level": "low",
        "blocked_reason": "",
        "notes": "本试验仅做 battle_reward 受控只读对齐验证，不接入正式奖励逻辑，不替换正式数据源。",
    }

    blocked = compute_blocked_reason(row)
    if parse_error:
        blocked.append("probe_output_parse_failed")
        row["notes"] = f"{row['notes']} parse_error={parse_error}"
    row["blocked_reason"] = ",".join(sorted(set(blocked)))
    row["risk_level"] = "low" if not blocked else ("high" if row["godot_exit_code"] != "0" else "medium")

    write_tsv(Path(args.out), row)
    write_md(Path(args.out_md), row)
    print(f"Wrote {args.out} and {args.out_md}.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
