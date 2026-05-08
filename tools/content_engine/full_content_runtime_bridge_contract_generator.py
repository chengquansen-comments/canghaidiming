#!/usr/bin/env python3
"""v2.1 full content runtime bridge contract + whitelist bundle generator。"""

from __future__ import annotations

import csv
import json
import os
import uuid
from datetime import datetime, timezone
from pathlib import Path

READINESS = Path("data/design/generated_full_package_runtime_readiness.tsv")
PREVIEW_BASE = Path("data/runtime_preview/content_engine")

OUT_CONTRACT = Path("data/design/generated_full_content_adapter_contract.tsv")
OUT_BINDING = Path("data/design/generated_full_content_whitelist_binding_map.tsv")
OUT_BUNDLE = Path("data/runtime/content_engine_whitelist/prologue_01.full_content_bridge.json")
OUT_MANIFEST = Path("data/runtime/content_engine_whitelist/full_content_bridge_manifest.json")

SLOT = "prologue_01"
REWARD_ID = "rw_prologue_01"

CONTRACT_FIELDS = [
    "domain",
    "adapter_name",
    "runtime_input_path",
    "expected_runtime_object",
    "required_methods",
    "fallback_policy",
    "write_to_game_state_allowed",
    "formal_flow_touch_required",
    "contract_status",
    "notes",
]

BINDING_FIELDS = [
    "battle_slot_id",
    "domain",
    "candidate_available",
    "candidate_id",
    "candidate_count",
    "candidate_source",
    "binding_status",
    "binding_reason",
    "runtime_bridge_allowed",
    "notes",
]


def now_iso() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="seconds")


def read_tsv(path: Path) -> list[dict[str, str]]:
    with path.open("r", encoding="utf-8", newline="") as f:
        return list(csv.DictReader(f, delimiter="\t"))


def write_tsv_atomic(path: Path, fields: list[str], rows: list[dict[str, str]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_name(f"{path.name}.{uuid.uuid4().hex}.tmp")
    with tmp.open("w", encoding="utf-8", newline="") as f:
        w = csv.DictWriter(f, fieldnames=fields, delimiter="\t", lineterminator="\n")
        w.writeheader()
        w.writerows(rows)
        f.flush()
        os.fsync(f.fileno())
    os.replace(tmp, path)


def write_json_atomic(path: Path, payload: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_name(f"{path.name}.{uuid.uuid4().hex}.tmp")
    with tmp.open("w", encoding="utf-8") as f:
        json.dump(payload, f, ensure_ascii=False, indent=2)
        f.write("\n")
        f.flush()
        os.fsync(f.fileno())
    os.replace(tmp, path)


def main() -> int:
    _ = read_tsv(READINESS)

    battle_slots = json.loads((PREVIEW_BASE / "battle_slots.preview.json").read_text(encoding="utf-8")).get("battle_slots", [])
    enemy_decks = json.loads((PREVIEW_BASE / "enemy_decks.preview.json").read_text(encoding="utf-8")).get("enemy_decks", [])
    cards = json.loads((PREVIEW_BASE / "card_pool.preview.json").read_text(encoding="utf-8")).get("cards", [])
    rewards = json.loads((PREVIEW_BASE / "battle_rewards.preview.json").read_text(encoding="utf-8")).get("rewards", [])
    operation_nodes = json.loads((PREVIEW_BASE / "operation_nodes.preview.json").read_text(encoding="utf-8")).get("operation_nodes", [])
    narrative_nodes = json.loads((PREVIEW_BASE / "narrative_nodes.preview.json").read_text(encoding="utf-8")).get("narrative_nodes", [])
    route_gates = json.loads((PREVIEW_BASE / "route_gates.preview.json").read_text(encoding="utf-8")).get("route_gates", [])

    slot_ok = any(str(r.get("battle_slot_id", "")) == SLOT for r in battle_slots)
    reward_ok = any(str(r.get("reward_plan_id", "")) == REWARD_ID for r in rewards)

    # 敌方 deck 白名单默认候选：优先 normal tier，再按 card_count 升序。
    def deck_rank(d: dict) -> tuple[int, int, str]:
        tier = str(d.get("tier", "")).lower()
        normal_rank = 0 if tier in {"normal", "common", "base", "tier_1", "1"} else 1
        card_count = int(d.get("card_count", 9999)) if str(d.get("card_count", "")).isdigit() else 9999
        return (normal_rank, card_count, str(d.get("deck_id", "")))

    enemy_candidate = min(enemy_decks, key=deck_rank) if enemy_decks else {}
    enemy_id = str(enemy_candidate.get("deck_id", ""))
    enemy_available = bool(enemy_id)

    narrative_has_body = any(any(k in n for k in ["full_text", "body", "dialogue", "content_text", "正文"]) for n in narrative_nodes if isinstance(n, dict))

    contract_rows = [
        {
            "domain": "battle_slot",
            "adapter_name": "battle_slot_runtime_bridge_adapter",
            "runtime_input_path": "data/runtime/content_engine_whitelist/prologue_01.full_content_bridge.json::domains.battle_slot",
            "expected_runtime_object": "BattleSlotCandidate",
            "required_methods": "resolve_battle_slot_candidate,validate_slot_candidate",
            "fallback_policy": "legacy",
            "write_to_game_state_allowed": "false",
            "formal_flow_touch_required": "true",
            "contract_status": "proposal",
            "notes": "仅定义 contract，不实现 Godot adapter。",
        },
        {
            "domain": "enemy_deck",
            "adapter_name": "enemy_deck_runtime_bridge_adapter",
            "runtime_input_path": "data/runtime/content_engine_whitelist/prologue_01.full_content_bridge.json::domains.enemy_deck",
            "expected_runtime_object": "EnemyDeckCandidate",
            "required_methods": "resolve_enemy_deck_candidate,validate_enemy_binding",
            "fallback_policy": "legacy",
            "write_to_game_state_allowed": "false",
            "formal_flow_touch_required": "true",
            "contract_status": "proposal",
            "notes": "白名单默认候选，仅 bridge。",
        },
        {
            "domain": "card_pool",
            "adapter_name": "card_pool_runtime_bridge_adapter",
            "runtime_input_path": "data/runtime/content_engine_whitelist/prologue_01.full_content_bridge.json::domains.card_pool",
            "expected_runtime_object": "CardPoolCandidate",
            "required_methods": "resolve_card_pool_candidate,validate_card_pool_candidate",
            "fallback_policy": "legacy",
            "write_to_game_state_allowed": "false",
            "formal_flow_touch_required": "true",
            "contract_status": "proposal",
            "notes": "不写入 CardData，仅 contract。",
        },
        {
            "domain": "reward",
            "adapter_name": "battle_reward_runtime_bridge_adapter",
            "runtime_input_path": "data/runtime/content_engine_whitelist/prologue_01.full_content_bridge.json::domains.reward",
            "expected_runtime_object": "RewardCandidate",
            "required_methods": "resolve_reward_candidate,compare_with_legacy_reward",
            "fallback_policy": "legacy",
            "write_to_game_state_allowed": "false",
            "formal_flow_touch_required": "true",
            "contract_status": "proposal",
            "notes": "formal selected_reward 仍 legacy。",
        },
        {
            "domain": "operation_node",
            "adapter_name": "operation_node_runtime_bridge_adapter",
            "runtime_input_path": "data/runtime/content_engine_whitelist/prologue_01.full_content_bridge.json::domains.operation_node",
            "expected_runtime_object": "OperationNodeCandidate",
            "required_methods": "resolve_operation_candidate,validate_operation_candidate",
            "fallback_policy": "legacy",
            "write_to_game_state_allowed": "false",
            "formal_flow_touch_required": "true",
            "contract_status": "proposal",
            "notes": "仅 bridge 计数，不挂地图。",
        },
        {
            "domain": "narrative",
            "adapter_name": "narrative_runtime_bridge_adapter",
            "runtime_input_path": "data/runtime/content_engine_whitelist/prologue_01.full_content_bridge.json::domains.narrative",
            "expected_runtime_object": "NarrativeHookCandidate",
            "required_methods": "resolve_narrative_candidate,validate_narrative_hook_only",
            "fallback_policy": "legacy",
            "write_to_game_state_allowed": "false",
            "formal_flow_touch_required": "true",
            "contract_status": "proposal",
            "notes": "仅 key/hook，不含正文。",
        },
        {
            "domain": "route_gate",
            "adapter_name": "route_gate_runtime_bridge_adapter",
            "runtime_input_path": "data/runtime/content_engine_whitelist/prologue_01.full_content_bridge.json::domains.route_gate",
            "expected_runtime_object": "RouteGateCandidate",
            "required_methods": "resolve_route_gate_candidate,validate_route_gate_candidate",
            "fallback_policy": "legacy",
            "write_to_game_state_allowed": "false",
            "formal_flow_touch_required": "true",
            "contract_status": "proposal",
            "notes": "仅 bridge 计数，不接正式路线逻辑。",
        },
    ]

    binding_rows = [
        {
            "battle_slot_id": SLOT,
            "domain": "battle_slot",
            "candidate_available": "true" if slot_ok else "false",
            "candidate_id": SLOT if slot_ok else "",
            "candidate_count": "1" if slot_ok else "0",
            "candidate_source": "runtime_preview.battle_slots",
            "binding_status": "bound" if slot_ok else "missing",
            "binding_reason": "whitelist_battle_slot_candidate",
            "runtime_bridge_allowed": "true",
            "notes": "白名单槽位绑定。",
        },
        {
            "battle_slot_id": SLOT,
            "domain": "enemy_deck",
            "candidate_available": "true" if enemy_available else "false",
            "candidate_id": enemy_id,
            "candidate_count": "1" if enemy_available else "0",
            "candidate_source": "runtime_preview.enemy_decks",
            "binding_status": "bound" if enemy_available else "missing",
            "binding_reason": "whitelist_default_enemy_deck_candidate",
            "runtime_bridge_allowed": "true",
            "notes": "最低复杂度普通 deck 候选。",
        },
        {
            "battle_slot_id": SLOT,
            "domain": "card_pool",
            "candidate_available": "true",
            "candidate_id": "card_pool_preview",
            "candidate_count": str(len(cards)),
            "candidate_source": "runtime_preview.card_pool",
            "binding_status": "bound",
            "binding_reason": "whitelist_card_pool_candidate",
            "runtime_bridge_allowed": "true",
            "notes": "仅候选，不进入 CardData。",
        },
        {
            "battle_slot_id": SLOT,
            "domain": "reward",
            "candidate_available": "true" if reward_ok else "false",
            "candidate_id": REWARD_ID if reward_ok else "",
            "candidate_count": "1" if reward_ok else "0",
            "candidate_source": "runtime_preview.battle_rewards",
            "binding_status": "bound" if reward_ok else "missing",
            "binding_reason": "whitelist_reward_candidate",
            "runtime_bridge_allowed": "true",
            "notes": "白名单奖励绑定。",
        },
        {
            "battle_slot_id": SLOT,
            "domain": "operation_node",
            "candidate_available": "true",
            "candidate_id": "operation_nodes_preview",
            "candidate_count": str(len(operation_nodes)),
            "candidate_source": "runtime_preview.operation_nodes",
            "binding_status": "bound",
            "binding_reason": "whitelist_operation_candidate",
            "runtime_bridge_allowed": "true",
            "notes": "仅计数，不接正式地图流程。",
        },
        {
            "battle_slot_id": SLOT,
            "domain": "narrative",
            "candidate_available": "true" if (not narrative_has_body and len(narrative_nodes) > 0) else "false",
            "candidate_id": "narrative_key_hook_preview",
            "candidate_count": str(len(narrative_nodes)),
            "candidate_source": "runtime_preview.narrative_nodes",
            "binding_status": "bound" if (not narrative_has_body and len(narrative_nodes) > 0) else "blocked",
            "binding_reason": "whitelist_narrative_hook_candidate",
            "runtime_bridge_allowed": "true",
            "notes": "仅 key/hook，不允许正文。",
        },
        {
            "battle_slot_id": SLOT,
            "domain": "route_gate",
            "candidate_available": "true",
            "candidate_id": "route_gates_preview",
            "candidate_count": str(len(route_gates)),
            "candidate_source": "runtime_preview.route_gates",
            "binding_status": "bound",
            "binding_reason": "whitelist_route_gate_candidate",
            "runtime_bridge_allowed": "true",
            "notes": "仅计数，不接正式路线逻辑。",
        },
    ]

    bundle = {
        "package_type": "full_content_whitelist_bridge",
        "generated_at": now_iso(),
        "battle_slot_id": SLOT,
        "global_content_engine_enabled": False,
        "formal_runtime_enabled": False,
        "rollback_policy": "legacy",
        "runtime_ready": False,
        "bridge_only": True,
        "domains": {
            "battle_slot": {"candidate_id": SLOT if slot_ok else "", "candidate_available": slot_ok, "candidate_count": 1 if slot_ok else 0},
            "enemy_deck": {"candidate_id": enemy_id, "candidate_available": enemy_available, "candidate_count": 1 if enemy_available else 0, "binding_reason": "whitelist_default_enemy_deck_candidate"},
            "card_pool": {"candidate_id": "card_pool_preview", "candidate_available": True, "candidate_count": len(cards)},
            "reward": {"candidate_id": REWARD_ID if reward_ok else "", "candidate_available": reward_ok, "candidate_count": 1 if reward_ok else 0},
            "operation_node": {"candidate_id": "operation_nodes_preview", "candidate_available": True, "candidate_count": len(operation_nodes)},
            "narrative": {"candidate_id": "narrative_key_hook_preview", "candidate_available": (not narrative_has_body and len(narrative_nodes) > 0), "candidate_count": len(narrative_nodes), "hook_only": True},
            "route_gate": {"candidate_id": "route_gates_preview", "candidate_available": True, "candidate_count": len(route_gates)},
        },
        "notes": "仅 whitelist bridge bundle；不启用正式 generated content。",
    }

    manifest = {
        "package_type": "full_content_whitelist_bridge_manifest",
        "generated_at": now_iso(),
        "whitelist_battle_slots": [SLOT],
        "bundle_count": 1,
        "global_content_engine_enabled": False,
        "formal_runtime_enabled": False,
        "rollback_policy": "legacy",
        "runtime_ready": False,
        "bridge_only": True,
        "bundles": [OUT_BUNDLE.as_posix()],
    }

    write_tsv_atomic(OUT_CONTRACT, CONTRACT_FIELDS, contract_rows)
    write_tsv_atomic(OUT_BINDING, BINDING_FIELDS, binding_rows)
    write_json_atomic(OUT_BUNDLE, bundle)
    write_json_atomic(OUT_MANIFEST, manifest)

    print(
        f"Wrote {OUT_CONTRACT.as_posix()}, {OUT_BINDING.as_posix()}, "
        f"{OUT_BUNDLE.as_posix()}, {OUT_MANIFEST.as_posix()}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
