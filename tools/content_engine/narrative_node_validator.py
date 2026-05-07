#!/usr/bin/env python3
"""Validate generated narrative node skeleton plan for Content Engine v0.5c."""

from __future__ import annotations

import argparse
import csv
import re
from dataclasses import dataclass, field
from pathlib import Path


VALID_ROUTE_AFFINITY = {"common", "normal", "true_route", "wuzhuangyuan", "mixed", "optional"}
VALID_NODE_KIND = {
    "operation_hook",
    "battle_hook",
    "old_case_clue",
    "military_gate",
    "clean_reputation",
    "lightness_encounter",
    "boss_prepare",
    "route_offer",
    "ending_hint",
}
VALID_NARRATIVE_ROLE = {
    "setup",
    "clue",
    "pressure",
    "choice",
    "consequence",
    "preparation",
    "route_unlock",
    "foreshadow",
    "ending_bridge",
}
REQUIRED_HINT_IDS = {
    "true_route_hint_01",
    "wuzhuangyuan_offer_hint_01",
    "normal_ending_hint_01",
    "boss_prepare_hint_01",
}
FORBIDDEN_RESULT_PATTERNS = [
    re.compile(r"军功[+＋]\d+"),
    re.compile(r"清望[+＋]\d+"),
    re.compile(r"武境[+＋]\d+"),
    re.compile(r"martial_xp", re.IGNORECASE),
    re.compile(r"weapon_xp", re.IGNORECASE),
    re.compile(r"military_merit", re.IGNORECASE),
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
    parser = argparse.ArgumentParser(description="Validate Content Engine v0.5c narrative node plan.")
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


def split_tags(value: str) -> set[str]:
    out: set[str] = set()
    for part in (value or "").split(","):
        token = part.strip()
        if not token or token.lower() == "none":
            continue
        out.add(token)
    return out


def validate(design_dir: Path) -> ValidationReport:
    report = ValidationReport()
    narrative_path = design_dir / "generated_narrative_node_plan.tsv"
    operation_path = design_dir / "generated_operation_node_plan.tsv"
    reward_path = design_dir / "generated_battle_reward_plan.tsv"
    if not narrative_path.exists():
        report.fail(f"Missing required file: {narrative_path}")
        return report
    if not operation_path.exists():
        report.fail(f"Missing required file: {operation_path}")
        return report
    if not reward_path.exists():
        report.fail(f"Missing required file: {reward_path}")
        return report

    report.pass_(f"Found {narrative_path}")
    rows = read_tsv(narrative_path)
    operation_rows = read_tsv(operation_path)
    reward_rows = read_tsv(reward_path)
    if not rows:
        report.fail("generated_narrative_node_plan.tsv is empty.")
        return report

    validate_row_count(rows, report)
    validate_unique_ids(rows, report)
    validate_operation_coverage(rows, operation_rows, report)
    validate_boss_coverage(rows, reward_rows, report)
    validate_required_hints(rows, report)
    validate_body_constraints(rows, report)
    validate_keys(rows, report)
    validate_enums(rows, report)
    validate_route_constraints(rows, report)
    validate_lightness_constraints(rows, report)
    return report


def validate_row_count(rows: list[dict[str, str]], report: ValidationReport) -> None:
    total = len(rows)
    if 26 <= total <= 36:
        report.pass_(f"Narrative skeleton count is within expected range 26-36 (actual={total}).")
    else:
        report.warn(f"Narrative skeleton count is outside suggested range 26-36 (actual={total}).")


def validate_unique_ids(rows: list[dict[str, str]], report: ValidationReport) -> None:
    ids = [row.get("narrative_node_id", "") for row in rows]
    if len(ids) == len(set(ids)):
        report.pass_("narrative_node_id values are unique.")
    else:
        report.fail("Duplicate narrative_node_id detected.")


def validate_operation_coverage(
    narrative_rows: list[dict[str, str]], operation_rows: list[dict[str, str]], report: ValidationReport
) -> None:
    missing: list[str] = []
    for row in operation_rows:
        operation_id = row.get("operation_node_id", "")
        covered = any(
            node.get("source_type") == "operation_node"
            and (
                node.get("source_id") == operation_id
                or node.get("source_operation_node_id") == operation_id
            )
            for node in narrative_rows
        )
        if not covered:
            missing.append(operation_id)
    if missing:
        report.fail("Some operation nodes have no narrative skeleton: " + ", ".join(missing))
    else:
        report.pass_("Each operation node has at least one narrative skeleton.")


def validate_boss_coverage(
    narrative_rows: list[dict[str, str]], reward_rows: list[dict[str, str]], report: ValidationReport
) -> None:
    narrative_reward_ids = {
        row.get("source_reward_plan_id", "") or row.get("source_id", "")
        for row in narrative_rows
        if row.get("source_type") == "battle_reward"
    }

    for battle_type in ["boss", "true_boss", "wuzhuangyuan_exam"]:
        reward_ids = {row.get("reward_plan_id", "") for row in reward_rows if row.get("battle_type") == battle_type}
        covered = bool(reward_ids & narrative_reward_ids)
        if covered:
            report.pass_(f"{battle_type} has at least one narrative skeleton.")
        else:
            report.fail(f"{battle_type} is missing narrative skeleton coverage.")


def validate_required_hints(rows: list[dict[str, str]], report: ValidationReport) -> None:
    source_ids = {row.get("source_id", "") for row in rows}
    node_ids = {row.get("narrative_node_id", "") for row in rows}
    missing: list[str] = []
    for hint_id in REQUIRED_HINT_IDS:
        if hint_id in source_ids:
            continue
        if any(hint_id in node_id for node_id in node_ids):
            continue
        missing.append(hint_id)
    if missing:
        report.fail("Missing required hint nodes: " + ", ".join(missing))
    else:
        report.pass_("Required route hints all exist.")


def validate_body_constraints(rows: list[dict[str, str]], report: ValidationReport) -> None:
    bad_body = [row.get("narrative_node_id", "") for row in rows if row.get("should_write_body", "").strip().lower() != "false"]
    bad_budget = [row.get("narrative_node_id", "") for row in rows if as_int(row.get("line_budget", "0"), 0) > 1]
    if bad_body:
        report.fail("should_write_body must be false: " + ", ".join(bad_body))
    else:
        report.pass_("All should_write_body values are false.")
    if bad_budget:
        report.fail("line_budget exceeds 1: " + ", ".join(bad_budget))
    else:
        report.pass_("All line_budget values are <= 1.")


def validate_keys(rows: list[dict[str, str]], report: ValidationReport) -> None:
    bad_empty: list[str] = []
    bad_same: list[str] = []
    bad_result: list[str] = []
    for row in rows:
        node_id = row.get("narrative_node_id", "")
        preview_key = row.get("preview_key", "").strip()
        result_key = row.get("result_key", "").strip()
        if not preview_key or not result_key:
            bad_empty.append(node_id)
        if preview_key and result_key and preview_key == result_key:
            bad_same.append(node_id)
        for pattern in FORBIDDEN_RESULT_PATTERNS:
            if pattern.search(result_key):
                bad_result.append(node_id)
                break
    if bad_empty:
        report.fail("preview_key/result_key must be non-empty: " + ", ".join(bad_empty))
    else:
        report.pass_("All preview_key/result_key are non-empty.")
    if bad_same:
        report.fail("preview_key and result_key cannot be the same: " + ", ".join(bad_same))
    else:
        report.pass_("preview_key and result_key are separated.")
    if bad_result:
        report.fail("result_key contains forbidden numeric-display style content: " + ", ".join(bad_result))
    else:
        report.pass_("result_key contains no numeric-display style content.")


def validate_enums(rows: list[dict[str, str]], report: ValidationReport) -> None:
    bad_route = [row.get("narrative_node_id", "") for row in rows if row.get("route_affinity", "") not in VALID_ROUTE_AFFINITY]
    bad_kind = [row.get("narrative_node_id", "") for row in rows if row.get("node_kind", "") not in VALID_NODE_KIND]
    bad_role = [row.get("narrative_node_id", "") for row in rows if row.get("narrative_role", "") not in VALID_NARRATIVE_ROLE]

    if bad_route:
        report.fail("Invalid route_affinity values: " + ", ".join(bad_route))
    else:
        report.pass_("All route_affinity values are valid.")
    if bad_kind:
        report.fail("Invalid node_kind values: " + ", ".join(bad_kind))
    else:
        report.pass_("All node_kind values are valid.")
    if bad_role:
        report.fail("Invalid narrative_role values: " + ", ".join(bad_role))
    else:
        report.pass_("All narrative_role values are valid.")


def is_wuzhuangyuan_related(row: dict[str, str]) -> bool:
    if row.get("route_affinity") == "wuzhuangyuan":
        return True
    if row.get("source_type") == "wuzhuangyuan_offer":
        return True
    if "wuzhuangyuan" in row.get("source_id", ""):
        return True
    tags = split_tags(row.get("hook_tags", "")) | split_tags(row.get("route_gate_tags", ""))
    return any("wuzhuangyuan" in tag for tag in tags)


def is_true_route_related(row: dict[str, str]) -> bool:
    if row.get("route_affinity") == "true_route":
        return True
    if row.get("route_type") == "true_route":
        return True
    if "true_route" in row.get("source_id", ""):
        return True
    if row.get("node_kind") in {"old_case_clue", "ending_hint"} and "true" in row.get("source_id", ""):
        return True
    return False


def validate_route_constraints(rows: list[dict[str, str]], report: ValidationReport) -> None:
    bad_wz_required: list[str] = []
    bad_wz_old_case: list[str] = []
    bad_true_route_tags: list[str] = []
    bad_normal_lightness_required: list[str] = []

    for row in rows:
        node_id = row.get("narrative_node_id", "")
        required_flags = split_tags(row.get("required_flags", ""))
        hook_tags = split_tags(row.get("hook_tags", ""))
        gate_tags = split_tags(row.get("route_gate_tags", ""))

        if is_wuzhuangyuan_related(row):
            if "martial_realm_10" not in required_flags or "high_military_merit" not in required_flags:
                bad_wz_required.append(node_id)
            if any("old_case" in flag for flag in required_flags):
                bad_wz_old_case.append(node_id)

        if is_true_route_related(row):
            joined = hook_tags | gate_tags
            expected = {"old_case", "old_case_progress", "true_route_candidate", "true_boss_hint", "key_evidence"}
            if not (joined & expected):
                bad_true_route_tags.append(node_id)

        if row.get("route_affinity") in {"normal", "common"} and (
            row.get("node_kind") == "ending_hint" or "normal_ending" in row.get("source_id", "")
        ):
            if {"lightness_3", "lightness_4", "lightness_cap_3", "lightness_cap_4"} & required_flags:
                bad_normal_lightness_required.append(node_id)

    if bad_wz_required:
        report.fail("Wuzhuangyuan nodes must require martial_realm_10 + high_military_merit: " + ", ".join(bad_wz_required))
    else:
        report.pass_("Wuzhuangyuan required flag constraints are satisfied.")
    if bad_wz_old_case:
        report.fail("Wuzhuangyuan nodes should not require old_case progression: " + ", ".join(bad_wz_old_case))
    else:
        report.pass_("Wuzhuangyuan nodes do not force old_case progression.")
    if bad_true_route_tags:
        report.fail("True-route nodes must include old_case/true_route related tags: " + ", ".join(bad_true_route_tags))
    else:
        report.pass_("True-route nodes include old_case/true_route related tags.")
    if bad_normal_lightness_required:
        report.fail("Normal ending nodes must not require lightness_3/4: " + ", ".join(bad_normal_lightness_required))
    else:
        report.pass_("Normal ending nodes do not require lightness_3/4.")


def validate_lightness_constraints(rows: list[dict[str, str]], report: ValidationReport) -> None:
    bad_cap4_related: list[str] = []
    bad_required_flag: list[str] = []
    for row in rows:
        node_id = row.get("narrative_node_id", "")
        route_affinity = row.get("route_affinity", "")
        risk_level = row.get("risk_level", "")
        required_flags = split_tags(row.get("required_flags", ""))
        optional_flags = split_tags(row.get("optional_flags", ""))
        tags = split_tags(row.get("route_gate_tags", "")) | split_tags(row.get("hook_tags", "")) | split_tags(row.get("lightness_tags", ""))
        cap4_related = "lightness_cap_4" in tags or "lightness_4" in required_flags or "lightness_4" in optional_flags
        if cap4_related:
            route_ok = route_affinity in {"true_route", "wuzhuangyuan", "optional", "mixed"}
            risk_ok = risk_level in {"rare", "route"}
            if not (route_ok or risk_ok):
                bad_cap4_related.append(node_id)
        if "lightness_4_required" in required_flags:
            bad_required_flag.append(node_id)

    if bad_cap4_related:
        report.fail("lightness_cap_4 related nodes must be rare/route/true_route/wuzhuangyuan related: " + ", ".join(bad_cap4_related))
    else:
        report.pass_("lightness_cap_4 related node placement is valid.")
    if bad_required_flag:
        report.fail("required_flags must not include lightness_4_required: " + ", ".join(bad_required_flag))
    else:
        report.pass_("No lightness_4_required appears in required_flags.")


def main() -> int:
    args = parse_args()
    report = validate(Path(args.design_dir))
    print(report.format())
    return 0 if report.ok() else 1


if __name__ == "__main__":
    raise SystemExit(main())
