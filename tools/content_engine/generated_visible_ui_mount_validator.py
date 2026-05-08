#!/usr/bin/env python3
from __future__ import annotations

import argparse
import csv
from pathlib import Path

REPORT_PATH = Path("data/design/generated_visible_ui_mount_report.tsv")


def _is_true(v: str) -> bool:
    return str(v).strip().lower() == "true"


def main() -> int:
    parser = argparse.ArgumentParser(description="验证 generated visible ui mount 报告")
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
        ("visible_status_payload_available", _is_true(r.get("visible_status_payload_available", "false"))),
        ("visible_text_non_empty", _is_true(r.get("visible_text_non_empty", "false"))),
        ("generated_status_rendered", _is_true(r.get("generated_status_rendered", "false"))),
    ]
    for name, ok in checks:
        if not ok:
            print(f"FAIL: {name}=false")
            return 1

    if not r.get("selected_generated_node_id", ""):
        print("FAIL: selected_generated_node_id 为空")
        return 1
    if not r.get("battle_slot_id", ""):
        print("FAIL: battle_slot_id 为空")
        return 1
    if not r.get("enemy_deck_id", ""):
        print("FAIL: enemy_deck_id 为空")
        return 1
    if int(r.get("card_pool_count", "0")) != 72:
        print("FAIL: card_pool_count != 72")
        return 1
    if not r.get("reward_plan_id", ""):
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
    if not _is_true(r.get("reward_pending_available", "false")):
        print("FAIL: reward_pending_available=false")
        return 1
    if r.get("fallback_policy", "") != "legacy":
        print("FAIL: fallback_policy 非 legacy")
        return 1
    if _is_true(r.get("writes_card_data", "false")):
        print("FAIL: writes_card_data=true")
        return 1
    if _is_true(r.get("writes_story_data", "false")):
        print("FAIL: writes_story_data=true")
        return 1
    if _is_true(r.get("writes_combat_result", "false")):
        print("FAIL: writes_combat_result=true")
        return 1

    print("PASS: visible ui mount 与 generated status 渲染通过")
    print("RESULT: PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
