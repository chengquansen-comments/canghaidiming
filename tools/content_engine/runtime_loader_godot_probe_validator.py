#!/usr/bin/env python3
"""Validate v0.8f Godot loader probe report and isolation constraints."""

from __future__ import annotations

import argparse
import csv
import subprocess
import sys
from dataclasses import dataclass, field
from pathlib import Path

from runtime_loader_godot_probe import OUTPUT_FIELDS, OUTPUT_MD, OUTPUT_TSV


ALLOWED_RUNTIME_FILES = {"card_pool.json", "battle_reward.json", "runtime_manifest.json", "runtime_loader_config.json"}
FORBIDDEN_HIGH_RISK = {
    "scripts/card_data.gd",
    "scripts/battle_state_machine.gd",
    "scripts/combat_resolver.gd",
}


@dataclass
class ValidationReport:
    passes: list[str] = field(default_factory=list)
    warnings: list[str] = field(default_factory=list)
    failures: list[str] = field(default_factory=list)

    def pass_(self, message: str) -> None:
        self.passes.append(message)

    def fail(self, message: str) -> None:
        self.failures.append(message)

    def ok(self) -> bool:
        return not self.failures

    def format(self) -> str:
        lines: list[str] = []
        lines.extend([f"PASS: {item}" for item in self.passes])
        lines.extend([f"FAIL: {item}" for item in self.failures])
        lines.append("RESULT: PASS" if self.ok() else "RESULT: FAIL")
        return "\n".join(lines)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Validate runtime loader Godot probe outputs.")
    parser.add_argument("--report", default=f"data/design/{OUTPUT_TSV}")
    parser.add_argument("--report-md", default=f"data/design/{OUTPUT_MD}")
    parser.add_argument("--runtime-dir", default="data/runtime/content_engine")
    return parser.parse_args()


def read_tsv(path: Path, required_fields: list[str]) -> list[dict[str, str]]:
    with path.open("r", encoding="utf-8", newline="") as handle:
        reader = csv.DictReader(handle, delimiter="\t")
        fieldnames = reader.fieldnames or []
        missing = [field for field in required_fields if field not in fieldnames]
        if missing:
            raise ValueError(f"{path} is missing required columns: " + ", ".join(missing))
        return list(reader)


def check_report_row(row: dict[str, str], report: ValidationReport) -> None:
    expected_true = [
        "probe_ok",
        "manifest_loaded",
        "manifest_valid",
        "runtime_bundle_loaded",
        "manifest_first",
        "direct_runtime_read_disallowed",
        "fail_closed",
    ]
    for field_name in expected_true:
        if (row.get(field_name) or "").strip() != "true":
            report.fail(f"{field_name} must be true")

    if (row.get("write_api_present") or "").strip() != "false":
        report.fail("write_api_present must be false")
    if (row.get("integration_status") or "").strip() != "not_integrated":
        report.fail("integration_status must be not_integrated")
    if (row.get("godot_exit_code") or "").strip() != "0":
        report.fail("godot_exit_code must be 0")
    if (row.get("loaded_domain_count") or "").strip() != "2":
        report.fail("loaded_domain_count must be 2")

    domains = sorted([item.strip() for item in (row.get("loaded_domains") or "").split(",") if item.strip()])
    if domains != ["battle_reward", "card_pool"]:
        report.fail(f"loaded_domains must be battle_reward,card_pool; got {domains}")
    if (row.get("error_count") or "").strip() != "0":
        report.fail("error_count must be 0")


def check_runtime_dir(runtime_dir: Path, report: ValidationReport) -> None:
    if not runtime_dir.exists() or not runtime_dir.is_dir():
        report.fail(f"runtime dir missing: {runtime_dir}")
        return
    names = {entry.name for entry in runtime_dir.iterdir() if entry.is_file()}
    if names != ALLOWED_RUNTIME_FILES:
        report.fail(f"runtime dir file set mismatch: expected={sorted(ALLOWED_RUNTIME_FILES)} actual={sorted(names)}")
    else:
        report.pass_("runtime dir keeps expected allowlisted file set")


def check_references(report: ValidationReport) -> None:
    scripts_dir = Path("scripts")
    loader_refs = 0
    probe_refs = 0
    for gd in scripts_dir.glob("*.gd"):
        if gd.name in {"content_engine_runtime_loader.gd"}:
            continue
        text = gd.read_text(encoding="utf-8")
        if "content_engine_runtime_loader.gd" in text or "ContentEngineRuntimeLoader" in text:
            loader_refs += 1
        if "content_engine_loader_probe.gd" in text:
            probe_refs += 1
    if loader_refs != 0:
        report.fail(f"existing .gd files reference loader: {loader_refs}")
    if probe_refs != 0:
        report.fail(f"existing .gd files reference probe: {probe_refs}")
    if loader_refs == 0 and probe_refs == 0:
        report.pass_("no existing .gd references to loader/probe")


def check_git_scope(report: ValidationReport) -> None:
    out = subprocess.check_output(["git", "status", "--porcelain"], text=True)
    changed = [line[3:] for line in out.splitlines() if len(line) > 3]
    for path in changed:
        if path in FORBIDDEN_HIGH_RISK:
            report.fail(f"high-risk file modified: {path}")
        if path.startswith("scenes/") and path.endswith(".tscn"):
            report.fail(f"scene modified: {path}")
        if path.startswith("data/story_battles/") and path.endswith(".tsv"):
            report.fail(f"story battle TSV modified: {path}")


def check_markdown(path: Path, report: ValidationReport) -> None:
    if not path.exists():
        report.fail(f"missing probe markdown: {path}")
        return
    text = path.read_text(encoding="utf-8")
    for token in ["Runtime Loader Godot Probe Report", "Probe Row"]:
        if token not in text:
            report.fail(f"probe markdown missing token: {token}")


def run_subvalidator(script_path: str) -> tuple[int, str]:
    proc = subprocess.run([sys.executable, script_path], capture_output=True, text=True)
    return proc.returncode, proc.stdout + proc.stderr


def main() -> int:
    args = parse_args()
    report = ValidationReport()

    try:
        rows = read_tsv(Path(args.report), OUTPUT_FIELDS)
    except ValueError as exc:
        report.fail(str(exc))
        print(report.format())
        return 1

    if len(rows) != 1:
        report.fail(f"probe report must contain exactly 1 row, got {len(rows)}")
    else:
        check_report_row(rows[0], report)

    check_runtime_dir(Path(args.runtime_dir), report)
    check_references(report)
    check_git_scope(report)
    check_markdown(Path(args.report_md), report)

    manifest_rc, _ = run_subvalidator("tools/content_engine/runtime_export_manifest_validator.py")
    if manifest_rc != 0:
        report.fail("runtime_export_manifest_validator failed")
    else:
        report.pass_("runtime_export_manifest_validator passed")

    scaffold_rc, _ = run_subvalidator("tools/content_engine/runtime_loader_scaffold_validator.py")
    if scaffold_rc != 0:
        report.fail("runtime_loader_scaffold_validator failed")
    else:
        report.pass_("runtime_loader_scaffold_validator passed")

    print(report.format())
    return 0 if report.ok() else 1


if __name__ == "__main__":
    raise SystemExit(main())
