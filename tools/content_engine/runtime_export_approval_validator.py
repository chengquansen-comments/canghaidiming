#!/usr/bin/env python3
"""Validate Content Engine v0.7c runtime export approval overlay outputs."""

from __future__ import annotations

import argparse
import csv
from dataclasses import dataclass, field
from pathlib import Path

from runtime_export_approval_overlay import (
    ALLOWED_APPROVAL_STATUS,
    ALLOWED_WAIVER_STATUS,
    APPROVAL_FIELDS,
    APPROVAL_TSV,
    OUTPUT_FIELDS,
    OUTPUT_MD,
    OUTPUT_TSV,
)
from runtime_export_dry_run import OUTPUT_TSV as DRY_RUN_TSV


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
    parser = argparse.ArgumentParser(description="Validate runtime export approval overlay outputs.")
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
    approval_path = design_dir / APPROVAL_TSV
    dry_run_path = design_dir / DRY_RUN_TSV
    overlay_tsv = design_dir / OUTPUT_TSV
    overlay_md = design_dir / OUTPUT_MD

    for path in [approval_path, dry_run_path, overlay_tsv, overlay_md]:
        if not path.exists():
            report.fail(f"Missing required file: {path}")
            return report
        report.pass_(f"Found {path}")

    try:
        approval_rows = read_tsv(approval_path, APPROVAL_FIELDS)
        dry_rows = read_tsv(dry_run_path, ["runtime_domain", "source_artifacts"])
        overlay_rows = read_tsv(overlay_tsv, OUTPUT_FIELDS)
    except ValueError as exc:
        report.fail(str(exc))
        return report

    validate_approval_table(approval_rows, dry_rows, report)
    validate_overlay_rows(approval_rows, dry_rows, overlay_rows, report)
    validate_markdown(overlay_md, report)
    return report


def validate_approval_table(
    approval_rows: list[dict[str, str]], dry_rows: list[dict[str, str]], report: ValidationReport
) -> None:
    known_pairs: set[tuple[str, str]] = set()
    for row in dry_rows:
        domain = (row.get("runtime_domain") or "").strip()
        for artifact_id in split_csv(row.get("source_artifacts", "")):
            known_pairs.add((domain, artifact_id))

    seen_pairs: set[tuple[str, str]] = set()
    for row in approval_rows:
        domain = (row.get("runtime_domain") or "").strip()
        artifact_id = (row.get("artifact_id") or "").strip()
        pair = (domain, artifact_id)
        if pair in seen_pairs:
            report.fail(f"Duplicate approval row: {domain}/{artifact_id}")
        seen_pairs.add(pair)

        status = (row.get("approval_status") or "").strip()
        if status not in ALLOWED_APPROVAL_STATUS:
            report.fail(f"Invalid approval_status for {domain}/{artifact_id}: {status!r}")

        waiver_status = (row.get("waiver_status") or "").strip()
        if waiver_status not in ALLOWED_WAIVER_STATUS:
            report.fail(f"Invalid waiver_status for {domain}/{artifact_id}: {waiver_status!r}")

        try:
            approved_for_export = parse_bool(row.get("approved_for_export", "false"))
        except ValueError as exc:
            report.fail(f"{domain}/{artifact_id}: {exc}")
            continue

        validator_status = (row.get("validator_status") or "").strip()
        waiver_flags = split_csv(row.get("waiver_flags", ""))
        approved_by = (row.get("approved_by") or "").strip()
        approved_at = (row.get("approved_at") or "").strip()
        notes = (row.get("approval_notes") or "").lower()

        if approved_for_export:
            if validator_status != "PASS":
                report.fail(f"approved_for_export=true requires validator_status=PASS: {domain}/{artifact_id}")
            if status != "approved":
                report.fail(f"approved_for_export=true requires approval_status=approved: {domain}/{artifact_id}")
            if waiver_flags:
                report.fail(f"approved_for_export=true requires waiver_flags empty: {domain}/{artifact_id}")
            if waiver_status not in {"none", "cleared"}:
                report.fail(f"approved_for_export=true requires waiver_status none/cleared: {domain}/{artifact_id}")
            if not approved_by or not approved_at:
                report.fail(f"approved_for_export=true requires approved_by and approved_at: {domain}/{artifact_id}")

        if pair not in known_pairs:
            if "orphan" not in notes and "unknown" not in notes:
                report.fail(f"Unknown approval record must be marked orphan/unknown: {domain}/{artifact_id}")

    report.pass_("Approval table fields, enums, and manual approval constraints validated.")


def validate_overlay_rows(
    approval_rows: list[dict[str, str]],
    dry_rows: list[dict[str, str]],
    overlay_rows: list[dict[str, str]],
    report: ValidationReport,
) -> None:
    expected_domains = {(row.get("runtime_domain") or "").strip() for row in dry_rows}
    overlay_domains = {(row.get("runtime_domain") or "").strip() for row in overlay_rows}
    if expected_domains != overlay_domains:
        report.fail("Overlay runtime domains must match dry-run domains.")
    else:
        report.pass_("Overlay runtime domains match dry-run domains.")

    approval_map: dict[tuple[str, str], dict[str, str]] = {}
    for row in approval_rows:
        approval_map[((row.get("runtime_domain") or "").strip(), (row.get("artifact_id") or "").strip())] = row

    for row in overlay_rows:
        domain = (row.get("runtime_domain") or "").strip()
        source_artifacts = split_csv(row.get("source_artifacts", ""))
        reasons = split_csv(row.get("blocked_reasons", ""))
        would_export = parse_bool(row.get("would_export", "false"))
        blocked = parse_bool(row.get("blocked", "true"))
        unknown_records = split_csv(row.get("unknown_approval_records", ""))

        if would_export and blocked:
            report.fail(f"would_export=true requires blocked=false: {domain}")
        if not would_export and not blocked:
            report.fail(f"would_export=false requires blocked=true: {domain}")

        if would_export:
            for artifact_id in source_artifacts:
                approval = approval_map.get((domain, artifact_id))
                if approval is None:
                    report.fail(f"would_export=true but approval missing: {domain}/{artifact_id}")
                    continue
                if (approval.get("validator_status") or "").strip() != "PASS":
                    report.fail(f"would_export=true requires PASS: {domain}/{artifact_id}")
                if (approval.get("approval_status") or "").strip() != "approved":
                    report.fail(f"would_export=true requires approved status: {domain}/{artifact_id}")
                if not parse_bool(approval.get("approved_for_export", "false")):
                    report.fail(f"would_export=true requires approved_for_export=true: {domain}/{artifact_id}")
                if split_csv(approval.get("waiver_flags", "")):
                    report.fail(f"would_export=true requires empty waiver_flags: {domain}/{artifact_id}")
                if (approval.get("waiver_status") or "").strip() in {"pending", "unresolved", "rejected"}:
                    report.fail(f"would_export=true requires cleared waiver status: {domain}/{artifact_id}")
            if unknown_records:
                report.fail(f"would_export=true cannot have unknown approval records: {domain}")

        if reasons and "approval_record_unknown_to_dry_run" in reasons and not unknown_records:
            report.fail(f"approval_record_unknown_to_dry_run reason requires unknown_approval_records payload: {domain}")

    report.pass_("Overlay would_export/blocked gating rules validated.")


def validate_markdown(path: Path, report: ValidationReport) -> None:
    text = path.read_text(encoding="utf-8")
    for section in ["Runtime Export Approval Overlay", "Overlay Summary", "Overlay Candidates", "Blocked Runtime Artifacts"]:
        if section not in text:
            report.fail(f"Overlay markdown missing section: {section}")
    if "Runtime files written: 0" not in text:
        report.fail("Overlay markdown must state runtime files written: 0")
    else:
        report.pass_("Overlay markdown confirms runtime files written: 0")
    if "Runtime export implemented: yes" in text:
        report.fail("Overlay markdown must not claim runtime export implementation.")


def main() -> int:
    args = parse_args()
    report = validate(Path(args.design_dir))
    print(report.format())
    return 0 if report.ok() else 1


if __name__ == "__main__":
    raise SystemExit(main())
