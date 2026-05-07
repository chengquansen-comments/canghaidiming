#!/usr/bin/env python3
"""验证 battle_reward 受控只读接入试验报告与隔离边界。"""

from __future__ import annotations

import argparse
import csv
import subprocess
import sys
from dataclasses import dataclass, field
from pathlib import Path


REPORT_TSV = Path("data/design/generated_battle_reward_readonly_integration_probe_report.tsv")
REPORT_MD = Path("data/design/generated_battle_reward_readonly_integration_probe_report.md")
RUNTIME_DIR = Path("data/runtime/content_engine")
PLAN_TSV = Path("data/design/generated_battle_reward_plan.tsv")
PROBE_GD = Path("tools/content_engine/battle_reward_readonly_integration_probe.gd")
REQUIRED_FIELDS = [
    "runtime_domain",
    "godot_exit_code",
    "probe_ok",
    "manifest_loaded",
    "manifest_valid",
    "runtime_loaded",
    "runtime_record_count",
    "legacy_record_count",
    "record_count_match_status",
    "field_count_match_status",
    "missing_in_runtime_count",
    "extra_in_runtime_count",
    "changed_record_count",
    "config_enabled",
    "integration_mode",
    "read_only",
    "formal_data_source_replaced",
    "combat_flow_touched",
    "battle_state_touched",
    "card_pool_out_of_scope",
    "existing_gd_reference_count",
    "integration_status",
    "risk_level",
    "blocked_reason",
    "notes",
]
ALLOWED_RUNTIME_FILES = {
    "battle_reward.json",
    "card_pool.json",
    "runtime_manifest.json",
    "runtime_loader_config.json",
}
FORBIDDEN_HIGH_RISK = {
    "scripts/combat_resolver.gd",
    "scripts/battle_state_machine.gd",
    "scripts/card_data.gd",
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
    parser = argparse.ArgumentParser(description="验证 battle_reward readonly integration probe 输出。")
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


def tsv_row_count(path: Path) -> int:
    with path.open("r", encoding="utf-8", newline="") as f:
        return len(list(csv.DictReader(f, delimiter="\t")))


def run_cmd(cmd: list[str]) -> tuple[int, str]:
    proc = subprocess.run(cmd, capture_output=True, text=True)
    return proc.returncode, (proc.stdout + proc.stderr)


def parse_int(value: str, name: str) -> int:
    try:
        return int(value)
    except ValueError as exc:
        raise ValueError(f"{name} must be integer text, got {value!r}") from exc


def count_existing_gd_references() -> int:
    targets = [
        "content_engine_runtime_loader.gd",
        "ContentEngineRuntimeLoader",
        "content_engine_runtime_gate.gd",
        "ContentEngineRuntimeGate",
        "content_engine_battle_reward_probe.gd",
        "CONTENT_ENGINE_BATTLE_REWARD_PROBE_JSON_BEGIN",
        "battle_reward_readonly_integration_probe.gd",
        "BATTLE_REWARD_READONLY_INTEGRATION_PROBE_JSON_BEGIN",
    ]
    excluded = {"content_engine_runtime_loader.gd", "content_engine_runtime_gate.gd"}
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
        report.fail(f"report row count must be 1, got {len(rows)}")
        print(report.format())
        return 1
    if not Path(args.report_md).exists():
        report.fail("missing markdown report")
    row = rows[0]

    try:
        runtime_count = parse_int(row["runtime_record_count"], "runtime_record_count")
        legacy_count = parse_int(row["legacy_record_count"], "legacy_record_count")
        missing_count = parse_int(row["missing_in_runtime_count"], "missing_in_runtime_count")
        extra_count = parse_int(row["extra_in_runtime_count"], "extra_in_runtime_count")
        _changed_count = parse_int(row["changed_record_count"], "changed_record_count")
    except ValueError as exc:
        report.fail(str(exc))
        print(report.format())
        return 1

    legacy_actual = tsv_row_count(PLAN_TSV)
    if row["runtime_domain"] != "battle_reward":
        report.fail("runtime_domain must be battle_reward")
    if row["godot_exit_code"] != "0":
        report.fail("godot_exit_code must be 0")
    if row["probe_ok"] != "true":
        report.fail("probe_ok must be true")
    if row["manifest_loaded"] != "true":
        report.fail("manifest_loaded must be true")
    if row["manifest_valid"] != "true":
        report.fail("manifest_valid must be true")
    if row["runtime_loaded"] != "true":
        report.fail("runtime_loaded must be true")
    if runtime_count not in {45, legacy_actual}:
        report.fail(f"runtime_record_count must be 45 or legacy actual {legacy_actual}, got {runtime_count}")
    if legacy_count != runtime_count:
        report.fail("legacy_record_count must equal runtime_record_count")
    if row["record_count_match_status"] != "matched":
        report.fail("record_count_match_status must be matched")
    if row["field_count_match_status"] != "matched":
        report.fail("field_count_match_status must be matched")
    if missing_count != 0:
        report.fail("missing_in_runtime_count must be 0")
    if extra_count != 0:
        report.fail("extra_in_runtime_count must be 0")
    if row["config_enabled"] != "false":
        report.fail("config_enabled must be false")
    if row["integration_mode"] != "disabled":
        report.fail("integration_mode must be disabled")
    if row["read_only"] != "true":
        report.fail("read_only must be true")
    if row["formal_data_source_replaced"] != "false":
        report.fail("formal_data_source_replaced must be false")
    if row["combat_flow_touched"] != "false":
        report.fail("combat_flow_touched must be false")
    if row["battle_state_touched"] != "false":
        report.fail("battle_state_touched must be false")
    if row["card_pool_out_of_scope"] != "true":
        report.fail("card_pool_out_of_scope must be true")
    if row["existing_gd_reference_count"] != "0":
        report.fail("existing_gd_reference_count must be 0")
    if row["integration_status"] != "readonly_probe_only":
        report.fail("integration_status must be readonly_probe_only")

    if not PROBE_GD.exists():
        report.fail(f"missing probe gd: {PROBE_GD}")
    else:
        gd_text = PROBE_GD.read_text(encoding="utf-8")
        for token in FORBIDDEN_WRITE_TOKENS:
            if token in gd_text:
                report.fail(f"probe contains forbidden write token: {token}")

    runtime_files = {p.name for p in RUNTIME_DIR.iterdir() if p.is_file()} if RUNTIME_DIR.exists() else set()
    if runtime_files != ALLOWED_RUNTIME_FILES:
        report.fail(f"runtime dir mismatch: expected={sorted(ALLOWED_RUNTIME_FILES)} actual={sorted(runtime_files)}")
    else:
        report.pass_("runtime dir contains only allowlisted files")

    ref_count = count_existing_gd_references()
    if ref_count != 0:
        report.fail(f"existing .gd references loader/gate/probe found: {ref_count}")
    else:
        report.pass_("no existing .gd references loader/gate/probe")

    check_git_scope(report)

    check_rc, _ = run_cmd([sys.executable, "tools/content_engine/content_engine_check.py"])
    if check_rc != 0:
        report.fail("content_engine_check.py failed")
    else:
        report.pass_("content_engine_check.py passed")

    validate_rc, _ = run_cmd([sys.executable, "tools/content_engine/content_engine_validate.py"])
    if validate_rc != 0:
        report.fail("content_engine_validate.py failed")
    else:
        report.pass_("content_engine_validate.py passed")

    print(report.format())
    return 0 if report.ok() else 1


if __name__ == "__main__":
    raise SystemExit(main())
