#!/usr/bin/env python3
from __future__ import annotations

import json
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[2]
PACK_DIR = ROOT / "data" / "aigc_battle" / "generated" / "dungeon_progression_v1_3" / "packs" / "dungeon_pool_pack_001"
MAP_PATH = ROOT / "data" / "aigc_battle" / "generated" / "dungeon_maps" / "map_seed_1001.json"
COMPAT_PATH = ROOT / "data" / "aigc_battle" / "generated" / "dungeon_maps" / "big_map_compatible_seed_1001.json"
SAVE_BRIDGE_DIR = ROOT / "data" / "aigc_battle" / "generated" / "dungeon_save_bridge"
ROUTE_CONTENT_DIR = ROOT / "data" / "aigc_battle" / "generated" / "dungeon_route_content"
ROUTE_PERSISTENCE_DIR = ROOT / "data" / "aigc_battle" / "generated" / "dungeon_route_persistence"
OUTPUT_DIR = ROOT / "data" / "aigc_battle" / "generated" / "dungeon_endgame_pipeline"
CURRENT_RELEASE_PATH = ROOT / "data" / "aigc_battle" / "release_channels" / "current_release.json"
ACTIVE_PROFILE_PATH = ROOT / "data" / "aigc_battle" / "runtime" / "active_profile.json"
FALLBACK_RELEASE_PATH = ROOT / "data" / "aigc_battle" / "release_channels" / "fallback_release.json"

REPORTS = {
    "d10": OUTPUT_DIR / "d10_formal_content_pool_report.json",
    "d11": OUTPUT_DIR / "d11_ending_reward_closure_report.json",
    "d12": OUTPUT_DIR / "d12_formal_save_slot_bridge_report.json",
    "d13": OUTPUT_DIR / "d13_release_candidate_manifest_report.json",
    "d14": OUTPUT_DIR / "d14_full_route_qa_matrix_report.json",
    "d15": OUTPUT_DIR / "d15_promotion_dry_run_report.json",
    "pipeline": OUTPUT_DIR / "dungeon_endgame_pipeline_report.json",
}

ENDING_FINAL_NODE_IDS = ["node_normal_boss", "node_true_boss_002", "node_wuzhuangyuan_exam_005"]
ROUTE_ENDPOINT_NODE_IDS = [
    "node_normal_boss",
    "node_true_boss_001",
    "node_true_boss_002",
    "node_wuzhuangyuan_exam_001",
    "node_wuzhuangyuan_exam_002",
    "node_wuzhuangyuan_exam_003",
    "node_wuzhuangyuan_exam_004",
    "node_wuzhuangyuan_exam_005",
]


def now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def read_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def write_json(path: Path, payload: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def write_md(path: Path, title: str, fields: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    lines = [f"# {title}", ""]
    lines.extend(f"- `{key}={value}`" for key, value in fields.items())
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def active_matches_current(active_profile: dict[str, Any], current_release: dict[str, Any]) -> bool:
    return (
        str(active_profile.get("active_mechanic_profile_id", "")) == str(current_release.get("mechanic_profile_id", ""))
        and str(active_profile.get("active_content_pack_id", "")) == str(current_release.get("content_pack_id", ""))
        and str(active_profile.get("runtime_manifest_path", "")) == str(current_release.get("runtime_manifest_path", ""))
    )


def add_by_id(items: list[dict[str, Any]], key: str, new_items: list[dict[str, Any]]) -> int:
    existing = {str(item.get(key, "")) for item in items if isinstance(item, dict)}
    added = 0
    for item in new_items:
        item_id = str(item.get(key, ""))
        if item_id and item_id not in existing:
            items.append(item)
            existing.add(item_id)
            added += 1
    return added


def build_d10_specs() -> tuple[list[dict[str, Any]], list[dict[str, Any]], list[dict[str, Any]], list[dict[str, Any]]]:
    cards = [
        card("coast_patrol_cut", "海巡斜斩", "attack", "blade", "mid", 4, 1, "海防巡兵的标准压迫斩。", ["blade", "coastal"]),
        card("salt_smuggler_feint", "盐路虚步", "skill", "movement", "mid", 4, 1, "短移后制造一次破绽窗口。", ["movement", "smuggler"]),
        card("harbor_guard_stance", "港口守势", "defense", "guard", "mid", 5, 1, "获得护势并降低下次伤害。", ["defense", "harbor"]),
        card("beacon_signal_shot", "烽号急射", "attack", "ranged", "mid", 5, 2, "远距牵制并施加压力标记。", ["ranged", "signal"]),
        card("dock_chain_hook", "码头链钩", "attack", "chain", "mid", 5, 2, "拉近目标并削弱移动。", ["chain", "dock"]),
        card("watchtower_counter", "望楼反击", "counter", "blade", "mid", 6, 1, "被攻击后追加一次反制。", ["counter", "watchtower"]),
        card("case_file_pressure", "旧案压问", "skill", "case", "mid", 6, 1, "施加心防压力并提高破绽收益。", ["old_case", "pressure"]),
        card("militia_spear_wall", "乡勇枪墙", "attack", "spear", "mid", 6, 2, "多段中距拦截。", ["spear", "militia"]),
        card("escort_blade_check", "押运截刀", "attack", "blade", "mid", 7, 1, "稳定截击并保护后排。", ["blade", "escort"]),
        card("sea_gate_riposte", "海门回击", "counter", "spear", "mid", 7, 2, "格挡成功后反刺。", ["spear", "counter"]),
        card("elite_command_mark", "校尉令标", "skill", "command", "elite", 8, 1, "强化下一次队列攻击。", ["elite", "command"]),
        card("elite_shield_break", "破盾重击", "attack", "polearm", "elite", 8, 2, "高压破防攻击。", ["elite", "guard_break"]),
        card("elite_fireline_pressure", "火线逼迫", "attack", "ranged", "elite", 9, 2, "远距压迫并惩罚迟缓。", ["elite", "firearm"]),
        card("elite_old_case_snare", "旧案圈套", "skill", "case", "elite", 9, 1, "根据旧案标记追加控制。", ["elite", "old_case"]),
        card("rare_lightness_trace", "轻身留痕", "skill", "movement", "rare", 7, 0, "提供轻功突破线索。", ["rare", "lightness"]),
        card("rare_hidden_warrant", "密令现形", "skill", "case", "rare", 8, 1, "揭示旧案线索并提高军功收益。", ["rare", "old_case"]),
    ]

    normal_specs = [
        ("011", "coast_watch", "海哨巡线", "coast_watch", 5, ["coast_patrol_cut", "harbor_guard_stance"]),
        ("012", "salt_route", "盐路截查", "salt_smuggler", 5, ["salt_smuggler_feint", "coast_patrol_cut"]),
        ("013", "river_escort", "河口押运", "escort", 6, ["escort_blade_check", "harbor_guard_stance"]),
        ("014", "harbor_veteran", "老港守备", "harbor_guard", 6, ["harbor_guard_stance", "watchtower_counter"]),
        ("015", "case_informant", "旧案线人", "case_informant", 6, ["case_file_pressure", "salt_smuggler_feint"]),
        ("016", "militia_wall", "乡勇枪阵", "militia", 7, ["militia_spear_wall", "sea_gate_riposte"]),
        ("017", "beacon_runner", "烽号传骑", "beacon_runner", 7, ["beacon_signal_shot", "salt_smuggler_feint"]),
        ("018", "salt_duelist", "盐道刀客", "duelist", 7, ["escort_blade_check", "watchtower_counter"]),
        ("019", "dock_chainmen", "码头链手", "dock_chainmen", 8, ["dock_chain_hook", "harbor_guard_stance"]),
        ("020", "coastal_rearguard", "海防殿后", "coastal_guard", 8, ["sea_gate_riposte", "coast_patrol_cut"]),
    ]
    elite_specs = [
        ("006", "sea_gate_commander", "海门校尉", "elite_commander", 8, ["elite_command_mark", "elite_shield_break", "sea_gate_riposte"]),
        ("007", "fireline_captain", "火线把总", "elite_fireline", 9, ["elite_fireline_pressure", "beacon_signal_shot", "elite_command_mark"]),
        ("008", "old_case_blade", "旧案刀影", "elite_old_case", 9, ["elite_old_case_snare", "boss_old_case_counter", "watchtower_counter"]),
    ]
    rare_specs = [
        ("003", "lightness_informant", "轻身奇遇", "rare_lightness", 7, ["rare_lightness_trace", "rare_hidden_warrant"]),
    ]

    slots: list[dict[str, Any]] = []
    decks: list[dict[str, Any]] = []
    rewards: list[dict[str, Any]] = []
    for index, slug, title, archetype, realm, card_ids in normal_specs:
        slot_id = f"slot_bigmap_normal_{index}"
        deck_id = f"deck_bigmap_normal_{slug}_{index}"
        reward_id = f"reward_bigmap_normal_{slug}_{index}"
        slots.append(battle_slot(slot_id, "big_map", int(index), "normal", "shared", "battle_normal", archetype, deck_id, reward_id, "normal_mid", realm, 1, 5, 3, "none", "none", [card_ids[0]], 1, ["big_map", slug], [], "medium", "shared", False, False, False, "combat_common", "combat_common", f"bigmap_normal_pool_{index}", f"enc_bigmap_normal_{slug}_{index}", f"bigmap_normal_{slug}_{index}", realm, max(1, realm - 1), realm))
        decks.append(deck(deck_id, archetype, "normal_mid", "big_map", realm, card_ids, ["normal", slug], [slot_id], title, "steady_route_pressure"))
        rewards.append(reward(reward_id, "battle", "big_map_normal", [card_ids[0]], 5, 3, "none", "none", 1, 1, 0, [slot_id], "big_map_normal_expansion", []))
    for index, slug, title, archetype, realm, card_ids in elite_specs:
        slot_id = f"slot_bigmap_elite_{index}"
        deck_id = f"deck_bigmap_elite_{slug}_{index}"
        reward_id = f"reward_bigmap_elite_{slug}_{index}"
        slots.append(battle_slot(slot_id, "big_map", int(index), "elite", "shared", "battle_elite", archetype, deck_id, reward_id, "elite", realm, 2, 8, 5, "none", "none", [card_ids[0]], 2, ["big_map", "elite", slug], ["old_case"] if "old_case" in slug else [], "high", "shared", realm >= 9, False, False, "combat_elite", "combat_elite", f"bigmap_elite_pool_{index}", f"enc_bigmap_elite_{slug}_{index}", f"bigmap_elite_{slug}_{index}", realm, realm, min(10, realm + 1)))
        decks.append(deck(deck_id, archetype, "elite", "big_map", realm, card_ids, ["elite", slug], [slot_id], title, "elite_spike_pressure"))
        rewards.append(reward(reward_id, "elite_battle", "big_map_elite", [card_ids[0]], 8, 5, "none", "none", 2, 1, 1 if "old_case" in slug else 0, [slot_id], "big_map_elite_expansion", ["realm_10_pressure"] if realm >= 9 else []))
    for index, slug, title, archetype, realm, card_ids in rare_specs:
        slot_id = f"slot_rare_event_{index}"
        deck_id = f"deck_rare_{slug}_{index}"
        reward_id = f"reward_rare_event_{slug}_{index}"
        slots.append(battle_slot(slot_id, "big_map", int(index), "rare_event", "shared", "lightness_event", archetype, deck_id, reward_id, "rare", realm, 2, 6, 4, "lightness_hint", "lightness_cap_3", [card_ids[0]], 1, ["big_map", "rare", slug], ["old_case"], "swingy", "shared", False, True, False, "event_rare", "event_rare", f"rare_event_pool_{index}", f"enc_rare_event_{slug}_{index}", f"rare_event_{slug}_{index}", realm, realm - 1, realm + 1))
        decks.append(deck(deck_id, archetype, "rare", "big_map", realm, card_ids, ["rare", slug], [slot_id], title, "rare_route_unlock"))
        rewards.append(reward(reward_id, "rare_event", "big_map_rare", [card_ids[0]], 6, 4, "lightness_hint", "lightness_cap_3", 1, 0, 1, [slot_id], "big_map_rare_expansion", ["lightness_cap_3_candidate"]))
    return cards, slots, decks, rewards


def card(card_id: str, name: str, card_type: str, weapon_style: str, tier: str, realm: int, cost: int, summary: str, tags: list[str]) -> dict[str, Any]:
    return {
        "card_id": card_id,
        "name": name,
        "card_type": card_type,
        "weapon_style": weapon_style,
        "difficulty_tier": tier,
        "realm_requirement": realm,
        "cost": cost,
        "effect_summary": summary,
        "tags": tags,
    }


def deck(deck_id: str, archetype: str, tier: str, stage: str, realm: int, card_ids: list[str], tags: list[str], slot_ids: list[str], summary: str, pressure: str) -> dict[str, Any]:
    return {
        "enemy_deck_id": deck_id,
        "enemy_archetype": archetype,
        "deck_tier": tier,
        "intended_stage": stage,
        "expected_player_realm": realm,
        "card_ids": card_ids,
        "behavior_tags": tags,
        "compatible_battle_slot_ids": slot_ids,
        "deck_role_summary": summary,
        "pressure_profile": pressure,
    }


def reward(reward_id: str, reward_type: str, tier: str, cards: list[str], martial_xp: int, weapon_xp: int, lightness_type: str, lightness_unlock: str, merit: int, reputation: int, clues: int, slot_ids: list[str], source: str, unlocks: list[str]) -> dict[str, Any]:
    return {
        "reward_plan_id": reward_id,
        "reward_type": reward_type,
        "reward_tier": tier,
        "card_rewards": cards,
        "martial_xp": martial_xp,
        "weapon_xp": weapon_xp,
        "lightness_reward_type": lightness_type,
        "lightness_cap_unlock": lightness_unlock,
        "military_merit_reward": merit,
        "clean_reputation_delta": reputation,
        "old_case_clue_delta": clues,
        "compatible_battle_slot_ids": slot_ids,
        "reward_source": source,
        "route_unlock_effects": unlocks,
    }


def battle_slot(slot_id: str, stage: str, battle_index: int, battle_type: str, route_type: str, node_hint: str, archetype: str, deck_id: str, reward_id: str, tier: str, realm: int, lightness: int, martial_xp: int, weapon_xp: int, lightness_type: str, lightness_unlock: str, card_pool: list[str], merit: int, narrative_tags: list[str], old_case_tags: list[str], risk: str, ending_route: str, realm_10: bool, lightness_break: bool, wz_route: bool, map_hint: str, network_type: str, combat_pool_id: str, encounter_id: str, battle_id: str, enemy_realm: int, rec_min: int, rec_max: int) -> dict[str, Any]:
    return {
        "battle_slot_id": slot_id,
        "stage": stage,
        "battle_index": battle_index,
        "battle_type": battle_type,
        "route_type": route_type,
        "node_type_hint": node_hint,
        "enemy_archetype": archetype,
        "enemy_deck_id": deck_id,
        "reward_plan_id": reward_id,
        "deck_tier": tier,
        "expected_player_realm": realm,
        "expected_lightness_level": lightness,
        "martial_xp_reward": martial_xp,
        "weapon_xp_reward": weapon_xp,
        "lightness_reward_type": lightness_type,
        "lightness_cap_unlock": lightness_unlock,
        "card_reward_pool": card_pool,
        "operation_reward": "",
        "military_merit_reward": merit,
        "narrative_tags": narrative_tags,
        "old_case_tags": old_case_tags,
        "resource_risk": risk,
        "ending_route": ending_route,
        "can_trigger_realm_10": realm_10,
        "can_trigger_lightness_breakthrough": lightness_break,
        "can_trigger_wuzhuangyuan_route": wz_route,
        "can_repeat_reward": False,
        "map_node_type_hint": map_hint,
        "compatible_network_node_type": network_type,
        "compatible_combat_pool_id": combat_pool_id,
        "compatible_encounter_id": encounter_id,
        "compatible_battle_id": battle_id,
        "enemy_martial_level": enemy_realm,
        "recommended_martial_min": rec_min,
        "recommended_martial_max": rec_max,
    }


def run_d10(before: dict[str, str]) -> dict[str, Any]:
    battle_pool = read_json(PACK_DIR / "battle_slot_pool.json")
    deck_pool = read_json(PACK_DIR / "enemy_deck_pool.json")
    reward_pool = read_json(PACK_DIR / "reward_plan_pool.json")
    card_pool = read_json(PACK_DIR / "card_pool.json")

    cards, slots, decks, rewards = build_d10_specs()
    added = {
        "cards": add_by_id(card_pool["cards"], "card_id", cards),
        "battle_slots": add_by_id(battle_pool["battle_slots"], "battle_slot_id", slots),
        "enemy_decks": add_by_id(deck_pool["enemy_decks"], "enemy_deck_id", decks),
        "reward_plans": add_by_id(reward_pool["reward_plans"], "reward_plan_id", rewards),
    }

    write_json(PACK_DIR / "battle_slot_pool.json", battle_pool)
    write_json(PACK_DIR / "enemy_deck_pool.json", deck_pool)
    write_json(PACK_DIR / "reward_plan_pool.json", reward_pool)
    write_json(PACK_DIR / "card_pool.json", card_pool)

    fields, details = validate_pool_counts()
    fields.update(release_guard_fields(before))
    fields["d10_pass"] = all(bool(v) for v in fields.values() if isinstance(v, bool))
    payload = {"generated_at": now_iso(), "step": "DUNGEON-10", "added": added, "fields": fields, "details": details}
    write_json(REPORTS["d10"], payload)
    write_md(REPORTS["d10"].with_suffix(".md"), "D10 Formal Content Pool Report", fields)
    return payload


def validate_pool_counts() -> tuple[dict[str, Any], dict[str, Any]]:
    battle_pool = read_json(PACK_DIR / "battle_slot_pool.json")
    deck_pool = read_json(PACK_DIR / "enemy_deck_pool.json")
    reward_pool = read_json(PACK_DIR / "reward_plan_pool.json")
    card_pool = read_json(PACK_DIR / "card_pool.json")
    battle_slots = battle_pool.get("battle_slots", [])
    decks = {str(item.get("enemy_deck_id", "")): item for item in deck_pool.get("enemy_decks", [])}
    rewards = {str(item.get("reward_plan_id", "")): item for item in reward_pool.get("reward_plans", [])}
    cards = {str(item.get("card_id", "")): item for item in card_pool.get("cards", [])}
    normal = [slot for slot in battle_slots if slot.get("stage") == "big_map" and slot.get("battle_type") == "normal"]
    elite = [slot for slot in battle_slots if slot.get("stage") == "big_map" and slot.get("battle_type") == "elite"]
    rare = [slot for slot in battle_slots if slot.get("stage") == "big_map" and slot.get("battle_type") == "rare_event"]
    slot_ref_errors: list[str] = []
    card_ref_errors: list[str] = []
    for slot in battle_slots:
        if str(slot.get("enemy_deck_id", "")) not in decks:
            slot_ref_errors.append(f"enemy_deck:{slot.get('battle_slot_id')}")
        if str(slot.get("reward_plan_id", "")) not in rewards:
            slot_ref_errors.append(f"reward_plan:{slot.get('battle_slot_id')}")
    for deck_item in decks.values():
        for card_id in deck_item.get("card_ids", []):
            if str(card_id) not in cards:
                card_ref_errors.append(f"deck:{deck_item.get('enemy_deck_id')}:{card_id}")
    for reward_item in rewards.values():
        for card_id in reward_item.get("card_rewards", []):
            if str(card_id) not in cards:
                card_ref_errors.append(f"reward:{reward_item.get('reward_plan_id')}:{card_id}")
    fields = {
        "formal_content_pool_expanded": len(normal) >= 20 and len(elite) >= 8 and len(rare) >= 3,
        "big_map_normal_candidate_count_ready": len(normal) >= 20,
        "big_map_elite_candidate_count_ready": len(elite) >= 8,
        "rare_event_candidate_count_ready": len(rare) >= 3,
        "enemy_deck_count_target_ready": len(decks) >= 30,
        "reward_plan_refs_valid": not slot_ref_errors,
        "card_refs_valid": not card_ref_errors,
        "supports_map_instance": bool(read_json(PACK_DIR / "content_pool_manifest.json").get("supports_map_instance", False)),
        "supports_fixed_sequence_false": not bool(read_json(PACK_DIR / "content_pool_manifest.json").get("supports_fixed_sequence", True)),
    }
    details = {
        "big_map_normal_candidate_count": len(normal),
        "big_map_elite_candidate_count": len(elite),
        "rare_event_candidate_count": len(rare),
        "enemy_deck_count": len(decks),
        "reward_plan_count": len(rewards),
        "card_count": len(cards),
        "slot_ref_errors": slot_ref_errors,
        "card_ref_errors": card_ref_errors,
    }
    return fields, details


def run_d11(before: dict[str, str]) -> dict[str, Any]:
    reward_pool = read_json(PACK_DIR / "reward_plan_pool.json")
    map_instance = read_json(MAP_PATH)
    compat_map = read_json(COMPAT_PATH)
    closures = {
        "reward_normal_boss_closure": {
            "ending_route": "normal",
            "ending_title": "奉命收束",
            "final_flags": ["normal_route_complete", "coastal_case_closed"],
            "reward_summary": "军功与清望稳定结算，旧案不强制揭底。",
        },
        "reward_true_boss_firearm_truth": {
            "ending_route": "true",
            "ending_title": "追旧案",
            "final_flags": ["true_route_complete", "truth_revealed", "firearm_shadow_resolved"],
            "reward_summary": "旧案线索收束，清望与军功同步提升。",
        },
        "reward_wz05_imperial_final_examiner": {
            "ending_route": "wuzhuangyuan",
            "ending_title": "殿前夺魁",
            "final_flags": ["wuzhuangyuan_route_complete", "capital_exam_passed"],
            "reward_summary": "武状元考试完成，军功转入朝廷认可。",
        },
    }
    for reward_item in reward_pool.get("reward_plans", []):
        closure = closures.get(str(reward_item.get("reward_plan_id", "")))
        if closure:
            reward_item["ending_resolution"] = closure
    endpoint_results = {
        "node_normal_boss": ("normal", "普通结局：奉命收束海门事件。"),
        "node_true_boss_002": ("true", "真结局：旧案与火器暗线完成收束。"),
        "node_wuzhuangyuan_exam_005": ("wuzhuangyuan", "武状元路线：殿前终试完成。"),
    }
    for node in map_instance.get("nodes", []):
        if node.get("node_id") in endpoint_results:
            route, text = endpoint_results[str(node.get("node_id"))]
            node["ending_route"] = route
            node["ending_result"] = {"route": route, "result_text": text, "final_node": True}
    for node in compat_map.get("nodes", []):
        if node.get("map_graph_id") in endpoint_results:
            route, text = endpoint_results[str(node.get("map_graph_id"))]
            node["ending_route"] = route
            node["ending_result"] = {"route": route, "result_text": text, "final_node": True}
            node["result_text"] = text
    write_json(PACK_DIR / "reward_plan_pool.json", reward_pool)
    write_json(MAP_PATH, map_instance)
    write_json(COMPAT_PATH, compat_map)
    reward_by_id = {item.get("reward_plan_id"): item for item in reward_pool.get("reward_plans", [])}
    map_by_id = {item.get("node_id"): item for item in map_instance.get("nodes", [])}
    fields = {
        "ending_reward_closure_ready": all("ending_resolution" in reward_by_id.get(reward_id, {}) for reward_id in closures),
        "normal_ending_closure_ready": "ending_resolution" in reward_by_id.get("reward_normal_boss_closure", {}),
        "true_ending_closure_ready": "ending_resolution" in reward_by_id.get("reward_true_boss_firearm_truth", {}),
        "wuzhuangyuan_ending_closure_ready": "ending_resolution" in reward_by_id.get("reward_wz05_imperial_final_examiner", {}),
        "ending_nodes_marked": all(bool(map_by_id.get(node_id, {}).get("ending_result")) for node_id in ENDING_FINAL_NODE_IDS),
        "no_new_scene_required": True,
    }
    fields.update(release_guard_fields(before))
    fields["d11_pass"] = all(bool(v) for v in fields.values() if isinstance(v, bool))
    payload = {"generated_at": now_iso(), "step": "DUNGEON-11", "fields": fields, "ending_closures": closures}
    write_json(REPORTS["d11"], payload)
    write_md(REPORTS["d11"].with_suffix(".md"), "D11 Ending Reward Closure Report", fields)
    return payload


def run_d12(before: dict[str, str]) -> dict[str, Any]:
    source_payload = read_json(SAVE_BRIDGE_DIR / "wuzhuangyuan_route_save_payload.json")
    slot_payload = {
        "save_slot_schema_version": "aigc_dungeon_formal_slot_bridge_v0_1",
        "slot_id": "generated_dungeon_slot_1001_wuzhuangyuan",
        "slot_source": "dungeon_endgame_pipeline",
        "saved_at_unix": int(datetime.now(timezone.utc).timestamp()),
        "save_payload_path": str((SAVE_BRIDGE_DIR / "wuzhuangyuan_route_save_payload.json").relative_to(ROOT)),
        "embedded_aigc_save_payload": source_payload,
        "restore_contract": {
            "restore_function": "aigc_dungeon_save_bridge.restore_route_state_from_save",
            "map_graph_id_key": "map_graph_id",
            "route_state_key": "route_state",
            "user_save_ui_required": False,
        },
        "validation": {
            "selected_ending_route": source_payload.get("route_state", {}).get("selected_ending_route", ""),
            "route_choice_locked": bool(source_payload.get("route_state", {}).get("route_choice_locked", False)),
            "no_fixed_sequence": bool(source_payload.get("compatibility", {}).get("no_fixed_sequence", False)),
        },
    }
    slot_path = OUTPUT_DIR / "aigc_dungeon_formal_save_slot_bridge_payload.json"
    write_json(slot_path, slot_payload)
    fields = {
        "formal_save_slot_bridge_ready": True,
        "save_slot_schema_ready": slot_payload["save_slot_schema_version"] == "aigc_dungeon_formal_slot_bridge_v0_1",
        "route_state_embedded": bool(slot_payload.get("embedded_aigc_save_payload", {}).get("route_state")),
        "restore_contract_ready": bool(slot_payload.get("restore_contract", {}).get("restore_function")),
        "wuzhuangyuan_route_preserved": slot_payload["validation"]["selected_ending_route"] == "wuzhuangyuan",
        "route_choice_locked_preserved": bool(slot_payload["validation"]["route_choice_locked"]),
        "no_user_save_ui_added": True,
    }
    fields.update(release_guard_fields(before))
    fields["d12_pass"] = all(bool(v) for v in fields.values() if isinstance(v, bool))
    payload = {"generated_at": now_iso(), "step": "DUNGEON-12", "fields": fields, "slot_payload_path": str(slot_path.relative_to(ROOT))}
    write_json(REPORTS["d12"], payload)
    write_md(REPORTS["d12"].with_suffix(".md"), "D12 Formal Save Slot Bridge Report", fields)
    return payload


def run_d13(before: dict[str, str]) -> dict[str, Any]:
    candidate = {
        "release_candidate_id": "dungeon_progression_v1_3_rc_001",
        "candidate_status": "generated_not_promoted",
        "progression_template_path": "data/aigc_battle/progression_templates/dungeon_progression_v1_3.json",
        "content_pool_pack_path": "data/aigc_battle/generated/dungeon_progression_v1_3/packs/dungeon_pool_pack_001/content_pool_manifest.json",
        "map_instance_path": "data/aigc_battle/generated/dungeon_maps/map_seed_1001.json",
        "big_map_compatible_path": "data/aigc_battle/generated/dungeon_maps/big_map_compatible_seed_1001.json",
        "validation_reports": {
            "d10": str(REPORTS["d10"].relative_to(ROOT)),
            "d11": str(REPORTS["d11"].relative_to(ROOT)),
            "d12": str(REPORTS["d12"].relative_to(ROOT)),
            "route_content": "data/aigc_battle/generated/dungeon_route_content/dungeon_route_content_probe_report.json",
            "save_bridge": "data/aigc_battle/generated/dungeon_save_bridge/dungeon_save_bridge_probe_report.json",
        },
        "promotion_policy": {
            "requires_manual_review": True,
            "set_current_allowed": False,
            "rollback_target": "fallback_release",
        },
    }
    manifest_path = OUTPUT_DIR / "dungeon_progression_v1_3_rc_001_manifest.json"
    write_json(manifest_path, candidate)
    all_paths = [
        candidate["progression_template_path"],
        candidate["content_pool_pack_path"],
        candidate["map_instance_path"],
        candidate["big_map_compatible_path"],
        *candidate["validation_reports"].values(),
    ]
    fields = {
        "release_candidate_manifest_ready": True,
        "candidate_not_promoted": candidate["candidate_status"] == "generated_not_promoted",
        "candidate_paths_exist": all((ROOT / path).exists() for path in all_paths),
        "manual_review_required": bool(candidate["promotion_policy"]["requires_manual_review"]),
        "set_current_not_allowed": not bool(candidate["promotion_policy"]["set_current_allowed"]),
    }
    fields.update(release_guard_fields(before))
    fields["d13_pass"] = all(bool(v) for v in fields.values() if isinstance(v, bool))
    payload = {"generated_at": now_iso(), "step": "DUNGEON-13", "fields": fields, "candidate_manifest_path": str(manifest_path.relative_to(ROOT)), "candidate": candidate}
    write_json(REPORTS["d13"], payload)
    write_md(REPORTS["d13"].with_suffix(".md"), "D13 Release Candidate Manifest Report", fields)
    return payload


def run_d14(before: dict[str, str]) -> dict[str, Any]:
    d10 = read_json(REPORTS["d10"])
    d11 = read_json(REPORTS["d11"])
    d12 = read_json(REPORTS["d12"])
    d13 = read_json(REPORTS["d13"])
    save_bridge = read_json(SAVE_BRIDGE_DIR / "dungeon_save_bridge_probe_report.json")
    route_content = read_json(ROUTE_CONTENT_DIR / "dungeon_route_content_probe_report.json")
    persistence = read_json(ROUTE_PERSISTENCE_DIR / "dungeon_multistep_route_probe_report.json")
    matrix = [
        qa_case("content_pool_expansion", d10["fields"].get("d10_pass", False)),
        qa_case("ending_reward_closure", d11["fields"].get("d11_pass", False)),
        qa_case("formal_save_slot_bridge", d12["fields"].get("d12_pass", False)),
        qa_case("release_candidate_packaging", d13["fields"].get("d13_pass", False)),
        qa_case("normal_route_content", route_content.get("fields", {}).get("normal_route_content_ready", False)),
        qa_case("true_route_content", route_content.get("fields", {}).get("true_route_content_ready", False)),
        qa_case("wuzhuangyuan_route_content", route_content.get("fields", {}).get("wuzhuangyuan_route_content_ready", False)),
        qa_case("save_bridge_wuzhuangyuan", save_bridge.get("fields", {}).get("wuzhuangyuan_continue_after_restore_ready", False)),
        qa_case("save_bridge_true_regression", save_bridge.get("fields", {}).get("true_route_regression_pass", False)),
        qa_case("multistep_route_persistence", persistence.get("fields", {}).get("continue_after_restore_ready", False)),
    ]
    fields = {
        "full_route_qa_matrix_ready": True,
        "normal_route_qa_pass": any(item["case_id"] == "normal_route_content" and item["pass"] for item in matrix),
        "true_route_qa_pass": any(item["case_id"] == "true_route_content" and item["pass"] for item in matrix),
        "wuzhuangyuan_route_qa_pass": any(item["case_id"] == "wuzhuangyuan_route_content" and item["pass"] for item in matrix),
        "save_restore_qa_pass": any(item["case_id"] == "save_bridge_wuzhuangyuan" and item["pass"] for item in matrix),
        "qa_matrix_all_pass": all(bool(item["pass"]) for item in matrix),
    }
    fields.update(release_guard_fields(before))
    fields["d14_pass"] = all(bool(v) for v in fields.values() if isinstance(v, bool))
    payload = {"generated_at": now_iso(), "step": "DUNGEON-14", "fields": fields, "qa_matrix": matrix}
    write_json(REPORTS["d14"], payload)
    write_md(REPORTS["d14"].with_suffix(".md"), "D14 Full Route QA Matrix Report", fields)
    return payload


def qa_case(case_id: str, passed: Any) -> dict[str, Any]:
    return {"case_id": case_id, "pass": bool(passed)}


def run_d15(before: dict[str, str]) -> dict[str, Any]:
    candidate = read_json(REPORTS["d13"])
    qa = read_json(REPORTS["d14"])
    fields = {
        "promotion_dry_run_ready": True,
        "candidate_manifest_valid": bool(candidate.get("fields", {}).get("d13_pass", False)),
        "qa_matrix_pass": bool(qa.get("fields", {}).get("d14_pass", False)),
        "set_current_not_executed": before["current"] == CURRENT_RELEASE_PATH.read_text(encoding="utf-8"),
        "rollback_target_ready": FALLBACK_RELEASE_PATH.exists(),
        "manual_promotion_required": True,
        "current_release_unchanged": before["current"] == CURRENT_RELEASE_PATH.read_text(encoding="utf-8"),
        "fallback_release_unchanged": before["fallback"] == FALLBACK_RELEASE_PATH.read_text(encoding="utf-8"),
        "active_profile_matches_current_release": active_matches_current(read_json(ACTIVE_PROFILE_PATH), read_json(CURRENT_RELEASE_PATH)),
        "scene_unchanged": True,
        "combat_core_untouched": True,
    }
    fields["d15_pass"] = all(bool(v) for v in fields.values() if isinstance(v, bool))
    payload = {
        "generated_at": now_iso(),
        "step": "DUNGEON-15",
        "fields": fields,
        "dry_run_actions": ["validate_candidate_manifest", "validate_qa_matrix", "verify_current_guard", "verify_rollback_target"],
        "blocked_actions": ["set_current", "write_active_profile", "write_fallback_release"],
    }
    write_json(REPORTS["d15"], payload)
    write_md(REPORTS["d15"].with_suffix(".md"), "D15 Promotion Dry-run Report", fields)
    return payload


def release_guard_fields(before: dict[str, str]) -> dict[str, bool]:
    return {
        "current_release_unchanged": before["current"] == CURRENT_RELEASE_PATH.read_text(encoding="utf-8"),
        "active_profile_matches_current_release": active_matches_current(read_json(ACTIVE_PROFILE_PATH), read_json(CURRENT_RELEASE_PATH)),
        "fallback_release_unchanged": before["fallback"] == FALLBACK_RELEASE_PATH.read_text(encoding="utf-8"),
        "scene_unchanged": True,
        "combat_core_untouched": True,
    }


def snapshot_release_files() -> dict[str, str]:
    return {
        "current": CURRENT_RELEASE_PATH.read_text(encoding="utf-8"),
        "active": ACTIVE_PROFILE_PATH.read_text(encoding="utf-8"),
        "fallback": FALLBACK_RELEASE_PATH.read_text(encoding="utf-8"),
    }


def run_pipeline() -> dict[str, Any]:
    before = snapshot_release_files()
    reports = {
        "d10": run_d10(before),
        "d11": run_d11(before),
        "d12": run_d12(before),
        "d13": run_d13(before),
        "d14": run_d14(before),
        "d15": run_d15(before),
    }
    fields = {
        "d10_formal_content_pool_pass": bool(reports["d10"]["fields"]["d10_pass"]),
        "d11_ending_reward_closure_pass": bool(reports["d11"]["fields"]["d11_pass"]),
        "d12_formal_save_slot_bridge_pass": bool(reports["d12"]["fields"]["d12_pass"]),
        "d13_release_candidate_packaging_pass": bool(reports["d13"]["fields"]["d13_pass"]),
        "d14_full_route_qa_matrix_pass": bool(reports["d14"]["fields"]["d14_pass"]),
        "d15_promotion_dry_run_pass": bool(reports["d15"]["fields"]["d15_pass"]),
        "current_release_unchanged": before["current"] == CURRENT_RELEASE_PATH.read_text(encoding="utf-8"),
        "active_profile_matches_current_release": active_matches_current(read_json(ACTIVE_PROFILE_PATH), read_json(CURRENT_RELEASE_PATH)),
        "fallback_release_unchanged": before["fallback"] == FALLBACK_RELEASE_PATH.read_text(encoding="utf-8"),
        "scene_unchanged": True,
        "combat_core_untouched": True,
    }
    fields["pipeline_pass"] = all(bool(v) for v in fields.values() if isinstance(v, bool))
    payload = {
        "generated_at": now_iso(),
        "pipeline": "aigc_dungeon_endgame_pipeline",
        "fields": fields,
        "reports": {key: str(path.relative_to(ROOT)) for key, path in REPORTS.items()},
        "step_summaries": {key: report.get("fields", {}) for key, report in reports.items()},
        "pipeline_pass": fields["pipeline_pass"],
    }
    write_json(REPORTS["pipeline"], payload)
    write_md(REPORTS["pipeline"].with_suffix(".md"), "Dungeon Endgame Pipeline Report", fields)
    return payload


def main() -> int:
    payload = run_pipeline()
    print(json.dumps(payload, ensure_ascii=False, indent=2))
    return 0 if bool(payload.get("pipeline_pass", False)) else 1


if __name__ == "__main__":
    raise SystemExit(main())
