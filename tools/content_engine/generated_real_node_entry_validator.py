#!/usr/bin/env python3
from __future__ import annotations

import argparse
import csv
from pathlib import Path

REPORT_PATH = Path("data/design/generated_real_node_entry_report.tsv")


def _is_true(v: str) -> bool:
    return str(v).strip().lower() == "true"


def _non_empty(v: str) -> bool:
    return bool(str(v).strip())


def main() -> int:
    parser = argparse.ArgumentParser(description="验证 generated real node entry 报告")
    parser.add_argument("--report", default=str(REPORT_PATH))
    args = parser.parse_args()

    p = Path(args.report)
    if not p.exists() or p.stat().st_size <= 0:
        print("FAIL: report 不存在或为空")
        print("RESULT: FAIL")
        return 1

    with p.open("r", encoding="utf-8", newline="") as f:
        rows = list(csv.DictReader(f, delimiter="\t"))
    if not rows:
        print("FAIL: report 无数据行")
        print("RESULT: FAIL")
        return 1

    r = rows[0]
    bool_checks = [
        "real_node_entry_exists",
        "real_node_entry_visible_or_callable",
        "real_node_entry_invoked",
        "reached_battle_from_real_entry",
        "generated_battle_context_bound",
        "generated_status_rendered",
        "generated_enemy_visible",
        "enemy_summary_visible",
        "generated_card_pool_visible",
        "reward_pending_available",
        "generated_reward_visible",
        "generated_context_preserved_after_action",
        "generated_real_node_entry_ready",
        "no_card_data_write",
        "no_story_battles_write",
        "no_final_combat_result_write",
    ]
    for key in bool_checks:
        if not _is_true(r.get(key, "false")):
            print(f"FAIL: {key}=false")
            print("RESULT: FAIL")
            return 1

    if _is_true(r.get("legacy_only_path", "true")):
        print("FAIL: legacy_only_path=true")
        return 1
    if not _non_empty(r.get("selected_generated_node_id", "")):
        print("FAIL: selected_generated_node_id 为空")
        return 1
    if not _non_empty(r.get("battle_slot_id", "")):
        print("FAIL: battle_slot_id 为空")
        return 1
    if not _non_empty(r.get("enemy_deck_id", "")):
        print("FAIL: enemy_deck_id 为空")
        return 1
    if int(r.get("card_pool_count", "0")) != 72:
        print("FAIL: card_pool_count != 72")
        return 1
    if not _non_empty(r.get("reward_plan_id", "")):
        print("FAIL: reward_plan_id 为空")
        return 1
    if not (_is_true(r.get("player_input_ready", "false")) or _is_true(r.get("action_executed", "false"))):
        print("FAIL: player_input_ready/action_executed 均为 false")
        return 1
    if r.get("fallback_policy", "") != "legacy":
        print("FAIL: fallback_policy 非 legacy")
        return 1

    print("PASS: generated real node entry 从真实入口触发并到达 generated battle")
    print("RESULT: PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
