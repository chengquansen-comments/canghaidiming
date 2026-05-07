#!/usr/bin/env python3
"""Validate v0.9b runtime battle_reward compare report and isolation constraints."""

from __future__ import annotations

import argparse
import csv
import subprocess
import sys
from dataclasses import dataclass, field
from pathlib import Path


REPORT_TSV = Path("data/design/generated_runtime_battle_reward_compare_report.tsv")
REPORT_MD = Path("data/design/generated_runtime_battle_reward_compare_report.md")
RUNTIME_ROOT = Path("data/runtime/content_engine")
ALLOWED_RUNTIME_FILES = {
    "card_pool.json",
    "battle_reward.json",
    "runtime_manifest.json",
    "runtime_loader_config.json",
}
REQUIRED_FIELDS = [
    "runtime_domain",
    "artifact_id",
    "runtime_path",
    "runtime_loaded",
    "runtime_record_count",
    "runtime_field_count",
    "legacy_source_status",
    "legacy_source_path",
    "legacy_record_count",
    "legacy_field_count",
    "compare_scope",
    "comparable",
    "schema_match_status",
    "record_count_match_status",
    "field_count_match_status",
    "missing_in_runtime_count",
    "extra_in_runtime_count",
    "changed_record_count",
    "read_only",
    "formal_data_source_replaced",
    "integration_status",
    "risk_level",
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
        lines = [*(f"PASS: {x}" for x in self.passes), *(f"FAIL: {x}" for x in self.failures)]
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


def check_no_loader_gate_refs(report: ValidationReport) -> None:
    scripts_dir = Path("scripts")
    loader_refs = 0
    gate_refs = 0
    for gd in scripts_dir.glob("*.gd"):
        text = gd.read_text(encoding="utf-8")
        if gd.name != "content_engine_runtime_loader.gd":
            if "content_engine_runtime_loader.gd" in text or "ContentEngineRuntimeLoader" in text:
                loader_refs += 1
        if gd.name != "content_engine_runtime_gate.gd":
            if "content_engine_runtime_gate.gd" in text or "ContentEngineRuntimeGate" in text:
                gate_refs += 1
    if loader_refs != 0:
        report.fail(f"existing .gd references loader found: {loader_refs}")
    if gate_refs != 0:
        report.fail(f"existing .gd references gate found: {gate_refs}")
    if loader_refs == 0 and gate_refs == 0:
        report.pass_("no existing .gd references loader/gate")


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


def is_int_text(value: str) -> bool:
    try:
        int(value)
        return True
    except ValueError:
        return False


def main() -> int:
    parser = argparse.ArgumentParser(description="Validate runtime battle_reward compare report.")
    parser.add_argument("--report", default=str(REPORT_TSV))
    parser.add_argument("--report-md", default=str(REPORT_MD))
    args = parser.parse_args()

    report = ValidationReport()
    rows = read_tsv(Path(args.report), REQUIRED_FIELDS)
    if not Path(args.report_md).exists():
        report.fail("missing runtime battle_reward compare markdown report")
    if len(rows) != 1:
        report.fail(f"compare report row count must be 1, got {len(rows)}")
        print(report.format())
        return 1

    row = rows[0]

    if row["runtime_domain"] != "battle_reward":
        report.fail(f"runtime_domain must be battle_reward, got {row['runtime_domain']}")
    else:
        report.pass_("runtime_domain is battle_reward")

    if row["runtime_loaded"] != "true":
        report.fail("runtime_loaded must be true")
    else:
        report.pass_("runtime_loaded is true")

    if row["read_only"] != "true":
        report.fail("read_only must be true")
    else:
        report.pass_("read_only is true")

    if row["formal_data_source_replaced"] != "false":
        report.fail("formal_data_source_replaced must be false")
    else:
        report.pass_("formal_data_source_replaced is false")

    if row["integration_status"] not in {"not_integrated", "compare_only"}:
        report.fail(f"integration_status invalid: {row['integration_status']}")
    else:
        report.pass_(f"integration_status valid: {row['integration_status']}")

    if row["compare_scope"] not in {"runtime_only", "runtime_vs_legacy", "legacy_source_ambiguous"}:
        report.fail(f"invalid compare_scope: {row['compare_scope']}")

    if row["legacy_source_status"] not in {"found", "not_found", "ambiguous"}:
        report.fail(f"invalid legacy_source_status: {row['legacy_source_status']}")

    if row["comparable"] not in {"true", "false"}:
        report.fail("comparable must be true/false")

    for key in [
        "runtime_record_count",
        "runtime_field_count",
        "legacy_record_count",
        "legacy_field_count",
        "missing_in_runtime_count",
        "extra_in_runtime_count",
        "changed_record_count",
    ]:
        if not is_int_text(row[key]):
            report.fail(f"{key} must be integer text, got {row[key]!r}")

    runtime_names = {p.name for p in RUNTIME_ROOT.iterdir() if p.is_file()} if RUNTIME_ROOT.exists() else set()
    if runtime_names != ALLOWED_RUNTIME_FILES:
        report.fail(f"runtime dir mismatch: expected={sorted(ALLOWED_RUNTIME_FILES)} actual={sorted(runtime_names)}")
    else:
        report.pass_("runtime dir contains only allowlisted files")

    check_no_loader_gate_refs(report)
    check_git_scope(report)

    if run_subvalidator("tools/content_engine/content_engine_regression_validator.py") != 0:
        report.fail("content_engine_regression_validator failed")
    else:
        report.pass_("content_engine_regression_validator passed")

    if run_subvalidator("tools/content_engine/runtime_integration_gate_validator.py") != 0:
        report.fail("runtime_integration_gate_validator failed")
    else:
        report.pass_("runtime_integration_gate_validator passed")

    print(report.format())
    return 0 if report.ok() else 1


if __name__ == "__main__":
    raise SystemExit(main())
