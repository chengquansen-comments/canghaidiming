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


def build_narrative_mvp_node_status() -> tuple[list[str], dict[str, Any]]:
    rows = read_table("narrative_mvp_node_status")
    flow_rows: list[tuple[int, str]] = []
    node_status: dict[str, Any] = {}
    seen_orders: dict[int, str] = {}

    for row in rows:
        node_id = required(row, "id", "narrative_mvp_node_status")
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

    flow_node_ids = [node_id for _, node_id in sorted(flow_rows, key=lambda pair: pair[0])]
    return flow_node_ids, node_status


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
        steps.append(step)

    career_choices = {required(row, "role", "narrative_mvp_career_choices"): required(row, "label", "narrative_mvp_career_choices") for row in read_table("narrative_mvp_career_choices")}

    nodes: list[dict[str, Any]] = []
    for row in sorted(read_table("narrative_mvp_nodes"), key=lambda r: int(required(r, "order", "narrative_mvp_nodes"))):
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
        nodes.append(node)

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
