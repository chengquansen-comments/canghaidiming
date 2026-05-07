#!/usr/bin/env python3
"""验证 v0.9d battle_reward Godot compare/probe 报告与隔离边界。"""

from __future__ import annotations

import argparse
import csv
import subprocess
import sys
from dataclasses import dataclass, field
from pathlib import Path


REPORT_TSV = Path("data/design/generated_runtime_battle_reward_godot_compare_report.tsv")
REPORT_MD = Path("data/design/generated_runtime_battle_reward_godot_compare_report.md")
PLAN_TSV = Path("data/design/generated_battle_reward_plan.tsv")
RUNTIME_ROOT = Path("data/runtime/content_engine")
PROBE_SCRIPT = Path("tools/content_engine/content_engine_battle_reward_probe.gd")
ALLOWED_RUNTIME_FILES = {
    "card_pool.json",
    "battle_reward.json",
    "runtime_manifest.json",
    "runtime_loader_config.json",
}
REQUIRED_FIELDS = [
    "runtime_domain",
    "godot_probe_exit_code",
    "godot_probe_ok",
    "manifest_loaded",
    "manifest_valid",
    "runtime_loaded",
    "godot_runtime_record_count",
    "python_runtime_record_count",
    "legacy_record_count",
    "godot_runtime_field_count",
    "python_runtime_field_count",
    "record_count_match_status",
    "field_count_match_status",
    "missing_in_godot_count",
    "extra_in_godot_count",
    "changed_record_count",
    "manifest_first",
    "read_only",
    "formal_data_source_replaced",
    "integration_status",
    "gate_config_enabled",
    "gate_integration_mode",
    "existing_gd_reference_count",
    "risk_level",
    "blocked_reason",
    "notes",
]
FORBIDDEN_HIGH_RISK = {
    "scripts/card_data.gd",
    "scripts/battle_state_machine.gd",
    "scripts/combat_resolver.gd",
}
FORBIDDEN_WRITE_TOKENS = [
    "FileAccess.WRITE",
    "store_string",
    "store_var",
    "DirAccess.make_dir_recursive",
]


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


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="验证 runtime battle_reward Godot compare 报告。")
    parser.add_argument("--report", default=str(REPORT_TSV))
    parser.add_argument("--report-md", default=str(REPORT_MD))
    return parser.parse_args()


def read_tsv(path: Path, required_fields: list[str]) -> list[dict[str, str]]:
    with path.open("r", encoding="utf-8", newline="") as f:
        reader = csv.DictReader(f, delimiter="\t")
        fields = reader.fieldnames or []
        missing = [x for x in required_fields if x not in fields]
        if missing:
            raise ValueError(f"{path} missing columns: {', '.join(missing)}")
        return list(reader)


def parse_int_text(value: str, field_name: str) -> int:
    try:
        return int(value)
    except ValueError as exc:
        raise ValueError(f"{field_name} must be integer text, got {value!r}") from exc


def run_subvalidator(script: str) -> int:
    proc = subprocess.run([sys.executable, script], capture_output=True, text=True)
    return proc.returncode


def count_existing_gd_references() -> int:
    targets = [
        "content_engine_runtime_loader.gd",
        "ContentEngineRuntimeLoader",
        "content_engine_runtime_gate.gd",
        "ContentEngineRuntimeGate",
        "content_engine_battle_reward_probe.gd",
        "CONTENT_ENGINE_BATTLE_REWARD_PROBE_JSON_BEGIN",
    ]
    excluded = {
        "content_engine_runtime_loader.gd",
        "content_engine_runtime_gate.gd",
    }
    count = 0
    for gd in Path("scripts").glob("*.gd"):
        if gd.name in excluded:
            continue
        text = gd.read_text(encoding="utf-8")
        if any(token in text for token in targets):
            count += 1
    return count


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


def main() -> int:
    args = parse_args()
    report = ValidationReport()

    rows = read_tsv(Path(args.report), REQUIRED_FIELDS)
    if len(rows) != 1:
        report.fail(f"godot compare report row count must be 1, got {len(rows)}")
        print(report.format())
        return 1
    if not Path(args.report_md).exists():
        report.fail("missing runtime battle_reward godot compare markdown report")
    row = rows[0]

    plan_rows = read_tsv(PLAN_TSV, [])
    legacy_count_actual = len(plan_rows)

    try:
        godot_count = parse_int_text(row["godot_runtime_record_count"], "godot_runtime_record_count")
        python_count = parse_int_text(row["python_runtime_record_count"], "python_runtime_record_count")
        legacy_count = parse_int_text(row["legacy_record_count"], "legacy_record_count")
        _godot_field_count = parse_int_text(row["godot_runtime_field_count"], "godot_runtime_field_count")
        _python_field_count = parse_int_text(row["python_runtime_field_count"], "python_runtime_field_count")
        missing_in_godot = parse_int_text(row["missing_in_godot_count"], "missing_in_godot_count")
        extra_in_godot = parse_int_text(row["extra_in_godot_count"], "extra_in_godot_count")
        _changed_count = parse_int_text(row["changed_record_count"], "changed_record_count")
    except ValueError as exc:
        report.fail(str(exc))
        print(report.format())
        return 1

    if row["runtime_domain"] != "battle_reward":
        report.fail(f"runtime_domain must be battle_reward, got {row['runtime_domain']}")
    else:
        report.pass_("runtime_domain is battle_reward")

    if row["godot_probe_exit_code"] != "0":
        report.fail("godot_probe_exit_code must be 0")
    else:
        report.pass_("godot_probe_exit_code is 0")

    for key in ["godot_probe_ok", "manifest_loaded", "manifest_valid", "runtime_loaded", "manifest_first", "read_only"]:
        if row[key] != "true":
            report.fail(f"{key} must be true")
    if row["formal_data_source_replaced"] != "false":
        report.fail("formal_data_source_replaced must be false")
    if row["integration_status"] != "godot_compare_only":
        report.fail(f"integration_status must be godot_compare_only, got {row['integration_status']}")
    if row["gate_config_enabled"] != "false":
        report.fail("gate_config_enabled must be false")
    if row["gate_integration_mode"] != "disabled":
        report.fail("gate_integration_mode must be disabled")
    if row["record_count_match_status"] != "matched":
        report.fail("record_count_match_status must be matched")
    if row["field_count_match_status"] != "matched":
        report.fail("field_count_match_status must be matched")

    if godot_count not in {45, legacy_count_actual}:
        report.fail(f"godot_runtime_record_count must be 45 or legacy actual {legacy_count_actual}, got {godot_count}")
    if python_count != godot_count:
        report.fail("python_runtime_record_count must equal godot_runtime_record_count")
    if legacy_count != godot_count:
        report.fail("legacy_record_count must equal godot_runtime_record_count")
    if missing_in_godot != 0:
        report.fail(f"missing_in_godot_count must be 0, got {missing_in_godot}")
    if extra_in_godot != 0:
        report.fail(f"extra_in_godot_count must be 0, got {extra_in_godot}")

    if row["existing_gd_reference_count"] != "0":
        report.fail(f"existing_gd_reference_count must be 0, got {row['existing_gd_reference_count']}")
    else:
        report.pass_("existing_gd_reference_count is 0")

    if not PROBE_SCRIPT.exists():
        report.fail(f"missing probe script: {PROBE_SCRIPT}")
    else:
        probe_text = PROBE_SCRIPT.read_text(encoding="utf-8")
        for token in FORBIDDEN_WRITE_TOKENS:
            if token in probe_text:
                report.fail(f"probe contains forbidden write token: {token}")
        if "CONTENT_ENGINE_BATTLE_REWARD_PROBE_JSON_BEGIN" not in probe_text:
            report.fail("probe missing begin marker")
        if "CONTENT_ENGINE_BATTLE_REWARD_PROBE_JSON_END" not in probe_text:
            report.fail("probe missing end marker")
        if "load_manifest()" not in probe_text:
            report.fail("probe must call load_manifest for manifest-first")
        if "validate_runtime_file" not in probe_text:
            report.fail("probe must call validate_runtime_file for battle_reward runtime read")
        if "load_runtime_bundle" in probe_text:
            report.fail("probe must not call load_runtime_bundle (card_pool out_of_scope)")

    runtime_names = {p.name for p in RUNTIME_ROOT.iterdir() if p.is_file()} if RUNTIME_ROOT.exists() else set()
    if runtime_names != ALLOWED_RUNTIME_FILES:
        report.fail(f"runtime dir mismatch: expected={sorted(ALLOWED_RUNTIME_FILES)} actual={sorted(runtime_names)}")
    else:
        report.pass_("runtime dir contains only allowlisted files")

    actual_reference_count = count_existing_gd_references()
    if actual_reference_count != 0:
        report.fail(f"existing .gd references loader/gate/probe found: {actual_reference_count}")
    else:
        report.pass_("no existing .gd references loader/gate/probe")

    check_git_scope(report)

    if run_subvalidator("tools/content_engine/runtime_integration_gate_validator.py") != 0:
        report.fail("runtime_integration_gate_validator failed")
    else:
        report.pass_("runtime_integration_gate_validator passed")

    if run_subvalidator("tools/content_engine/runtime_battle_reward_compare_validator.py") != 0:
        report.fail("runtime_battle_reward_compare_validator failed")
    else:
        report.pass_("runtime_battle_reward_compare_validator passed")

    if run_subvalidator("tools/content_engine/runtime_export_manifest_validator.py") != 0:
        report.fail("runtime_export_manifest_validator failed")
    else:
        report.pass_("runtime_export_manifest_validator passed")

    print(report.format())
    return 0 if report.ok() else 1


if __name__ == "__main__":
    raise SystemExit(main())
