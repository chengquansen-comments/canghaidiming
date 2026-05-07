#!/usr/bin/env python3
"""Validate v0.8e runtime loader scaffold outputs and constraints."""

from __future__ import annotations

import argparse
import csv
import subprocess
import sys
from dataclasses import dataclass, field
from pathlib import Path

from runtime_loader_scaffold_probe import OUTPUT_FIELDS, OUTPUT_MD, OUTPUT_TSV


SCAFFOLD_FILE = Path("scripts/content_engine_runtime_loader.gd")
FORBIDDEN_WRITE_TOKENS = ["FileAccess.WRITE", "store_string", "store_var", "DirAccess.make_dir_recursive"]
FORBIDDEN_CALL_TOKENS = ["combat_resolver", "battle_state_machine", "card_data", "MainVisual", "main_visual"]
ALLOWED_RUNTIME_FILES = {"card_pool.json", "battle_reward.json", "runtime_manifest.json"}


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
    parser = argparse.ArgumentParser(description="Validate runtime loader scaffold report.")
    parser.add_argument("--report", default=f"data/design/{OUTPUT_TSV}")
    parser.add_argument("--report-md", default=f"data/design/{OUTPUT_MD}")
    parser.add_argument("--runtime-dir", default="data/runtime/content_engine")
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


def check_git_scope(report: ValidationReport) -> None:
    out = subprocess.check_output(["git", "status", "--porcelain"], text=True)
    changed = [line[3:] for line in out.splitlines() if len(line) > 3]

    for path in changed:
        if path in {
            "scripts/card_data.gd",
            "scripts/battle_state_machine.gd",
            "scripts/combat_resolver.gd",
        }:
            report.fail(f"high-risk .gd file modified: {path}")
        if path.startswith("scenes/") and path.endswith(".tscn"):
            report.fail(f"scene modified: {path}")
        if path.startswith("data/story_battles/") and path.endswith(".tsv"):
            report.fail(f"story battle TSV modified: {path}")
        if path.startswith("scripts/") and "loader" in path.lower() and path.endswith(".gd") and path != str(SCAFFOLD_FILE):
            report.fail(f"unexpected loader script detected: {path}")


def check_no_references(report: ValidationReport) -> None:
    scripts_dir = Path("scripts")
    refs = 0
    for gd in scripts_dir.glob("*.gd"):
        if gd == SCAFFOLD_FILE:
            continue
        text = gd.read_text(encoding="utf-8")
        if "content_engine_runtime_loader.gd" in text or "ContentEngineRuntimeLoader" in text:
            refs += 1
    if refs != 0:
        report.fail(f"existing .gd references to scaffold found: {refs}")
    else:
        report.pass_("no existing .gd files reference the scaffold loader")


def check_scaffold_content(report: ValidationReport) -> None:
    if not SCAFFOLD_FILE.exists():
        report.fail(f"missing scaffold file: {SCAFFOLD_FILE}")
        return
    text = SCAFFOLD_FILE.read_text(encoding="utf-8")

    for token in ["func load_manifest()", "func load_runtime_bundle()", "func validate_manifest(", "func validate_runtime_file("]:
        if token not in text:
            report.fail(f"missing required loader API: {token}")

    if "runtime_manifest.json" not in text:
        report.fail("scaffold missing manifest-first entry")

    for token in FORBIDDEN_WRITE_TOKENS:
        if token in text:
            report.fail(f"forbidden write API token in scaffold: {token}")

    lower = text.lower()
    for token in FORBIDDEN_CALL_TOKENS:
        if token.lower() in lower:
            report.fail(f"forbidden main combat/flow touch token in scaffold: {token}")


def check_runtime_dir(runtime_dir: Path, report: ValidationReport) -> None:
    if not runtime_dir.exists() or not runtime_dir.is_dir():
        report.fail(f"runtime dir missing: {runtime_dir}")
        return
    names = {entry.name for entry in runtime_dir.iterdir() if entry.is_file()}
    if names != ALLOWED_RUNTIME_FILES:
        report.fail(f"runtime dir files mismatch: expected={sorted(ALLOWED_RUNTIME_FILES)} actual={sorted(names)}")
    else:
        report.pass_("runtime dir contains exactly 3 expected files")


def check_scaffold_report(report_rows: list[dict[str, str]], report: ValidationReport) -> None:
    if len(report_rows) != 1:
        report.fail(f"scaffold report must contain exactly 1 row, got {len(report_rows)}")
        return
    row = report_rows[0]

    expected_true = ["manifest_first", "direct_runtime_read_disallowed", "fail_closed", "runtime_dir_allowed_only"]
    for field_name in expected_true:
        if (row.get(field_name) or "").strip() != "true":
            report.fail(f"{field_name} must be true")

    if (row.get("write_api_present") or "").strip() != "false":
        report.fail("write_api_present must be false")
    if (row.get("integration_status") or "").strip() != "not_integrated":
        report.fail("integration_status must be not_integrated")

    ref_count = (row.get("existing_gd_reference_count") or "").strip()
    if ref_count != "0":
        report.fail(f"existing_gd_reference_count must be 0, got {ref_count}")


def check_markdown(path: Path, report: ValidationReport) -> None:
    if not path.exists():
        report.fail(f"missing scaffold markdown: {path}")
        return
    text = path.read_text(encoding="utf-8")
    for token in ["Runtime Loader Scaffold Report", "Probe Result", "integration_status"]:
        if token not in text:
            report.fail(f"scaffold markdown missing token: {token}")


def main() -> int:
    args = parse_args()
    report = ValidationReport()

    report_path = Path(args.report)
    report_md_path = Path(args.report_md)
    runtime_dir = Path(args.runtime_dir)

    try:
        report_rows = read_tsv(report_path, OUTPUT_FIELDS)
    except ValueError as exc:
        report.fail(str(exc))
        print(report.format())
        return 1

    check_scaffold_report(report_rows, report)
    check_scaffold_content(report)
    check_no_references(report)
    check_runtime_dir(runtime_dir, report)
    check_git_scope(report)
    check_markdown(report_md_path, report)

    manifest_validator_cmd = [sys.executable, "tools/content_engine/runtime_export_manifest_validator.py"]
    manifest_validator = subprocess.run(manifest_validator_cmd, capture_output=True, text=True)
    if manifest_validator.returncode != 0:
        report.fail("runtime_export_manifest_validator check failed")
    else:
        report.pass_("runtime_export_manifest_validator check passed")

    print(report.format())
    return 0 if report.ok() else 1


if __name__ == "__main__":
    raise SystemExit(main())
