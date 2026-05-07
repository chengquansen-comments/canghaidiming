#!/usr/bin/env python3
"""Validate Content Engine v0.1 generated planning TSVs."""

from __future__ import annotations

import argparse
import csv
from dataclasses import dataclass, field
from pathlib import Path


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

    def fail_(self, message: str) -> None:
        # Backward-compatible alias for older call sites.
        self.fail(message)

    def ok(self) -> bool:
        return not self.failures

    def format(self) -> str:
        lines: list[str] = []
        for item in self.passes:
            lines.append(f"PASS: {item}")
        for item in self.warnings:
            lines.append(f"WARN: {item}")
        for item in self.failures:
            lines.append(f"FAIL: {item}")
        lines.append("RESULT: PASS" if self.ok() else "RESULT: FAIL")
        return "\n".join(lines)


def read_tsv(path: Path) -> list[dict[str, str]]:
    with path.open("r", encoding="utf-8", newline="") as handle:
        return list(csv.DictReader(handle, delimiter="\t"))


def as_int(row: dict[str, str], field_name: str, default: int = 0) -> int:
    text = (row.get(field_name) or "").strip()
    try:
        return int(round(float(text)))
    except ValueError:
        return default


def find_one(rows: list[dict[str, str]], key: str, value: str) -> dict[str, str] | None:
    for row in rows:
        if row.get(key) == value:
            return row
    return None


def validate_design_dir(design_dir: str | Path) -> ValidationReport:
    root = Path(design_dir)
    report = ValidationReport()
    battle_path = root / "generated_battle_slot_plan.tsv"
    deck_path = root / "generated_enemy_deck_requirement.tsv"
    curve_path = root / "generated_route_progression_curve.tsv"
    operation_path = root / "generated_operation_node_requirement.tsv"

    for path in [battle_path, deck_path, curve_path, operation_path]:
        if path.exists():
            report.pass_(f"Found {path}")
        else:
            report.fail_(f"Missing required output file: {path}")
    if not report.ok():
        return report

    battle_rows = read_tsv(battle_path)
    deck_rows = read_tsv(deck_path)
    curve_rows = read_tsv(curve_path)
    operation_rows = read_tsv(operation_path)

    validate_big_map_counts(deck_rows, report)
    validate_battle_slots(battle_rows, report)
    validate_operation_nodes(operation_rows, report)
    validate_routes(curve_rows, report)
    return report


def validate_big_map_counts(rows: list[dict[str, str]], report: ValidationReport) -> None:
    total = find_one(rows, "requirement_id", "big_map_total")
    elite = find_one(rows, "requirement_id", "big_map_elite")
    if total is None:
        report.fail_("Missing big_map_total deck requirement row.")
        return
    total_min = as_int(total, "actual_battle_count_min")
    total_default = as_int(total, "actual_battle_count_default")
    total_max = as_int(total, "actual_battle_count_max")
    deck_default = as_int(total, "required_deck_count_default")
    if (total_min, total_default, total_max) == (14, 15, 16):
        report.pass_("Big map battle range is 14-16 with default 15.")
    else:
        report.fail_(f"Big map battle range expected 14/15/16, got {total_min}/{total_default}/{total_max}.")
    if deck_default == 30:
        report.pass_("Big map total candidate deck default is 30.")
    else:
        report.fail_(f"Big map total candidate deck default expected 30, got {deck_default}.")
    if elite is None:
        report.fail_("Missing big_map_elite deck requirement row.")
        return
    elite_default = as_int(elite, "actual_battle_count_default")
    ratio = elite_default / total_default if total_default else 0.0
    if 0.20 <= ratio <= 0.30:
        report.pass_(f"Big map elite default ratio is {ratio:.1%}.")
    else:
        report.fail_(f"Big map elite default ratio should be 20%-30%, got {ratio:.1%}.")


def validate_battle_slots(rows: list[dict[str, str]], report: ValidationReport) -> None:
    wz_exams = [
        row
        for row in rows
        if row.get("route_type") == "wuzhuangyuan" and row.get("battle_type") == "wuzhuangyuan_exam"
    ]
    if len(wz_exams) == 5:
        report.pass_("Wuzhuangyuan route has 5 exam battle slots.")
    else:
        report.fail_(f"Wuzhuangyuan route expected 5 exam battle slots, got {len(wz_exams)}.")

def validate_operation_nodes(rows: list[dict[str, str]], report: ValidationReport) -> None:
    operation = find_one(rows, "requirement_id", "big_map_operation_total")
    combat = find_one(rows, "requirement_id", "big_map_combat_total_reference")
    total = find_one(rows, "requirement_id", "big_map_total_node_reference")
    if operation is None:
        report.fail_("Missing big_map_operation_total operation requirement row.")
        return
    if combat is None:
        report.fail_("Missing big_map_combat_total_reference operation requirement row.")
        return
    if total is None:
        report.fail_("Missing big_map_total_node_reference operation requirement row.")
        return

    operation_default = as_int(operation, "actual_node_count_default")
    combat_default = as_int(combat, "actual_node_count_default")
    total_default = as_int(total, "actual_node_count_default")
    if 7 <= operation_default <= 9:
        report.pass_(f"Operation node default count is around 8 (got {operation_default}).")
    else:
        report.fail_(f"Operation node default count expected around 8, got {operation_default}.")

    if 14 <= combat_default <= 16:
        report.pass_(f"Combat reference default count is around 15 (got {combat_default}).")
    else:
        report.fail_(f"Combat reference default count expected around 15, got {combat_default}.")

    if 22 <= total_default <= 24:
        report.pass_(f"Total passed node default count is around 23 (got {total_default}).")
    else:
        report.fail_(f"Total passed node default count expected around 23, got {total_default}.")

    try:
        ratio_default = float((operation.get("ratio_default") or "0").strip())
        ratio_min = float((operation.get("ratio_min") or "0").strip())
        ratio_max = float((operation.get("ratio_max") or "0").strip())
    except ValueError:
        report.fail_("Operation ratio row has invalid numeric values.")
        return

    if ratio_min >= 0.30 and ratio_max <= 0.40 and ratio_min <= ratio_default <= ratio_max:
        report.pass_(f"Operation ratio range is within 30%-40% (default {ratio_default:.3f}).")
    else:
        report.fail_(
            "Operation ratio expected within 30%-40%, "
            f"got min/default/max {ratio_min:.3f}/{ratio_default:.3f}/{ratio_max:.3f}."
        )


def validate_routes(rows: list[dict[str, str]], report: ValidationReport) -> None:
    normal_boss = find_one(rows, "checkpoint", "normal_after_boss")
    if normal_boss is None:
        report.fail_("Missing normal_after_boss route checkpoint.")
    else:
        realm_default = as_int(normal_boss, "expected_realm_default")
        realm_max = as_int(normal_boss, "expected_realm_max")
        lightness_max = as_int(normal_boss, "expected_lightness_max")
        if 8 <= realm_default <= 9 and realm_max <= 9:
            report.pass_("Normal route final realm target is 8-9.")
        else:
            report.fail_(f"Normal route final realm expected 8-9, got default {realm_default}, max {realm_max}.")
        if lightness_max <= 2:
            report.pass_("Normal route lightness max does not exceed 2.")
        else:
            report.fail_(f"Normal route lightness max should not exceed 2, got {lightness_max}.")

    can_reach_10 = any(
        row.get("can_reach_realm_10") == "TRUE" and row.get("route") in {"elite", "true_route"}
        for row in rows
    )
    if can_reach_10:
        report.pass_("Elite or true route can reach realm 10.")
    else:
        report.fail_("Expected elite or true route to reach realm 10.")

    wz_unlock = any(row.get("route") == "wuzhuangyuan" and row.get("can_unlock_wuzhuangyuan") == "TRUE" for row in rows)
    if wz_unlock:
        report.pass_("Wuzhuangyuan route marks can_unlock_wuzhuangyuan.")
    else:
        report.fail_("Wuzhuangyuan route must mark can_unlock_wuzhuangyuan.")

    invalid_lightness_4 = [
        row.get("checkpoint", "")
        for row in rows
        if as_int(row, "expected_lightness_max") >= 4 and row.get("route") not in {"true_route", "wuzhuangyuan"}
    ]
    if invalid_lightness_4:
        report.fail_("Lightness 4 appears outside true_route / wuzhuangyuan: " + ", ".join(invalid_lightness_4))
    else:
        report.pass_("Lightness 4 only appears in allowed special routes.")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Validate Content Engine v0.1 generated planning tables.")
    parser.add_argument("--design-dir", default="data/design")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    report = validate_design_dir(args.design_dir)
    print(report.format())
    return 0 if report.ok() else 1


if __name__ == "__main__":
    raise SystemExit(main())
