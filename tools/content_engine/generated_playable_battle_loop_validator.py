#!/usr/bin/env python3
from __future__ import annotations

import argparse
import csv
from pathlib import Path

REPORT_PATH = Path("data/design/generated_playable_battle_loop_report.tsv")


def _is_true(v: str) -> bool:
    return str(v).strip().lower() == "true"


def _non_empty(v: str) -> bool:
    return bool(str(v).strip())


def main() -> int:
    parser = argparse.ArgumentParser(description="验证 generated playable battle loop 报告")
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
    checks = [
        ("visible_ui_mounted", _is_true(r.get("visible_ui_mounted", "false"))),
        ("visible_text_non_empty", _is_true(r.get("visible_text_non_empty", "false"))),
        ("generated_status_rendered", _is_true(r.get("generated_status_rendered", "false"))),
        ("generated_battle_context_bound", _is_true(r.get("generated_battle_context_bound", "false"))),
        ("generated_enemy_visible", _is_true(r.get("generated_enemy_visible", "false"))),
        ("enemy_summary_visible", _is_true(r.get("enemy_summary_visible", "false"))),
        ("generated_card_pool_visible", _is_true(r.get("generated_card_pool_visible", "false"))),
        ("reward_pending_available", _is_true(r.get("reward_pending_available", "false"))),
        ("generated_reward_visible", _is_true(r.get("generated_reward_visible", "false"))),
        ("generated_context_preserved_after_action", _is_true(r.get("generated_context_preserved_after_action", "false"))),
        ("generated_playable_loop_ready", _is_true(r.get("generated_playable_loop_ready", "false"))),
        ("no_card_data_write", _is_true(r.get("no_card_data_write", "false"))),
        ("no_story_battles_write", _is_true(r.get("no_story_battles_write", "false"))),
        ("no_final_combat_result_write", _is_true(r.get("no_final_combat_result_write", "false"))),
    ]
    for name, ok in checks:
        if not ok:
            print(f"FAIL: {name}=false")
            print("RESULT: FAIL")
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
    if int(r.get("narrative_key_count", "0")) != 28:
        print("FAIL: narrative_key_count != 28")
        return 1
    if int(r.get("route_gate_count", "0")) != 9:
        print("FAIL: route_gate_count != 9")
        return 1
    if not (_is_true(r.get("player_input_ready", "false")) or _is_true(r.get("action_executed", "false"))):
        print("FAIL: player_input_ready/action_executed 均为 false")
        return 1
    if _is_true(r.get("legacy_only_path", "true")):
        print("FAIL: legacy_only_path=true")
        return 1
    if r.get("fallback_policy", "") != "legacy":
        print("FAIL: fallback_policy 非 legacy")
        return 1

    print("PASS: generated playable battle loop 可见链路与最小可玩闭环通过")
    print("RESULT: PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
