#!/usr/bin/env python3
"""Validate generated enemy archetype pool for Content Engine v0.2."""

from __future__ import annotations

import argparse
import csv
from dataclasses import dataclass, field
from pathlib import Path


VALID_BATTLE_TYPES = {"normal", "elite", "boss", "true_boss", "wuzhuangyuan_exam"}
VALID_WEAPON_STYLES = {"generic", "spearman", "blademaster", "mixed", "firearm", "footwork", "official"}


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
    parser = argparse.ArgumentParser(description="Validate Content Engine v0.2 enemy archetype pool.")
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


def parse_ratio_field(value: str) -> bool:
    items = [part.strip() for part in value.split(",") if part.strip()]
    if not items:
        return False
    for item in items:
        if ":" not in item:
            return False
        role, number = item.split(":", 1)
        if role.strip() == "":
            return False
        try:
            float(number.strip())
        except ValueError:
            return False
    return True


def count_by(rows: list[dict[str, str]], key: str, value: str) -> int:
    return sum(1 for row in rows if (row.get(key) or "") == value)


def validate(design_dir: Path) -> ValidationReport:
    report = ValidationReport()
    archetype_path = design_dir / "generated_enemy_archetype_pool.tsv"
    requirement_path = design_dir / "generated_enemy_deck_requirement.tsv"
    if not archetype_path.exists():
        report.fail(f"Missing required file: {archetype_path}")
        return report
    if not requirement_path.exists():
        report.fail(f"Missing required file: {requirement_path}")
        return report
    report.pass_(f"Found {archetype_path}")
    report.pass_(f"Found {requirement_path}")

    rows = read_tsv(archetype_path)
    requirements = read_tsv(requirement_path)
    if not rows:
        report.fail("Archetype pool is empty.")
        return report

    validate_counts(rows, report)
    validate_fields(rows, report)
    validate_constraints(rows, report)
    validate_variant_coverage(rows, requirements, report)
    return report


def validate_counts(rows: list[dict[str, str]], report: ValidationReport) -> None:
    normal_count = count_by(rows, "scope", "big_map_normal")
    elite_count = count_by(rows, "scope", "big_map_elite")
    wz_count = count_by(rows, "scope", "wuzhuangyuan_exam")
    boss_normal_count = count_by(rows, "scope", "boss_normal")
    boss_true_count = count_by(rows, "scope", "boss_true")

    if 7 <= normal_count <= 8:
        report.pass_(f"Normal archetype count is {normal_count} (expected 7-8).")
    else:
        report.fail(f"Normal archetype count expected 7-8, got {normal_count}.")
    if 4 <= elite_count <= 5:
        report.pass_(f"Elite archetype count is {elite_count} (expected 4-5).")
    else:
        report.fail(f"Elite archetype count expected 4-5, got {elite_count}.")
    if wz_count == 5:
        report.pass_("Wuzhuangyuan exam archetype count is 5.")
    else:
        report.fail(f"Wuzhuangyuan exam archetype count expected 5, got {wz_count}.")
    if boss_normal_count >= 1:
        report.pass_("Normal boss archetype count is at least 1.")
    else:
        report.fail("Normal boss archetype count should be at least 1.")
    if boss_true_count >= 2:
        report.pass_("True-route boss archetype count is at least 2.")
    else:
        report.fail("True-route boss archetype count should be at least 2.")


def validate_fields(rows: list[dict[str, str]], report: ValidationReport) -> None:
    ids = [row.get("archetype_id", "") for row in rows]
    if len(set(ids)) == len(ids):
        report.pass_("All archetype_id values are unique.")
    else:
        report.fail("Duplicate archetype_id detected.")

    bad_battle_type = [row.get("archetype_id", "") for row in rows if (row.get("battle_type") or "") not in VALID_BATTLE_TYPES]
    if bad_battle_type:
        report.fail("Invalid battle_type in archetypes: " + ", ".join(bad_battle_type))
    else:
        report.pass_("All battle_type values are valid.")

    bad_weapon_style = [row.get("archetype_id", "") for row in rows if (row.get("weapon_style") or "") not in VALID_WEAPON_STYLES]
    if bad_weapon_style:
        report.fail("Invalid weapon_style in archetypes: " + ", ".join(bad_weapon_style))
    else:
        report.pass_("All weapon_style values are valid.")

    bad_complexity = []
    for row in rows:
        value = as_int(row.get("complexity_level", ""), -1)
        if value < 1 or value > 5:
            bad_complexity.append(row.get("archetype_id", ""))
    if bad_complexity:
        report.fail("complexity_level out of range [1,5]: " + ", ".join(bad_complexity))
    else:
        report.pass_("All complexity_level values are within 1-5.")

    bad_ratio_rows = [row.get("archetype_id", "") for row in rows if not parse_ratio_field(row.get("tactic_role_ratio", ""))]
    if bad_ratio_rows:
        report.fail("Invalid tactic_role_ratio format: " + ", ".join(bad_ratio_rows))
    else:
        report.pass_("All tactic_role_ratio values are parseable.")


def validate_constraints(rows: list[dict[str, str]], report: ValidationReport) -> None:
    normal_bad = [row.get("archetype_id", "") for row in rows if row.get("battle_type") == "normal" and as_int(row.get("complexity_level", "")) > 3]
    elite_bad = [
        row.get("archetype_id", "")
        for row in rows
        if row.get("battle_type") == "elite" and not (3 <= as_int(row.get("complexity_level", "")) <= 4)
    ]
    true_boss_bad = [row.get("archetype_id", "") for row in rows if row.get("battle_type") == "true_boss" and as_int(row.get("complexity_level", "")) != 5]
    final_exam = next((row for row in rows if row.get("archetype_id") == "exam_imperial_final_examiner"), None)

    if normal_bad:
        report.fail("Normal archetype complexity should be <=3: " + ", ".join(normal_bad))
    else:
        report.pass_("Normal archetype complexity constraint satisfied.")

    if elite_bad:
        report.fail("Elite archetype complexity should be 3-4: " + ", ".join(elite_bad))
    else:
        report.pass_("Elite archetype complexity constraint satisfied.")

    if true_boss_bad:
        report.fail("true_boss complexity should be 5: " + ", ".join(true_boss_bad))
    else:
        report.pass_("true_boss complexity constraint satisfied.")

    if final_exam is None:
        report.fail("Missing exam_imperial_final_examiner archetype.")
    elif as_int(final_exam.get("complexity_level", "")) != 5:
        report.fail("exam_imperial_final_examiner should have complexity_level 5.")
    else:
        report.pass_("Final imperial examiner complexity is 5.")

    hard_gate_hits: list[str] = []
    for row in rows:
        text = f"{row.get('forbidden_tags', '')} {row.get('notes', '')}".lower()
        if "lightness 4 must" in text or "lightness4must" in text or "require_lightness_4" in text:
            hard_gate_hits.append(row.get("archetype_id", ""))
    if hard_gate_hits:
        report.fail("Found hard lightness-4 gates: " + ", ".join(hard_gate_hits))
    else:
        report.pass_("No hard lightness-4 gate markers detected.")


def requirement_by_id(requirements: list[dict[str, str]], requirement_id: str) -> dict[str, str] | None:
    for row in requirements:
        if row.get("requirement_id") == requirement_id:
            return row
    return None


def validate_variant_coverage(rows: list[dict[str, str]], requirements: list[dict[str, str]], report: ValidationReport) -> None:
    for requirement_id in ["big_map_normal", "big_map_elite", "wuzhuangyuan_exam"]:
        req = requirement_by_id(requirements, requirement_id)
        if req is None:
            report.fail(f"Missing deck requirement row: {requirement_id}")
            continue
        expected_min = as_int(req.get("required_deck_count_min", ""), 0)
        expected_max = as_int(req.get("required_deck_count_max", ""), 0)
        actual = sum(as_int(row.get("recommended_deck_variant_count", ""), 0) for row in rows if row.get("source_requirement_id") == requirement_id)
        if expected_min <= actual <= expected_max:
            report.pass_(
                f"Variant coverage for {requirement_id} is {actual} (expected {expected_min}-{expected_max})."
            )
        else:
            report.fail(
                f"Variant coverage for {requirement_id} expected {expected_min}-{expected_max}, got {actual}."
            )


def main() -> int:
    args = parse_args()
    report = validate(Path(args.design_dir))
    print(report.format())
    return 0 if report.ok() else 1


if __name__ == "__main__":
    raise SystemExit(main())
