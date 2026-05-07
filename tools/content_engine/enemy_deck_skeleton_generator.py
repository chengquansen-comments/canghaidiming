#!/usr/bin/env python3
"""Generate Content Engine v0.3 enemy deck skeletons (design-layer only)."""

from __future__ import annotations

import argparse
import csv
from dataclasses import dataclass
from pathlib import Path


OUTPUT_FIELDS = [
    "deck_skeleton_id",
    "archetype_id",
    "scope",
    "route_type",
    "battle_type",
    "tier",
    "variant_index",
    "deck_variant_role",
    "weapon_style",
    "expected_player_realm",
    "complexity_level",
    "target_card_count",
    "attack_card_count",
    "guard_card_count",
    "movement_card_count",
    "posture_break_card_count",
    "tempo_card_count",
    "combo_card_count",
    "special_card_count",
    "preferred_distance_min",
    "preferred_distance_max",
    "tactic_role_ratio",
    "required_card_tags",
    "forbidden_card_tags",
    "ai_behavior_hint",
    "reward_pressure_level",
    "source_archetype_id",
    "source_requirement_id",
    "notes",
]

INPUT_FILES = [
    "generated_enemy_archetype_pool.tsv",
    "generated_enemy_deck_requirement.tsv",
    "generated_battle_slot_plan.tsv",
]

NORMAL_VARIANT_ROLES = ["basic", "advanced", "aggressive", "defensive"]
ELITE_VARIANT_ROLES = ["basic", "advanced"]


@dataclass(frozen=True)
class ArchetypeRow:
    archetype_id: str
    scope: str
    route_type: str
    battle_type: str
    tier: str
    weapon_style: str
    complexity_level: int
    expected_player_realm: str
    preferred_distance_min: int
    preferred_distance_max: int
    tactic_role_ratio: str
    recommended_deck_variant_count: int
    source_requirement_id: str


@dataclass(frozen=True)
class CardRoleCounts:
    attack: int
    guard: int
    movement: int
    posture_break: int
    tempo: int
    combo: int
    special: int


@dataclass(frozen=True)
class DeckSkeleton:
    deck_skeleton_id: str
    archetype: ArchetypeRow
    variant_index: int
    deck_variant_role: str
    target_card_count: int
    counts: CardRoleCounts
    required_card_tags: str
    forbidden_card_tags: str
    ai_behavior_hint: str
    reward_pressure_level: str
    notes: str

    def to_row(self) -> dict[str, str]:
        return {
            "deck_skeleton_id": self.deck_skeleton_id,
            "archetype_id": self.archetype.archetype_id,
            "scope": self.archetype.scope,
            "route_type": self.archetype.route_type,
            "battle_type": self.archetype.battle_type,
            "tier": self.archetype.tier,
            "variant_index": str(self.variant_index),
            "deck_variant_role": self.deck_variant_role,
            "weapon_style": self.archetype.weapon_style,
            "expected_player_realm": self.archetype.expected_player_realm,
            "complexity_level": str(self.archetype.complexity_level),
            "target_card_count": str(self.target_card_count),
            "attack_card_count": str(self.counts.attack),
            "guard_card_count": str(self.counts.guard),
            "movement_card_count": str(self.counts.movement),
            "posture_break_card_count": str(self.counts.posture_break),
            "tempo_card_count": str(self.counts.tempo),
            "combo_card_count": str(self.counts.combo),
            "special_card_count": str(self.counts.special),
            "preferred_distance_min": str(self.archetype.preferred_distance_min),
            "preferred_distance_max": str(self.archetype.preferred_distance_max),
            "tactic_role_ratio": self.archetype.tactic_role_ratio,
            "required_card_tags": self.required_card_tags,
            "forbidden_card_tags": self.forbidden_card_tags,
            "ai_behavior_hint": self.ai_behavior_hint,
            "reward_pressure_level": self.reward_pressure_level,
            "source_archetype_id": self.archetype.archetype_id,
            "source_requirement_id": self.archetype.source_requirement_id,
            "notes": self.notes,
        }


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Generate deterministic enemy deck skeletons for Content Engine v0.3.")
    parser.add_argument("--design-dir", default="data/design")
    parser.add_argument("--out", default="data/design/generated_enemy_deck_skeleton.tsv")
    return parser.parse_args()


def read_tsv(path: Path) -> list[dict[str, str]]:
    with path.open("r", encoding="utf-8", newline="") as handle:
        return list(csv.DictReader(handle, delimiter="\t"))


def must_exist(design_dir: Path) -> None:
    missing = [name for name in INPUT_FILES if not (design_dir / name).exists()]
    if missing:
        paths = ", ".join(str(design_dir / item) for item in missing)
        raise FileNotFoundError(f"Missing required design inputs: {paths}")


def as_int(value: str, fallback: int) -> int:
    try:
        return int(round(float((value or "").strip())))
    except ValueError:
        return fallback


def parse_archetypes(rows: list[dict[str, str]]) -> list[ArchetypeRow]:
    archetypes: list[ArchetypeRow] = []
    for row in rows:
        archetypes.append(
            ArchetypeRow(
                archetype_id=row.get("archetype_id", ""),
                scope=row.get("scope", ""),
                route_type=row.get("route_type", ""),
                battle_type=row.get("battle_type", ""),
                tier=row.get("tier", ""),
                weapon_style=row.get("weapon_style", ""),
                complexity_level=as_int(row.get("complexity_level", ""), 1),
                expected_player_realm=row.get("expected_player_realm", ""),
                preferred_distance_min=as_int(row.get("preferred_distance_min", ""), 1),
                preferred_distance_max=as_int(row.get("preferred_distance_max", ""), 3),
                tactic_role_ratio=row.get("tactic_role_ratio", ""),
                recommended_deck_variant_count=as_int(row.get("recommended_deck_variant_count", ""), 1),
                source_requirement_id=row.get("source_requirement_id", ""),
            )
        )
    return archetypes


def build_skeletons(
    archetypes: list[ArchetypeRow],
    deck_requirements: list[dict[str, str]],
    battle_slots: list[dict[str, str]],
) -> list[DeckSkeleton]:
    # These v0.1 tables are read now so v0.4 can tighten generated decks against
    # requirement and slot metadata without changing the v0.3 command contract.
    _ = deck_requirements
    _ = battle_slots
    skeletons: list[DeckSkeleton] = []
    for archetype in archetypes:
        skeletons.extend(build_for_archetype(archetype))
    return skeletons


def build_for_archetype(archetype: ArchetypeRow) -> list[DeckSkeleton]:
    if archetype.scope == "big_map_normal":
        return build_variant_set(archetype, NORMAL_VARIANT_ROLES, archetype.recommended_deck_variant_count)
    if archetype.scope == "big_map_elite":
        return build_variant_set(archetype, ELITE_VARIANT_ROLES, archetype.recommended_deck_variant_count)
    if archetype.scope in {"boss_normal", "boss_true"}:
        return build_boss_variant_set(archetype)
    if archetype.scope == "wuzhuangyuan_exam":
        return [build_one(archetype, 1, exam_role(archetype))]
    return [build_one(archetype, 1, "basic")]


def build_variant_set(archetype: ArchetypeRow, roles: list[str], requested_count: int) -> list[DeckSkeleton]:
    count = max(1, min(requested_count, len(roles)))
    return [build_one(archetype, index + 1, roles[index]) for index in range(count)]


def build_boss_variant_set(archetype: ArchetypeRow) -> list[DeckSkeleton]:
    if archetype.battle_type == "true_boss":
        roles = ["phase_1", "phase_2"]
    else:
        roles = ["phase_1"]
    return [build_one(archetype, index + 1, role) for index, role in enumerate(roles)]


def exam_role(archetype: ArchetypeRow) -> str:
    if archetype.archetype_id == "exam_imperial_final_examiner":
        return "exam_final"
    return "exam_standard"


def build_one(archetype: ArchetypeRow, variant_index: int, role: str) -> DeckSkeleton:
    target = target_card_count(archetype, role)
    return DeckSkeleton(
        deck_skeleton_id=deck_skeleton_id(archetype, role),
        archetype=archetype,
        variant_index=variant_index,
        deck_variant_role=role,
        target_card_count=target,
        counts=card_role_counts(archetype, role, target),
        required_card_tags=join_tags(required_tags(archetype, role)),
        forbidden_card_tags=join_tags(forbidden_tags(archetype, role)),
        ai_behavior_hint=ai_hint(archetype, role),
        reward_pressure_level=reward_pressure(archetype, role),
        notes=notes_for(archetype, role),
    )


def deck_skeleton_id(archetype: ArchetypeRow, role: str) -> str:
    if archetype.scope == "big_map_normal":
        return f"enemy_{archetype.archetype_id}_{role}"
    if archetype.scope == "big_map_elite":
        return f"enemy_{archetype.archetype_id}_elite_{role}"
    if archetype.scope in {"boss_normal", "boss_true"}:
        return f"boss_{archetype.archetype_id}_{role}"
    if archetype.scope == "wuzhuangyuan_exam":
        return f"exam_{archetype.archetype_id}"
    return f"enemy_{archetype.archetype_id}_{role}"


def target_card_count(archetype: ArchetypeRow, role: str) -> int:
    if archetype.scope == "big_map_normal":
        if role == "basic":
            return 9 if archetype.complexity_level <= 2 else 10
        if role == "advanced":
            return 11 if archetype.complexity_level <= 2 else 12
        return 10 if archetype.complexity_level <= 2 else 11
    if archetype.scope == "big_map_elite":
        return 12 if role == "basic" else 14
    if archetype.scope == "boss_normal":
        return 15
    if archetype.scope == "boss_true":
        if archetype.battle_type == "true_boss":
            return 17 if role == "phase_1" else 18
        return 16
    if archetype.scope == "wuzhuangyuan_exam":
        return 16 if role == "exam_final" else 14
    return 10


def card_role_counts(archetype: ArchetypeRow, role: str, target: int) -> CardRoleCounts:
    if archetype.scope == "big_map_normal":
        return normal_counts(archetype.weapon_style, role, target)
    if archetype.scope == "big_map_elite":
        return elite_counts(archetype.weapon_style, role)
    if archetype.scope in {"boss_normal", "boss_true"}:
        return boss_counts(archetype, role)
    if archetype.scope == "wuzhuangyuan_exam":
        return exam_counts(archetype.weapon_style, role)
    return balanced_counts(target)


def normal_counts(weapon_style: str, role: str, target: int) -> CardRoleCounts:
    aggressive_bonus = 1 if role == "aggressive" else 0
    defensive_bonus = 1 if role == "defensive" else 0
    advanced_bonus = 1 if role == "advanced" else 0
    if weapon_style == "spearman":
        return CardRoleCounts(3 + aggressive_bonus, 2 + defensive_bonus, 1 + advanced_bonus, 2, 1, advanced_bonus, 0)
    if weapon_style == "blademaster":
        return CardRoleCounts(3 + aggressive_bonus, 2 + defensive_bonus, 1 + advanced_bonus, 1, 1, 1 + advanced_bonus, 0)
    if weapon_style == "footwork":
        return CardRoleCounts(2 + aggressive_bonus, 1 + defensive_bonus, 3, 1, 2, advanced_bonus, 1)
    if weapon_style == "firearm":
        return CardRoleCounts(3 + aggressive_bonus, 1 + defensive_bonus, 1 + advanced_bonus, 2, 2, 0, 1)
    if weapon_style == "official":
        return CardRoleCounts(2 + aggressive_bonus, 2 + defensive_bonus, 2, 2, 1, advanced_bonus, 0)
    if weapon_style == "mixed":
        return CardRoleCounts(3 + aggressive_bonus, 2 + defensive_bonus, 1 + advanced_bonus, 2, 1, advanced_bonus, 0)
    return balanced_counts(target)


def elite_counts(weapon_style: str, role: str) -> CardRoleCounts:
    advanced_bonus = 1 if role == "advanced" else 0
    if weapon_style == "spearman":
        return CardRoleCounts(4, 2, 2, 3, 2, advanced_bonus, 0)
    if weapon_style == "blademaster":
        return CardRoleCounts(4, 3, 2, 2, 2, 1 + advanced_bonus, 0)
    if weapon_style == "firearm":
        return CardRoleCounts(4, 2, 2, 2, 3, advanced_bonus, 1)
    if weapon_style == "official":
        return CardRoleCounts(3, 3, 2, 3, 2, 1 + advanced_bonus, 0)
    if weapon_style == "mixed":
        return CardRoleCounts(4, 2, 2, 2, 2, 1 + advanced_bonus, 1)
    return CardRoleCounts(3, 3, 2, 2, 2, 1 + advanced_bonus, 0)


def boss_counts(archetype: ArchetypeRow, role: str) -> CardRoleCounts:
    phase_two_bonus = 1 if role == "phase_2" else 0
    if archetype.battle_type == "true_boss":
        return CardRoleCounts(5, 3, 3, 3 + phase_two_bonus, 3, 2 + phase_two_bonus, 1)
    if archetype.scope == "boss_true":
        return CardRoleCounts(4, 3, 2, 3, 2, 2, 1)
    return CardRoleCounts(4, 3, 2, 3, 2, 1, 1)


def exam_counts(weapon_style: str, role: str) -> CardRoleCounts:
    if role == "exam_final":
        return CardRoleCounts(4, 3, 3, 3, 2, 1, 1)
    if weapon_style == "footwork":
        return CardRoleCounts(3, 2, 3, 2, 2, 1, 0)
    if weapon_style == "blademaster":
        return CardRoleCounts(4, 3, 2, 2, 2, 1, 0)
    return CardRoleCounts(3, 3, 2, 3, 2, 1, 0)


def balanced_counts(target: int) -> CardRoleCounts:
    _ = target
    return CardRoleCounts(3, 2, 2, 2, 1, 0, 0)


def required_tags(archetype: ArchetypeRow, role: str) -> list[str]:
    tags: list[str] = []
    if archetype.weapon_style == "spearman":
        tags.extend(["weapon_spearman", "role_control", "role_break"])
    elif archetype.weapon_style == "blademaster":
        tags.extend(["weapon_blademaster", "role_approach", "role_counter"])
    elif archetype.weapon_style == "footwork":
        tags.extend(["weapon_footwork", "role_movement", "role_tempo"])
    elif archetype.weapon_style == "firearm":
        tags.extend(["weapon_firearm", "role_firearm_pressure", "role_tempo"])
    elif archetype.weapon_style == "official":
        tags.extend(["role_fundamental", "role_control"])
    elif archetype.weapon_style == "mixed":
        tags.extend(["role_mixed_weapon", "role_control", "role_pressure"])

    if archetype.scope == "big_map_elite":
        tags.append("enemy_elite")
    if archetype.scope in {"boss_normal", "boss_true"}:
        tags.extend(["boss_only", "role_boss_phase"])
    if archetype.battle_type == "true_boss":
        tags.append("true_boss_only")
    if archetype.scope == "wuzhuangyuan_exam":
        tags.extend(["exam_official", "role_fundamental"])
    tags.append(f"variant_{role}")
    return unique(tags)


def forbidden_tags(archetype: ArchetypeRow, role: str) -> list[str]:
    tags = ["player_only", "weapon_mismatch"]
    if archetype.scope == "big_map_normal":
        tags.extend(["boss_only", "true_boss_only"])
    elif archetype.scope == "big_map_elite":
        tags.append("true_boss_only")
    if archetype.scope in {"boss_normal", "boss_true"}:
        tags.append("lightness_4_required")
    if archetype.scope == "wuzhuangyuan_exam" and role == "exam_final":
        tags.append("lightness_4_required")
    return unique(tags)


def ai_hint(archetype: ArchetypeRow, role: str) -> str:
    if archetype.scope == "wuzhuangyuan_exam":
        return "test_fundamentals" if role != "exam_final" else "test_fundamentals_then_pressure"
    if archetype.scope in {"boss_normal", "boss_true"}:
        return "boss_phase_pressure" if role != "phase_2" else "boss_phase_escalation"
    if role == "aggressive":
        return "pressure_until_player_retreats"
    if role == "defensive":
        return "guard_then_break"
    if archetype.weapon_style == "spearman":
        return "hold_distance_then_thrust"
    if archetype.weapon_style == "blademaster":
        return "approach_and_counter"
    if archetype.weapon_style == "firearm":
        return "pressure_without_range_lock"
    if archetype.weapon_style == "footwork":
        return "circle_then_change_tempo"
    return "guard_then_break"


def reward_pressure(archetype: ArchetypeRow, role: str) -> str:
    _ = role
    if archetype.scope == "big_map_normal":
        return "low" if archetype.complexity_level <= 2 else "medium"
    if archetype.scope == "big_map_elite":
        return "high"
    if archetype.scope in {"boss_normal", "boss_true"}:
        return "boss"
    if archetype.scope == "wuzhuangyuan_exam":
        return "exam"
    return "medium"


def notes_for(archetype: ArchetypeRow, role: str) -> str:
    if archetype.scope == "wuzhuangyuan_exam":
        return "武状元考试卡组骨架；重基本功与制度化压力，不填具体 card_id。"
    if archetype.scope in {"boss_normal", "boss_true"}:
        return "Boss 阶段卡组骨架；轻功 4 只作为优势，不作为硬门槛，不填具体 card_id。"
    return f"敌人卡组骨架 {role} 变体；v0.3 只定义角色计数与标签约束。"


def unique(tags: list[str]) -> list[str]:
    seen: set[str] = set()
    result: list[str] = []
    for tag in tags:
        if tag and tag not in seen:
            seen.add(tag)
            result.append(tag)
    return result


def join_tags(tags: list[str]) -> str:
    return ",".join(tags)


def write_tsv(path: Path, rows: list[dict[str, str]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=OUTPUT_FIELDS, delimiter="\t", lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)


def main() -> int:
    args = parse_args()
    design_dir = Path(args.design_dir)
    out_path = Path(args.out)
    must_exist(design_dir)
    archetypes = parse_archetypes(read_tsv(design_dir / "generated_enemy_archetype_pool.tsv"))
    deck_requirements = read_tsv(design_dir / "generated_enemy_deck_requirement.tsv")
    battle_slots = read_tsv(design_dir / "generated_battle_slot_plan.tsv")
    skeletons = build_skeletons(archetypes, deck_requirements, battle_slots)
    write_tsv(out_path, [item.to_row() for item in skeletons])
    print(f"WROTE: {out_path}")
    print(f"DECK_SKELETONS: {len(skeletons)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
