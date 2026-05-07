#!/usr/bin/env python3
"""Validate generated enemy deck skeletons for Content Engine v0.3."""

from __future__ import annotations

import argparse
import csv
from dataclasses import dataclass, field
from pathlib import Path


COUNT_FIELDS = [
    "attack_card_count",
    "guard_card_count",
    "movement_card_count",
    "posture_break_card_count",
    "tempo_card_count",
    "combo_card_count",
    "special_card_count",
]


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
    parser = argparse.ArgumentParser(description="Validate Content Engine v0.3 enemy deck skeletons.")
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


def count_by(rows: list[dict[str, str]], key: str, value: str) -> int:
    return sum(1 for row in rows if (row.get(key) or "") == value)


def validate(design_dir: Path) -> ValidationReport:
    report = ValidationReport()
    skeleton_path = design_dir / "generated_enemy_deck_skeleton.tsv"
    archetype_path = design_dir / "generated_enemy_archetype_pool.tsv"
    if not skeleton_path.exists():
        report.fail(f"Missing required file: {skeleton_path}")
        return report
    if not archetype_path.exists():
        report.fail(f"Missing required file: {archetype_path}")
        return report
    report.pass_(f"Found {skeleton_path}")
    report.pass_(f"Found {archetype_path}")

    rows = read_tsv(skeleton_path)
    archetypes = read_tsv(archetype_path)
    if not rows:
        report.fail("Deck skeleton table is empty.")
        return report

    validate_ids(rows, report)
    validate_archetype_coverage(rows, archetypes, report)
    validate_scope_counts(rows, report)
    validate_target_counts(rows, report)
    validate_card_count_mix(rows, report)
    validate_complexity(rows, report)
    validate_tags(rows, report)
    return report


def validate_ids(rows: list[dict[str, str]], report: ValidationReport) -> None:
    ids = [row.get("deck_skeleton_id", "") for row in rows]
    if len(set(ids)) == len(ids):
        report.pass_("All deck_skeleton_id values are unique.")
    else:
        report.fail("Duplicate deck_skeleton_id detected.")


def validate_archetype_coverage(
    rows: list[dict[str, str]],
    archetypes: list[dict[str, str]],
    report: ValidationReport,
) -> None:
    by_archetype: dict[str, int] = {}
    for row in rows:
        archetype_id = row.get("archetype_id", "")
        by_archetype[archetype_id] = by_archetype.get(archetype_id, 0) + 1

    missing = [row.get("archetype_id", "") for row in archetypes if by_archetype.get(row.get("archetype_id", ""), 0) < 1]
    if missing:
        report.fail("Archetypes without deck skeleton: " + ", ".join(missing))
    else:
        report.pass_("Every archetype has at least one deck skeleton.")

    for archetype in archetypes:
        archetype_id = archetype.get("archetype_id", "")
        expected = as_int(archetype.get("recommended_deck_variant_count", ""), 1)
        actual = by_archetype.get(archetype_id, 0)
        if actual == expected:
            report.pass_(f"{archetype_id} skeleton count matches recommended count ({actual}).")
        elif actual > 0 and abs(actual - expected) <= 1:
            report.warn(f"{archetype_id} skeleton count is near recommended count: expected {expected}, got {actual}.")
        else:
            report.fail(f"{archetype_id} skeleton count expected near {expected}, got {actual}.")


def validate_scope_counts(rows: list[dict[str, str]], report: ValidationReport) -> None:
    normal = count_by(rows, "scope", "big_map_normal")
    elite = count_by(rows, "scope", "big_map_elite")
    exam = count_by(rows, "scope", "wuzhuangyuan_exam")
    boss_normal = count_by(rows, "scope", "boss_normal")
    boss_true = count_by(rows, "scope", "boss_true")

    if 20 <= normal <= 24:
        report.pass_(f"Normal deck skeleton count is {normal} (expected 20-24).")
    else:
        report.fail(f"Normal deck skeleton count expected 20-24, got {normal}.")
    if 8 <= elite <= 10:
        report.pass_(f"Elite deck skeleton count is {elite} (expected 8-10).")
    else:
        report.fail(f"Elite deck skeleton count expected 8-10, got {elite}.")
    if exam == 5:
        report.pass_("Wuzhuangyuan exam skeleton count is exactly 5.")
    else:
        report.fail(f"Wuzhuangyuan exam skeleton count expected 5, got {exam}.")
    if boss_normal >= 1 and boss_true >= 2:
        report.pass_(f"Boss skeletons cover normal boss and true-route bosses ({boss_normal}+{boss_true}).")
    else:
        report.fail(f"Boss skeleton coverage insufficient: boss_normal={boss_normal}, boss_true={boss_true}.")


def validate_target_counts(rows: list[dict[str, str]], report: ValidationReport) -> None:
    bad: list[str] = []
    for row in rows:
        target = as_int(row.get("target_card_count", ""), -1)
        if not target_in_range(row, target):
            bad.append(f"{row.get('deck_skeleton_id', '')}={target}")
    if bad:
        report.fail("target_card_count out of expected range: " + ", ".join(bad))
    else:
        report.pass_("All target_card_count values are in expected ranges.")


def target_in_range(row: dict[str, str], target: int) -> bool:
    scope = row.get("scope", "")
    if scope == "big_map_normal":
        return 8 <= target <= 12
    if scope == "big_map_elite":
        return 12 <= target <= 14
    if scope in {"boss_normal", "boss_true"}:
        return 14 <= target <= 18
    if scope == "wuzhuangyuan_exam":
        return 12 <= target <= 16
    return target > 0


def validate_card_count_mix(rows: list[dict[str, str]], report: ValidationReport) -> None:
    bad_mix: list[str] = []
    bad_sum: list[str] = []
    bad_normal_special: list[str] = []
    bad_normal_combo: list[str] = []
    for row in rows:
        values = {field: as_int(row.get(field, ""), 0) for field in COUNT_FIELDS}
        total_roles = sum(values.values())
        target = as_int(row.get("target_card_count", ""), 0)
        deck_id = row.get("deck_skeleton_id", "")
        if values["attack_card_count"] >= total_roles or values["guard_card_count"] <= 0 or values["movement_card_count"] <= 0:
            bad_mix.append(deck_id)
        if total_roles < target - 1 or total_roles > target + 4:
            bad_sum.append(f"{deck_id}: roles={total_roles}, target={target}")
        if row.get("scope") == "big_map_normal" and values["special_card_count"] > 1:
            bad_normal_special.append(deck_id)
        if row.get("scope") == "big_map_normal" and values["combo_card_count"] > 2:
            bad_normal_combo.append(deck_id)

    if bad_mix:
        report.fail("Card role mix is too narrow: " + ", ".join(bad_mix))
    else:
        report.pass_("Card role mix includes guard and movement and is not all attack.")
    if bad_sum:
        report.fail("Card role totals are not close to target_card_count: " + ", ".join(bad_sum))
    else:
        report.pass_("Card role totals are close to target_card_count.")
    if bad_normal_special:
        report.fail("Normal enemy special_card_count should be <=1: " + ", ".join(bad_normal_special))
    else:
        report.pass_("Normal enemy special_card_count constraint satisfied.")
    if bad_normal_combo:
        report.warn("Normal enemy combo_card_count is high: " + ", ".join(bad_normal_combo))


def validate_complexity(rows: list[dict[str, str]], report: ValidationReport) -> None:
    out_of_range: list[str] = []
    normal_bad: list[str] = []
    true_boss_bad: list[str] = []
    final_exam_bad: list[str] = []
    for row in rows:
        value = as_int(row.get("complexity_level", ""), -1)
        deck_id = row.get("deck_skeleton_id", "")
        if value < 1 or value > 5:
            out_of_range.append(deck_id)
        if row.get("scope") == "big_map_normal" and value > 3:
            normal_bad.append(deck_id)
        if row.get("battle_type") == "true_boss" and value != 5:
            true_boss_bad.append(deck_id)
        if row.get("archetype_id") == "exam_imperial_final_examiner" and value != 5:
            final_exam_bad.append(deck_id)

    if out_of_range:
        report.fail("complexity_level out of range [1,5]: " + ", ".join(out_of_range))
    else:
        report.pass_("All complexity_level values are within 1-5.")
    if normal_bad:
        report.fail("Normal enemy complexity should be <=3: " + ", ".join(normal_bad))
    else:
        report.pass_("Normal enemy complexity constraint satisfied.")
    if true_boss_bad:
        report.fail("true_boss complexity should be 5: " + ", ".join(true_boss_bad))
    else:
        report.pass_("true_boss complexity constraint satisfied.")
    if final_exam_bad:
        report.fail("Final Wuzhuangyuan exam complexity should be 5: " + ", ".join(final_exam_bad))
    else:
        report.pass_("Final Wuzhuangyuan exam complexity constraint satisfied.")


def validate_tags(rows: list[dict[str, str]], report: ValidationReport) -> None:
    mismatch: list[str] = []
    empty_forbidden: list[str] = []
    missing_lightness_forbidden: list[str] = []
    bad_required_lightness: list[str] = []
    for row in rows:
        deck_id = row.get("deck_skeleton_id", "")
        required = tags(row.get("required_card_tags", ""))
        forbidden = tags(row.get("forbidden_card_tags", ""))
        if not tags_match(row, required):
            mismatch.append(deck_id)
        if not forbidden:
            empty_forbidden.append(deck_id)
        if needs_lightness_forbidden(row) and "lightness_4_required" not in forbidden:
            missing_lightness_forbidden.append(deck_id)
        if "lightness_4_required" in required:
            bad_required_lightness.append(deck_id)

    if mismatch:
        report.fail("weapon_style does not match required_card_tags: " + ", ".join(mismatch))
    else:
        report.pass_("weapon_style and required_card_tags match.")
    if empty_forbidden:
        report.fail("forbidden_card_tags is empty: " + ", ".join(empty_forbidden))
    else:
        report.pass_("forbidden_card_tags is non-empty for every skeleton.")
    if missing_lightness_forbidden:
        report.fail("Boss/final exam must forbid lightness_4_required: " + ", ".join(missing_lightness_forbidden))
    else:
        report.pass_("Boss and final exam lightness_4_required forbidden-tag constraint satisfied.")
    if bad_required_lightness:
        report.fail("lightness_4_required must not appear in required_card_tags: " + ", ".join(bad_required_lightness))
    else:
        report.pass_("No skeleton requires lightness_4_required.")


def tags_match(row: dict[str, str], required: set[str]) -> bool:
    weapon_style = row.get("weapon_style", "")
    if weapon_style == "spearman":
        return "weapon_spearman" in required
    if weapon_style == "blademaster":
        return "weapon_blademaster" in required
    if weapon_style == "firearm":
        return "weapon_firearm" in required or "role_firearm_pressure" in required
    if weapon_style == "official" or row.get("scope") == "wuzhuangyuan_exam":
        return "exam_official" in required or "role_fundamental" in required
    return True


def needs_lightness_forbidden(row: dict[str, str]) -> bool:
    if row.get("scope") in {"boss_normal", "boss_true"}:
        return True
    return row.get("archetype_id") == "exam_imperial_final_examiner"


def main() -> int:
    args = parse_args()
    report = validate(Path(args.design_dir))
    print(report.format())
    return 0 if report.ok() else 1


if __name__ == "__main__":
    raise SystemExit(main())
