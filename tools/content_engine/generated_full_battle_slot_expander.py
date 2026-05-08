#!/usr/bin/env python3
from __future__ import annotations

import csv
import json
from datetime import datetime, timezone
from pathlib import Path

DESIGN = Path("data/design")
RUNTIME_PREVIEW = Path("data/runtime_preview/content_engine")
RUNTIME_WHITELIST = Path("data/runtime/content_engine_whitelist")

OUT_CONFIG = DESIGN / "generated_full_battle_slot_whitelist_config.tsv"
OUT_BINDING = DESIGN / "generated_full_battle_slot_binding_map.tsv"
OUT_INTEGRATION = DESIGN / "generated_full_battle_slot_integration_report.tsv"
OUT_BUNDLE = RUNTIME_WHITELIST / "generated_full_battle_slots.full_content_bridge.json"
OUT_MANIFEST = RUNTIME_WHITELIST / "generated_full_battle_slots_manifest.json"


def now_iso() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="seconds")


def load_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def write_tsv(path: Path, fields: list[str], rows: list[dict[str, str]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="") as f:
        w = csv.DictWriter(f, fieldnames=fields, delimiter="\t", lineterminator="\n")
        w.writeheader()
        w.writerows(rows)


def slot_group(slot_id: str) -> str:
    if slot_id.startswith("prologue"):
        return "prologue"
    if slot_id.startswith("wuju") or slot_id.startswith("wz_exam"):
        return "wuju"
    if "boss" in slot_id:
        return "boss"
    if "big_map" in slot_id:
        return "big_map"
    return "other"


def main() -> int:
    battle_slots = load_json(RUNTIME_PREVIEW / "battle_slots.preview.json").get("battle_slots", [])
    battle_rewards = load_json(RUNTIME_PREVIEW / "battle_rewards.preview.json").get("rewards", [])
    enemy_decks = load_json(RUNTIME_PREVIEW / "enemy_decks.preview.json").get("enemy_decks", [])
    card_pool = load_json(RUNTIME_PREVIEW / "card_pool.preview.json").get("cards", [])
    operation_nodes = load_json(RUNTIME_PREVIEW / "operation_nodes.preview.json").get("operation_nodes", [])
    narrative_nodes = load_json(RUNTIME_PREVIEW / "narrative_nodes.preview.json").get("narrative_nodes", [])
    route_gates = load_json(RUNTIME_PREVIEW / "route_gates.preview.json").get("route_gates", [])

    slot_ids = sorted({str(r.get("battle_slot_id", "")) for r in battle_slots if str(r.get("battle_slot_id", ""))})
    reward_by_slot: dict[str, str] = {}
    for row in battle_rewards:
        sid = str(row.get("battle_slot_id", ""))
        rid = str(row.get("reward_plan_id", ""))
        if sid and rid and sid not in reward_by_slot:
            reward_by_slot[sid] = rid

    default_enemy_deck = str(enemy_decks[0].get("deck_id", "")) if enemy_decks else ""
    domains = ["battle_slot", "enemy_deck", "card_pool", "reward", "operation_node", "narrative", "route_gate"]

    cfg_rows: list[dict[str, str]] = []
    binding_rows: list[dict[str, str]] = []
    slot_bundle_map: dict[str, dict] = {}

    for sid in slot_ids:
        reward_id = reward_by_slot.get(sid, "")
        reward_fallback_required = not bool(reward_id)
        cfg_rows.append(
            {
                "battle_slot_id": sid,
                "slot_group": slot_group(sid),
                "whitelist_enabled": "true",
                "generated_content_enabled": "true",
                "rollback_policy": "legacy",
                "enabled_domains": "battle_slot,enemy_deck,card_pool,reward,operation_node,narrative,route_gate",
                "reward_plan_id": reward_id,
                "reward_fallback_required": "true" if reward_fallback_required else "false",
                "notes": "reward 缺失仅该域 fallback legacy" if reward_fallback_required else "full preview battle_slot generated enabled",
            }
        )

        domain_map = {
            "battle_slot": {
                "candidate_available": True,
                "candidate_id": sid,
                "candidate_count": 1,
                "formal_source": "content_engine",
                "fallback_policy": "legacy",
                "binding_reason": "preview_battle_slot_candidate",
                "notes": "battle_slot candidate available",
            },
            "enemy_deck": {
                "candidate_available": bool(default_enemy_deck),
                "candidate_id": default_enemy_deck,
                "candidate_count": 1 if default_enemy_deck else 0,
                "formal_source": "content_engine" if default_enemy_deck else "legacy",
                "fallback_policy": "legacy",
                "binding_reason": "whitelist_default_enemy_deck_candidate",
                "notes": "enemy_deck default candidate",
            },
            "card_pool": {
                "candidate_available": True,
                "candidate_id": "card_pool_preview",
                "candidate_count": len(card_pool),
                "formal_source": "content_engine_candidate",
                "fallback_policy": "legacy",
                "binding_reason": "shared_preview_card_pool",
                "notes": "readonly candidate no CardData write",
            },
            "reward": {
                "candidate_available": bool(reward_id),
                "candidate_id": reward_id,
                "candidate_count": 1 if reward_id else 0,
                "formal_source": "content_engine" if reward_id else "legacy",
                "fallback_policy": "legacy",
                "binding_reason": "slot_reward_lookup" if reward_id else "reward_missing_fallback_legacy",
                "notes": "reward 缺失时 fallback legacy",
            },
            "operation_node": {
                "candidate_available": True,
                "candidate_id": "operation_nodes_preview",
                "candidate_count": len(operation_nodes),
                "formal_source": "content_engine_candidate",
                "fallback_policy": "legacy",
                "binding_reason": "shared_preview_operation_nodes",
                "notes": "candidate only",
            },
            "narrative": {
                "candidate_available": True,
                "candidate_id": "narrative_key_hook_preview",
                "candidate_count": len(narrative_nodes),
                "formal_source": "content_engine_candidate",
                "fallback_policy": "legacy",
                "binding_reason": "shared_preview_narrative_keys",
                "notes": "key/hook only no body text",
            },
            "route_gate": {
                "candidate_available": True,
                "candidate_id": "route_gates_preview",
                "candidate_count": len(route_gates),
                "formal_source": "content_engine_candidate",
                "fallback_policy": "legacy",
                "binding_reason": "shared_preview_route_gates",
                "notes": "candidate only no formal routing change",
            },
        }
        slot_bundle_map[sid] = domain_map
        for d in domains:
            row = domain_map[d]
            binding_rows.append(
                {
                    "battle_slot_id": sid,
                    "domain": d,
                    "candidate_available": "true" if bool(row["candidate_available"]) else "false",
                    "candidate_id": str(row["candidate_id"]),
                    "candidate_count": str(row["candidate_count"]),
                    "formal_source": str(row["formal_source"]),
                    "fallback_policy": "legacy",
                    "binding_reason": str(row["binding_reason"]),
                    "notes": str(row["notes"]),
                }
            )

    write_tsv(
        OUT_CONFIG,
        [
            "battle_slot_id",
            "slot_group",
            "whitelist_enabled",
            "generated_content_enabled",
            "rollback_policy",
            "enabled_domains",
            "reward_plan_id",
            "reward_fallback_required",
            "notes",
        ],
        cfg_rows,
    )
    write_tsv(
        OUT_BINDING,
        [
            "battle_slot_id",
            "domain",
            "candidate_available",
            "candidate_id",
            "candidate_count",
            "formal_source",
            "fallback_policy",
            "binding_reason",
            "notes",
        ],
        binding_rows,
    )

    bundle = {
        "package_type": "full_content_all_preview_battle_slots_bridge",
        "generated_at": now_iso(),
        "rollback_policy": "legacy",
        "global_content_engine_enabled": False,
        "formal_runtime_enabled": False,
        "runtime_ready": False,
        "bridge_only": True,
        "full_battle_slot_content_enabled": True,
        "whitelist_battle_slots": slot_ids,
        "slots": {
            sid: {
                "battle_slot_id": sid,
                "rollback_policy": "legacy",
                "global_content_engine_enabled": False,
                "formal_runtime_enabled": False,
                "runtime_ready": False,
                "bridge_only": True,
                "domains": {
                    d: {
                        "candidate_available": slot_bundle_map[sid][d]["candidate_available"],
                        "candidate_id": slot_bundle_map[sid][d]["candidate_id"],
                        "candidate_count": slot_bundle_map[sid][d]["candidate_count"],
                    }
                    for d in domains
                },
            }
            for sid in slot_ids
        },
    }
    manifest = {
        "package_type": "full_content_all_preview_battle_slots_bridge_manifest",
        "generated_at": now_iso(),
        "whitelist_battle_slots": slot_ids,
        "bundle_path": "res://data/runtime/content_engine_whitelist/generated_full_battle_slots.full_content_bridge.json",
        "bundle_count": 1,
        "rollback_policy": "legacy",
        "global_content_engine_enabled": False,
        "formal_runtime_enabled": False,
        "runtime_ready": False,
        "bridge_only": True,
        "full_battle_slot_content_enabled": True,
    }
    OUT_BUNDLE.parent.mkdir(parents=True, exist_ok=True)
    OUT_BUNDLE.write_text(json.dumps(bundle, ensure_ascii=False, indent=2), encoding="utf-8")
    OUT_MANIFEST.write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8")

    integration_rows = [
        {"check_id": "preview_battle_slot_total", "value": str(len(slot_ids))},
        {"check_id": "whitelist_config_total", "value": str(len(cfg_rows))},
        {"check_id": "binding_total", "value": str(len(binding_rows))},
        {"check_id": "binding_expected", "value": str(len(slot_ids) * len(domains))},
        {"check_id": "card_pool_count", "value": str(len(card_pool))},
        {"check_id": "operation_node_count", "value": str(len(operation_nodes))},
        {"check_id": "narrative_count", "value": str(len(narrative_nodes))},
        {"check_id": "route_gate_count", "value": str(len(route_gates))},
        {"check_id": "prologue_01_reward", "value": reward_by_slot.get("prologue_01", "")},
        {
            "check_id": "reward_fallback_slot_count",
            "value": str(sum(1 for r in cfg_rows if r["reward_fallback_required"] == "true")),
        },
    ]
    write_tsv(OUT_INTEGRATION, ["check_id", "value"], integration_rows)

    print(f"PASS: full preview battle_slot expanded slots={len(slot_ids)} binding={len(binding_rows)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
