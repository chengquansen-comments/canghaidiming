#!/usr/bin/env python3
from __future__ import annotations

import csv
import subprocess
from pathlib import Path

REPORT = Path("data/design/generated_battle_flow_report.tsv")
CFG = Path("data/design/generated_full_battle_slot_whitelist_config.tsv")
FORBIDDEN_PATTERNS = [
    "scripts/combat_resolver.gd",
    "scripts/battle_state_machine.gd",
    "scripts/card_data.gd",
    "data/story_battles/",
    "scenes/",
]


def fail(msg: str) -> int:
    print(f"FAIL: {msg}")
    return 1


def read_tsv(path: Path) -> list[dict[str, str]]:
    with path.open("r", encoding="utf-8", newline="") as f:
        return list(csv.DictReader(f, delimiter="\t"))


def changed_forbidden_files() -> list[str]:
    out = subprocess.check_output(["git", "status", "--porcelain"], text=True)
    bad = []
    for line in out.splitlines():
        p = line[3:].strip() if len(line) > 3 else ""
        if p and any(p == t or p.startswith(t) for t in FORBIDDEN_PATTERNS):
            bad.append(p)
    return sorted(set(bad))


def main() -> int:
    if not REPORT.exists() or REPORT.stat().st_size == 0:
        return fail("report 不存在或为空")
    if not CFG.exists() or CFG.stat().st_size == 0:
        return fail("full whitelist config 不存在或为空")

    rows = read_tsv(REPORT)
    cfg_rows = read_tsv(CFG)
    generated_slots = [r.get("battle_slot_id", "") for r in cfg_rows if r.get("battle_slot_id", "")]
    expected = len(set(generated_slots))
    if expected != 16:
        return fail(f"generated preview slot 数量必须 16，当前 {expected}")

    whitelist_rows = [r for r in rows if r.get("is_generated_preview_slot") == "true"]
    if len(whitelist_rows) != expected:
        return fail(f"report 中 generated preview slot 数量必须 {expected}，当前 {len(whitelist_rows)}")

    fallback_required = {
        r.get("battle_slot_id", "")
        for r in cfg_rows
        if r.get("reward_fallback_required", "").lower() == "true"
    }

    for r in whitelist_rows:
        slot = r.get("battle_slot_id", "")
        if r.get("battle_flow_payload_available") != "true":
            return fail(f"{slot}: battle_flow_payload_available 必须 true")
        if not r.get("enemy_deck_id", ""):
            return fail(f"{slot}: enemy_deck_id 不得为空")
        if r.get("card_pool_count") != "72":
            return fail(f"{slot}: card_pool_count 必须 72")
        if r.get("operation_node_count") != "10":
            return fail(f"{slot}: operation_node_count 必须 10")
        if r.get("narrative_key_count") != "28":
            return fail(f"{slot}: narrative_key_count 必须 28")
        if r.get("route_gate_count") != "9":
            return fail(f"{slot}: route_gate_count 必须 9")
        if r.get("fallback_policy") != "legacy":
            return fail(f"{slot}: fallback_policy 必须 legacy")
        if r.get("writes_card_data") != "false":
            return fail(f"{slot}: writes_card_data 必须 false")
        if r.get("writes_story_data") != "false":
            return fail(f"{slot}: writes_story_data 必须 false")
        if r.get("writes_battle_state") != "false":
            return fail(f"{slot}: writes_battle_state 必须 false")
        if r.get("writes_combat_result") != "false":
            return fail(f"{slot}: writes_combat_result 必须 false")

        if slot in fallback_required:
            if r.get("reward_source") != "legacy":
                return fail(f"{slot}: reward_fallback_required 时 reward_source 必须 legacy")
        else:
            if slot == "prologue_01" and r.get("reward_plan_id") != "rw_prologue_01":
                return fail("prologue_01 reward 必须 rw_prologue_01")

    non_rows = [r for r in rows if r.get("is_generated_preview_slot") == "false"]
    if not non_rows:
        return fail("缺少非 generated preview slot 样例")
    non = non_rows[0]
    if non.get("battle_slot_source") != "legacy":
        return fail("非 generated preview slot battle_slot_source 必须 legacy")
    if non.get("reward_source") != "legacy":
        return fail("非 generated preview slot reward_source 必须 legacy")

    bad = changed_forbidden_files()
    if bad:
        return fail("检测到禁止修改文件: " + ", ".join(bad))

    print(f"PASS: generated preview slot={expected}，每个 slot battle_flow_payload 可用")
    print("PASS: enemy_deck_id 非空，card_pool=72，operation=10，narrative=28，route_gate=9")
    print("PASS: prologue_01 reward=rw_prologue_01，reward 缺失槽位 fallback legacy")
    print("PASS: 非 generated preview slot legacy，不写 CardData/story/battle/combat")
    print("RESULT: PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
