#!/usr/bin/env python3
"""Generate Content Engine v0.4b enemy deck sets (design-layer only)."""

from __future__ import annotations

import argparse
import csv
from collections import Counter
from dataclasses import dataclass
from pathlib import Path


OUTPUT_FIELDS = [
    "deck_id",
    "deck_skeleton_id",
    "archetype_id",
    "scope",
    "route_type",
    "battle_type",
    "tier",
    "variant_index",
    "deck_variant_role",
    "card_slot_index",
    "slot_role",
    "card_id",
    "card_class",
    "card_weapon_style",
    "card_rarity",
    "card_tactic_role",
    "card_deck_role",
    "card_power_budget",
    "card_budget_delta",
    "preferred_distance_min",
    "preferred_distance_max",
    "selection_score",
    "selection_reason",
    "required_card_tags",
    "forbidden_card_tags",
    "card_tags",
    "source_card_pool",
    "notes",
]

INPUT_FILES = [
    "generated_enemy_deck_skeleton.tsv",
    "generated_card_pool.tsv",
    "generated_enemy_archetype_pool.tsv",
    "generated_enemy_deck_requirement.tsv",
]

ROLE_FIELDS = {
    "attack": "attack_card_count",
    "guard": "guard_card_count",
    "movement": "movement_card_count",
    "posture_break": "posture_break_card_count",
    "tempo": "tempo_card_count",
    "combo": "combo_card_count",
    "special": "special_card_count",
}

ROLE_ORDER = ["attack", "guard", "movement", "posture_break", "tempo", "combo", "special"]


@dataclass(frozen=True)
class DeckSkeleton:
    deck_skeleton_id: str
    archetype_id: str
    scope: str
    route_type: str
    battle_type: str
    tier: str
    variant_index: int
    deck_variant_role: str
    weapon_style: str
    target_card_count: int
    preferred_distance_min: int
    preferred_distance_max: int
    tactic_role_ratio: str
    required_card_tags: set[str]
    forbidden_card_tags: set[str]
    role_counts: dict[str, int]


@dataclass(frozen=True)
class CardPoolRow:
    card_id: str
    card_class: str
    weapon_style: str
    weapon_requirement: str
    rarity: str
    tactic_role: str
    deck_role: str
    min_distance: int
    max_distance: int
    power_budget: int
    budget_delta: int
    implementation_status: str
    tags: set[str]

    @classmethod
    def from_row(cls, row: dict[str, str]) -> "CardPoolRow":
        return cls(
            card_id=row.get("card_id", ""),
            card_class=row.get("card_class", ""),
            weapon_style=row.get("weapon_style", ""),
            weapon_requirement=row.get("weapon_requirement", ""),
            rarity=row.get("rarity", ""),
            tactic_role=row.get("tactic_role", ""),
            deck_role=row.get("deck_role", ""),
            min_distance=as_int(row.get("min_distance", ""), 1),
            max_distance=as_int(row.get("max_distance", ""), 3),
            power_budget=as_int(row.get("power_budget", ""), 0),
            budget_delta=as_int(row.get("budget_delta", ""), 0),
            implementation_status=row.get("implementation_status", ""),
            tags=split_tags(row.get("tags", "")),
        )


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Generate deterministic design-layer enemy deck sets for Content Engine v0.4b.")
    parser.add_argument("--design-dir", default="data/design")
    parser.add_argument("--out", default="data/design/generated_enemy_deck_sets.tsv")
    return parser.parse_args()


def must_exist(design_dir: Path) -> None:
    missing = [name for name in INPUT_FILES if not (design_dir / name).exists()]
    if missing:
        text = ", ".join(str(design_dir / item) for item in missing)
        raise FileNotFoundError(f"Missing required design inputs: {text}")


def read_tsv(path: Path) -> list[dict[str, str]]:
    with path.open("r", encoding="utf-8", newline="") as handle:
        return list(csv.DictReader(handle, delimiter="\t"))


def write_tsv(path: Path, rows: list[dict[str, str]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=OUTPUT_FIELDS, delimiter="\t", lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)


def as_int(value: str, fallback: int) -> int:
    try:
        return int(round(float((value or "").strip())))
    except ValueError:
        return fallback


def split_tags(value: str) -> set[str]:
    return {part.strip() for part in value.split(",") if part.strip()}


def parse_tactic_ratio(text: str) -> list[str]:
    items: list[tuple[str, float]] = []
    for part in text.split(","):
        block = part.strip()
        if ":" not in block:
            continue
        key, raw = block.split(":", 1)
        key = key.strip()
        try:
            weight = float(raw.strip())
        except ValueError:
            continue
        items.append((key, weight))
    items.sort(key=lambda item: (-item[1], item[0]))
    return [item[0] for item in items[:3]]


def tactic_matches(card_tactic_role: str, top_tactics: list[str]) -> bool:
    role_alias = {
        "pressure": {"pressure", "burst"},
        "guard_counter": {"counter", "guard"},
        "control": {"control", "poke"},
        "break": {"break", "punish"},
        "footwork": {"approach", "retreat", "control"},
        "firearm_pressure": {"firearm_pressure", "pressure", "tempo"},
        "burst": {"burst", "finisher"},
    }
    card_bucket = next((name for name, values in role_alias.items() if card_tactic_role in values), card_tactic_role)
    for tactic in top_tactics:
        wanted = role_alias.get(tactic, {tactic})
        if card_tactic_role in wanted or card_bucket == tactic:
            return True
    return False


def parse_skeletons(rows: list[dict[str, str]]) -> list[DeckSkeleton]:
    parsed: list[DeckSkeleton] = []
    for row in rows:
        role_counts = {role: as_int(row.get(field, ""), 0) for role, field in ROLE_FIELDS.items()}
        parsed.append(
            DeckSkeleton(
                deck_skeleton_id=row.get("deck_skeleton_id", ""),
                archetype_id=row.get("archetype_id", ""),
                scope=row.get("scope", ""),
                route_type=row.get("route_type", ""),
                battle_type=row.get("battle_type", ""),
                tier=row.get("tier", ""),
                variant_index=as_int(row.get("variant_index", ""), 1),
                deck_variant_role=row.get("deck_variant_role", ""),
                weapon_style=row.get("weapon_style", ""),
                target_card_count=as_int(row.get("target_card_count", ""), 0),
                preferred_distance_min=as_int(row.get("preferred_distance_min", ""), 1),
                preferred_distance_max=as_int(row.get("preferred_distance_max", ""), 3),
                tactic_role_ratio=row.get("tactic_role_ratio", ""),
                required_card_tags=split_tags(row.get("required_card_tags", "")),
                forbidden_card_tags=split_tags(row.get("forbidden_card_tags", "")),
                role_counts=role_counts,
            )
        )
    return parsed


def build_slot_roles(skeleton: DeckSkeleton) -> list[str]:
    counts = dict(skeleton.role_counts)
    target = skeleton.target_card_count
    current = sum(counts.values())

    if current < target:
        for role in add_priority(skeleton):
            if current >= target:
                break
            counts[role] = counts.get(role, 0) + 1
            current += 1

    if current > target:
        for role in trim_priority(skeleton):
            while current > target and counts.get(role, 0) > 0:
                counts[role] -= 1
                current -= 1
            if current <= target:
                break

    roles: list[str] = []
    for role in ROLE_ORDER:
        roles.extend([role] * max(0, counts.get(role, 0)))
    return roles[:target]


def add_priority(skeleton: DeckSkeleton) -> list[str]:
    if skeleton.scope == "wuzhuangyuan_exam":
        return ["guard", "movement", "posture_break", "attack", "tempo", "combo", "special"] * 8
    if skeleton.scope in {"boss_normal", "boss_true"}:
        return ["attack", "guard", "movement", "tempo", "special", "posture_break", "combo"] * 8
    return ["attack", "guard", "movement", "posture_break", "tempo", "combo", "special"] * 8


def trim_priority(skeleton: DeckSkeleton) -> list[str]:
    if skeleton.scope == "wuzhuangyuan_exam":
        return ["special", "combo", "tempo", "attack", "movement", "guard", "posture_break"]
    if skeleton.scope in {"boss_normal", "boss_true"}:
        return ["combo", "movement", "guard", "attack", "posture_break", "tempo", "special"]
    return ["special", "combo", "tempo", "movement", "guard", "attack", "posture_break"]


def max_repeat_limit(scope: str) -> int:
    if scope in {"boss_normal", "boss_true"}:
        return 3
    return 2


def select_card(
    skeleton: DeckSkeleton,
    slot_role: str,
    cards: list[CardPoolRow],
    card_by_id: dict[str, dict[str, str]],
    used: Counter[str],
    slot_index: int,
) -> dict[str, str]:
    deck_limit = max_repeat_limit(skeleton.scope)
    selected, score, reason = pick_candidate(skeleton, slot_role, cards, used, deck_limit, strict_repeat=True)
    notes = ""
    if selected is None:
        selected, score, reason = pick_candidate(skeleton, slot_role, cards, used, deck_limit, strict_repeat=False)
        notes = "repeat_limit_relaxed_for_pool_coverage"
    if selected is None:
        raise RuntimeError(f"No card candidate for deck={skeleton.deck_skeleton_id} slot_role={slot_role} slot_index={slot_index}")

    used[selected.card_id] += 1
    card_row = card_by_id[selected.card_id]
    return {
        "deck_id": skeleton.deck_skeleton_id,
        "deck_skeleton_id": skeleton.deck_skeleton_id,
        "archetype_id": skeleton.archetype_id,
        "scope": skeleton.scope,
        "route_type": skeleton.route_type,
        "battle_type": skeleton.battle_type,
        "tier": skeleton.tier,
        "variant_index": str(skeleton.variant_index),
        "deck_variant_role": skeleton.deck_variant_role,
        "card_slot_index": str(slot_index),
        "slot_role": slot_role,
        "card_id": selected.card_id,
        "card_class": card_row.get("card_class", ""),
        "card_weapon_style": card_row.get("weapon_style", ""),
        "card_rarity": card_row.get("rarity", ""),
        "card_tactic_role": card_row.get("tactic_role", ""),
        "card_deck_role": card_row.get("deck_role", ""),
        "card_power_budget": card_row.get("power_budget", ""),
        "card_budget_delta": card_row.get("budget_delta", ""),
        "preferred_distance_min": str(skeleton.preferred_distance_min),
        "preferred_distance_max": str(skeleton.preferred_distance_max),
        "selection_score": f"{score:.2f}",
        "selection_reason": ",".join(reason),
        "required_card_tags": ",".join(sorted(skeleton.required_card_tags)),
        "forbidden_card_tags": ",".join(sorted(skeleton.forbidden_card_tags)),
        "card_tags": card_row.get("tags", ""),
        "source_card_pool": "generated_card_pool.tsv",
        "notes": notes,
    }


def pick_candidate(
    skeleton: DeckSkeleton,
    slot_role: str,
    cards: list[CardPoolRow],
    used: Counter[str],
    limit: int,
    strict_repeat: bool,
) -> tuple[CardPoolRow | None, float, list[str]]:
    ranked: list[tuple[float, str, CardPoolRow, list[str]]] = []
    top_tactics = parse_tactic_ratio(skeleton.tactic_role_ratio)
    for card in cards:
        if card.implementation_status == "deprecated":
            continue
        if card.deck_role != slot_role:
            continue
        if not hard_scope_card_allowed(skeleton, card):
            continue
        if card.tags & skeleton.forbidden_card_tags:
            continue
        if "lightness_4_required" in skeleton.forbidden_card_tags and "lightness_4_required" in card.tags:
            continue
        if strict_repeat and used.get(card.card_id, 0) >= limit:
            continue
        score, reason = score_candidate(skeleton, card, used, top_tactics)
        ranked.append((score, card.card_id, card, reason))

    if not ranked:
        return None, 0.0, []
    ranked.sort(key=lambda item: (-item[0], item[1]))
    best = ranked[0]
    return best[2], best[0], best[3]


def hard_scope_card_allowed(skeleton: DeckSkeleton, card: CardPoolRow) -> bool:
    if card.weapon_style == "boss" and skeleton.scope not in {"boss_normal", "boss_true"}:
        return False
    if card.weapon_requirement == "boss_only" and skeleton.scope not in {"boss_normal", "boss_true"}:
        return False
    if skeleton.scope == "wuzhuangyuan_exam" and card.weapon_style == "boss":
        return False
    if skeleton.scope in {"boss_normal", "boss_true"}:
        return card.weapon_style in {"boss", "generic", "mixed", "official", "blademaster", "spearman", "firearm", "footwork"}
    return card.weapon_style != "boss"


def score_candidate(
    skeleton: DeckSkeleton,
    card: CardPoolRow,
    used: Counter[str],
    top_tactics: list[str],
) -> tuple[float, list[str]]:
    score = 50.0
    reasons = ["role_match"]

    if card.weapon_style == skeleton.weapon_style:
        score += 25.0
        reasons.append("weapon_match")
    elif card.weapon_style == "generic":
        score += 10.0
        reasons.append("generic_fallback")
    elif skeleton.scope == "wuzhuangyuan_exam" and card.weapon_style in {"official", "mixed"}:
        score += 14.0
        reasons.append("exam_official_fundamental")

    if skeleton.scope in {"boss_normal", "boss_true"} and card.weapon_style == "boss":
        score += 18.0
        reasons.append("boss_phase_card")

    required_hits = len(skeleton.required_card_tags & card.tags)
    if required_hits > 0:
        score += min(24.0, required_hits * 8.0)
        reasons.append("required_tag_match")

    if distance_overlap(skeleton.preferred_distance_min, skeleton.preferred_distance_max, card.min_distance, card.max_distance):
        score += 10.0
        reasons.append("distance_match")

    if tactic_matches(card.tactic_role, top_tactics):
        score += 10.0
        reasons.append("tactic_match")

    rarity_score, rarity_reason = rarity_adjustment(skeleton, card)
    score += rarity_score
    if rarity_reason:
        reasons.append(rarity_reason)

    if abs(card.budget_delta) <= 1:
        score += 5.0
    elif abs(card.budget_delta) <= 2:
        score += 3.0

    repeats = used.get(card.card_id, 0)
    if repeats > 0:
        score -= repeats * 12.0
        reasons.append("repeat_penalty")

    if skeleton.weapon_style == "firearm" and card.tactic_role in {"firearm_pressure", "tempo", "control"}:
        score += 8.0
        reasons.append("firearm_counterplay")

    return score, unique_list(reasons)


def rarity_adjustment(skeleton: DeckSkeleton, card: CardPoolRow) -> tuple[float, str]:
    rarity = card.rarity
    if skeleton.scope == "big_map_normal":
        if skeleton.tier == "basic":
            if rarity == "common":
                return 8.0, "rarity_fit"
            if rarity == "uncommon":
                return 4.0, "rarity_fit"
            if rarity == "rare":
                return -2.0, ""
            return -8.0, ""
        if rarity in {"common", "uncommon"}:
            return 6.0, "rarity_fit"
        if rarity == "rare":
            return 2.0, ""
        return -6.0, ""
    if skeleton.scope == "big_map_elite":
        if rarity == "uncommon":
            return 8.0, "rarity_fit"
        if rarity == "rare":
            return 6.0, "rarity_fit"
        if rarity == "common":
            return 2.0, ""
        return -6.0, ""
    if skeleton.scope in {"boss_normal", "boss_true"}:
        if rarity == "boss":
            return 10.0, "rarity_fit"
        if rarity == "special":
            return 8.0, "rarity_fit"
        if rarity == "rare":
            return 6.0, "rarity_fit"
        return 1.0, ""
    if skeleton.scope == "wuzhuangyuan_exam":
        if rarity == "uncommon":
            return 8.0, "rarity_fit"
        if rarity == "rare":
            return 7.0, "rarity_fit"
        if rarity == "common":
            return 4.0, "rarity_fit"
        if rarity == "special":
            return 2.0, ""
        return -8.0, ""
    return 0.0, ""


def unique_list(values: list[str]) -> list[str]:
    seen: set[str] = set()
    out: list[str] = []
    for value in values:
        if value and value not in seen:
            seen.add(value)
            out.append(value)
    return out


def distance_overlap(a_min: int, a_max: int, b_min: int, b_max: int) -> bool:
    return max(a_min, b_min) <= min(a_max, b_max)


def generate_rows(
    skeletons: list[DeckSkeleton],
    card_rows: list[dict[str, str]],
    cards: list[CardPoolRow],
) -> list[dict[str, str]]:
    card_by_id = {row.get("card_id", ""): row for row in card_rows}
    out: list[dict[str, str]] = []
    for skeleton in skeletons:
        if "lightness_4_required" in skeleton.required_card_tags:
            raise RuntimeError(f"Invalid skeleton required_card_tags contains lightness_4_required: {skeleton.deck_skeleton_id}")
        slot_roles = build_slot_roles(skeleton)
        used: Counter[str] = Counter()
        for index, slot_role in enumerate(slot_roles, start=1):
            out.append(select_card(skeleton, slot_role, cards, card_by_id, used, index))
    return out


def main() -> int:
    args = parse_args()
    design_dir = Path(args.design_dir)
    out_path = Path(args.out)
    must_exist(design_dir)

    skeleton_rows = read_tsv(design_dir / "generated_enemy_deck_skeleton.tsv")
    card_rows = read_tsv(design_dir / "generated_card_pool.tsv")
    _ = read_tsv(design_dir / "generated_enemy_archetype_pool.tsv")
    _ = read_tsv(design_dir / "generated_enemy_deck_requirement.tsv")

    skeletons = parse_skeletons(skeleton_rows)
    cards = [CardPoolRow.from_row(row) for row in card_rows]
    rows = generate_rows(skeletons, card_rows, cards)
    write_tsv(out_path, rows)

    print(f"WROTE: {out_path}")
    print(f"DECKS: {len(skeletons)}")
    print(f"CARD_ASSIGNMENTS: {len(rows)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
