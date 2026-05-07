#!/usr/bin/env python3
"""v1.7 full preview readonly validator。"""

from __future__ import annotations

import csv
import json
import subprocess
from pathlib import Path

PY_REPORT = Path("data/design/generated_full_preview_readonly_probe_report.tsv")
GODOT_REPORT = Path("data/design/generated_full_preview_godot_readonly_report.tsv")
MANIFEST = Path("data/runtime_preview/content_engine/full_content_package.preview_manifest.json")
RUNTIME_CONFIG = Path("data/runtime/content_engine/runtime_loader_config.json")
FORBIDDEN_RUNTIME_REWARD = Path("data/runtime/content_engine/battle_rewards.json")
SHADOW_FREEZE_REPORT = Path("data/design/generated_battle_reward_shadow_freeze_report.tsv")

FORBIDDEN_PATTERNS = [
    "scripts/narrative_demo_canonical_controller.gd",
    "scripts/battle_reward_runtime_adapter.gd",
    "scripts/combat_resolver.gd",
    "scripts/battle_state_machine.gd",
    "scripts/card_data.gd",
    "data/story_battles/",
    "scenes/",
]
EXPECTED = {
    "battle_rewards": 45,
    "battle_slots": 16,
    "enemy_decks": 39,
    "card_pool": 72,
    "operation_nodes": 10,
    "narrative_nodes": 28,
    "route_gates": 9,
}


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
        path = line[3:].strip() if len(line) > 3 else ""
        if path and any(path == p or path.startswith(p) for p in FORBIDDEN_PATTERNS):
            bad.append(path)
    return sorted(set(bad))


def main() -> int:
    if not PY_REPORT.exists() or PY_REPORT.stat().st_size == 0:
        return fail("Python report 不存在或为空")
    if not GODOT_REPORT.exists() or GODOT_REPORT.stat().st_size == 0:
        return fail("Godot report 不存在或为空")

    py_rows = read_tsv(PY_REPORT)
    gd_rows = read_tsv(GODOT_REPORT)
    if any(r.get("status") != "PASS" for r in py_rows):
        return fail("Python report 存在 FAIL 项")

    gd_idx = {r.get("check_id", ""): r for r in gd_rows}
    for domain, expected in EXPECTED.items():
        count_row = gd_idx.get(f"count::{domain}", {})
        if count_row.get("status") != "PASS" or count_row.get("actual") != str(expected):
            return fail(f"{domain} count 异常 expected={expected} actual={count_row.get('actual')}")
        rr = gd_idx.get(f"runtime_ready::{domain}", {})
        if rr.get("status") != "PASS" or rr.get("actual") != "false":
            return fail(f"{domain} runtime_ready 必须 false")
        po = gd_idx.get(f"preview_only::{domain}", {})
        if po.get("status") != "PASS" or po.get("actual") != "true":
            return fail(f"{domain} preview_only 必须 true")

    if FORBIDDEN_RUNTIME_REWARD.exists():
        return fail("不应存在 data/runtime/content_engine/battle_rewards.json")

    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    if manifest.get("selected_reward_policy") != "legacy":
        return fail("selected_reward_policy 必须 legacy")
    if manifest.get("content_engine_enabled") is not False:
        return fail("content_engine_enabled 必须 false")

    runtime_cfg = json.loads(RUNTIME_CONFIG.read_text(encoding="utf-8"))
    if bool(runtime_cfg.get("content_engine_runtime_enabled", False)):
        return fail("runtime_loader_config 不得启用")

    if SHADOW_FREEZE_REPORT.exists() and SHADOW_FREEZE_REPORT.stat().st_size > 0:
        rows = read_tsv(SHADOW_FREEZE_REPORT)
        idx = {r.get("check_id", ""): r for r in rows}
        if idx.get("selected_reward_source", {}).get("actual") != "legacy":
            return fail("selected_reward_source 必须仍为 legacy")

    forbidden_changed = changed_forbidden_files()
    if forbidden_changed:
        return fail("检测到禁止修改文件: " + ", ".join(forbidden_changed))

    print("PASS: Python report 存在")
    print("PASS: Godot report 存在")
    print("PASS: 7 个 domain 数量正确")
    print("PASS: runtime_ready 全部 false")
    print("PASS: preview_only 全部 true")
    print("PASS: 未写 data/runtime/content_engine/battle_rewards.json")
    print("PASS: selected_reward 仍 legacy")
    print("PASS: content_engine_enabled=false")
    print("PASS: 未修改 story/runtime/scenes/battle core")
    print("RESULT: PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
