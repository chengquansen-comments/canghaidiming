#!/usr/bin/env python3
"""Validate Content Engine v0.6d content package approval outputs."""

from __future__ import annotations

import argparse
import csv
from dataclasses import dataclass, field
from pathlib import Path

from content_package_approval_generator import APPROVAL_FIELDS, APPROVAL_TSV
from content_package_manifest_generator import MANIFEST_FILENAME
from content_validator_orchestrator import SUMMARY_TSV


ALLOWED_APPROVAL_STATUS = {"pending_review", "approved", "rejected", "blocked", "waiver_required"}
HIGH_RISK_REQUIRED = {"generated_card_pool", "generated_enemy_deck_sets", "generated_enemy_deck_skeleton"}
WARN_REQUIRED = {"generated_enemy_deck_skeleton", "generated_enemy_deck_sets"}


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
    parser = argparse.ArgumentParser(description="Validate Content Engine v0.6d content package approval table.")
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


def split_csv(value: str) -> set[str]:
    return {part.strip() for part in (value or "").split(",") if part.strip()}


def as_int(value: str, field_name: str) -> int:
    try:
        return int((value or "").strip())
    except ValueError as exc:
        raise ValueError(f"Field {field_name} must be integer, got: {value!r}") from exc


def validate(design_dir: Path) -> ValidationReport:
    report = ValidationReport()
    approval_path = design_dir / APPROVAL_TSV
    manifest_path = design_dir / MANIFEST_FILENAME
    summary_path = design_dir / SUMMARY_TSV

    for path in [approval_path, manifest_path, summary_path]:
        if not path.exists():
            report.fail(f"Missing required file: {path}")
            return report
        report.pass_(f"Found {path}")

    try:
        approval_rows = read_tsv(approval_path, APPROVAL_FIELDS)
        manifest_rows = read_tsv(manifest_path, ["artifact_id"])
        _ = read_tsv(summary_path, ["validator_id", "status"])
    except ValueError as exc:
        report.fail(str(exc))
        return report

    validate_coverage(approval_rows, manifest_rows, report)
    validate_rows(approval_rows, report)
    return report


def validate_coverage(approval_rows: list[dict[str, str]], manifest_rows: list[dict[str, str]], report: ValidationReport) -> None:
    approval_ids = [row.get("approval_id", "") for row in approval_rows]
    artifact_ids = [row.get("artifact_id", "") for row in approval_rows]
    manifest_ids = {row.get("artifact_id", "") for row in manifest_rows}

    if len(approval_ids) == len(set(approval_ids)):
        report.pass_("approval_id values are unique.")
    else:
        report.fail("Duplicate approval_id values detected.")

    if len(artifact_ids) == len(set(artifact_ids)):
        report.pass_("artifact_id values are unique.")
    else:
        report.fail("Duplicate artifact_id values detected.")

    missing = sorted(manifest_ids - set(artifact_ids))
    if missing:
        report.fail("Approval table is missing manifest artifacts: " + ", ".join(missing))
    else:
        report.pass_("Approval table contains all 13 manifest artifacts.")


def validate_rows(rows: list[dict[str, str]], report: ValidationReport) -> None:
    approved_true: list[str] = []
    for row in rows:
        artifact_id = row.get("artifact_id", "<missing>")
        approval_status = (row.get("approval_status") or "").strip()
        validator_status = (row.get("validator_status") or "").strip()
        waiver_flags = split_csv(row.get("waiver_flags", ""))
        required_actions = split_csv(row.get("required_actions", ""))
        export_blockers = split_csv(row.get("export_blockers", ""))
        risk_level = (row.get("risk_level") or "").strip()
        approved_for_export = (row.get("approved_for_export") or "").strip()

        if approval_status not in ALLOWED_APPROVAL_STATUS:
            report.fail(f"Invalid approval_status for {artifact_id}: {approval_status!r}")
        if approved_for_export not in {"true", "false"}:
            report.fail(f"approved_for_export must be true/false for {artifact_id}")
        if approved_for_export == "true":
            approved_true.append(artifact_id)

        try:
            as_int(row.get("validator_warning_count", ""), "validator_warning_count")
            as_int(row.get("validator_error_count", ""), "validator_error_count")
        except ValueError as exc:
            report.fail(f"{artifact_id}: {exc}")

        if validator_status == "FAIL" and approval_status != "blocked":
            report.fail(f"FAIL artifact must be blocked: {artifact_id}")
        if validator_status == "WARN" and approval_status != "waiver_required":
            report.fail(f"WARN artifact must be waiver_required: {artifact_id}")
        if validator_status == "WARN" and "waiver_required" not in waiver_flags:
            report.fail(f"WARN artifact must include waiver_required flag: {artifact_id}")
        if validator_status == "WARN" and not ({"resolve_validator_warning", "manual_waiver_required"} & required_actions):
            report.fail(f"WARN artifact must include resolve/manual waiver action: {artifact_id}")
        if validator_status == "PASS" and approval_status == "approved":
            report.fail(f"PASS artifact must not be auto-approved: {artifact_id}")
        if not export_blockers:
            report.fail(f"export_blockers must not be empty: {artifact_id}")
        if "approval_not_granted" not in export_blockers:
            report.fail(f"approval_not_granted blocker is required: {artifact_id}")
        if artifact_id in HIGH_RISK_REQUIRED and risk_level == "low":
            report.fail(f"High-risk artifact must not be low risk: {artifact_id}")

    for artifact_id in WARN_REQUIRED:
        row = next((item for item in rows if item.get("artifact_id") == artifact_id), None)
        if row is None:
            continue
        if row.get("approval_status") != "waiver_required":
            report.fail(f"{artifact_id} must be waiver_required due to validator WARN")

    if approved_true:
        report.fail("No artifact should have approved_for_export=true in v0.6d: " + ", ".join(approved_true))
    else:
        report.pass_("No artifact is auto-approved for export.")


def main() -> int:
    args = parse_args()
    report = validate(Path(args.design_dir))
    print(report.format())
    return 0 if report.ok() else 1


if __name__ == "__main__":
    raise SystemExit(main())
