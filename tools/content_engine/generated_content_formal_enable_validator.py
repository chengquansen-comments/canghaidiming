#!/usr/bin/env python3
"""v2.3 generated content formal enable validator。"""

from __future__ import annotations

import csv
import json
import subprocess
from pathlib import Path

REPORT = Path("data/design/generated_content_formal_enable_report.tsv")
RUNTIME_CFG = Path("data/runtime/content_engine/runtime_loader_config.json")
SHADOW_FREEZE = Path("data/design/generated_battle_reward_shadow_freeze_report.tsv")

FORBIDDEN_PATTERNS = [
    "scripts/combat_resolver.gd",
    "scripts/battle_state_machine.gd",
    "scripts/card_data.gd",
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
    if idx["reward"].get("formal_selected_source") != "content_engine":
        return fail("reward formal_selected_source 必须 content_engine")
    if idx["reward"].get("candidate_id") != "rw_prologue_01":
        return fail("reward candidate_id 必须 rw_prologue_01")

    if idx["battle_slot"].get("candidate_id") != "prologue_01":
        return fail("battle_slot candidate_id 必须 prologue_01")

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

    if idx["enemy_deck"].get("notes", "").find("resolver") < 0:
        return fail("enemy_deck 需明确不进入 resolver")
    if idx["card_pool"].get("notes", "").find("CardData") < 0:
        return fail("card_pool 需明确不写 CardData")
    if idx["narrative"].get("notes", "").find("key/hook") < 0:
        return fail("narrative 需明确仅 key/hook")
    if idx["route_gate"].get("notes", "").find("正式分流") < 0:
        return fail("route_gate 需明确不改变正式分流")

    non_whitelist = [r for r in rows if r.get("battle_slot_id") != "prologue_01" and r.get("domain") == "reward"]
    if not non_whitelist:
        return fail("缺少非白名单 legacy 样例")
    if any(r.get("formal_selected_source") != "legacy" for r in non_whitelist):
        return fail("非白名单必须 legacy")

    cfg = json.loads(RUNTIME_CFG.read_text(encoding="utf-8"))
    if bool(cfg.get("content_engine_runtime_enabled", False)):
        return fail("runtime_loader_config 必须 disabled")

    if SHADOW_FREEZE.exists() and SHADOW_FREEZE.stat().st_size > 0:
        freeze = {r.get("check_id", ""): r for r in read_tsv(SHADOW_FREEZE)}
        if freeze.get("selected_reward_source", {}).get("actual") != "legacy":
            return fail("selected_reward 基线必须仍 legacy")

    bad = changed_forbidden_files()
    if bad:
        return fail("检测到禁止修改文件: " + ", ".join(bad))

    print("PASS: report 存在，prologue_01 覆盖 7 domain")
    print("PASS: reward formal_selected_source=content_engine, candidate=rw_prologue_01")
    print("PASS: 非白名单 reward 仍 legacy")
    print("PASS: enemy_deck/card_pool/narrative/route_gate 均为只读 candidate")
    print("PASS: fallback_policy=legacy, game_state_written=false")
    print("PASS: 未改 story/scenes/combat core")
    print("RESULT: PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
