#!/usr/bin/env python3
from __future__ import annotations

import csv
import subprocess
from pathlib import Path

REPORT = Path("data/design/generated_map_route_runtime_flow_report.tsv")
LOADOUT_REPORT = Path("data/design/generated_battle_runtime_loadout_report.tsv")
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

    whitelist = [r for r in rows if r.get("is_whitelisted") == "true" and "v2_8_loadout=" not in r.get("notes", "")]
    if len(whitelist) != 11:
        return fail(f"白名单 slot 数量必须 11，当前 {len(whitelist)}")

    for r in whitelist:
        slot = r.get("battle_slot_id", "")
        if r.get("battle_slot_candidate_available") != "true":
            return fail(f"{slot}: battle_slot_candidate_available 必须 true")
        if r.get("operation_node_count") != "10":
            return fail(f"{slot}: operation_node_count 必须 10")
        if r.get("narrative_key_count") != "28":
            return fail(f"{slot}: narrative_key_count 必须 28")
        if r.get("narrative_keys_only") != "true":
            return fail(f"{slot}: narrative_keys_only 必须 true")
        if r.get("route_gate_count") != "9":
            return fail(f"{slot}: route_gate_count 必须 9")
        if r.get("route_gate_writes_formal_flow") != "false":
            return fail(f"{slot}: route_gate_writes_formal_flow 必须 false")
        if r.get("map_route_candidate_available") != "true":
            return fail(f"{slot}: map_route_candidate_available 必须 true")
        if r.get("fallback_policy") != "legacy":
            return fail(f"{slot}: fallback_policy 必须 legacy")
        if r.get("writes_story_data") != "false" or r.get("writes_battle_state") != "false" or r.get("writes_combat_result") != "false":
            return fail(f"{slot}: writes_* 必须全 false")

    non = [r for r in rows if r.get("is_whitelisted") == "false"]
    if not non:
        return fail("缺少非白名单样例")
    if non[0].get("map_route_candidate_available") != "false" or non[0].get("fallback_policy") != "legacy":
        return fail("非白名单必须 legacy")

    anchor = [r for r in rows if "v2_8_loadout=" in r.get("notes", "")]
    if not anchor:
        return fail("缺少 v2.8 loadout / reward 锚点")
    note = anchor[0].get("notes", "")
    if "v2_8_loadout=true" not in note:
        return fail("v2.8 battle loadout 仍有效校验失败")
    if "reward_selected_source=content_engine" not in note:
        return fail("reward 白名单仍可用校验失败")

    if not LOADOUT_REPORT.exists() or LOADOUT_REPORT.stat().st_size == 0:
        return fail("v2.8 loadout report 缺失")

    bad = changed_forbidden_files()
    if bad:
        return fail("检测到禁止修改文件: " + ", ".join(bad))

    print("PASS: 白名单 11 slot map_route_runtime_candidate 全部可用")
    print("PASS: operation=10 narrative=28 route_gate=9 且不写正式分流")
    print("PASS: 非白名单 legacy，fallback_policy=legacy")
    print("PASS: v2.8 battle loadout 仍有效，reward 白名单仍可用")
    print("PASS: 未写 story/battle/combat state，未改核心文件")
    print("RESULT: PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
