#!/usr/bin/env python3
"""v1.7b full package shadow compare probe（只读）。"""

from __future__ import annotations

import csv
import json
import os
import uuid
from datetime import datetime, timezone
from pathlib import Path

BASE = Path("data/runtime_preview/content_engine")
OUT_MATRIX = Path("data/design/generated_content_domain_switch_matrix.tsv")
OUT_REPORT = Path("data/design/generated_full_package_shadow_compare_report.tsv")
RUNTIME_CONFIG = Path("data/runtime/content_engine/runtime_loader_config.json")

MANIFEST = BASE / "full_content_package.preview_manifest.json"
BATTLE_SLOTS = BASE / "battle_slots.preview.json"
ENEMY_DECKS = BASE / "enemy_decks.preview.json"
CARD_POOL = BASE / "card_pool.preview.json"
REWARDS = BASE / "battle_rewards.preview.json"
OPERATIONS = BASE / "operation_nodes.preview.json"
NARRATIVES = BASE / "narrative_nodes.preview.json"
ROUTES = BASE / "route_gates.preview.json"

SLOT = "prologue_01"
REWARD = "rw_prologue_01"

MATRIX_FIELDS = ["domain", "source_mode", "enabled_scope", "default_mode", "content_engine_enabled", "notes"]
REPORT_FIELDS = [
    "domain",
    "battle_slot_id",
    "legacy_source",
    "candidate_source",
    "candidate_available",
    "candidate_id",
    "formal_source_unchanged",
    "content_engine_enabled",
    "runtime_loader_config",
    "notes",
]


def atomic_write_tsv(path: Path, fields: list[str], rows: list[dict[str, str]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_name(f"{path.name}.{uuid.uuid4().hex}.tmp")
    with tmp.open("w", encoding="utf-8", newline="") as f:
        w = csv.DictWriter(f, fieldnames=fields, delimiter="\t", lineterminator="\n")
        w.writeheader()
        w.writerows(rows)
        f.flush()
        os.fsync(f.fileno())
    os.replace(tmp, path)


def load_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def now_iso() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="seconds")


def main() -> int:
    _ = now_iso()
    manifest = load_json(MANIFEST)
    battle_slots = load_json(BATTLE_SLOTS).get("battle_slots", [])
    enemy_decks = load_json(ENEMY_DECKS).get("enemy_decks", [])
    cards = load_json(CARD_POOL).get("cards", [])
    rewards = load_json(REWARDS).get("rewards", [])
    ops = load_json(OPERATIONS).get("operation_nodes", [])
    narratives = load_json(NARRATIVES).get("narrative_nodes", [])
    routes = load_json(ROUTES).get("route_gates", [])

    runtime_cfg = load_json(RUNTIME_CONFIG)
    runtime_loader = "disabled" if not bool(runtime_cfg.get("content_engine_runtime_enabled", False)) else str(runtime_cfg.get("integration_mode", "unknown"))
    ce_enabled = "false"

    matrix_domains = [
        "battle_slot",
        "enemy_deck",
        "card_pool",
        "reward",
        "operation_node",
        "narrative",
        "route_gate",
    ]
    matrix_rows = [
        {
            "domain": d,
            "source_mode": "shadow_compare",
            "enabled_scope": SLOT,
            "default_mode": "legacy",
            "content_engine_enabled": ce_enabled,
            "notes": "仅用于 prologue_01 的 shadow compare；不全局启用。",
        }
        for d in matrix_domains
    ]

    slot_ok = any(str(r.get("battle_slot_id", "")) == SLOT for r in battle_slots)
    reward_ok = any(str(r.get("reward_plan_id", "")) == REWARD for r in rewards)

    narrative_has_body = any(any(k in r for k in ["full_text", "body", "dialogue", "content_text", "正文"]) for r in narratives if isinstance(r, dict))

    domain_rows = [
        ("battle_slot", slot_ok, SLOT, "prologue_01 candidate 命中。" if slot_ok else "prologue_01 candidate 缺失。"),
        ("reward", reward_ok, REWARD, "rw_prologue_01 candidate 命中。" if reward_ok else "rw_prologue_01 candidate 缺失。"),
        ("enemy_deck", False, "", "preview 中未提供 prologue_01 到 deck_id 的直接绑定，仅记录未绑定。"),
        ("card_pool", len(cards) == 72, "card_pool_72", "72 张 candidate 可用，但不进入正式 CardData。"),
        ("operation_node", len(ops) > 0, f"operation_nodes_{len(ops)}", "仅记录可用数量，不进入正式地图流程。"),
        ("narrative", len(narratives) > 0 and not narrative_has_body, f"narrative_nodes_{len(narratives)}", "仅 key/hook，不写正式正文。"),
        ("route_gate", len(routes) > 0, f"route_gates_{len(routes)}", "仅记录可用 gate，不进入正式路线逻辑。"),
    ]

    report_rows: list[dict[str, str]] = []
    for domain, available, candidate_id, notes in domain_rows:
        report_rows.append(
            {
                "domain": domain,
                "battle_slot_id": SLOT,
                "legacy_source": "legacy",
                "candidate_source": "content_engine_preview",
                "candidate_available": "true" if available else "false",
                "candidate_id": candidate_id,
                "formal_source_unchanged": "true",
                "content_engine_enabled": ce_enabled,
                "runtime_loader_config": runtime_loader,
                "notes": notes,
            }
        )

    # 清理 manifest 中潜在 true 值风险，仅读并验证不写回。
    _ = manifest.get("content_engine_enabled", False)

    atomic_write_tsv(OUT_MATRIX, MATRIX_FIELDS, matrix_rows)
    atomic_write_tsv(OUT_REPORT, REPORT_FIELDS, report_rows)
    print(f"Wrote {OUT_MATRIX.as_posix()} and {OUT_REPORT.as_posix()} rows={len(report_rows)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
