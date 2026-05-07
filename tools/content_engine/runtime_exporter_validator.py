#!/usr/bin/env python3
"""Validate Content Engine v0.8b runtime exporter outputs."""

from __future__ import annotations

import argparse
import csv
import json
from dataclasses import dataclass, field
from pathlib import Path

from runtime_export_diff_report import OUTPUT_TSV as DIFF_REPORT_TSV
from runtime_exporter import (
    ALLOWED_RUNTIME_FILENAMES,
    OUTPUT_FIELDS,
    OUTPUT_MD,
    OUTPUT_TSV,
    RUNTIME_PREFIX,
    WRITE_RESULT_FIELDS,
    WRITE_RESULT_MD,
    WRITE_RESULT_TSV,
)


RUNTIME_DIR = Path("data/runtime/content_engine")


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
    parser = argparse.ArgumentParser(description="Validate runtime exporter v0.8b outputs.")
    parser.add_argument("--design-dir", default="data/design")
    parser.add_argument("--allow-runtime-files", action="store_true")
    return parser.parse_args()


def parse_bool(value: str) -> bool:
    lowered = (value or "").strip().lower()
    if lowered in {"true", "1", "yes"}:
        return True
    if lowered in {"false", "0", "no"}:
        return False
    raise ValueError(f"Invalid bool value: {value!r}")


def parse_non_negative_int(value: str, *, field_name: str, row_key: str) -> int:
    raw = (value or "").strip()
    try:
        parsed = int(raw)
    except ValueError as exc:
        raise ValueError(f"{row_key}: {field_name} must be integer, got {raw!r}") from exc
    if parsed < 0:
        raise ValueError(f"{row_key}: {field_name} must be non-negative, got {parsed}")
    return parsed


def read_tsv(path: Path, required_fields: list[str]) -> list[dict[str, str]]:
    with path.open("r", encoding="utf-8", newline="") as handle:
        reader = csv.DictReader(handle, delimiter="\t")
        fieldnames = reader.fieldnames or []
        missing = [field for field in required_fields if field not in fieldnames]
        if missing:
            raise ValueError(f"{path} is missing required columns: " + ", ".join(missing))
        return list(reader)


def is_allowed_diff_row(row: dict[str, str]) -> bool:
    try:
        would_export = parse_bool(row.get("would_export", "false"))
        record_count_ok = int((row.get("planned_record_count") or "0").strip()) >= 0
        field_count_ok = int((row.get("planned_field_count") or "0").strip()) >= 0
    except (ValueError, TypeError):
        return False
    return (
        would_export
        and (row.get("export_action") or "").strip() == "planned_create"
        and (row.get("diff_status") or "").strip() == "new_runtime_file_planned"
        and (row.get("risk_level") or "").strip() in {"low", "medium"}
        and not (row.get("blocked_reason") or "").strip()
        and bool((row.get("schema_fingerprint") or "").strip())
        and bool((row.get("content_fingerprint") or "").strip())
        and record_count_ok
        and field_count_ok
        and (row.get("planned_runtime_path") or "").strip().startswith(RUNTIME_PREFIX)
    )


def validate_plan_against_diff(
    diff_rows: list[dict[str, str]],
    plan_rows: list[dict[str, str]],
    report: ValidationReport,
) -> None:
    diff_map = {(row["runtime_domain"], row["artifact_id"]): row for row in diff_rows}
    allowed_diff_count = sum(1 for row in diff_rows if is_allowed_diff_row(row))
    allowed_plan_count = 0

    for row in plan_rows:
        domain = (row.get("runtime_domain") or "").strip()
        artifact_id = (row.get("artifact_id") or "").strip()
        row_key = f"{domain}/{artifact_id}"
        diff_row = diff_map.get((domain, artifact_id))
        if diff_row is None:
            report.fail(f"Exporter plan row not present in diff report: {row_key}")
            continue

        planned_path = (row.get("planned_runtime_path") or "").strip()
        if not planned_path.startswith(RUNTIME_PREFIX):
            report.fail(f"planned_runtime_path must be under {RUNTIME_PREFIX}: {row_key}")

        if not (row.get("schema_fingerprint") or "").strip() or not (row.get("content_fingerprint") or "").strip():
            report.fail(f"schema/content fingerprint must be non-empty: {row_key}")

        for field_name in ["planned_record_count", "planned_field_count"]:
            try:
                parse_non_negative_int(row.get(field_name, ""), field_name=field_name, row_key=row_key)
            except ValueError as exc:
                report.fail(str(exc))

        action = (row.get("export_action") or "").strip()
        blocked_reason = (row.get("blocked_reason") or "").strip()
        if action == "planned_create":
            allowed_plan_count += 1
            path_name = Path(planned_path).name
            path_parent = Path(planned_path).parent.as_posix()
            if path_parent != RUNTIME_DIR.as_posix() or path_name not in ALLOWED_RUNTIME_FILENAMES:
                report.fail(f"planned_create row must target runtime allowlist file: {row_key}")
            if blocked_reason and blocked_reason != "missing_confirm_runtime_export":
                report.fail(f"planned_create row has unexpected blocked_reason: {row_key}")
        elif not blocked_reason:
            report.fail(f"blocked row must include blocked_reason: {row_key}")

    if allowed_plan_count != allowed_diff_count:
        report.fail(
            "Allowed candidate count must match diff planned_create count: "
            f"plan={allowed_plan_count}, diff={allowed_diff_count}"
        )
    else:
        report.pass_(f"Allowed candidate count matches diff planned_create count: {allowed_diff_count}")

    if allowed_diff_count != 2:
        report.fail(f"Current expected allowed candidate count is 2, got {allowed_diff_count}")
    else:
        report.pass_("Current expected allowed candidate count is 2.")


def validate_plan_write_result_alignment(
    plan_rows: list[dict[str, str]],
    write_rows: list[dict[str, str]],
    report: ValidationReport,
) -> None:
    write_map = {(row["runtime_domain"], row["artifact_id"]): row for row in write_rows}
    if len(plan_rows) != len(write_rows):
        report.fail(f"Plan and write-result row count mismatch: plan={len(plan_rows)}, write={len(write_rows)}")

    for plan_row in plan_rows:
        key = ((plan_row.get("runtime_domain") or "").strip(), (plan_row.get("artifact_id") or "").strip())
        row_key = f"{key[0]}/{key[1]}"
        write_row = write_map.get(key)
        if write_row is None:
            report.fail(f"Missing write-result row: {row_key}")
            continue

        if (plan_row.get("planned_runtime_path") or "").strip() != (write_row.get("planned_runtime_path") or "").strip():
            report.fail(f"planned_runtime_path mismatch: {row_key}")
        if (plan_row.get("schema_fingerprint") or "").strip() != (write_row.get("schema_fingerprint") or "").strip():
            report.fail(f"schema_fingerprint mismatch: {row_key}")
        if (plan_row.get("content_fingerprint") or "").strip() != (write_row.get("content_fingerprint") or "").strip():
            report.fail(f"content_fingerprint mismatch: {row_key}")

        for bool_field in ["write_enabled", "would_write", "write_requested", "confirm_runtime_export"]:
            try:
                parse_bool(write_row.get(bool_field, ""))
            except ValueError as exc:
                report.fail(f"{row_key}: {exc}")

        if (plan_row.get("write_enabled") or "").strip() != (write_row.get("write_enabled") or "").strip():
            report.fail(f"write_enabled mismatch between plan and write-result: {row_key}")
        if (plan_row.get("would_write") or "").strip() != (write_row.get("would_write") or "").strip():
            report.fail(f"would_write mismatch between plan and write-result: {row_key}")
        if (plan_row.get("actual_write_status") or "").strip() != (write_row.get("actual_write_status") or "").strip():
            report.fail(f"actual_write_status mismatch between plan and write-result: {row_key}")
        if (plan_row.get("blocked_reason") or "").strip() != (write_row.get("blocked_reason") or "").strip():
            report.fail(f"blocked_reason mismatch between plan and write-result: {row_key}")

        status = (write_row.get("actual_write_status") or "").strip()
        if status not in {"written", "not_written", "blocked", "failed_validation"}:
            report.fail(f"Invalid actual_write_status: {row_key} -> {status}")


def validate_no_write(write_rows: list[dict[str, str]], report: ValidationReport) -> None:
    if RUNTIME_DIR.exists():
        report.fail("data/runtime/content_engine/ must not exist in no-write mode.")
    else:
        report.pass_("data/runtime/content_engine/ was not created in no-write mode.")

    for row in write_rows:
        row_key = f"{row['runtime_domain']}/{row['artifact_id']}"
        try:
            if parse_bool(row.get("write_enabled", "false")):
                report.fail(f"write_enabled must be false in no-write mode: {row_key}")
            if parse_bool(row.get("would_write", "false")):
                report.fail(f"would_write must be false in no-write mode: {row_key}")
        except ValueError as exc:
            report.fail(f"{row_key}: {exc}")
            continue

        if (row.get("actual_write_status") or "").strip() != "not_written":
            report.fail(f"actual_write_status must be not_written in no-write mode: {row_key}")
        if (row.get("bytes_written") or "").strip() not in {"", "0"}:
            report.fail(f"bytes_written must be empty in no-write mode: {row_key}")


def validate_guarded_write(write_rows: list[dict[str, str]], report: ValidationReport) -> None:
    if not RUNTIME_DIR.exists():
        report.fail("data/runtime/content_engine/ must exist for guarded-write validation.")
        return

    entries = list(RUNTIME_DIR.iterdir())
    entry_names = {entry.name for entry in entries}
    if any(not entry.is_file() for entry in entries):
        report.fail("runtime directory must contain files only.")
    extra_entries = entry_names - ALLOWED_RUNTIME_FILENAMES
    if extra_entries:
        report.fail("runtime directory contains non-allowlisted files: " + ", ".join(sorted(extra_entries)))
    if entry_names != ALLOWED_RUNTIME_FILENAMES:
        report.fail(
            "runtime directory must contain exactly allowlisted files: "
            f"expected={sorted(ALLOWED_RUNTIME_FILENAMES)}, actual={sorted(entry_names)}"
        )

    written_rows = [row for row in write_rows if (row.get("actual_write_status") or "").strip() == "written"]
    blocked_rows = [row for row in write_rows if (row.get("actual_write_status") or "").strip() == "blocked"]
    failed_rows = [row for row in write_rows if (row.get("actual_write_status") or "").strip() == "failed_validation"]
    if len(written_rows) != 2:
        report.fail(f"guarded-write must produce exactly 2 written rows, got {len(written_rows)}")
    if failed_rows:
        report.fail(f"failed_validation rows must be 0, got {len(failed_rows)}")

    for row in blocked_rows:
        row_key = f"{row['runtime_domain']}/{row['artifact_id']}"
        if (row.get("bytes_written") or "").strip() not in {"", "0"}:
            report.fail(f"blocked row must not include bytes_written: {row_key}")

    write_map = {(row["runtime_domain"], row["artifact_id"]): row for row in write_rows}
    written_paths: set[str] = set()
    for row in written_rows:
        row_key = f"{row['runtime_domain']}/{row['artifact_id']}"
        planned_path = (row.get("planned_runtime_path") or "").strip()
        path_obj = Path(planned_path)
        if path_obj.parent.as_posix() != RUNTIME_DIR.as_posix() or path_obj.name not in ALLOWED_RUNTIME_FILENAMES:
            report.fail(f"written row planned path is not allowlisted: {row_key}")
            continue
        bytes_raw = (row.get("bytes_written") or "").strip()
        try:
            bytes_value = int(bytes_raw)
        except ValueError:
            report.fail(f"written row bytes_written must be integer: {row_key}")
            continue
        if bytes_value <= 0:
            report.fail(f"written row bytes_written must be >0: {row_key}")
            continue

        runtime_file = RUNTIME_DIR / path_obj.name
        if not runtime_file.exists():
            report.fail(f"written runtime file missing on disk: {runtime_file}")
            continue

        try:
            payload = json.loads(runtime_file.read_text(encoding="utf-8"))
        except json.JSONDecodeError as exc:
            report.fail(f"runtime file is not valid JSON: {runtime_file} ({exc})")
            continue

        if payload.get("runtime_domain") != row.get("runtime_domain"):
            report.fail(f"runtime_domain mismatch in {runtime_file}: expected {row.get('runtime_domain')}")
        if payload.get("artifact_id") != row.get("artifact_id"):
            report.fail(f"artifact_id mismatch in {runtime_file}: expected {row.get('artifact_id')}")
        if payload.get("schema_fingerprint") != row.get("schema_fingerprint"):
            report.fail(f"schema_fingerprint mismatch in {runtime_file}")
        if payload.get("content_fingerprint") != row.get("content_fingerprint"):
            report.fail(f"content_fingerprint mismatch in {runtime_file}")

        written_paths.add(path_obj.name)

    if written_paths != ALLOWED_RUNTIME_FILENAMES:
        report.fail(
            "written runtime file set mismatch: "
            f"expected={sorted(ALLOWED_RUNTIME_FILENAMES)}, actual={sorted(written_paths)}"
        )

    required_keys = {
        ("card_pool", "generated_card_pool"),
        ("battle_reward", "generated_battle_reward_plan"),
    }
    if not required_keys.issubset(set(write_map.keys())):
        report.fail("write-result missing required card_pool/battle_reward rows")


def validate_markdown(plan_md: Path, write_md: Path, report: ValidationReport) -> None:
    plan_text = plan_md.read_text(encoding="utf-8")
    for section in ["Runtime Exporter Plan", "Exporter Plan Summary", "Safety Notes"]:
        if section not in plan_text:
            report.fail(f"Exporter plan markdown missing section: {section}")

    write_text = write_md.read_text(encoding="utf-8")
    for section in ["Runtime Exporter Write Result", "Write Result Summary", "Notes"]:
        if section not in write_text:
            report.fail(f"Write result markdown missing section: {section}")


def validate(design_dir: Path, *, allow_runtime_files: bool) -> ValidationReport:
    report = ValidationReport()

    diff_path = design_dir / DIFF_REPORT_TSV
    plan_tsv = design_dir / OUTPUT_TSV
    plan_md = design_dir / OUTPUT_MD
    write_tsv = design_dir / WRITE_RESULT_TSV
    write_md = design_dir / WRITE_RESULT_MD

    for path in [diff_path, plan_tsv, plan_md, write_tsv, write_md]:
        if not path.exists():
            report.fail(f"Missing required file: {path}")
            return report
        report.pass_(f"Found {path}")

    try:
        diff_rows = read_tsv(
            diff_path,
            [
                "runtime_domain",
                "artifact_id",
                "would_export",
                "planned_runtime_path",
                "export_action",
                "risk_level",
                "diff_status",
                "planned_record_count",
                "planned_field_count",
                "schema_fingerprint",
                "content_fingerprint",
                "blocked_reason",
            ],
        )
        plan_rows = read_tsv(plan_tsv, OUTPUT_FIELDS)
        write_rows = read_tsv(write_tsv, WRITE_RESULT_FIELDS)
    except ValueError as exc:
        report.fail(str(exc))
        return report

    validate_plan_against_diff(diff_rows, plan_rows, report)
    validate_plan_write_result_alignment(plan_rows, write_rows, report)
    validate_markdown(plan_md, write_md, report)

    if allow_runtime_files:
        validate_guarded_write(write_rows, report)
    else:
        validate_no_write(write_rows, report)

    return report


def main() -> int:
    args = parse_args()
    report = validate(Path(args.design_dir), allow_runtime_files=args.allow_runtime_files)
    print(report.format())
    return 0 if report.ok() else 1


if __name__ == "__main__":
    raise SystemExit(main())
