#!/usr/bin/env python3
"""battle_reward v1.0c shadow runtime 接入探测。"""

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
REPORT_TSV = Path("data/design/generated_battle_reward_shadow_runtime_report.tsv")
REPORT_MD = Path("data/design/generated_battle_reward_shadow_runtime_report.md")

ALLOWED_ADAPTER_REF_FILES = {
    "scripts/narrative_demo_canonical_controller.gd",
    "scripts/narrative/battle_reward_runtime_adapter.gd",
}
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
    parser = argparse.ArgumentParser(description="battle_reward shadow runtime probe")
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


def config_disabled(cfg: dict) -> bool:
    return (
        cfg.get("content_engine_runtime_enabled") is False
        and cfg.get("read_only_probe_enabled") is False
        and str(cfg.get("integration_mode", "")) == "disabled"
        and str(cfg.get("fallback_mode", "")) == "existing_data_source"
    )


def git_changed_paths() -> list[str]:
    out = subprocess.check_output(["git", "status", "--porcelain"], text=True)
    paths = []
    for line in out.splitlines():
        if len(line) < 4:
            continue
        p = line[3:]
        if " -> " in p:
            p = p.split(" -> ", 1)[1]
        paths.append(p)
    return sorted(set(paths))


def find_function_body(text: str, func_name: str) -> str:
    lines = text.splitlines()
    start = -1
    for i, line in enumerate(lines):
        if re.match(rf"^func\s+{re.escape(func_name)}\s*\(", line.strip()):
            start = i
            break
    if start < 0:
        return ""
    body: list[str] = []
    for j in range(start, len(lines)):
        line = lines[j]
        if j > start and re.match(r"^func\s+[A-Za-z0-9_]+\s*\(", line.strip()):
            break
        body.append(line)
    return "\n".join(body)


def main() -> int:
    args = parse_args()
    rows: list[dict[str, str]] = []

    canonical_exists = CANONICAL_PATH.exists()
    add_row(rows, "canonical_file_exists", canonical_exists, "true", str(canonical_exists).lower(), "canonical controller 文件必须存在")
    canonical_text = CANONICAL_PATH.read_text(encoding="utf-8", errors="ignore") if canonical_exists else ""

    adapter_ref_in_canonical = ("BattleRewardRuntimeAdapter" in canonical_text) or ("battle_reward_runtime_adapter.gd" in canonical_text)
    add_row(rows, "shadow_integration_present", adapter_ref_in_canonical, "true", str(adapter_ref_in_canonical).lower(), "canonical 中必须存在 adapter 引用")
    add_row(rows, "shadow_integration_file", canonical_exists, "scripts/narrative_demo_canonical_controller.gd", CANONICAL_PATH.as_posix(), "shadow 接入文件必须是 canonical controller")

    func_body = find_function_body(canonical_text, "_battle_reward_for_source")
    has_target_func = bool(func_body)
    add_row(rows, "shadow_integration_function", has_target_func and "_battle_reward_for_source" or "missing", "_battle_reward_for_source", "_battle_reward_for_source" if has_target_func else "missing", "shadow 接入函数必须为 _battle_reward_for_source")

    has_shadow_marker = "v1.0c shadow only" in func_body or "shadow only" in func_body
    add_row(rows, "shadow_marker_present", has_shadow_marker, "true", str(has_shadow_marker).lower(), "_battle_reward_for_source 内应包含 shadow-only 标记")

    returns_legacy = "return legacy_reward" in func_body
    add_row(rows, "selected_reward_source", returns_legacy, "legacy", "legacy" if returns_legacy else "unknown", "正式返回值必须保持 legacy reward")

    add_row(rows, "runtime_reward_candidate_only", "resolve_reward(" in func_body, "true", str("resolve_reward(" in func_body).lower(), "应旁路调用 adapter.resolve_reward")

    dangerous_in_shadow = []
    for token in DANGEROUS_CALLS:
        if re.search(rf"(?<![A-Za-z0-9_]){re.escape(token)}(?![A-Za-z0-9_])", func_body):
            dangerous_in_shadow.append(token)
    add_row(rows, "shadow_region_dangerous_call_count", len(dangerous_in_shadow) == 0, "0", str(len(dangerous_in_shadow)), f"危险调用={','.join(dangerous_in_shadow)}")

    adapter_ref_files = []
    for gd in Path("scripts").rglob("*.gd"):
        rel = gd.as_posix()
        text = gd.read_text(encoding="utf-8", errors="ignore")
        if "BattleRewardRuntimeAdapter" in text or "battle_reward_runtime_adapter.gd" in text:
            adapter_ref_files.append(rel)
    adapter_ref_files = sorted(set(adapter_ref_files))
    adapter_refs_ok = set(adapter_ref_files).issubset(ALLOWED_ADAPTER_REF_FILES)
    add_row(rows, "adapter_formal_flow_reference_count", adapter_refs_ok, "0_outside_allowlist", str(len([p for p in adapter_ref_files if p not in ALLOWED_ADAPTER_REF_FILES])), f"adapter_ref_files={adapter_ref_files}")

    canonical_ref_count = 0
    if canonical_exists and adapter_ref_in_canonical:
        canonical_ref_count = canonical_text.count("BattleRewardRuntimeAdapter") + canonical_text.count("battle_reward_runtime_adapter.gd")
    add_row(rows, "canonical_controller_adapter_reference_count", canonical_ref_count > 0, ">=1", str(canonical_ref_count), "canonical controller 应存在 adapter 引用")

    cfg_ok = False
    if CONFIG_PATH.exists():
        cfg = json.loads(CONFIG_PATH.read_text(encoding="utf-8"))
        cfg_ok = isinstance(cfg, dict) and config_disabled(cfg)
    add_row(rows, "runtime_loader_config_disabled", cfg_ok, "true", str(cfg_ok).lower(), "runtime_loader_config 必须保持 disabled")

    runtime_exists = RUNTIME_REWARD_PATH.exists()
    runtime_count = -1
    if runtime_exists:
        payload = json.loads(RUNTIME_REWARD_PATH.read_text(encoding="utf-8"))
        if isinstance(payload, dict):
            runtime_count = int(payload.get("record_count", -1))
    add_row(rows, "battle_reward_runtime_record_count", runtime_count == 45, "45", str(runtime_count), "runtime battle_reward 记录数必须为 45")

    runtime_files = {p.name for p in RUNTIME_DIR.iterdir() if p.is_file()} if RUNTIME_DIR.exists() else set()
    whitelist_ok = runtime_files == ALLOWED_RUNTIME_FILES
    add_row(rows, "runtime_dir_whitelist_status", whitelist_ok, "pass", "pass" if whitelist_ok else "fail", f"actual={sorted(runtime_files)}")

    changed = git_changed_paths()
    high_risk_touched = [p for p in changed if p in HIGH_RISK or (p.startswith("data/story_battles/") and p.endswith(".tsv")) or (p.startswith("scenes/") and p.endswith(".tscn"))]
    add_row(rows, "high_risk_files_touched", len(high_risk_touched) == 0, "false", "true" if high_risk_touched else "false", ",".join(high_risk_touched))

    formal_touched = [p for p in changed if p in FORMAL_SOURCES]
    add_row(rows, "formal_data_source_replaced", len(formal_touched) == 0, "false", "true" if formal_touched else "false", ",".join(formal_touched))

    adapter_text = ADAPTER_PATH.read_text(encoding="utf-8", errors="ignore") if ADAPTER_PATH.exists() else ""
    add_row(rows, "selected_reward_runtime_effective", '"selected_reward_runtime_effective": false' in adapter_text, "false", "false" if '"selected_reward_runtime_effective": false' in adapter_text else "unknown", "adapter 需保持 runtime 不生效")
    add_row(rows, "battle_state_touched", '"battle_state_touched": false' in adapter_text, "false", "false" if '"battle_state_touched": false' in adapter_text else "unknown", "adapter 不得触碰 battle_state")
    add_row(rows, "combat_result_touched", '"combat_flow_touched": false' in adapter_text, "false", "false" if '"combat_flow_touched": false' in adapter_text else "unknown", "adapter 不得触碰 combat_result/flow")

    Path(args.out).parent.mkdir(parents=True, exist_ok=True)
    with Path(args.out).open("w", encoding="utf-8", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=FIELDS, delimiter="\t", lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)

    blocking_fail = [r for r in rows if r["severity"] == "blocking" and r["status"] != "PASS"]
    lines = [
        "# Battle Reward Shadow Runtime 探测报告",
        "",
        f"- blocking 失败数: {len(blocking_fail)}",
        "",
        "## 关键结论",
        "",
    ]
    key_ids = [
        "shadow_integration_present",
        "shadow_integration_file",
        "shadow_integration_function",
        "selected_reward_source",
        "selected_reward_runtime_effective",
        "runtime_reward_candidate_only",
        "formal_data_source_replaced",
        "runtime_loader_config_disabled",
        "battle_state_touched",
        "combat_result_touched",
        "high_risk_files_touched",
        "runtime_dir_whitelist_status",
        "battle_reward_runtime_record_count",
    ]
    idx = {r["check_id"]: r for r in rows}
    for k in key_ids:
        r = idx.get(k)
        if r:
            lines.append(f"- {k}={r['actual']}")

    lines.extend([
        "",
        "## 明细",
        "",
        "| check_id | status | expected | actual | severity |",
        "|---|---|---|---|---|",
    ])
    for r in rows:
        lines.append(f"| {r['check_id']} | {r['status']} | {r['expected']} | {r['actual']} | {r['severity']} |")

    lines.extend(["", "## 说明", "", "- 本阶段为 shadow 实接：只旁路对比，不改变正式奖励结果。", "- 任何 blocking 失败均视为不满足 v1.0c 安全边界。", ""])
    Path(args.out_md).write_text("\n".join(lines), encoding="utf-8")

    print(f"Wrote {args.out} and {args.out_md}.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
