#!/usr/bin/env python3
from __future__ import annotations

import csv
import json
import sys
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
    rows = read_table("classes")
    classes: dict[str, Any] = {}
    for row in rows:
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
    card_rows = read_table("cards")
    effect_rows = sorted(read_table("card_effects"), key=lambda row: int(required(row, "order", "card_effects")))

    effects_by_card: dict[str, list[dict[str, Any]]] = {}
    for row in effect_rows:
        card_id = required(row, "card_id", "card_effects")
        effect_type = required(row, "type", f"card effect {card_id}")
        effect: dict[str, Any] = {"type": effect_type}
        for field in CARD_EFFECT_FIELDS:
            parsed = parse_optional_value(field, row.get(field, ""))
            if parsed is not None:
                effect[field] = parsed
        effects_by_card.setdefault(card_id, []).append(effect)

    cards: dict[str, Any] = {}
    for row in card_rows:
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
    rows = read_table("effect_types")
    effect_types: dict[str, Any] = {}
    for row in rows:
        effect_type = required(row, "type", "effect_types")
        effect_types[effect_type] = {
            "handler": required(row, "handler", f"effect type {effect_type}"),
            "required_fields": parse_str_list(row.get("required_fields", "")),
            "description": row.get("description", "").strip(),
        }
    return effect_types


def build_enemies() -> list[dict[str, Any]]:
    enemy_rows = read_table("enemies")
    intent_rows = sorted(read_table("enemy_intents"), key=lambda row: int(required(row, "order", "enemy_intents")))

    intents_by_enemy: dict[str, list[dict[str, Any]]] = {}
    for row in intent_rows:
        enemy_id = required(row, "enemy_id", "enemy_intents")
        intent = {
            "name": required(row, "name", f"enemy intent {enemy_id}"),
            "cost": int(required(row, "cost", f"enemy intent {enemy_id}")),
        }
        for field in ENEMY_INTENT_FIELDS:
            parsed = parse_optional_value(field, row.get(field, ""))
            if parsed is not None:
                intent[field] = parsed
        intents_by_enemy.setdefault(enemy_id, []).append(intent)

    enemies: list[dict[str, Any]] = []
    for row in enemy_rows:
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
    rows = read_table("routes")
    routes: dict[str, Any] = {}
    for row in rows:
        route_id = required(row, "id", "routes")
        route: dict[str, Any] = {
            "title": required(row, "title", f"route {route_id}"),
            "kind": required(row, "kind", f"route {route_id}"),
            "next": parse_str_list(row.get("next", "")),
        }
        enemy_id = row.get("enemy_id", "").strip()
        if enemy_id != "":
            route["enemy_id"] = enemy_id
        heal = row.get("heal", "").strip()
        if heal != "":
            route["heal"] = int(heal)
        map_length = row.get("map_length", "").strip()
        if map_length != "":
            route["map_length"] = int(map_length)
        initial_distance = row.get("initial_distance", "").strip()
        if initial_distance != "":
            route["initial_distance"] = int(initial_distance)
        routes[route_id] = route
    return routes


def build_rewards() -> list[str]:
    rows = read_table("rewards")
    return [required(row, "card_id", "rewards") for row in rows]


def build_battle_scene_manifest() -> dict[str, Any]:
    rows = read_table("battle_scene_manifest")
    manifest: dict[str, Any] = {}
    float_fields = ["mist", "dim", "accent", "camera_zoom", "camera_pan_x", "camera_pan_y"]
    for row in rows:
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
    meta: dict[str, Any] = {}
    for row in read_table("enemy_manifest_meta"):
        key = required(row, "key", "enemy_manifest_meta")
        meta[key] = parse_json_or_string(row.get("value", ""))

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
        weights: dict[str, float] = {}
        for field in ["gain_posture", "attack", "guard", "break_posture", "feint"]:
            value = row.get(field, "").strip()
            if value != "":
                weights[field] = float(value)
        weights_by_enemy[enemy_id] = weights

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
        reward = {
            "jun_gong": int(required(row, "reward_jun_gong", f"enemy {enemy_id}")),
            "qing_wang": int(required(row, "reward_qing_wang", f"enemy {enemy_id}")),
            "clues": int(required(row, "reward_clues", f"enemy {enemy_id}")),
        }
        enemies[enemy_id] = {
            "enemy_id": enemy_id,
            "display_name": required(row, "display_name", f"enemy {enemy_id}"),
            "narrative_identity": required(row, "narrative_identity", f"enemy {enemy_id}"),
            "weapon": required(row, "weapon", f"enemy {enemy_id}"),
            "role_sheet": required(row, "role_sheet", f"enemy {enemy_id}"),
            "max_hp": int(required(row, "max_hp", f"enemy {enemy_id}")),
            "max_posture": int(required(row, "max_posture", f"enemy {enemy_id}")),
            "start_posture": int(required(row, "start_posture", f"enemy {enemy_id}")),
            "intent_style": required(row, "intent_style", f"enemy {enemy_id}"),
            "behavior_tags": parse_str_list(row.get("behavior_tags", "")),
            "preferred_intents": parse_str_list(row.get("preferred_intents", "")),
            "intent_weights": weights_by_enemy.get(enemy_id, {}),
            "phase_behaviors": phases_by_enemy.get(enemy_id, []),
            "deck": deck_by_enemy.get(enemy_id, []),
            "ai_note": row.get("ai_note", "").strip(),
            "reward": reward,
        }
    return {"meta": meta, "encounters": encounters, "enemies": enemies}


def build_narrative_mvp_nodes() -> dict[str, Any]:
    meta = {required(row, "key", "narrative_mvp_meta"): parse_json_or_string(row.get("value", "")) for row in read_table("narrative_mvp_meta")}
    prologue_values = {required(row, "key", "narrative_mvp_prologue"): parse_json_or_string(row.get("value", "")) for row in read_table("narrative_mvp_prologue")}
    steps = []
    for row in sorted(read_table("narrative_mvp_prologue_steps"), key=lambda r: int(required(r, "order", "narrative_mvp_prologue_steps"))):
        step: dict[str, Any] = {
            "id": required(row, "id", "narrative_mvp_prologue_steps"),
            "text": required(row, "text", "narrative_mvp_prologue_steps"),
        }
        title = row.get("title", "").strip()
        if title != "":
            step["title"] = title
        career_prompt = row.get("career_prompt", "").strip()
        if career_prompt != "":
            step["career_prompt"] = career_prompt
        combat_json = row.get("combat_json", "").strip()
        if combat_json != "":
            step["combat"] = parse_json_field(combat_json)
        steps.append(step)
    career_choices = {required(row, "role", "narrative_mvp_career_choices"): required(row, "label", "narrative_mvp_career_choices") for row in read_table("narrative_mvp_career_choices")}

    nodes = []
    for row in sorted(read_table("narrative_mvp_nodes"), key=lambda r: int(required(r, "order", "narrative_mvp_nodes"))):
        node: dict[str, Any] = {
            "id": required(row, "id", "narrative_mvp_nodes"),
            "title": required(row, "title", "narrative_mvp_nodes"),
            "scene": required(row, "scene", "narrative_mvp_nodes"),
            "text": required(row, "text", "narrative_mvp_nodes"),
        }
        dialogue_json = row.get("dialogue_json", "").strip()
        if dialogue_json != "":
            node["dialogue"] = parse_json_field(dialogue_json)
        combat_json = row.get("combat_json", "").strip()
        if combat_json != "":
            node["combat"] = parse_json_field(combat_json)
        choices_json = row.get("choices_json", "").strip()
        if choices_json != "":
            node["choices"] = parse_json_field(choices_json)
        nodes.append(node)

    ending = {required(row, "key", "narrative_mvp_ending"): parse_json_or_string(row.get("value", "")) for row in read_table("narrative_mvp_ending")}
    hints = {required(row, "key", "narrative_mvp_hints"): required(row, "value", "narrative_mvp_hints") for row in read_table("narrative_mvp_hints")}
    return {
        "meta": meta,
        "prologue": {
            "title": str(prologue_values.get("title", "")),
            "steps": steps,
            "career_choices": career_choices,
        },
        "nodes": nodes,
        "ending": ending,
        "hints": hints,
    }


def build_performance_tracks() -> dict[str, Any]:
    timeline: dict[str, Any] = {}
    for row in read_table("performance_timeline"):
        track_id = required(row, "track_id", "performance_timeline")
        config: dict[str, Any] = {}
        for key, raw in row.items():
            if key == "track_id":
                continue
            value = raw.strip()
            if value == "":
                continue
            if key in {"hero", "master"}:
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
        rows = []
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
        if field == "range_bonus":
            return parse_int_list(value)
        return parse_str_list(value)
    return value


def parse_int_list(raw_value: str) -> list[int]:
    return [int(part.strip()) for part in raw_value.split("|") if part.strip() != ""]


def parse_str_list(raw_value: str) -> list[str]:
    return [part.strip() for part in raw_value.split("|") if part.strip() != ""]


def parse_bool(raw_value: str) -> bool:
    lowered = raw_value.lower()
    if lowered in {"true", "1", "yes"}:
        return True
    if lowered in {"false", "0", "no"}:
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
