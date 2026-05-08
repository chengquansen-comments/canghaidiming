#!/usr/bin/env python3
"""v2.5 generated map/route domain formal validator。"""

from __future__ import annotations

import csv
import subprocess
from pathlib import Path

REPORT = Path("data/design/generated_map_route_domain_formal_report.tsv")
REQ_DOMAINS = {"battle_slot", "operation_node", "narrative", "route_gate", "reward", "enemy_deck", "card_pool"}
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

    rows = read_tsv(REPORT)
    prologue = [r for r in rows if r.get("battle_slot_id") == "prologue_01"]
    if {r.get("domain", "") for r in prologue} != REQ_DOMAINS:
        return fail("prologue_01 未覆盖要求 domain")

    idx = {r.get("domain", ""): r for r in prologue}
    if idx["battle_slot"].get("candidate_available") != "true":
        return fail("battle_slot candidate_available 必须 true")
    if idx["operation_node"].get("candidate_count") != "10":
        return fail("operation_node candidate_count 必须 10")
    if idx["narrative"].get("candidate_count") != "28":
        return fail("narrative candidate_count 必须 28")
    if idx["route_gate"].get("candidate_count") != "9":
        return fail("route_gate candidate_count 必须 9")

    if "key/hook" not in idx["narrative"].get("notes", ""):
        return fail("narrative 必须仅 key/hook")
    if idx["route_gate"].get("writes_formal_flow") != "false":
        return fail("route_gate writes_formal_flow 必须 false")

    if idx["reward"].get("candidate_id") != "rw_prologue_01":
        return fail("reward candidate_id 必须 rw_prologue_01")
    if idx["enemy_deck"].get("candidate_available") != "true":
        return fail("enemy_deck candidate_available 必须 true")
    if idx["card_pool"].get("candidate_count") != "72":
        return fail("card_pool candidate_count 必须 72")

    for domain in REQ_DOMAINS:
        r = idx[domain]
        if r.get("fallback_policy") != "legacy":
            return fail(f"{domain}: fallback_policy 必须 legacy")
        if r.get("legacy_fallback_available") != "true":
            return fail(f"{domain}: legacy_fallback_available 必须 true")

    non_whitelist = [r for r in rows if r.get("battle_slot_id") != "prologue_01"]
    if not non_whitelist:
        return fail("缺少非白名单样例")
    if any(r.get("formal_source") != "legacy" for r in non_whitelist):
        return fail("非白名单 formal_source 必须 legacy")

    bad = changed_forbidden_files()
    if bad:
        return fail("检测到禁止修改文件: " + ", ".join(bad))

    print("PASS: report 存在且 prologue_01 覆盖 7 domain")
    print("PASS: battle_slot/operation_node/narrative/route_gate 计数正确")
    print("PASS: narrative 仅 key/hook，route_gate 不写正式分流")
    print("PASS: reward=rw_prologue_01, enemy_deck available, card_pool_count=72")
    print("PASS: 非白名单仍 legacy，fallback_policy=legacy")
    print("PASS: 未改 combat_resolver/battle_state_machine/card_data/story_battles/scenes")
    print("RESULT: PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
