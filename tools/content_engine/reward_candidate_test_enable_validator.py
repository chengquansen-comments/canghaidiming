#!/usr/bin/env python3
"""v1.5 controlled reward candidate test enable validator。"""

from __future__ import annotations

import csv
import json
import subprocess
from pathlib import Path

REPORT = Path("data/design/generated_reward_candidate_test_enable_report.tsv")
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
        return fail("test enable report 不存在或为空")

    rows = read_tsv(REPORT)
    if len(rows) != 1:
        return fail(f"report 必须只包含 1 个测试 battle_slot，实际 {len(rows)}")
    row = rows[0]

    required_pairs = {
        "candidate_reward_found": "true",
        "candidate_reward_source": "content_engine_candidate",
        "formal_selected_reward_source": "legacy",
        "selected_reward_unchanged": "true",
        "runtime_loader_config": "disabled",
        "test_mode": "content_engine_candidate",
        "test_result": "PASS",
    }
    for k, expected in required_pairs.items():
        if row.get(k) != expected:
            return fail(f"{k} 期望 {expected}，实际 {row.get(k)}")

    runtime_cfg = json.loads(RUNTIME_CONFIG.read_text(encoding="utf-8"))
    if bool(runtime_cfg.get("content_engine_runtime_enabled", False)):
        return fail("runtime_loader_config 不得启用")

    if FORBIDDEN_RUNTIME_REWARD.exists():
        return fail("不应存在 data/runtime/content_engine/battle_rewards.json")

    forbidden_changed = changed_forbidden_files()
    if forbidden_changed:
        return fail("检测到禁止修改文件: " + ", ".join(forbidden_changed))

    print("PASS: report 存在且仅 1 个测试 battle_slot")
    print("PASS: candidate_reward_found=true")
    print("PASS: candidate_reward_source=content_engine_candidate")
    print("PASS: formal_selected_reward_source=legacy")
    print("PASS: selected_reward_unchanged=true")
    print("PASS: runtime_loader_config=disabled")
    print("PASS: content_engine_enabled 未启用")
    print("PASS: 未写 data/runtime/content_engine/battle_rewards.json")
    print("PASS: 未检测到 story/runtime/scenes/battle core 禁止修改")
    print("RESULT: PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
