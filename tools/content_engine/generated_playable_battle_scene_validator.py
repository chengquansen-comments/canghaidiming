#!/usr/bin/env python3
from __future__ import annotations

import argparse
import csv
import subprocess
from pathlib import Path

REPORT_PATH = Path("data/design/generated_playable_battle_scene_report.tsv")


def _read_rows(path: Path) -> list[dict[str, str]]:
    with path.open("r", encoding="utf-8", newline="") as f:
        return list(csv.DictReader(f, delimiter="\t"))


def _is_true(v: str) -> bool:
    return str(v).strip().lower() == "true"


def _git_changed_under(prefix: str) -> bool:
    proc = subprocess.run(["git", "status", "--short", prefix], capture_output=True, text=True, check=False)
    return bool((proc.stdout or "").strip())


def main() -> int:
    parser = argparse.ArgumentParser(description="验证 generated playable battle scene 冒烟报告")
    parser.add_argument("--report", default=str(REPORT_PATH))
    args = parser.parse_args()

    report_path = Path(args.report)
    if not report_path.exists() or report_path.stat().st_size <= 0:
        print(f"FAIL: 报告不存在或为空: {report_path.as_posix()}")
        print("RESULT: FAIL")
        return 1

    rows = _read_rows(report_path)
    if not rows:
        print("FAIL: 报告无数据行")
        print("RESULT: FAIL")
        return 1

    generated_rows = [r for r in rows if _is_true(r.get("battle_slot_id", "").startswith("prologue") or r.get("battle_slot_id", "").startswith("wuju") or r.get("source", "") == "content_engine")]
    generated_rows = [r for r in rows if r.get("source", "") == "content_engine"]
    if len(generated_rows) != 16:
        print(f"FAIL: generated node 数量异常 expected=16 actual={len(generated_rows)}")
        print("RESULT: FAIL")
        return 1

    selected_rows = [r for r in generated_rows if _is_true(r.get("selected_in_probe", "false"))]
    if not selected_rows:
        print("FAIL: 至少需要一个 selected_in_probe=true")
        print("RESULT: FAIL")
        return 1

    for row in selected_rows:
        if not _is_true(row.get("scene_or_controller_loaded", "false")):
            print("FAIL: selected row scene_or_controller_loaded=false")
            print("RESULT: FAIL")
            return 1
        if not _is_true(row.get("battle_controller_initialized", "false")):
            print("FAIL: selected row battle_controller_initialized=false")
            print("RESULT: FAIL")
            return 1
        if not _is_true(row.get("battle_context_loaded", "false")):
            print("FAIL: selected row battle_context_loaded=false")
            print("RESULT: FAIL")
            return 1
        if not _is_true(row.get("can_present_battle", "false")):
            print("FAIL: selected row can_present_battle=false")
            print("RESULT: FAIL")
            return 1

    prologue_rows = [r for r in generated_rows if r.get("battle_slot_id", "") == "prologue_01"]
    if not prologue_rows or prologue_rows[0].get("reward_plan_id", "") != "rw_prologue_01":
        print("FAIL: prologue_01 reward 不是 rw_prologue_01")
        print("RESULT: FAIL")
        return 1

    reward_fallback_ok = any(r.get("reward_source", "") == "legacy" and r.get("reward_plan_id", "") == "" for r in generated_rows)

    for row in generated_rows:
        if not row.get("enemy_deck_id", ""):
            print("FAIL: enemy_deck_id 为空")
            print("RESULT: FAIL")
            return 1
        if not _is_true(row.get("enemy_deck_loaded", "false")):
            print("FAIL: enemy_deck_loaded=false")
            print("RESULT: FAIL")
            return 1
        if int(row.get("card_pool_count", "0")) != 72:
            print("FAIL: card_pool_count != 72")
            print("RESULT: FAIL")
            return 1
        if not _is_true(row.get("generated_card_pool_available", "false")):
            print("FAIL: generated_card_pool_available=false")
            print("RESULT: FAIL")
            return 1
        if int(row.get("narrative_key_count", "0")) != 28:
            print("FAIL: narrative_key_count != 28")
            print("RESULT: FAIL")
            return 1
        if int(row.get("route_gate_count", "0")) != 9:
            print("FAIL: route_gate_count != 9")
            print("RESULT: FAIL")
            return 1
        if row.get("fallback_policy", "") != "legacy":
            print("FAIL: fallback_policy 不是 legacy")
            print("RESULT: FAIL")
            return 1
        if not _is_true(row.get("legacy_fallback_available", "false")):
            print("FAIL: legacy_fallback_available=false")
            print("RESULT: FAIL")
            return 1
        if _is_true(row.get("writes_card_data", "false")):
            print("FAIL: writes_card_data=true")
            print("RESULT: FAIL")
            return 1
        if _is_true(row.get("writes_story_data", "false")):
            print("FAIL: writes_story_data=true")
            print("RESULT: FAIL")
            return 1
        if _is_true(row.get("writes_combat_result", "false")):
            print("FAIL: writes_combat_result=true")
            print("RESULT: FAIL")
            return 1

    non_generated = [r for r in rows if r.get("source", "") == "legacy"]
    if not non_generated:
        print("FAIL: 缺少 non-generated legacy 行")
        print("RESULT: FAIL")
        return 1

    if _git_changed_under("data/story_battles"):
        print("FAIL: 检测到 story_battles 目录变更")
        print("RESULT: FAIL")
        return 1

    print("PASS: generated node count=16，selected row 可进入 battle scene/controller 初始化路径")
    print("PASS: enemy/card/reward/narrative/route 指标通过，fallback 与写保护通过")
    print("RESULT: PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
