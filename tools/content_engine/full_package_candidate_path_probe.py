#!/usr/bin/env python3
"""v1.8 whitelist full package candidate path probe（只读）。"""

from __future__ import annotations

import csv
import json
import os
import uuid
from pathlib import Path

BASE = Path("data/runtime_preview/content_engine")
OUT = Path("data/design/generated_full_package_candidate_path_report.tsv")
RUNTIME_CONFIG = Path("data/runtime/content_engine/runtime_loader_config.json")

BATTLE_SLOTS = BASE / "battle_slots.preview.json"
ENEMY_DECKS = BASE / "enemy_decks.preview.json"
CARD_POOL = BASE / "card_pool.preview.json"
REWARDS = BASE / "battle_rewards.preview.json"
OPERATIONS = BASE / "operation_nodes.preview.json"
NARRATIVES = BASE / "narrative_nodes.preview.json"
ROUTES = BASE / "route_gates.preview.json"

SLOT = "prologue_01"
REWARD_ID = "rw_prologue_01"

FIELDS = [
    "battle_slot_id",
    "domain",
    "candidate_available",
    "candidate_id",
    "candidate_count",
    "candidate_source",
    "formal_source",
    "formal_source_unchanged",
    "content_engine_enabled",
    "runtime_loader_config",
    "notes",
]


def load_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def atomic_write(path: Path, rows: list[dict[str, str]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_name(f"{path.name}.{uuid.uuid4().hex}.tmp")
    with tmp.open("w", encoding="utf-8", newline="") as f:
        w = csv.DictWriter(f, fieldnames=FIELDS, delimiter="\t", lineterminator="\n")
        w.writeheader()
        w.writerows(rows)
        f.flush()
        os.fsync(f.fileno())
    os.replace(tmp, path)


def row(domain: str, available: bool, candidate_id: str, count: int, notes: str, runtime_loader: str) -> dict[str, str]:
    return {
        "battle_slot_id": SLOT,
        "domain": domain,
        "candidate_available": "true" if available else "false",
        "candidate_id": candidate_id,
        "candidate_count": str(count),
        "candidate_source": "content_engine_preview",
        "formal_source": "legacy",
        "formal_source_unchanged": "true",
        "content_engine_enabled": "false",
        "runtime_loader_config": runtime_loader,
        "notes": notes,
    }


def main() -> int:
    battle_slots = load_json(BATTLE_SLOTS).get("battle_slots", [])
    enemy_decks = load_json(ENEMY_DECKS).get("enemy_decks", [])
    cards = load_json(CARD_POOL).get("cards", [])
    rewards = load_json(REWARDS).get("rewards", [])
    operations = load_json(OPERATIONS).get("operation_nodes", [])
    narratives = load_json(NARRATIVES).get("narrative_nodes", [])
    routes = load_json(ROUTES).get("route_gates", [])

    cfg = load_json(RUNTIME_CONFIG)
    runtime_loader = "disabled" if not bool(cfg.get("content_engine_runtime_enabled", False)) else str(cfg.get("integration_mode", "unknown"))

    slot_ok = any(str(r.get("battle_slot_id", "")) == SLOT for r in battle_slots)
    reward_ok = any(str(r.get("reward_plan_id", "")) == REWARD_ID for r in rewards)

    narrative_has_body = any(any(k in r for k in ["full_text", "body", "dialogue", "content_text", "正文"]) for r in narratives if isinstance(r, dict))

    rows = [
        row("battle_slot", slot_ok, SLOT, 1 if slot_ok else 0, "白名单槽位 candidate。", runtime_loader),
        row("reward", reward_ok, REWARD_ID if reward_ok else "", 1 if reward_ok else 0, "白名单奖励 candidate。", runtime_loader),
        row("enemy_deck", False, "", 0, "未提供 prologue_01 到 deck 的直接绑定。", runtime_loader),
        row("card_pool", len(cards) == 72, "card_pool_preview", len(cards), "仅候选，不进入正式 CardData。", runtime_loader),
        row("operation_node", len(operations) == 10, "operation_nodes_preview", len(operations), "仅候选计数，不进入正式地图流程。", runtime_loader),
        row("narrative", len(narratives) == 28 and not narrative_has_body, "narrative_key_hook_preview", len(narratives), "仅 key/hook，不包含正文。", runtime_loader),
        row("route_gate", len(routes) == 9, "route_gates_preview", len(routes), "仅候选计数，不进入正式路线逻辑。", runtime_loader),
    ]

    atomic_write(OUT, rows)
    print(f"Wrote {OUT.as_posix()} rows={len(rows)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
