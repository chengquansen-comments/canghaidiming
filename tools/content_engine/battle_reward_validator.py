#!/usr/bin/env python3
"""Validate generated battle reward plan for Content Engine v0.5a."""

from __future__ import annotations

import argparse
import csv
from collections import Counter
from dataclasses import dataclass, field
from pathlib import Path


VALID_BATTLE_TYPES = {"tutorial", "weapon_trial", "exam", "normal", "elite", "boss", "true_boss", "wuzhuangyuan_exam"}
VALID_REWARD_PROFILE = {
    "tutorial",
    "weapon_trial",
    "wuju_exam",
    "normal_low",
    "normal_standard",
    "normal_high",
    "elite_standard",
    "elite_high",
    "boss_normal",
    "boss_true_gate",
    "true_boss",
    "wuzhuangyuan_exam",
    "wuzhuangyuan_final",
}


@dataclass
class ValidationReport:
    passes: list[str] = field(default_factory=list)
    warnings: list[str] = field(default_factory=list)
    failures: list[str] = field(default_factory=list)

    def pass_(self, message: str) -> None:
        self.passes.append(message)

    def warn(self, message: str) -> None:
        self.warnings.append(message)

    def fail(self, message: str) -> None:
        self.failures.append(message)

    def ok(self) -> bool:
        return not self.failures

    def format(self) -> str:
        lines: list[str] = []
        lines.extend([f"PASS: {item}" for item in self.passes])
        lines.extend([f"WARN: {item}" for item in self.warnings])
        lines.extend([f"FAIL: {item}" for item in self.failures])
        lines.append("RESULT: PASS" if self.ok() else "RESULT: FAIL")
        return "\n".join(lines)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Validate Content Engine v0.5a battle reward plan.")
    parser.add_argument("--design-dir", default="data/design")
    return parser.parse_args()


def read_tsv(path: Path) -> list[dict[str, str]]:
    with path.open("r", encoding="utf-8", newline="") as handle:
        return list(csv.DictReader(handle, delimiter="\t"))


def as_int(value: str, default: int = 0) -> int:
    try:
        return int(round(float((value or "").strip())))
    except ValueError:
        return default


def as_bool(value: str) -> bool:
    return (value or "").strip().lower() in {"1", "true", "yes"}


def validate(design_dir: Path) -> ValidationReport:
    report = ValidationReport()
    reward_path = design_dir / "generated_battle_reward_plan.tsv"
    deck_sets_path = design_dir / "generated_enemy_deck_sets.tsv"
    config_path = design_dir / "progression_numeric_config_v1_3.tsv"
    for path in [reward_path, deck_sets_path, config_path]:
        if not path.exists():
            report.fail(f"Missing required file: {path}")
            return report
    report.pass_(f"Found {reward_path}")
    report.pass_(f"Found {deck_sets_path}")
    report.pass_(f"Found {config_path}")

    rows = read_tsv(reward_path)
    decks = read_tsv(deck_sets_path)
    config_rows = read_tsv(config_path)
    if not rows:
        report.fail("generated_battle_reward_plan.tsv is empty.")
        return report

    deck_ids = {row.get("deck_id", "") for row in decks}
    validate_ids(rows, report)
    validate_refs(rows, deck_ids, report)
    validate_basic_fields(rows, report)
    validate_profiles(rows, report)
    validate_martial_distribution(rows, report)
    validate_exam_and_boss(rows, report)
    validate_route_estimates(rows, config_rows, report)
    validate_lightness_rules(rows, report)
    validate_route_flags(rows, report)
    return report


def validate_ids(rows: list[dict[str, str]], report: ValidationReport) -> None:
    ids = [row.get("reward_plan_id", "") for row in rows]
    if len(set(ids)) == len(ids):
        report.pass_("reward_plan_id values are unique.")
    else:
        report.fail("Duplicate reward_plan_id detected.")


def validate_refs(rows: list[dict[str, str]], deck_ids: set[str], report: ValidationReport) -> None:
    bad: list[str] = []
    for row in rows:
        deck_id = row.get("deck_id", "")
        if deck_id and deck_id not in deck_ids:
            bad.append(f"{row.get('reward_plan_id', '')}:{deck_id}")
    if bad:
        report.fail("Rows referencing unknown deck_id: " + ", ".join(bad))
    else:
        report.pass_("All non-empty deck_id references exist in generated_enemy_deck_sets.tsv.")


def validate_basic_fields(rows: list[dict[str, str]], report: ValidationReport) -> None:
    bad_type = [row.get("reward_plan_id", "") for row in rows if row.get("battle_type", "") not in VALID_BATTLE_TYPES]
    bad_profile = [row.get("reward_plan_id", "") for row in rows if row.get("reward_profile", "") not in VALID_REWARD_PROFILE]
    bad_martial = [row.get("reward_plan_id", "") for row in rows if as_int(row.get("martial_xp_reward", ""), -1) < 0]
    bad_weapon = [row.get("reward_plan_id", "") for row in rows if as_int(row.get("weapon_xp_reward", ""), -1) < 0]

    if bad_type:
        report.fail("Invalid battle_type rows: " + ", ".join(bad_type))
    else:
        report.pass_("All battle_type values are valid.")
    if bad_profile:
        report.fail("Invalid reward_profile rows: " + ", ".join(bad_profile))
    else:
        report.pass_("All reward_profile values are valid.")
    if bad_martial:
        report.fail("martial_xp_reward has negative values: " + ", ".join(bad_martial))
    else:
        report.pass_("All martial_xp_reward values are non-negative.")
    if bad_weapon:
        report.fail("weapon_xp_reward has negative values: " + ", ".join(bad_weapon))
    else:
        report.pass_("All weapon_xp_reward values are non-negative.")


def validate_profiles(rows: list[dict[str, str]], report: ValidationReport) -> None:
    normal_pool = [as_int(row.get("martial_xp_reward", ""), 0) for row in rows if row.get("battle_slot_id") == "big_map_normal_pool"]
    elite_pool = [as_int(row.get("martial_xp_reward", ""), 0) for row in rows if row.get("battle_slot_id") == "big_map_elite_pool"]
    normal_mode = mode(normal_pool)
    elite_mode = mode(elite_pool)
    if normal_mode == 5:
        report.pass_("big_map_normal_pool martial_xp_reward mode is 5.")
    else:
        report.warn(f"big_map_normal_pool martial_xp_reward mode is {normal_mode}, expected 5.")
    if elite_mode == 12:
        report.pass_("big_map_elite_pool martial_xp_reward mode is 12.")
    else:
        report.warn(f"big_map_elite_pool martial_xp_reward mode is {elite_mode}, expected 12.")


def validate_martial_distribution(rows: list[dict[str, str]], report: ValidationReport) -> None:
    normal_boss = [as_int(row.get("martial_xp_reward", ""), 0) for row in rows if row.get("reward_profile") == "boss_normal"]
    true_gate = [as_int(row.get("martial_xp_reward", ""), 0) for row in rows if row.get("reward_profile") == "boss_true_gate"]
    true_boss = [as_int(row.get("martial_xp_reward", ""), 0) for row in rows if row.get("reward_profile") == "true_boss"]
    if normal_boss and all(value in {11, 12, 13} for value in normal_boss):
        report.pass_("Normal boss martial_xp_reward is around 12.")
    else:
        report.fail("Normal boss martial_xp_reward is not around 12.")
    if true_gate and all(value in {11, 12, 13} for value in true_gate):
        report.pass_("True-route gate boss martial_xp_reward is around 12.")
    else:
        report.fail("True-route gate boss martial_xp_reward is not around 12.")
    if true_boss and all(value in {15, 16, 17} for value in true_boss):
        report.pass_("True boss martial_xp_reward is around 16.")
    else:
        report.fail("True boss martial_xp_reward is not around 16.")


def validate_exam_and_boss(rows: list[dict[str, str]], report: ValidationReport) -> None:
    exam_rows = [row for row in rows if row.get("battle_slot_id", "").startswith("wz_exam_")]
    if len(exam_rows) == 5:
        report.pass_("Wuzhuangyuan exam reward rows are exactly 5.")
    else:
        report.fail(f"Wuzhuangyuan exam reward rows expected 5, got {len(exam_rows)}.")
    has_final = any(row.get("battle_slot_id") == "wz_exam_05" and row.get("reward_profile") == "wuzhuangyuan_final" for row in rows)
    if has_final:
        report.pass_("Wuzhuangyuan final reward row exists.")
    else:
        report.fail("Missing Wuzhuangyuan final reward row.")


def validate_route_estimates(rows: list[dict[str, str]], config_rows: list[dict[str, str]], report: ValidationReport) -> None:
    pre = sum(
        as_int(row.get("martial_xp_reward", ""), 0)
        for row in rows
        if row.get("battle_slot_id") in {"prologue_01", "wuju_weapon_01", "wuju_weapon_02", "wuju_exam_01", "wuju_exam_02", "wuju_exam_03"}
    )
    normal_pool = [as_int(row.get("martial_xp_reward", ""), 0) for row in rows if row.get("battle_slot_id") == "big_map_normal_pool"]
    elite_pool = [as_int(row.get("martial_xp_reward", ""), 0) for row in rows if row.get("battle_slot_id") == "big_map_elite_pool"]
    normal_boss = sum(as_int(row.get("martial_xp_reward", ""), 0) for row in rows if row.get("reward_profile") == "boss_normal")
    true_gate = sum(as_int(row.get("martial_xp_reward", ""), 0) for row in rows if row.get("reward_profile") == "boss_true_gate")

    normal_est = pre + 12 * mode(normal_pool) + 3 * mode(elite_pool) + normal_boss
    elite_est = pre + 10 * mode(normal_pool) + 5 * mode(elite_pool) + true_gate

    realm_9 = config_value(config_rows, "martial_realm_9_xp_threshold", 120)
    realm_10 = config_value(config_rows, "martial_realm_10_xp_threshold", 145)
    normal_realm = estimated_realm(normal_est, config_rows)
    elite_realm = estimated_realm(elite_est, config_rows)

    if realm_9 <= normal_est < realm_10 and normal_realm in {8, 9}:
        report.pass_(f"Normal route estimate martial_xp={normal_est}, realm≈{normal_realm} (8-9).")
    else:
        report.fail(f"Normal route estimate off target: martial_xp={normal_est}, realm≈{normal_realm}.")
    if elite_est >= realm_10 and elite_realm == 10:
        report.pass_(f"Elite route estimate martial_xp={elite_est}, realm≈10.")
    else:
        report.fail(f"Elite route estimate does not reach stable realm 10: martial_xp={elite_est}, realm≈{elite_realm}.")


def validate_lightness_rules(rows: list[dict[str, str]], report: ValidationReport) -> None:
    bad_normal_cap = [
        row.get("reward_plan_id", "")
        for row in rows
        if row.get("ending_route") in {"none", "normal"}
        and not row.get("battle_slot_id", "").startswith("wz_exam_")
        and cap_rank(row.get("lightness_cap_unlock", "")) > cap_rank("cap_2")
    ]
    bad_cap4 = [
        row.get("reward_plan_id", "")
        for row in rows
        if row.get("lightness_cap_unlock") == "cap_4" and row.get("battle_slot_id") not in {"wz_exam_05"}
    ]
    rare_count = sum(1 for row in rows if row.get("lightness_reward_type") == "rare_breakthrough")

    if bad_normal_cap:
        report.fail("Normal-route lightness cap exceeds cap_2: " + ", ".join(bad_normal_cap))
    else:
        report.pass_("Normal-route lightness cap does not exceed cap_2.")
    if bad_cap4:
        report.fail("cap_4 appears outside intended rare slots: " + ", ".join(bad_cap4))
    else:
        report.pass_("cap_4 only appears in rare intended slots.")
    if rare_count <= 2:
        report.pass_(f"rare_breakthrough row count is low ({rare_count}).")
    else:
        report.fail(f"rare_breakthrough row count too high ({rare_count}).")


def validate_route_flags(rows: list[dict[str, str]], report: ValidationReport) -> None:
    bad_wz_trigger = [
        row.get("reward_plan_id", "")
        for row in rows
        if as_bool(row.get("can_trigger_wuzhuangyuan_route", "false"))
        and not (row.get("battle_slot_id") == "big_map_elite_pool" and row.get("reward_profile") == "elite_high")
    ]
    bad_exam_old_case = [
        row.get("reward_plan_id", "")
        for row in rows
        if row.get("battle_slot_id", "").startswith("wz_exam_")
        and as_int(row.get("old_case_progress_reward", ""), 0) > 1
    ]
    if bad_wz_trigger:
        report.fail("can_trigger_wuzhuangyuan_route appears in invalid rows: " + ", ".join(bad_wz_trigger))
    else:
        report.pass_("can_trigger_wuzhuangyuan_route only appears in elite-high pool rows.")
    if bad_exam_old_case:
        report.fail("Wuzhuangyuan exam old_case_progress_reward too high: " + ", ".join(bad_exam_old_case))
    else:
        report.pass_("Wuzhuangyuan exam old_case_progress_reward is controlled.")


def mode(values: list[int]) -> int:
    if not values:
        return 0
    counter = Counter(values)
    ordered = sorted(counter.items(), key=lambda item: (-item[1], item[0]))
    return ordered[0][0]


def cap_rank(value: str) -> int:
    mapping = {"none": 0, "cap_1": 1, "cap_2": 2, "cap_3": 3, "cap_4": 4}
    return mapping.get(value, 0)


def config_value(config_rows: list[dict[str, str]], config_id: str, fallback: int) -> int:
    for row in config_rows:
        if row.get("config_id") == config_id:
            return as_int(row.get("default_value", ""), fallback)
    return fallback


def estimated_realm(martial_xp: int, config_rows: list[dict[str, str]]) -> int:
    realm = 1
    for idx in range(2, 11):
        threshold = config_value(config_rows, f"martial_realm_{idx}_xp_threshold", 10 ** 9)
        if martial_xp >= threshold:
            realm = idx
    return realm


def main() -> int:
    args = parse_args()
    report = validate(Path(args.design_dir))
    print(report.format())
    return 0 if report.ok() else 1


if __name__ == "__main__":
    raise SystemExit(main())
