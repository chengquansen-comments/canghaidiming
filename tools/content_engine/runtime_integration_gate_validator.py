#!/usr/bin/env python3
"""Validate v0.9a runtime integration gate report and isolation constraints."""

from __future__ import annotations

import argparse
import csv
import json
import subprocess
import sys
from dataclasses import dataclass, field
from pathlib import Path


REPORT_TSV = Path("data/design/generated_runtime_integration_gate_report.tsv")
REPORT_MD = Path("data/design/generated_runtime_integration_gate_report.md")
CONFIG_PATH = Path("data/runtime/content_engine/runtime_loader_config.json")
RUNTIME_ROOT = Path("data/runtime/content_engine")
ALLOWED_RUNTIME_FILES = {
    "card_pool.json",
    "battle_reward.json",
    "runtime_manifest.json",
    "runtime_loader_config.json",
}
REQUIRED_FIELDS = [
    "config_path",
    "gate_script",
    "content_engine_runtime_enabled",
    "read_only_probe_enabled",
    "integration_mode",
    "fallback_mode",
    "gate_status",
    "gate_default_disabled",
    "write_api_present",
    "existing_gd_reference_count",
    "formal_data_source_replaced",
    "runtime_dir_allowed_only",
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


def run_subvalidator(script: str) -> int:
    return subprocess.run([sys.executable, script], capture_output=True, text=True).returncode


def check_config_default(report: ValidationReport) -> None:
    if not CONFIG_PATH.exists():
        report.fail(f"missing config: {CONFIG_PATH}")
        return
    try:
        cfg = json.loads(CONFIG_PATH.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        report.fail(f"config parse failed: {exc}")
        return
    if not isinstance(cfg, dict):
        report.fail("config must be JSON object")
        return

    if cfg.get("content_engine_runtime_enabled") is not False:
        report.fail("config.content_engine_runtime_enabled must be false")
    if cfg.get("read_only_probe_enabled") is not False:
        report.fail("config.read_only_probe_enabled must be false")
    if str(cfg.get("integration_mode", "")) != "disabled":
        report.fail("config.integration_mode must be disabled")
    if str(cfg.get("fallback_mode", "")) != "existing_data_source":
        report.fail("config.fallback_mode must be existing_data_source")


def main() -> int:
    parser = argparse.ArgumentParser(description="Validate runtime integration gate report.")
    parser.add_argument("--report", default=str(REPORT_TSV))
    parser.add_argument("--report-md", default=str(REPORT_MD))
    args = parser.parse_args()

    report = ValidationReport()

    rows = read_tsv(Path(args.report), REQUIRED_FIELDS)
    if not Path(args.report_md).exists():
        report.fail("missing runtime integration gate markdown report")
    if len(rows) != 1:
        report.fail(f"gate report row count must be 1, got {len(rows)}")
        print(report.format())
        return 1

    row = rows[0]

    if row["content_engine_runtime_enabled"] != "false":
        report.fail("content_engine_runtime_enabled must be false")
    else:
        report.pass_("content_engine_runtime_enabled is false")

    if row["integration_mode"] != "disabled":
        report.fail("integration_mode must be disabled")
    else:
        report.pass_("integration_mode is disabled")

    if row["fallback_mode"] != "existing_data_source":
        report.fail("fallback_mode must be existing_data_source")
    else:
        report.pass_("fallback_mode is existing_data_source")

    if row["gate_status"] not in {"disabled", "not_integrated"}:
        report.fail(f"gate_status must be disabled or not_integrated, got {row['gate_status']}")
    else:
        report.pass_(f"gate_status valid: {row['gate_status']}")

    if row["gate_default_disabled"] != "true":
        report.fail("gate_default_disabled must be true")
    else:
        report.pass_("gate_default_disabled is true")

    if row["write_api_present"] != "false":
        report.fail("write_api_present must be false")
    else:
        report.pass_("write_api_present is false")

    if row["existing_gd_reference_count"] != "0":
        report.fail(f"existing_gd_reference_count must be 0, got {row['existing_gd_reference_count']}")
    else:
        report.pass_("existing_gd_reference_count is 0")

    if row["formal_data_source_replaced"] != "false":
        report.fail("formal_data_source_replaced must be false")
    else:
        report.pass_("formal_data_source_replaced is false")

    runtime_names = {p.name for p in RUNTIME_ROOT.iterdir() if p.is_file()} if RUNTIME_ROOT.exists() else set()
    if runtime_names != ALLOWED_RUNTIME_FILES:
        report.fail(
            f"runtime dir file set mismatch: expected={sorted(ALLOWED_RUNTIME_FILES)} actual={sorted(runtime_names)}"
        )
    else:
        report.pass_("runtime dir contains only allowlisted v0.9a files")

    check_config_default(report)
    check_git_scope(report)

    if run_subvalidator("tools/content_engine/content_engine_regression_validator.py") != 0:
        report.fail("content_engine_regression_validator failed")
    else:
        report.pass_("content_engine_regression_validator passed")

    print(report.format())
    return 0 if report.ok() else 1


if __name__ == "__main__":
    raise SystemExit(main())
