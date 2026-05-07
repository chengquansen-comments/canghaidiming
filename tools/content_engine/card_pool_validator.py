#!/usr/bin/env python3
"""Validate generated card pool for Content Engine v0.4a."""

from __future__ import annotations

import argparse
import csv
from collections import Counter
from dataclasses import dataclass, field
from pathlib import Path


EXPECTED_FIELDS = [
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

VALID_CARD_CLASS = {"attack", "guard", "movement", "posture_break", "tempo", "combo", "special"}
VALID_WEAPON_STYLE = {"generic", "spearman", "blademaster", "firearm", "footwork", "official", "mixed", "boss"}
VALID_TACTIC_ROLE = {
    "opener",
    "pressure",
    "poke",
    "control",
    "approach",
    "retreat",
    "guard",
    "counter",
    "break",
    "burst",
    "finisher",
    "combo_bridge",
    "punish",
    "recovery",
    "firearm_pressure",
    "exam_fundamental",
    "boss_pressure",
    "tempo",
}
VALID_DECK_ROLE = {"attack", "guard", "movement", "posture_break", "tempo", "combo", "special"}

STYLE_MIN = {
    "generic": 10,
    "spearman": 12,
    "blademaster": 12,
    "firearm": 6,
    "footwork": 6,
    "official": 8,
    "boss": 8,
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
    parser = argparse.ArgumentParser(description="Validate Content Engine v0.4a generated card pool.")
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


def tags(value: str) -> set[str]:
    return {part.strip() for part in value.split(",") if part.strip()}


def validate(design_dir: Path) -> ValidationReport:
    report = ValidationReport()
    path = design_dir / "generated_card_pool.tsv"
    if not path.exists():
        report.fail(f"Missing required file: {path}")
        return report
    report.pass_(f"Found {path}")

    rows = read_tsv(path)
    if not rows:
        report.fail("generated_card_pool.tsv is empty.")
        return report

    validate_fields(rows, report)
    validate_uniqueness(rows, report)
    validate_enums(rows, report)
    validate_numeric(rows, report)
    validate_budget_formula(rows, report)
    validate_distribution(rows, report)
    validate_tags(rows, report)
    validate_firearm_counterplay(rows, report)
    return report


def validate_fields(rows: list[dict[str, str]], report: ValidationReport) -> None:
    missing_fields = [field for field in EXPECTED_FIELDS if field not in rows[0]]
    if missing_fields:
        report.fail("Missing required fields: " + ", ".join(missing_fields))
    else:
        report.pass_("All required fields are present.")


def validate_uniqueness(rows: list[dict[str, str]], report: ValidationReport) -> None:
    ids = [row.get("card_id", "") for row in rows]
    if len(set(ids)) == len(ids):
        report.pass_("All card_id values are unique.")
    else:
        report.fail("Duplicate card_id detected.")


def validate_enums(rows: list[dict[str, str]], report: ValidationReport) -> None:
    bad_class = [row.get("card_id", "") for row in rows if row.get("card_class", "") not in VALID_CARD_CLASS]
    bad_style = [row.get("card_id", "") for row in rows if row.get("weapon_style", "") not in VALID_WEAPON_STYLE]
    bad_tactic = [row.get("card_id", "") for row in rows if row.get("tactic_role", "") not in VALID_TACTIC_ROLE]
    bad_deck = [row.get("card_id", "") for row in rows if row.get("deck_role", "") not in VALID_DECK_ROLE]

    if bad_class:
        report.fail("Invalid card_class: " + ", ".join(bad_class))
    else:
        report.pass_("All card_class values are valid.")
    if bad_style:
        report.fail("Invalid weapon_style: " + ", ".join(bad_style))
    else:
        report.pass_("All weapon_style values are valid.")
    if bad_tactic:
        report.fail("Invalid tactic_role: " + ", ".join(bad_tactic))
    else:
        report.pass_("All tactic_role values are valid.")
    if bad_deck:
        report.fail("Invalid deck_role: " + ", ".join(bad_deck))
    else:
        report.pass_("All deck_role values are valid.")


def validate_numeric(rows: list[dict[str, str]], report: ValidationReport) -> None:
    bad_distance: list[str] = []
    bad_cost: list[str] = []
    for row in rows:
        card_id = row.get("card_id", "")
        min_distance = as_int(row.get("min_distance", ""), -1)
        max_distance = as_int(row.get("max_distance", ""), -1)
        momentum_cost = as_int(row.get("momentum_cost", ""), -1)
        if min_distance > max_distance:
            bad_distance.append(card_id)
        if momentum_cost < 0:
            bad_cost.append(card_id)

    if bad_distance:
        report.fail("Found min_distance > max_distance: " + ", ".join(bad_distance))
    else:
        report.pass_("All cards satisfy min_distance <= max_distance.")
    if bad_cost:
        report.fail("Found momentum_cost < 0: " + ", ".join(bad_cost))
    else:
        report.pass_("All momentum_cost values are >= 0.")


def validate_budget_formula(rows: list[dict[str, str]], report: ValidationReport) -> None:
    bad_power: list[str] = []
    bad_target: list[str] = []
    bad_delta: list[str] = []
    for row in rows:
        card_id = row.get("card_id", "")
        gain = as_int(row.get("gain_momentum", ""), 0)
        break_m = as_int(row.get("break_momentum", ""), 0)
        damage = as_int(row.get("damage", ""), 0)
        guard = as_int(row.get("guard", ""), 0)
        cost = as_int(row.get("momentum_cost", ""), 0)
        power = as_int(row.get("power_budget", ""), -9999)
        target = as_int(row.get("budget_target", ""), -9999)
        delta = as_int(row.get("budget_delta", ""), -9999)
        expected_power = gain * 2 + break_m * 2 + damage + guard
        expected_target = cost * 4
        expected_delta = expected_power - expected_target
        if power != expected_power:
            bad_power.append(card_id)
        if target != expected_target:
            bad_target.append(card_id)
        if delta != expected_delta:
            bad_delta.append(card_id)

    if bad_power:
        report.fail("power_budget formula mismatch: " + ", ".join(bad_power))
    else:
        report.pass_("power_budget matches formula for all cards.")
    if bad_target:
        report.fail("budget_target formula mismatch: " + ", ".join(bad_target))
    else:
        report.pass_("budget_target matches formula for all cards.")
    if bad_delta:
        report.fail("budget_delta formula mismatch: " + ", ".join(bad_delta))
    else:
        report.pass_("budget_delta matches formula for all cards.")


def validate_distribution(rows: list[dict[str, str]], report: ValidationReport) -> None:
    style_counter = Counter(row.get("weapon_style", "") for row in rows)
    for style, minimum in STYLE_MIN.items():
        value = style_counter.get(style, 0)
        if value >= minimum:
            report.pass_(f"{style} card count is {value} (>= {minimum}).")
        else:
            report.fail(f"{style} card count is {value}, expected >= {minimum}.")

    role_counter = Counter(row.get("deck_role", "") for row in rows)
    missing_roles = [role for role in VALID_DECK_ROLE if role_counter.get(role, 0) <= 0]
    if missing_roles:
        report.fail("Missing deck_role coverage: " + ", ".join(sorted(missing_roles)))
    else:
        report.pass_("All primary deck_role buckets are covered.")


def validate_tags(rows: list[dict[str, str]], report: ValidationReport) -> None:
    bad_minimum: list[str] = []
    bad_generic_boss: list[str] = []
    bad_normal_boss: list[str] = []
    bad_lightness: list[str] = []
    bad_boss_lightness: list[str] = []
    for row in rows:
        card_id = row.get("card_id", "")
        style = row.get("weapon_style", "")
        row_tags = tags(row.get("tags", ""))
        if not required_tag_blocks_present(row_tags):
            bad_minimum.append(card_id)
        if style == "generic" and ("boss_only" in row_tags or "true_boss_only" in row_tags):
            bad_generic_boss.append(card_id)
        if style in {"spearman", "blademaster", "firearm", "footwork", "official", "mixed"} and (
            "boss_only" in row_tags or "true_boss_only" in row_tags
        ):
            bad_normal_boss.append(card_id)
        combo = row.get("combo_tags", "")
        if "lightness_4_required" in row_tags or "lightness_4_required" in combo:
            bad_lightness.append(card_id)
        if style == "boss" and "lightness_4_required" in row_tags:
            bad_boss_lightness.append(card_id)

    if bad_minimum:
        report.fail("tags missing weapon_/role_/deck_/ai_ blocks: " + ", ".join(bad_minimum))
    else:
        report.pass_("All cards have required tag blocks.")
    if bad_generic_boss:
        report.fail("generic cards must not contain boss-only tags: " + ", ".join(bad_generic_boss))
    else:
        report.pass_("generic cards do not contain boss-only tags.")
    if bad_normal_boss:
        report.fail("non-boss weapon cards must not contain boss-only tags: " + ", ".join(bad_normal_boss))
    else:
        report.pass_("non-boss weapon cards do not contain boss-only tags.")
    if bad_lightness:
        report.fail("tags/combo_tags must not include lightness_4_required: " + ", ".join(bad_lightness))
    else:
        report.pass_("No card uses lightness_4_required in tags/combo_tags.")
    if bad_boss_lightness:
        report.fail("boss cards must not require lightness_4_required: " + ", ".join(bad_boss_lightness))
    else:
        report.pass_("boss cards do not require lightness_4_required.")


def required_tag_blocks_present(row_tags: set[str]) -> bool:
    has_weapon = any(tag.startswith("weapon_") for tag in row_tags)
    has_role = any(tag.startswith("role_") for tag in row_tags)
    has_deck = any(tag.startswith("deck_") for tag in row_tags)
    has_ai = any(tag.startswith("ai_") for tag in row_tags)
    return has_weapon and has_role and has_deck and has_ai


def validate_firearm_counterplay(rows: list[dict[str, str]], report: ValidationReport) -> None:
    firearm_rows = [row for row in rows if row.get("weapon_style") == "firearm"]
    if not firearm_rows:
        report.fail("No firearm cards found.")
        return

    high_damage = [row for row in firearm_rows if as_int(row.get("damage", ""), 0) >= 4 and as_int(row.get("min_distance", ""), 0) >= 3]
    if len(high_damage) == len(firearm_rows):
        report.fail("All firearm cards are long-range high-damage cards.")
    else:
        report.pass_("Firearm cards are not all long-range high-damage.")

    counterplay_rows = []
    for row in firearm_rows:
        row_tags = tags(row.get("tags", ""))
        if row.get("deck_role") == "tempo" or "ai_setup" in row_tags or "ai_counterplay" in row_tags:
            counterplay_rows.append(row)
    if counterplay_rows:
        report.pass_(f"Firearm counterplay coverage present ({len(counterplay_rows)} cards).")
    else:
        report.fail("Firearm cards lack tempo/setup/counterplay coverage.")


def main() -> int:
    args = parse_args()
    report = validate(Path(args.design_dir))
    print(report.format())
    return 0 if report.ok() else 1


if __name__ == "__main__":
    raise SystemExit(main())
