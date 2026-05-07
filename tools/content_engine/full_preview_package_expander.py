#!/usr/bin/env python3
"""v1.6 full preview package expansion（仅写 runtime_preview）。"""

from __future__ import annotations

import csv
import json
from collections import defaultdict
from datetime import datetime, timezone
from pathlib import Path
from tempfile import NamedTemporaryFile

BASE = Path("data/runtime_preview/content_engine")

REWARD_JSON = BASE / "battle_rewards.preview.json"
REWARD_MANIFEST = BASE / "battle_rewards.preview_manifest.json"

BATTLE_SLOT_TSV = Path("data/design/generated_battle_slot_plan.tsv")
ENEMY_DECK_TSV = Path("data/design/generated_enemy_deck_sets.tsv")
CARD_POOL_TSV = Path("data/design/generated_card_pool.tsv")
OP_NODE_TSV = Path("data/design/generated_operation_node_plan.tsv")
NARRATIVE_TSV = Path("data/design/generated_narrative_node_plan.tsv")
ROUTE_GATE_TSV = Path("data/design/generated_route_gate_plan.tsv")

OUT_BATTLE_SLOTS = BASE / "battle_slots.preview.json"
OUT_ENEMY_DECKS = BASE / "enemy_decks.preview.json"
OUT_CARD_POOL = BASE / "card_pool.preview.json"
OUT_OPERATION_NODES = BASE / "operation_nodes.preview.json"
OUT_NARRATIVE_NODES = BASE / "narrative_nodes.preview.json"
OUT_ROUTE_GATES = BASE / "route_gates.preview.json"
OUT_FULL_MANIFEST = BASE / "full_content_package.preview_manifest.json"


def read_tsv(path: Path) -> list[dict[str, str]]:
    with path.open("r", encoding="utf-8", newline="") as f:
        return list(csv.DictReader(f, delimiter="\t"))


def write_json_atomic(path: Path, payload: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with NamedTemporaryFile("w", encoding="utf-8", delete=False, dir=path.parent, prefix=path.name, suffix=".tmp") as tmp:
        json.dump(payload, tmp, ensure_ascii=False, indent=2)
        tmp.write("\n")
        tmp_path = Path(tmp.name)
    tmp_path.replace(path)


def top(package_type: str, source_artifact: str, generated_at: str) -> dict[str, object]:
    return {
        "package_type": package_type,
        "runtime_ready": False,
        "preview_only": True,
        "source_artifact": source_artifact,
        "generated_at": generated_at,
        "selected_reward_policy": "legacy",
    }


def main() -> int:
    reward = json.loads(REWARD_JSON.read_text(encoding="utf-8"))
    reward_manifest = json.loads(REWARD_MANIFEST.read_text(encoding="utf-8"))
    rewards = reward.get("rewards", []) if isinstance(reward, dict) else []
    if not isinstance(rewards, list) or len(rewards) != 45:
        raise ValueError("battle_rewards.preview.json rewards must be 45")

    generated_at = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

    # 兼容历史 reward preview：仅补齐顶层元信息，不改 rewards 内容。
    reward_changed = False
    if reward.get("runtime_ready") is not False:
        reward["runtime_ready"] = False
        reward_changed = True
    if reward.get("preview_only") is not True:
        reward["preview_only"] = True
        reward_changed = True
    if reward.get("source_artifact", "") in ("", None):
        reward["source_artifact"] = "generated_battle_reward_plan"
        reward_changed = True
    if reward.get("selected_reward_policy") != "legacy":
        reward["selected_reward_policy"] = "legacy"
        reward_changed = True
    if not reward.get("generated_at"):
        reward["generated_at"] = generated_at
        reward_changed = True
    if reward_changed:
        write_json_atomic(REWARD_JSON, reward)

    manifest_changed = False
    if reward_manifest.get("runtime_ready") is not False:
        reward_manifest["runtime_ready"] = False
        manifest_changed = True
    if reward_manifest.get("preview_only") is not True:
        reward_manifest["preview_only"] = True
        manifest_changed = True
    if reward_manifest.get("selected_reward_policy") != "legacy":
        reward_manifest["selected_reward_policy"] = "legacy"
        manifest_changed = True
    if not reward_manifest.get("generated_at"):
        reward_manifest["generated_at"] = generated_at
        manifest_changed = True
    if manifest_changed:
        write_json_atomic(REWARD_MANIFEST, reward_manifest)

    battle_slots = read_tsv(BATTLE_SLOT_TSV)
    enemy_rows = read_tsv(ENEMY_DECK_TSV)
    card_pool = read_tsv(CARD_POOL_TSV)
    operation_nodes = read_tsv(OP_NODE_TSV)
    narrative_rows = read_tsv(NARRATIVE_TSV)
    route_gates = read_tsv(ROUTE_GATE_TSV)

    enemy_by_deck: dict[str, list[dict[str, str]]] = defaultdict(list)
    for row in enemy_rows:
        enemy_by_deck[row.get("deck_id", "")].append(row)

    enemy_decks: list[dict[str, object]] = []
    for deck_id, rows in sorted(enemy_by_deck.items()):
        if not deck_id:
            continue
        seed = rows[0]
        cards = [r.get("card_id", "") for r in rows if r.get("card_id", "")]
        enemy_decks.append(
            {
                "deck_id": deck_id,
                "archetype_id": seed.get("archetype_id", ""),
                "battle_type": seed.get("battle_type", ""),
                "tier": seed.get("tier", ""),
                "variant_index": seed.get("variant_index", ""),
                "card_count": len(cards),
                "card_ids": cards,
            }
        )

    narrative_nodes = [
        {
            "narrative_node_id": r.get("narrative_node_id", ""),
            "source_id": r.get("source_id", ""),
            "node_kind": r.get("node_kind", ""),
            "narrative_role": r.get("narrative_role", ""),
            "hook_tags": r.get("hook_tags", ""),
            "hook_line": r.get("hook_line", ""),
            "trigger_stage": r.get("trigger_stage", ""),
        }
        for r in narrative_rows
    ]

    payloads = {
        OUT_BATTLE_SLOTS: {**top("battle_slots_preview", "generated_battle_slot_plan", generated_at), "battle_slots": battle_slots},
        OUT_ENEMY_DECKS: {**top("enemy_decks_preview", "generated_enemy_deck_sets", generated_at), "enemy_decks": enemy_decks},
        OUT_CARD_POOL: {**top("card_pool_preview", "generated_card_pool", generated_at), "cards": card_pool},
        OUT_OPERATION_NODES: {**top("operation_nodes_preview", "generated_operation_node_plan", generated_at), "operation_nodes": operation_nodes},
        OUT_NARRATIVE_NODES: {**top("narrative_nodes_preview", "generated_narrative_node_plan", generated_at), "narrative_nodes": narrative_nodes},
        OUT_ROUTE_GATES: {**top("route_gates_preview", "generated_route_gate_plan", generated_at), "route_gates": route_gates},
    }

    for path, payload in payloads.items():
        write_json_atomic(path, payload)

    full_manifest = {
        "package_type": "full_content_preview_manifest",
        "runtime_ready": False,
        "preview_only": True,
        "source_artifact": "full_preview_package_expansion_v1_6",
        "generated_at": generated_at,
        "selected_reward_policy": "legacy",
        "content_engine_enabled": False,
        "domains": [
            {"domain": "battle_rewards", "path": REWARD_JSON.as_posix(), "count": len(rewards), "runtime_ready": False, "preview_only": True},
            {"domain": "battle_slots", "path": OUT_BATTLE_SLOTS.as_posix(), "count": len(battle_slots), "runtime_ready": False, "preview_only": True},
            {"domain": "enemy_decks", "path": OUT_ENEMY_DECKS.as_posix(), "count": len(enemy_decks), "runtime_ready": False, "preview_only": True},
            {"domain": "card_pool", "path": OUT_CARD_POOL.as_posix(), "count": len(card_pool), "runtime_ready": False, "preview_only": True},
            {"domain": "operation_nodes", "path": OUT_OPERATION_NODES.as_posix(), "count": len(operation_nodes), "runtime_ready": False, "preview_only": True},
            {"domain": "narrative_nodes", "path": OUT_NARRATIVE_NODES.as_posix(), "count": len(narrative_nodes), "runtime_ready": False, "preview_only": True},
            {"domain": "route_gates", "path": OUT_ROUTE_GATES.as_posix(), "count": len(route_gates), "runtime_ready": False, "preview_only": True},
        ],
        "blockers": ["runtime_loader_disabled", "preview_only", "not_runtime_export"],
        "notes": "复用 reward preview；本阶段仅扩展 full preview package，不写 data/runtime。",
        "source_reward_manifest": reward_manifest,
    }
    write_json_atomic(OUT_FULL_MANIFEST, full_manifest)

    print("Wrote full preview package and manifest")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
