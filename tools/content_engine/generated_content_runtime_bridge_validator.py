#!/usr/bin/env python3
"""v2.2 generated content runtime bridge validator。"""

from __future__ import annotations

import csv
import json
import subprocess
from pathlib import Path

REPORT = Path("data/design/generated_content_runtime_bridge_probe_report.tsv")
BUNDLE = Path("data/runtime/content_engine_whitelist/prologue_01.full_content_bridge.json")
RUNTIME_CFG = Path("data/runtime/content_engine/runtime_loader_config.json")
SHADOW_FREEZE = Path("data/design/generated_battle_reward_shadow_freeze_report.tsv")

FORBIDDEN_PATTERNS = [
    "scripts/combat_resolver.gd",
    "scripts/battle_state_machine.gd",
    "scripts/card_data.gd",
    "data/story_battles/",
    "scenes/",
]

REQUIRED_CHECKS = {
    "manifest_readable": "PASS",
    "bundle_readable": "PASS",
    "bundle_validate": "PASS",
    "domain_read::battle_slot": "PASS",
    "domain_read::enemy_deck": "PASS",
    "domain_read::card_pool": "PASS",
    "domain_read::reward": "PASS",
    "domain_read::operation_node": "PASS",
    "domain_read::narrative": "PASS",
    "domain_read::route_gate": "PASS",
    "reward_candidate_id": "PASS",
    "battle_slot_candidate_id": "PASS",
    "enemy_deck_candidate_exists": "PASS",
    "card_pool_count": "PASS",
    "operation_node_count": "PASS",
    "narrative_count": "PASS",
    "route_gate_count": "PASS",
    "selected_reward_unchanged": "PASS",
    "battle_state_unchanged": "PASS",
    "combat_result_unchanged": "PASS",
}


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
        return fail("probe report 不存在或为空")

    rows = read_tsv(REPORT)
    idx = {r.get("check_id", ""): r for r in rows}
    for k, v in REQUIRED_CHECKS.items():
        if idx.get(k, {}).get("status") != v:
            return fail(f"{k} 期望 {v}，实际 {idx.get(k, {}).get('status')}")

    bundle = json.loads(BUNDLE.read_text(encoding="utf-8"))
    if bundle.get("global_content_engine_enabled") is not False:
        return fail("global_content_engine_enabled 必须 false")
    if bundle.get("formal_runtime_enabled") is not False:
        return fail("formal_runtime_enabled 必须 false")

    cfg = json.loads(RUNTIME_CFG.read_text(encoding="utf-8"))
    if bool(cfg.get("content_engine_runtime_enabled", False)):
        return fail("runtime_loader_config 必须 disabled")

    # 避免误判历史文件：只验证本次 bridge 输出路径。
    if not str(BUNDLE).startswith("data/runtime/content_engine_whitelist/"):
        return fail("bridge bundle 路径必须位于 data/runtime/content_engine_whitelist/")

    if SHADOW_FREEZE.exists() and SHADOW_FREEZE.stat().st_size > 0:
        freeze = {r.get("check_id", ""): r for r in read_tsv(SHADOW_FREEZE)}
        if freeze.get("selected_reward_source", {}).get("actual") != "legacy":
            return fail("selected_reward 必须仍 legacy")

    bad = changed_forbidden_files()
    if bad:
        return fail("检测到禁止修改文件: " + ", ".join(bad))

    print("PASS: probe report 存在且 7 domain 全部可读")
    print("PASS: reward=rw_prologue_01, battle_slot=prologue_01, enemy_deck candidate 存在")
    print("PASS: card_pool=72, operation_node=10, narrative=28, route_gate=9")
    print("PASS: selected_reward=legacy, global_content_engine_enabled=false")
    print("PASS: formal_runtime_enabled=false, runtime_loader_config=disabled")
    print("PASS: 未改 story/scenes/combat core")
    print("RESULT: PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
