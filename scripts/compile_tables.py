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

        DATA_DIR.mkdir(parents=True, exist_ok=True)
        write_json(DATA_DIR / "classes.json", classes)
        write_json(DATA_DIR / "cards.json", cards)
        write_json(DATA_DIR / "effects.json", effects)
        write_json(DATA_DIR / "enemies.json", enemies)
        write_json(DATA_DIR / "routes.json", routes)
        write_json(DATA_DIR / "rewards.json", rewards)
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


def required(row: dict[str, str], key: str, context: str) -> str:
    value = row.get(key, "").strip()
    if value == "":
        raise ValueError(f"{context} is missing required field '{key}'")
    return value


def write_json(path: Path, payload: Any) -> None:
    with path.open("w", encoding="utf-8") as handle:
        json.dump(payload, handle, ensure_ascii=False, indent=2)
        handle.write("\n")


if __name__ == "__main__":
    raise SystemExit(main())
