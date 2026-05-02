#!/usr/bin/env python3
from __future__ import annotations

import csv
import json
import re
import sys
import xml.etree.ElementTree as ET
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
TABLES_DIR = ROOT / "tables"
DATA_DIR = ROOT / "data"

CARD_EFFECT_FIELDS = [
    "amount",
    "target",
    "flag",
    "if_preferred",
    "damage",
    "momentum_damage",
    "range_bonus",
    "range_penalty",
    "bonus_damage_if_momentum_missing",
    "bonus_damage_if_collapsed",
    "refund_if_collapsed",
    "cost_zero_if_collapsed",
    "force_crit_if_collapsed",
    "override_damage_if_collapsed",
]

ENEMY_INTENT_FIELDS = [
    "move_to",
    "move_delta",
    "damage",
    "momentum_damage",
    "guard",
    "range_bonus",
    "tags",
]

INT_FIELDS = {
    "cost",
    "amount",
    "target",
    "damage",
    "momentum_damage",
    "range_penalty",
    "bonus_damage_if_momentum_missing",
    "bonus_damage_if_collapsed",
    "refund_if_collapsed",
    "override_damage_if_collapsed",
    "move_to",
    "move_delta",
    "guard",
    "max_hp",
    "max_momentum",
    "start_distance",
    "order",
}

LIST_FIELDS = {
    "preferred_ranges",
    "deck",
    "required_fields",
    "range_bonus",
    "tags",
}

BOOL_FIELDS = {
    "if_preferred",
    "cost_zero_if_collapsed",
    "force_crit_if_collapsed",
}

NARRATIVE_ALLOWED_EFFECT_FIELDS = {
    "military_merit",
    "clean_reputation",
    "case_clues",
    "jun_gong",
    "qing_wang",
    "clues",
    "heal",
    "ending_flag",
    "next_normal_battle_easier",
    "elite_chance",
}

STRATEGIC_MAP_NODE_TYPES = {
    "combat_common",
    "combat_elite",
    "military",
    "case",
    "reputation",
    "rest",
    "risk",
}

STRATEGIC_MAP_EFFECT_FIELDS = {
    "military_merit",
    "clean_reputation",
    "case_clues",
    "card_rewards",
}

NARRATIVE_REQUIRED_STATUS_FIELDS = ["flow_order", "column", "type", "visual_path"]


def main() -> int:
    try:
        classes = build_classes()
        cards = build_cards()
        effects = build_effect_types()
        enemies = build_enemies()
        routes = build_routes()
        rewards = build_rewards()
        battle_scene_manifest = build_battle_scene_manifest()
        enemy_manifest = build_enemy_manifest()
        story_battles = build_story_battles()
        strategic_map = build_strategic_map(story_battles, battle_scene_manifest)
        narrative_mvp_nodes = build_narrative_mvp_nodes()
        performance_tracks = build_performance_tracks()
        raw_documents = build_raw_json_documents()
        validate_narrative_visual_assets(narrative_mvp_nodes)
        validate_performance_track_assets(performance_tracks)

        DATA_DIR.mkdir(parents=True, exist_ok=True)
        write_json(DATA_DIR / "classes.json", classes)
        write_json(DATA_DIR / "cards.json", cards)
        write_json(DATA_DIR / "effects.json", effects)
        write_json(DATA_DIR / "enemies.json", enemies)
        write_json(DATA_DIR / "routes.json", routes)
        write_json(DATA_DIR / "rewards.json", rewards)
        write_json(DATA_DIR / "battle_scene_manifest.json", battle_scene_manifest)
        write_json(DATA_DIR / "enemy_manifest.json", enemy_manifest)
        write_json(DATA_DIR / "story_battles.json", story_battles)
        write_json(DATA_DIR / "strategic_map.json", strategic_map)
        write_json(DATA_DIR / "narrative_mvp_nodes.json", narrative_mvp_nodes)
        write_json(DATA_DIR / "performance_tracks.json", performance_tracks)
        for relative_path, payload in raw_documents.items():
            write_json(ROOT / relative_path, payload)
    except Exception as exc:
        print(f"Compile failed: {exc}", file=sys.stderr)
        return 1

    print("Compiled table sources into data/*.json")
    return 0


def build_classes() -> dict[str, Any]:
    classes: dict[str, Any] = {}
    for row in read_table("classes"):
        class_id = required(row, "id", "classes")
        classes[class_id] = {
            "id": class_id,
            "name": required(row, "name", f"class {class_id}"),
            "weapon": required(row, "weapon", f"class {class_id}"),
            "preferred_ranges": parse_int_list(required(row, "preferred_ranges", f"class {class_id}")),
            "passive": required(row, "passive", f"class {class_id}"),
            "deck": parse_str_list(required(row, "deck", f"class {class_id}")),
        }
    return classes


def build_cards() -> dict[str, Any]:
    effects_by_card: dict[str, list[dict[str, Any]]] = {}
    effect_rows = sorted(read_table("card_effects"), key=lambda row: int(required(row, "order", "card_effects")))
    for row in effect_rows:
        card_id = required(row, "card_id", "card_effects")
        effect: dict[str, Any] = {"type": required(row, "type", f"card effect {card_id}")}
        for field in CARD_EFFECT_FIELDS:
            parsed = parse_optional_value(field, row.get(field, ""))
            if parsed is not None:
                effect[field] = parsed
        effects_by_card.setdefault(card_id, []).append(effect)

    cards: dict[str, Any] = {}
    for row in read_table("cards"):
        card_id = required(row, "id", "cards")
        cards[card_id] = {
            "name": required(row, "name", f"card {card_id}"),
            "category": required(row, "category", f"card {card_id}"),
            "cost": int(required(row, "cost", f"card {card_id}")),
            "text": required(row, "text", f"card {card_id}"),
            "effects": effects_by_card.get(card_id, []),
        }
    return cards


def build_effect_types() -> dict[str, Any]:
    effect_types: dict[str, Any] = {}
    for row in read_table("effect_types"):
        effect_type = required(row, "type", "effect_types")
        effect_types[effect_type] = {
            "handler": required(row, "handler", f"effect type {effect_type}"),
            "required_fields": parse_str_list(row.get("required_fields", "")),
            "description": row.get("description", "").strip(),
        }
    return effect_types


def build_enemies() -> list[dict[str, Any]]:
    intents_by_enemy: dict[str, list[dict[str, Any]]] = {}
    intent_rows = sorted(read_table("enemy_intents"), key=lambda row: int(required(row, "order", "enemy_intents")))
    for row in intent_rows:
        enemy_id = required(row, "enemy_id", "enemy_intents")
        intent: dict[str, Any] = {
            "name": required(row, "name", f"enemy intent {enemy_id}"),
            "cost": int(required(row, "cost", f"enemy intent {enemy_id}")),
        }
        for field in ENEMY_INTENT_FIELDS:
            parsed = parse_optional_value(field, row.get(field, ""))
            if parsed is not None:
                intent[field] = parsed
        intents_by_enemy.setdefault(enemy_id, []).append(intent)

    enemies: list[dict[str, Any]] = []
    for row in read_table("enemies"):
        enemy_id = required(row, "id", "enemies")
        enemies.append(
            {
                "id": enemy_id,
                "name": required(row, "name", f"enemy {enemy_id}"),
                "title": required(row, "title", f"enemy {enemy_id}"),
                "max_hp": int(required(row, "max_hp", f"enemy {enemy_id}")),
                "max_momentum": int(required(row, "max_momentum", f"enemy {enemy_id}")),
                "start_distance": int(required(row, "start_distance", f"enemy {enemy_id}")),
                "preferred_ranges": parse_int_list(required(row, "preferred_ranges", f"enemy {enemy_id}")),
                "passive": required(row, "passive", f"enemy {enemy_id}"),
                "intents": intents_by_enemy.get(enemy_id, []),
            }
        )
    return enemies


def build_routes() -> dict[str, Any]:
    routes: dict[str, Any] = {}
    for row in read_table("routes"):
        route_id = required(row, "id", "routes")
        route: dict[str, Any] = {
            "title": required(row, "title", f"route {route_id}"),
            "kind": required(row, "kind", f"route {route_id}"),
            "next": parse_str_list(row.get("next", "")),
        }
        for field in ["enemy_id", "heal", "map_length", "initial_distance"]:
            value = row.get(field, "").strip()
            if value == "":
                continue
            route[field] = int(value) if field != "enemy_id" else value
        routes[route_id] = route
    return routes


def build_rewards() -> list[str]:
    return [required(row, "card_id", "rewards") for row in read_table("rewards")]


def build_battle_scene_manifest() -> dict[str, Any]:
    manifest: dict[str, Any] = {}
    float_fields = ["mist", "dim", "accent", "camera_zoom", "camera_pan_x", "camera_pan_y"]
    for row in read_table("battle_scene_manifest"):
        scene_id = required(row, "id", "battle_scene_manifest")
        scene: dict[str, Any] = {
            "background": required(row, "background", f"battle scene {scene_id}"),
            "label": required(row, "label", f"battle scene {scene_id}"),
        }
        for field in float_fields:
            value = row.get(field, "").strip()
            if value != "":
                scene[field] = float(value)
        manifest[scene_id] = scene
    return manifest


def build_enemy_manifest() -> dict[str, Any]:
    meta = {required(row, "key", "enemy_manifest_meta"): parse_json_or_string(row.get("value", "")) for row in read_table("enemy_manifest_meta")}

    encounters: dict[str, Any] = {}
    for row in read_table("enemy_manifest_encounters"):
        encounter_id = required(row, "encounter_id", "enemy_manifest_encounters")
        encounters[encounter_id] = {
            "battle_id": required(row, "battle_id", f"encounter {encounter_id}"),
            "enemy_id": required(row, "enemy_id", f"encounter {encounter_id}"),
            "player_role": required(row, "player_role", f"encounter {encounter_id}"),
            "enemy_role": required(row, "enemy_role", f"encounter {encounter_id}"),
            "enemy_family": required(row, "enemy_family", f"encounter {encounter_id}"),
            "difficulty": required(row, "difficulty", f"encounter {encounter_id}"),
            "label": required(row, "label", f"encounter {encounter_id}"),
        }

    weights_by_enemy: dict[str, dict[str, float]] = {}
    for row in read_table("enemy_manifest_intent_weights"):
        enemy_id = required(row, "enemy_id", "enemy_manifest_intent_weights")
        weights_by_enemy[enemy_id] = {field: float(row[field]) for field in ["gain_posture", "attack", "guard", "break_posture", "feint"] if row.get(field, "").strip() != ""}

    phases_by_enemy: dict[str, list[dict[str, Any]]] = {}
    phase_rows = sorted(read_table("enemy_manifest_phase_behaviors"), key=lambda row: (required(row, "enemy_id", "enemy_manifest_phase_behaviors"), int(required(row, "order", "enemy_manifest_phase_behaviors"))))
    for row in phase_rows:
        enemy_id = required(row, "enemy_id", "enemy_manifest_phase_behaviors")
        phases_by_enemy.setdefault(enemy_id, []).append(
            {
                "phase": required(row, "phase", f"phase behavior {enemy_id}"),
                "hp_below": float(required(row, "hp_below", f"phase behavior {enemy_id}")),
                "intent_bias": required(row, "intent_bias", f"phase behavior {enemy_id}"),
                "note": row.get("note", "").strip(),
            }
        )

    deck_by_enemy: dict[str, list[dict[str, Any]]] = {}
    deck_rows = sorted(read_table("enemy_manifest_deck"), key=lambda row: (required(row, "enemy_id", "enemy_manifest_deck"), int(required(row, "order", "enemy_manifest_deck"))))
    for row in deck_rows:
        enemy_id = required(row, "enemy_id", "enemy_manifest_deck")
        deck_by_enemy.setdefault(enemy_id, []).append(
            {
                "id": required(row, "id", f"enemy deck {enemy_id}"),
                "name": required(row, "name", f"enemy deck {enemy_id}"),
                "min": int(required(row, "min", f"enemy deck {enemy_id}")),
                "max": int(required(row, "max", f"enemy deck {enemy_id}")),
                "cost": int(required(row, "cost", f"enemy deck {enemy_id}")),
                "role": required(row, "role", f"enemy deck {enemy_id}"),
                "gain": int(required(row, "gain", f"enemy deck {enemy_id}")),
                "break": int(required(row, "break", f"enemy deck {enemy_id}")),
                "damage": int(required(row, "damage", f"enemy deck {enemy_id}")),
                "guard": int(required(row, "guard", f"enemy deck {enemy_id}")),
                "tags": parse_str_list(row.get("tags", "")),
                "style": row.get("style", "").strip(),
                "facing": parse_bool(required(row, "facing", f"enemy deck {enemy_id}")),
            }
        )

    enemies: dict[str, Any] = {}
    for row in read_table("enemy_manifest_enemies"):
        enemy_id = required(row, "enemy_id", "enemy_manifest_enemies")
        enemies[enemy_id] = {
            "enemy_id": enemy_id,
            "display_name": required(row, "display_name", f"enemy {enemy_id}"),
            "narrative_identity": required(row, "narrative_identity", f"enemy {enemy_id}"),
            "weapon": required(row, "weapon", f"enemy {enemy_id}"),
            "role_sheet": required(row, "role_sheet", f"enemy {enemy_id}"),
            "max_hp": int(required(row, "max_hp", f"enemy {enemy_id}")),
            "max_posture": int(required(row, "max_posture", f"enemy {enemy_id}")),
            "start_posture": int(required(row, "start_posture", f"enemy {enemy_id}")),
            "realm": int(row.get("realm", "").strip() or 1),
            "qinggong": max(1, int(row.get("qinggong", "").strip() or 1)),
            "intent_style": required(row, "intent_style", f"enemy {enemy_id}"),
            "behavior_tags": parse_str_list(row.get("behavior_tags", "")),
            "preferred_intents": parse_str_list(row.get("preferred_intents", "")),
            "intent_weights": weights_by_enemy.get(enemy_id, {}),
            "phase_behaviors": phases_by_enemy.get(enemy_id, []),
            "deck": deck_by_enemy.get(enemy_id, []),
            "ai_note": row.get("ai_note", "").strip(),
            "reward": {
                "jun_gong": int(required(row, "reward_jun_gong", f"enemy {enemy_id}")),
                "qing_wang": int(required(row, "reward_qing_wang", f"enemy {enemy_id}")),
                "clues": int(required(row, "reward_clues", f"enemy {enemy_id}")),
            },
        }
    return {"meta": meta, "encounters": encounters, "enemies": enemies}


STORY_BATTLE_TABLES = {
    "fighter_templates": ("fighter_template_id", DATA_DIR / "story_battles" / "fighter_templates.tsv"),
    "story_deck_sets": ("story_deck_id", DATA_DIR / "story_battles" / "story_deck_sets.tsv"),
    "fighter_stat_sets": ("stat_set_id", DATA_DIR / "story_battles" / "fighter_stat_sets.tsv"),
    "story_encounters": ("encounter_id", DATA_DIR / "story_battles" / "story_encounters.tsv"),
}

STORY_BATTLE_INT_FIELDS = ["max_hp", "max_momentum", "starting_momentum", "starting_realm", "qinggong"]
STORY_BATTLE_SETTLEMENT_MODES = {"symmetric", "reactive"}
STORY_BATTLE_PRESSURE_PROFILES = {"none", "edge_pressure", "break_resist"}


def build_story_battles() -> dict[str, Any]:
    tables, indexes, validation = compile_story_battle_tables()
    return {
        "schema_version": 1,
        "tables": tables,
        "indexes": indexes,
        "validation": validation,
    }


def compile_story_battle_tables() -> tuple[dict[str, Any], dict[str, Any], dict[str, Any]]:
    source_dir = DATA_DIR / "story_battles"
    tables: dict[str, Any] = {}
    indexes: dict[str, Any] = {}
    errors: list[str] = []
    warnings: list[str] = []

    for name, (id_field, path) in STORY_BATTLE_TABLES.items():
        if not str(path).startswith(str(source_dir)):
            raise ValueError(f"story battle table path escaped source dir: {path}")
        if not path.exists():
            raise FileNotFoundError(f"Missing story battle source table: {path.relative_to(ROOT)}")
        rows = read_delimited(path, "\t")
        tables[name] = rows
        indexes[f"{name}_by_id"] = index_story_battle_rows(rows, id_field, name, errors)

    template_ids = indexes["fighter_templates_by_id"]
    deck_ids = indexes["story_deck_sets_by_id"]
    stat_ids = indexes["fighter_stat_sets_by_id"]
    encounter_ids = indexes["story_encounters_by_id"]

    for deck_id, deck_row in deck_ids.items():
        template_id = str(deck_row.get("fighter_template_id", ""))
        validate_story_ref(errors, f"story_deck_sets.{deck_id}.fighter_template_id", template_ids, template_id)

    for stat_id, stat_row in stat_ids.items():
        for field in STORY_BATTLE_INT_FIELDS:
            value = str(stat_row.get(field, ""))
            if not value.isdigit():
                errors.append(f"fighter_stat_sets.{stat_id} has non-int field {field}={value}")

    for encounter_id, encounter in encounter_ids.items():
        validate_story_ref(errors, f"story_encounters.{encounter_id}.player_template_id", template_ids, str(encounter.get("player_template_id", "")))
        validate_story_ref(errors, f"story_encounters.{encounter_id}.opponent_template_id", template_ids, str(encounter.get("opponent_template_id", "")))
        validate_story_ref(errors, f"story_encounters.{encounter_id}.player_deck_id", deck_ids, str(encounter.get("player_deck_id", "")))
        validate_story_ref(errors, f"story_encounters.{encounter_id}.opponent_deck_id", deck_ids, str(encounter.get("opponent_deck_id", "")))
        validate_story_ref(errors, f"story_encounters.{encounter_id}.player_stat_set_id", stat_ids, str(encounter.get("player_stat_set_id", "")))
        validate_story_ref(errors, f"story_encounters.{encounter_id}.opponent_stat_set_id", stat_ids, str(encounter.get("opponent_stat_set_id", "")))

        settlement_mode = str(encounter.get("settlement_mode", "reactive"))
        if settlement_mode not in STORY_BATTLE_SETTLEMENT_MODES:
            errors.append(f"story_encounters.{encounter_id} has invalid settlement_mode: {settlement_mode}")
        pressure_profile = str(encounter.get("pressure_profile", "none"))
        if pressure_profile not in STORY_BATTLE_PRESSURE_PROFILES:
            errors.append(f"story_encounters.{encounter_id} has invalid pressure_profile: {pressure_profile}")

        player_deck = deck_ids.get(str(encounter.get("player_deck_id", "")), {})
        opponent_deck = deck_ids.get(str(encounter.get("opponent_deck_id", "")), {})
        if player_deck and str(player_deck.get("fighter_template_id", "")) != str(encounter.get("player_template_id", "")):
            warnings.append(f"story_encounters.{encounter_id} player_deck_id template differs from player_template_id")
        if opponent_deck and str(opponent_deck.get("fighter_template_id", "")) != str(encounter.get("opponent_template_id", "")):
            warnings.append(f"story_encounters.{encounter_id} opponent_deck_id template differs from opponent_template_id")

    if errors:
        joined = "\n  - ".join(errors)
        raise ValueError(f"Story battle validation failed:\n  - {joined}")

    validation = {
        "ok": True,
        "errors": [],
        "warnings": warnings,
        "counts": {
            "templates": len(template_ids),
            "decks": len(deck_ids),
            "stats": len(stat_ids),
            "encounters": len(encounter_ids),
        },
    }
    return tables, indexes, validation


def index_story_battle_rows(rows: list[dict[str, str]], id_field: str, table_name: str, errors: list[str]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for row in rows:
        row_id = row.get(id_field, "").strip()
        if row_id == "":
            errors.append(f"{table_name} row missing id field: {id_field}")
            continue
        if row_id in result:
            errors.append(f"{table_name} duplicate {id_field}: {row_id}")
            continue
        result[row_id] = row
    return result


def validate_story_ref(errors: list[str], label: str, index: dict[str, Any], value: str) -> None:
    if value == "":
        errors.append(f"{label} is empty")
        return
    if value not in index:
        errors.append(f"{label} references missing id: {value}")


def build_strategic_map(story_battles: dict[str, Any], battle_scene_manifest: dict[str, Any]) -> dict[str, Any]:
    encounter_index = story_battles.get("indexes", {}).get("story_encounters_by_id", {})
    if not isinstance(encounter_index, dict):
        encounter_index = {}
    template_index = story_battles.get("indexes", {}).get("fighter_templates_by_id", {})
    if not isinstance(template_index, dict):
        template_index = {}
    deck_index = story_battles.get("indexes", {}).get("story_deck_sets_by_id", {})
    if not isinstance(deck_index, dict):
        deck_index = {}
    node_pool = build_strategic_map_node_pool(encounter_index, battle_scene_manifest)
    generation_rules = build_strategic_map_generation_rules()
    final_boss_rules = build_strategic_map_final_boss_rules(encounter_index, battle_scene_manifest)
    enemy_martial_stats = build_enemy_martial_stats()
    combat_enemy_pools = build_combat_enemy_pools(template_index, deck_index)
    combat_balance_targets = build_combat_balance_targets(combat_enemy_pools)
    validate_strategic_map_generation(node_pool, generation_rules)
    validate_combat_enemy_pool_coverage(node_pool, enemy_martial_stats, combat_enemy_pools)
    return {
        "schema_version": 1,
        "node_types": sorted(STRATEGIC_MAP_NODE_TYPES),
        "node_pool": node_pool,
        "generation_rules": generation_rules,
        "final_boss_rules": final_boss_rules,
        "enemy_martial_stats": enemy_martial_stats,
        "combat_enemy_pools": combat_enemy_pools,
        "combat_balance_targets": combat_balance_targets,
    }


def build_strategic_map_node_pool(encounter_index: dict[str, Any], battle_scene_manifest: dict[str, Any]) -> list[dict[str, Any]]:
    rows = read_table("map_node_pool")
    result: list[dict[str, Any]] = []
    seen: set[str] = set()
    errors: list[str] = []
    for row in rows:
        node_id = required(row, "node_id", "map_node_pool")
        if node_id in seen:
            errors.append(f"map_node_pool duplicate node_id: {node_id}")
            continue
        seen.add(node_id)
        node_type = required(row, "node_type", f"map node {node_id}")
        if node_type not in STRATEGIC_MAP_NODE_TYPES:
            errors.append(f"map node {node_id} has invalid node_type: {node_type}")
        effects = parse_json_field(row.get("effects_json", "{}") or "{}")
        if not isinstance(effects, dict):
            errors.append(f"map node {node_id}.effects_json must be an object")
            effects = {}
        for key in effects.keys():
            if str(key) not in STRATEGIC_MAP_EFFECT_FIELDS:
                errors.append(f"map node {node_id}.effects_json has unsupported effect: {key}")
        weight = int(required(row, "weight", f"map node {node_id}"))
        max_per_run = int(required(row, "max_per_run", f"map node {node_id}"))
        if weight <= 0:
            errors.append(f"map node {node_id}.weight must be > 0")
        if max_per_run < 1:
            errors.append(f"map node {node_id}.max_per_run must be >= 1")
        encounter_id = row.get("encounter_id", "").strip()
        battle_id = row.get("battle_id", "").strip()
        combat_pool_id = row.get("combat_pool_id", "").strip()
        recommended_martial_min = int(row.get("recommended_martial_min", "0") or 0)
        recommended_martial_max = int(row.get("recommended_martial_max", "0") or 0)
        enemy_martial_level = int(row.get("enemy_martial_level", "0") or 0)
        if node_type in {"combat_common", "combat_elite"}:
            validate_story_ref(errors, f"map node {node_id}.encounter_id", encounter_index, encounter_id)
            validate_story_ref(errors, f"map node {node_id}.battle_id", battle_scene_manifest, battle_id)
            if combat_pool_id == "":
                errors.append(f"map node {node_id}.combat_pool_id is required for combat nodes")
            if recommended_martial_min < 1:
                errors.append(f"map node {node_id}.recommended_martial_min must be >= 1")
            if recommended_martial_max < recommended_martial_min:
                errors.append(f"map node {node_id}.recommended_martial_max must be >= recommended_martial_min")
            if enemy_martial_level < 1:
                errors.append(f"map node {node_id}.enemy_martial_level must be >= 1")
        elif encounter_id != "" or battle_id != "":
            if encounter_id != "":
                validate_story_ref(errors, f"map node {node_id}.encounter_id", encounter_index, encounter_id)
            if battle_id != "":
                validate_story_ref(errors, f"map node {node_id}.battle_id", battle_scene_manifest, battle_id)
        visual_path = row.get("visual_path", "").strip()
        validate_runtime_asset_path(visual_path, f"map node {node_id}.visual_path")
        result.append({
            "node_id": node_id,
            "title": required(row, "title", f"map node {node_id}"),
            "node_type": node_type,
            "region_min": int(required(row, "region_min", f"map node {node_id}")),
            "region_max": int(required(row, "region_max", f"map node {node_id}")),
            "primary_line": row.get("primary_line", "").strip(),
            "secondary_line": row.get("secondary_line", "").strip(),
            "min_military_merit": int(row.get("min_military_merit", "0") or 0),
            "max_military_merit": int(row["max_military_merit"]) if row.get("max_military_merit", "").strip() != "" else -1,
            "min_case_clues": int(row.get("min_case_clues", "0") or 0),
            "min_clean_reputation": int(row.get("min_clean_reputation", "0") or 0),
            "max_clean_reputation": int(row["max_clean_reputation"]) if row.get("max_clean_reputation", "").strip() != "" else -1,
            "min_martial_level": int(row.get("min_martial_level", "1") or 1),
            "weight": weight,
            "max_per_run": max_per_run,
            "can_repeat": parse_bool(row.get("can_repeat", "false")),
            "unique_group": row.get("unique_group", "").strip(),
            "encounter_id": encounter_id,
            "battle_id": battle_id,
            "combat_pool_id": combat_pool_id,
            "recommended_martial_min": recommended_martial_min,
            "recommended_martial_max": recommended_martial_max,
            "enemy_martial_level": enemy_martial_level,
            "visual_path": visual_path,
            "preview_text": row.get("preview_text", "").strip(),
            "result_text": row.get("result_text", "").strip(),
            "effects": effects,
            "tags": parse_str_list(row.get("tags", "")),
        })
    if errors:
        joined = "\n  - ".join(errors)
        raise ValueError(f"Strategic map node validation failed:\n  - {joined}")
    return result


def build_strategic_map_generation_rules() -> list[dict[str, Any]]:
    result: list[dict[str, Any]] = []
    seen: set[str] = set()
    errors: list[str] = []
    for row in read_table("map_generation_rules"):
        region_id = required(row, "region_id", "map_generation_rules")
        if region_id in seen:
            errors.append(f"map_generation_rules duplicate region_id: {region_id}")
            continue
        seen.add(region_id)
        layer_count = int(required(row, "layer_count", f"map generation {region_id}"))
        choices_per_layer = int(required(row, "choices_per_layer", f"map generation {region_id}"))
        if layer_count < 1:
            errors.append(f"map generation {region_id}.layer_count must be >= 1")
        if choices_per_layer < 2:
            errors.append(f"map generation {region_id}.choices_per_layer must be >= 2")
        result.append({
            "region_id": region_id,
            "region_title": required(row, "region_title", f"map generation {region_id}"),
            "layer_count": layer_count,
            "choices_per_layer": choices_per_layer,
            "common_combat_min": int(row.get("common_combat_min", "0") or 0),
            "elite_combat_min": int(row.get("elite_combat_min", "0") or 0),
            "military_min": int(row.get("military_min", "0") or 0),
            "case_min": int(row.get("case_min", "0") or 0),
            "reputation_min": int(row.get("reputation_min", "0") or 0),
            "rest_max": int(row.get("rest_max", "0") or 0),
            "mandatory_tags": parse_str_list(row.get("mandatory_tags", "")),
            "forbidden_repeat_tags": parse_str_list(row.get("forbidden_repeat_tags", "")),
        })
    if errors:
        joined = "\n  - ".join(errors)
        raise ValueError(f"Strategic map generation validation failed:\n  - {joined}")
    return result


def build_strategic_map_final_boss_rules(encounter_index: dict[str, Any], battle_scene_manifest: dict[str, Any]) -> list[dict[str, Any]]:
    result: list[dict[str, Any]] = []
    seen: set[str] = set()
    errors: list[str] = []
    for row in read_table("final_boss_rules"):
        boss_variant_id = required(row, "boss_variant_id", "final_boss_rules")
        if boss_variant_id in seen:
            errors.append(f"final_boss_rules duplicate boss_variant_id: {boss_variant_id}")
            continue
        seen.add(boss_variant_id)
        encounter_id = required(row, "encounter_id", f"final boss {boss_variant_id}")
        battle_id = required(row, "battle_id", f"final boss {boss_variant_id}")
        validate_story_ref(errors, f"final boss {boss_variant_id}.encounter_id", encounter_index, encounter_id)
        validate_story_ref(errors, f"final boss {boss_variant_id}.battle_id", battle_scene_manifest, battle_id)
        modifiers = parse_json_field(row.get("battle_modifiers_json", "{}") or "{}")
        if not isinstance(modifiers, dict):
            errors.append(f"final boss {boss_variant_id}.battle_modifiers_json must be an object")
            modifiers = {}
        result.append({
            "boss_variant_id": boss_variant_id,
            "title": required(row, "title", f"final boss {boss_variant_id}"),
            "priority": int(required(row, "priority", f"final boss {boss_variant_id}")),
            "required_case_clues": int(row.get("required_case_clues", "0") or 0),
            "required_military_merit": int(row.get("required_military_merit", "0") or 0),
            "required_clean_reputation": int(row.get("required_clean_reputation", "0") or 0),
            "required_martial_level": int(row.get("required_martial_level", "1") or 1),
            "battle_id": battle_id,
            "encounter_id": encounter_id,
            "intro_text": row.get("intro_text", "").strip(),
            "ending_flag": row.get("ending_flag", "").strip(),
            "battle_modifiers": modifiers,
        })
    if errors:
        joined = "\n  - ".join(errors)
        raise ValueError(f"Strategic final boss validation failed:\n  - {joined}")
    return sorted(result, key=lambda item: int(item.get("priority", 0)), reverse=True)


def build_enemy_martial_stats() -> dict[str, Any]:
    result: dict[str, Any] = {}
    seen_levels: set[int] = set()
    errors: list[str] = []
    for row in read_table("enemy_martial_stats"):
        level = int(required(row, "martial_level", "enemy_martial_stats"))
        if level in seen_levels:
            errors.append(f"enemy_martial_stats duplicate martial_level: {level}")
            continue
        seen_levels.add(level)
        max_hp = int(required(row, "max_hp", f"enemy martial {level}"))
        max_momentum = int(required(row, "max_momentum", f"enemy martial {level}"))
        starting_momentum = int(required(row, "starting_momentum", f"enemy martial {level}"))
        qinggong = int(required(row, "qinggong", f"enemy martial {level}"))
        if level < 1:
            errors.append(f"enemy martial level must be >= 1: {level}")
        if max_hp < 1:
            errors.append(f"enemy martial {level}.max_hp must be >= 1")
        if max_momentum < 1:
            errors.append(f"enemy martial {level}.max_momentum must be >= 1")
        if starting_momentum < 0 or starting_momentum > max_momentum:
            errors.append(f"enemy martial {level}.starting_momentum must be between 0 and max_momentum")
        if qinggong < 1:
            errors.append(f"enemy martial {level}.qinggong must be >= 1")
        result[str(level)] = {
            "martial_level": level,
            "display_name": required(row, "display_name", f"enemy martial {level}"),
            "max_hp": max_hp,
            "max_momentum": max_momentum,
            "starting_momentum": starting_momentum,
            "qinggong": qinggong,
            "notes": row.get("notes", "").strip(),
        }
    if errors:
        joined = "\n  - ".join(errors)
        raise ValueError(f"Enemy martial stat validation failed:\n  - {joined}")
    return result


def build_combat_enemy_pools(template_index: dict[str, Any], deck_index: dict[str, Any]) -> dict[str, Any]:
    pools: dict[str, list[dict[str, Any]]] = {}
    seen: set[str] = set()
    errors: list[str] = []
    for row in read_table("combat_enemy_pools"):
        entry_id = required(row, "pool_entry_id", "combat_enemy_pools")
        if entry_id in seen:
            errors.append(f"combat_enemy_pools duplicate pool_entry_id: {entry_id}")
            continue
        seen.add(entry_id)
        pool_id = required(row, "combat_pool_id", f"combat enemy pool {entry_id}")
        template_id = required(row, "opponent_template_id", f"combat enemy pool {entry_id}")
        deck_id = required(row, "opponent_deck_id", f"combat enemy pool {entry_id}")
        validate_story_ref(errors, f"combat enemy pool {entry_id}.opponent_template_id", template_index, template_id)
        validate_story_ref(errors, f"combat enemy pool {entry_id}.opponent_deck_id", deck_index, deck_id)
        deck = deck_index.get(deck_id, {})
        if deck and str(deck.get("fighter_template_id", "")) != template_id:
            errors.append(f"combat enemy pool {entry_id}.opponent_deck_id template differs from opponent_template_id")
        martial_min = int(required(row, "martial_min", f"combat enemy pool {entry_id}"))
        martial_max = int(required(row, "martial_max", f"combat enemy pool {entry_id}"))
        weight = int(required(row, "weight", f"combat enemy pool {entry_id}"))
        if martial_min < 1:
            errors.append(f"combat enemy pool {entry_id}.martial_min must be >= 1")
        if martial_max < martial_min:
            errors.append(f"combat enemy pool {entry_id}.martial_max must be >= martial_min")
        if weight <= 0:
            errors.append(f"combat enemy pool {entry_id}.weight must be > 0")
        pools.setdefault(pool_id, []).append({
            "pool_entry_id": entry_id,
            "combat_pool_id": pool_id,
            "display_name": required(row, "display_name", f"combat enemy pool {entry_id}"),
            "enemy_family": required(row, "enemy_family", f"combat enemy pool {entry_id}"),
            "opponent_template_id": template_id,
            "opponent_deck_id": deck_id,
            "martial_min": martial_min,
            "martial_max": martial_max,
            "weight": weight,
            "hp_bonus": int(row.get("hp_bonus", "0") or 0),
            "max_momentum_bonus": int(row.get("max_momentum_bonus", "0") or 0),
            "starting_momentum_bonus": int(row.get("starting_momentum_bonus", "0") or 0),
            "qinggong_bonus": int(row.get("qinggong_bonus", "0") or 0),
            "notes": row.get("notes", "").strip(),
        })
    if errors:
        joined = "\n  - ".join(errors)
        raise ValueError(f"Combat enemy pool validation failed:\n  - {joined}")
    return pools


def validate_combat_enemy_pool_coverage(node_pool: list[dict[str, Any]], enemy_martial_stats: dict[str, Any], combat_enemy_pools: dict[str, Any]) -> None:
    errors: list[str] = []
    for node in node_pool:
        if not str(node.get("node_type", "")).startswith("combat_"):
            continue
        pool_id = str(node.get("combat_pool_id", ""))
        enemy_martial = int(node.get("enemy_martial_level", 0))
        if str(enemy_martial) not in enemy_martial_stats:
            errors.append(f"map node {node.get('node_id')} enemy_martial_level has no enemy_martial_stats row: {enemy_martial}")
            continue
        entries = combat_enemy_pools.get(pool_id, [])
        if not entries:
            errors.append(f"map node {node.get('node_id')} combat_pool_id has no combat_enemy_pools rows: {pool_id}")
            continue
        if not any(int(entry.get("martial_min", 0)) <= enemy_martial <= int(entry.get("martial_max", 0)) for entry in entries):
            errors.append(f"map node {node.get('node_id')} pool {pool_id} has no entry for enemy martial {enemy_martial}")
    if errors:
        joined = "\n  - ".join(errors)
        raise ValueError(f"Combat enemy pool coverage failed:\n  - {joined}")


def build_combat_balance_targets(combat_enemy_pools: dict[str, Any]) -> dict[str, Any]:
    targets: dict[str, list[dict[str, Any]]] = {}
    seen: set[tuple[str, str]] = set()
    errors: list[str] = []
    for row in read_table("combat_balance_targets"):
        pool_id = required(row, "combat_pool_id", "combat_balance_targets")
        role = required(row, "difficulty_role", f"combat balance target {pool_id}")
        key = (pool_id, role)
        if key in seen:
            errors.append(f"combat_balance_targets duplicate pool/role: {pool_id}/{role}")
            continue
        seen.add(key)
        if pool_id not in combat_enemy_pools:
            errors.append(f"combat_balance_targets references missing combat_pool_id: {pool_id}")
        delta_min = int(required(row, "player_martial_delta_min", f"combat balance target {pool_id}/{role}"))
        delta_max = int(required(row, "player_martial_delta_max", f"combat balance target {pool_id}/{role}"))
        win_min = float(required(row, "target_win_rate_min", f"combat balance target {pool_id}/{role}"))
        win_max = float(required(row, "target_win_rate_max", f"combat balance target {pool_id}/{role}"))
        hp_min = float(required(row, "target_avg_player_hp_remaining_min", f"combat balance target {pool_id}/{role}"))
        hp_max = float(required(row, "target_avg_player_hp_remaining_max", f"combat balance target {pool_id}/{role}"))
        turns_min = float(required(row, "target_turns_min", f"combat balance target {pool_id}/{role}"))
        turns_max = float(required(row, "target_turns_max", f"combat balance target {pool_id}/{role}"))
        if delta_max < delta_min:
            errors.append(f"combat_balance_targets {pool_id}/{role} delta max must be >= min")
        for label, low, high in [
            ("target_win_rate", win_min, win_max),
            ("target_avg_player_hp_remaining", hp_min, hp_max),
            ("target_turns", turns_min, turns_max),
        ]:
            if high < low:
                errors.append(f"combat_balance_targets {pool_id}/{role} {label} max must be >= min")
        for label, value in [
            ("target_win_rate_min", win_min),
            ("target_win_rate_max", win_max),
            ("target_avg_player_hp_remaining_min", hp_min),
            ("target_avg_player_hp_remaining_max", hp_max),
        ]:
            if value < 0.0 or value > 1.0:
                errors.append(f"combat_balance_targets {pool_id}/{role} {label} must be 0..1")
        targets.setdefault(pool_id, []).append({
            "combat_pool_id": pool_id,
            "difficulty_role": role,
            "player_martial_delta_min": delta_min,
            "player_martial_delta_max": delta_max,
            "target_win_rate_min": win_min,
            "target_win_rate_max": win_max,
            "target_avg_player_hp_remaining_min": hp_min,
            "target_avg_player_hp_remaining_max": hp_max,
            "target_turns_min": turns_min,
            "target_turns_max": turns_max,
            "notes": row.get("notes", "").strip(),
        })
    if errors:
        joined = "\n  - ".join(errors)
        raise ValueError(f"Combat balance target validation failed:\n  - {joined}")
    return targets


def validate_strategic_map_generation(node_pool: list[dict[str, Any]], generation_rules: list[dict[str, Any]]) -> None:
    errors: list[str] = []
    for rule in generation_rules:
        region_label = str(rule.get("region_id", "unknown"))
        region_index = int(region_label.split("_")[-1]) if region_label.split("_")[-1].isdigit() else 0
        eligible = [node for node in node_pool if int(node.get("region_min", 0)) <= region_index <= int(node.get("region_max", 0))]
        if len(eligible) < int(rule.get("choices_per_layer", 0)):
            errors.append(f"map generation {region_label} does not have enough eligible nodes")
        for tag in rule.get("mandatory_tags", []):
            if not any(tag in node.get("tags", []) for node in eligible):
                errors.append(f"map generation {region_label} mandatory tag has no eligible node: {tag}")
        checks = [
            ("common_combat_min", "combat_common"),
            ("elite_combat_min", "combat_elite"),
            ("military_min", "military"),
            ("case_min", "case"),
            ("reputation_min", "reputation"),
        ]
        for field, node_type in checks:
            required_count = int(rule.get(field, 0))
            if required_count > 0:
                available = [node for node in eligible if node.get("node_type") == node_type]
                if len(available) < required_count:
                    errors.append(f"map generation {region_label} needs {required_count} {node_type} nodes, has {len(available)}")
    if errors:
        joined = "\n  - ".join(errors)
        raise ValueError(f"Strategic map generation validation failed:\n  - {joined}")


def build_narrative_mvp_node_status() -> tuple[list[str], dict[str, Any]]:
    rows = read_table("narrative_mvp_node_status")
    flow_rows: list[tuple[int, str]] = []
    node_status: dict[str, Any] = {}
    seen_orders: dict[int, str] = {}

    for row in rows:
        node_id = required(row, "id", "narrative_mvp_node_status")
        if node_id in node_status:
            raise ValueError(f"narrative_mvp_node_status: duplicate node_status id '{node_id}'")
        flow_enabled = parse_bool(row.get("flow_enabled", "false"))
        raw_order = row.get("flow_order", "").strip()
        flow_order = int(raw_order) if raw_order != "" else None
        status = {
            "flow_enabled": flow_enabled,
            "flow_order": flow_order,
            "column": row.get("column", "").strip(),
            "type": row.get("type", "").strip(),
            "visual_path": row.get("visual_path", "").strip(),
            "implementation_status": row.get("implementation_status", "").strip(),
            "note": row.get("note", "").strip(),
        }
        node_status[node_id] = status
        if flow_enabled:
            if flow_order is None:
                raise ValueError(f"narrative_mvp_node_status: flow_enabled node '{node_id}' is missing flow_order")
            if flow_order in seen_orders:
                raise ValueError(f"narrative_mvp_node_status: duplicate flow_order {flow_order} for '{seen_orders[flow_order]}' and '{node_id}'")
            seen_orders[flow_order] = node_id
            flow_rows.append((flow_order, node_id))
        elif flow_order is not None:
            raise ValueError(f"narrative_mvp_node_status: node '{node_id}' has flow_order but flow_enabled is false")

    flow_node_ids = [node_id for _, node_id in sorted(flow_rows, key=lambda pair: pair[0])]
    return flow_node_ids, node_status


def build_narrative_node_from_row(row: dict[str, str], node_status: dict[str, Any]) -> dict[str, Any]:
    node_id = required(row, "id", "narrative_mvp_nodes")
    node: dict[str, Any] = {
        "id": node_id,
        "title": required(row, "title", "narrative_mvp_nodes"),
        "scene": required(row, "scene", "narrative_mvp_nodes"),
        "text": required(row, "text", "narrative_mvp_nodes"),
    }
    if node_id in node_status:
        status = node_status[node_id]
        for field in ["column", "type", "visual_path", "implementation_status", "flow_enabled", "flow_order"]:
            value = status.get(field)
            if value not in (None, ""):
                node[field] = value
    if row.get("dialogue_json", "").strip() != "":
        node["dialogue"] = parse_json_field(row["dialogue_json"].strip())
    if row.get("combat_json", "").strip() != "":
        node["combat"] = parse_json_field(row["combat_json"].strip())
    if row.get("choices_json", "").strip() != "":
        node["choices"] = parse_json_field(row["choices_json"].strip())
    return node


def build_narrative_nodes(node_status: dict[str, Any]) -> list[dict[str, Any]]:
    nodes: list[dict[str, Any]] = []
    seen_node_ids: set[str] = set()

    for row in sorted(read_table("narrative_mvp_nodes"), key=lambda r: int(required(r, "order", "narrative_mvp_nodes"))):
        node_id = required(row, "id", "narrative_mvp_nodes")
        if node_id in seen_node_ids:
            raise ValueError(f"narrative_mvp_nodes: duplicate node id '{node_id}'")
        seen_node_ids.add(node_id)
        nodes.append(build_narrative_node_from_row(row, node_status))

    return nodes


def build_narrative_mvp_nodes() -> dict[str, Any]:
    meta = {required(row, "key", "narrative_mvp_meta"): parse_json_or_string(row.get("value", "")) for row in read_table("narrative_mvp_meta")}
    prologue_values = {required(row, "key", "narrative_mvp_prologue"): parse_json_or_string(row.get("value", "")) for row in read_table("narrative_mvp_prologue")}
    flow_node_ids, node_status = build_narrative_mvp_node_status()

    steps: list[dict[str, Any]] = []
    for row in sorted(read_table("narrative_mvp_prologue_steps"), key=lambda r: int(required(r, "order", "narrative_mvp_prologue_steps"))):
        step: dict[str, Any] = {
            "id": required(row, "id", "narrative_mvp_prologue_steps"),
            "text": required(row, "text", "narrative_mvp_prologue_steps"),
        }
        for optional_field in ["title", "column", "type"]:
            value = row.get(optional_field, "").strip()
            if value != "":
                step[optional_field] = value
        if row.get("career_prompt", "").strip() != "":
            step["career_prompt"] = row["career_prompt"].strip()
        if row.get("combat_json", "").strip() != "":
            step["combat"] = parse_json_field(row["combat_json"].strip())
            _validate_single_narrative_combat(step["combat"], f"narrative_mvp_prologue_steps.{step['id']}.combat_json")
        steps.append(step)

    career_choices = {required(row, "role", "narrative_mvp_career_choices"): required(row, "label", "narrative_mvp_career_choices") for row in read_table("narrative_mvp_career_choices")}

    nodes = build_narrative_nodes(node_status)

    validate_narrative_mvp_config(nodes, flow_node_ids, node_status)

    ending = {required(row, "key", "narrative_mvp_ending"): parse_json_or_string(row.get("value", "")) for row in read_table("narrative_mvp_ending")}
    hints = {required(row, "key", "narrative_mvp_hints"): required(row, "value", "narrative_mvp_hints") for row in read_table("narrative_mvp_hints")}
    return {
        "meta": meta,
        "flow_node_ids": flow_node_ids,
        "node_status": node_status,
        "prologue": {
            "title": str(prologue_values.get("title", "")),
            "steps": steps,
            "career_choices": career_choices,
        },
        "nodes": nodes,
        "ending": ending,
        "hints": hints,
    }


def validate_narrative_mvp_config(nodes: list[dict[str, Any]], flow_node_ids: list[str], node_status: dict[str, Any]) -> None:
    errors: list[str] = []
    node_by_id = {str(node.get("id", "")): node for node in nodes}
    node_ids = set(node_by_id.keys())

    if not flow_node_ids:
        errors.append("narrative_mvp_node_status: at least one node must have flow_enabled=true")

    for node_id in node_status.keys():
        if node_id not in node_ids:
            errors.append(f"narrative_mvp_node_status: node '{node_id}' is not present in narrative_mvp_nodes.tsv")

    for node_id in flow_node_ids:
        if node_id not in node_ids:
            errors.append(f"flow_node_ids: node '{node_id}' is not present in narrative_mvp_nodes.tsv")
            continue
        status = node_status.get(node_id, {})
        if status.get("implementation_status") != "playable":
            errors.append(f"flow node '{node_id}' must have implementation_status=playable")
        for field in NARRATIVE_REQUIRED_STATUS_FIELDS:
            if status.get(field) in (None, ""):
                errors.append(f"flow node '{node_id}' is missing required status field '{field}'")

    for node in nodes:
        node_id = str(node.get("id", ""))
        node_type = str(node.get("type", ""))
        choices = node.get("choices", [])
        if choices is None:
            choices = []
        if not isinstance(choices, list):
            errors.append(f"node '{node_id}' choices must be a list")
            continue

        if node_id.endswith("_aftermath") and node_type != "战后处理":
            errors.append(f"node '{node_id}' ends with _aftermath but type is not 战后处理")

        node_combat = node.get("combat", {})
        _validate_narrative_combat(errors, f"node '{node_id}' combat_json", node_combat)
        if node_type == "战后处理" and isinstance(node_combat, dict) and bool(node_combat.get("enabled", False)):
            errors.append(f"post-battle node '{node_id}' must not have enabled combat_json")

        shared_battle_counts: dict[tuple[str, str], int] = {}
        for idx, choice in enumerate(choices):
            if not isinstance(choice, dict):
                errors.append(f"node '{node_id}' choice {idx} must be a dictionary")
                continue
            effects = choice.get("effects", {})
            if effects is not None and not isinstance(effects, dict):
                errors.append(f"node '{node_id}' choice {idx} effects must be a dictionary")
            if isinstance(effects, dict):
                for effect_key in effects.keys():
                    if str(effect_key) not in NARRATIVE_ALLOWED_EFFECT_FIELDS:
                        errors.append(f"node '{node_id}' choice '{choice.get('label', idx)}' has unsupported effect '{effect_key}'")
            choice_combat = choice.get("combat", {})
            _validate_narrative_combat(errors, f"node '{node_id}' choice '{choice.get('label', idx)}' combat", choice_combat)
            if isinstance(choice_combat, dict) and bool(choice_combat.get("enabled", False)):
                if node_type == "战后处理":
                    errors.append(f"post-battle node '{node_id}' choice '{choice.get('label', idx)}' must not trigger combat")
                battle_key = (str(choice_combat.get("encounter_id", "")), str(choice_combat.get("battle_id", "")))
                shared_battle_counts[battle_key] = shared_battle_counts.get(battle_key, 0) + 1

        for battle_key, count in shared_battle_counts.items():
            if count > 1:
                errors.append(
                    f"node '{node_id}' has {count} choices pointing to the same combat {battle_key}; split battle and aftermath nodes instead"
                )

    if errors:
        joined = "\n  - ".join(errors)
        raise ValueError(f"Narrative MVP validation failed:\n  - {joined}")


def _validate_single_narrative_combat(combat: Any, context: str) -> None:
    errors: list[str] = []
    _validate_narrative_combat(errors, context, combat)
    if errors:
        raise ValueError("; ".join(errors))


def _validate_narrative_combat(errors: list[str], context: str, combat: Any) -> None:
    if not isinstance(combat, dict) or not bool(combat.get("enabled", False)):
        return
    if str(combat.get("encounter_id", "")).strip() == "":
        errors.append(f"{context} is enabled but missing encounter_id")
    if str(combat.get("battle_id", "")).strip() == "":
        errors.append(f"{context} is enabled but missing battle_id")
    if "override_player_profile" not in combat:
        errors.append(f"{context} is enabled but missing override_player_profile")
    elif not isinstance(combat.get("override_player_profile"), bool):
        errors.append(f"{context}.override_player_profile must be boolean")


def build_performance_tracks() -> dict[str, Any]:
    timeline: dict[str, Any] = {}
    string_fields = {"prop_path", "prop2_path", "prop3_path"}
    bool_fields = {"hero", "master"}
    for row in read_table("performance_timeline"):
        track_id = required(row, "track_id", "performance_timeline")
        config: dict[str, Any] = {}
        for key, raw in row.items():
            if key == "track_id":
                continue
            value = raw.strip()
            if value == "":
                continue
            if key in string_fields:
                config[key] = value
            elif key in bool_fields:
                config[key] = parse_bool(value)
            else:
                config[key] = float(value)
        timeline[track_id] = config

    beats: dict[str, list[dict[str, Any]]] = {track_id: [] for track_id in timeline.keys()}
    rows = sorted(read_table("performance_beats"), key=lambda r: (required(r, "track_id", "performance_beats"), int(required(r, "order", "performance_beats"))))
    for row in rows:
        track_id = required(row, "track_id", "performance_beats")
        beats.setdefault(track_id, []).append(
            {
                "t": float(required(row, "t", f"performance beat {track_id}")),
                "type": required(row, "type", f"performance beat {track_id}"),
                "power": float(required(row, "power", f"performance beat {track_id}")),
            }
        )
    return {"timeline": timeline, "beats": beats}


def validate_narrative_visual_assets(payload: dict[str, Any]) -> None:
    for node in payload.get("nodes", []):
        if not isinstance(node, dict):
            continue
        node_id = str(node.get("id", "unknown"))
        validate_runtime_asset_path(str(node.get("visual_path", "")), f"narrative node {node_id}.visual_path")
    node_status = payload.get("node_status", {})
    if isinstance(node_status, dict):
        for node_id, status in node_status.items():
            if isinstance(status, dict):
                validate_runtime_asset_path(str(status.get("visual_path", "")), f"node_status {node_id}.visual_path")


def validate_performance_track_assets(payload: dict[str, Any]) -> None:
    timeline = payload.get("timeline", {})
    if not isinstance(timeline, dict):
        raise ValueError("performance_tracks.timeline must be a dictionary")
    for track_id, track in timeline.items():
        if not isinstance(track, dict):
            raise ValueError(f"performance track '{track_id}' must be a dictionary")
        for prefix in ["prop", "prop2", "prop3"]:
            validate_runtime_asset_path(str(track.get("%s_path" % prefix, "")), f"performance track {track_id}.{prefix}_path")


def validate_runtime_asset_path(path: str, context: str) -> None:
    if path.strip() == "":
        return
    if not path.startswith("res://"):
        raise ValueError(f"{context} must use res:// path, got: {path}")
    local_path = ROOT / path.replace("res://", "", 1)
    if not local_path.exists():
        raise ValueError(f"{context} points to missing asset: {path}")
    if local_path.suffix.lower() == ".svg":
        validate_runtime_svg(local_path, context)


def validate_runtime_svg(path: Path, context: str) -> None:
    text = path.read_text(encoding="utf-8")
    try:
        ET.fromstring(text)
    except ET.ParseError as exc:
        raise ValueError(f"{context} is not valid SVG XML: {path}: {exc}") from exc
    lowered = text.lower()
    if "<image" in lowered:
        raise ValueError(f"{context} SVG must not embed image tags: {path}")
    if "@font-face" in lowered:
        raise ValueError(f"{context} SVG must not embed font declarations: {path}")
    if re.search(r"(?:href|xlink:href)\s*=\s*['\"](?:https?:)?//", text, re.IGNORECASE):
        raise ValueError(f"{context} SVG must not reference remote resources: {path}")


def build_raw_json_documents() -> dict[Path, Any]:
    documents: dict[Path, Any] = {}
    for row in read_table("raw_json_documents"):
        relative_path = Path(required(row, "path", "raw_json_documents"))
        documents[relative_path] = parse_json_field(required(row, "payload_json", f"raw json {relative_path}"))
    return documents


def read_table(base_name: str) -> list[dict[str, str]]:
    for suffix, delimiter in ((".tsv", "\t"), (".csv", ",")):
        path = TABLES_DIR / f"{base_name}{suffix}"
        if path.exists():
            return read_delimited(path, delimiter)
    raise FileNotFoundError(f"Missing source table: {base_name}.tsv or {base_name}.csv")


def read_delimited(path: Path, delimiter: str) -> list[dict[str, str]]:
    with path.open("r", encoding="utf-8-sig", newline="") as handle:
        reader = csv.DictReader(handle, delimiter=delimiter)
        rows: list[dict[str, str]] = []
        for row in reader:
            cleaned = {str(key).strip(): (value or "").strip() for key, value in row.items() if key is not None}
            if any(value != "" for value in cleaned.values()):
                rows.append(cleaned)
        return rows


def parse_optional_value(field: str, raw_value: str) -> Any | None:
    value = raw_value.strip()
    if value == "":
        return None
    if field in BOOL_FIELDS:
        return parse_bool(value)
    if field in INT_FIELDS:
        return int(value)
    if field in LIST_FIELDS:
        return parse_int_list(value) if field == "range_bonus" else parse_str_list(value)
    return value


def parse_int_list(raw_value: str) -> list[int]:
    return [int(part.strip()) for part in raw_value.split("|") if part.strip() != ""]


def parse_str_list(raw_value: str) -> list[str]:
    return [part.strip() for part in raw_value.split("|") if part.strip() != ""]


def parse_bool(raw_value: str) -> bool:
    lowered = raw_value.strip().lower()
    if lowered in {"true", "1", "yes", "y"}:
        return True
    if lowered in {"false", "0", "no", "n", ""}:
        return False
    raise ValueError(f"Invalid boolean value: {raw_value}")


def parse_json_field(raw_value: str) -> Any:
    try:
        return json.loads(raw_value)
    except json.JSONDecodeError as exc:
        raise ValueError(f"Invalid JSON field: {raw_value[:80]}") from exc


def parse_json_or_string(raw_value: str) -> Any:
    value = raw_value.strip()
    if value == "":
        return ""
    try:
        return json.loads(value)
    except json.JSONDecodeError:
        return value


def required(row: dict[str, str], key: str, context: str) -> str:
    value = row.get(key, "").strip()
    if value == "":
        raise ValueError(f"{context} is missing required field '{key}'")
    return value


def write_json(path: Path, payload: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8") as handle:
        json.dump(payload, ensure_ascii=False, indent=2, fp=handle)
        handle.write("\n")


if __name__ == "__main__":
    raise SystemExit(main())
