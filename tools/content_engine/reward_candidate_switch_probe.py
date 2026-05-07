#!/usr/bin/env python3
"""v1.4 reward candidate switch skeleton probe（只读）。"""

from __future__ import annotations

import csv
import json
import tempfile
from pathlib import Path

PREVIEW_JSON = Path("data/runtime_preview/content_engine/battle_rewards.preview.json")
PREVIEW_MANIFEST = Path("data/runtime_preview/content_engine/battle_rewards.preview_manifest.json")
RUNTIME_CONFIG = Path("data/runtime/content_engine/runtime_loader_config.json")
MODE_CONFIG = Path("data/design/reward_source_mode_config.tsv")
OUT_REPORT = Path("data/design/generated_reward_candidate_switch_probe_report.tsv")
FORBIDDEN_RUNTIME_REWARD = Path("data/runtime/content_engine/battle_rewards.json")

FIELDS = [
    "mode",
    "mode_allowed",
    "preview_package_exists",
    "preview_reward_count",
    "selected_reward_source",
    "candidate_reward_available",
    "selected_reward_unchanged",
    "runtime_loader_config",
    "runtime_write_detected",
    "notes",
]

ALLOWED_MODES = ["legacy", "shadow_compare", "content_engine_candidate", "content_engine_enabled"]


def read_mode_from_config() -> str:
    if not MODE_CONFIG.exists():
        return "legacy"
    with MODE_CONFIG.open("r", encoding="utf-8", newline="") as f:
        rows = list(csv.DictReader(f, delimiter="\t"))
    for row in rows:
        if row.get("config_key", "").strip() == "reward_source_mode":
            mode = row.get("config_value", "").strip()
            return mode or "legacy"
    return "legacy"


def write_tsv_atomic(path: Path, rows: list[dict[str, str]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile("w", encoding="utf-8", newline="", delete=False, dir=path.parent, prefix=path.name, suffix=".tmp") as tmp:
        writer = csv.DictWriter(tmp, fieldnames=FIELDS, delimiter="\t", lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)
        tmp_path = Path(tmp.name)
    tmp_path.replace(path)


def main() -> int:
    mode = read_mode_from_config()
    if mode not in ALLOWED_MODES:
        raise ValueError(f"invalid reward_source_mode: {mode}")

    preview_exists = PREVIEW_JSON.exists() and PREVIEW_MANIFEST.exists()
    preview_count = 0
    if preview_exists:
        preview = json.loads(PREVIEW_JSON.read_text(encoding="utf-8"))
        rewards = preview.get("rewards", []) if isinstance(preview, dict) else []
        if not isinstance(rewards, list):
            raise ValueError("preview rewards must be list")
        preview_count = len(rewards)

    runtime_mode = "unknown"
    if RUNTIME_CONFIG.exists():
        cfg = json.loads(RUNTIME_CONFIG.read_text(encoding="utf-8"))
        enabled = bool(cfg.get("content_engine_runtime_enabled", False))
        integration_mode = str(cfg.get("integration_mode", "disabled"))
        runtime_mode = integration_mode if enabled else "disabled"

    runtime_write_detected = FORBIDDEN_RUNTIME_REWARD.exists()

    rows: list[dict[str, str]] = []
    for item in ALLOWED_MODES:
        mode_allowed = item != "content_engine_enabled"
        if item == "legacy":
            mode_allowed = mode == "legacy"

        rows.append(
            {
                "mode": item,
                "mode_allowed": "true" if mode_allowed else "false",
                "preview_package_exists": "true" if preview_exists else "false",
                "preview_reward_count": str(preview_count),
                "selected_reward_source": "legacy",
                "candidate_reward_available": "true" if preview_count > 0 else "false",
                "selected_reward_unchanged": "true",
                "runtime_loader_config": runtime_mode,
                "runtime_write_detected": "true" if runtime_write_detected else "false",
                "notes": (
                    "默认 legacy；shadow_compare/content_engine_candidate 仅候选或对比；"
                    "content_engine_enabled 禁止启用；不写入 selected_reward。"
                ),
            }
        )

    write_tsv_atomic(OUT_REPORT, rows)
    print(f"Wrote {OUT_REPORT.as_posix()} rows={len(rows)} default_mode={mode}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
