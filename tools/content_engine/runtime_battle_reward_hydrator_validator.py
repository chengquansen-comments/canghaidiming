#!/usr/bin/env python3
"""验证 v0.9c battle_reward hydration 报告与边界约束。"""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
import subprocess
import sys
from dataclasses import dataclass, field
from pathlib import Path


REPORT_TSV = Path("data/design/generated_runtime_battle_reward_hydration_report.tsv")
REPORT_MD = Path("data/design/generated_runtime_battle_reward_hydration_report.md")
SOURCE_TSV = Path("data/design/generated_battle_reward_plan.tsv")
RUNTIME_BATTLE_REWARD = Path("data/runtime/content_engine/battle_reward.json")
RUNTIME_MANIFEST = Path("data/runtime/content_engine/runtime_manifest.json")
CARD_POOL_PATH = Path("data/runtime/content_engine/card_pool.json")
RUNTIME_LOADER_CONFIG = Path("data/runtime/content_engine/runtime_loader_config.json")
ALLOWED_RUNTIME_FILES = {
    "card_pool.json",
    "battle_reward.json",
    "runtime_manifest.json",
    "runtime_loader_config.json",
}
REQUIRED_FIELDS = [
    "runtime_domain",
    "source_design_path",
    "runtime_path",
    "source_record_count",
    "hydrated_record_count",
    "source_field_count",
    "hydrated_field_count",
    "previous_runtime_record_count",
    "previous_runtime_field_count",
    "previous_content_fingerprint",
    "new_content_fingerprint",
    "manifest_updated",
    "card_pool_unchanged",
    "runtime_loader_config_unchanged",
    "read_only_integration",
    "formal_data_source_replaced",
    "integration_status",
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


def sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(65536), b""):
            h.update(chunk)
    return h.hexdigest()


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


def main() -> int:
    parser = argparse.ArgumentParser(description="验证 battle_reward hydrator 报告。")
    parser.add_argument("--report", default=str(REPORT_TSV))
    parser.add_argument("--report-md", default=str(REPORT_MD))
    args = parser.parse_args()

    report = ValidationReport()
    rows = read_tsv(Path(args.report), REQUIRED_FIELDS)
    if not Path(args.report_md).exists():
        report.fail("missing hydration markdown report")
    if len(rows) != 1:
        report.fail(f"hydration report row count must be 1, got {len(rows)}")
        print(report.format())
        return 1

    row = rows[0]

    with SOURCE_TSV.open("r", encoding="utf-8", newline="") as f:
        source_reader = csv.DictReader(f, delimiter="\t")
        source_rows = list(source_reader)
        source_fields = source_reader.fieldnames or []

    source_record_count = len(source_rows)
    if int(row["source_record_count"]) != source_record_count:
        report.fail(f"source_record_count mismatch: report={row['source_record_count']} actual={source_record_count}")
    if int(row["hydrated_record_count"]) != source_record_count:
        report.fail("hydrated_record_count must equal source_record_count")
    else:
        report.pass_("hydrated_record_count equals source_record_count")

    if int(row["source_field_count"]) != len(source_fields):
        report.fail("source_field_count mismatch")

    payload = json.loads(RUNTIME_BATTLE_REWARD.read_text(encoding="utf-8"))
    if not isinstance(payload, dict):
        report.fail("battle_reward.json must be object")
        print(report.format())
        return 1

    payload_cf = str(payload.get("content_fingerprint", ""))
    if not row["new_content_fingerprint"] or row["new_content_fingerprint"] != payload_cf:
        report.fail("new_content_fingerprint must be non-empty and match battle_reward.json")
    else:
        report.pass_("new_content_fingerprint matches runtime battle_reward.json")

    if int(payload.get("record_count", -1)) != source_record_count:
        report.fail("battle_reward.json record_count mismatch source")
    if int(payload.get("field_count", -1)) != int(row["hydrated_field_count"]):
        report.fail("battle_reward.json field_count mismatch hydration report")

    manifest = json.loads(RUNTIME_MANIFEST.read_text(encoding="utf-8"))
    if not isinstance(manifest, dict):
        report.fail("runtime_manifest.json must be object")
    files = manifest.get("files", []) if isinstance(manifest, dict) else []
    battle_entries = [x for x in files if isinstance(x, dict) and x.get("runtime_domain") == "battle_reward"]
    if len(battle_entries) != 1:
        report.fail(f"manifest battle_reward entry count must be 1, got {len(battle_entries)}")
    else:
        e = battle_entries[0]
        if str(e.get("content_fingerprint", "")) != payload_cf:
            report.fail("manifest battle_reward content_fingerprint mismatch")
        if int(e.get("record_count", -1)) != source_record_count:
            report.fail("manifest battle_reward record_count mismatch")
        if str(e.get("sha256", "")) != sha256_file(RUNTIME_BATTLE_REWARD):
            report.fail("manifest battle_reward sha256 mismatch")
        else:
            report.pass_("manifest battle_reward entry matches runtime file")

    if row["card_pool_unchanged"] != "true":
        report.fail("card_pool_unchanged must be true")
    if row["runtime_loader_config_unchanged"] != "true":
        report.fail("runtime_loader_config_unchanged must be true")
    if row["formal_data_source_replaced"] != "false":
        report.fail("formal_data_source_replaced must be false")
    if row["read_only_integration"] != "true":
        report.fail("read_only_integration must be true")
    if row["integration_status"] not in {"hydrated_not_integrated", "compare_only"}:
        report.fail(f"invalid integration_status: {row['integration_status']}")

    runtime_names = {p.name for p in Path("data/runtime/content_engine").iterdir() if p.is_file()}
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
