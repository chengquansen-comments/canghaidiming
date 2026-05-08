#!/usr/bin/env python3
"""v2.6 full domain enable acceptance validator。"""

from __future__ import annotations

import csv
import subprocess
from pathlib import Path

REPORT = Path("data/design/generated_full_domain_enable_acceptance_report.tsv")
REQ_DOMAINS = {"battle_slot", "enemy_deck", "card_pool", "reward", "operation_node", "narrative", "route_gate"}
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
    slots = {r.get("battle_slot_id", "") for r in rows}
    if slots != {"prologue_01", "sample_non_whitelist"}:
        return fail(f"slot 覆盖异常: {sorted(slots)}")

    prologue = [r for r in rows if r.get("battle_slot_id") == "prologue_01"]
    if {r.get("domain", "") for r in prologue} != REQ_DOMAINS:
        return fail("prologue_01 未覆盖 7 domain")

    idx = {r.get("domain", ""): r for r in prologue}
    if idx["reward"].get("candidate_id") != "rw_prologue_01":
        return fail("reward 必须 rw_prologue_01")
    if idx["enemy_deck"].get("candidate_available") != "true":
        return fail("enemy_deck candidate_available 必须 true")
    if idx["card_pool"].get("candidate_count") != "72":
        return fail("card_pool_count 必须 72")
    if idx["operation_node"].get("candidate_count") != "10":
        return fail("operation_node_count 必须 10")
    if idx["narrative"].get("candidate_count") != "28":
        return fail("narrative_count 必须 28")
    if "no body" not in idx["narrative"].get("notes", ""):
        return fail("narrative 必须无正文，仅 key/hook")
    if idx["route_gate"].get("candidate_count") != "9":
        return fail("route_gate_count 必须 9")
    if "writes_formal_flow=false" not in idx["route_gate"].get("notes", ""):
        return fail("route_gate 不得改变正式分流")
    if idx["battle_slot"].get("formal_source") != "content_engine":
        return fail("battle_slot formal_source 必须 content_engine")

    for d in REQ_DOMAINS:
        r = idx[d]
        if r.get("rollback_to_legacy_ok") != "true":
            return fail(f"{d}: rollback_to_legacy_ok 必须 true")
        if r.get("non_whitelist_legacy_ok") != "true":
            return fail(f"{d}: non_whitelist_legacy_ok 必须 true")
        if r.get("writes_game_state") != "false":
            return fail(f"{d}: writes_game_state 必须 false")
        if r.get("rollback_policy") != "legacy":
            return fail(f"{d}: rollback_policy 必须 legacy")

    non_rows = [r for r in rows if r.get("battle_slot_id") == "sample_non_whitelist"]
    if len(non_rows) != 1:
        return fail("非白名单样例行数必须为 1")
    non = non_rows[0]
    if non.get("formal_source") != "legacy":
        return fail("非白名单 formal_source 必须 legacy")
    if non.get("rollback_to_legacy_ok") != "true" or non.get("non_whitelist_legacy_ok") != "true":
        return fail("非白名单 legacy/rollback 检查失败")
    if non.get("writes_game_state") != "false":
        return fail("非白名单 writes_game_state 必须 false")

    bad = changed_forbidden_files()
    if bad:
        return fail("检测到禁止修改文件: " + ", ".join(bad))

    print("PASS: report 存在，覆盖 prologue_01 + 非白名单样例")
    print("PASS: prologue_01 覆盖 7 domain 且计数/ID 正确")
    print("PASS: rollback_to_legacy_ok=true, non_whitelist_legacy_ok=true")
    print("PASS: narrative 无正文，route_gate 不改变正式分流")
    print("PASS: writes_game_state=false，未改核心/scene/story 文件")
    print("RESULT: PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
