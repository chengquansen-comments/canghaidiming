#!/usr/bin/env python3
from __future__ import annotations

import csv
import json
from datetime import datetime, timezone
from pathlib import Path

DESIGN = Path("data/design")
RUNTIME_PREVIEW = Path("data/runtime_preview/content_engine")
RUNTIME_WHITELIST = Path("data/runtime/content_engine_whitelist")

OUT_CONFIG = DESIGN / "generated_slice_whitelist_config.tsv"
OUT_BINDING = DESIGN / "generated_slice_whitelist_binding_map.tsv"
OUT_ACCEPT = DESIGN / "generated_slice_whitelist_acceptance_report.tsv"
OUT_BUNDLE = RUNTIME_WHITELIST / "generated_slice.full_content_bridge.json"
OUT_MANIFEST = RUNTIME_WHITELIST / "generated_slice_manifest.json"


def now_iso() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="seconds")


def write_tsv(path: Path, fields: list[str], rows: list[dict[str, str]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="") as f:
        w = csv.DictWriter(f, fieldnames=fields, delimiter="\t", lineterminator="\n")
        w.writeheader()
        w.writerows(rows)


def load_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def contains_kw(text: str) -> bool:
    t = text.lower()
    kws = ["wuju", "weapon", "exam", "武举", "武器", "考试"]
    return any(k in t for k in kws)


def main() -> int:
    battle_slots = load_json(RUNTIME_PREVIEW / "battle_slots.preview.json")["battle_slots"]
    battle_rewards = load_json(RUNTIME_PREVIEW / "battle_rewards.preview.json")["rewards"]
    enemy_decks = load_json(RUNTIME_PREVIEW / "enemy_decks.preview.json")["enemy_decks"]
    card_pool = load_json(RUNTIME_PREVIEW / "card_pool.preview.json").get("cards", [])
    operation_nodes = load_json(RUNTIME_PREVIEW / "operation_nodes.preview.json")["operation_nodes"]
    narrative_nodes = load_json(RUNTIME_PREVIEW / "narrative_nodes.preview.json")["narrative_nodes"]
    route_gates = load_json(RUNTIME_PREVIEW / "route_gates.preview.json")["route_gates"]

    discovered = []
    for row in battle_slots:
        sid = str(row.get("battle_slot_id", ""))
        hay = " ".join([sid, str(row.get("stage", "")), str(row.get("route_type", "")), str(row.get("notes", ""))])
        if sid.startswith("prologue") or contains_kw(hay):
            discovered.append(sid)
    discovered = sorted(set(discovered))
    if "prologue_01" not in discovered:
        discovered.insert(0, "prologue_01")

    reward_by_slot = {}
    for r in battle_rewards:
        s = str(r.get("battle_slot_id", ""))
        if s and s not in reward_by_slot:
            reward_by_slot[s] = str(r.get("reward_plan_id", ""))

    default_enemy_deck = str(enemy_decks[0].get("deck_id", "")) if enemy_decks else ""

    config_rows = []
    for sid in discovered:
        slice_type = "prologue" if sid.startswith("prologue") else "wuju_slice"
        reward_plan = reward_by_slot.get(sid, "")
        config_rows.append(
            {
                "battle_slot_id": sid,
                "slice_type": slice_type,
                "whitelist_enabled": "true",
                "generated_content_enabled": "true",
                "rollback_policy": "legacy",
                "enabled_domains": "battle_slot,enemy_deck,card_pool,reward,operation_node,narrative,route_gate",
                "reward_plan_id": reward_plan,
                "notes": "reward 缺失时该域回落 legacy" if not reward_plan else "generated slice whitelist",
            }
        )

    binding_rows = []
    domains = ["battle_slot", "enemy_deck", "card_pool", "reward", "operation_node", "narrative", "route_gate"]
    slot_bundles = {}
    for sid in discovered:
        reward_id = reward_by_slot.get(sid, "")
        slot_domains = {
            "battle_slot": {
                "candidate_available": True,
                "candidate_id": sid,
                "candidate_count": 1,
                "formal_source": "content_engine",
                "fallback_policy": "legacy",
                "binding_reason": "slot_discovered",
                "notes": "battle slot candidate",
            },
            "enemy_deck": {
                "candidate_available": bool(default_enemy_deck),
                "candidate_id": default_enemy_deck,
                "candidate_count": 1 if default_enemy_deck else 0,
                "formal_source": "content_engine" if default_enemy_deck else "legacy",
                "fallback_policy": "legacy",
                "binding_reason": "whitelist_default_enemy_deck_candidate",
                "notes": "default candidate",
            },
            "card_pool": {
                "candidate_available": True,
                "candidate_id": "card_pool_preview",
                "candidate_count": len(card_pool),
                "formal_source": "content_engine_candidate",
                "fallback_policy": "legacy",
                "binding_reason": "shared_preview_pool",
                "notes": "readonly no CardData write",
            },
            "reward": {
                "candidate_available": bool(reward_id),
                "candidate_id": reward_id,
                "candidate_count": 1 if reward_id else 0,
                "formal_source": "content_engine" if reward_id else "legacy",
                "fallback_policy": "legacy",
                "binding_reason": "slot_reward_lookup" if reward_id else "reward_missing_fallback_legacy",
                "notes": "reward 缺失则 legacy",
            },
            "operation_node": {
                "candidate_available": True,
                "candidate_id": "operation_nodes_preview",
                "candidate_count": len(operation_nodes),
                "formal_source": "content_engine_candidate",
                "fallback_policy": "legacy",
                "binding_reason": "shared_operation_nodes",
                "notes": "candidate only",
            },
            "narrative": {
                "candidate_available": True,
                "candidate_id": "narrative_key_hook_preview",
                "candidate_count": len(narrative_nodes),
                "formal_source": "content_engine_candidate",
                "fallback_policy": "legacy",
                "binding_reason": "shared_narrative_hooks",
                "notes": "key/hook only",
            },
            "route_gate": {
                "candidate_available": True,
                "candidate_id": "route_gates_preview",
                "candidate_count": len(route_gates),
                "formal_source": "content_engine_candidate",
                "fallback_policy": "legacy",
                "binding_reason": "shared_route_gates",
                "notes": "candidate only no formal routing change",
            },
        }
        slot_bundles[sid] = slot_domains
        for d in domains:
            v = slot_domains[d]
            binding_rows.append(
                {
                    "battle_slot_id": sid,
                    "domain": d,
                    "candidate_available": str(bool(v["candidate_available"]).lower() if isinstance(v["candidate_available"], str) else str(v["candidate_available"]).lower()),
                    "candidate_id": str(v["candidate_id"]),
                    "candidate_count": str(v["candidate_count"]),
                    "formal_source": str(v["formal_source"]),
                    "fallback_policy": "legacy",
                    "binding_reason": str(v["binding_reason"]),
                    "notes": str(v["notes"]),
                }
            )

    # fix bool string field
    for r in binding_rows:
        r["candidate_available"] = "true" if r["candidate_available"] in {"True", "true"} else "false"

    write_tsv(
        OUT_CONFIG,
        ["battle_slot_id", "slice_type", "whitelist_enabled", "generated_content_enabled", "rollback_policy", "enabled_domains", "reward_plan_id", "notes"],
        config_rows,
    )
    write_tsv(
        OUT_BINDING,
        ["battle_slot_id", "domain", "candidate_available", "candidate_id", "candidate_count", "formal_source", "fallback_policy", "binding_reason", "notes"],
        binding_rows,
    )

    bundle = {
        "package_type": "full_content_generated_slice_bridge",
        "generated_at": now_iso(),
        "rollback_policy": "legacy",
        "global_content_engine_enabled": False,
        "formal_runtime_enabled": False,
        "runtime_ready": False,
        "bridge_only": True,
        "slice_content_enabled": True,
        "whitelist_battle_slots": discovered,
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
                        "candidate_available": slot_bundles[sid][d]["candidate_available"],
                        "candidate_id": slot_bundles[sid][d]["candidate_id"],
                        "candidate_count": slot_bundles[sid][d]["candidate_count"],
                    }
                    for d in domains
                },
            }
            for sid in discovered
        },
    }
    manifest = {
        "package_type": "full_content_generated_slice_bridge_manifest",
        "generated_at": now_iso(),
        "whitelist_battle_slots": discovered,
        "bundle_path": "res://data/runtime/content_engine_whitelist/generated_slice.full_content_bridge.json",
        "bundle_count": 1,
        "rollback_policy": "legacy",
        "global_content_engine_enabled": False,
        "formal_runtime_enabled": False,
        "runtime_ready": False,
        "bridge_only": True,
        "slice_content_enabled": True,
    }
    OUT_BUNDLE.parent.mkdir(parents=True, exist_ok=True)
    OUT_BUNDLE.write_text(json.dumps(bundle, ensure_ascii=False, indent=2), encoding="utf-8")
    OUT_MANIFEST.write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8")

    wuju_count = sum(1 for s in discovered if contains_kw(s))
    accept_rows = [
        {"check_id": "discovered_slot_count", "value": str(len(discovered))},
        {"check_id": "contains_prologue_01", "value": str("prologue_01" in discovered).lower()},
        {"check_id": "discovered_wuju_count", "value": str(wuju_count)},
        {"check_id": "card_pool_count", "value": str(len(card_pool))},
        {"check_id": "operation_node_count", "value": str(len(operation_nodes))},
        {"check_id": "narrative_count", "value": str(len(narrative_nodes))},
        {"check_id": "route_gate_count", "value": str(len(route_gates))},
    ]
    write_tsv(OUT_ACCEPT, ["check_id", "value"], accept_rows)
    print(f"PASS: generated slice whitelist slots={len(discovered)} wuju={wuju_count}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
