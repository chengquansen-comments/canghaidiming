#!/usr/bin/env python3
"""v1.0d-final 一键交付验收执行器（Determinism Hardening）。"""

from __future__ import annotations

import argparse
import csv
import os
import subprocess
import time
import uuid
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path

REPORT_TSV = Path("data/design/generated_content_engine_acceptance_report.tsv")
REPORT_MD = Path("data/design/generated_content_engine_acceptance_report.md")
SUMMARY_TSV = Path("data/design/generated_content_engine_acceptance_summary.tsv")
SUMMARY_MD = Path("data/design/generated_content_engine_acceptance_summary.md")

STEP_FIELDS = [
    "run_id",
    "step_id",
    "check_id",
    "command",
    "exit_code",
    "status",
    "duration_ms",
    "severity",
    "generated_at",
    "detail",
]
SUMMARY_FIELDS = [
    "run_id",
    "check_id",
    "status",
    "required_report_path",
    "report_exists",
    "report_non_empty",
    "report_run_id",
    "generated_at",
    "notes",
]


@dataclass(frozen=True)
class StepDef:
    check_id: str
    command: str
    report_paths: tuple[Path, ...]


STEPS: tuple[StepDef, ...] = (
    StepDef(
        "battle_reward_shadow_freeze_probe",
        "python3 tools/content_engine/battle_reward_shadow_freeze_probe.py",
        (
            Path("data/design/generated_battle_reward_shadow_freeze_report.tsv"),
            Path("data/design/generated_battle_reward_shadow_freeze_report.md"),
        ),
    ),
    StepDef(
        "battle_reward_shadow_freeze_validator",
        "python3 tools/content_engine/battle_reward_shadow_freeze_validator.py",
        tuple(),
    ),
    StepDef(
        "battle_reward_runtime_test_harness",
        "python3 tools/content_engine/battle_reward_runtime_test_harness.py",
        (
            Path("data/design/generated_battle_reward_runtime_test_harness_report.tsv"),
            Path("data/design/generated_battle_reward_runtime_test_harness_report.md"),
        ),
    ),
    StepDef(
        "battle_reward_runtime_test_harness_validator",
        "python3 tools/content_engine/battle_reward_runtime_test_harness_validator.py",
        tuple(),
    ),
    StepDef(
        "full_preview_readonly_probe_py",
        "python3 tools/content_engine/full_preview_readonly_probe.py",
        (Path("data/design/generated_full_preview_readonly_probe_report.tsv"),),
    ),
    StepDef(
        "full_preview_readonly_probe_godot",
        "godot --headless --path . --script tools/content_engine/full_preview_readonly_probe.gd",
        (Path("data/design/generated_full_preview_godot_readonly_report.tsv"),),
    ),
    StepDef(
        "full_preview_readonly_validator",
        "python3 tools/content_engine/full_preview_readonly_validator.py",
        tuple(),
    ),
    StepDef(
        "full_package_shadow_compare_probe",
        "python3 tools/content_engine/full_package_shadow_compare_probe.py",
        (
            Path("data/design/generated_content_domain_switch_matrix.tsv"),
            Path("data/design/generated_full_package_shadow_compare_report.tsv"),
        ),
    ),
    StepDef(
        "full_package_shadow_compare_validator",
        "python3 tools/content_engine/full_package_shadow_compare_validator.py",
        tuple(),
    ),
    StepDef(
        "full_package_candidate_path_probe",
        "python3 tools/content_engine/full_package_candidate_path_probe.py",
        (Path("data/design/generated_full_package_candidate_path_report.tsv"),),
    ),
    StepDef(
        "full_package_candidate_path_validator",
        "python3 tools/content_engine/full_package_candidate_path_validator.py",
        tuple(),
    ),
    StepDef(
        "full_package_whitelist_test_enable_probe",
        "python3 tools/content_engine/full_package_whitelist_test_enable_probe.py",
        (Path("data/design/generated_full_package_whitelist_test_enable_report.tsv"),),
    ),
    StepDef(
        "full_package_whitelist_test_enable_validator",
        "python3 tools/content_engine/full_package_whitelist_test_enable_validator.py",
        tuple(),
    ),
    StepDef(
        "full_package_runtime_readiness_audit",
        "python3 tools/content_engine/full_package_runtime_readiness_audit.py",
        (
            Path("data/design/generated_full_package_runtime_readiness.tsv"),
            Path("data/design/generated_full_package_runtime_blockers.md"),
        ),
    ),
    StepDef(
        "full_package_runtime_readiness_validator",
        "python3 tools/content_engine/full_package_runtime_readiness_validator.py",
        tuple(),
    ),
    StepDef(
        "full_content_runtime_bridge_contract_generator",
        "python3 tools/content_engine/full_content_runtime_bridge_contract_generator.py",
        (
            Path("data/design/generated_full_content_adapter_contract.tsv"),
            Path("data/design/generated_full_content_whitelist_binding_map.tsv"),
            Path("data/runtime/content_engine_whitelist/prologue_01.full_content_bridge.json"),
            Path("data/runtime/content_engine_whitelist/full_content_bridge_manifest.json"),
        ),
    ),
    StepDef(
        "full_content_runtime_bridge_contract_validator",
        "python3 tools/content_engine/full_content_runtime_bridge_contract_validator.py",
        tuple(),
    ),
    StepDef(
        "generated_content_runtime_bridge_probe",
        "godot --headless --path . --script tools/content_engine/generated_content_runtime_bridge_probe.gd",
        (Path("data/design/generated_content_runtime_bridge_probe_report.tsv"),),
    ),
    StepDef(
        "generated_content_runtime_bridge_validator",
        "python3 tools/content_engine/generated_content_runtime_bridge_validator.py",
        tuple(),
    ),
    StepDef(
        "generated_content_formal_enable_probe",
        "godot --headless --path . --script tools/content_engine/generated_content_formal_enable_probe.gd",
        (Path("data/design/generated_content_formal_enable_report.tsv"),),
    ),
    StepDef(
        "generated_content_formal_enable_validator",
        "python3 tools/content_engine/generated_content_formal_enable_validator.py",
        tuple(),
    ),
    StepDef(
        "generated_battle_domain_formal_probe",
        "godot --headless --path . --script tools/content_engine/generated_battle_domain_formal_probe.gd",
        (Path("data/design/generated_battle_domain_formal_report.tsv"),),
    ),
    StepDef(
        "generated_battle_domain_formal_validator",
        "python3 tools/content_engine/generated_battle_domain_formal_validator.py",
        tuple(),
    ),
    StepDef(
        "generated_map_route_domain_formal_probe",
        "godot --headless --path . --script tools/content_engine/generated_map_route_domain_formal_probe.gd",
        (Path("data/design/generated_map_route_domain_formal_report.tsv"),),
    ),
    StepDef(
        "generated_map_route_domain_formal_validator",
        "python3 tools/content_engine/generated_map_route_domain_formal_validator.py",
        tuple(),
    ),
    StepDef(
        "generated_full_domain_enable_acceptance_probe",
        "godot --headless --path . --script tools/content_engine/generated_full_domain_enable_acceptance_probe.gd",
        (Path("data/design/generated_full_domain_enable_acceptance_report.tsv"),),
    ),
    StepDef(
        "generated_full_domain_enable_acceptance_validator",
        "python3 tools/content_engine/generated_full_domain_enable_acceptance_validator.py",
        tuple(),
    ),
    StepDef(
        "generated_slice_whitelist_expander",
        "python3 tools/content_engine/generated_slice_whitelist_expander.py",
        (
            Path("data/design/generated_slice_whitelist_config.tsv"),
            Path("data/design/generated_slice_whitelist_binding_map.tsv"),
            Path("data/design/generated_slice_whitelist_acceptance_report.tsv"),
            Path("data/runtime/content_engine_whitelist/generated_slice.full_content_bridge.json"),
            Path("data/runtime/content_engine_whitelist/generated_slice_manifest.json"),
        ),
    ),
    StepDef(
        "generated_slice_whitelist_validator",
        "python3 tools/content_engine/generated_slice_whitelist_validator.py",
        tuple(),
    ),
    StepDef(
        "generated_full_battle_slot_expander",
        "python3 tools/content_engine/generated_full_battle_slot_expander.py",
        (
            Path("data/design/generated_full_battle_slot_whitelist_config.tsv"),
            Path("data/design/generated_full_battle_slot_binding_map.tsv"),
            Path("data/design/generated_full_battle_slot_integration_report.tsv"),
            Path("data/runtime/content_engine_whitelist/generated_full_battle_slots.full_content_bridge.json"),
            Path("data/runtime/content_engine_whitelist/generated_full_battle_slots_manifest.json"),
        ),
    ),
    StepDef(
        "generated_full_battle_slot_validator",
        "python3 tools/content_engine/generated_full_battle_slot_validator.py",
        tuple(),
    ),
    StepDef(
        "generated_battle_flow_probe",
        "godot --headless --path . --script tools/content_engine/generated_battle_flow_probe.gd",
        (Path("data/design/generated_battle_flow_report.tsv"),),
    ),
    StepDef(
        "generated_battle_flow_validator",
        "python3 tools/content_engine/generated_battle_flow_validator.py",
        tuple(),
    ),
    StepDef(
        "generated_node_route_flow_probe",
        "godot --headless --path . --script tools/content_engine/generated_node_route_flow_probe.gd",
        (Path("data/design/generated_node_route_flow_report.tsv"),),
    ),
    StepDef(
        "generated_node_route_flow_validator",
        "python3 tools/content_engine/generated_node_route_flow_validator.py",
        tuple(),
    ),
    StepDef(
        "generated_player_node_selection_probe",
        "godot --headless --path . --script tools/content_engine/generated_player_node_selection_probe.gd",
        (Path("data/design/generated_player_node_selection_report.tsv"),),
    ),
    StepDef(
        "generated_player_node_selection_validator",
        "python3 tools/content_engine/generated_player_node_selection_validator.py",
        tuple(),
    ),
    StepDef(
        "generated_node_battle_entry_probe",
        "godot --headless --path . --script tools/content_engine/generated_node_battle_entry_probe.gd",
        (Path("data/design/generated_node_battle_entry_report.tsv"),),
    ),
    StepDef(
        "generated_node_battle_entry_validator",
        "python3 tools/content_engine/generated_node_battle_entry_validator.py",
        tuple(),
    ),
    StepDef(
        "generated_node_battle_start_probe",
        "godot --headless --path . --script tools/content_engine/generated_node_battle_start_probe.gd",
        (Path("data/design/generated_node_battle_start_report.tsv"),),
    ),
    StepDef(
        "generated_node_battle_start_validator",
        "python3 tools/content_engine/generated_node_battle_start_validator.py",
        tuple(),
    ),
    StepDef(
        "generated_playable_battle_entry_probe",
        "godot --headless --path . --script tools/content_engine/generated_playable_battle_entry_probe.gd",
        (Path("data/design/generated_playable_battle_entry_report.tsv"),),
    ),
    StepDef(
        "generated_playable_battle_entry_validator",
        "python3 tools/content_engine/generated_playable_battle_entry_validator.py",
        tuple(),
    ),
    StepDef(
        "generated_playable_battle_scene_probe",
        "godot --headless --path . --script tools/content_engine/generated_playable_battle_scene_probe.gd",
        (Path("data/design/generated_playable_battle_scene_report.tsv"),),
    ),
    StepDef(
        "generated_playable_battle_scene_validator",
        "python3 tools/content_engine/generated_playable_battle_scene_validator.py",
        tuple(),
    ),
    StepDef(
        "generated_minimal_playable_round_probe",
        "godot --headless --path . --script tools/content_engine/generated_minimal_playable_round_probe.gd",
        (Path("data/design/generated_minimal_playable_round_report.tsv"),),
    ),
    StepDef(
        "generated_minimal_playable_round_validator",
        "python3 tools/content_engine/generated_minimal_playable_round_validator.py",
        tuple(),
    ),
    StepDef(
        "generated_playable_loop_probe",
        "godot --headless --path . --script tools/content_engine/generated_playable_loop_probe.gd",
        (Path("data/design/generated_playable_loop_report.tsv"),),
    ),
    StepDef(
        "generated_playable_loop_validator",
        "python3 tools/content_engine/generated_playable_loop_validator.py",
        tuple(),
    ),
    StepDef(
        "generated_player_visible_entry_probe",
        "godot --headless --path . --script tools/content_engine/generated_player_visible_entry_probe.gd",
        (Path("data/design/generated_player_visible_entry_report.tsv"),),
    ),
    StepDef(
        "generated_player_visible_entry_validator",
        "python3 tools/content_engine/generated_player_visible_entry_validator.py",
        tuple(),
    ),
    StepDef(
        "generated_visible_ui_mount_probe",
        "godot --headless --path . --script tools/content_engine/generated_visible_ui_mount_probe.gd",
        (Path("data/design/generated_visible_ui_mount_report.tsv"),),
    ),
    StepDef(
        "generated_visible_ui_mount_validator",
        "python3 tools/content_engine/generated_visible_ui_mount_validator.py",
        tuple(),
    ),
    StepDef(
        "generated_battle_runtime_loadout_probe",
        "godot --headless --path . --script tools/content_engine/generated_battle_runtime_loadout_probe.gd",
        (Path("data/design/generated_battle_runtime_loadout_report.tsv"),),
    ),
    StepDef(
        "generated_battle_runtime_loadout_validator",
        "python3 tools/content_engine/generated_battle_runtime_loadout_validator.py",
        tuple(),
    ),
    StepDef(
        "generated_map_route_runtime_flow_probe",
        "godot --headless --path . --script tools/content_engine/generated_map_route_runtime_flow_probe.gd",
        (Path("data/design/generated_map_route_runtime_flow_report.tsv"),),
    ),
    StepDef(
        "generated_map_route_runtime_flow_validator",
        "python3 tools/content_engine/generated_map_route_runtime_flow_validator.py",
        tuple(),
    ),
    StepDef(
        "generated_slice_full_integration_acceptance_probe",
        "godot --headless --path . --script tools/content_engine/generated_slice_full_integration_acceptance_probe.gd",
        (Path("data/design/generated_slice_full_integration_acceptance_report.tsv"),),
    ),
    StepDef(
        "generated_slice_full_integration_acceptance_validator",
        "python3 tools/content_engine/generated_slice_full_integration_acceptance_validator.py",
        tuple(),
    ),
    StepDef(
        "content_engine_regression_runner",
        "python3 tools/content_engine/content_engine_regression_runner.py",
        (
            Path("data/design/generated_content_engine_regression_report.tsv"),
            Path("data/design/generated_content_engine_regression_report.md"),
        ),
    ),
    StepDef(
        "content_engine_regression_validator",
        "python3 tools/content_engine/content_engine_regression_validator.py",
        tuple(),
    ),
)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="运行 content engine 交付级验收（稳定版）。")
    parser.add_argument("--out", default=str(REPORT_TSV))
    parser.add_argument("--out-md", default=str(REPORT_MD))
    parser.add_argument("--summary", default=str(SUMMARY_TSV))
    parser.add_argument("--summary-md", default=str(SUMMARY_MD))
    return parser.parse_args()


def now_iso() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="seconds")


def tail_text(text: str, max_lines: int = 30, max_chars: int = 3000) -> str:
    clipped = "\n".join(text.splitlines()[-max_lines:])
    return clipped[-max_chars:].strip()


def atomic_write_text(path: Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_name(f"{path.name}.{uuid.uuid4().hex}.tmp")
    with tmp.open("w", encoding="utf-8", newline="") as f:
        f.write(text)
        f.flush()
        os.fsync(f.fileno())
    os.replace(tmp, path)


def atomic_write_tsv(path: Path, fieldnames: list[str], rows: list[dict[str, str]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_name(f"{path.name}.{uuid.uuid4().hex}.tmp")
    with tmp.open("w", encoding="utf-8", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames, delimiter="\t", lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)
        f.flush()
        os.fsync(f.fileno())
    os.replace(tmp, path)


def clean_acceptance_outputs(paths: tuple[Path, ...]) -> None:
    for path in paths:
        if path.exists():
            path.unlink()


def run_step(step_id: int, step: StepDef, run_id: str) -> dict[str, str]:
    started = time.time()
    proc = subprocess.run(step.command, shell=True, capture_output=True, text=True)
    duration_ms = int((time.time() - started) * 1000)
    combined = ((proc.stdout or "") + "\n" + (proc.stderr or "")).strip()
    status = "PASS" if proc.returncode == 0 else "FAIL"
    return {
        "run_id": run_id,
        "step_id": str(step_id),
        "check_id": step.check_id,
        "command": step.command,
        "exit_code": str(proc.returncode),
        "status": status,
        "duration_ms": str(duration_ms),
        "severity": "blocking",
        "generated_at": now_iso(),
        "detail": tail_text(combined) if combined else "none",
    }


def verify_report_file(path: Path, min_mtime: float) -> tuple[str, str, str]:
    if not path.exists():
        return "false", "false", "missing_report"
    if not path.is_file():
        return "false", "false", "invalid_report:not_a_file"
    try:
        size = path.stat().st_size
        mtime = path.stat().st_mtime
    except OSError:
        return "false", "false", "invalid_report:stat_failed"
    if size <= 0:
        return "true", "false", "empty_report"
    if mtime < min_mtime:
        return "true", "true", "stale_report"
    try:
        _ = path.read_text(encoding="utf-8", errors="ignore")
    except OSError:
        return "true", "true", "invalid_report:unreadable"
    return "true", "true", "pass"


def build_summary_rows(run_id: str, run_started_epoch: float, step_rows: list[dict[str, str]]) -> list[dict[str, str]]:
    step_status = {row["check_id"]: row["status"] for row in step_rows}
    summary_rows: list[dict[str, str]] = []
    for step in STEPS:
        if not step.report_paths:
            summary_rows.append(
                {
                    "run_id": run_id,
                    "check_id": step.check_id,
                    "status": step_status.get(step.check_id, "FAIL"),
                    "required_report_path": "none",
                    "report_exists": "true",
                    "report_non_empty": "true",
                    "report_run_id": run_id,
                    "generated_at": now_iso(),
                    "notes": "validator_step_no_direct_report",
                }
            )
            continue

        for report_path in step.report_paths:
            report_exists, report_non_empty, notes = verify_report_file(report_path, run_started_epoch)
            base_status = step_status.get(step.check_id, "FAIL")
            final_status = "pass" if base_status == "PASS" and notes == "pass" else notes if notes != "pass" else "invalid_report:step_failed"
            summary_rows.append(
                {
                    "run_id": run_id,
                    "check_id": step.check_id,
                    "status": final_status,
                    "required_report_path": report_path.as_posix(),
                    "report_exists": report_exists,
                    "report_non_empty": report_non_empty,
                    "report_run_id": run_id,
                    "generated_at": now_iso(),
                    "notes": f"step_status={base_status}",
                }
            )

    return summary_rows


def write_step_md(path: Path, run_id: str, rows: list[dict[str, str]]) -> None:
    blocking_fail = [r for r in rows if r["status"] != "PASS"]
    acceptance_status = "PASS" if not blocking_fail else "FAIL"
    lines = [
        "# Content Engine 交付验收执行报告",
        "",
        f"- run_id={run_id}",
        f"- acceptance_status={acceptance_status}",
        f"- blocking_fail_count={len(blocking_fail)}",
        "",
        "## 步骤明细",
        "",
        "| step_id | check_id | exit_code | status | duration_ms |",
        "|---|---|---|---|---|",
    ]
    for row in rows:
        lines.append(f"| {row['step_id']} | {row['check_id']} | {row['exit_code']} | {row['status']} | {row['duration_ms']} |")
    lines.extend(
        [
            "",
            "## 说明",
            "",
            "- 本 runner 顺序执行 shadow freeze、runtime harness、full preview readonly、full package shadow compare、full package candidate path、full package whitelist test enable、runtime readiness audit、runtime bridge contract、Godot runtime bridge spine、prologue formal enable、regression 链路。",
            "- selected_reward 仍为 legacy，runtime reward 仍仅 candidate/shadow_compare。",
            "- 本报告用于 v1.0d-final 的验收稳定性加固，确保不读取半写入文件、不依赖并行时序、无需复跑。",
            "- 所有结论都不改变正式业务流程，不改变玩家实际奖励、不改变成长奖励、不改变结算 UI。",
            "",
        ]
    )
    atomic_write_text(path, "\n".join(lines))


def write_summary_md(path: Path, run_id: str, rows: list[dict[str, str]]) -> None:
    hard_fail = [r for r in rows if r["status"] != "pass" and not r["status"].startswith("PASS")]
    overall = "PASS" if not hard_fail else "FAIL"
    lines = [
        "# Content Engine Acceptance Summary",
        "",
        f"- run_id={run_id}",
        f"- overall_status={overall}",
        "- selected_reward: legacy",
        "- runtime_loader_config: disabled",
        "- runtime_reward_mode: candidate/shadow_compare only",
        "- actual_player_reward_changed: false",
        "- battle_state_changed: false",
        "- combat_result_changed: false",
        "",
        "## Required Reports",
        "",
        "| check_id | status | report_path | report_exists | report_non_empty |",
        "|---|---|---|---|---|",
    ]
    for row in rows:
        lines.append(
            f"| {row['check_id']} | {row['status']} | {row['required_report_path']} | {row['report_exists']} | {row['report_non_empty']} |"
        )
    lines.extend(["", "- `status` 取值：`pass` / `missing_report` / `empty_report` / `stale_report` / `invalid_report:*`。", ""])
    lines.extend(
        [
            "## 说明",
            "",
            "- 本摘要是 validator 的主入口，优先用于判断本轮 run_id 的报告完整性与新鲜度。",
            "- 当出现 missing_report、empty_report、stale_report、invalid_report 任一状态时必须直接判定失败。",
            "- 当前阶段保持 selected_reward=legacy，runtime_loader_config=disabled，runtime reward 仅候选对比，不进入正式奖励结算。",
            "",
        ]
    )
    atomic_write_text(path, "\n".join(lines))


def main() -> int:
    args = parse_args()
    out_report = Path(args.out)
    out_report_md = Path(args.out_md)
    out_summary = Path(args.summary)
    out_summary_md = Path(args.summary_md)

    clean_acceptance_outputs((out_report, out_report_md, out_summary, out_summary_md))

    run_id = f"acceptance-{datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%SZ')}-{uuid.uuid4().hex[:8]}"
    run_started_epoch = time.time()

    step_rows: list[dict[str, str]] = []
    for idx, step in enumerate(STEPS, start=1):
        row = run_step(idx, step, run_id)
        step_rows.append(row)

    atomic_write_tsv(out_report, STEP_FIELDS, step_rows)
    write_step_md(out_report_md, run_id, step_rows)

    summary_rows = build_summary_rows(run_id, run_started_epoch, step_rows)
    atomic_write_tsv(out_summary, SUMMARY_FIELDS, summary_rows)
    write_summary_md(out_summary_md, run_id, summary_rows)

    failed_step = any(row["status"] != "PASS" for row in step_rows)
    failed_summary = any(row["status"] != "pass" and not row["status"].startswith("PASS") for row in summary_rows)
    ok = not failed_step and not failed_summary
    print(
        f"Wrote {out_report.as_posix()}, {out_report_md.as_posix()}, {out_summary.as_posix()}, {out_summary_md.as_posix()}. "
        f"run_id={run_id} acceptance_status={'PASS' if ok else 'FAIL'}"
    )
    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
