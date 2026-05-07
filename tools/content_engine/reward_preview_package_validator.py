#!/usr/bin/env python3
"""v1.2b reward preview package validator。"""

from __future__ import annotations

import csv
import json
from pathlib import Path

PREVIEW_JSON = Path("data/runtime_preview/content_engine/battle_rewards.preview.json")
PREVIEW_MANIFEST = Path("data/runtime_preview/content_engine/battle_rewards.preview_manifest.json")
RUNTIME_FORMAL_JSON = Path("data/runtime/content_engine/battle_rewards.json")
APPROVAL_PATH = Path("data/design/generated_reward_preview_approval.tsv")
REWARD_PLAN_PATH = Path("data/design/generated_battle_reward_plan.tsv")


def fail(msg: str) -> int:
    print(f"FAIL: {msg}")
    return 1


def read_tsv(path: Path) -> list[dict[str, str]]:
    with path.open("r", encoding="utf-8", newline="") as f:
        return list(csv.DictReader(f, delimiter="\t"))


def main() -> int:
    if not PREVIEW_JSON.exists() or not PREVIEW_MANIFEST.exists():
        return fail("preview json/manifest missing")
    if RUNTIME_FORMAL_JSON.exists():
        return fail("forbidden runtime file exists: data/runtime/content_engine/battle_rewards.json")

    pkg = json.loads(PREVIEW_JSON.read_text(encoding="utf-8"))
    m = json.loads(PREVIEW_MANIFEST.read_text(encoding="utf-8"))

    if pkg.get("runtime_ready") is not False:
        return fail("runtime_ready must be false in preview json")
    if m.get("runtime_ready") is not False:
        return fail("runtime_ready must be false in preview manifest")
    if pkg.get("selected_reward_policy") != "legacy" or m.get("selected_reward_policy") != "legacy":
        return fail("selected_reward_policy must be legacy")
    if "content_engine_enabled" in pkg or "content_engine_enabled" in m:
        return fail("content_engine_enabled must not appear")

    rewards = pkg.get("rewards", [])
    if not isinstance(rewards, list):
        return fail("rewards must be list")

    rows = read_tsv(REWARD_PLAN_PATH)
    if len(rewards) != len(rows):
        return fail(f"exported_reward_count mismatch: rewards={len(rewards)} rows={len(rows)}")
    if int(m.get("exported_reward_count", -1)) != len(rows):
        return fail("manifest exported_reward_count mismatch")

    disallowed_top_keys = {"enemy", "card", "deck", "narrative", "route"}
    for key in pkg.keys():
        if key in disallowed_top_keys:
            return fail(f"preview package contains disallowed key: {key}")

    approval_rows = read_tsv(APPROVAL_PATH)
    if len(approval_rows) != 1:
        return fail("approval row count invalid")
    ar = approval_rows[0]
    if ar.get("runtime_allowed") != "false":
        return fail("runtime_allowed must remain false")

    print("PASS: preview json exists")
    print("PASS: preview manifest exists")
    print("PASS: runtime_ready=false")
    print("PASS: selected_reward_policy=legacy")
    print("PASS: exported_reward_count matches source")
    print("PASS: no runtime formal battle_rewards.json")
    print("PASS: preview package only includes reward payload")
    print("PASS: runtime_allowed=false")
    print("RESULT: PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
