#!/usr/bin/env python3
"""Build Content Engine v0.1 derived planning TSVs."""

from __future__ import annotations

import argparse
import csv
from pathlib import Path

from progression_config_loader import ProgressionConfig, load_config, write_minimal_sample_config


BATTLE_SLOT_FIELDS = [
    "battle_slot_id",
    "stage",
    "route_type",
    "battle_type",
    "slot_index",
    "min_count",
    "default_count",
    "max_count",
    "expected_player_realm",
    "expected_lightness_level",
    "enemy_pool_scope",
    "is_fixed",
    "notes",
]

ENEMY_REQUIREMENT_FIELDS = [
    "requirement_id",
    "scope",
    "route_type",
    "battle_type",
    "actual_battle_count_min",
    "actual_battle_count_default",
    "actual_battle_count_max",
    "pool_multiplier",
    "required_deck_count_min",
    "required_deck_count_default",
    "required_deck_count_max",
    "recommended_archetype_count",
    "recommended_visual_identity_count",
    "notes",
]

ROUTE_CURVE_FIELDS = [
    "route",
    "checkpoint",
    "battle_count_cumulative",
    "martial_xp_min",
    "martial_xp_default",
    "martial_xp_max",
    "expected_realm_min",
    "expected_realm_default",
    "expected_realm_max",
    "expected_lightness_min",
    "expected_lightness_default",
    "expected_lightness_max",
    "can_reach_realm_10",
    "can_unlock_true_ending",
    "can_unlock_wuzhuangyuan",
    "notes",
]

OPERATION_NODE_FIELDS = [
    "requirement_id",
    "scope",
    "route_type",
    "node_type",
    "actual_node_count_min",
    "actual_node_count_default",
    "actual_node_count_max",
    "ratio_min",
    "ratio_default",
    "ratio_max",
    "recommended_subtypes",
    "notes",
]

DEFAULT_THRESHOLDS = {1: 0, 2: 8, 3: 18, 4: 30, 5: 44, 6: 60, 7: 78, 8: 98, 9: 120, 10: 145}


def build_battle_slot_plan(config: ProgressionConfig) -> list[dict[str, str]]:
    normal_min = config.integer("big_map_elite_route_normal_battles", default=10)
    normal_default = config.integer("big_map_standard_route_normal_battles", default=11)
    normal_max = config.integer("big_map_normal_route_normal_battles", default=12)
    elite_min = config.integer("big_map_elite_battle_count", "min_value", 3)
    elite_default = config.integer("big_map_elite_battle_count", "default_value", 4)
    elite_max = config.integer("big_map_elite_battle_count", "max_value", 5)

    rows = [
        slot("prologue_01", "prologue", "common", "tutorial", 1, 1, 1, 1, "1", "0", "tutorial", True, "序章教学 / 剧情战。"),
        slot("wuju_weapon_01", "wuju", "common", "weapon_trial", 1, 1, 1, 1, "2", "0-1", "wuju_weapon", True, "长枪兵器试。"),
        slot("wuju_weapon_02", "wuju", "common", "weapon_trial", 2, 1, 1, 1, "2-3", "0-1", "wuju_weapon", True, "单刀兵器试。"),
        slot("wuju_exam_01", "wuju", "common", "exam", 3, 1, 1, 1, "3", "1", "wuju_exam", True, "步法 / 距离考核。"),
        slot("wuju_exam_02", "wuju", "common", "exam", 4, 1, 1, 1, "3", "1", "wuju_exam", True, "兵器 / 招式考核。"),
        slot("wuju_exam_03", "wuju", "common", "exam", 5, 1, 1, 1, "3-4", "1", "wuju_exam", True, "对人战考核。"),
        slot("big_map_normal_pool", "big_map", "common", "normal", 1, normal_min, normal_default, normal_max, "4-8", "1-2", "big_map_normal", False, "大地图普通战池行，未来可展开为候选 slot。"),
        slot("big_map_elite_pool", "big_map", "common", "elite", 2, elite_min, elite_default, elite_max, "7-10", "1-2", "big_map_elite", False, "大地图精英战池行，控制 20%-30% 默认比例。"),
        slot("normal_boss_01", "ending_normal", "normal", "boss", 1, 1, 1, 1, "8-9", "1-2", "boss_normal", True, "普通结局 Boss，8-9 境可通。"),
        slot("true_boss_01", "ending_true", "true_route", "boss", 1, 1, 1, 1, "9-10", "2-3", "boss_true", True, "真结局 Boss 1。"),
        slot("true_boss_02", "ending_true", "true_route", "true_boss", 2, 1, 1, 1, "10", "2-3", "boss_true", True, "真 Boss，按武道 10 境设计。"),
    ]
    for index in range(1, 6):
        rows.append(
            slot(
                f"wz_exam_{index:02d}",
                "wuzhuangyuan",
                "wuzhuangyuan",
                "wuzhuangyuan_exam",
                index,
                1,
                1,
                1,
                "10",
                "2-4",
                "wuzhuangyuan_exam",
                True,
                "武状元回京考试固定战斗。",
            )
        )
    return rows


def build_enemy_deck_requirement(config: ProgressionConfig) -> list[dict[str, str]]:
    multiplier = config.number("big_map_pool_multiplier", default=2.0)
    archetype_total = config.integer("big_map_archetype_count", default=12)
    visual_total = config.integer("big_map_visual_identity_count", default=14)
    return [
        requirement("big_map_normal", "big_map_normal", "common", "normal", 10, 11, 12, multiplier, 20, 22, 24, 8, 10, "普通敌人候选池，按约 2 倍体验量准备。"),
        requirement("big_map_elite", "big_map_elite", "common", "elite", 3, 4, 5, multiplier, 6, 8, 10, 4, 6, "精英敌人候选池，默认 8 个 deck。"),
        requirement("big_map_total", "big_map", "common", "mixed", 14, 15, 16, multiplier, 28, 30, 32, archetype_total, visual_total, "大地图总候选池，约为实际体验战斗数 2 倍。"),
        requirement("boss_normal", "boss_normal", "normal", "boss", 1, 1, 1, 1.0, 1, 1, 1, 1, 1, "Boss 不走 2 倍随机池。"),
        requirement("boss_true", "boss_true", "true_route", "boss", 2, 2, 2, 1.0, 2, 2, 2, 2, 2, "真结局两个 Boss deck。"),
        requirement("wuzhuangyuan_exam", "wuzhuangyuan_exam", "wuzhuangyuan", "wuzhuangyuan_exam", 5, 5, 5, 1.0, 5, 5, 5, 5, 3, "武状元路线固定考试，不走 2 倍池。"),
    ]


def build_route_progression_curve(config: ProgressionConfig) -> list[dict[str, str]]:
    thresholds = load_thresholds(config)
    pre_big_map = config.integer("curve_pre_big_map_martial_xp_total", default=32)
    normal_total = config.integer("curve_normal_route_martial_xp_total", default=140)
    elite_default = config.integer("curve_standard_route_martial_xp_total", default=147)
    true_boss_1 = config.integer("curve_elite_route_after_boss1_martial_xp", default=154)
    true_final = true_boss_1 + config.integer("reward_true_boss_final_martial_xp", default=16)
    wz_exam_gain_default = 50
    return [
        curve("normal", "normal_after_wuju", 6, pre_big_map, pre_big_map, pre_big_map, thresholds, 0, 1, 1, False, False, False, "序章 + 武举线结束，进入大地图前。"),
        curve("normal", "normal_after_big_map", 21, 128, 128, 128, thresholds, 1, 2, 2, False, False, False, "普通路线大地图结束，目标 8-9 境。"),
        curve("normal", "normal_after_boss", 22, normal_total, normal_total, normal_total, thresholds, 1, 2, 2, False, False, False, "普通结局完成，最终 8-9 境。"),
        curve("elite", "elite_after_big_map", 21, 142, elite_default, 154, thresholds, 2, 2, 2, True, True, False, "精英路线大地图后接近或达到 10 境。"),
        curve("true_route", "true_after_boss_1", 22, true_boss_1, true_boss_1, true_boss_1, thresholds, 2, 2, 3, True, True, False, "真结局 Boss 1 后稳定 10 境。"),
        curve("true_route", "true_after_true_boss", 23, true_final, true_final, true_final, thresholds, 2, 3, 3, True, True, False, "真 Boss 按 10 境设计；轻功 4 不是硬门槛。"),
        curve("wuzhuangyuan", "wuzhuangyuan_before_exam", 21, 145, true_boss_1, 166, thresholds, 2, 3, 4, True, True, True, "触发条件：武境 10 + 军功高；轻功 4 只来自奇遇或特殊标记。"),
        curve("wuzhuangyuan", "wuzhuangyuan_after_exam", 26, 185, true_boss_1 + wz_exam_gain_default, 226, thresholds, 2, 3, 4, True, True, True, "回京考试 5 战后获得武状元特殊结局。"),
    ]

def build_operation_node_requirement(config: ProgressionConfig) -> list[dict[str, str]]:
    combat_min = config.integer("big_map_combat_nodes", "min_value", 14)
    combat_default = config.integer("big_map_combat_nodes", "default_value", 15)
    combat_max = config.integer("big_map_combat_nodes", "max_value", 16)
    operation_min = config.integer("big_map_operation_nodes", "min_value", 7)
    operation_default = config.integer("big_map_operation_nodes", "default_value", 8)
    operation_max = config.integer("big_map_operation_nodes", "max_value", 10)
    total_min = config.integer("big_map_total_nodes", "min_value", 22)
    total_default = config.integer("big_map_total_nodes", "default_value", 23)
    total_max = config.integer("big_map_total_nodes", "max_value", 26)
    ratio_min = config.number("big_map_operation_ratio", "min_value", 0.30)
    ratio_default = config.number("big_map_operation_ratio", "default_value", 0.348)
    ratio_max = config.number("big_map_operation_ratio", "max_value", 0.40)
    subtype_text = "校场|行营|军门|器械所|师门|市井|旧案|身法奇遇|休整"
    return [
        operation_requirement(
            "big_map_operation_total",
            "big_map",
            "common",
            "operation_total",
            operation_min,
            operation_default,
            operation_max,
            ratio_min,
            ratio_default,
            ratio_max,
            subtype_text,
            "经营 / 事件 / 修行节点需求，覆盖 30%-40% 占比。",
        ),
        operation_requirement(
            "big_map_combat_total_reference",
            "big_map",
            "common",
            "combat_reference",
            combat_min,
            combat_default,
            combat_max,
            0.0,
            0.0,
            0.0,
            "战斗",
            "大地图战斗节点基线，供混排与节奏校验。",
        ),
        operation_requirement(
            "big_map_total_node_reference",
            "big_map",
            "common",
            "total_node_reference",
            total_min,
            total_default,
            total_max,
            0.0,
            0.0,
            0.0,
            "战斗+经营",
            "大地图总经过节点，来自战斗节点和经营节点汇总。",
        ),
    ]


def load_thresholds(config: ProgressionConfig) -> dict[int, int]:
    thresholds: dict[int, int] = {}
    for realm, fallback in DEFAULT_THRESHOLDS.items():
        config_id = f"martial_realm_{realm}_xp_threshold"
        thresholds[realm] = config.integer(config_id, default=fallback)
    return thresholds


def realm_for_xp(xp: int, thresholds: dict[int, int]) -> int:
    current = 1
    for realm, threshold in sorted(thresholds.items()):
        if xp >= threshold:
            current = realm
    return current


def slot(
    battle_slot_id: str,
    stage: str,
    route_type: str,
    battle_type: str,
    slot_index: int,
    min_count: int,
    default_count: int,
    max_count: int,
    expected_realm: str,
    expected_lightness: str,
    enemy_pool_scope: str,
    is_fixed: bool,
    notes: str,
) -> dict[str, str]:
    return {
        "battle_slot_id": battle_slot_id,
        "stage": stage,
        "route_type": route_type,
        "battle_type": battle_type,
        "slot_index": str(slot_index),
        "min_count": str(min_count),
        "default_count": str(default_count),
        "max_count": str(max_count),
        "expected_player_realm": expected_realm,
        "expected_lightness_level": expected_lightness,
        "enemy_pool_scope": enemy_pool_scope,
        "is_fixed": "TRUE" if is_fixed else "FALSE",
        "notes": notes,
    }


def requirement(
    requirement_id: str,
    scope: str,
    route_type: str,
    battle_type: str,
    battle_min: int,
    battle_default: int,
    battle_max: int,
    multiplier: float,
    deck_min: int,
    deck_default: int,
    deck_max: int,
    archetypes: int,
    visuals: int,
    notes: str,
) -> dict[str, str]:
    return {
        "requirement_id": requirement_id,
        "scope": scope,
        "route_type": route_type,
        "battle_type": battle_type,
        "actual_battle_count_min": str(battle_min),
        "actual_battle_count_default": str(battle_default),
        "actual_battle_count_max": str(battle_max),
        "pool_multiplier": f"{multiplier:.1f}",
        "required_deck_count_min": str(deck_min),
        "required_deck_count_default": str(deck_default),
        "required_deck_count_max": str(deck_max),
        "recommended_archetype_count": str(archetypes),
        "recommended_visual_identity_count": str(visuals),
        "notes": notes,
    }


def curve(
    route: str,
    checkpoint: str,
    battle_count: int,
    xp_min: int,
    xp_default: int,
    xp_max: int,
    thresholds: dict[int, int],
    lightness_min: int,
    lightness_default: int,
    lightness_max: int,
    can_reach_10: bool,
    can_unlock_true: bool,
    can_unlock_wz: bool,
    notes: str,
) -> dict[str, str]:
    return {
        "route": route,
        "checkpoint": checkpoint,
        "battle_count_cumulative": str(battle_count),
        "martial_xp_min": str(xp_min),
        "martial_xp_default": str(xp_default),
        "martial_xp_max": str(xp_max),
        "expected_realm_min": str(realm_for_xp(xp_min, thresholds)),
        "expected_realm_default": str(realm_for_xp(xp_default, thresholds)),
        "expected_realm_max": str(realm_for_xp(xp_max, thresholds)),
        "expected_lightness_min": str(lightness_min),
        "expected_lightness_default": str(lightness_default),
        "expected_lightness_max": str(lightness_max),
        "can_reach_realm_10": "TRUE" if can_reach_10 else "FALSE",
        "can_unlock_true_ending": "TRUE" if can_unlock_true else "FALSE",
        "can_unlock_wuzhuangyuan": "TRUE" if can_unlock_wz else "FALSE",
        "notes": notes,
    }

def operation_requirement(
    requirement_id: str,
    scope: str,
    route_type: str,
    node_type: str,
    node_min: int,
    node_default: int,
    node_max: int,
    ratio_min: float,
    ratio_default: float,
    ratio_max: float,
    recommended_subtypes: str,
    notes: str,
) -> dict[str, str]:
    return {
        "requirement_id": requirement_id,
        "scope": scope,
        "route_type": route_type,
        "node_type": node_type,
        "actual_node_count_min": str(node_min),
        "actual_node_count_default": str(node_default),
        "actual_node_count_max": str(node_max),
        "ratio_min": f"{ratio_min:.3f}",
        "ratio_default": f"{ratio_default:.3f}",
        "ratio_max": f"{ratio_max:.3f}",
        "recommended_subtypes": recommended_subtypes,
        "notes": notes,
    }


def write_tsv(path: Path, fieldnames: list[str], rows: list[dict[str, str]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames, delimiter="\t", lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)


def build_outputs(config_path: Path, out_dir: Path) -> list[Path]:
    if not config_path.exists():
        write_minimal_sample_config(config_path)
        print(f"WARN: config missing; wrote minimal runnable sample: {config_path}")
    config = load_config(config_path)
    outputs = [
        (out_dir / "generated_battle_slot_plan.tsv", BATTLE_SLOT_FIELDS, build_battle_slot_plan(config)),
        (out_dir / "generated_enemy_deck_requirement.tsv", ENEMY_REQUIREMENT_FIELDS, build_enemy_deck_requirement(config)),
        (out_dir / "generated_route_progression_curve.tsv", ROUTE_CURVE_FIELDS, build_route_progression_curve(config)),
        (out_dir / "generated_operation_node_requirement.tsv", OPERATION_NODE_FIELDS, build_operation_node_requirement(config)),
    ]
    for path, fields, rows in outputs:
        write_tsv(path, fields, rows)
    return [path for path, _, _ in outputs]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Build Content Engine v0.1 progression planning tables.")
    parser.add_argument("--config", default="data/design/progression_numeric_config_v1_3.tsv")
    parser.add_argument("--out-dir", default="data/design")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    outputs = build_outputs(Path(args.config), Path(args.out_dir))
    for output in outputs:
        print(f"WROTE: {output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
