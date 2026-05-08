#!/usr/bin/env python3
"""v2.4 generated battle domain formal validator。"""

from __future__ import annotations

import csv
import subprocess
from pathlib import Path

REPORT = Path("data/design/generated_battle_domain_formal_report.tsv")
FORBIDDEN_PATTERNS = [
    "scripts/combat_resolver.gd",
    "scripts/battle_state_machine.gd",
    "data/story_battles/",
    "scenes/",
]
REQ_DOMAINS = {"battle_slot", "enemy_deck", "card_pool", "reward", "operation_node", "narrative", "route_gate"}


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
    prologue = [r for r in rows if r.get("battle_slot_id") == "prologue_01"]
    if {r.get("domain", "") for r in prologue} != REQ_DOMAINS:
        return fail("prologue_01 未覆盖 7 domain")

    idx = {r.get("domain", ""): r for r in prologue}
    if idx["enemy_deck"].get("candidate_available") != "true":
        return fail("enemy_deck candidate_available 必须 true")
    if idx["card_pool"].get("candidate_count") != "72":
        return fail("card_pool candidate_count 必须 72")
    if idx["reward"].get("candidate_id") != "rw_prologue_01":
        return fail("reward candidate_id 必须 rw_prologue_01")
    if idx["reward"].get("formal_source") != "content_engine":
        return fail("reward formal_source 必须 content_engine")

    if "CardData" not in idx["card_pool"].get("notes", ""):
        return fail("card_pool notes 必须声明不写 CardData")
    if "resolver" not in idx["enemy_deck"].get("notes", ""):
        return fail("enemy_deck notes 必须声明不进入 resolver")
    if "key/hook" not in idx["narrative"].get("notes", ""):
        return fail("narrative notes 必须声明仅 key/hook")
    if "正式分流" not in idx["route_gate"].get("notes", ""):
        return fail("route_gate notes 必须声明不改正式分流")

    for d in REQ_DOMAINS:
        r = idx[d]
        if r.get("generated_content_enabled") != "true":
            return fail(f"{d}: generated_content_enabled 必须 true")
        if r.get("fallback_policy") != "legacy":
            return fail(f"{d}: fallback_policy 必须 legacy")
        if r.get("legacy_fallback_available") != "true":
            return fail(f"{d}: legacy_fallback_available 必须 true")
        if r.get("game_state_written") != "false":
            return fail(f"{d}: game_state_written 必须 false")

    non_whitelist = [r for r in rows if r.get("battle_slot_id") != "prologue_01" and r.get("domain") == "reward"]
    if not non_whitelist:
        return fail("缺少非白名单 legacy 样例")
    if any(r.get("formal_source") != "legacy" for r in non_whitelist):
        return fail("非白名单 formal_source 必须 legacy")

    bad = changed_forbidden_files()
    if bad:
        return fail("检测到禁止修改文件: " + ", ".join(bad))

    print("PASS: report 存在，prologue_01 覆盖 7 domain")
    print("PASS: enemy_deck candidate=true, card_pool_count=72")
    print("PASS: reward=rw_prologue_01 且 formal_source=content_engine")
    print("PASS: 非白名单仍 legacy")
    print("PASS: fallback_policy=legacy, game_state_written=false")
    print("PASS: 未改 combat_resolver/battle_state_machine/story_battles/scenes")
    print("RESULT: PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
