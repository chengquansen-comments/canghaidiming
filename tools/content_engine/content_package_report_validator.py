#!/usr/bin/env python3
"""Validate Content Engine v0.6b content package report."""

from __future__ import annotations

import argparse
import re
from dataclasses import dataclass, field
from pathlib import Path

from content_package_manifest_generator import MANIFEST_FILENAME
from content_package_report_generator import REPORT_FILENAME, blocked_rows, count_runtime_ready, read_manifest


REQUIRED_SECTIONS = [
    "## 2. Executive Summary",
    "## 3. Artifact Inventory",
    "## 4. Dependency Graph",
    "## 5. Validator Status Summary",
    "## 6. Export Readiness",
    "## 7. Runtime Export Blockers",
    "## 8. Risk Notes",
    "## 9. Suggested Next Steps",
]
FORBIDDEN_PHRASES = [
    "runtime data has been generated",
    "generated runtime data",
    "can be directly exported to runtime",
    "can directly enter runtime",
    "already runtime-ready for export",
]
NOT_RUN_EXPLANATION = "NOT_RUN does not mean invalid. It means the manifest generator did not re-run validators."
RUNTIME_BLOCK_NOTE = "no artifact should be consumed by runtime exporter yet."


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
    parser = argparse.ArgumentParser(description="Validate Content Engine v0.6b content package report.")
    parser.add_argument("--design-dir", default="data/design")
    return parser.parse_args()


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def require_line_value(text: str, label: str) -> int:
    pattern = re.compile(rf"^- {re.escape(label)}: (\d+)$", re.MULTILINE)
    match = pattern.search(text)
    if not match:
        raise ValueError(f"Report is missing required summary line: - {label}: <number>")
    return int(match.group(1))


def validate(design_dir: Path) -> ValidationReport:
    report = ValidationReport()
    manifest_path = design_dir / MANIFEST_FILENAME
    report_path = design_dir / REPORT_FILENAME

    if not manifest_path.exists():
        report.fail(f"Missing required file: {manifest_path}")
        return report
    if not report_path.exists():
        report.fail(f"Missing required file: {report_path}")
        return report

    report.pass_(f"Found {manifest_path}")
    report.pass_(f"Found {report_path}")

    try:
        manifest_rows = read_manifest(manifest_path)
        text = read_text(report_path)
    except (FileNotFoundError, ValueError) as exc:
        report.fail(str(exc))
        return report

    validate_title(text, report)
    validate_sections(text, report)
    try:
        validate_summary_counts(text, manifest_rows, report)
    except ValueError as exc:
        report.fail(str(exc))
    validate_artifact_mentions(text, manifest_rows, report)
    validate_required_notes(text, manifest_rows, report)
    validate_forbidden_claims(text, report)
    return report


def validate_title(text: str, report: ValidationReport) -> None:
    if "# Content Package Report" in text:
        report.pass_("Report title is present.")
    else:
        report.fail("Report is missing title: # Content Package Report")


def validate_sections(text: str, report: ValidationReport) -> None:
    missing = [section for section in REQUIRED_SECTIONS if section not in text]
    if missing:
        report.fail("Report is missing required sections: " + ", ".join(missing))
    else:
        report.pass_("All required report sections are present.")


def validate_summary_counts(text: str, manifest_rows: list, report: ValidationReport) -> None:
    artifact_count = require_line_value(text, "Artifact count")
    runtime_ready_count = require_line_value(text, "Runtime ready artifacts")
    blocked_count = require_line_value(text, "Blocked artifacts")

    expected_artifact_count = len(manifest_rows)
    expected_runtime_ready_count = count_runtime_ready(manifest_rows)
    expected_blocked_count = len(blocked_rows(manifest_rows))

    if artifact_count == expected_artifact_count:
        report.pass_(f"Artifact count matches manifest ({artifact_count}).")
    else:
        report.fail(f"Artifact count mismatch: report={artifact_count}, manifest={expected_artifact_count}")

    if runtime_ready_count == expected_runtime_ready_count:
        report.pass_(f"Runtime ready artifact count matches manifest ({runtime_ready_count}).")
    else:
        report.fail(
            f"Runtime ready artifact count mismatch: report={runtime_ready_count}, manifest={expected_runtime_ready_count}"
        )

    if blocked_count == expected_blocked_count:
        report.pass_(f"Blocked artifact count matches manifest ({blocked_count}).")
    else:
        report.fail(f"Blocked artifact count mismatch: report={blocked_count}, manifest={expected_blocked_count}")


def validate_artifact_mentions(text: str, manifest_rows: list, report: ValidationReport) -> None:
    missing = [row.artifact_id for row in manifest_rows if row.artifact_id not in text]
    if missing:
        report.fail("Report does not mention all manifest artifacts: " + ", ".join(missing))
    else:
        report.pass_("Every manifest artifact_id appears in the report.")


def validate_required_notes(text: str, manifest_rows: list, report: ValidationReport) -> None:
    if any(row.validator_status == "NOT_RUN" for row in manifest_rows):
        if NOT_RUN_EXPLANATION in text:
            report.pass_("Report explains NOT_RUN status correctly.")
        else:
            report.fail("Manifest contains NOT_RUN but report does not explain that NOT_RUN is not invalid.")

    if all(not row.is_runtime_ready for row in manifest_rows):
        if RUNTIME_BLOCK_NOTE in text:
            report.pass_("Report states that runtime exporter should not consume artifacts yet.")
        else:
            report.fail("All artifacts are blocked, but report is missing the runtime consumption warning.")


def validate_forbidden_claims(text: str, report: ValidationReport) -> None:
    lowered = text.lower()
    bad = [phrase for phrase in FORBIDDEN_PHRASES if phrase in lowered]
    if bad:
        report.fail("Report contains forbidden runtime-export claims: " + ", ".join(bad))
    else:
        report.pass_("Report does not claim runtime data generation or direct runtime export.")


def main() -> int:
    args = parse_args()
    report = validate(Path(args.design_dir))
    print(report.format())
    return 0 if report.ok() else 1


if __name__ == "__main__":
    raise SystemExit(main())
