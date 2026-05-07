#!/usr/bin/env python3
"""Generate Content Engine v0.2 enemy archetype pool (design-layer only)."""

from __future__ import annotations

import argparse
import csv
from dataclasses import dataclass
from pathlib import Path


OUTPUT_FIELDS = [
    "archetype_id",
    "scope",
    "route_type",
    "battle_type",
    "tier",
    "weapon_style",
    "enemy_role",
    "complexity_level",
    "expected_player_realm",
    "preferred_distance_min",
    "preferred_distance_max",
    "primary_checks",
    "secondary_checks",
    "tactic_role_ratio",
    "recommended_deck_variant_count",
    "visual_identity_hint",
    "forbidden_tags",
    "discouraged_tags",
    "source_requirement_id",
    "notes",
]

INPUT_FILES = [
    "generated_enemy_deck_requirement.tsv",
    "generated_battle_slot_plan.tsv",
    "generated_route_progression_curve.tsv",
    "generated_operation_node_requirement.tsv",
]


@dataclass(frozen=True)
class ArchetypeSpec:
    archetype_id: str
    scope: str
    route_type: str
    battle_type: str
    tier: str
    weapon_style: str
    enemy_role: str
    complexity_level: int
    expected_player_realm: str
    preferred_distance_min: int
    preferred_distance_max: int
    primary_checks: str
    secondary_checks: str
    tactic_role_ratio: str
    recommended_deck_variant_count: int
    visual_identity_hint: str
    forbidden_tags: str
    discouraged_tags: str
    source_requirement_id: str
    notes: str

    def to_row(self) -> dict[str, str]:
        return {
            "archetype_id": self.archetype_id,
            "scope": self.scope,
            "route_type": self.route_type,
            "battle_type": self.battle_type,
            "tier": self.tier,
            "weapon_style": self.weapon_style,
            "enemy_role": self.enemy_role,
            "complexity_level": str(self.complexity_level),
            "expected_player_realm": self.expected_player_realm,
            "preferred_distance_min": str(self.preferred_distance_min),
            "preferred_distance_max": str(self.preferred_distance_max),
            "primary_checks": self.primary_checks,
            "secondary_checks": self.secondary_checks,
            "tactic_role_ratio": self.tactic_role_ratio,
            "recommended_deck_variant_count": str(self.recommended_deck_variant_count),
            "visual_identity_hint": self.visual_identity_hint,
            "forbidden_tags": self.forbidden_tags,
            "discouraged_tags": self.discouraged_tags,
            "source_requirement_id": self.source_requirement_id,
            "notes": self.notes,
        }


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Generate deterministic enemy archetype pool for Content Engine v0.2.")
    parser.add_argument("--design-dir", default="data/design")
    parser.add_argument("--out", default="data/design/generated_enemy_archetype_pool.tsv")
    return parser.parse_args()


def read_tsv(path: Path) -> list[dict[str, str]]:
    with path.open("r", encoding="utf-8", newline="") as handle:
        return list(csv.DictReader(handle, delimiter="\t"))


def must_exist(design_dir: Path) -> None:
    missing = [name for name in INPUT_FILES if not (design_dir / name).exists()]
    if missing:
        raise FileNotFoundError("Missing required design inputs: " + ", ".join(str(design_dir / item) for item in missing))


def by_id(rows: list[dict[str, str]], key: str, value: str) -> dict[str, str]:
    for row in rows:
        if row.get(key) == value:
            return row
    raise KeyError(f"Missing required row where {key}={value}")


def build_specs(
    deck_requirements: list[dict[str, str]],
    battle_slots: list[dict[str, str]],
    route_curve: list[dict[str, str]],
    operation_nodes: list[dict[str, str]],
) -> list[ArchetypeSpec]:
    _ = route_curve
    _ = operation_nodes
    normal_realm = by_id(battle_slots, "battle_slot_id", "big_map_normal_pool").get("expected_player_realm", "4-8")
    elite_realm = by_id(battle_slots, "battle_slot_id", "big_map_elite_pool").get("expected_player_realm", "7-10")
    normal_boss_realm = by_id(battle_slots, "battle_slot_id", "normal_boss_01").get("expected_player_realm", "8-9")
    true_boss_1_realm = by_id(battle_slots, "battle_slot_id", "true_boss_01").get("expected_player_realm", "9-10")
    true_boss_2_realm = by_id(battle_slots, "battle_slot_id", "true_boss_02").get("expected_player_realm", "10")
    exam_realm = by_id(battle_slots, "battle_slot_id", "wz_exam_01").get("expected_player_realm", "10")

    normal_default = as_int(by_id(deck_requirements, "requirement_id", "big_map_normal"), "required_deck_count_default", 22)
    elite_default = as_int(by_id(deck_requirements, "requirement_id", "big_map_elite"), "required_deck_count_default", 8)
    exam_default = as_int(by_id(deck_requirements, "requirement_id", "wuzhuangyuan_exam"), "required_deck_count_default", 5)

    normal_variants = distribute(normal_default, 8, 2, 3)
    elite_variants = distribute(elite_default, 5, 1, 2)
    exam_variants = distribute(exam_default, 5, 1, 1)

    normal_specs = build_normal_specs(normal_realm, normal_variants)
    elite_specs = build_elite_specs(elite_realm, elite_variants)
    boss_specs = build_boss_specs(normal_boss_realm, true_boss_1_realm, true_boss_2_realm)
    exam_specs = build_exam_specs(exam_realm, exam_variants)
    return normal_specs + elite_specs + boss_specs + exam_specs


def build_normal_specs(normal_realm: str, variants: list[int]) -> list[ArchetypeSpec]:
    base = [
        ("coastal_raider_blade", "blademaster", "pressure", 2, 1, 2, "distance_control,guard_management", "burst_survival", "pressure:35,approach:25,burst:20,guard:20", "海寇刀客"),
        ("coastal_raider_spear", "spearman", "control", 2, 2, 3, "anti_approach,distance_control", "posture_pressure", "control:35,break:25,pressure:20,guard:20", "海寇枪兵"),
        ("militia_spearman", "spearman", "control", 1, 2, 3, "distance_control,anti_approach", "guard_management", "control:40,guard:25,break:20,pressure:15", "海防枪兵"),
        ("shield_blademan", "blademaster", "guard_counter", 2, 1, 2, "guard_management,burst_survival", "distance_control", "guard:40,counter:30,pressure:20,break:10", "持盾刀手"),
        ("scout_footwork", "footwork", "footwork", 3, 1, 3, "footwork_response,combo_stability", "distance_control", "footwork:35,pressure:25,control:20,guard:20", "斥候身法手"),
        ("firearm_runner", "firearm", "firearm_pressure", 3, 3, 4, "firearm_approach,distance_control", "guard_management", "firearm_pressure:40,control:30,guard:20,burst:10", "火器游击手"),
        ("hungry_garrison", "mixed", "pressure", 2, 1, 2, "posture_pressure,guard_management", "burst_survival", "pressure:30,break:30,guard:20,control:20", "饥军杂营"),
        ("corrupt_patrolman", "official", "control", 2, 1, 3, "distance_control,anti_approach", "footwork_response", "control:30,guard_counter:30,pressure:20,break:20", "军门巡哨"),
    ]
    specs: list[ArchetypeSpec] = []
    for (i, item) in enumerate(base):
        archetype_id, weapon_style, enemy_role, complexity, d_min, d_max, primary, secondary, ratio, visual = item
        specs.append(
            ArchetypeSpec(
                archetype_id=archetype_id,
                scope="big_map_normal",
                route_type="common",
                battle_type="normal",
                tier="basic" if complexity <= 2 else "advanced",
                weapon_style=weapon_style,
                enemy_role=enemy_role,
                complexity_level=complexity,
                expected_player_realm=normal_realm if i < 4 else "5-8",
                preferred_distance_min=d_min,
                preferred_distance_max=d_max,
                primary_checks=primary,
                secondary_checks=secondary,
                tactic_role_ratio=ratio,
                recommended_deck_variant_count=variants[i],
                visual_identity_hint=visual,
                forbidden_tags="no_boss_only,no_true_boss_skill,no_high_lightness_required",
                discouraged_tags="avoid_complex_combo,avoid_instant_burst",
                source_requirement_id="big_map_normal",
                notes="普通敌人 archetype；仅输出骨架，不包含具体卡组。",
            )
        )
    return specs


def build_elite_specs(elite_realm: str, variants: list[int]) -> list[ArchetypeSpec]:
    base = [
        ("elite_spear_instructor", "spearman", "control", 3, 2, 3, "distance_control,anti_approach,combo_stability", "guard_management", "control:35,break:30,guard:20,pressure:15", "京营枪术教头"),
        ("elite_blade_counter", "blademaster", "guard_counter", 4, 1, 2, "guard_management,burst_survival,posture_pressure", "distance_control", "guard_counter:35,pressure:25,burst:20,break:20", "军门刀术都头"),
        ("elite_dual_blade_raider", "mixed", "burst", 4, 1, 2, "burst_survival,footwork_response", "guard_management", "burst:35,pressure:30,footwork:20,guard:15", "双刀精锐海寇"),
        ("elite_firearm_guard", "firearm", "firearm_pressure", 3, 3, 4, "firearm_approach,distance_control", "posture_pressure", "firearm_pressure:40,control:30,guard:20,break:10", "火器营精锐"),
        ("elite_military_officer", "official", "boss_controller", 4, 1, 3, "combo_stability,distance_control,guard_management", "burst_survival", "control:30,guard_counter:25,break:25,pressure:20", "军门校尉"),
    ]
    specs: list[ArchetypeSpec] = []
    for i, item in enumerate(base):
        archetype_id, weapon_style, enemy_role, complexity, d_min, d_max, primary, secondary, ratio, visual = item
        specs.append(
            ArchetypeSpec(
                archetype_id=archetype_id,
                scope="big_map_elite",
                route_type="common",
                battle_type="elite",
                tier="elite",
                weapon_style=weapon_style,
                enemy_role=enemy_role,
                complexity_level=complexity,
                expected_player_realm=elite_realm,
                preferred_distance_min=d_min,
                preferred_distance_max=d_max,
                primary_checks=primary,
                secondary_checks=secondary,
                tactic_role_ratio=ratio,
                recommended_deck_variant_count=variants[i],
                visual_identity_hint=visual,
                forbidden_tags="no_true_boss_skill,no_high_lightness_required",
                discouraged_tags="avoid_long_range_lock",
                source_requirement_id="big_map_elite",
                notes="精英敌人 archetype；用于 3-5 场精英池。",
            )
        )
    return specs


def build_boss_specs(normal_realm: str, true_realm_1: str, true_realm_2: str) -> list[ArchetypeSpec]:
    return [
        ArchetypeSpec(
            archetype_id="normal_boss_old_case_officer",
            scope="boss_normal",
            route_type="normal",
            battle_type="boss",
            tier="boss",
            weapon_style="official",
            enemy_role="boss_controller",
            complexity_level=4,
            expected_player_realm=normal_realm,
            preferred_distance_min=1,
            preferred_distance_max=3,
            primary_checks="guard_management,posture_pressure,combo_stability",
            secondary_checks="distance_control,burst_survival",
            tactic_role_ratio="control:30,guard_counter:25,break:25,pressure:20",
            recommended_deck_variant_count=1,
            visual_identity_hint="旧案军门官",
            forbidden_tags="no_true_boss_skill,no_high_lightness_required",
            discouraged_tags="avoid_instant_burst",
            source_requirement_id="boss_normal",
            notes="普通结局 Boss；8-9 境可通，不以轻功 3-4 为门槛。",
        ),
        ArchetypeSpec(
            archetype_id="true_boss_gatekeeper",
            scope="boss_true",
            route_type="true_route",
            battle_type="boss",
            tier="boss",
            weapon_style="mixed",
            enemy_role="boss_controller",
            complexity_level=4,
            expected_player_realm=true_realm_1,
            preferred_distance_min=1,
            preferred_distance_max=3,
            primary_checks="combo_stability,guard_management,boss_phase_reading",
            secondary_checks="distance_control,posture_pressure",
            tactic_role_ratio="control:30,break:25,guard_counter:25,pressure:20",
            recommended_deck_variant_count=1,
            visual_identity_hint="真结局守门强敌",
            forbidden_tags="no_lightness_hard_gate",
            discouraged_tags="avoid_instant_burst",
            source_requirement_id="boss_true",
            notes="真结局 Boss 1；作为真 Boss 前置检查。",
        ),
        ArchetypeSpec(
            archetype_id="true_boss_hidden_commander",
            scope="boss_true",
            route_type="true_route",
            battle_type="true_boss",
            tier="boss",
            weapon_style="mixed",
            enemy_role="boss_controller",
            complexity_level=5,
            expected_player_realm=true_realm_2,
            preferred_distance_min=2,
            preferred_distance_max=4,
            primary_checks="boss_phase_reading,combo_stability,burst_survival",
            secondary_checks="distance_control,firearm_approach",
            tactic_role_ratio="control:30,pressure:25,break:25,guard_counter:20",
            recommended_deck_variant_count=1,
            visual_identity_hint="真结局隐秘统领",
            forbidden_tags="no_lightness_hard_gate",
            discouraged_tags="avoid_instant_burst",
            source_requirement_id="boss_true",
            notes="真 Boss；按武道 10 境设计，轻功 4 仅提供优势。",
        ),
    ]


def build_exam_specs(exam_realm: str, variants: list[int]) -> list[ArchetypeSpec]:
    base = [
        ("exam_capital_basic_weapon", "official", "mixed_examiner", 4, 1, 2, "exam_fundamentals,distance_control", "guard_management", "pressure:25,control:25,guard:25,break:25", "京营武备考官"),
        ("exam_capital_footwork", "footwork", "footwork", 4, 1, 3, "exam_fundamentals,footwork_response", "distance_control", "footwork:35,control:25,guard:20,pressure:20", "京营步法考官"),
        ("exam_capital_mixed_weapon", "mixed", "mixed_examiner", 4, 1, 3, "exam_fundamentals,combo_stability", "guard_management", "control:30,pressure:25,break:25,guard:20", "殿前混兵考核官"),
        ("exam_capital_duel_chain", "blademaster", "guard_counter", 4, 1, 2, "exam_fundamentals,burst_survival", "posture_pressure", "guard_counter:30,pressure:30,burst:20,control:20", "殿前连战擂主"),
        ("exam_imperial_final_examiner", "official", "boss_controller", 5, 1, 3, "exam_fundamentals,boss_phase_reading,combo_stability", "guard_management,footwork_response", "control:30,guard_counter:25,break:25,pressure:20", "殿前终试考官"),
    ]
    specs: list[ArchetypeSpec] = []
    for i, item in enumerate(base):
        archetype_id, weapon_style, enemy_role, complexity, d_min, d_max, primary, secondary, ratio, visual = item
        specs.append(
            ArchetypeSpec(
                archetype_id=archetype_id,
                scope="wuzhuangyuan_exam",
                route_type="wuzhuangyuan",
                battle_type="wuzhuangyuan_exam",
                tier="exam",
                weapon_style=weapon_style,
                enemy_role=enemy_role,
                complexity_level=complexity,
                expected_player_realm=exam_realm,
                preferred_distance_min=d_min,
                preferred_distance_max=d_max,
                primary_checks=primary,
                secondary_checks=secondary,
                tactic_role_ratio=ratio,
                recommended_deck_variant_count=variants[i],
                visual_identity_hint=visual,
                forbidden_tags="no_lightness_hard_gate,no_true_boss_skill",
                discouraged_tags="avoid_instant_burst",
                source_requirement_id="wuzhuangyuan_exam",
                notes="武状元考试 archetype；打法规整、制度化，不走海寇亡命节奏。",
            )
        )
    return specs


def distribute(total: int, count: int, minimum: int, maximum: int) -> list[int]:
    values = [minimum for _ in range(count)]
    remaining = total - sum(values)
    index = 0
    while remaining > 0 and index < count * 4:
        pos = index % count
        if values[pos] < maximum:
            values[pos] += 1
            remaining -= 1
        index += 1
    return values


def as_int(row: dict[str, str], key: str, fallback: int) -> int:
    try:
        return int(round(float((row.get(key) or "").strip())))
    except ValueError:
        return fallback


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
    deck_requirements = read_tsv(design_dir / "generated_enemy_deck_requirement.tsv")
    battle_slots = read_tsv(design_dir / "generated_battle_slot_plan.tsv")
    route_curve = read_tsv(design_dir / "generated_route_progression_curve.tsv")
    operation_nodes = read_tsv(design_dir / "generated_operation_node_requirement.tsv")
    specs = build_specs(deck_requirements, battle_slots, route_curve, operation_nodes)
    write_tsv(out_path, [item.to_row() for item in specs])
    print(f"WROTE: {out_path}")
    print(f"ARCHETYPES: {len(specs)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
