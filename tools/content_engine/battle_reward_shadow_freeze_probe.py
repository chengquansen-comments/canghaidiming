#!/usr/bin/env python3
"""v1.0d-prep battle_reward shadow 边界冻结探测。"""

from __future__ import annotations

import argparse
import csv
import json
import re
import subprocess
from pathlib import Path

CANONICAL_PATH = Path("scripts/narrative_demo_canonical_controller.gd")
ADAPTER_PATH = Path("scripts/narrative/battle_reward_runtime_adapter.gd")
CONFIG_PATH = Path("data/runtime/content_engine/runtime_loader_config.json")
RUNTIME_REWARD_PATH = Path("data/runtime/content_engine/battle_reward.json")
RUNTIME_DIR = Path("data/runtime/content_engine")
REPORT_TSV = Path("data/design/generated_battle_reward_shadow_freeze_report.tsv")
REPORT_MD = Path("data/design/generated_battle_reward_shadow_freeze_report.md")
ALLOWED_ADAPTER_REF_FILES = {
    "scripts/narrative_demo_canonical_controller.gd",
    "scripts/narrative/battle_reward_runtime_adapter.gd",
}
ALLOWED_RUNTIME_FILES = {
    "data/runtime/content_engine/battle_reward.json",
    "data/runtime/content_engine/card_pool.json",
    "data/runtime/content_engine/runtime_manifest.json",
    "data/runtime/content_engine/runtime_loader_config.json",
}
HIGH_RISK = {
    "scripts/combat_resolver.gd",
    "scripts/battle_state_machine.gd",
    "scripts/card_data.gd",
}
FORMAL_SOURCES = {
    "data/rewards.json",
    "data/enemy_manifest.json",
    "data/story_battles.json",
}
DANGEROUS_CALLS = [
    "grant_player_cards",
    "apply_player_growth",
    "_pick_reward_card",
    "_open_gain_move",
    "_finish_battle",
    "set_result",
]
FIELDS = ["check_id", "status", "expected", "actual", "detail", "severity"]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="battle_reward shadow freeze probe")
    parser.add_argument("--out", default=str(REPORT_TSV))
    parser.add_argument("--out-md", default=str(REPORT_MD))
    return parser.parse_args()


def add_row(rows: list[dict[str, str]], check_id: str, ok: bool, expected: str, actual: str, detail: str, severity: str = "blocking") -> None:
    rows.append(
        {
            "check_id": check_id,
            "status": "PASS" if ok else "FAIL",
            "expected": expected,
            "actual": actual,
            "detail": detail,
            "severity": severity,
        }
    )


def git_changed_paths() -> list[str]:
    out = subprocess.check_output(["git", "status", "--porcelain"], text=True)
    paths: list[str] = []
    for line in out.splitlines():
        if len(line) < 4:
            continue
        path = line[3:]
        if " -> " in path:
            path = path.split(" -> ", 1)[1]
        paths.append(path)
    return sorted(set(paths))


def find_func_body(text: str, func_name: str) -> str:
    lines = text.splitlines()
    start = -1
    for idx, line in enumerate(lines):
        if re.match(rf"^func\s+{re.escape(func_name)}\s*\(", line.strip()):
            start = idx
            break
    if start < 0:
        return ""
    body: list[str] = []
    for i in range(start, len(lines)):
        line = lines[i]
        if i > start and re.match(r"^func\s+[A-Za-z0-9_]+\s*\(", line.strip()):
            break
        body.append(line)
    return "\n".join(body)


def main() -> int:
    args = parse_args()
    rows: list[dict[str, str]] = []

    canonical_exists = CANONICAL_PATH.exists()
    canonical_text = CANONICAL_PATH.read_text(encoding="utf-8", errors="ignore") if canonical_exists else ""
    func_body = find_func_body(canonical_text, "_battle_reward_for_source")

    adapter_refs: list[str] = []
    for gd in Path("scripts").rglob("*.gd"):
        text = gd.read_text(encoding="utf-8", errors="ignore")
        if "BattleRewardRuntimeAdapter" in text or "battle_reward_runtime_adapter.gd" in text:
            adapter_refs.append(gd.as_posix())
    adapter_refs = sorted(set(adapter_refs))
    out_of_allow = [x for x in adapter_refs if x not in ALLOWED_ADAPTER_REF_FILES]
    add_row(rows, "adapter_formal_flow_reference_count", len(out_of_allow) == 0, "0", str(len(out_of_allow)), f"adapter_ref_files={adapter_refs}")

    has_target_func = bool(func_body)
    add_row(rows, "shadow_integration_file", canonical_exists, "scripts/narrative_demo_canonical_controller.gd", CANONICAL_PATH.as_posix(), "shadow 接入文件必须固定")
    add_row(rows, "shadow_integration_function", has_target_func, "_battle_reward_for_source", "_battle_reward_for_source" if has_target_func else "missing", "shadow 接入函数必须固定")

    outside_text = canonical_text.replace(func_body, "") if func_body else canonical_text
    resolve_inside = func_body.count("resolve_reward(") if func_body else 0
    resolve_outside = outside_text.count("resolve_reward(")
    integration_point_only = has_target_func and resolve_inside >= 1 and resolve_outside == 0
    add_row(
        rows,
        "shadow_integration_point_only",
        integration_point_only,
        "true",
        str(integration_point_only).lower(),
        f"resolve_inside={resolve_inside},resolve_outside={resolve_outside}",
    )

    has_shadow_marker = ("v1.0c shadow only" in func_body) or ("shadow only" in func_body)
    add_row(rows, "shadow_marker_present", has_shadow_marker, "true", str(has_shadow_marker).lower(), "函数内必须保留 shadow-only 标记")

    runtime_enabled_forbidden = [
        "content_engine_runtime_enabled = true",
        'integration_mode = "runtime_enabled"',
        "return runtime_reward",
        "selected_reward = runtime_reward",
    ]
    has_runtime_enabled_logic = any(token in canonical_text for token in runtime_enabled_forbidden)
    add_row(rows, "runtime_enabled_formal_logic_absent", not has_runtime_enabled_logic, "true", str((not has_runtime_enabled_logic)).lower(), "canonical 不得出现 runtime_enabled 正式生效逻辑")

    returns_legacy = "return legacy_reward" in func_body
    add_row(rows, "selected_reward_source", returns_legacy, "legacy", "legacy" if returns_legacy else "unknown", "正式选择结果必须保持 legacy")

    adapter_text = ADAPTER_PATH.read_text(encoding="utf-8", errors="ignore") if ADAPTER_PATH.exists() else ""
    runtime_effective_false = '"selected_reward_runtime_effective": false' in adapter_text
    add_row(rows, "selected_reward_runtime_effective", runtime_effective_false, "false", "false" if runtime_effective_false else "unknown", "runtime 奖励不得正式生效")

    candidate_only = "resolve_reward(" in func_body and returns_legacy
    add_row(rows, "runtime_reward_candidate_only", candidate_only, "true", str(candidate_only).lower(), "runtime reward 只能作为 candidate/shadow_compare")

    cfg_ok = False
    if CONFIG_PATH.exists():
        cfg = json.loads(CONFIG_PATH.read_text(encoding="utf-8"))
        cfg_ok = (
            isinstance(cfg, dict)
            and cfg.get("content_engine_runtime_enabled") is False
            and str(cfg.get("integration_mode", "")) == "disabled"
        )
    add_row(rows, "runtime_loader_config_disabled", cfg_ok, "true", str(cfg_ok).lower(), "runtime_loader_config 必须保持 disabled")

    runtime_count = -1
    if RUNTIME_REWARD_PATH.exists():
        payload = json.loads(RUNTIME_REWARD_PATH.read_text(encoding="utf-8"))
        if isinstance(payload, dict):
            runtime_count = int(payload.get("record_count", -1))
            if runtime_count < 0 and isinstance(payload.get("records"), list):
                runtime_count = len(payload["records"])
    add_row(rows, "battle_reward_runtime_record_count", runtime_count == 45, "45", str(runtime_count), "runtime battle_reward 条数必须为 45")

    changed = git_changed_paths()
    formal_changed = [x for x in changed if x in FORMAL_SOURCES]
    add_row(rows, "formal_data_source_replaced", len(formal_changed) == 0, "false", "true" if formal_changed else "false", ",".join(formal_changed))

    high_risk_changed = [
        x
        for x in changed
        if x in HIGH_RISK or (x.startswith("data/story_battles/") and x.endswith(".tsv")) or (x.startswith("scenes/") and x.endswith(".tscn"))
    ]
    add_row(rows, "high_risk_files_touched", len(high_risk_changed) == 0, "false", "true" if high_risk_changed else "false", ",".join(high_risk_changed))

    runtime_files = {p.as_posix() for p in RUNTIME_DIR.glob("*") if p.is_file()} if RUNTIME_DIR.exists() else set()
    whitelist_ok = runtime_files == ALLOWED_RUNTIME_FILES
    add_row(rows, "runtime_dir_whitelist_status", whitelist_ok, "pass", "pass" if whitelist_ok else "fail", f"actual={sorted(runtime_files)}")

    hit_dangerous = [token for token in DANGEROUS_CALLS if re.search(rf"(?<![A-Za-z0-9_]){re.escape(token)}(?![A-Za-z0-9_])", func_body)]
    add_row(rows, "shadow_region_dangerous_call_count", len(hit_dangerous) == 0, "0", str(len(hit_dangerous)), f"dangerous_calls={','.join(hit_dangerous)}")

    blocking_fail = [r for r in rows if r["severity"] == "blocking" and r["status"] != "PASS"]
    freeze_ok = len(blocking_fail) == 0
    add_row(rows, "shadow_freeze_status", freeze_ok, "pass", "pass" if freeze_ok else "fail", "v1.0c shadow 边界冻结结论")

    out_path = Path(args.out)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    with out_path.open("w", encoding="utf-8", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=FIELDS, delimiter="\t", lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)

    key_order = [
        "shadow_freeze_status",
        "shadow_integration_file",
        "shadow_integration_function",
        "selected_reward_source",
        "selected_reward_runtime_effective",
        "runtime_reward_candidate_only",
        "runtime_loader_config_disabled",
        "formal_data_source_replaced",
        "high_risk_files_touched",
        "runtime_dir_whitelist_status",
        "battle_reward_runtime_record_count",
    ]
    by_id = {row["check_id"]: row for row in rows}
    lines = [
        "# Battle Reward Shadow Freeze 探测报告",
        "",
        f"- blocking_fail_count={len(blocking_fail)}",
        "",
        "## 关键结论",
        "",
    ]
    for key in key_order:
        row = by_id.get(key)
        if row:
            lines.append(f"- {key}={row['actual']}")

    lines.extend([
        "",
        "## 明细",
        "",
        "| check_id | status | expected | actual | severity |",
        "|---|---|---|---|---|",
    ])
    for row in rows:
        lines.append(f"| {row['check_id']} | {row['status']} | {row['expected']} | {row['actual']} | {row['severity']} |")

    lines.extend([
        "",
        "## 说明",
        "",
        "- 本探测用于冻结 v1.0c shadow 边界，禁止 runtime 奖励误入正式流程。",
        "- 任何 blocking 失败都应阻断后续提交。",
        "",
    ])
    Path(args.out_md).write_text("\n".join(lines), encoding="utf-8")

    print(f"Wrote {args.out} and {args.out_md}.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
