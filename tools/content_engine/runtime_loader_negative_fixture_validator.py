#!/usr/bin/env python3
"""Validate v0.8g negative fixture report and isolation constraints."""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
import subprocess
import sys
from dataclasses import dataclass, field
from pathlib import Path


REPORT_TSV = Path("data/design/generated_runtime_loader_negative_fixture_report.tsv")
REPORT_MD = Path("data/design/generated_runtime_loader_negative_fixture_report.md")
FIXTURE_ROOT = Path("data/design/runtime_loader_negative_fixtures")
INDEX_FILE = FIXTURE_ROOT / "fixture_manifest.json"
RUNTIME_ROOT = Path("data/runtime/content_engine")
ALLOWED_RUNTIME_FILES = {"card_pool.json", "battle_reward.json", "runtime_manifest.json", "runtime_loader_config.json"}
FIELDS = [
    "fixture_name",
    "fixture_path",
    "expected_ok",
    "actual_ok",
    "match_status",
    "expected_error_type",
    "actual_error_type",
    "manifest_loaded",
    "manifest_valid",
    "runtime_bundle_loaded",
    "fail_closed",
    "returned_domain_count",
    "write_api_present",
    "formal_runtime_unchanged",
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


def read_tsv(path: Path, required: list[str]) -> list[dict[str, str]]:
    with path.open("r", encoding="utf-8", newline="") as f:
        r = csv.DictReader(f, delimiter="\t")
        names = r.fieldnames or []
        missing = [x for x in required if x not in names]
        if missing:
            raise ValueError(f"{path} missing columns: {', '.join(missing)}")
        return list(r)


def sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(65536), b""):
            h.update(chunk)
    return h.hexdigest()


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
    loader_refs = 0
    probe_refs = 0
    for gd in scripts_dir.glob("*.gd"):
        if gd.name == "content_engine_runtime_loader.gd":
            continue
        txt = gd.read_text(encoding="utf-8")
        if "content_engine_runtime_loader.gd" in txt or "ContentEngineRuntimeLoader" in txt:
            loader_refs += 1
        if "content_engine_loader_probe.gd" in txt:
            probe_refs += 1
    if loader_refs != 0:
        report.fail(f"existing .gd references loader: {loader_refs}")
    if probe_refs != 0:
        report.fail(f"existing .gd references probe: {probe_refs}")


def main() -> int:
    parser = argparse.ArgumentParser(description="Validate runtime loader negative fixture report.")
    parser.add_argument("--report", default=str(REPORT_TSV))
    parser.add_argument("--report-md", default=str(REPORT_MD))
    args = parser.parse_args()

    report = ValidationReport()

    rows = read_tsv(Path(args.report), FIELDS)
    if len(rows) < 12:
        report.fail(f"fixture row count must be >=12, got {len(rows)}")

    if not Path(args.report_md).exists():
        report.fail("missing markdown report")

    by_name = {r["fixture_name"]: r for r in rows}
    if "valid_control" not in by_name:
        report.fail("valid_control fixture missing")
    else:
        if by_name["valid_control"]["actual_ok"] != "true":
            report.fail("valid_control must pass")

    for row in rows:
        name = row["fixture_name"]
        if row["match_status"] != "matched":
            report.fail(f"match_status must be matched: {name}")
        if row["fail_closed"] != "true":
            report.fail(f"fail_closed must be true: {name}")
        if row["write_api_present"] != "false":
            report.fail(f"write_api_present must be false: {name}")
        if row["formal_runtime_unchanged"] != "true":
            report.fail(f"formal_runtime_unchanged must be true: {name}")
        if name != "valid_control":
            if row["actual_ok"] != "false":
                report.fail(f"negative fixture must fail: {name}")
            if row["returned_domain_count"] != "0":
                report.fail(f"negative fixture returned_domain_count must be 0: {name}")

    # formal runtime hash unchanged check vs index baseline
    if INDEX_FILE.exists():
        index = json.loads(INDEX_FILE.read_text(encoding="utf-8"))
        before = index.get("formal_runtime_sha256_before", {})
        after = {n: sha256_file(RUNTIME_ROOT / n) for n in ["card_pool.json", "battle_reward.json", "runtime_manifest.json"]}
        if before != after:
            report.fail("formal runtime sha256 changed after fixture tests")
        else:
            report.pass_("formal runtime sha256 unchanged")
    else:
        report.fail("fixture index missing")

    names = {p.name for p in RUNTIME_ROOT.iterdir() if p.is_file()} if RUNTIME_ROOT.exists() else set()
    if names != ALLOWED_RUNTIME_FILES:
        report.fail(f"runtime dir file set mismatch: expected={sorted(ALLOWED_RUNTIME_FILES)} actual={sorted(names)}")
    else:
        report.pass_("runtime dir still has only 3 formal files")

    if run_subvalidator("tools/content_engine/runtime_export_manifest_validator.py") != 0:
        report.fail("runtime_export_manifest_validator failed")
    else:
        report.pass_("runtime_export_manifest_validator passed")

    if run_subvalidator("tools/content_engine/runtime_loader_godot_probe_validator.py") != 0:
        report.fail("runtime_loader_godot_probe_validator failed")
    else:
        report.pass_("runtime_loader_godot_probe_validator passed")

    check_no_refs(report)
    check_git_scope(report)

    print(report.format())
    return 0 if report.ok() else 1


if __name__ == "__main__":
    raise SystemExit(main())
