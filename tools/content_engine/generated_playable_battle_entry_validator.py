#!/usr/bin/env python3
from __future__ import annotations

import csv
import subprocess
from pathlib import Path

REPORT = Path("data/design/generated_playable_battle_entry_report.tsv")
CFG = Path("data/design/generated_full_battle_slot_whitelist_config.tsv")
FORBIDDEN_PATTERNS = [
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
    slots = sorted({r.get("battle_slot_id", "") for r in cfg_rows if r.get("battle_slot_id", "")})
    if len(slots) != 16:
        return fail(f"generated node count 必须 16，当前 {len(slots)}")

    generated_rows = [r for r in rows if r.get("battle_slot_id", "") in slots]
    if len(generated_rows) != 16:
        return fail(f"generated node 行数必须 16，当前 {len(generated_rows)}")

    fallback_required = {
        r.get("battle_slot_id", "")
        for r in cfg_rows
        if r.get("reward_fallback_required", "").lower() == "true"
    }

    selected = 0
    for r in generated_rows:
        slot = r.get("battle_slot_id", "")
        if r.get("playable_entry_available") != "true":
            return fail(f"{slot}: playable_entry_available 必须 true")
        if r.get("can_start_playable_battle") != "true":
            return fail(f"{slot}: can_start_playable_battle 必须 true")
        if r.get("battle_context_initialized") != "true":
            return fail(f"{slot}: battle_context_initialized 必须 true")
        if r.get("selected_in_probe") == "true":
            selected += 1
        if not r.get("enemy_deck_id", ""):
            return fail(f"{slot}: enemy_deck_id 不得为空")
        if r.get("card_pool_count") != "72":
            return fail(f"{slot}: card_pool_count 必须 72")
        if r.get("generated_card_pool_available") != "true":
            return fail(f"{slot}: generated_card_pool_available 必须 true")
        if r.get("narrative_key_count") != "28":
            return fail(f"{slot}: narrative_key_count 必须 28")
        if r.get("route_gate_count") != "9":
            return fail(f"{slot}: route_gate_count 必须 9")
        if r.get("fallback_policy") != "legacy":
            return fail(f"{slot}: fallback_policy 必须 legacy")
        if r.get("legacy_fallback_available") != "true":
            return fail(f"{slot}: legacy_fallback_available 必须 true")
        if r.get("writes_card_data") != "false":
            return fail(f"{slot}: writes_card_data 必须 false")
        if r.get("writes_story_data") != "false":
            return fail(f"{slot}: writes_story_data 必须 false")
        if r.get("writes_combat_result") != "false":
            return fail(f"{slot}: writes_combat_result 必须 false")

        if slot in fallback_required:
            if r.get("reward_source") != "legacy":
                return fail(f"{slot}: reward 缺失时 reward_source 必须 legacy")
        elif slot == "prologue_01" and r.get("reward_plan_id") != "rw_prologue_01":
            return fail("prologue_01 reward 必须 rw_prologue_01")

    if selected < 1:
        return fail("至少 1 个 selected_in_probe=true")

    non_rows = [r for r in rows if r.get("battle_slot_id") == "sample_non_generated_preview_slot"]
    if not non_rows:
        return fail("缺少非 generated node 校验行")
    non = non_rows[0]
    if non.get("playable_entry_source") != "legacy":
        return fail("非 generated node 必须 legacy")

    bad = changed_forbidden_files()
    if bad:
        return fail("检测到禁止修改文件: " + ", ".join(bad))

    print("PASS: generated node count=16，每个 node playable entry 可用")
    print("PASS: selected node 可启动 playable battle 且 context 初始化完成")
    print("PASS: enemy/card/reward/narrative/route 指标通过")
    print("PASS: 非 generated node legacy，未写 CardData/story/final combat_result")
    print("RESULT: PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
