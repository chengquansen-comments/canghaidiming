#!/usr/bin/env python3
"""battle_reward shadow integration plan 静态探测。"""

from __future__ import annotations

import argparse
import csv
import json
import re
import subprocess
from pathlib import Path


PLAN_MD = Path("docs/BATTLE_REWARD_SHADOW_INTEGRATION_PLAN.md")
CONFIG_PATH = Path("data/runtime/content_engine/runtime_loader_config.json")
RUNTIME_REWARD_PATH = Path("data/runtime/content_engine/battle_reward.json")
ADAPTER_PATH = Path("scripts/narrative/battle_reward_runtime_adapter.gd")
CANONICAL_CONTROLLER_PATH = Path("scripts/narrative_demo_canonical_controller.gd")
REPORT_TSV = Path("data/design/generated_battle_reward_shadow_integration_plan_report.tsv")
REPORT_MD = Path("data/design/generated_battle_reward_shadow_integration_plan_report.md")

ALLOWED_RUNTIME_FILES = {
    "battle_reward.json",
    "card_pool.json",
    "runtime_manifest.json",
    "runtime_loader_config.json",
}
HIGH_RISK = {
    "scripts/combat_resolver.gd",
    "scripts/battle_state_machine.gd",
    "scripts/card_data.gd",
}
FORMAL_REWARD_SOURCE = {
    "data/rewards.json",
    "data/enemy_manifest.json",
    "data/story_battles.json",
}
ALLOWED_ADAPTER_REF_FILES = {
    "scripts/narrative/battle_reward_runtime_adapter.gd",
    "scripts/narrative_demo_canonical_controller.gd",
}

FIELDS = ["check_id", "status", "expected", "actual", "detail", "severity"]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="battle_reward shadow integration plan probe")
    parser.add_argument("--out", default=str(REPORT_TSV))
    parser.add_argument("--out-md", default=str(REPORT_MD))
    return parser.parse_args()


def config_is_disabled(cfg: dict) -> bool:
    return (
        cfg.get("content_engine_runtime_enabled") is False
        and cfg.get("read_only_probe_enabled") is False
        and str(cfg.get("integration_mode", "")) == "disabled"
        and str(cfg.get("fallback_mode", "")) == "existing_data_source"
    )


def git_changed_paths() -> list[str]:
    out = subprocess.check_output(["git", "status", "--porcelain"], text=True)
    paths: list[str] = []
    for line in out.splitlines():
        if len(line) < 4:
            continue
        p = line[3:]
        if " -> " in p:
            p = p.split(" -> ", 1)[1]
        paths.append(p)
    return sorted(set(paths))


def bool_status(ok: bool) -> str:
    return "PASS" if ok else "FAIL"


def add_check(rows: list[dict[str, str]], check_id: str, ok: bool, expected: str, actual: str, detail: str, severity: str) -> None:
    rows.append(
        {
            "check_id": check_id,
            "status": bool_status(ok),
            "expected": expected,
            "actual": actual,
            "detail": detail,
            "severity": severity,
        }
    )


def count_adapter_refs(exclude_adapter_self: bool = True) -> int:
    count = 0
    for gd in Path("scripts").rglob("*.gd"):
        rel = gd.as_posix()
        if exclude_adapter_self and rel == ADAPTER_PATH.as_posix():
            continue
        text = gd.read_text(encoding="utf-8", errors="ignore")
        if "BattleRewardRuntimeAdapter" in text or "battle_reward_runtime_adapter.gd" in text:
            count += 1
    return count


def count_adapter_refs_outside_allowlist() -> int:
    count = 0
    for gd in Path("scripts").rglob("*.gd"):
        rel = gd.as_posix()
        text = gd.read_text(encoding="utf-8", errors="ignore")
        if "BattleRewardRuntimeAdapter" in text or "battle_reward_runtime_adapter.gd" in text:
            if rel not in ALLOWED_ADAPTER_REF_FILES:
                count += 1
    return count


def main() -> int:
    args = parse_args()
    rows: list[dict[str, str]] = []

    plan_exists = PLAN_MD.exists()
    add_check(rows, "plan_md_exists", plan_exists, "exists", "exists" if plan_exists else "missing", "shadow 设计文档必须存在。", "blocking")

    plan_text = PLAN_MD.read_text(encoding="utf-8", errors="ignore") if plan_exists else ""
    required_phrase_groups = [
        ["v1.0c-plan"],
        ["shadow"],
        ["legacy reward 仍然是正式奖励"],
        ["runtime reward 只作为 runtime_candidate"],
        ["selected_reward 必须来自 legacy"],
        ["runtime_reward_effective=false"],
        ["fallback legacy", "fallback legacy。", "fallback legacy。", "fallback legacy；"],
        ["不修改 battle_state"],
        ["不修改 combat_result"],
        ["不替换正式奖励源"],
        ["runtime_loader_config 必须保持 disabled", "`runtime_loader_config` 必须保持 disabled"],
    ]
    for group in required_phrase_groups:
        phrase = group[0]
        ok = any(candidate in plan_text for candidate in group)
        add_check(
            rows,
            f"plan_phrase::{phrase}",
            ok,
            "present",
            "present" if ok else "missing",
            f"文档应包含关键短语：{phrase}",
            "blocking",
        )

    preferred_entry = "scripts/narrative_demo_canonical_controller.gd::_battle_reward_for_source"
    add_check(
        rows,
        "preferred_entry_recorded",
        preferred_entry in plan_text,
        preferred_entry,
        "present" if preferred_entry in plan_text else "missing",
        "应明确记录首选最小接入点。",
        "blocking",
    )

    forbidden_points = [
        "scripts/combat_resolver.gd",
        "scripts/battle_state_machine.gd",
        "scripts/card_data.gd",
        "scripts/battle_controller_core_round_resolution.gd::_finish_battle",
    ]
    for point in forbidden_points:
        ok = point in plan_text
        add_check(rows, f"forbidden_point::{point}", ok, "present", "present" if ok else "missing", "应记录禁止接入点。", "blocking")

    cfg = json.loads(CONFIG_PATH.read_text(encoding="utf-8")) if CONFIG_PATH.exists() else {}
    cfg_disabled = isinstance(cfg, dict) and config_is_disabled(cfg)
    add_check(rows, "runtime_loader_config_disabled", cfg_disabled, "true", "true" if cfg_disabled else "false", "runtime_loader_config 必须保持 disabled。", "blocking")

    runtime_exists = RUNTIME_REWARD_PATH.exists()
    runtime_count = 0
    if runtime_exists:
        payload = json.loads(RUNTIME_REWARD_PATH.read_text(encoding="utf-8"))
        if isinstance(payload, dict):
            runtime_count = int(payload.get("record_count", 0))
    add_check(rows, "battle_reward_runtime_exists", runtime_exists, "true", "true" if runtime_exists else "false", "runtime battle_reward.json 必须存在。", "blocking")
    add_check(rows, "battle_reward_runtime_record_count", runtime_count == 45, "45", str(runtime_count), "runtime battle_reward 记录数应为 45。", "blocking")

    adapter_ref_count = count_adapter_refs_outside_allowlist()
    add_check(rows, "adapter_formal_flow_reference_count", adapter_ref_count == 0, "0", str(adapter_ref_count), "adapter 不得在未授权文件中引用。", "blocking")

    canonical_text = CANONICAL_CONTROLLER_PATH.read_text(encoding="utf-8", errors="ignore") if CANONICAL_CONTROLLER_PATH.exists() else ""
    canonical_ref = canonical_text.count("BattleRewardRuntimeAdapter") + canonical_text.count("battle_reward_runtime_adapter.gd")
    canonical_ok = canonical_ref in {0, 1, 2, 3, 4}
    add_check(rows, "canonical_controller_adapter_reference_count", canonical_ok, "0_or_more_allowed_in_v1_0c", str(canonical_ref), "v1.0c 允许 canonical 作为最小接入点引用 adapter。", "blocking")

    changed = git_changed_paths()
    high_risk_touched = [
        p for p in changed
        if p in HIGH_RISK or (p.startswith("data/story_battles/") and p.endswith(".tsv")) or (p.startswith("scenes/") and p.endswith(".tscn"))
    ]
    add_check(rows, "high_risk_files_touched", len(high_risk_touched) == 0, "false", "true" if high_risk_touched else "false", ",".join(high_risk_touched), "blocking")

    formal_source_touched = [p for p in changed if p in FORMAL_REWARD_SOURCE]
    add_check(rows, "formal_reward_source_touched", len(formal_source_touched) == 0, "false", "true" if formal_source_touched else "false", ",".join(formal_source_touched), "blocking")

    runtime_files = {p.name for p in Path("data/runtime/content_engine").iterdir() if p.is_file()} if Path("data/runtime/content_engine").exists() else set()
    whitelist_ok = runtime_files == ALLOWED_RUNTIME_FILES
    add_check(rows, "runtime_dir_whitelist_status", whitelist_ok, "pass", "pass" if whitelist_ok else "fail", f"actual={sorted(runtime_files)}", "blocking")

    Path(args.out).parent.mkdir(parents=True, exist_ok=True)
    with Path(args.out).open("w", encoding="utf-8", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=FIELDS, delimiter="\t", lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)

    blocking_fail = [r for r in rows if r["severity"] == "blocking" and r["status"] != "PASS"]
    lines = [
        "# Battle Reward Shadow Integration Plan 探测报告",
        "",
        f"- blocking 失败数: {len(blocking_fail)}",
        "",
        "## 明细",
        "",
        "| check_id | status | expected | actual | severity |",
        "|---|---|---|---|---|",
    ]
    for r in rows:
        lines.append(f"| {r['check_id']} | {r['status']} | {r['expected']} | {r['actual']} | {r['severity']} |")
    lines.extend(["", "## 说明", "", "- 本阶段仅做 shadow 接入设计确认，不实现接入。", "- 任何 blocking 失败都应阻断后续 v1.0c 实施。", ""])
    Path(args.out_md).write_text("\n".join(lines), encoding="utf-8")

    print(f"Wrote {args.out} and {args.out_md}.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
