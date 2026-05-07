#!/usr/bin/env python3
"""v1.4 reward candidate switch skeleton validator。"""

from __future__ import annotations

import csv
import json
import subprocess
from pathlib import Path

REPORT = Path("data/design/generated_reward_candidate_switch_probe_report.tsv")
MODE_CONFIG = Path("data/design/reward_source_mode_config.tsv")
RUNTIME_CONFIG = Path("data/runtime/content_engine/runtime_loader_config.json")
FORBIDDEN_RUNTIME_REWARD = Path("data/runtime/content_engine/battle_rewards.json")

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


def read_default_mode() -> str:
    if not MODE_CONFIG.exists():
        return "legacy"
    rows = read_tsv(MODE_CONFIG)
    for row in rows:
        if row.get("config_key", "").strip() == "reward_source_mode":
            return row.get("config_value", "").strip() or "legacy"
    return "legacy"


def changed_forbidden_files() -> list[str]:
    out = subprocess.check_output(["git", "status", "--porcelain"], text=True)
    bad: list[str] = []
    for line in out.splitlines():
        path = line[3:].strip() if len(line) > 3 else ""
        if not path:
            continue
        if any(path == p or path.startswith(p) for p in FORBIDDEN_PATTERNS):
            bad.append(path)
    return sorted(set(bad))


def main() -> int:
    if not REPORT.exists() or REPORT.stat().st_size == 0:
        return fail("report 不存在或为空")

    rows = read_tsv(REPORT)
    if len(rows) != 4:
        return fail(f"report 行数应为 4（四种 mode），实际 {len(rows)}")

    row_by_mode = {r.get("mode", ""): r for r in rows}
    required_modes = ["legacy", "shadow_compare", "content_engine_candidate", "content_engine_enabled"]
    for mode in required_modes:
        if mode not in row_by_mode:
            return fail(f"缺少 mode 行: {mode}")

    default_mode = read_default_mode()
    if default_mode != "legacy":
        return fail(f"default mode 必须 legacy，当前 {default_mode}")

    if row_by_mode["legacy"].get("mode_allowed") != "true":
        return fail("legacy mode_allowed 必须 true")
    if row_by_mode["content_engine_enabled"].get("mode_allowed") != "false":
        return fail("content_engine_enabled 必须保持禁用")

    for mode, row in row_by_mode.items():
        if row.get("selected_reward_source") != "legacy":
            return fail(f"{mode}: selected_reward_source 必须 legacy")
        if row.get("selected_reward_unchanged") != "true":
            return fail(f"{mode}: selected_reward_unchanged 必须 true")
        if row.get("runtime_loader_config") != "disabled":
            return fail(f"{mode}: runtime_loader_config 必须 disabled")
        if row.get("preview_reward_count") != "45":
            return fail(f"{mode}: preview_reward_count 必须 45")

    if FORBIDDEN_RUNTIME_REWARD.exists():
        return fail("不应存在 data/runtime/content_engine/battle_rewards.json")

    if row_by_mode["content_engine_candidate"].get("candidate_reward_available") != "true":
        return fail("content_engine_candidate 需可读取 candidate")

    runtime_cfg = json.loads(RUNTIME_CONFIG.read_text(encoding="utf-8"))
    if bool(runtime_cfg.get("content_engine_runtime_enabled", False)):
        return fail("runtime_loader_config 不得启用")

    forbidden_changed = changed_forbidden_files()
    if forbidden_changed:
        return fail("检测到禁止修改文件: " + ", ".join(forbidden_changed))

    print("PASS: report 存在且覆盖四种 mode")
    print("PASS: default mode=legacy")
    print("PASS: content_engine_enabled 保持禁用")
    print("PASS: selected_reward 仍 legacy 且未改变")
    print("PASS: runtime_loader_config=disabled")
    print("PASS: preview_reward_count=45")
    print("PASS: 未写 data/runtime/content_engine/battle_rewards.json")
    print("PASS: 未检测到 story/runtime/scenes/battle core 禁止修改")
    print("RESULT: PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
