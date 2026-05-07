#!/usr/bin/env python3
"""Validate Content Engine v0.7d runtime export diff report outputs."""

from __future__ import annotations

import argparse
import csv
from dataclasses import dataclass, field
from pathlib import Path

from runtime_export_approval_overlay import OUTPUT_TSV as OVERLAY_TSV
from runtime_export_diff_report import (
    ALLOWED_ACTIONS,
    ALLOWED_DIFF_STATUS,
    ALLOWED_RISK_LEVEL,
    OUTPUT_FIELDS,
    OUTPUT_MD,
    OUTPUT_TSV,
    RUNTIME_PREFIX,
)


RESTRICTED_PREFIXES = ("scripts/", "scenes/", "data/story_battles/")


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
    parser = argparse.ArgumentParser(description="Validate runtime export diff report outputs.")
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
    overlay_path = design_dir / OVERLAY_TSV
    report_tsv = design_dir / OUTPUT_TSV
    report_md = design_dir / OUTPUT_MD

    for path in [overlay_path, report_tsv, report_md]:
        if not path.exists():
            report.fail(f"Missing required file: {path}")
            return report
        report.pass_(f"Found {path}")

    try:
        overlay_rows = read_tsv(overlay_path, ["runtime_domain", "source_artifacts", "would_export", "blocked"])
        diff_rows = read_tsv(report_tsv, OUTPUT_FIELDS)
    except ValueError as exc:
        report.fail(str(exc))
        return report

    validate_rows(overlay_rows, diff_rows, report)
    validate_runtime_absence(report)
    validate_markdown(report_md, report)
    return report


def validate_rows(overlay_rows: list[dict[str, str]], diff_rows: list[dict[str, str]], report: ValidationReport) -> None:
    overlay_map = {(r["runtime_domain"], r["source_artifacts"]): r for r in overlay_rows}
    for row in diff_rows:
        domain = (row.get("runtime_domain") or "").strip()
        artifact_id = (row.get("artifact_id") or "").strip()
        key = (domain, artifact_id)
        overlay = overlay_map.get(key)
        if overlay is None:
            report.fail(f"Diff row is unknown to overlay: {domain}/{artifact_id}")
            continue

        try:
            would_export = parse_bool(row.get("would_export", "false"))
        except ValueError as exc:
            report.fail(f"{domain}: {exc}")
            continue

        overlay_would_export = parse_bool(overlay.get("would_export", "false"))
        overlay_blocked = parse_bool(overlay.get("blocked", "true"))
        if would_export != overlay_would_export:
            report.fail(f"would_export mismatch with overlay: {domain}")

        planned_path = (row.get("planned_runtime_path") or "").strip()
        if not planned_path.startswith(RUNTIME_PREFIX):
            report.fail(f"planned_runtime_path must be under {RUNTIME_PREFIX}: {domain}")
        for restricted in RESTRICTED_PREFIXES:
            if planned_path.startswith(restricted):
                report.fail(f"planned_runtime_path points to restricted prefix {restricted}: {domain}")

        action = (row.get("export_action") or "").strip()
        if action not in ALLOWED_ACTIONS:
            report.fail(f"Invalid export_action for {domain}: {action!r}")
        diff_status = (row.get("diff_status") or "").strip()
        if diff_status not in ALLOWED_DIFF_STATUS:
            report.fail(f"Invalid diff_status for {domain}: {diff_status!r}")
        risk = (row.get("risk_level") or "").strip()
        if risk not in ALLOWED_RISK_LEVEL:
            report.fail(f"Invalid risk_level for {domain}: {risk!r}")

        schema_fp = (row.get("schema_fingerprint") or "").strip()
        content_fp = (row.get("content_fingerprint") or "").strip()
        if not schema_fp or not content_fp:
            report.fail(f"schema_fingerprint/content_fingerprint must be non-empty: {domain}")

        for field_name in ["planned_record_count", "planned_field_count"]:
            try:
                value = int((row.get(field_name) or "").strip())
            except ValueError:
                report.fail(f"{field_name} must be integer: {domain}")
                continue
            if value < 0:
                report.fail(f"{field_name} must be non-negative: {domain}")

        blocked_reason = (row.get("blocked_reason") or "").strip()
        if overlay_blocked:
            if not blocked_reason:
                report.fail(f"blocked overlay row must have blocked_reason: {domain}")
            if action != "blocked":
                report.fail(f"blocked overlay row must use export_action=blocked: {domain}")
            if diff_status not in {"blocked", "unsafe_path"}:
                report.fail(f"blocked overlay row must use blocked/unsafe_path diff_status: {domain}")
        else:
            if blocked_reason:
                report.fail(f"unblocked overlay row must have empty blocked_reason: {domain}")
            if action not in {"planned_create", "planned_update", "planned_skip"}:
                report.fail(f"unblocked overlay row must use planned action: {domain}")

    report.pass_("Diff report row invariants validated.")


def validate_runtime_absence(report: ValidationReport) -> None:
    runtime_dir = Path("data/runtime/content_engine")
    if runtime_dir.exists():
        report.fail("data/runtime/content_engine/ must not exist in v0.7d.")
    else:
        report.pass_("data/runtime/content_engine/ was not created.")


def validate_markdown(path: Path, report: ValidationReport) -> None:
    text = path.read_text(encoding="utf-8")
    for section in ["Runtime Export Diff Report", "Diff Summary", "Planned Candidates", "Safety Notes"]:
        if section not in text:
            report.fail(f"Diff markdown missing section: {section}")
    if "Runtime files written: 0" not in text:
        report.fail("Diff markdown must state runtime files written: 0")
    else:
        report.pass_("Diff markdown confirms runtime files written: 0")
    if "Runtime export implemented: yes" in text:
        report.fail("Diff markdown must not claim runtime export implementation.")


def main() -> int:
    args = parse_args()
    report = validate(Path(args.design_dir))
    print(report.format())
    return 0 if report.ok() else 1


if __name__ == "__main__":
    raise SystemExit(main())
