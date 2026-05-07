#!/usr/bin/env python3
"""battle_reward runtime adapter scaffold 只读探测。"""

from __future__ import annotations

import argparse
import csv
import json
import re
import subprocess
from pathlib import Path


ADAPTER_PATH = Path("scripts/narrative/battle_reward_runtime_adapter.gd")
CONFIG_PATH = Path("data/runtime/content_engine/runtime_loader_config.json")
RUNTIME_REWARD_PATH = Path("data/runtime/content_engine/battle_reward.json")
REPORT_TSV = Path("data/design/generated_battle_reward_runtime_adapter_scaffold_report.tsv")
REPORT_MD = Path("data/design/generated_battle_reward_runtime_adapter_scaffold_report.md")

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
DANGEROUS_TOKENS = [
    "grant_player_cards",
    "apply_player_growth",
    "_pick_reward_card",
    "_open_gain_move",
    "_finish_battle",
    "set_result",
    "_apply_battle_result_reward",
]
MAIN_FLOW_SCAN_DIRS = [Path("scripts")]
MAIN_FLOW_EXCLUDE = {
    "scripts/narrative/battle_reward_runtime_adapter.gd",
}
ALLOWED_ADAPTER_REF_FILES = {
    "scripts/narrative/battle_reward_runtime_adapter.gd",
    "scripts/narrative_demo_canonical_controller.gd",
}
FIELDS = [
    "adapter_file_exists",
    "adapter_class_declared",
    "adapter_resolve_api_present",
    "adapter_referenced_by_main_flow",
    "dangerous_call_count",
    "dangerous_calls",
    "runtime_loader_config_disabled",
    "runtime_battle_reward_exists",
    "runtime_battle_reward_record_count",
    "read_only",
    "formal_data_source_replaced",
    "combat_flow_touched",
    "battle_state_touched",
    "config_enabled",
    "selected_reward_runtime_effective",
    "selected_reward_is_legacy",
    "runtime_only_as_candidate_or_compare",
    "high_risk_modified_count",
    "high_risk_modified_files",
    "formal_reward_source_modified_count",
    "formal_reward_source_modified_files",
    "blocked_reason",
    "notes",
]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="battle_reward runtime adapter scaffold probe")
    parser.add_argument("--out", default=str(REPORT_TSV))
    parser.add_argument("--out-md", default=str(REPORT_MD))
    return parser.parse_args()


def bool_text(v: bool) -> str:
    return "true" if v else "false"


def read_json_dict(path: Path) -> dict:
    payload = json.loads(path.read_text(encoding="utf-8"))
    return payload if isinstance(payload, dict) else {}


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


def config_is_disabled(cfg: dict) -> bool:
    return (
        cfg.get("content_engine_runtime_enabled") is False
        and cfg.get("read_only_probe_enabled") is False
        and str(cfg.get("integration_mode", "")) == "disabled"
        and str(cfg.get("fallback_mode", "")) == "existing_data_source"
    )


def scan_adapter_tokens(adapter_text: str) -> list[str]:
    found: list[str] = []
    for token in DANGEROUS_TOKENS:
        pattern = rf"(?<![A-Za-z0-9_]){re.escape(token)}(?![A-Za-z0-9_])"
        if re.search(pattern, adapter_text):
            found.append(token)
    return found


def scan_main_flow_refs() -> list[str]:
    refs: list[str] = []
    ref_tokens = [
        "battle_reward_runtime_adapter.gd",
        "BattleRewardRuntimeAdapter",
    ]
    for root in MAIN_FLOW_SCAN_DIRS:
        for path in root.rglob("*.gd"):
            rel = path.as_posix()
            if rel in MAIN_FLOW_EXCLUDE:
                continue
            text = path.read_text(encoding="utf-8", errors="ignore")
            for token in ref_tokens:
                if token in text:
                    refs.append(f"{rel}:{token}")
    return sorted(set(refs))


def scan_unauthorized_adapter_refs() -> list[str]:
    unauthorized: list[str] = []
    for ref in scan_main_flow_refs():
        path = ref.split(":", 1)[0]
        if path not in ALLOWED_ADAPTER_REF_FILES:
            unauthorized.append(ref)
    return sorted(set(unauthorized))


def build_row() -> dict[str, str]:
    adapter_file_exists = ADAPTER_PATH.exists()
    adapter_text = ADAPTER_PATH.read_text(encoding="utf-8", errors="ignore") if adapter_file_exists else ""
    adapter_class_declared = "class_name BattleRewardRuntimeAdapter" in adapter_text
    adapter_resolve_api_present = "func resolve_reward(source_id: String, legacy_reward: Dictionary, context: Dictionary = {}) -> Dictionary:" in adapter_text

    dangerous_calls = scan_adapter_tokens(adapter_text)
    unauthorized_refs = scan_unauthorized_adapter_refs()

    runtime_loader_config_disabled = False
    config_enabled = False
    if CONFIG_PATH.exists():
        cfg = read_json_dict(CONFIG_PATH)
        runtime_loader_config_disabled = config_is_disabled(cfg)
        config_enabled = bool(cfg.get("content_engine_runtime_enabled", False))

    runtime_battle_reward_exists = RUNTIME_REWARD_PATH.exists()
    runtime_battle_reward_record_count = 0
    if runtime_battle_reward_exists:
        runtime_payload = read_json_dict(RUNTIME_REWARD_PATH)
        runtime_battle_reward_record_count = int(runtime_payload.get("record_count", 0))

    changed = git_changed_paths()
    high_risk_modified = [
        p for p in changed
        if p in HIGH_RISK or (p.startswith("data/story_battles/") and p.endswith(".tsv")) or (p.startswith("scenes/") and p.endswith(".tscn"))
    ]
    formal_source_modified = [p for p in changed if p in FORMAL_REWARD_SOURCE]

    read_only = '"read_only": true' in adapter_text
    formal_data_source_replaced = False if '"formal_data_source_replaced": false' in adapter_text else True
    combat_flow_touched = False if '"combat_flow_touched": false' in adapter_text else True
    battle_state_touched = False if '"battle_state_touched": false' in adapter_text else True
    selected_reward_runtime_effective = False if '"selected_reward_runtime_effective": false' in adapter_text else True
    selected_reward_is_legacy = '"selected_source": "legacy"' in adapter_text
    runtime_only_as_candidate_or_compare = '"runtime_candidate"' in adapter_text and '"shadow_compare"' in adapter_text

    blocked: list[str] = []
    if not adapter_file_exists:
        blocked.append("adapter_missing")
    if not adapter_class_declared:
        blocked.append("adapter_class_missing")
    if not adapter_resolve_api_present:
        blocked.append("resolve_api_missing")
    if len(unauthorized_refs) > 0:
        blocked.append("adapter_referenced_by_main_flow")
    if len(dangerous_calls) > 0:
        blocked.append("dangerous_calls_found")
    if not runtime_loader_config_disabled:
        blocked.append("runtime_loader_config_not_disabled")
    if not runtime_battle_reward_exists:
        blocked.append("runtime_battle_reward_missing")
    if runtime_battle_reward_record_count != 45:
        blocked.append("runtime_record_count_not_45")
    if len(high_risk_modified) > 0:
        blocked.append("high_risk_modified")
    if len(formal_source_modified) > 0:
        blocked.append("formal_source_modified")

    return {
        "adapter_file_exists": bool_text(adapter_file_exists),
        "adapter_class_declared": bool_text(adapter_class_declared),
        "adapter_resolve_api_present": bool_text(adapter_resolve_api_present),
        "adapter_referenced_by_main_flow": bool_text(len(unauthorized_refs) > 0),
        "dangerous_call_count": str(len(dangerous_calls)),
        "dangerous_calls": ",".join(dangerous_calls),
        "runtime_loader_config_disabled": bool_text(runtime_loader_config_disabled),
        "runtime_battle_reward_exists": bool_text(runtime_battle_reward_exists),
        "runtime_battle_reward_record_count": str(runtime_battle_reward_record_count),
        "read_only": bool_text(read_only),
        "formal_data_source_replaced": bool_text(formal_data_source_replaced),
        "combat_flow_touched": bool_text(combat_flow_touched),
        "battle_state_touched": bool_text(battle_state_touched),
        "config_enabled": bool_text(config_enabled),
        "selected_reward_runtime_effective": bool_text(selected_reward_runtime_effective),
        "selected_reward_is_legacy": bool_text(selected_reward_is_legacy),
        "runtime_only_as_candidate_or_compare": bool_text(runtime_only_as_candidate_or_compare),
        "high_risk_modified_count": str(len(high_risk_modified)),
        "high_risk_modified_files": ",".join(high_risk_modified),
        "formal_reward_source_modified_count": str(len(formal_source_modified)),
        "formal_reward_source_modified_files": ",".join(formal_source_modified),
        "blocked_reason": ",".join(blocked),
        "notes": "adapter 引用仅允许存在于 adapter 文件自身与 canonical shadow 接入点；selected_reward 仍固定 legacy。",
    }


def write_tsv(path: Path, row: dict[str, str]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=FIELDS, delimiter="\t", lineterminator="\n")
        writer.writeheader()
        writer.writerow(row)


def write_md(path: Path, row: dict[str, str]) -> None:
    lines = [
        "# Battle Reward Runtime Adapter Scaffold 探测报告",
        "",
        "## 结论",
        "",
        f"- adapter 文件存在: {row['adapter_file_exists']}",
        f"- adapter 被主流程引用: {row['adapter_referenced_by_main_flow']}",
        f"- runtime_loader_config 仍 disabled: {row['runtime_loader_config_disabled']}",
        f"- runtime battle_reward 记录数: {row['runtime_battle_reward_record_count']}",
        f"- selected_reward 是否仍 legacy: {row['selected_reward_is_legacy']}",
        f"- runtime 是否仅候选/对比: {row['runtime_only_as_candidate_or_compare']}",
        f"- blocked_reason: {row['blocked_reason'] if row['blocked_reason'] else 'none'}",
        "",
        "## 安全边界",
        "",
        f"- read_only: {row['read_only']}",
        f"- formal_data_source_replaced: {row['formal_data_source_replaced']}",
        f"- combat_flow_touched: {row['combat_flow_touched']}",
        f"- battle_state_touched: {row['battle_state_touched']}",
        f"- selected_reward_runtime_effective: {row['selected_reward_runtime_effective']}",
        f"- dangerous_call_count: {row['dangerous_call_count']}",
        f"- dangerous_calls: {row['dangerous_calls'] if row['dangerous_calls'] else 'none'}",
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
    row = build_row()
    write_tsv(Path(args.out), row)
    write_md(Path(args.out_md), row)
    print(f"Wrote {args.out} and {args.out_md}.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
