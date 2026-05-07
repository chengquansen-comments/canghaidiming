#!/usr/bin/env python3
"""Validate generated operation node plan for Content Engine v0.5b."""

from __future__ import annotations

import argparse
import csv
from collections import Counter
from dataclasses import dataclass, field
from pathlib import Path


REQUIRED_SUBTYPES = {"校场", "行营", "军门", "器械所", "师门", "市井", "旧案", "休整"}


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
    parser = argparse.ArgumentParser(description="Validate Content Engine v0.5b operation node plan.")
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


def split_tags(value: str) -> set[str]:
    return {part.strip() for part in value.split(",") if part.strip()}


def validate(design_dir: Path) -> ValidationReport:
    report = ValidationReport()
    node_path = design_dir / "generated_operation_node_plan.tsv"
    requirement_path = design_dir / "generated_operation_node_requirement.tsv"
    if not node_path.exists():
        report.fail(f"Missing required file: {node_path}")
        return report
    if not requirement_path.exists():
        report.fail(f"Missing required file: {requirement_path}")
        return report
    report.pass_(f"Found {node_path}")
    report.pass_(f"Found {requirement_path}")

    rows = read_tsv(node_path)
    req_rows = read_tsv(requirement_path)
    if not rows:
        report.fail("generated_operation_node_plan.tsv is empty.")
        return report

    validate_ids(rows, report)
    validate_counts(rows, req_rows, report)
    validate_required_subtypes(rows, report)
    validate_lightness(rows, report)
    validate_route_triggers(rows, report)
    validate_old_case(rows, report)
    validate_balance_costs(rows, report)
    validate_military_gate_tradeoff(rows, report)
    return report


def validate_ids(rows: list[dict[str, str]], report: ValidationReport) -> None:
    ids = [row.get("operation_node_id", "") for row in rows]
    if len(set(ids)) == len(ids):
        report.pass_("operation_node_id values are unique.")
    else:
        report.fail("Duplicate operation_node_id detected.")


def requirement_default(req_rows: list[dict[str, str]]) -> int:
    for row in req_rows:
        if row.get("requirement_id") == "big_map_operation_total":
            return as_int(row.get("actual_node_count_default", ""), 8)
    return 8


def validate_counts(rows: list[dict[str, str]], req_rows: list[dict[str, str]], report: ValidationReport) -> None:
    default_count = requirement_default(req_rows)
    total = len(rows)
    base_count = sum(1 for row in rows if as_int(row.get("node_index", ""), 0) <= default_count)
    if default_count - 1 <= base_count <= default_count + 1:
        report.pass_(f"Default operation node count is about {default_count} (actual={base_count}).")
    else:
        report.fail(f"Default operation node count expected around {default_count}, got {base_count}.")
    if 8 <= total <= 10:
        report.pass_(f"Total candidate operation nodes are within 8-10 (actual={total}).")
    else:
        report.fail(f"Total candidate operation nodes should be 8-10, got {total}.")


def validate_required_subtypes(rows: list[dict[str, str]], report: ValidationReport) -> None:
    subtypes = {row.get("node_subtype", "") for row in rows}
    missing = sorted(REQUIRED_SUBTYPES - subtypes)
    if missing:
        report.fail("Missing required node_subtype: " + ", ".join(missing))
    else:
        report.pass_("All required node_subtype entries exist.")


def validate_lightness(rows: list[dict[str, str]], report: ValidationReport) -> None:
    lightness_nodes = [row for row in rows if row.get("node_type") == "lightness_encounter"]
    if len(lightness_nodes) <= 1:
        report.pass_(f"lightness_encounter node count is controlled ({len(lightness_nodes)}).")
    else:
        report.fail(f"Too many lightness_encounter nodes: {len(lightness_nodes)}.")

    bad_cap4 = [
        row.get("operation_node_id", "")
        for row in rows
        if row.get("lightness_cap_unlock") == "cap_4" and row.get("risk_level") not in {"rare", "route"}
    ]
    if bad_cap4:
        report.fail("cap_4 appears in common nodes: " + ", ".join(bad_cap4))
    else:
        report.pass_("cap_4 does not appear in common operation nodes.")

    rare_break_bad = [
        row.get("operation_node_id", "")
        for row in rows
        if row.get("lightness_reward_type") == "rare_breakthrough" and row.get("risk_level") not in {"rare", "route"}
    ]
    if rare_break_bad:
        report.fail("rare_breakthrough nodes must be rare/route risk: " + ", ".join(rare_break_bad))
    else:
        report.pass_("rare_breakthrough nodes are limited to rare/route risk.")

    cap3_bad = [
        row.get("operation_node_id", "")
        for row in rows
        if row.get("lightness_cap_unlock") == "cap_3"
        and row.get("node_type") not in {"lightness_encounter", "master", "old_case"}
    ]
    if cap3_bad:
        report.warn("cap_3 appears outside rare/master/old_case patterns: " + ", ".join(cap3_bad))
    else:
        report.pass_("cap_3 unlock placement matches rare/master/old_case patterns.")


def validate_route_triggers(rows: list[dict[str, str]], report: ValidationReport) -> None:
    bad_stage = [
        row.get("operation_node_id", "")
        for row in rows
        if as_bool(row.get("can_trigger_wuzhuangyuan_route", "false"))
        and row.get("stage") not in {"big_map_late", "boss_prepare", "wuzhuangyuan_prepare"}
    ]
    if bad_stage:
        report.fail("can_trigger_wuzhuangyuan_route appears in invalid stage: " + ", ".join(bad_stage))
    else:
        report.pass_("Wuzhuangyuan trigger stage constraint satisfied.")

    bad_tags = []
    for row in rows:
        if not as_bool(row.get("can_trigger_wuzhuangyuan_route", "false")):
            continue
        route_tags = split_tags(row.get("route_gate_tags", ""))
        if "high_military_merit" not in route_tags and "wuzhuangyuan_candidate" not in route_tags:
            bad_tags.append(row.get("operation_node_id", ""))
    if bad_tags:
        report.fail("Wuzhuangyuan trigger nodes missing route tags: " + ", ".join(bad_tags))
    else:
        report.pass_("Wuzhuangyuan trigger nodes include required route tags.")


def validate_old_case(rows: list[dict[str, str]], report: ValidationReport) -> None:
    bad: list[str] = []
    for row in rows:
        if as_int(row.get("old_case_progress_reward", ""), 0) <= 0:
            continue
        tags_a = split_tags(row.get("narrative_hook_tags", ""))
        tags_b = split_tags(row.get("route_gate_tags", ""))
        if "old_case" not in tags_a and "old_case_progress" not in tags_b:
            bad.append(row.get("operation_node_id", ""))
    if bad:
        report.fail("old_case_progress_reward nodes missing old_case tags: " + ", ".join(bad))
    else:
        report.pass_("old_case_progress_reward nodes include old_case tags.")


def validate_balance_costs(rows: list[dict[str, str]], report: ValidationReport) -> None:
    bad: list[str] = []
    for row in rows:
        martial = as_int(row.get("martial_xp_reward", ""), 0)
        reward_type = row.get("resource_reward_type", "")
        reward_amount = as_int(row.get("resource_reward_amount", ""), 0)
        if martial >= 3 and reward_type in {"heal", "supply"} and reward_amount >= 2:
            bad.append(row.get("operation_node_id", ""))
    if bad:
        report.fail("High martial_xp nodes also giving large heal/supply: " + ", ".join(bad))
    else:
        report.pass_("High martial_xp nodes are not stacked with large heal/supply.")


def validate_military_gate_tradeoff(rows: list[dict[str, str]], report: ValidationReport) -> None:
    bad: list[str] = []
    for row in rows:
        if row.get("node_type") != "military_gate":
            continue
        merit = as_int(row.get("military_merit_reward", ""), 0)
        if merit <= 0:
            continue
        clean = as_int(row.get("clean_reputation_reward", ""), 0)
        notes = row.get("notes", "").lower()
        if clean >= 0 and "代价" not in notes and "risk" not in notes:
            bad.append(row.get("operation_node_id", ""))
    if bad:
        report.warn("Military merit nodes should include reputation cost or note: " + ", ".join(bad))
    else:
        report.pass_("Military merit nodes have explicit tradeoff or note.")

    has_boss_prepare = any(as_bool(row.get("can_prepare_boss", "false")) for row in rows)
    if has_boss_prepare:
        report.pass_("At least one boss preparation node exists.")
    else:
        report.fail("Missing can_prepare_boss=true node.")


def main() -> int:
    args = parse_args()
    report = validate(Path(args.design_dir))
    print(report.format())
    return 0 if report.ok() else 1


if __name__ == "__main__":
    raise SystemExit(main())
