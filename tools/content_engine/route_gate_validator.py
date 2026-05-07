#!/usr/bin/env python3
"""Validate generated route gate plan for Content Engine v0.5d."""

from __future__ import annotations

import argparse
import csv
from dataclasses import dataclass, field
from pathlib import Path


REQUIRED_GATE_IDS = {
    "gate_normal_ending_default",
    "gate_normal_boss_access",
    "gate_true_route_unlock",
    "gate_true_boss_unlock",
    "gate_wuzhuangyuan_candidate",
    "gate_wuzhuangyuan_exam_unlock",
    "gate_lightness_cap_3",
    "gate_lightness_cap_4",
    "gate_boss_prepare_required",
}
VALID_ROUTE_IDS = {
    "normal_ending",
    "true_ending",
    "true_boss",
    "wuzhuangyuan",
    "lightness_breakthrough",
    "boss_prepare",
}
VALID_ROUTE_TYPES = {"normal", "true_route", "wuzhuangyuan", "optional", "support"}
VALID_GATE_KINDS = {"default_fallback", "unlock", "boss_access", "special_route", "rare_breakthrough", "preparation", "player_choice"}


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
        lines.extend([f"PASS: {message}" for message in self.passes])
        lines.extend([f"WARN: {message}" for message in self.warnings])
        lines.extend([f"FAIL: {message}" for message in self.failures])
        lines.append("RESULT: PASS" if self.ok() else "RESULT: FAIL")
        return "\n".join(lines)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Validate Content Engine v0.5d route gate plan.")
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


def split_tokens(value: str) -> set[str]:
    out: set[str] = set()
    for part in (value or "").split(","):
        token = part.strip()
        if not token or token.lower() == "none":
            continue
        out.add(token)
    return out


def by_gate_id(rows: list[dict[str, str]]) -> dict[str, dict[str, str]]:
    return {row.get("route_gate_id", ""): row for row in rows}


def validate(design_dir: Path) -> ValidationReport:
    report = ValidationReport()
    gate_path = design_dir / "generated_route_gate_plan.tsv"
    operation_path = design_dir / "generated_operation_node_plan.tsv"
    battle_path = design_dir / "generated_battle_reward_plan.tsv"
    narrative_path = design_dir / "generated_narrative_node_plan.tsv"

    for path in [gate_path, operation_path, battle_path, narrative_path]:
        if not path.exists():
            report.fail(f"Missing required file: {path}")
            return report
    report.pass_(f"Found {gate_path}")

    gate_rows = read_tsv(gate_path)
    operation_rows = read_tsv(operation_path)
    battle_rows = read_tsv(battle_path)
    narrative_rows = read_tsv(narrative_path)
    if not gate_rows:
        report.fail("generated_route_gate_plan.tsv is empty.")
        return report

    id_map = by_gate_id(gate_rows)
    validate_unique_ids(gate_rows, report)
    validate_required_gates(id_map, report)
    validate_enums(gate_rows, report)
    validate_normal_gates(id_map, report)
    validate_true_route_gates(id_map, report)
    validate_wuzhuangyuan_gates(id_map, report)
    validate_player_choice(id_map, battle_rows, operation_rows, narrative_rows, report)
    validate_lightness_cap4(id_map, report)
    validate_no_lightness_4_required(gate_rows, report)
    validate_boss_prepare_trace(id_map, operation_rows, report)
    return report


def validate_unique_ids(rows: list[dict[str, str]], report: ValidationReport) -> None:
    ids = [row.get("route_gate_id", "") for row in rows]
    if len(ids) == len(set(ids)):
        report.pass_("route_gate_id values are unique.")
    else:
        report.fail("Duplicate route_gate_id detected.")


def validate_required_gates(id_map: dict[str, dict[str, str]], report: ValidationReport) -> None:
    missing = sorted(REQUIRED_GATE_IDS - set(id_map.keys()))
    if missing:
        report.fail("Missing required route gates: " + ", ".join(missing))
    else:
        report.pass_("All required route gates exist.")


def validate_enums(rows: list[dict[str, str]], report: ValidationReport) -> None:
    bad_route_id = [row.get("route_gate_id", "") for row in rows if row.get("route_id", "") not in VALID_ROUTE_IDS]
    bad_route_type = [row.get("route_gate_id", "") for row in rows if row.get("route_type", "") not in VALID_ROUTE_TYPES]
    bad_gate_kind = [row.get("route_gate_id", "") for row in rows if row.get("gate_kind", "") not in VALID_GATE_KINDS]
    if bad_route_id:
        report.fail("Invalid route_id values: " + ", ".join(bad_route_id))
    else:
        report.pass_("All route_id values are valid.")
    if bad_route_type:
        report.fail("Invalid route_type values: " + ", ".join(bad_route_type))
    else:
        report.pass_("All route_type values are valid.")
    if bad_gate_kind:
        report.fail("Invalid gate_kind values: " + ", ".join(bad_gate_kind))
    else:
        report.pass_("All gate_kind values are valid.")


def validate_normal_gates(id_map: dict[str, dict[str, str]], report: ValidationReport) -> None:
    normal_ids = ["gate_normal_ending_default", "gate_normal_boss_access"]
    bad_realm10: list[str] = []
    bad_merit: list[str] = []
    bad_lightness: list[str] = []
    for gate_id in normal_ids:
        row = id_map.get(gate_id)
        if row is None:
            continue
        required_flags = split_tokens(row.get("required_flags", ""))
        required_lightness_level = as_int(row.get("required_lightness_level", ""), 0)
        martial_min = as_int(row.get("required_martial_realm_min", ""), 0)
        if "martial_realm_10" in required_flags or martial_min >= 10:
            bad_realm10.append(gate_id)
        if "high_military_merit" in required_flags or row.get("required_military_merit_level") == "high":
            bad_merit.append(gate_id)
        if (
            required_lightness_level >= 3
            or "lightness_3" in required_flags
            or "lightness_4" in required_flags
            or "lightness_cap_3" in required_flags
            or "lightness_cap_4" in required_flags
        ):
            bad_lightness.append(gate_id)

    if bad_realm10:
        report.fail("Normal ending gates must not require martial_realm_10: " + ", ".join(bad_realm10))
    else:
        report.pass_("Normal ending gates do not require martial_realm_10.")
    if bad_merit:
        report.fail("Normal ending gates must not require high_military_merit: " + ", ".join(bad_merit))
    else:
        report.pass_("Normal ending gates do not require high_military_merit.")
    if bad_lightness:
        report.fail("Normal ending gates must not require lightness 3/4: " + ", ".join(bad_lightness))
    else:
        report.pass_("Normal ending gates do not require lightness 3/4.")


def validate_true_route_gates(id_map: dict[str, dict[str, str]], report: ValidationReport) -> None:
    true_unlock = id_map.get("gate_true_route_unlock")
    true_boss = id_map.get("gate_true_boss_unlock")
    if true_unlock is not None:
        if true_unlock.get("required_old_case_progress_level") == "high":
            report.pass_("True route unlock requires high old_case progress.")
        else:
            report.fail("gate_true_route_unlock must set required_old_case_progress_level=high.")
    if true_boss is not None:
        martial_min = as_int(true_boss.get("required_martial_realm_min", ""), 0)
        flags = split_tokens(true_boss.get("required_flags", ""))
        lightness_min = as_int(true_boss.get("required_lightness_level", ""), 0)
        if martial_min == 10:
            report.pass_("True boss gate requires martial realm min 10.")
        else:
            report.fail("gate_true_boss_unlock must set required_martial_realm_min=10.")
        if lightness_min >= 4 or "lightness_4" in flags or "lightness_cap_4" in flags:
            report.fail("gate_true_boss_unlock must not require lightness 4.")
        else:
            report.pass_("True boss gate does not require lightness 4.")


def validate_wuzhuangyuan_gates(id_map: dict[str, dict[str, str]], report: ValidationReport) -> None:
    wz_ids = ["gate_wuzhuangyuan_candidate", "gate_wuzhuangyuan_exam_unlock"]
    bad_realm: list[str] = []
    bad_merit: list[str] = []
    bad_old_case: list[str] = []
    bad_lightness: list[str] = []
    for gate_id in wz_ids:
        row = id_map.get(gate_id)
        if row is None:
            continue
        flags = split_tokens(row.get("required_flags", ""))
        old_case_level = row.get("required_old_case_progress_level", "")
        lightness_min = as_int(row.get("required_lightness_level", ""), 0)
        martial_min = as_int(row.get("required_martial_realm_min", ""), 0)
        merit_level = row.get("required_military_merit_level", "")

        if martial_min != 10 or "martial_realm_10" not in flags:
            bad_realm.append(gate_id)
        if merit_level != "high" or "high_military_merit" not in flags:
            bad_merit.append(gate_id)
        if old_case_level == "high":
            bad_old_case.append(gate_id)
        if lightness_min >= 4 or "lightness_4" in flags or "lightness_cap_4" in flags:
            bad_lightness.append(gate_id)

    if bad_realm:
        report.fail("Wuzhuangyuan gates must require martial realm min 10: " + ", ".join(bad_realm))
    else:
        report.pass_("Wuzhuangyuan gates require martial realm min 10.")
    if bad_merit:
        report.fail("Wuzhuangyuan gates must require high military merit: " + ", ".join(bad_merit))
    else:
        report.pass_("Wuzhuangyuan gates require high military merit.")
    if bad_old_case:
        report.fail("Wuzhuangyuan gates must not require old_case progress high: " + ", ".join(bad_old_case))
    else:
        report.pass_("Wuzhuangyuan gates do not require old_case progress high.")
    if bad_lightness:
        report.fail("Wuzhuangyuan gates must not require lightness 4: " + ", ".join(bad_lightness))
    else:
        report.pass_("Wuzhuangyuan gates do not require lightness 4.")


def validate_player_choice(
    id_map: dict[str, dict[str, str]],
    battle_rows: list[dict[str, str]],
    operation_rows: list[dict[str, str]],
    narrative_rows: list[dict[str, str]],
    report: ValidationReport,
) -> None:
    true_possible = any(
        as_bool(row.get("can_trigger_realm_10", "")) and as_int(row.get("old_case_progress_reward", "0"), 0) > 0 for row in battle_rows
    ) or any(as_bool(row.get("can_support_true_ending", "")) for row in operation_rows) or any(
        row.get("route_affinity") == "true_route" for row in narrative_rows
    )
    wz_possible = any(as_bool(row.get("can_trigger_wuzhuangyuan_route", "")) for row in battle_rows) or any(
        as_bool(row.get("can_trigger_wuzhuangyuan_route", "")) for row in operation_rows
    ) or any(row.get("route_affinity") == "wuzhuangyuan" for row in narrative_rows)
    has_choice_gate = any(as_bool(row.get("is_player_choice", "false")) for row in id_map.values())
    if true_possible and wz_possible:
        if has_choice_gate:
            report.pass_("Player-choice gate exists for true_route vs wuzhuangyuan overlap.")
        else:
            report.fail("Missing is_player_choice=true gate while true_route and wuzhuangyuan overlap is possible.")
    else:
        report.warn("Current sources do not indicate simultaneous true_route and wuzhuangyuan possibility.")


def validate_lightness_cap4(id_map: dict[str, dict[str, str]], report: ValidationReport) -> None:
    row = id_map.get("gate_lightness_cap_4")
    if row is None:
        return
    risk = row.get("risk_level", "")
    ending_route = row.get("ending_route", "")
    if risk in {"rare", "route"}:
        report.pass_("lightness_cap_4 gate risk_level is rare/route.")
    else:
        report.fail("gate_lightness_cap_4 must have risk_level=rare or route.")
    if ending_route not in {"normal", "true_route", "wuzhuangyuan"}:
        report.pass_("lightness_cap_4 gate ending_route is non-ending route.")
    else:
        report.fail("gate_lightness_cap_4 must not target normal/true_route/wuzhuangyuan ending_route.")


def validate_no_lightness_4_required(rows: list[dict[str, str]], report: ValidationReport) -> None:
    bad: list[str] = []
    for row in rows:
        gate_id = row.get("route_gate_id", "")
        for key in ["required_flags", "optional_flags", "blocked_by_flags"]:
            if "lightness_4_required" in split_tokens(row.get(key, "")):
                bad.append(gate_id)
                break
    if bad:
        report.fail("lightness_4_required must not appear: " + ", ".join(bad))
    else:
        report.pass_("No lightness_4_required appears in gate flags.")


def validate_boss_prepare_trace(
    id_map: dict[str, dict[str, str]], operation_rows: list[dict[str, str]], report: ValidationReport
) -> None:
    row = id_map.get("gate_boss_prepare_required")
    if row is None:
        return
    source_ids = split_tokens(row.get("source_operation_node_ids", ""))
    can_prepare_ids = {
        op_row.get("operation_node_id", "")
        for op_row in operation_rows
        if as_bool(op_row.get("can_prepare_boss", ""))
    }
    if source_ids & can_prepare_ids:
        report.pass_("boss_prepare gate traces to can_prepare_boss=true operation node.")
    else:
        report.fail("gate_boss_prepare_required must trace to can_prepare_boss=true operation nodes.")


def main() -> int:
    args = parse_args()
    report = validate(Path(args.design_dir))
    print(report.format())
    return 0 if report.ok() else 1


if __name__ == "__main__":
    raise SystemExit(main())
