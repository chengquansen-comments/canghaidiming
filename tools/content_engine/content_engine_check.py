#!/usr/bin/env python3
"""v0.9-lite 日常总入口。"""

from __future__ import annotations

import argparse
import csv
import json
import subprocess
import time
from pathlib import Path
from typing import Optional


REPORT_TSV = Path("data/design/generated_content_engine_lite_check_report.tsv")
REPORT_MD = Path("data/design/generated_content_engine_lite_check_report.md")
FIELDS = [
    "step_id",
    "step_name",
    "command",
    "exit_code",
    "status",
    "duration_ms",
    "blocked_reason",
    "notes",
]
EXPORT_BEGIN = "CONTENT_ENGINE_EXPORT_JSON_BEGIN"
EXPORT_END = "CONTENT_ENGINE_EXPORT_JSON_END"
VALIDATE_BEGIN = "CONTENT_ENGINE_VALIDATE_JSON_BEGIN"
VALIDATE_END = "CONTENT_ENGINE_VALIDATE_JSON_END"
GODOT_PROBE_BEGIN = "CONTENT_ENGINE_GODOT_PROBE_JSON_BEGIN"
GODOT_PROBE_END = "CONTENT_ENGINE_GODOT_PROBE_JSON_END"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Content Engine v0.9-lite 日常总入口。")
    parser.add_argument("--out", default=str(REPORT_TSV))
    parser.add_argument("--out-md", default=str(REPORT_MD))
    return parser.parse_args()


def parse_marker_payload(text: str, begin: str, end: str) -> Optional[dict]:
    start = text.find(begin)
    stop = text.find(end)
    if start < 0 or stop < 0 or stop <= start:
        return None
    content = text[start + len(begin):stop].strip()
    try:
        payload = json.loads(content)
    except json.JSONDecodeError:
        return None
    if not isinstance(payload, dict):
        return None
    return payload


def run_step(step_id: int, step_name: str, command: str) -> tuple[dict[str, str], str]:
    start = time.time()
    proc = subprocess.run(command, shell=True, capture_output=True, text=True)
    duration_ms = int((time.time() - start) * 1000)
    combined_output = (proc.stdout or "") + "\n" + (proc.stderr or "")
    status = "PASS" if proc.returncode == 0 else "FAIL"
    blocked_reason = "" if proc.returncode == 0 else "exit_nonzero"
    row = {
        "step_id": str(step_id),
        "step_name": step_name,
        "command": command,
        "exit_code": str(proc.returncode),
        "status": status,
        "duration_ms": str(duration_ms),
        "blocked_reason": blocked_reason,
        "notes": "none" if proc.returncode == 0 else combined_output.strip()[-300:],
    }
    return row, combined_output


def write_tsv(path: Path, rows: list[dict[str, str]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=FIELDS, delimiter="\t", lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)


def write_md(
    path: Path,
    rows: list[dict[str, str]],
    export_payload: Optional[dict],
    validate_payload: Optional[dict],
    godot_probe_payload: Optional[dict],
    warning_detected: bool,
) -> None:
    overall_pass = all(row["status"] == "PASS" for row in rows)
    runtime_files = validate_payload.get("runtime_files", []) if isinstance(validate_payload, dict) else []
    runtime_files_text = ", ".join(runtime_files) if isinstance(runtime_files, list) else ""
    battle_count = validate_payload.get("battle_reward_record_count", 0) if isinstance(validate_payload, dict) else 0
    battle_godot_count = godot_probe_payload.get("battle_reward_godot_record_count", 0) if isinstance(godot_probe_payload, dict) else 0
    manifest_ok = bool(validate_payload.get("manifest_check_passed", False)) if isinstance(validate_payload, dict) else False
    config_disabled = bool(validate_payload.get("runtime_loader_config_disabled", False)) if isinstance(validate_payload, dict) else False
    gd_ref_count = int(validate_payload.get("existing_gd_reference_count", -1)) if isinstance(validate_payload, dict) else -1
    replaced = bool(validate_payload.get("formal_data_source_replaced", True)) if isinstance(validate_payload, dict) else True
    high_risk = validate_payload.get("high_risk_modified_files", []) if isinstance(validate_payload, dict) else []
    integration_status = godot_probe_payload.get("integration_status", "unknown") if isinstance(godot_probe_payload, dict) else "unknown"
    card_pool_status = export_payload.get("card_pool_status", "unknown") if isinstance(export_payload, dict) else "unknown"
    card_pool_integration = export_payload.get("card_pool_integration_status", "unknown") if isinstance(export_payload, dict) else "unknown"

    lines = [
        "# Content Engine Lite 日常检查报告",
        "",
        f"- 总体状态：{'PASS' if overall_pass else 'FAIL'}",
        f"- battle_reward record_count: {battle_count}",
        f"- battle_reward Godot record_count: {battle_godot_count}",
        f"- runtime 目录文件列表: {runtime_files_text}",
        f"- manifest 校验结果: {'PASS' if manifest_ok else 'FAIL'}",
        f"- Godot probe 结果: {'PASS' if (isinstance(godot_probe_payload, dict) and bool(godot_probe_payload.get('ok', False))) else 'FAIL'}",
        f"- runtime_loader_config 保持 disabled: {'是' if config_disabled else '否'}",
        f"- 仍未接入正式 loader: {'是' if (config_disabled and gd_ref_count == 0 and integration_status in {'not_integrated', 'compare_only', 'godot_compare_only'}) else '否'}",
        f"- 是否替换正式数据源: {'是' if replaced else '否'}",
        f"- 是否修改高风险文件: {'是' if len(high_risk) > 0 else '否'}",
        f"- card_pool 状态: {card_pool_status}",
        f"- card_pool 集成状态: {card_pool_integration}",
        f"- 是否还有 Godot warning: {'是' if warning_detected else '否'}",
        "",
        "## 步骤结果",
        "",
        "| Step | Name | Exit Code | Status | Duration(ms) | Blocked Reason |",
        "|---|---|---|---|---|---|",
    ]
    for row in rows:
        lines.append(
            f"| {row['step_id']} | {row['step_name']} | {row['exit_code']} | {row['status']} | {row['duration_ms']} | {row['blocked_reason']} |"
        )
    lines.append("")
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(lines), encoding="utf-8")


def main() -> int:
    args = parse_args()
    steps = [
        ("lite_export_battle_reward", "python3 tools/content_engine/content_engine_export.py --domain battle_reward --write"),
        ("lite_validate", "python3 tools/content_engine/content_engine_validate.py"),
        ("lite_godot_probe", "python3 tools/content_engine/content_engine_godot_probe.py"),
        ("battle_reward_runtime_adapter_scaffold_probe", "python3 tools/content_engine/battle_reward_runtime_adapter_scaffold_probe.py"),
        ("battle_reward_runtime_adapter_scaffold_validator", "python3 tools/content_engine/battle_reward_runtime_adapter_scaffold_validator.py"),
        ("battle_reward_shadow_integration_plan_probe", "python3 tools/content_engine/battle_reward_shadow_integration_plan_probe.py"),
        ("battle_reward_shadow_integration_plan_validator", "python3 tools/content_engine/battle_reward_shadow_integration_plan_validator.py"),
        ("battle_reward_shadow_runtime_probe", "python3 tools/content_engine/battle_reward_shadow_runtime_probe.py"),
        ("battle_reward_shadow_runtime_validator", "python3 tools/content_engine/battle_reward_shadow_runtime_validator.py"),
        ("battle_reward_shadow_freeze_probe", "python3 tools/content_engine/battle_reward_shadow_freeze_probe.py"),
        ("battle_reward_shadow_freeze_validator", "python3 tools/content_engine/battle_reward_shadow_freeze_validator.py"),
        ("battle_reward_runtime_test_harness", "python3 tools/content_engine/battle_reward_runtime_test_harness.py"),
        ("battle_reward_runtime_test_harness_validator", "python3 tools/content_engine/battle_reward_runtime_test_harness_validator.py"),
        ("full_preview_readonly_probe_py", "python3 tools/content_engine/full_preview_readonly_probe.py"),
        ("full_preview_readonly_probe_godot", "godot --headless --path . --script tools/content_engine/full_preview_readonly_probe.gd"),
        ("full_preview_readonly_validator", "python3 tools/content_engine/full_preview_readonly_validator.py"),
        ("full_package_shadow_compare_probe", "python3 tools/content_engine/full_package_shadow_compare_probe.py"),
        ("full_package_shadow_compare_validator", "python3 tools/content_engine/full_package_shadow_compare_validator.py"),
        ("full_package_candidate_path_probe", "python3 tools/content_engine/full_package_candidate_path_probe.py"),
        ("full_package_candidate_path_validator", "python3 tools/content_engine/full_package_candidate_path_validator.py"),
        ("full_package_whitelist_test_enable_probe", "python3 tools/content_engine/full_package_whitelist_test_enable_probe.py"),
        ("full_package_whitelist_test_enable_validator", "python3 tools/content_engine/full_package_whitelist_test_enable_validator.py"),
        ("full_package_runtime_readiness_audit", "python3 tools/content_engine/full_package_runtime_readiness_audit.py"),
        ("full_package_runtime_readiness_validator", "python3 tools/content_engine/full_package_runtime_readiness_validator.py"),
        ("full_content_runtime_bridge_contract_generator", "python3 tools/content_engine/full_content_runtime_bridge_contract_generator.py"),
        ("full_content_runtime_bridge_contract_validator", "python3 tools/content_engine/full_content_runtime_bridge_contract_validator.py"),
        ("generated_content_runtime_bridge_probe", "godot --headless --path . --script tools/content_engine/generated_content_runtime_bridge_probe.gd"),
        ("generated_content_runtime_bridge_validator", "python3 tools/content_engine/generated_content_runtime_bridge_validator.py"),
        ("generated_content_formal_enable_probe", "godot --headless --path . --script tools/content_engine/generated_content_formal_enable_probe.gd"),
        ("generated_content_formal_enable_validator", "python3 tools/content_engine/generated_content_formal_enable_validator.py"),
        ("generated_battle_domain_formal_probe", "godot --headless --path . --script tools/content_engine/generated_battle_domain_formal_probe.gd"),
        ("generated_battle_domain_formal_validator", "python3 tools/content_engine/generated_battle_domain_formal_validator.py"),
        ("generated_map_route_domain_formal_probe", "godot --headless --path . --script tools/content_engine/generated_map_route_domain_formal_probe.gd"),
        ("generated_map_route_domain_formal_validator", "python3 tools/content_engine/generated_map_route_domain_formal_validator.py"),
        ("generated_full_domain_enable_acceptance_probe", "godot --headless --path . --script tools/content_engine/generated_full_domain_enable_acceptance_probe.gd"),
        ("generated_full_domain_enable_acceptance_validator", "python3 tools/content_engine/generated_full_domain_enable_acceptance_validator.py"),
        ("generated_slice_whitelist_expander", "python3 tools/content_engine/generated_slice_whitelist_expander.py"),
        ("generated_slice_whitelist_validator", "python3 tools/content_engine/generated_slice_whitelist_validator.py"),
        ("generated_full_battle_slot_expander", "python3 tools/content_engine/generated_full_battle_slot_expander.py"),
        ("generated_full_battle_slot_validator", "python3 tools/content_engine/generated_full_battle_slot_validator.py"),
        ("generated_battle_runtime_loadout_probe", "godot --headless --path . --script tools/content_engine/generated_battle_runtime_loadout_probe.gd"),
        ("generated_battle_runtime_loadout_validator", "python3 tools/content_engine/generated_battle_runtime_loadout_validator.py"),
        ("generated_map_route_runtime_flow_probe", "godot --headless --path . --script tools/content_engine/generated_map_route_runtime_flow_probe.gd"),
        ("generated_map_route_runtime_flow_validator", "python3 tools/content_engine/generated_map_route_runtime_flow_validator.py"),
        ("generated_slice_full_integration_acceptance_probe", "godot --headless --path . --script tools/content_engine/generated_slice_full_integration_acceptance_probe.gd"),
        ("generated_slice_full_integration_acceptance_validator", "python3 tools/content_engine/generated_slice_full_integration_acceptance_validator.py"),
        ("git_diff_check", "git diff --check"),
        ("godot_headless_quit", "godot --headless --path . --quit"),
        ("godot_headless_mainvisual", "godot --headless --path . --quit scenes/MainVisual.tscn"),
    ]

    rows: list[dict[str, str]] = []
    outputs: list[str] = []
    export_payload: Optional[dict] = None
    validate_payload: Optional[dict] = None
    godot_probe_payload: Optional[dict] = None

    for idx, (name, command) in enumerate(steps, start=1):
        row, output = run_step(idx, name, command)
        rows.append(row)
        outputs.append(output)
        if name == "lite_export_battle_reward":
            export_payload = parse_marker_payload(output, EXPORT_BEGIN, EXPORT_END)
            if export_payload is None:
                row["status"] = "FAIL"
                row["exit_code"] = "1"
                row["blocked_reason"] = "export_payload_missing"
                row["notes"] = "未解析到 export marker payload。"
        elif name == "lite_validate":
            validate_payload = parse_marker_payload(output, VALIDATE_BEGIN, VALIDATE_END)
            if validate_payload is None:
                row["status"] = "FAIL"
                row["exit_code"] = "1"
                row["blocked_reason"] = "validate_payload_missing"
                row["notes"] = "未解析到 validate marker payload。"
        elif name == "lite_godot_probe":
            godot_probe_payload = parse_marker_payload(output, GODOT_PROBE_BEGIN, GODOT_PROBE_END)
            if godot_probe_payload is None:
                row["status"] = "FAIL"
                row["exit_code"] = "1"
                row["blocked_reason"] = "godot_probe_payload_missing"
                row["notes"] = "未解析到 godot_probe marker payload。"

    warning_detected = any(("WARNING:" in out or "ERROR:" in out) for out in outputs)
    write_tsv(Path(args.out), rows)
    write_md(Path(args.out_md), rows, export_payload, validate_payload, godot_probe_payload, warning_detected)

    overall_ok = all(row["status"] == "PASS" for row in rows)
    print(f"Wrote {args.out} and {args.out_md}. overall={'PASS' if overall_ok else 'FAIL'}")
    return 0 if overall_ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
