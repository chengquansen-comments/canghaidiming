#!/usr/bin/env python3
from __future__ import annotations

import csv
import subprocess
from pathlib import Path

REPORT = Path("data/design/generated_slice_full_integration_acceptance_report.tsv")
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
    whitelist_rows = [r for r in rows if r.get("is_whitelisted") == "true" and r.get("domain") in {"battle_slot","enemy_deck","card_pool","reward","operation_node","narrative","route_gate"}]
    slots = sorted({r.get("battle_slot_id", "") for r in whitelist_rows})
    if len(slots) != 11:
        return fail(f"白名单 slot 数量必须 11，当前 {len(slots)}")

    req_domains = {"battle_slot","enemy_deck","card_pool","reward","operation_node","narrative","route_gate"}
    for s in slots:
        srows = [r for r in whitelist_rows if r.get("battle_slot_id") == s]
        d = {r.get("domain", "") for r in srows}
        if d != req_domains:
            return fail(f"{s}: 7 domain 覆盖不完整")
        idx = {r["domain"]: r for r in srows}
        if idx["enemy_deck"].get("candidate_available") != "true":
            return fail(f"{s}: enemy_deck candidate 不可用")
        if idx["card_pool"].get("candidate_count") != "72":
            return fail(f"{s}: card_pool_count 必须 72")
        if idx["operation_node"].get("candidate_count") != "10":
            return fail(f"{s}: operation_node_count 必须 10")
        if idx["narrative"].get("candidate_count") != "28":
            return fail(f"{s}: narrative_key_count 必须 28")
        if "narrative_keys_only=true" not in idx["narrative"].get("notes", ""):
            return fail(f"{s}: narrative 必须仅 key/hook")
        if idx["route_gate"].get("candidate_count") != "9":
            return fail(f"{s}: route_gate_count 必须 9")
        if "route_gate_writes_formal_flow=false" not in idx["route_gate"].get("notes", ""):
            return fail(f"{s}: route_gate 不得改变正式分流")
        for dname in req_domains:
            r = idx[dname]
            if r.get("rollback_to_legacy_ok") != "true":
                return fail(f"{s}/{dname}: rollback_to_legacy_ok 必须 true")
            if r.get("writes_card_data") != "false" or r.get("writes_story_data") != "false" or r.get("writes_battle_state") != "false" or r.get("writes_combat_result") != "false":
                return fail(f"{s}/{dname}: writes_* 必须全 false")

    prologue_reward = [r for r in whitelist_rows if r.get("battle_slot_id") == "prologue_01" and r.get("domain") == "reward"]
    if not prologue_reward:
        return fail("缺少 prologue_01 reward 记录")
    if prologue_reward[0].get("candidate_id") != "rw_prologue_01":
        return fail("prologue_01 reward 必须 rw_prologue_01")

    missing_reward_slots = [
        r.get("battle_slot_id") for r in whitelist_rows
        if r.get("domain") == "reward" and r.get("candidate_available") == "false"
    ]
    for s in missing_reward_slots:
        row = next(x for x in whitelist_rows if x.get("battle_slot_id") == s and x.get("domain") == "reward")
        if row.get("formal_source") != "legacy":
            return fail(f"{s}: reward 缺失时必须 fallback legacy")

    non_rows = [r for r in rows if r.get("is_whitelisted") == "false"]
    if len(non_rows) < 7:
        return fail("非白名单样例不足")
    if any(r.get("formal_source") != "legacy" for r in non_rows):
        return fail("非白名单 formal_source 必须 legacy")

    # anchors: loadout+map route usable
    anchors = [r for r in rows if r.get("domain") == "integration_anchor"]
    if len(anchors) != 11:
        return fail("integration_anchor 数量必须 11")
    for a in anchors:
        note = a.get("notes", "")
        if "loadout=true" not in note or "map_route=true" not in note:
            return fail(f"{a.get('battle_slot_id','')}: loadout/map_route 可用性失败")

    bad = changed_forbidden_files()
    if bad:
        return fail("检测到禁止修改文件: " + ", ".join(bad))

    print("PASS: 白名单 11 slot 覆盖 7 domain 且全域候选可用")
    print("PASS: prologue_01 reward=rw_prologue_01，reward 缺失可 fallback legacy")
    print("PASS: narrative 仅 key/hook，route_gate 不改正式分流")
    print("PASS: 非白名单 legacy，rollback_to_legacy=true")
    print("PASS: writes_card_data/story/battle/combat 全 false，未改核心文件")
    print("RESULT: PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
