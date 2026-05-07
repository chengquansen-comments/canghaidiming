#!/usr/bin/env python3
"""v0.9d battle_reward 只读 Godot compare/probe 报告生成器。"""

from __future__ import annotations

import argparse
import csv
import json
import subprocess
from pathlib import Path


BEGIN_MARKER = "CONTENT_ENGINE_BATTLE_REWARD_PROBE_JSON_BEGIN"
END_MARKER = "CONTENT_ENGINE_BATTLE_REWARD_PROBE_JSON_END"
PROBE_SCRIPT = "tools/content_engine/content_engine_battle_reward_probe.gd"
PLAN_TSV = Path("data/design/generated_battle_reward_plan.tsv")
RUNTIME_JSON = Path("data/runtime/content_engine/battle_reward.json")
COMPARE_TSV = Path("data/design/generated_runtime_battle_reward_compare_report.tsv")
CONFIG_JSON = Path("data/runtime/content_engine/runtime_loader_config.json")
REPORT_TSV = Path("data/design/generated_runtime_battle_reward_godot_compare_report.tsv")
REPORT_MD = Path("data/design/generated_runtime_battle_reward_godot_compare_report.md")

REPORT_FIELDS = [
    "runtime_domain",
    "godot_probe_exit_code",
    "godot_probe_ok",
    "manifest_loaded",
    "manifest_valid",
    "runtime_loaded",
    "godot_runtime_record_count",
    "python_runtime_record_count",
    "legacy_record_count",
    "godot_runtime_field_count",
    "python_runtime_field_count",
    "record_count_match_status",
    "field_count_match_status",
    "missing_in_godot_count",
    "extra_in_godot_count",
    "changed_record_count",
    "manifest_first",
    "read_only",
    "formal_data_source_replaced",
    "integration_status",
    "gate_config_enabled",
    "gate_integration_mode",
    "existing_gd_reference_count",
    "risk_level",
    "blocked_reason",
    "notes",
]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="运行 Godot battle_reward probe 并生成 v0.9d compare 报告。")
    parser.add_argument("--godot-cmd", default="godot")
    parser.add_argument("--probe-script", default=PROBE_SCRIPT)
    parser.add_argument("--plan-tsv", default=str(PLAN_TSV))
    parser.add_argument("--runtime-json", default=str(RUNTIME_JSON))
    parser.add_argument("--compare-tsv", default=str(COMPARE_TSV))
    parser.add_argument("--config-json", default=str(CONFIG_JSON))
    parser.add_argument("--out", default=str(REPORT_TSV))
    parser.add_argument("--out-md", default=str(REPORT_MD))
    return parser.parse_args()


def read_json_dict(path: Path) -> dict:
    payload = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(payload, dict):
        raise ValueError(f"{path} 必须是 JSON object")
    return payload


def parse_tsv_rows(path: Path) -> tuple[list[dict[str, str]], list[str]]:
    with path.open("r", encoding="utf-8", newline="") as f:
        reader = csv.DictReader(f, delimiter="\t")
        rows = list(reader)
        fields = reader.fieldnames or []
    return rows, fields


def parse_probe_payload(stdout: str) -> dict[str, object]:
    start = stdout.find(BEGIN_MARKER)
    end = stdout.find(END_MARKER)
    if start < 0 or end < 0 or end <= start:
        raise ValueError("probe 输出缺少 JSON marker")
    content = stdout[start + len(BEGIN_MARKER):end].strip()
    payload = json.loads(content)
    if not isinstance(payload, dict):
        raise ValueError("probe payload 必须是 JSON object")
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
    ]
    scripts_dir = Path("scripts")
    excluded = {
        "content_engine_runtime_loader.gd",
        "content_engine_runtime_gate.gd",
        "content_engine_battle_reward_probe.gd",
    }
    count = 0
    for gd in scripts_dir.glob("*.gd"):
        if gd.name in excluded:
            continue
        text = gd.read_text(encoding="utf-8")
        if any(token in text for token in targets):
            count += 1
    return count


def build_blocked_reasons(row: dict[str, str]) -> list[str]:
    blocked: list[str] = []
    if row["godot_probe_exit_code"] != "0":
        blocked.append("godot_probe_exit_nonzero")
    if row["godot_probe_ok"] != "true":
        blocked.append("godot_probe_not_ok")
    if row["manifest_loaded"] != "true":
        blocked.append("manifest_not_loaded")
    if row["manifest_valid"] != "true":
        blocked.append("manifest_invalid")
    if row["runtime_loaded"] != "true":
        blocked.append("runtime_not_loaded")
    if row["record_count_match_status"] != "matched":
        blocked.append("record_count_mismatch")
    if row["field_count_match_status"] != "matched":
        blocked.append("field_count_mismatch")
    if row["missing_in_godot_count"] != "0":
        blocked.append("missing_in_godot")
    if row["extra_in_godot_count"] != "0":
        blocked.append("extra_in_godot")
    if row["manifest_first"] != "true":
        blocked.append("manifest_first_broken")
    if row["read_only"] != "true":
        blocked.append("read_only_broken")
    if row["formal_data_source_replaced"] != "false":
        blocked.append("formal_data_source_replaced")
    if row["integration_status"] != "godot_compare_only":
        blocked.append("integration_status_invalid")
    if row["gate_config_enabled"] != "false":
        blocked.append("gate_config_enabled")
    if row["gate_integration_mode"] != "disabled":
        blocked.append("gate_mode_not_disabled")
    if row["existing_gd_reference_count"] != "0":
        blocked.append("existing_gd_references_found")
    return blocked


def write_tsv(path: Path, row: dict[str, str]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=REPORT_FIELDS, delimiter="\t", lineterminator="\n")
        writer.writeheader()
        writer.writerow(row)


def write_md(path: Path, row: dict[str, str]) -> None:
    lines = [
        "# Runtime Battle Reward Godot 对比报告",
        "",
        "- 阶段：v0.9d battle_reward read-only Godot compare/probe",
        f"- runtime_domain: {row['runtime_domain']}",
        f"- godot_probe_exit_code: {row['godot_probe_exit_code']}",
        f"- godot_probe_ok: {row['godot_probe_ok']}",
        f"- record_count_match_status: {row['record_count_match_status']}",
        f"- field_count_match_status: {row['field_count_match_status']}",
        f"- blocked_reason: {row['blocked_reason'] or 'none'}",
        "",
        "## 对比结果行",
        "",
        "| Runtime Domain | Godot Records | Python Records | Legacy Records | Godot Fields | Python Fields | Record Match | Field Match | Missing In Godot | Extra In Godot |",
        "|---|---|---|---|---|---|---|---|---|---|",
        (
            f"| {row['runtime_domain']} | {row['godot_runtime_record_count']} | {row['python_runtime_record_count']} | "
            f"{row['legacy_record_count']} | {row['godot_runtime_field_count']} | {row['python_runtime_field_count']} | "
            f"{row['record_count_match_status']} | {row['field_count_match_status']} | {row['missing_in_godot_count']} | {row['extra_in_godot_count']} |"
        ),
        "",
        "## 边界检查",
        "",
        f"- manifest_first: {row['manifest_first']}",
        f"- read_only: {row['read_only']}",
        f"- formal_data_source_replaced: {row['formal_data_source_replaced']}",
        f"- integration_status: {row['integration_status']}",
        f"- gate_config_enabled: {row['gate_config_enabled']}",
        f"- gate_integration_mode: {row['gate_integration_mode']}",
        f"- existing_gd_reference_count: {row['existing_gd_reference_count']}",
        "",
        "## 说明",
        "",
        f"- {row['notes']}",
        "",
    ]
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(lines), encoding="utf-8")


def main() -> int:
    args = parse_args()
    plan_path = Path(args.plan_tsv)
    runtime_path = Path(args.runtime_json)
    compare_path = Path(args.compare_tsv)
    config_path = Path(args.config_json)

    for path in [plan_path, runtime_path, compare_path, config_path]:
        if not path.exists():
            raise FileNotFoundError(f"缺少必需输入：{path}")

    cmd = [args.godot_cmd, "--headless", "--path", ".", "--script", args.probe_script]
    proc = subprocess.run(cmd, capture_output=True, text=True)

    probe_payload: dict[str, object]
    probe_parse_error = ""
    try:
        probe_payload = parse_probe_payload(proc.stdout)
    except (ValueError, json.JSONDecodeError) as exc:
        probe_parse_error = str(exc)
        probe_payload = {
            "ok": False,
            "runtime_domain": "battle_reward",
            "manifest_loaded": False,
            "manifest_valid": False,
            "runtime_loaded": False,
            "runtime_record_count": 0,
            "runtime_field_count": 0,
            "loaded_record_ids": [],
            "error_count": 1,
            "errors": [f"probe_output_parse_failed:{exc}"],
            "manifest_first": True,
            "read_only": True,
            "formal_data_source_replaced": False,
            "integration_status": "godot_compare_only",
        }

    plan_rows, plan_fields = parse_tsv_rows(plan_path)
    runtime_payload = read_json_dict(runtime_path)
    compare_rows, _compare_fields = parse_tsv_rows(compare_path)
    config_payload = read_json_dict(config_path)

    python_runtime_record_count = safe_int(runtime_payload.get("record_count", 0))
    python_runtime_field_count = safe_int(runtime_payload.get("field_count", 0))
    legacy_record_count = len(plan_rows)
    legacy_ids = {row.get("reward_plan_id", "") for row in plan_rows if row.get("reward_plan_id", "")}

    godot_record_count = safe_int(probe_payload.get("runtime_record_count", 0))
    godot_field_count = safe_int(probe_payload.get("runtime_field_count", 0))
    godot_ids_raw = probe_payload.get("loaded_record_ids", [])
    godot_ids = {str(x) for x in godot_ids_raw} if isinstance(godot_ids_raw, list) else set()

    missing_in_godot_count = len(legacy_ids - godot_ids) if legacy_ids else max(legacy_record_count - godot_record_count, 0)
    extra_in_godot_count = len(godot_ids - legacy_ids) if legacy_ids else max(godot_record_count - legacy_record_count, 0)
    changed_record_count = 0 if (missing_in_godot_count == 0 and extra_in_godot_count == 0) else (missing_in_godot_count + extra_in_godot_count)

    record_matched = (
        godot_record_count == python_runtime_record_count
        and python_runtime_record_count == legacy_record_count
        and missing_in_godot_count == 0
        and extra_in_godot_count == 0
    )
    field_matched = godot_field_count == python_runtime_field_count and python_runtime_field_count == len(plan_fields)

    compare_integration_status = ""
    if compare_rows:
        compare_integration_status = compare_rows[0].get("integration_status", "")

    gate_config_enabled = bool(config_payload.get("content_engine_runtime_enabled", False))
    gate_integration_mode = str(config_payload.get("integration_mode", ""))
    existing_gd_reference_count = count_existing_gd_references()

    notes = "v0.9d 仅做 battle_reward Godot 只读探针对比，不接入正式奖励逻辑，不替换正式数据源。"
    if compare_integration_status:
        notes = f"{notes} Python compare integration_status={compare_integration_status}。"
    if probe_parse_error:
        notes = f"{notes} probe_parse_error={probe_parse_error}。"

    row = {
        "runtime_domain": str(probe_payload.get("runtime_domain", "battle_reward")),
        "godot_probe_exit_code": str(proc.returncode),
        "godot_probe_ok": bool_text(probe_payload.get("ok", False)),
        "manifest_loaded": bool_text(probe_payload.get("manifest_loaded", False)),
        "manifest_valid": bool_text(probe_payload.get("manifest_valid", False)),
        "runtime_loaded": bool_text(probe_payload.get("runtime_loaded", False)),
        "godot_runtime_record_count": str(godot_record_count),
        "python_runtime_record_count": str(python_runtime_record_count),
        "legacy_record_count": str(legacy_record_count),
        "godot_runtime_field_count": str(godot_field_count),
        "python_runtime_field_count": str(python_runtime_field_count),
        "record_count_match_status": "matched" if record_matched else "mismatched",
        "field_count_match_status": "matched" if field_matched else "mismatched",
        "missing_in_godot_count": str(missing_in_godot_count),
        "extra_in_godot_count": str(extra_in_godot_count),
        "changed_record_count": str(changed_record_count),
        "manifest_first": bool_text(probe_payload.get("manifest_first", False)),
        "read_only": bool_text(probe_payload.get("read_only", False)),
        "formal_data_source_replaced": bool_text(probe_payload.get("formal_data_source_replaced", False)),
        "integration_status": str(probe_payload.get("integration_status", "godot_compare_only")),
        "gate_config_enabled": bool_text(gate_config_enabled),
        "gate_integration_mode": gate_integration_mode,
        "existing_gd_reference_count": str(existing_gd_reference_count),
        "risk_level": "low",
        "blocked_reason": "",
        "notes": notes,
    }

    blocked = build_blocked_reasons(row)
    row["blocked_reason"] = ",".join(blocked)
    row["risk_level"] = "low" if not blocked else ("high" if "godot_probe_exit_nonzero" in blocked else "medium")

    write_tsv(Path(args.out), row)
    write_md(Path(args.out_md), row)
    print(f"Wrote {args.out} and {args.out_md}.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
