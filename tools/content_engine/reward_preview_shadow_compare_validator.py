#!/usr/bin/env python3
"""v1.3 reward preview shadow compare validator。"""

from __future__ import annotations

import csv
import json
from pathlib import Path

READONLY_REPORT = Path("data/design/generated_reward_preview_readonly_probe_report.tsv")
SHADOW_REPORT = Path("data/design/generated_reward_preview_shadow_compare_report.tsv")
PREVIEW_JSON = Path("data/runtime_preview/content_engine/battle_rewards.preview.json")
PREVIEW_MANIFEST = Path("data/runtime_preview/content_engine/battle_rewards.preview_manifest.json")
FORMAL_RUNTIME_REWARD = Path("data/runtime/content_engine/battle_rewards.json")


def fail(msg: str) -> int:
    print(f"FAIL: {msg}")
    return 1


def read_tsv(path: Path) -> list[dict[str, str]]:
    with path.open("r", encoding="utf-8", newline="") as f:
        return list(csv.DictReader(f, delimiter="\t"))


def main() -> int:
    if not READONLY_REPORT.exists() or READONLY_REPORT.stat().st_size == 0:
        return fail("readonly probe report missing/empty")
    if not SHADOW_REPORT.exists() or SHADOW_REPORT.stat().st_size == 0:
        return fail("shadow compare report missing/empty")
    if not PREVIEW_JSON.exists() or not PREVIEW_MANIFEST.exists():
        return fail("preview package json/manifest missing")

    readonly_rows = read_tsv(READONLY_REPORT)
    shadow_rows = read_tsv(SHADOW_REPORT)
    pkg = json.loads(PREVIEW_JSON.read_text(encoding="utf-8"))
    manifest = json.loads(PREVIEW_MANIFEST.read_text(encoding="utf-8"))
    rewards = pkg.get("rewards", []) if isinstance(pkg, dict) else []

    if not isinstance(rewards, list) or len(rewards) != 45:
        return fail(f"preview reward count must be 45, got {len(rewards) if isinstance(rewards, list) else 'non-list'}")
    if len(shadow_rows) != 45:
        return fail(f"shadow compare row count must be 45, got {len(shadow_rows)}")
    if any(r.get("selected_reward_unchanged") != "true" for r in shadow_rows):
        return fail("selected_reward_unchanged must be true for all rows")

    if "content_engine_enabled" in pkg or "content_engine_enabled" in manifest:
        return fail("content_engine_enabled must not appear in preview package")
    if manifest.get("runtime_ready") is not False or pkg.get("runtime_ready") is not False:
        return fail("runtime_ready must remain false")
    if FORMAL_RUNTIME_REWARD.exists():
        return fail("forbidden formal runtime reward file exists: data/runtime/content_engine/battle_rewards.json")

    idx = {r.get("check_id", ""): r for r in readonly_rows}
    if idx.get("selected_reward_source", {}).get("actual") != "legacy":
        return fail("selected_reward must remain legacy")
    if idx.get("runtime_loader_config_disabled", {}).get("actual") != "true":
        return fail("runtime_loader_config must remain disabled")

    print("PASS: readonly probe report exists")
    print("PASS: shadow compare report exists")
    print("PASS: preview reward count is 45")
    print("PASS: all selected_reward_unchanged=true")
    print("PASS: no content_engine_enabled")
    print("PASS: runtime_ready remains false")
    print("PASS: no formal runtime battle_rewards.json")
    print("PASS: selected_reward remains legacy")
    print("PASS: runtime_loader_config remains disabled")
    print("RESULT: PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
