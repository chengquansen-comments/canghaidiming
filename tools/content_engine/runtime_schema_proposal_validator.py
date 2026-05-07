#!/usr/bin/env python3
"""Validate Content Engine v0.7a runtime schema proposal outputs."""

from __future__ import annotations

import argparse
import csv
from dataclasses import dataclass, field
from pathlib import Path

from content_package_approval_generator import APPROVAL_TSV
from content_package_manifest_generator import MANIFEST_FILENAME
from content_validator_orchestrator import SUMMARY_TSV
from runtime_schema_proposal_generator import OUTPUT_FIELDS, OUTPUT_TSV


ALLOWED_DOMAINS = {
    "enemy_deck",
    "card_pool",
    "battle_reward",
    "operation_node",
    "narrative_node",
    "route_gate",
    "package_manifest",
}
REQUIRED_DOMAINS = sorted(ALLOWED_DOMAINS)
RUNTIME_PREFIX = "data/runtime/content_engine/"


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
    parser = argparse.ArgumentParser(description="Validate Content Engine v0.7a runtime schema proposal.")
    parser.add_argument("--design-dir", default="data/design")
    return parser.parse_args()


def read_tsv(path: Path, required_fields: list[str]) -> list[dict[str, str]]:
    with path.open("r", encoding="utf-8", newline="") as handle:
        reader = csv.DictReader(handle, delimiter="\t")
        fieldnames = reader.fieldnames or []
        missing = [field for field in required_fields if field not in fieldnames]
        if missing:
            raise ValueError(f"{path} is missing required columns: " + ", ".join(missing))
        return list(reader)


def parse_bool(value: str) -> bool:
    lowered = (value or "").strip().lower()
    if lowered in {"true", "1", "yes"}:
        return True
    if lowered in {"false", "0", "no"}:
        return False
    raise ValueError(f"Invalid bool value: {value!r}")


def split_csv(value: str) -> set[str]:
    return {part.strip() for part in (value or "").split(",") if part.strip()}


def validate(design_dir: Path) -> ValidationReport:
    report = ValidationReport()
    proposal_path = design_dir / OUTPUT_TSV
    manifest_path = design_dir / MANIFEST_FILENAME
    summary_path = design_dir / SUMMARY_TSV
    approval_path = design_dir / APPROVAL_TSV

    for path in [proposal_path, manifest_path, summary_path, approval_path]:
        if not path.exists():
            report.fail(f"Missing required file: {path}")
            return report
        report.pass_(f"Found {path}")

    try:
        rows = read_tsv(proposal_path, OUTPUT_FIELDS)
    except ValueError as exc:
        report.fail(str(exc))
        return report

    if not rows:
        report.fail(f"{proposal_path} is empty.")
        return report

    validate_domains(rows, report)
    validate_common_rules(rows, report)
    validate_runtime_file_absence(rows, report)
    validate_notes(rows, report)
    return report


def validate_domains(rows: list[dict[str, str]], report: ValidationReport) -> None:
    domains = {row.get("runtime_domain", "").strip() for row in rows}
    missing = sorted(set(REQUIRED_DOMAINS) - domains)
    bad = sorted(domain for domain in domains if domain not in ALLOWED_DOMAINS)
    if missing:
        report.fail("Missing runtime domains: " + ", ".join(missing))
    else:
        report.pass_("All 7 required runtime domains are present.")
    if bad:
        report.fail("Invalid runtime_domain values: " + ", ".join(bad))


def validate_common_rules(rows: list[dict[str, str]], report: ValidationReport) -> None:
    for row in rows:
        schema_id = (row.get("schema_id") or "").strip()
        target_path = (row.get("target_path") or "").strip()
        source_artifacts = split_csv(row.get("source_artifacts", ""))
        req_approval = (row.get("required_approval_status") or "").strip()
        req_validator = (row.get("required_validator_status") or "").strip()

        if not schema_id:
            report.fail("schema_id must be non-empty.")
        if not target_path:
            report.fail(f"target_path must be non-empty for schema {schema_id}")
        elif not target_path.startswith(RUNTIME_PREFIX):
            report.fail(f"target_path must be under {RUNTIME_PREFIX}: {schema_id}")

        try:
            export_now = parse_bool(row.get("export_allowed_now", "false"))
            requires_waiver = parse_bool(row.get("requires_waiver_clearance", "false"))
        except ValueError as exc:
            report.fail(f"{schema_id}: {exc}")
            continue

        if export_now:
            report.fail(f"export_allowed_now must be false for all rows: {schema_id}")
        if req_approval != "approved":
            report.fail(f"required_approval_status must be approved: {schema_id}")
        if req_validator != "PASS":
            report.fail(f"required_validator_status must be PASS: {schema_id}")

        if {"generated_enemy_deck_sets", "generated_enemy_deck_skeleton"} & source_artifacts and not requires_waiver:
            report.fail(f"requires_waiver_clearance must be true when schema depends on WARN artifacts: {schema_id}")

    report.pass_("Common schema policy rules validated.")


def validate_runtime_file_absence(rows: list[dict[str, str]], report: ValidationReport) -> None:
    bad: list[str] = []
    for row in rows:
        path = Path((row.get("target_path") or "").strip())
        if path.exists():
            bad.append(path.as_posix())
    if bad:
        report.fail("Runtime output files must not exist in v0.7a: " + ", ".join(sorted(set(bad))))
    else:
        report.pass_("No runtime JSON output files were created.")


def validate_notes(rows: list[dict[str, str]], report: ValidationReport) -> None:
    by_domain: dict[str, list[str]] = {}
    for row in rows:
        domain = (row.get("runtime_domain") or "").strip()
        notes = (row.get("notes") or "").lower()
        by_domain.setdefault(domain, []).append(notes)

    narrative_notes = " ".join(by_domain.get("narrative_node", []))
    card_pool_notes = " ".join(by_domain.get("card_pool", []))
    route_notes = " ".join(by_domain.get("route_gate", []))

    if "skeleton" not in narrative_notes or "no final prose" not in narrative_notes:
        report.fail("narrative_node notes must mention skeleton only / no final prose.")
    else:
        report.pass_("narrative_node notes include skeleton-only warning.")

    if "design_only" not in card_pool_notes or "not runtime-ready" not in card_pool_notes:
        report.fail("card_pool notes must mention design_only card not runtime-ready.")
    else:
        report.pass_("card_pool notes include design-only warning.")

    if "design-layer only" not in route_notes or "not" not in route_notes or "godot" not in route_notes:
        report.fail("route_gate notes must mention design-layer only / not Godot runtime logic.")
    else:
        report.pass_("route_gate notes include runtime-logic boundary warning.")

    all_notes = " ".join((row.get("notes") or "").lower() for row in rows)
    if "runtime export implemented" in all_notes:
        report.fail("Schema proposal must not claim runtime export is implemented.")


def main() -> int:
    args = parse_args()
    report = validate(Path(args.design_dir))
    print(report.format())
    return 0 if report.ok() else 1


if __name__ == "__main__":
    raise SystemExit(main())
