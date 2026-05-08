#!/usr/bin/env python3
from __future__ import annotations

import argparse
import csv
import subprocess
from pathlib import Path

REPORT_PATH = Path("data/design/generated_playable_loop_report.tsv")


def _read_rows(path: Path) -> list[dict[str, str]]:
    with path.open("r", encoding="utf-8", newline="") as f:
        return list(csv.DictReader(f, delimiter="\t"))


def _is_true(v: str) -> bool:
    return str(v).strip().lower() == "true"


def _git_changed_under(prefix: str) -> bool:
    proc = subprocess.run(["git", "status", "--short", prefix], capture_output=True, text=True, check=False)
    return bool((proc.stdout or "").strip())


def main() -> int:
    parser = argparse.ArgumentParser(description="验证 generated playable loop 报告")
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

    generated_rows = [
        r for r in rows
        if r.get("node_id", "").startswith("generated_node_")
        and r.get("battle_slot_id", "") != "sample_non_generated_preview_slot"
    ]
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
        if not _is_true(row.get("battle_controller_initialized", "false")):
            print("FAIL: selected row battle_controller_initialized=false")
            return 1
        if not _is_true(row.get("round_initialized", "false")):
            print("FAIL: selected row round_initialized=false")
            return 1
        if not _is_true(row.get("player_input_ready", "false")):
            print("FAIL: selected row player_input_ready=false")
            return 1
        if not _is_true(row.get("action_selected", "false")):
            print("FAIL: selected row action_selected=false")
            return 1
        if not _is_true(row.get("action_executed", "false")):
            print("FAIL: selected row action_executed=false")
            return 1

    prologue_rows = [r for r in generated_rows if r.get("battle_slot_id", "") == "prologue_01"]
    if not prologue_rows or prologue_rows[0].get("reward_plan_id", "") != "rw_prologue_01":
        print("FAIL: prologue_01 reward 不是 rw_prologue_01")
        return 1

    for row in generated_rows:
        if row.get("action_source", "") not in {"content_engine", "generated_compatible"}:
            print("FAIL: action_source 非法")
            return 1
        if not row.get("selected_card_id", "") and not row.get("selected_action_id", ""):
            print("FAIL: selected_card_id/selected_action_id 同时为空")
            return 1
        if not row.get("enemy_deck_id", ""):
            print("FAIL: enemy_deck_id 为空")
            return 1
        if not _is_true(row.get("enemy_deck_loaded", "false")):
            print("FAIL: enemy_deck_loaded=false")
            return 1
        enemy_intent_ok = _is_true(row.get("enemy_intent_available", "false")) or _is_true(row.get("enemy_action_candidate_available", "false"))
        if not enemy_intent_ok:
            print("FAIL: enemy_intent_available 与 enemy_action_candidate_available 均 false")
            return 1
        if int(row.get("card_pool_count", "0")) != 72:
            print("FAIL: card_pool_count != 72")
            return 1
        if int(row.get("compatible_card_count", "0")) <= 0:
            print("FAIL: compatible_card_count <= 0")
            return 1
        if not _is_true(row.get("reward_pending_available", "false")):
            print("FAIL: reward_pending_available=false")
            return 1
        if not _is_true(row.get("settlement_candidate_available", "false")):
            print("FAIL: settlement_candidate_available=false")
            return 1
        if int(row.get("narrative_key_count", "0")) != 28:
            print("FAIL: narrative_key_count != 28")
            return 1
        if int(row.get("route_gate_count", "0")) != 9:
            print("FAIL: route_gate_count != 9")
            return 1
        if row.get("fallback_policy", "") != "legacy":
            print("FAIL: fallback_policy 不是 legacy")
            return 1
        if not _is_true(row.get("legacy_fallback_available", "false")):
            print("FAIL: legacy_fallback_available=false")
            return 1
        if _is_true(row.get("writes_card_data", "false")):
            print("FAIL: writes_card_data=true")
            return 1
        if _is_true(row.get("writes_story_data", "false")):
            print("FAIL: writes_story_data=true")
            return 1
        if _is_true(row.get("writes_combat_result", "false")):
            print("FAIL: writes_combat_result=true")
            return 1

    non_generated = [r for r in rows if r.get("battle_slot_id", "") == "sample_non_generated_preview_slot"]
    if not non_generated:
        print("FAIL: 缺少 non-generated legacy 行")
        return 1

    if _git_changed_under("data/story_battles"):
        print("FAIL: 检测到 story_battles 目录变更")
        return 1

    print("PASS: generated node=16，selected node 完成 one-action playable loop")
    print("PASS: reward pending/settlement candidate 与写保护约束通过")
    print("RESULT: PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
