#!/usr/bin/env python3
"""Validate runtime loader preflight report for Content Engine v0.8d."""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
import subprocess
from dataclasses import dataclass, field
from pathlib import Path

from runtime_export_manifest import MANIFEST_JSON, MANIFEST_REPORT_TSV
from runtime_export_manifest_validator import validate_manifest as validate_manifest_core
from runtime_export_manifest_validator import validate_runtime_directory as validate_runtime_dir_core
from runtime_export_manifest_validator import validate_write_result as validate_write_result_core
from runtime_exporter import ALLOWED_RUNTIME_FILENAMES, RUNTIME_DIR, WRITE_RESULT_FIELDS, WRITE_RESULT_TSV
from runtime_loader_preflight import OUTPUT_FIELDS, OUTPUT_MD, OUTPUT_TSV


RESTRICTED_PREFIXES = ("scripts/", "scenes/", "data/story_battles/")
ALLOWED_SCOPES = {"read_only_manifest_check", "read_only_runtime_file_check", "runtime_data_probe", "blocked"}
ALLOWED_READ_MODES = {"manifest_first", "direct_runtime_file_disallowed", "blocked"}
ALLOWED_FAILURE = {"fail_closed", "fallback_to_existing_design_data", "fallback_to_static_runtime_data", "blocked"}


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
    parser = argparse.ArgumentParser(description="Validate runtime loader preflight report.")
    parser.add_argument("--runtime-dir", default=str(RUNTIME_DIR))
    parser.add_argument("--manifest", default=f"data/runtime/content_engine/{MANIFEST_JSON}")
    parser.add_argument("--manifest-report", default=f"data/design/{MANIFEST_REPORT_TSV}")
    parser.add_argument("--write-result", default=f"data/design/{WRITE_RESULT_TSV}")
    parser.add_argument("--preflight-report", default=f"data/design/{OUTPUT_TSV}")
    parser.add_argument("--preflight-report-md", default=f"data/design/{OUTPUT_MD}")
    return parser.parse_args()


def read_tsv(path: Path, required_fields: list[str]) -> list[dict[str, str]]:
    with path.open("r", encoding="utf-8", newline="") as handle:
        reader = csv.DictReader(handle, delimiter="\t")
        fieldnames = reader.fieldnames or []
        missing = [field for field in required_fields if field not in fieldnames]
        if missing:
            raise ValueError(f"{path} is missing required columns: " + ", ".join(missing))
        return list(reader)


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(65536), b""):
            digest.update(chunk)
    return digest.hexdigest()


def check_forbidden_git_changes(report: ValidationReport) -> None:
    out = subprocess.check_output(["git", "status", "--porcelain"], text=True)
    changed_paths = [line[3:] for line in out.splitlines() if len(line) > 3]

    for path in changed_paths:
        if path in {
            "scripts/card_data.gd",
            "scripts/battle_state_machine.gd",
            "scripts/combat_resolver.gd",
        }:
            report.fail(f"high-risk .gd file modified/added: {path}")
        if path.endswith(".tscn") and path.startswith("scenes/"):
            report.fail(f"scene file modified/added in v0.8d scope: {path}")
        if path.startswith("data/story_battles/") and path.endswith(".tsv"):
            report.fail(f"story battle TSV modified/added in v0.8d scope: {path}")
        lower = path.lower()
        if path.startswith("scripts/") and "loader" in lower and path.endswith(".gd") and path != "scripts/content_engine_runtime_loader.gd":
            report.fail(f"unexpected loader script .gd change: {path}")


def validate_preflight_rows(
    preflight_rows: list[dict[str, str]],
    manifest_files: list[dict[str, object]],
    runtime_dir: Path,
    report: ValidationReport,
) -> None:
    if len(preflight_rows) != len(manifest_files):
        report.fail(f"preflight row count must match manifest files: preflight={len(preflight_rows)} manifest={len(manifest_files)}")

    manifest_keys = {
        (str(item.get("runtime_domain") or ""), str(item.get("artifact_id") or ""))
        for item in manifest_files
        if isinstance(item, dict)
    }
    preflight_keys = {
        ((row.get("runtime_domain") or "").strip(), (row.get("artifact_id") or "").strip())
        for row in preflight_rows
    }
    if preflight_keys != manifest_keys:
        report.fail("preflight rows must match manifest registered runtime file keys")

    for row in preflight_rows:
        runtime_domain = (row.get("runtime_domain") or "").strip()
        artifact_id = (row.get("artifact_id") or "").strip()
        row_key = f"{runtime_domain}/{artifact_id}"

        if (row.get("proposed_loader_scope") or "").strip() not in ALLOWED_SCOPES:
            report.fail(f"invalid proposed_loader_scope: {row_key}")
        if (row.get("proposed_read_mode") or "").strip() not in ALLOWED_READ_MODES:
            report.fail(f"invalid proposed_read_mode: {row_key}")
        if (row.get("proposed_failure_mode") or "").strip() not in ALLOWED_FAILURE:
            report.fail(f"invalid proposed_failure_mode: {row_key}")

        runtime_path = (row.get("runtime_path") or "").strip()
        path_obj = Path(runtime_path)
        if path_obj.is_absolute() or path_obj.parent.as_posix() != runtime_dir.as_posix():
            report.fail(f"runtime_path must stay under {runtime_dir}: {row_key}")
        if any(runtime_path.startswith(prefix) for prefix in RESTRICTED_PREFIXES):
            report.fail(f"runtime_path points restricted prefix: {row_key}")
        if path_obj.name not in ALLOWED_RUNTIME_FILENAMES:
            report.fail(f"runtime_path file not allowlisted: {row_key}")

        touchpoints = (row.get("proposed_godot_touchpoints") or "").strip()
        if not touchpoints.startswith("future_touchpoint_only:"):
            report.fail(f"proposed_godot_touchpoints must be future_touchpoint_only: {row_key}")

        fallback = (row.get("proposed_fallback_source") or "").strip()
        if not fallback:
            report.fail(f"proposed_fallback_source must be defined: {row_key}")

        loader_ready = (row.get("loader_ready") or "").strip()
        blocked_reason = (row.get("blocked_reason") or "").strip()
        if loader_ready == "true" and blocked_reason:
            report.fail(f"loader_ready=true row must have empty blocked_reason: {row_key}")
        if loader_ready == "false" and not blocked_reason:
            report.fail(f"loader_ready=false row must have blocked_reason: {row_key}")

        runtime_file = Path(runtime_path)
        json_ok = False
        sha_ok = False
        schema_ok = False
        content_ok = False
        if runtime_file.exists():
            try:
                payload = json.loads(runtime_file.read_text(encoding="utf-8"))
                json_ok = isinstance(payload, dict)
            except json.JSONDecodeError:
                json_ok = False
            if json_ok:
                manifest_item = next(
                    (
                        item
                        for item in manifest_files
                        if isinstance(item, dict)
                        and str(item.get("runtime_domain") or "") == runtime_domain
                        and str(item.get("artifact_id") or "") == artifact_id
                    ),
                    None,
                )
                if manifest_item is not None:
                    sha_ok = sha256_file(runtime_file) == str(manifest_item.get("sha256") or "")
                    schema_ok = str(payload.get("schema_fingerprint") or "") == str(manifest_item.get("schema_fingerprint") or "")
                    content_ok = str(payload.get("content_fingerprint") or "") == str(manifest_item.get("content_fingerprint") or "")

        if loader_ready == "true":
            all_ready = (
                (row.get("manifest_status") or "").strip() == "registered"
                and (row.get("json_parse_status") or "").strip() == "ok"
                and (row.get("checksum_status") or "").strip() == "matched"
                and (row.get("schema_fingerprint_status") or "").strip() == "matched"
                and (row.get("content_fingerprint_status") or "").strip() == "matched"
                and (row.get("proposed_read_mode") or "").strip() == "manifest_first"
                and (row.get("proposed_failure_mode") or "").strip() in {"fail_closed", "fallback_to_existing_design_data", "fallback_to_static_runtime_data"}
                and fallback != ""
                and json_ok
                and sha_ok
                and schema_ok
                and content_ok
            )
            if not all_ready:
                report.fail(f"loader_ready=true row does not satisfy strict readiness checks: {row_key}")


def validate_markdown(path: Path, report: ValidationReport) -> None:
    if not path.exists():
        report.fail(f"missing preflight markdown report: {path}")
        return
    text = path.read_text(encoding="utf-8")
    for token in ["Runtime Loader Preflight Report", "Preflight Rows", "Scope Boundary"]:
        if token not in text:
            report.fail(f"preflight markdown missing section: {token}")


def main() -> int:
    args = parse_args()
    report = ValidationReport()

    runtime_dir = Path(args.runtime_dir)
    manifest_path = Path(args.manifest)
    manifest_report_path = Path(args.manifest_report)
    write_result_path = Path(args.write_result)
    preflight_report_path = Path(args.preflight_report)
    preflight_report_md = Path(args.preflight_report_md)

    try:
        validate_write_result_core(write_result_path, report)
        validate_runtime_dir_core(runtime_dir, report)

        if not manifest_path.exists():
            report.fail(f"missing runtime manifest: {manifest_path}")
            print(report.format())
            return 1
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
        files = manifest.get("files") if isinstance(manifest, dict) else None
        if not isinstance(files, list):
            report.fail("runtime manifest files must be list")
            print(report.format())
            return 1

        manifest_report_rows = read_tsv(manifest_report_path, [
            "runtime_domain",
            "artifact_id",
            "runtime_path",
            "manifest_status",
            "sha256",
            "schema_fingerprint",
            "content_fingerprint",
            "record_count",
            "field_count",
        ])
        validate_manifest_core(manifest_path, runtime_dir, read_tsv(write_result_path, WRITE_RESULT_FIELDS), manifest_report_rows, report)

        preflight_rows = read_tsv(preflight_report_path, OUTPUT_FIELDS)
        validate_preflight_rows(preflight_rows, files, runtime_dir, report)
        validate_markdown(preflight_report_md, report)
        check_forbidden_git_changes(report)
    except ValueError as exc:
        report.fail(str(exc))

    print(report.format())
    return 0 if report.ok() else 1


if __name__ == "__main__":
    raise SystemExit(main())
