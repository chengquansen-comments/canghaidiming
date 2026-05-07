#!/usr/bin/env python3
"""v1.8 whitelist full package candidate path validator。"""

from __future__ import annotations

import csv
import json
import subprocess
from pathlib import Path

REPORT = Path("data/design/generated_full_package_candidate_path_report.tsv")
RUNTIME_CONFIG = Path("data/runtime/content_engine/runtime_loader_config.json")
SHADOW_FREEZE = Path("data/design/generated_battle_reward_shadow_freeze_report.tsv")
FORBIDDEN_RUNTIME_REWARD = Path("data/runtime/content_engine/battle_rewards.json")

REQ_DOMAINS = {"battle_slot", "enemy_deck", "card_pool", "reward", "operation_node", "narrative", "route_gate"}
FORBIDDEN_PATTERNS = [
    "scripts/narrative_demo_canonical_controller.gd",
    "scripts/battle_reward_runtime_adapter.gd",
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
    bad: list[str] = []
    for line in out.splitlines():
        p = line[3:].strip() if len(line) > 3 else ""
        if p and any(p == t or p.startswith(t) for t in FORBIDDEN_PATTERNS):
            bad.append(p)
    return sorted(set(bad))


def main() -> int:
    if not REPORT.exists() or REPORT.stat().st_size == 0:
        return fail("report 不存在或为空")

    rows = read_tsv(REPORT)
    if {r.get("domain", "") for r in rows} != REQ_DOMAINS:
        return fail("未覆盖 7 个 domain")
    if any(r.get("battle_slot_id") != "prologue_01" for r in rows):
        return fail("只允许覆盖 prologue_01")

    idx = {r.get("domain", ""): r for r in rows}
    if idx["reward"].get("candidate_id") != "rw_prologue_01" or idx["reward"].get("candidate_available") != "true":
        return fail("reward candidate 必须 rw_prologue_01")
    if idx["battle_slot"].get("candidate_id") != "prologue_01" or idx["battle_slot"].get("candidate_available") != "true":
        return fail("battle_slot candidate 必须 prologue_01")
    if idx["card_pool"].get("candidate_count") != "72":
        return fail("card_pool candidate_count 必须 72")
    if idx["operation_node"].get("candidate_count") != "10":
        return fail("operation_node candidate_count 必须 10")
    if idx["route_gate"].get("candidate_count") != "9":
        return fail("route_gate candidate_count 必须 9")

    if "正文" in idx["narrative"].get("notes", "") and "不包含正文" not in idx["narrative"].get("notes", ""):
        return fail("narrative 不得包含正文")

    for r in rows:
        if r.get("formal_source") != "legacy" or r.get("formal_source_unchanged") != "true":
            return fail(f"{r.get('domain')}: formal_source 必须 legacy 且 unchanged=true")
        if r.get("content_engine_enabled") != "false":
            return fail(f"{r.get('domain')}: content_engine_enabled 必须 false")
        if r.get("runtime_loader_config") != "disabled":
            return fail(f"{r.get('domain')}: runtime_loader_config 必须 disabled")

    cfg = json.loads(RUNTIME_CONFIG.read_text(encoding="utf-8"))
    if bool(cfg.get("content_engine_runtime_enabled", False)):
        return fail("runtime_loader_config 不得启用")

    if SHADOW_FREEZE.exists() and SHADOW_FREEZE.stat().st_size > 0:
        freeze = {r.get("check_id", ""): r for r in read_tsv(SHADOW_FREEZE)}
        if freeze.get("selected_reward_source", {}).get("actual") != "legacy":
            return fail("selected_reward 必须仍 legacy")

    if FORBIDDEN_RUNTIME_REWARD.exists():
        return fail("不应存在 data/runtime/content_engine/battle_rewards.json")

    forbidden = changed_forbidden_files()
    if forbidden:
        return fail("检测到禁止修改文件: " + ", ".join(forbidden))

    print("PASS: report 存在")
    print("PASS: 仅覆盖 prologue_01")
    print("PASS: 覆盖 7 个 domain")
    print("PASS: reward=rw_prologue_01, battle_slot=prologue_01")
    print("PASS: card_pool=72, operation_node=10, route_gate=9")
    print("PASS: narrative 仅 key/hook")
    print("PASS: content_engine_enabled=false")
    print("PASS: selected_reward=legacy")
    print("PASS: 未写 data/runtime 且未改 story/scenes/combat core")
    print("RESULT: PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
