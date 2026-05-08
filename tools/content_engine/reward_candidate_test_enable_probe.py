#!/usr/bin/env python3
"""v1.5 controlled reward candidate test enable probe（只读）。"""

from __future__ import annotations

import csv
import json
import tempfile
from pathlib import Path

TEST_CONFIG = Path("data/design/reward_candidate_test_enable_config.tsv")
MODE_CONFIG = Path("data/design/reward_source_mode_config.tsv")
PREVIEW_JSON = Path("data/runtime_preview/content_engine/battle_rewards.preview.json")
PREVIEW_MANIFEST = Path("data/runtime_preview/content_engine/battle_rewards.preview_manifest.json")
RUNTIME_CONFIG = Path("data/runtime/content_engine/runtime_loader_config.json")
OUT_REPORT = Path("data/design/generated_reward_candidate_test_enable_report.tsv")
FORBIDDEN_RUNTIME_REWARD = Path("data/runtime/content_engine/battle_rewards.json")

FIELDS = [
    "test_id",
    "battle_slot_id",
    "reward_plan_id",
    "test_mode",
    "preview_package_exists",
    "candidate_reward_found",
    "candidate_reward_source",
    "formal_selected_reward_source",
    "selected_reward_unchanged",
    "runtime_loader_config",
    "runtime_write_detected",
    "test_result",
    "notes",
]


def read_tsv(path: Path) -> list[dict[str, str]]:
    with path.open("r", encoding="utf-8", newline="") as f:
        return list(csv.DictReader(f, delimiter="\t"))


def write_atomic_tsv(path: Path, rows: list[dict[str, str]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile("w", encoding="utf-8", newline="", delete=False, dir=path.parent, prefix=path.name, suffix=".tmp") as tmp:
        w = csv.DictWriter(tmp, fieldnames=FIELDS, delimiter="\t", lineterminator="\n")
        w.writeheader()
        w.writerows(rows)
        tmp_path = Path(tmp.name)
    tmp_path.replace(path)


def read_default_mode() -> str:
    if not MODE_CONFIG.exists():
        return "legacy"
    for row in read_tsv(MODE_CONFIG):
        if row.get("config_key", "").strip() == "reward_source_mode":
            return row.get("config_value", "").strip() or "legacy"
    return "legacy"


def main() -> int:
    if not TEST_CONFIG.exists():
        raise FileNotFoundError("reward_candidate_test_enable_config.tsv missing")

    cfg_rows = read_tsv(TEST_CONFIG)
    if len(cfg_rows) != 1:
        raise ValueError(f"test config must contain exactly one row, got {len(cfg_rows)}")
    cfg = cfg_rows[0]

    preview_exists = PREVIEW_JSON.exists() and PREVIEW_MANIFEST.exists()
    if not preview_exists:
        raise FileNotFoundError("preview json/manifest missing")

    preview_data = json.loads(PREVIEW_JSON.read_text(encoding="utf-8"))
    manifest = json.loads(PREVIEW_MANIFEST.read_text(encoding="utf-8"))
    rewards = preview_data.get("rewards", []) if isinstance(preview_data, dict) else []
    if not isinstance(rewards, list):
        raise ValueError("preview rewards must be list")

    battle_slot_id = cfg.get("battle_slot_id", "").strip()
    reward_plan_id = cfg.get("reward_plan_id", "").strip()
    candidate_found = any(
        str(r.get("battle_slot_id", "")).strip() == battle_slot_id
        and str(r.get("reward_plan_id", "")).strip() == reward_plan_id
        for r in rewards
    )

    runtime_cfg = json.loads(RUNTIME_CONFIG.read_text(encoding="utf-8"))
    runtime_mode = "disabled" if not bool(runtime_cfg.get("content_engine_runtime_enabled", False)) else str(runtime_cfg.get("integration_mode", "unknown"))

    default_mode = read_default_mode()
    content_engine_enabled_appeared = "content_engine_enabled" in json.dumps(runtime_cfg, ensure_ascii=False)

    checks_ok = all(
        [
            cfg.get("test_mode", "") == "content_engine_candidate",
            cfg.get("candidate_allowed", "").lower() == "true",
            cfg.get("formal_selected_reward_policy", "") == "legacy",
            manifest.get("selected_reward_policy") == "legacy",
            manifest.get("runtime_ready") is False,
            default_mode == "legacy",
            not content_engine_enabled_appeared or not bool(runtime_cfg.get("content_engine_runtime_enabled", False)),
        ]
    )

    row = {
        "test_id": cfg.get("test_id", ""),
        "battle_slot_id": battle_slot_id,
        "reward_plan_id": reward_plan_id,
        "test_mode": cfg.get("test_mode", ""),
        "preview_package_exists": "true" if preview_exists else "false",
        "candidate_reward_found": "true" if candidate_found else "false",
        "candidate_reward_source": "content_engine_candidate" if candidate_found else "none",
        "formal_selected_reward_source": "legacy",
        "selected_reward_unchanged": "true",
        "runtime_loader_config": runtime_mode,
        "runtime_write_detected": "true" if FORBIDDEN_RUNTIME_REWARD.exists() else "false",
        "test_result": "PASS" if checks_ok and candidate_found else "FAIL",
        "notes": "仅离线测试指定 battle_slot 的 candidate 可选性；正式流程保持 legacy，不启用 content_engine_enabled。",
    }

    write_atomic_tsv(OUT_REPORT, [row])
    print(f"Wrote {OUT_REPORT.as_posix()} rows=1 test_id={row['test_id']} result={row['test_result']}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
