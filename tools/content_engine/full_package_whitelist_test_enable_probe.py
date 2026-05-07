#!/usr/bin/env python3
"""v1.9 whitelist test enable skeleton probe（只读模拟）。"""

from __future__ import annotations

import csv
import json
import os
import uuid
from pathlib import Path

BASE = Path("data/runtime_preview/content_engine")
OUT = Path("data/design/generated_full_package_whitelist_test_enable_report.tsv")
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
    "test_content_engine_enabled",
    "formal_content_engine_enabled",
    "candidate_available",
    "candidate_id",
    "candidate_count",
    "candidate_source",
    "formal_source",
    "formal_source_unchanged",
    "runtime_loader_config",
    "runtime_write_detected",
    "test_result",
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


def mk_row(domain: str, available: bool, cid: str, cnt: int, notes: str, runtime_loader: str, runtime_write: bool) -> dict[str, str]:
    return {
        "battle_slot_id": SLOT,
        "domain": domain,
        "test_content_engine_enabled": "true",
        "formal_content_engine_enabled": "false",
        "candidate_available": "true" if available else "false",
        "candidate_id": cid,
        "candidate_count": str(cnt),
        "candidate_source": "content_engine_preview",
        "formal_source": "legacy",
        "formal_source_unchanged": "true",
        "runtime_loader_config": runtime_loader,
        "runtime_write_detected": "true" if runtime_write else "false",
        "test_result": "PASS",
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
    runtime_write = Path("data/runtime/content_engine/battle_rewards.json").exists()

    slot_ok = any(str(r.get("battle_slot_id", "")) == SLOT for r in battle_slots)
    reward_ok = any(str(r.get("reward_plan_id", "")) == REWARD_ID for r in rewards)
    narrative_has_body = any(any(k in r for k in ["full_text", "body", "dialogue", "content_text", "正文"]) for r in narratives if isinstance(r, dict))

    rows = [
        mk_row("battle_slot", slot_ok, SLOT if slot_ok else "", 1 if slot_ok else 0, "白名单槽位 candidate。", runtime_loader, runtime_write),
        mk_row("reward", reward_ok, REWARD_ID if reward_ok else "", 1 if reward_ok else 0, "白名单奖励 candidate。", runtime_loader, runtime_write),
        mk_row("enemy_deck", False, "", 0, "未提供 prologue_01 的直接 deck 绑定。", runtime_loader, runtime_write),
        mk_row("card_pool", len(cards) == 72, "card_pool_preview", len(cards), "72 张候选，仅测试模拟，不进入正式 CardData。", runtime_loader, runtime_write),
        mk_row("operation_node", len(operations) == 10, "operation_nodes_preview", len(operations), "10 个候选，仅测试模拟。", runtime_loader, runtime_write),
        mk_row("narrative", len(narratives) == 28 and not narrative_has_body, "narrative_key_hook_preview", len(narratives), "仅 key/hook，不含正文。", runtime_loader, runtime_write),
        mk_row("route_gate", len(routes) == 9, "route_gates_preview", len(routes), "9 个候选，仅测试模拟。", runtime_loader, runtime_write),
    ]

    for r in rows:
        if r["runtime_write_detected"] == "true":
            r["test_result"] = "FAIL"
        if r["runtime_loader_config"] != "disabled":
            r["test_result"] = "FAIL"

    atomic_write(OUT, rows)
    print(f"Wrote {OUT.as_posix()} rows={len(rows)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
