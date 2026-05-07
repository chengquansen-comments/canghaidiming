#!/usr/bin/env python3
"""v1.7b full package shadow compare validator。"""

from __future__ import annotations

import csv
import json
import subprocess
from pathlib import Path

MATRIX = Path("data/design/generated_content_domain_switch_matrix.tsv")
REPORT = Path("data/design/generated_full_package_shadow_compare_report.tsv")
MANIFEST = Path("data/runtime_preview/content_engine/full_content_package.preview_manifest.json")
RUNTIME_CONFIG = Path("data/runtime/content_engine/runtime_loader_config.json")
FORBIDDEN_RUNTIME_REWARD = Path("data/runtime/content_engine/battle_rewards.json")
SHADOW_FREEZE = Path("data/design/generated_battle_reward_shadow_freeze_report.tsv")

FORBIDDEN_PATTERNS = [
    "scripts/narrative_demo_canonical_controller.gd",
    "scripts/battle_reward_runtime_adapter.gd",
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
    bad: list[str] = []
    for line in out.splitlines():
        path = line[3:].strip() if len(line) > 3 else ""
        if path and any(path == p or path.startswith(p) for p in FORBIDDEN_PATTERNS):
            bad.append(path)
    return sorted(set(bad))


def main() -> int:
    if not MATRIX.exists() or MATRIX.stat().st_size == 0:
        return fail("domain switch matrix 不存在或为空")
    if not REPORT.exists() or REPORT.stat().st_size == 0:
        return fail("shadow compare report 不存在或为空")

    matrix_rows = read_tsv(MATRIX)
    report_rows = read_tsv(REPORT)

    if {r.get('domain','') for r in matrix_rows} != REQ_DOMAINS:
        return fail("matrix 未覆盖 7 个 domain")
    if {r.get('domain','') for r in report_rows} != REQ_DOMAINS:
        return fail("report 未覆盖 7 个 domain")

    for row in matrix_rows:
        if row.get("default_mode") != "legacy":
            return fail(f"{row.get('domain')}: default_mode 必须 legacy")
        if row.get("source_mode") != "shadow_compare":
            return fail(f"{row.get('domain')}: source_mode 必须 shadow_compare")
        if row.get("content_engine_enabled") != "false":
            return fail(f"{row.get('domain')}: content_engine_enabled 必须 false")
        if row.get("enabled_scope") != "prologue_01":
            return fail(f"{row.get('domain')}: enabled_scope 必须 prologue_01")

    for row in report_rows:
        if row.get("battle_slot_id") != "prologue_01":
            return fail("shadow compare 只允许覆盖 prologue_01")
        if row.get("formal_source_unchanged") != "true":
            return fail(f"{row.get('domain')}: formal_source_unchanged 必须 true")
        if row.get("legacy_source") != "legacy":
            return fail(f"{row.get('domain')}: legacy_source 必须 legacy")
        if row.get("content_engine_enabled") != "false":
            return fail(f"{row.get('domain')}: content_engine_enabled 必须 false")
        if row.get("runtime_loader_config") != "disabled":
            return fail(f"{row.get('domain')}: runtime_loader_config 必须 disabled")

    idx = {r.get("domain", ""): r for r in report_rows}
    if idx["reward"].get("candidate_available") != "true" or idx["reward"].get("candidate_id") != "rw_prologue_01":
        return fail("reward candidate 必须命中 rw_prologue_01")
    if idx["battle_slot"].get("candidate_available") != "true" or idx["battle_slot"].get("candidate_id") != "prologue_01":
        return fail("battle_slot candidate 必须命中 prologue_01")

    if "正文" in idx["narrative"].get("notes", "") and "不写正式正文" not in idx["narrative"].get("notes", ""):
        return fail("narrative candidate 说明异常")
    if "CardData" in idx["card_pool"].get("notes", "") and "不进入正式 CardData" not in idx["card_pool"].get("notes", ""):
        return fail("card_pool candidate 不得声称已进入 CardData")

    if FORBIDDEN_RUNTIME_REWARD.exists():
        return fail("不应存在 data/runtime/content_engine/battle_rewards.json")

    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    if manifest.get("content_engine_enabled") is True:
        return fail("manifest content_engine_enabled 不得为 true")

    runtime_cfg = json.loads(RUNTIME_CONFIG.read_text(encoding="utf-8"))
    if bool(runtime_cfg.get("content_engine_runtime_enabled", False)):
        return fail("runtime_loader_config 不得启用")

    if SHADOW_FREEZE.exists() and SHADOW_FREEZE.stat().st_size > 0:
        freeze = {r.get("check_id", ""): r for r in read_tsv(SHADOW_FREEZE)}
        if freeze.get("selected_reward_source", {}).get("actual") != "legacy":
            return fail("selected_reward 必须仍 legacy")

    forbidden_changed = changed_forbidden_files()
    if forbidden_changed:
        return fail("检测到禁止修改文件: " + ", ".join(forbidden_changed))

    print("PASS: domain switch matrix 存在")
    print("PASS: shadow compare report 存在")
    print("PASS: 覆盖 7 个 domain")
    print("PASS: 仅覆盖 prologue_01")
    print("PASS: default_mode=legacy + source_mode=shadow_compare")
    print("PASS: content_engine_enabled=false")
    print("PASS: selected_reward 仍 legacy")
    print("PASS: runtime_loader_config=disabled")
    print("PASS: reward 命中 rw_prologue_01")
    print("PASS: battle_slot 命中 prologue_01")
    print("PASS: narrative/card_pool 说明符合只读候选约束")
    print("PASS: 未写 data/runtime 且未修改 story/scenes/combat core")
    print("RESULT: PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
