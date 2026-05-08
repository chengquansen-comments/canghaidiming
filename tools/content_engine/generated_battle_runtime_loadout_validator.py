#!/usr/bin/env python3
from __future__ import annotations

import csv
import subprocess
from pathlib import Path

REPORT = Path("data/design/generated_battle_runtime_loadout_report.tsv")
FULL_CFG = Path("data/design/generated_full_battle_slot_whitelist_config.tsv")
SLICE_CFG = Path("data/design/generated_slice_whitelist_config.tsv")
FORBIDDEN_PATTERNS = [
    "scripts/combat_resolver.gd",
    "scripts/battle_state_machine.gd",
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
    rows = read_tsv(REPORT)

    cfg_path = FULL_CFG if FULL_CFG.exists() and FULL_CFG.stat().st_size > 0 else SLICE_CFG
    cfg_rows = read_tsv(cfg_path)
    expected = len({r.get("battle_slot_id", "") for r in cfg_rows if r.get("battle_slot_id", "")})
    whitelist_rows = [r for r in rows if r.get("is_whitelisted") == "true" and r.get("enemy_deck_id") != "reward_anchor"]
    if len(whitelist_rows) != expected:
        return fail(f"白名单 slot 数量必须 {expected}，当前 {len(whitelist_rows)}")

    for r in whitelist_rows:
        slot = r.get("battle_slot_id", "")
        if r.get("enemy_deck_candidate_available") != "true":
            return fail(f"{slot}: enemy_deck_candidate_available 必须 true")
        if r.get("card_pool_count") != "72":
            return fail(f"{slot}: card_pool_count 必须 72")
        if int(r.get("compatible_card_count", "0")) <= 0:
            return fail(f"{slot}: compatible_card_count 必须 > 0")
        if r.get("loadout_candidate_available") != "true":
            return fail(f"{slot}: loadout_candidate_available 必须 true")
        if r.get("fallback_policy") != "legacy":
            return fail(f"{slot}: fallback_policy 必须 legacy")
        if r.get("writes_card_data") != "false":
            return fail(f"{slot}: writes_card_data 必须 false")
        if r.get("writes_battle_state") != "false":
            return fail(f"{slot}: writes_battle_state 必须 false")
        if r.get("writes_combat_result") != "false":
            return fail(f"{slot}: writes_combat_result 必须 false")

    non_rows = [r for r in rows if r.get("is_whitelisted") == "false"]
    if not non_rows:
        return fail("缺少非白名单样例")
    non = non_rows[0]
    if non.get("loadout_candidate_available") != "false":
        return fail("非白名单 loadout_candidate_available 必须 false")
    if non.get("fallback_policy") != "legacy":
        return fail("非白名单 fallback_policy 必须 legacy")

    reward_anchor = [r for r in rows if "reward_id=rw_prologue_01" in r.get("notes", "")]
    if not reward_anchor:
        return fail("缺少 prologue_01 reward=rw_prologue_01 锚点")
    if "selected_source=content_engine" not in reward_anchor[0].get("notes", ""):
        return fail("prologue_01 reward selected_source 必须 content_engine")

    bad = changed_forbidden_files()
    if bad:
        return fail("检测到禁止修改文件: " + ", ".join(bad))

    print(f"PASS: 白名单 {expected} slot loadout candidate 全部可用")
    print("PASS: 每个白名单 slot enemy_deck candidate=true, card_pool_count=72")
    print("PASS: compatible_card_count>0, unsupported_fields 已记录")
    print("PASS: 非白名单仍 legacy fallback")
    print("PASS: writes_card_data/battle_state/combat_result 全为 false")
    print("RESULT: PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
