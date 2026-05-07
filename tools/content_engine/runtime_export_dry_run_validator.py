#!/usr/bin/env python3
"""Validate Content Engine v0.7b runtime export dry-run outputs."""

from __future__ import annotations

import argparse
import csv
from dataclasses import dataclass, field
from pathlib import Path

from content_package_approval_generator import APPROVAL_TSV
from runtime_export_dry_run import OUTPUT_FIELDS, OUTPUT_MD, OUTPUT_TSV, RUNTIME_DOMAINS


TARGET_PREFIX = "data/runtime/content_engine/"
REQUIRED_MD_SECTIONS = [
    "Runtime Export Dry Run",
    "Dry Run Summary",
    "Export Candidates",
    "Blocked Runtime Artifacts",
    "Decision Rules",
    "Current Blocking Summary",
    "Safety Notes",
    "Next Steps",
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
    parser = argparse.ArgumentParser(description="Validate Content Engine v0.7b runtime export dry-run outputs.")
    parser.add_argument("--design-dir", default="data/design")
    return parser.parse_args()


def parse_bool(value: str) -> bool:
    lowered = (value or "").strip().lower()
    if lowered in {"true", "1", "yes"}:
        return True
    if lowered in {"false", "0", "no"}:
        return False
    raise ValueError(f"Invalid bool value: {value!r}")


def split_csv(value: str) -> set[str]:
    return {part.strip() for part in (value or "").split(",") if part.strip()}


def read_tsv(path: Path, required_fields: list[str]) -> list[dict[str, str]]:
    with path.open("r", encoding="utf-8", newline="") as handle:
        reader = csv.DictReader(handle, delimiter="\t")
        fieldnames = reader.fieldnames or []
        missing = [field for field in required_fields if field not in fieldnames]
        if missing:
            raise ValueError(f"{path} is missing required columns: " + ", ".join(missing))
        return list(reader)


def validate(design_dir: Path) -> ValidationReport:
    report = ValidationReport()
    tsv_path = design_dir / OUTPUT_TSV
    md_path = design_dir / OUTPUT_MD
    approval_path = design_dir / APPROVAL_TSV

    for path in [tsv_path, md_path]:
        if not path.exists():
            report.fail(f"Missing required file: {path}")
            return report
        report.pass_(f"Found {path}")

    try:
        rows = read_tsv(tsv_path, OUTPUT_FIELDS)
        approval_rows = read_tsv(approval_path, ["artifact_id", "approved_for_export"])
    except (ValueError, FileNotFoundError) as exc:
        report.fail(str(exc))
        return report

    validate_domain_coverage(rows, report)
    validate_row_invariants(rows, approval_rows, report)
    validate_runtime_output_absence(rows, report)
    validate_markdown(md_path, report)
    return report


def validate_domain_coverage(rows: list[dict[str, str]], report: ValidationReport) -> None:
    domains = [row.get("runtime_domain", "").strip() for row in rows]
    missing = sorted(set(RUNTIME_DOMAINS) - set(domains))
    extra = sorted(set(domains) - set(RUNTIME_DOMAINS))
    if missing:
        report.fail("Missing runtime_domain rows: " + ", ".join(missing))
    else:
        report.pass_("All 7 required runtime domains are present.")
    if extra:
        report.fail("Unexpected runtime_domain rows: " + ", ".join(extra))

    ids = [row.get("dry_run_id", "").strip() for row in rows]
    if len(ids) != len(set(ids)):
        report.fail("dry_run_id must be unique.")
    else:
        report.pass_("dry_run_id values are unique.")


def validate_row_invariants(
    rows: list[dict[str, str]], approval_rows: list[dict[str, str]], report: ValidationReport
) -> None:
    approved_for_export_count = sum(1 for row in approval_rows if parse_bool(row.get("approved_for_export", "false")))
    would_export_true_rows: list[str] = []
    blocked_false_rows: list[str] = []

    for row in rows:
        domain = row.get("runtime_domain", "<missing>")
        target_path = (row.get("target_path") or "").strip()
        block_reasons = split_csv(row.get("block_reasons", ""))

        if not target_path:
            report.fail(f"target_path must be non-empty: {domain}")
        elif not target_path.startswith(TARGET_PREFIX):
            report.fail(f"target_path must be under {TARGET_PREFIX}: {domain}")

        try:
            would_export = parse_bool(row.get("would_export", "false"))
            blocked = parse_bool(row.get("blocked", "true"))
            export_allowed_now = parse_bool(row.get("export_allowed_now", "false"))
        except ValueError as exc:
            report.fail(f"{domain}: {exc}")
            continue

        if would_export:
            would_export_true_rows.append(domain)
        if not blocked:
            blocked_false_rows.append(domain)

        if not blocked and not would_export:
            report.fail(f"blocked must be true when would_export=false: {domain}")
        if blocked and would_export:
            report.fail(f"blocked must be false when would_export=true: {domain}")
        if not export_allowed_now and would_export:
            report.fail(f"export_allowed_now=false requires would_export=false: {domain}")
        if not block_reasons:
            report.fail(f"block_reasons must be non-empty: {domain}")
        if "approval_not_granted" not in block_reasons and "approved_for_export_false" not in block_reasons:
            report.fail(f"block_reasons must include approval_not_granted or approved_for_export_false: {domain}")

    if would_export_true_rows:
        report.fail("Current phase requires would_export=false for all domains: " + ", ".join(would_export_true_rows))
    else:
        report.pass_("All would_export values are false.")

    if blocked_false_rows:
        report.fail("Current phase requires blocked=true for all domains: " + ", ".join(blocked_false_rows))
    else:
        report.pass_("All blocked values are true.")

    if approved_for_export_count == 0:
        report.pass_("approved_for_export=true count is 0 in current approval table.")
        if would_export_true_rows:
            report.fail("approved_for_export count is 0, therefore would_export must be false for all rows.")
    else:
        report.warn(f"approved_for_export=true count is {approved_for_export_count}; expectations have changed.")


def validate_runtime_output_absence(rows: list[dict[str, str]], report: ValidationReport) -> None:
    existing_runtime_targets: list[str] = []
    for row in rows:
        target_path = (row.get("target_path") or "").strip()
        if target_path and Path(target_path).exists():
            existing_runtime_targets.append(target_path)
    if existing_runtime_targets:
        report.fail(
            "v0.7b must not write runtime JSON files: " + ", ".join(sorted(set(existing_runtime_targets)))
        )
    else:
        report.pass_("No runtime JSON files were written.")


def validate_markdown(path: Path, report: ValidationReport) -> None:
    text = path.read_text(encoding="utf-8")
    for section in REQUIRED_MD_SECTIONS:
        if section not in text:
            report.fail(f"Markdown missing section: {section}")
    if "Runtime export implemented: yes" in text:
        report.fail("Markdown must not claim runtime export is implemented.")
    else:
        report.pass_("Markdown does not claim runtime export implementation.")

    if "Runtime files written: 0" not in text:
        report.fail("Markdown must state runtime files written as 0.")
    else:
        report.pass_("Markdown states runtime files written as 0.")

    if "Runtime files written: 1" in text or "Runtime files written: 2" in text:
        report.fail("Markdown must not claim runtime files were written.")


def main() -> int:
    args = parse_args()
    report = validate(Path(args.design_dir))
    print(report.format())
    return 0 if report.ok() else 1


if __name__ == "__main__":
    raise SystemExit(main())
