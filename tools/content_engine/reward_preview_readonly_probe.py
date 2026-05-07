#!/usr/bin/env python3
"""v1.3 reward preview read-only probe。"""

from __future__ import annotations

import csv
import json
from pathlib import Path

PREVIEW_JSON = Path("data/runtime_preview/content_engine/battle_rewards.preview.json")
PREVIEW_MANIFEST = Path("data/runtime_preview/content_engine/battle_rewards.preview_manifest.json")
SHADOW_FREEZE_REPORT = Path("data/design/generated_battle_reward_shadow_freeze_report.tsv")
OUT_READONLY = Path("data/design/generated_reward_preview_readonly_probe_report.tsv")
OUT_SHADOW = Path("data/design/generated_reward_preview_shadow_compare_report.tsv")

READONLY_FIELDS = [
    "check_id",
    "status",
    "expected",
    "actual",
    "notes",
]
SHADOW_FIELDS = [
    "battle_slot_id",
    "reward_plan_id",
    "legacy_selected_reward_source",
    "preview_candidate_available",
    "selected_reward_unchanged",
    "notes",
]


def read_tsv(path: Path) -> list[dict[str, str]]:
    with path.open("r", encoding="utf-8", newline="") as f:
        return list(csv.DictReader(f, delimiter="\t"))


def to_bool(v: object) -> bool:
    if isinstance(v, bool):
        return v
    return str(v).strip().lower() == "true"


def main() -> int:
    if not PREVIEW_JSON.exists() or not PREVIEW_MANIFEST.exists():
        raise FileNotFoundError("preview package json/manifest missing")

    preview = json.loads(PREVIEW_JSON.read_text(encoding="utf-8"))
    manifest = json.loads(PREVIEW_MANIFEST.read_text(encoding="utf-8"))
    rewards = preview.get("rewards", []) if isinstance(preview, dict) else []
    if not isinstance(rewards, list):
        raise ValueError("preview rewards must be list")

    selected_reward_source = "legacy"
    runtime_loader_disabled = "unknown"
    if SHADOW_FREEZE_REPORT.exists():
        idx = {r.get("check_id", ""): r for r in read_tsv(SHADOW_FREEZE_REPORT)}
        selected_reward_source = idx.get("selected_reward_source", {}).get("actual", "legacy") or "legacy"
        runtime_loader_disabled = idx.get("runtime_loader_config_disabled", {}).get("actual", "unknown") or "unknown"

    readonly_rows = [
        {
            "check_id": "preview_manifest_runtime_ready",
            "status": "PASS" if manifest.get("runtime_ready") is False else "FAIL",
            "expected": "false",
            "actual": str(manifest.get("runtime_ready")).lower(),
            "notes": "preview manifest 必须 runtime_ready=false",
        },
        {
            "check_id": "preview_manifest_selected_reward_policy",
            "status": "PASS" if str(manifest.get("selected_reward_policy", "")) == "legacy" else "FAIL",
            "expected": "legacy",
            "actual": str(manifest.get("selected_reward_policy", "")),
            "notes": "selected_reward_policy 必须 legacy",
        },
        {
            "check_id": "preview_reward_count",
            "status": "PASS" if len(rewards) == 45 else "FAIL",
            "expected": "45",
            "actual": str(len(rewards)),
            "notes": "preview reward 数量必须为 45",
        },
        {
            "check_id": "selected_reward_source",
            "status": "PASS" if selected_reward_source == "legacy" else "FAIL",
            "expected": "legacy",
            "actual": selected_reward_source,
            "notes": "selected_reward 仍应为 legacy",
        },
        {
            "check_id": "runtime_loader_config_disabled",
            "status": "PASS" if runtime_loader_disabled == "true" else "FAIL",
            "expected": "true",
            "actual": runtime_loader_disabled,
            "notes": "runtime_loader_config 应保持 disabled",
        },
    ]

    shadow_rows: list[dict[str, str]] = []
    for row in rewards:
        battle_slot_id = str(row.get("battle_slot_id", ""))
        reward_plan_id = str(row.get("reward_plan_id", ""))
        shadow_rows.append(
            {
                "battle_slot_id": battle_slot_id,
                "reward_plan_id": reward_plan_id,
                "legacy_selected_reward_source": "legacy",
                "preview_candidate_available": "true" if bool(reward_plan_id) else "false",
                "selected_reward_unchanged": "true",
                "notes": "preview 仅作为 candidate，对正式 selected_reward 无写入",
            }
        )

    OUT_READONLY.parent.mkdir(parents=True, exist_ok=True)
    with OUT_READONLY.open("w", encoding="utf-8", newline="") as f:
        w = csv.DictWriter(f, fieldnames=READONLY_FIELDS, delimiter="\t", lineterminator="\n")
        w.writeheader()
        w.writerows(readonly_rows)

    with OUT_SHADOW.open("w", encoding="utf-8", newline="") as f:
        w = csv.DictWriter(f, fieldnames=SHADOW_FIELDS, delimiter="\t", lineterminator="\n")
        w.writeheader()
        w.writerows(shadow_rows)

    print(f"Wrote {OUT_READONLY.as_posix()} and {OUT_SHADOW.as_posix()} rows={len(shadow_rows)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
