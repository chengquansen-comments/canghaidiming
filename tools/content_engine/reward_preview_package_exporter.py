#!/usr/bin/env python3
"""v1.2b reward preview package exporter（只读 preview 包）。"""

from __future__ import annotations

import csv
import json
from datetime import datetime, timezone
from pathlib import Path

APPROVAL_PATH = Path("data/design/generated_reward_preview_approval.tsv")
REWARD_PLAN_PATH = Path("data/design/generated_battle_reward_plan.tsv")
OUT_JSON = Path("data/runtime_preview/content_engine/battle_rewards.preview.json")
OUT_MANIFEST = Path("data/runtime_preview/content_engine/battle_rewards.preview_manifest.json")


def read_tsv(path: Path) -> list[dict[str, str]]:
    with path.open("r", encoding="utf-8", newline="") as f:
        return list(csv.DictReader(f, delimiter="\t"))


def to_int(value: str) -> int:
    try:
        return int(value)
    except Exception:
        return 0


def to_bool(value: str) -> bool:
    return str(value).strip().lower() == "true"


def main() -> int:
    if not APPROVAL_PATH.exists() or not REWARD_PLAN_PATH.exists():
        raise FileNotFoundError("missing required input tsv")

    approval_rows = read_tsv(APPROVAL_PATH)
    if len(approval_rows) != 1:
        raise ValueError("generated_reward_preview_approval.tsv must contain exactly one row")

    approval = approval_rows[0]
    if approval.get("artifact_id") != "generated_battle_reward_plan":
        raise ValueError("only generated_battle_reward_plan is allowed")
    if approval.get("preview_allowed") != "true":
        raise ValueError("preview_allowed must be true")
    if approval.get("runtime_allowed") != "false":
        raise ValueError("runtime_allowed must be false")
    if approval.get("approved_for_runtime") != "false":
        raise ValueError("approved_for_runtime must be false")

    rows = read_tsv(REWARD_PLAN_PATH)

    rewards = []
    for r in rows:
        rewards.append(
            {
                "reward_plan_id": r.get("reward_plan_id", ""),
                "battle_slot_id": r.get("battle_slot_id", ""),
                "deck_id": r.get("deck_id", ""),
                "battle_type": r.get("battle_type", ""),
                "reward_profile": r.get("reward_profile", ""),
                "martial_xp_reward": to_int(r.get("martial_xp_reward", "0")),
                "weapon_xp_reward": to_int(r.get("weapon_xp_reward", "0")),
                "military_merit_reward": to_int(r.get("military_merit_reward", "0")),
                "clean_reputation_reward": to_int(r.get("clean_reputation_reward", "0")),
                "old_case_progress_reward": to_int(r.get("old_case_progress_reward", "0")),
                "lightness_reward_type": r.get("lightness_reward_type", ""),
                "lightness_cap_unlock": r.get("lightness_cap_unlock", ""),
                "card_reward_pool": r.get("card_reward_pool", ""),
                "resource_reward_type": r.get("resource_reward_type", ""),
                "resource_reward_amount": to_int(r.get("resource_reward_amount", "0")),
                "can_trigger_realm_10": to_bool(r.get("can_trigger_realm_10", "false")),
                "can_trigger_lightness_breakthrough": to_bool(r.get("can_trigger_lightness_breakthrough", "false")),
                "can_trigger_wuzhuangyuan_route": to_bool(r.get("can_trigger_wuzhuangyuan_route", "false")),
                "ending_route": r.get("ending_route", ""),
            }
        )

    preview_package = {
        "package_type": "reward_preview",
        "runtime_ready": False,
        "source_artifact": "generated_battle_reward_plan",
        "selected_reward_policy": "legacy",
        "rewards": rewards,
    }

    manifest = {
        "package_type": "reward_preview",
        "generated_at": datetime.now(timezone.utc).isoformat(timespec="seconds"),
        "source_artifact": "generated_battle_reward_plan",
        "source_row_count": len(rows),
        "exported_reward_count": len(rewards),
        "runtime_ready": False,
        "output_path": OUT_JSON.as_posix(),
        "selected_reward_policy": "legacy",
        "runtime_allowed": False,
        "blockers": ["runtime_loader_disabled", "preview_only", "not_runtime_export"],
    }

    OUT_JSON.parent.mkdir(parents=True, exist_ok=True)
    OUT_JSON.write_text(json.dumps(preview_package, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    OUT_MANIFEST.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    print(f"Wrote {OUT_JSON.as_posix()} and {OUT_MANIFEST.as_posix()} rewards={len(rewards)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
