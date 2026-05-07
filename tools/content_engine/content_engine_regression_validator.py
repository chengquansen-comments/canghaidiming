#!/usr/bin/env python3
"""Validate v0.8h regression runner outputs."""

from __future__ import annotations

import argparse
import csv
import subprocess
import sys
from dataclasses import dataclass, field
from pathlib import Path


REPORT_TSV = Path("data/design/generated_content_engine_regression_report.tsv")
REPORT_MD = Path("data/design/generated_content_engine_regression_report.md")
RUNTIME_ROOT = Path("data/runtime/content_engine")
ALLOWED_RUNTIME_FILES = {"card_pool.json", "battle_reward.json", "runtime_manifest.json"}
REQUIRED_FIELDS = [
    "step_id",
    "phase",
    "step_name",
    "command",
    "exit_code",
    "status",
    "duration_ms",
    "stdout_tail",
    "stderr_tail",
    "required",
    "blocked_reason",
    "notes",
]
FORBIDDEN_HIGH_RISK = {
    "scripts/card_data.gd",
    "scripts/battle_state_machine.gd",
    "scripts/combat_resolver.gd",
}


@dataclass
class ValidationReport:
    passes: list[str] = field(default_factory=list)
    failures: list[str] = field(default_factory=list)

    def pass_(self, msg: str) -> None:
        self.passes.append(msg)

    def fail(self, msg: str) -> None:
        self.failures.append(msg)

    def ok(self) -> bool:
        return not self.failures

    def format(self) -> str:
        lines: list[str] = []
        lines.extend([f"PASS: {x}" for x in self.passes])
        lines.extend([f"FAIL: {x}" for x in self.failures])
        lines.append("RESULT: PASS" if self.ok() else "RESULT: FAIL")
        return "\n".join(lines)


def read_tsv(path: Path, required_fields: list[str]) -> list[dict[str, str]]:
    with path.open("r", encoding="utf-8", newline="") as f:
        r = csv.DictReader(f, delimiter="\t")
        fields = r.fieldnames or []
        missing = [x for x in required_fields if x not in fields]
        if missing:
            raise ValueError(f"{path} missing columns: {', '.join(missing)}")
        return list(r)


def run_subvalidator(script: str) -> int:
    return subprocess.run([sys.executable, script], capture_output=True, text=True).returncode


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


def check_no_refs(report: ValidationReport) -> None:
    scripts_dir = Path("scripts")
    refs = 0
    for gd in scripts_dir.glob("*.gd"):
        if gd.name == "content_engine_runtime_loader.gd":
            continue
        txt = gd.read_text(encoding="utf-8")
        if "content_engine_runtime_loader.gd" in txt or "ContentEngineRuntimeLoader" in txt:
            refs += 1
        if "content_engine_loader_probe.gd" in txt:
            refs += 1
    if refs != 0:
        report.fail(f"existing .gd references loader/probe found: {refs}")
    else:
        report.pass_("no existing .gd references loader/probe")


def check_negative_report(report: ValidationReport) -> None:
    path = Path("data/design/generated_runtime_loader_negative_fixture_report.tsv")
    rows = read_tsv(path, ["fixture_name", "match_status", "returned_domain_count", "write_api_present"])
    if not all(r["match_status"] == "matched" for r in rows):
        report.fail("negative fixtures match_status must all be matched")
    else:
        report.pass_("negative fixtures all matched")
    neg = [r for r in rows if r["fixture_name"] != "valid_control"]
    if not all(r["returned_domain_count"] == "0" for r in neg):
        report.fail("negative fixtures returned_domain_count must all be 0")
    else:
        report.pass_("negative fixtures returned_domain_count all 0")
    if not all(r["write_api_present"] == "false" for r in rows):
        report.fail("negative fixtures write_api_present must all be false")
    else:
        report.pass_("negative fixtures write_api_present all false")


def main() -> int:
    parser = argparse.ArgumentParser(description="Validate content engine regression report.")
    parser.add_argument("--report", default=str(REPORT_TSV))
    parser.add_argument("--report-md", default=str(REPORT_MD))
    args = parser.parse_args()

    report = ValidationReport()

    rows = read_tsv(Path(args.report), REQUIRED_FIELDS)
    if not Path(args.report_md).exists():
        report.fail("missing regression markdown report")

    required_rows = [r for r in rows if r.get("required") == "true"]
    required_pass = [r for r in required_rows if r.get("status") == "PASS"]
    required_fail = [r for r in required_rows if r.get("status") != "PASS"]

    if required_fail:
        report.fail(f"failed required step count must be 0, got {len(required_fail)}")
    else:
        report.pass_("all required steps passed")

    if not any(r["step_name"] == "preview_formal_runtime_sha_unchanged" and r["status"] == "PASS" for r in rows):
        report.fail("preview_formal_runtime_sha_unchanged must PASS")
    else:
        report.pass_("preview formal runtime sha unchanged PASS")

    names = {p.name for p in RUNTIME_ROOT.iterdir() if p.is_file()} if RUNTIME_ROOT.exists() else set()
    if names != ALLOWED_RUNTIME_FILES:
        report.fail(f"runtime dir file set mismatch: expected={sorted(ALLOWED_RUNTIME_FILES)} actual={sorted(names)}")
    else:
        report.pass_("runtime dir still contains only 3 formal files")

    for script, label in [
        ("tools/content_engine/runtime_export_manifest_validator.py", "manifest validator"),
        ("tools/content_engine/runtime_loader_godot_probe_validator.py", "godot probe validator"),
        ("tools/content_engine/runtime_loader_negative_fixture_validator.py", "negative fixture validator"),
    ]:
        if run_subvalidator(script) != 0:
            report.fail(f"{label} failed")
        else:
            report.pass_(f"{label} passed")

    check_negative_report(report)
    check_no_refs(report)
    check_git_scope(report)

    print(report.format())
    return 0 if report.ok() else 1


if __name__ == "__main__":
    raise SystemExit(main())
