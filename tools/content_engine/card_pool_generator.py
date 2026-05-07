#!/usr/bin/env python3
"""Generate Content Engine v0.4a card pool (design-layer only)."""

from __future__ import annotations

import argparse
import csv
from dataclasses import dataclass
from pathlib import Path


OUTPUT_FIELDS = [
    "card_id",
    "display_name",
    "card_class",
    "weapon_style",
    "weapon_requirement",
    "is_generic",
    "rarity",
    "tactic_role",
    "deck_role",
    "min_distance",
    "max_distance",
    "preferred_distance",
    "momentum_cost",
    "gain_momentum",
    "break_momentum",
    "damage",
    "guard",
    "self_move_after",
    "target_push_after",
    "target_pull_after",
    "move_condition",
    "tags",
    "combo_tags",
    "ai_usage_hint",
    "power_budget",
    "budget_target",
    "budget_delta",
    "implementation_status",
    "source_grammar",
    "notes",
]

INPUT_FILES = [
    "generated_enemy_deck_skeleton.tsv",
    "generated_enemy_archetype_pool.tsv",
    "generated_enemy_deck_requirement.tsv",
]

WEAPON_REQUIREMENT_BY_STYLE = {
    "generic": "none",
    "spearman": "spearman",
    "blademaster": "blademaster",
    "firearm": "firearm",
    "footwork": "none",
    "official": "official",
    "mixed": "none",
    "boss": "boss_only",
}


@dataclass(frozen=True)
class CardSeed:
    card_id: str
    display_name: str
    card_class: str
    weapon_style: str
    rarity: str
    tactic_role: str
    deck_role: str
    min_distance: int
    max_distance: int
    preferred_distance: int
    momentum_cost: int
    gain_momentum: int
    break_momentum: int
    damage: int
    guard: int
    self_move_after: int
    target_push_after: int
    target_pull_after: int
    move_condition: str
    role_tag: str
    ai_tag: str
    combo_tags: str
    ai_usage_hint: str
    implementation_status: str
    notes: str

    def to_row(self, source_grammar: str) -> dict[str, str]:
        power_budget = effect_budget(self.gain_momentum, self.break_momentum, self.damage, self.guard)
        budget_target = self.momentum_cost * 4
        budget_delta = power_budget - budget_target
        return {
            "card_id": self.card_id,
            "display_name": self.display_name,
            "card_class": self.card_class,
            "weapon_style": self.weapon_style,
            "weapon_requirement": WEAPON_REQUIREMENT_BY_STYLE.get(self.weapon_style, "none"),
            "is_generic": "true" if self.weapon_style == "generic" else "false",
            "rarity": self.rarity,
            "tactic_role": self.tactic_role,
            "deck_role": self.deck_role,
            "min_distance": str(self.min_distance),
            "max_distance": str(self.max_distance),
            "preferred_distance": str(self.preferred_distance),
            "momentum_cost": str(self.momentum_cost),
            "gain_momentum": str(self.gain_momentum),
            "break_momentum": str(self.break_momentum),
            "damage": str(self.damage),
            "guard": str(self.guard),
            "self_move_after": str(self.self_move_after),
            "target_push_after": str(self.target_push_after),
            "target_pull_after": str(self.target_pull_after),
            "move_condition": self.move_condition,
            "tags": build_tags(self.weapon_style, self.role_tag, self.deck_role, self.ai_tag),
            "combo_tags": self.combo_tags,
            "ai_usage_hint": self.ai_usage_hint,
            "power_budget": str(power_budget),
            "budget_target": str(budget_target),
            "budget_delta": str(budget_delta),
            "implementation_status": self.implementation_status,
            "source_grammar": source_grammar,
            "notes": budget_notes(self.notes, budget_delta),
        }


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Generate deterministic design-layer card pool for Content Engine v0.4a.")
    parser.add_argument("--design-dir", default="data/design")
    parser.add_argument("--out", default="data/design/generated_card_pool.tsv")
    return parser.parse_args()


def must_exist(design_dir: Path) -> None:
    missing = [name for name in INPUT_FILES if not (design_dir / name).exists()]
    if missing:
        paths = ", ".join(str(design_dir / item) for item in missing)
        raise FileNotFoundError(f"Missing required design inputs: {paths}")


def read_tsv(path: Path) -> list[dict[str, str]]:
    with path.open("r", encoding="utf-8", newline="") as handle:
        return list(csv.DictReader(handle, delimiter="\t"))


def write_tsv(path: Path, rows: list[dict[str, str]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=OUTPUT_FIELDS, delimiter="\t", lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)


def effect_budget(gain_momentum: int, break_momentum: int, damage: int, guard: int) -> int:
    return gain_momentum * 2 + break_momentum * 2 + damage + guard


def build_tags(weapon_style: str, role_tag: str, deck_role: str, ai_tag: str) -> str:
    return ",".join(
        [
            f"weapon_{weapon_style}",
            f"role_{role_tag}",
            f"deck_{deck_role}",
            f"ai_{ai_tag}",
        ]
    )


def budget_notes(notes: str, budget_delta: int) -> str:
    if abs(budget_delta) >= 3:
        return f"{notes} budget_delta={budget_delta} due to role identity."
    return notes


def resolve_grammar_source(repo_root: Path) -> str:
    grammar_path = repo_root / "docs" / "COMBAT_CARD_GRAMMAR_V1.md"
    if grammar_path.exists():
        return "docs/COMBAT_CARD_GRAMMAR_V1.md"
    return "content_engine_v0_4a_internal_template"


def coverage_note(
    deck_skeletons: list[dict[str, str]],
    archetypes: list[dict[str, str]],
    requirements: list[dict[str, str]],
) -> str:
    _ = archetypes
    _ = requirements
    deck_rows = len(deck_skeletons)
    return f"derived_for_v0_4a_deck_skeleton_coverage={deck_rows}"


def build_pool(base_note: str) -> list[CardSeed]:
    pool: list[CardSeed] = []
    pool.extend(generic_cards(base_note))
    pool.extend(spearman_cards(base_note))
    pool.extend(blademaster_cards(base_note))
    pool.extend(firearm_cards(base_note))
    pool.extend(footwork_cards(base_note))
    pool.extend(official_cards(base_note))
    pool.extend(boss_cards(base_note))
    return pool


def generic_cards(base_note: str) -> list[CardSeed]:
    return [
        CardSeed("generic_strike", "平击", "attack", "generic", "common", "opener", "attack", 1, 2, 1, 1, 1, 0, 2, 0, 0, 0, 0, "on_hit", "opener", "stable", "combo_opener", "stable_opening_poke", "data_ready", base_note),
        CardSeed("generic_forward_press", "逼步压击", "attack", "generic", "common", "pressure", "attack", 1, 2, 1, 1, 0, 1, 2, 0, 1, 0, 0, "on_hit", "pressure", "press", "combo_bridge", "step_in_then_pressure", "design_only", base_note),
        CardSeed("generic_guard", "稳架", "guard", "generic", "common", "guard", "guard", 1, 3, 2, 1, 1, 0, 0, 3, 0, 0, 0, "none", "guard", "stabilize", "", "guard_when_under_pressure", "data_ready", base_note),
        CardSeed("generic_counter_guard", "守中反击", "guard", "generic", "uncommon", "counter", "guard", 1, 2, 1, 2, 0, 1, 1, 3, 0, 0, 0, "on_hit", "counter", "counter", "combo_bridge", "guard_then_counter_cut", "design_only", base_note),
        CardSeed("generic_step_back", "后撤", "movement", "generic", "common", "retreat", "movement", 1, 3, 2, 0, 1, 0, 0, 1, -1, 0, 0, "always", "retreat", "disengage", "", "retreat_and_reset_tempo", "data_ready", base_note),
        CardSeed("generic_side_step", "侧闪换位", "movement", "generic", "common", "approach", "movement", 1, 2, 1, 1, 1, 0, 0, 1, 1, 0, 0, "always", "approach", "tempo", "combo_bridge", "step_to_better_angle", "design_only", base_note),
        CardSeed("generic_posture_tap", "点削", "posture_break", "generic", "common", "break", "posture_break", 1, 2, 1, 1, 0, 1, 1, 0, 0, 0, 0, "on_hit", "break", "chip", "", "chip_break_without_overburst", "design_only", base_note),
        CardSeed("generic_guard_split", "拆架试探", "posture_break", "generic", "uncommon", "punish", "posture_break", 1, 2, 1, 2, 0, 2, 1, 0, 0, 0, 0, "on_hit", "break", "punish", "combo_bridge", "punish_high_guard_targets", "design_only", base_note),
        CardSeed("generic_recover", "调息", "tempo", "generic", "common", "recovery", "tempo", 1, 3, 2, 0, 2, 0, 0, 1, 0, 0, 0, "none", "recovery", "reset", "", "recover_momentum_not_damage", "data_ready", base_note),
        CardSeed("generic_tempo_shift", "换拍", "tempo", "generic", "uncommon", "combo_bridge", "tempo", 1, 2, 1, 1, 1, 0, 1, 1, 0, 0, 0, "on_hit", "tempo", "setup", "combo_bridge", "tempo_link_for_followup", "design_only", base_note),
        CardSeed("generic_link_cut", "衔接斩", "combo", "generic", "uncommon", "combo_bridge", "combo", 1, 2, 1, 1, 0, 1, 2, 0, 0, 0, 0, "on_hit", "combo_bridge", "link", "combo_bridge", "bridge_between_opener_and_finisher", "design_only", base_note),
        CardSeed("generic_signature_setup", "整势起手", "special", "generic", "special", "recovery", "special", 1, 3, 2, 1, 2, 0, 0, 2, 0, 0, 0, "none", "recovery", "setup", "", "special_setup_without_weapon_identity_overlap", "design_only", base_note),
    ]


def spearman_cards(base_note: str) -> list[CardSeed]:
    return [
        CardSeed("spear_line_thrust", "中平长刺", "attack", "spearman", "common", "poke", "attack", 2, 3, 2, 1, 1, 1, 2, 0, 0, 0, 0, "on_hit", "control", "hold_distance", "combo_opener", "hold_distance_then_thrust", "data_ready", base_note),
        CardSeed("spear_long_poke", "长杆点刺", "attack", "spearman", "common", "poke", "attack", 2, 3, 3, 1, 1, 0, 2, 0, 0, 0, 0, "on_hit", "poke", "chip", "", "safe_midrange_poke", "design_only", base_note),
        CardSeed("spear_pressure_jab", "连刺压步", "attack", "spearman", "uncommon", "pressure", "attack", 2, 3, 2, 2, 0, 1, 3, 0, 0, 0, 0, "on_hit", "pressure", "press", "combo_bridge", "pressure_without_full_burst", "design_only", base_note),
        CardSeed("spear_push_cut", "推杆截势", "posture_break", "spearman", "common", "break", "posture_break", 2, 3, 2, 1, 0, 2, 1, 0, 0, 1, 0, "on_hit", "break", "deny_approach", "", "push_and_break_posture", "data_ready", base_note),
        CardSeed("spear_deny_entry", "封门拒进", "guard", "spearman", "uncommon", "counter", "guard", 2, 3, 2, 1, 0, 1, 1, 3, 0, 1, 0, "on_hit", "counter", "deny_approach", "", "guard_line_and_push_target", "design_only", base_note),
        CardSeed("spear_hold_distance", "守距横栏", "movement", "spearman", "common", "control", "movement", 2, 3, 2, 1, 1, 0, 0, 2, -1, 1, 0, "always", "control", "hold_distance", "", "maintain_ideal_range", "data_ready", base_note),
        CardSeed("spear_retreat_half_step", "半步后撤", "movement", "spearman", "common", "retreat", "movement", 2, 3, 2, 0, 1, 0, 0, 1, -1, 0, 0, "always", "retreat", "reset", "", "retreat_after_midrange_exchange", "design_only", base_note),
        CardSeed("spear_advance_shaft", "探杆进步", "movement", "spearman", "common", "approach", "movement", 1, 3, 2, 1, 1, 0, 1, 1, 1, 0, 0, "on_hit", "approach", "setup", "combo_bridge", "approach_to_restore_line", "design_only", base_note),
        CardSeed("spear_posture_grind", "磨势连点", "posture_break", "spearman", "uncommon", "break", "posture_break", 2, 3, 2, 2, 0, 2, 1, 0, 0, 0, 0, "on_hit", "break", "grind", "", "consistent_break_pressure", "design_only", base_note),
        CardSeed("spear_tempo_reset", "拨杆调息", "tempo", "spearman", "common", "recovery", "tempo", 2, 3, 2, 0, 2, 0, 0, 1, -1, 0, 0, "always", "recovery", "reset", "", "reset_tempo_with_distance_control", "data_ready", base_note),
        CardSeed("spear_chain_bridge", "贯线承接", "combo", "spearman", "uncommon", "combo_bridge", "combo", 2, 3, 2, 1, 1, 1, 1, 0, 0, 0, 0, "on_hit", "combo_bridge", "link", "combo_bridge", "low_to_mid_combo_link", "design_only", base_note),
        CardSeed("spear_pin_finish", "封线终刺", "combo", "spearman", "rare", "finisher", "combo", 2, 3, 2, 3, 0, 2, 4, 0, 0, 1, 0, "on_hit", "finisher", "burst", "combo_finisher", "finisher_with_readable_push", "design_only", base_note),
        CardSeed("spear_guard_breaker", "抬杆破架", "posture_break", "spearman", "rare", "punish", "posture_break", 2, 3, 2, 3, 0, 3, 2, 0, 0, 1, 0, "on_hit", "punish", "break_open", "", "anti_turtle_break_tool", "design_only", base_note),
        CardSeed("spear_control_special", "控线总诀", "special", "spearman", "special", "control", "special", 2, 3, 2, 2, 1, 2, 1, 2, -1, 1, 0, "always", "control", "hold_distance", "", "signature_control_without_high_combo_bias", "design_only", base_note),
    ]


def blademaster_cards(base_note: str) -> list[CardSeed]:
    return [
        CardSeed("blade_close_slash", "贴身斩", "attack", "blademaster", "common", "approach", "attack", 1, 2, 1, 1, 1, 0, 3, 0, 0, 0, 0, "on_hit", "approach", "close_in", "combo_opener", "close_range_opening_slash", "data_ready", base_note),
        CardSeed("blade_follow_step", "追步连斩", "attack", "blademaster", "uncommon", "pressure", "attack", 1, 2, 1, 2, 0, 1, 4, 0, 1, 0, 0, "on_hit", "pressure", "stick", "combo_bridge", "approach_and_keep_pressure", "design_only", base_note),
        CardSeed("blade_counter_cut", "守反切", "guard", "blademaster", "uncommon", "counter", "guard", 1, 2, 1, 2, 0, 1, 2, 3, 0, 0, 0, "on_hit", "counter", "counter", "", "guard_then_counter_cut", "data_ready", base_note),
        CardSeed("blade_inside_guard", "内门护手", "guard", "blademaster", "common", "guard", "guard", 1, 2, 1, 1, 1, 0, 0, 3, 0, 0, 0, "none", "guard", "stabilize", "", "close_guard_for_blade_style", "design_only", base_note),
        CardSeed("blade_quick_entry", "快步进身", "movement", "blademaster", "common", "approach", "movement", 1, 2, 1, 1, 1, 0, 1, 1, 1, 0, 0, "always", "approach", "setup", "", "primary_close_gap_tool", "data_ready", base_note),
        CardSeed("blade_shoulder_shift", "肩转换位", "movement", "blademaster", "common", "retreat", "movement", 1, 2, 1, 1, 1, 0, 0, 1, -1, 0, 0, "always", "retreat", "reset", "", "short_reset_without_full_disengage", "design_only", base_note),
        CardSeed("blade_opening_break", "开门断势", "posture_break", "blademaster", "uncommon", "break", "posture_break", 1, 2, 1, 2, 0, 2, 2, 0, 0, 0, 0, "on_hit", "break", "break_open", "", "break_then_continue_close_pressure", "design_only", base_note),
        CardSeed("blade_punish_riposte", "乘隙回斩", "posture_break", "blademaster", "rare", "punish", "posture_break", 1, 2, 1, 3, 0, 2, 3, 0, 0, 0, 0, "on_hit", "punish", "punish", "", "punish_tool_for_missed_defense", "design_only", base_note),
        CardSeed("blade_tempo_feint", "虚引换拍", "tempo", "blademaster", "uncommon", "combo_bridge", "tempo", 1, 2, 1, 1, 2, 0, 1, 0, 1, 0, 0, "always", "tempo", "setup", "combo_bridge", "tempo_shift_into_combo", "design_only", base_note),
        CardSeed("blade_focus_recover", "定息", "tempo", "blademaster", "common", "recovery", "tempo", 1, 2, 1, 0, 2, 0, 0, 1, 0, 0, 0, "none", "recovery", "reset", "", "recover_for_second_engage", "data_ready", base_note),
        CardSeed("blade_link_spin", "旋身承接", "combo", "blademaster", "uncommon", "combo_bridge", "combo", 1, 2, 1, 2, 1, 1, 2, 0, 1, 0, 0, "on_hit", "combo_bridge", "link", "combo_bridge", "bridge_for_close_combo", "design_only", base_note),
        CardSeed("blade_dual_cut_chain", "双切连势", "combo", "blademaster", "rare", "burst", "combo", 1, 2, 1, 3, 0, 1, 5, 0, 0, 0, 0, "on_hit", "burst", "burst", "combo_finisher", "high_damage_but_restricted_by_cost", "design_only", base_note),
        CardSeed("blade_finish_cross", "十字断", "combo", "blademaster", "rare", "finisher", "combo", 1, 2, 1, 3, 0, 2, 4, 0, 0, 0, 0, "on_hit", "finisher", "finish", "combo_finisher", "finisher_requires_proper_setup", "design_only", base_note),
        CardSeed("blade_signature_special", "刀势总压", "special", "blademaster", "special", "pressure", "special", 1, 2, 1, 2, 1, 2, 3, 1, 1, 0, 0, "on_hit", "pressure", "press", "", "signature_blade_pressure_tool", "design_only", base_note),
    ]


def firearm_cards(base_note: str) -> list[CardSeed]:
    return [
        CardSeed("enemy_firearm_aim", "举铳瞄线", "tempo", "firearm", "common", "firearm_pressure", "tempo", 3, 4, 3, 1, 2, 0, 0, 1, 0, 0, 0, "none", "firearm_pressure", "setup", "", "setup_before_shot_for_counterplay", "data_ready", base_note),
        CardSeed("enemy_firearm_shot", "火绳齐发", "attack", "firearm", "uncommon", "pressure", "attack", 3, 4, 3, 2, 0, 1, 4, 0, 0, 0, 0, "on_hit", "firearm_pressure", "firearm", "", "ranged_pressure_not_max_burst", "design_only", base_note),
        CardSeed("enemy_firearm_close_check", "压前点射", "attack", "firearm", "common", "punish", "attack", 2, 3, 3, 1, 0, 1, 2, 1, 0, 1, 0, "on_hit", "punish", "counterplay", "", "checks_direct_approach_with_push", "design_only", base_note),
        CardSeed("enemy_firearm_reposition", "换位装药", "movement", "firearm", "common", "retreat", "movement", 2, 4, 3, 1, 1, 0, 0, 1, -1, 0, 0, "always", "retreat", "counterplay", "", "reposition_instead_of_perma_lock", "data_ready", base_note),
        CardSeed("enemy_firearm_guard_cover", "掩体稳架", "guard", "firearm", "common", "guard", "guard", 2, 4, 3, 1, 1, 0, 0, 3, 0, 0, 0, "none", "guard", "stabilize", "", "defensive_turn_to_open_player_window", "design_only", base_note),
        CardSeed("enemy_firearm_break_bayonet", "枪托破势", "posture_break", "firearm", "uncommon", "break", "posture_break", 1, 2, 2, 2, 0, 2, 1, 0, 0, 1, 0, "on_hit", "break", "counterplay", "", "close_range_break_tool_not_sniper_lock", "design_only", base_note),
        CardSeed("enemy_firearm_suppression_order", "压制号令", "special", "firearm", "special", "firearm_pressure", "special", 3, 4, 3, 2, 1, 1, 2, 1, 0, 0, 0, "none", "firearm_pressure", "setup", "", "team_pressure_with_readable_gaps", "design_only", base_note),
    ]


def footwork_cards(base_note: str) -> list[CardSeed]:
    return [
        CardSeed("footwork_circle_step", "绕步", "movement", "footwork", "common", "control", "movement", 1, 3, 2, 0, 1, 0, 0, 1, 1, 0, 0, "always", "movement", "angle", "", "circle_for_distance_control", "data_ready", base_note),
        CardSeed("footwork_reverse_slide", "反滑退位", "movement", "footwork", "common", "retreat", "movement", 1, 3, 2, 0, 1, 0, 0, 1, -1, 0, 0, "always", "retreat", "evade", "", "retreat_without_lightness_gate", "data_ready", base_note),
        CardSeed("footwork_evade_cut", "闪步回削", "attack", "footwork", "uncommon", "counter", "attack", 1, 2, 1, 1, 1, 1, 2, 0, 1, 0, 0, "on_hit", "counter", "evade", "combo_bridge", "evade_then_chip_damage", "design_only", base_note),
        CardSeed("footwork_tempo_steal", "夺拍", "tempo", "footwork", "uncommon", "tempo", "tempo", 1, 3, 2, 1, 2, 0, 1, 0, 0, 0, 0, "on_hit", "tempo", "steal", "", "tempo_control_in_mobile_style", "design_only", base_note),
        CardSeed("footwork_low_break", "低位扫势", "posture_break", "footwork", "uncommon", "break", "posture_break", 1, 2, 1, 1, 0, 1, 1, 0, 0, 0, 0, "on_hit", "break", "trip", "", "light_break_with_position_gain", "design_only", base_note),
        CardSeed("footwork_guard_drift", "游身护势", "guard", "footwork", "common", "guard", "guard", 1, 3, 2, 1, 1, 0, 0, 2, 1, 0, 0, "always", "guard", "evade", "", "guard_while_repositioning", "design_only", base_note),
        CardSeed("footwork_special_flow", "流转身法", "special", "footwork", "special", "combo_bridge", "special", 1, 3, 2, 2, 1, 1, 1, 1, 1, 0, 0, "always", "combo_bridge", "flow", "combo_bridge", "mobile_special_with_clear_counterplay", "design_only", base_note),
    ]


def official_cards(base_note: str) -> list[CardSeed]:
    return [
        CardSeed("official_basic_cut", "军门正斩", "attack", "official", "common", "exam_fundamental", "attack", 1, 2, 1, 1, 1, 0, 2, 0, 0, 0, 0, "on_hit", "fundamental", "standard", "", "balanced_official_attack", "data_ready", base_note),
        CardSeed("official_guard_frame", "军门架手", "guard", "official", "common", "guard", "guard", 1, 3, 2, 1, 1, 0, 0, 3, 0, 0, 0, "none", "fundamental", "standard", "", "balanced_official_guard", "data_ready", base_note),
        CardSeed("official_step_set", "整步定势", "movement", "official", "common", "approach", "movement", 1, 3, 2, 1, 1, 0, 0, 1, 1, 0, 0, "always", "fundamental", "standard", "", "disciplined_approach_tool", "design_only", base_note),
        CardSeed("official_break_drill", "破势教式", "posture_break", "official", "uncommon", "break", "posture_break", 1, 2, 1, 2, 0, 2, 1, 0, 0, 0, 0, "on_hit", "fundamental", "drill", "", "fundamental_break_check", "design_only", base_note),
        CardSeed("exam_fundamental_probe", "科试探手", "tempo", "official", "common", "exam_fundamental", "tempo", 1, 3, 2, 0, 2, 0, 0, 1, 0, 0, 0, "none", "fundamental", "test", "", "tests_basic_resource_control", "data_ready", base_note),
        CardSeed("exam_chain_form", "连式考核", "combo", "official", "uncommon", "combo_bridge", "combo", 1, 2, 1, 1, 1, 1, 1, 1, 0, 0, 0, "on_hit", "fundamental", "test", "combo_bridge", "structured_combo_not_berserk_style", "design_only", base_note),
        CardSeed("official_counter_ritual", "定式反制", "guard", "official", "uncommon", "counter", "guard", 1, 2, 1, 2, 0, 1, 1, 3, 0, 0, 0, "on_hit", "counter", "discipline", "", "counter_based_on_form", "design_only", base_note),
        CardSeed("official_punish_form", "失式惩戒", "combo", "official", "rare", "punish", "combo", 1, 2, 1, 2, 0, 2, 3, 0, 0, 0, 0, "on_hit", "punish", "discipline", "combo_finisher", "punish_card_for_exam_and_officer", "design_only", base_note),
        CardSeed("official_standard_special", "军门总式", "special", "official", "special", "exam_fundamental", "special", 1, 3, 2, 2, 1, 1, 1, 2, 0, 0, 0, "none", "fundamental", "discipline", "", "balanced_special_for_exam_context", "design_only", base_note),
    ]


def boss_cards(base_note: str) -> list[CardSeed]:
    return [
        CardSeed("boss_phase_pressure", "阶段压制", "special", "boss", "boss", "boss_pressure", "special", 1, 3, 2, 2, 1, 2, 3, 2, 0, 0, 0, "none", "boss_pressure", "phase_pressure", "", "boss_only readable pressure opener", "design_only", base_note),
        CardSeed("boss_phase_counter", "阶段反制", "guard", "boss", "boss", "counter", "guard", 1, 3, 2, 2, 0, 2, 2, 4, 0, 0, 0, "on_hit", "boss_pressure", "boss_counter", "", "boss_only counter window card", "design_only", base_note),
        CardSeed("boss_phase_break", "阶段破势", "posture_break", "boss", "boss", "break", "posture_break", 1, 3, 2, 3, 0, 3, 2, 0, 0, 1, 0, "on_hit", "boss_pressure", "boss_break", "", "boss_only break with push to reset space", "design_only", base_note),
        CardSeed("boss_tempo_surge", "阶段抢拍", "tempo", "boss", "boss", "boss_pressure", "tempo", 1, 3, 2, 2, 2, 1, 1, 1, 0, 0, 0, "none", "boss_pressure", "boss_tempo", "", "boss_only tempo surge with clear tell", "design_only", base_note),
        CardSeed("boss_forward_step", "阶段迫近", "movement", "boss", "boss", "approach", "movement", 1, 3, 2, 1, 1, 0, 1, 1, 1, 0, 0, "always", "boss_pressure", "boss_step", "", "boss_only approach not teleport", "design_only", base_note),
        CardSeed("boss_guard_wall", "阶段固守", "guard", "boss", "boss", "guard", "guard", 1, 3, 2, 1, 1, 0, 0, 4, 0, 0, 0, "none", "boss_pressure", "boss_guard", "", "boss_only guard reset turn", "design_only", base_note),
        CardSeed("boss_punish_slice", "阶段惩击", "combo", "boss", "boss", "punish", "combo", 1, 3, 2, 3, 0, 2, 4, 0, 0, 0, 0, "on_hit", "boss_pressure", "boss_punish", "combo_finisher", "boss_only punish when player overextends", "design_only", base_note),
        CardSeed("boss_burst_finish", "阶段终击", "combo", "boss", "boss", "finisher", "combo", 2, 4, 3, 4, 0, 2, 5, 0, 0, 1, 0, "on_hit", "boss_pressure", "boss_finish", "combo_finisher", "boss_only finisher but still reactable", "design_only", base_note),
        CardSeed("boss_range_check", "阶段控距", "attack", "boss", "boss", "control", "attack", 2, 4, 3, 2, 0, 2, 3, 0, 0, 1, 0, "on_hit", "boss_pressure", "boss_range", "", "boss_only range check without lockout", "design_only", base_note),
    ]


def main() -> int:
    args = parse_args()
    design_dir = Path(args.design_dir)
    out_path = Path(args.out)
    must_exist(design_dir)
    deck_skeletons = read_tsv(design_dir / "generated_enemy_deck_skeleton.tsv")
    archetypes = read_tsv(design_dir / "generated_enemy_archetype_pool.tsv")
    requirements = read_tsv(design_dir / "generated_enemy_deck_requirement.tsv")

    source_grammar = resolve_grammar_source(Path.cwd())
    base_note = coverage_note(deck_skeletons, archetypes, requirements)
    rows = [seed.to_row(source_grammar) for seed in build_pool(base_note)]
    write_tsv(out_path, rows)

    print(f"WROTE: {out_path}")
    print(f"CARD_POOL_ROWS: {len(rows)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
