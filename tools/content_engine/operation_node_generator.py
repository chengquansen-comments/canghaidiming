#!/usr/bin/env python3
"""Generate Content Engine v0.5b operation node plan (design-layer only)."""

from __future__ import annotations

import argparse
import csv
from dataclasses import dataclass
from pathlib import Path


OUTPUT_FIELDS = [
    "operation_node_id",
    "scope",
    "route_type",
    "stage",
    "node_type",
    "node_subtype",
    "node_index",
    "availability_window",
    "expected_player_realm",
    "expected_lightness_level",
    "operation_role",
    "primary_function",
    "secondary_function",
    "resource_cost_type",
    "resource_cost_amount",
    "resource_reward_type",
    "resource_reward_amount",
    "martial_xp_reward",
    "weapon_xp_reward",
    "military_merit_reward",
    "clean_reputation_reward",
    "old_case_progress_reward",
    "lightness_reward_type",
    "lightness_cap_unlock",
    "card_service_type",
    "card_reward_pool",
    "risk_level",
    "can_prepare_boss",
    "can_trigger_lightness_breakthrough",
    "can_trigger_wuzhuangyuan_route",
    "can_support_true_ending",
    "narrative_hook_tags",
    "route_gate_tags",
    "notes",
]

INPUT_FILES = [
    "generated_operation_node_requirement.tsv",
    "generated_battle_reward_plan.tsv",
    "generated_route_progression_curve.tsv",
    "progression_numeric_config_v1_3.tsv",
]


@dataclass(frozen=True)
class OperationNode:
    operation_node_id: str
    scope: str
    route_type: str
    stage: str
    node_type: str
    node_subtype: str
    node_index: int
    availability_window: str
    expected_player_realm: str
    expected_lightness_level: str
    operation_role: str
    primary_function: str
    secondary_function: str
    resource_cost_type: str
    resource_cost_amount: int
    resource_reward_type: str
    resource_reward_amount: int
    martial_xp_reward: int
    weapon_xp_reward: int
    military_merit_reward: int
    clean_reputation_reward: int
    old_case_progress_reward: int
    lightness_reward_type: str
    lightness_cap_unlock: str
    card_service_type: str
    card_reward_pool: str
    risk_level: str
    can_prepare_boss: bool
    can_trigger_lightness_breakthrough: bool
    can_trigger_wuzhuangyuan_route: bool
    can_support_true_ending: bool
    narrative_hook_tags: str
    route_gate_tags: str
    notes: str

    def to_row(self) -> dict[str, str]:
        return {
            "operation_node_id": self.operation_node_id,
            "scope": self.scope,
            "route_type": self.route_type,
            "stage": self.stage,
            "node_type": self.node_type,
            "node_subtype": self.node_subtype,
            "node_index": str(self.node_index),
            "availability_window": self.availability_window,
            "expected_player_realm": self.expected_player_realm,
            "expected_lightness_level": self.expected_lightness_level,
            "operation_role": self.operation_role,
            "primary_function": self.primary_function,
            "secondary_function": self.secondary_function,
            "resource_cost_type": self.resource_cost_type,
            "resource_cost_amount": str(self.resource_cost_amount),
            "resource_reward_type": self.resource_reward_type,
            "resource_reward_amount": str(self.resource_reward_amount),
            "martial_xp_reward": str(self.martial_xp_reward),
            "weapon_xp_reward": str(self.weapon_xp_reward),
            "military_merit_reward": str(self.military_merit_reward),
            "clean_reputation_reward": str(self.clean_reputation_reward),
            "old_case_progress_reward": str(self.old_case_progress_reward),
            "lightness_reward_type": self.lightness_reward_type,
            "lightness_cap_unlock": self.lightness_cap_unlock,
            "card_service_type": self.card_service_type,
            "card_reward_pool": self.card_reward_pool,
            "risk_level": self.risk_level,
            "can_prepare_boss": to_bool(self.can_prepare_boss),
            "can_trigger_lightness_breakthrough": to_bool(self.can_trigger_lightness_breakthrough),
            "can_trigger_wuzhuangyuan_route": to_bool(self.can_trigger_wuzhuangyuan_route),
            "can_support_true_ending": to_bool(self.can_support_true_ending),
            "narrative_hook_tags": self.narrative_hook_tags,
            "route_gate_tags": self.route_gate_tags,
            "notes": self.notes,
        }


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Generate deterministic operation node plan for Content Engine v0.5b.")
    parser.add_argument("--design-dir", default="data/design")
    parser.add_argument("--out", default="data/design/generated_operation_node_plan.tsv")
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


def to_bool(value: bool) -> str:
    return "true" if value else "false"


def operation_default_count(requirement_rows: list[dict[str, str]]) -> int:
    for row in requirement_rows:
        if row.get("requirement_id") == "big_map_operation_total":
            raw = row.get("actual_node_count_default", "")
            try:
                return int(round(float(raw.strip())))
            except ValueError:
                return 8
    return 8


def operation_max_count(requirement_rows: list[dict[str, str]]) -> int:
    for row in requirement_rows:
        if row.get("requirement_id") == "big_map_operation_total":
            raw = row.get("actual_node_count_max", "")
            try:
                return int(round(float(raw.strip())))
            except ValueError:
                return 10
    return 10


def build_nodes(default_count: int, target_total: int) -> list[OperationNode]:
    # Base 8 nodes match v0.1.1 default operation-node count.
    base_nodes: list[OperationNode] = [
        OperationNode(
            "op_training_upgrade_01", "big_map", "common", "big_map_early", "training", "校场", 1, "M01-M05",
            "4-6", "1", "deck_upgrade", "upgrade_or_remove_card", "basic_form_refinement",
            "silver", 30, "upgrade_card", 1, 1, 1, 0, 0, 0, "practice", "none", "upgrade", "weapon_common",
            "low", False, False, False, False, "master_teaching", "none",
            "基础构筑强化节点；小幅成长，不替代战斗主收益。",
        ),
        OperationNode(
            "op_camp_rest_01", "big_map", "common", "big_map_early", "camp", "行营", 2, "M01-M05",
            "4-6", "1", "recovery", "heal_and_stabilize", "small_supply_refill",
            "supply", 1, "heal", 2, 0, 0, 0, 0, 0, "none", "none", "none", "none",
            "low", False, False, False, False, "camp_rest", "none",
            "恢复节点，几乎不给成长收益。",
        ),
        OperationNode(
            "op_military_gate_merit_01", "big_map", "normal", "big_map_mid", "military_gate", "军门", 3, "M06-M10",
            "6-8", "1-2", "military_merit", "gain_military_merit_with_reputation_risk", "route_prestige_check",
            "clean_reputation", 1, "title", 1, 1, 0, 2, -1, 0, "none", "none", "none", "none",
            "medium", False, False, False, False, "military_gate", "high_military_merit",
            "军功提升伴随清望代价，避免无脑正收益。",
        ),
        OperationNode(
            "op_weapon_service_01", "big_map", "common", "big_map_mid", "weapon_service", "器械所", 4, "M06-M10",
            "6-8", "1-2", "weapon_upgrade", "upgrade_weapon_routine", "tune_weapon_package",
            "silver", 40, "weapon_upgrade", 1, 1, 2, 0, 0, 0, "practice", "none", "transform", "weapon_uncommon",
            "medium", False, False, False, False, "weapon_service", "none",
            "兵器维护节点，偏武器成长不偏武境暴涨。",
        ),
        OperationNode(
            "op_master_teaching_01", "big_map", "optional", "big_map_mid", "master", "师门", 5, "M06-M10",
            "6-8", "2", "deck_upgrade", "advanced_form_teaching", "discipline_and_tempo",
            "silver", 50, "upgrade_card", 1, 2, 1, 0, 1, 0, "level_up", "cap_2", "choose_card", "weapon_or_generic_uncommon",
            "medium", False, False, False, True, "master_teaching", "true_route_candidate",
            "中段强化点，可支持真路线准备但不直接开高轻功。",
        ),
        OperationNode(
            "op_market_rumor_01", "big_map", "common", "big_map_mid", "market", "市井", 6, "M06-M10",
            "6-8", "1-2", "clean_reputation", "trade_and_collect_rumors", "minor_clue_exchange",
            "silver", 20, "clue", 1, 0, 0, 0, 1, 0, "none", "none", "remove", "generic_common",
            "low", False, False, False, False, "market_rumor", "none",
            "清望和线索补给点，不给高武道收益。",
        ),
        OperationNode(
            "op_old_case_clue_01", "big_map", "true_route", "big_map_late", "old_case", "旧案", 7, "M11-M15",
            "8-10", "2", "old_case_progress", "trade_clean_reputation_for_clue", "unlock_hidden_case_branch",
            "old_case_risk", 1, "clue", 2, 1, 0, 1, -1, 2, "practice", "cap_2", "none", "none",
            "route", False, False, False, True, "old_case", "old_case_progress,true_route_candidate",
            "旧案推进节点，风险更高，推进值明确大于 0。",
        ),
        OperationNode(
            "op_boss_prepare_01", "big_map", "normal", "boss_prepare", "boss_prepare", "休整", 8, "M13-M15",
            "8-10", "2", "boss_preparation", "prepare_final_boss", "heal_and_refit",
            "supply", 2, "heal", 2, 0, 1, 1, 0, 0, "none", "none", "final_upgrade", "weapon_or_generic_uncommon",
            "route", True, False, False, False, "boss_prepare", "none",
            "Boss 前准备节点，给整备不给大量武道成长。",
        ),
    ]

    optional_nodes: list[OperationNode] = [
        OperationNode(
            "op_lightness_encounter_01", "big_map", "optional", "big_map_late", "lightness_encounter", "身法奇遇", 9, "M11-M15",
            "8-10", "2-3", "lightness_breakthrough", "unlock_lightness_cap", "rare_body_movement_trial",
            "health", 1, "route_flag", 1, 1, 0, 0, 0, 0, "cap_unlock", "cap_3", "none", "none",
            "rare", False, True, False, False, "lightness_encounter", "lightness_cap_3",
            "稀缺轻功节点，只开到 cap_3，不做常态化收益。",
        ),
        OperationNode(
            "op_wuzhuangyuan_offer_01", "big_map", "wuzhuangyuan", "big_map_late", "military_gate", "军门", 10, "M11-M15",
            "9-10", "2-3", "route_choice", "offer_wuzhuangyuan_path", "military_merit_verification",
            "route_lock", 1, "route_flag", 1, 0, 0, 0, 0, 0, "none", "none", "none", "none",
            "route", False, False, True, False, "wuzhuangyuan_offer,military_gate", "high_military_merit,wuzhuangyuan_candidate",
            "武状元候选分流节点，依赖高军功标记。",
        ),
    ]

    selected_base = base_nodes[: min(len(base_nodes), max(1, default_count))]
    remaining = max(0, target_total - len(selected_base))
    return selected_base + optional_nodes[: min(len(optional_nodes), remaining)]


def main() -> int:
    args = parse_args()
    design_dir = Path(args.design_dir)
    out_path = Path(args.out)
    must_exist(design_dir)

    requirement_rows = read_tsv(design_dir / "generated_operation_node_requirement.tsv")
    _ = read_tsv(design_dir / "generated_battle_reward_plan.tsv")
    _ = read_tsv(design_dir / "generated_route_progression_curve.tsv")
    _ = read_tsv(design_dir / "progression_numeric_config_v1_3.tsv")

    default_nodes = operation_default_count(requirement_rows)
    max_nodes = operation_max_count(requirement_rows)
    target_total = min(max_nodes, default_nodes + 2)
    nodes = build_nodes(default_nodes, target_total)
    write_tsv(out_path, [node.to_row() for node in nodes])

    print(f"WROTE: {out_path}")
    print(f"OPERATION_NODES: {len(nodes)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
