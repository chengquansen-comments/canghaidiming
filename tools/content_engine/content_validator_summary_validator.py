#!/usr/bin/env python3
"""Validate Content Engine v0.6c validator summary outputs."""

from __future__ import annotations

import argparse
import csv
from dataclasses import dataclass, field
from pathlib import Path

from content_validator_orchestrator import SUMMARY_FIELDS, SUMMARY_MD, SUMMARY_TSV, VALIDATOR_SPECS


ALLOWED_STATUS = {"PASS", "WARN", "FAIL"}
REQUIRED_MD_SECTIONS = [
    "# Content Validator Summary",
    "## Validator Results",
    "## Failure Details",
    "## Warning Details",
    "## Runtime Export Readiness",
    "## Next Steps",
]
FORBIDDEN_MD_PHRASES = [
    "runtime export has been approved",
    "runtime export is approved",
    "generated runtime data",
    "runtime data has been generated",
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
        lines.extend([f"PASS: {message}" for message in self.passes])
        lines.extend([f"WARN: {message}" for message in self.warnings])
        lines.extend([f"FAIL: {message}" for message in self.failures])
        lines.append("RESULT: PASS" if self.ok() else "RESULT: FAIL")
        return "\n".join(lines)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Validate Content Engine v0.6c validator summary outputs.")
    parser.add_argument("--design-dir", default="data/design")
    return parser.parse_args()


def read_tsv(path: Path) -> list[dict[str, str]]:
    with path.open("r", encoding="utf-8", newline="") as handle:
        reader = csv.DictReader(handle, delimiter="\t")
        fieldnames = reader.fieldnames or []
        missing = [field for field in SUMMARY_FIELDS if field not in fieldnames]
        if missing:
            raise ValueError("Summary TSV is missing required columns: " + ", ".join(missing))
        return list(reader)


def as_int(value: str, field_name: str) -> int:
    try:
        return int((value or "").strip())
    except ValueError as exc:
        raise ValueError(f"Field {field_name} must be an integer, got: {value!r}") from exc


def validate(design_dir: Path) -> ValidationReport:
    report = ValidationReport()
    summary_tsv = design_dir / SUMMARY_TSV
    summary_md = design_dir / SUMMARY_MD

    if not summary_tsv.exists():
        report.fail(f"Missing required file: {summary_tsv}")
        return report
    if not summary_md.exists():
        report.fail(f"Missing required file: {summary_md}")
        return report

    report.pass_(f"Found {summary_tsv}")
    report.pass_(f"Found {summary_md}")

    try:
        rows = read_tsv(summary_tsv)
        text = summary_md.read_text(encoding="utf-8")
    except ValueError as exc:
        report.fail(str(exc))
        return report

    validate_validator_set(rows, report)
    validate_row_values(rows, report)
    validate_log_paths(rows, report)
    validate_markdown(text, rows, report)
    return report


def validate_validator_set(rows: list[dict[str, str]], report: ValidationReport) -> None:
    expected = [spec.validator_id for spec in VALIDATOR_SPECS]
    actual = [row.get("validator_id", "") for row in rows]

    if len(actual) == len(set(actual)):
        report.pass_("validator_id values are unique.")
    else:
        report.fail("Duplicate validator_id values detected in summary TSV.")

    missing = sorted(set(expected) - set(actual))
    extra = sorted(set(actual) - set(expected))
    if missing:
        report.fail("Summary TSV is missing validators: " + ", ".join(missing))
    else:
        report.pass_("Summary TSV contains all 11 validators.")
    if extra:
        report.warn("Summary TSV contains unexpected validators: " + ", ".join(extra))


def validate_row_values(rows: list[dict[str, str]], report: ValidationReport) -> None:
    for row in rows:
        validator_id = row.get("validator_id", "<missing>")
        status = (row.get("status") or "").strip()
        if status not in ALLOWED_STATUS:
            report.fail(f"Invalid status for {validator_id}: {status!r}")
            continue

        try:
            return_code = as_int(row.get("return_code", ""), "return_code")
            as_int(row.get("warning_count", ""), "warning_count")
            as_int(row.get("error_count", ""), "error_count")
            as_int(row.get("duration_ms", ""), "duration_ms")
        except ValueError as exc:
            report.fail(f"{validator_id}: {exc}")
            continue

        if status == "FAIL":
            notes = row.get("notes", "") or ""
            if return_code == 0 and "parsed_fail" not in notes:
                report.fail(f"{validator_id}: status=FAIL but return_code=0 without parsed_fail note")

    if not report.failures:
        report.pass_("Summary TSV row values are valid.")


def validate_log_paths(rows: list[dict[str, str]], report: ValidationReport) -> None:
    missing_logs: list[str] = []
    for row in rows:
        log_path = Path(row.get("log_path", ""))
        if not log_path.exists():
            missing_logs.append(f"{row.get('validator_id', '<missing>')}:{log_path}")
    if missing_logs:
        report.fail("Missing validator log files: " + ", ".join(missing_logs))
    else:
        report.pass_("All validator log_path files exist.")


def validate_markdown(text: str, rows: list[dict[str, str]], report: ValidationReport) -> None:
    missing = [section for section in REQUIRED_MD_SECTIONS if section not in text]
    if missing:
        report.fail("Summary Markdown is missing sections: " + ", ".join(missing))
    else:
        report.pass_("Summary Markdown contains all required sections.")

    if any(row.get("status") == "FAIL" for row in rows):
        if "## Failure Details" not in text:
            report.fail("Markdown must contain Failure Details when any validator fails.")

    lowered = text.lower()
    bad = [phrase for phrase in FORBIDDEN_MD_PHRASES if phrase in lowered]
    if bad:
        report.fail("Summary Markdown contains forbidden claims: " + ", ".join(bad))
    else:
        report.pass_("Summary Markdown does not claim runtime approval or runtime data generation.")


def main() -> int:
    args = parse_args()
    report = validate(Path(args.design_dir))
    print(report.format())
    return 0 if report.ok() else 1


if __name__ == "__main__":
    raise SystemExit(main())
