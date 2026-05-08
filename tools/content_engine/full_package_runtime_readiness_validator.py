#!/usr/bin/env python3
"""v2.0 full package runtime readiness validator。"""

from __future__ import annotations

import csv
import json
import subprocess
from pathlib import Path

TSV = Path("data/design/generated_full_package_runtime_readiness.tsv")
MD = Path("data/design/generated_full_package_runtime_blockers.md")
RUNTIME_CFG = Path("data/runtime/content_engine/runtime_loader_config.json")
SHADOW_FREEZE = Path("data/design/generated_battle_reward_shadow_freeze_report.tsv")
FORBIDDEN_RUNTIME = Path("data/runtime/content_engine/battle_rewards.json")

EXPECTED_COUNTS = {
    "reward": 45,
    "battle_slot": 16,
    "enemy_deck": 39,
    "card_pool": 72,
    "operation_node": 10,
    "narrative": 28,
    "route_gate": 9,
}
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
    if not TSV.exists() or TSV.stat().st_size == 0:
        return fail("readiness TSV 不存在或为空")
    if not MD.exists() or MD.stat().st_size == 0:
        return fail("blockers MD 不存在或为空")

    rows = read_tsv(TSV)
    domains = {r.get("domain", "") for r in rows}
    if domains != set(EXPECTED_COUNTS.keys()):
        return fail("TSV 未覆盖 7 个 domain")

    idx = {r["domain"]: r for r in rows}
    for d, c in EXPECTED_COUNTS.items():
        if idx[d].get("preview_count") != str(c):
            return fail(f"{d} preview_count 错误 expected={c} actual={idx[d].get('preview_count')}")

    if all(r.get("formal_enable_ready") == "true" for r in rows):
        return fail("formal_enable_ready 不得全 true")

    for r in rows:
        if r.get("runtime_adapter_exists") == "false" and r.get("blocker_level") == "none":
            return fail(f"{r.get('domain')}: 缺 adapter 但 blocker_level=none")
        if not r.get("blockers", "").strip():
            return fail(f"{r.get('domain')}: blockers 不能为空")

    if FORBIDDEN_RUNTIME.exists():
        return fail("不应存在 data/runtime/content_engine/battle_rewards.json")

    cfg = json.loads(RUNTIME_CFG.read_text(encoding="utf-8"))
    if bool(cfg.get("content_engine_runtime_enabled", False)):
        return fail("content_engine_enabled 必须 false")

    if SHADOW_FREEZE.exists() and SHADOW_FREEZE.stat().st_size > 0:
        freeze = {r.get("check_id", ""): r for r in read_tsv(SHADOW_FREEZE)}
        if freeze.get("selected_reward_source", {}).get("actual") != "legacy":
            return fail("selected_reward 必须 legacy")

    bad = changed_forbidden_files()
    if bad:
        return fail("检测到禁止修改文件: " + ", ".join(bad))

    print("PASS: readiness TSV 存在")
    print("PASS: blockers MD 存在")
    print("PASS: 覆盖 7 个 domain + preview_count 正确")
    print("PASS: formal_enable_ready 未全 true")
    print("PASS: 缺 adapter 的 domain 均有 blocker")
    print("PASS: 未写 data/runtime 且未改 story/scenes/battle core")
    print("PASS: selected_reward=legacy, content_engine_enabled=false")
    print("RESULT: PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
