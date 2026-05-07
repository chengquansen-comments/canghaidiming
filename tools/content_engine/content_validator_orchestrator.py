#!/usr/bin/env python3
"""Run Content Engine validators and generate validator summaries."""

from __future__ import annotations

import argparse
import csv
import subprocess
import time
from collections import Counter
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path


SUMMARY_FIELDS = [
    "validator_id",
    "stage",
    "validator_script",
    "target_artifact_id",
    "target_artifact_path",
    "status",
    "warning_count",
    "error_count",
    "return_code",
    "duration_ms",
    "summary_line",
    "log_path",
    "notes",
]
LOG_DIRNAME = "validator_logs"
SUMMARY_TSV = "generated_validator_summary.tsv"
SUMMARY_MD = "generated_validator_summary.md"


@dataclass(frozen=True)
class ValidatorSpec:
    validator_id: str
    stage: str
    validator_script: str
    target_artifact_id: str
    target_artifact_path: str


@dataclass(frozen=True)
class ValidatorResult:
    validator_id: str
    stage: str
    validator_script: str
    target_artifact_id: str
    target_artifact_path: str
    status: str
    warning_count: int
    error_count: int
    return_code: int
    duration_ms: int
    summary_line: str
    log_path: str
    notes: str


VALIDATOR_SPECS = [
    ValidatorSpec(
        "progression_validator",
        "v0.1-v0.1.1",
        "tools/content_engine/progression_validator.py",
        "generated_battle_slot_plan,generated_enemy_deck_requirement,generated_route_progression_curve,generated_operation_node_requirement",
        "data/design/generated_battle_slot_plan.tsv,data/design/generated_enemy_deck_requirement.tsv,data/design/generated_route_progression_curve.tsv,data/design/generated_operation_node_requirement.tsv",
    ),
    ValidatorSpec(
        "enemy_archetype_validator",
        "v0.2",
        "tools/content_engine/enemy_archetype_validator.py",
        "generated_enemy_archetype_pool",
        "data/design/generated_enemy_archetype_pool.tsv",
    ),
    ValidatorSpec(
        "enemy_deck_skeleton_validator",
        "v0.3",
        "tools/content_engine/enemy_deck_skeleton_validator.py",
        "generated_enemy_deck_skeleton",
        "data/design/generated_enemy_deck_skeleton.tsv",
    ),
    ValidatorSpec(
        "card_pool_validator",
        "v0.4a",
        "tools/content_engine/card_pool_validator.py",
        "generated_card_pool",
        "data/design/generated_card_pool.tsv",
    ),
    ValidatorSpec(
        "enemy_deck_sets_validator",
        "v0.4b",
        "tools/content_engine/enemy_deck_sets_validator.py",
        "generated_enemy_deck_sets",
        "data/design/generated_enemy_deck_sets.tsv",
    ),
    ValidatorSpec(
        "battle_reward_validator",
        "v0.5a",
        "tools/content_engine/battle_reward_validator.py",
        "generated_battle_reward_plan",
        "data/design/generated_battle_reward_plan.tsv",
    ),
    ValidatorSpec(
        "operation_node_validator",
        "v0.5b",
        "tools/content_engine/operation_node_validator.py",
        "generated_operation_node_plan",
        "data/design/generated_operation_node_plan.tsv",
    ),
    ValidatorSpec(
        "narrative_node_validator",
        "v0.5c",
        "tools/content_engine/narrative_node_validator.py",
        "generated_narrative_node_plan",
        "data/design/generated_narrative_node_plan.tsv",
    ),
    ValidatorSpec(
        "route_gate_validator",
        "v0.5d",
        "tools/content_engine/route_gate_validator.py",
        "generated_route_gate_plan",
        "data/design/generated_route_gate_plan.tsv",
    ),
    ValidatorSpec(
        "content_package_manifest_validator",
        "v0.6a",
        "tools/content_engine/content_package_manifest_validator.py",
        "generated_content_package_manifest",
        "data/design/generated_content_package_manifest.tsv",
    ),
    ValidatorSpec(
        "content_package_report_validator",
        "v0.6b",
        "tools/content_engine/content_package_report_validator.py",
        "generated_content_package_report",
        "data/design/generated_content_package_report.md",
    ),
]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Run Content Engine validator orchestration.")
    parser.add_argument("--design-dir", default="data/design")
    parser.add_argument("--out-tsv", default=f"data/design/{SUMMARY_TSV}")
    parser.add_argument("--out-md", default=f"data/design/{SUMMARY_MD}")
    return parser.parse_args()


def parse_status(output: str, return_code: int, warning_count: int, error_count: int) -> tuple[str, str, str]:
    lines = [line.strip() for line in output.splitlines() if line.strip()]
    result_line = next((line for line in lines if line.startswith("RESULT:")), "")
    notes: list[str] = []

    if result_line == "RESULT: FAIL":
        notes.append("parsed_fail")
        status = "FAIL"
    elif result_line == "RESULT: WARN":
        status = "WARN"
    elif result_line == "RESULT: PASS":
        status = "WARN" if warning_count > 0 else "PASS"
        if warning_count > 0:
            notes.append("pass_result_with_warnings")
    elif return_code == 0:
        status = "WARN"
        notes.append("missing_result_marker")
    else:
        status = "FAIL"
        notes.append("missing_result_marker")

    if return_code != 0:
        status = "FAIL"
        if "nonzero_return_code" not in notes:
            notes.append("nonzero_return_code")

    summary_line = select_summary_line(lines, result_line)
    return status, summary_line, ",".join(notes)


def select_summary_line(lines: list[str], result_line: str) -> str:
    priority_prefixes = ("FAIL:", "ERROR:", "WARN:", "RESULT:", "PASS:")
    for prefix in priority_prefixes:
        line = next((item for item in lines if item.startswith(prefix)), "")
        if line:
            return line
    if result_line:
        return result_line
    return "no validator output"


def count_warning_lines(output: str) -> int:
    count = 0
    for line in output.splitlines():
        upper = line.upper()
        if "WARN:" in upper or upper.startswith("WARNING:") or " WARNING " in f" {upper} ":
            count += 1
    return count


def count_error_lines(output: str) -> int:
    count = 0
    for line in output.splitlines():
        upper = line.upper()
        if "FAIL:" in upper or upper.startswith("ERROR:"):
            count += 1
    return count


def ensure_parent(path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)


def run_validator(spec: ValidatorSpec, design_dir: Path, log_dir: Path) -> ValidatorResult:
    script_path = Path(spec.validator_script)
    log_path = log_dir / f"{spec.validator_id}.log"
    ensure_parent(log_path)

    if not script_path.exists():
        message = f"FAIL: Missing validator script: {script_path}\nRESULT: FAIL\n"
        log_path.write_text(message, encoding="utf-8")
        return ValidatorResult(
            validator_id=spec.validator_id,
            stage=spec.stage,
            validator_script=spec.validator_script,
            target_artifact_id=spec.target_artifact_id,
            target_artifact_path=spec.target_artifact_path,
            status="FAIL",
            warning_count=0,
            error_count=1,
            return_code=127,
            duration_ms=0,
            summary_line=f"FAIL: Missing validator script: {script_path}",
            log_path=log_path.as_posix(),
            notes="missing_validator_script",
        )

    started = time.perf_counter()
    completed = subprocess.run(
        ["python3", spec.validator_script, "--design-dir", str(design_dir)],
        capture_output=True,
        text=True,
        check=False,
    )
    duration_ms = int(round((time.perf_counter() - started) * 1000.0))

    stdout = completed.stdout.strip()
    stderr = completed.stderr.strip()
    output = stdout if not stderr else f"{stdout}\n{stderr}".strip()
    if not output:
        output = "<no output>"
    log_path.write_text(output + "\n", encoding="utf-8")

    warning_count = count_warning_lines(output)
    error_count = count_error_lines(output)
    status, summary_line, notes = parse_status(output, completed.returncode, warning_count, error_count)

    return ValidatorResult(
        validator_id=spec.validator_id,
        stage=spec.stage,
        validator_script=spec.validator_script,
        target_artifact_id=spec.target_artifact_id,
        target_artifact_path=spec.target_artifact_path,
        status=status,
        warning_count=warning_count,
        error_count=error_count,
        return_code=completed.returncode,
        duration_ms=duration_ms,
        summary_line=summary_line,
        log_path=log_path.as_posix(),
        notes=notes,
    )


def write_summary_tsv(path: Path, results: list[ValidatorResult]) -> None:
    ensure_parent(path)
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=SUMMARY_FIELDS, delimiter="\t", lineterminator="\n")
        writer.writeheader()
        for result in results:
            writer.writerow(
                {
                    "validator_id": result.validator_id,
                    "stage": result.stage,
                    "validator_script": result.validator_script,
                    "target_artifact_id": result.target_artifact_id,
                    "target_artifact_path": result.target_artifact_path,
                    "status": result.status,
                    "warning_count": str(result.warning_count),
                    "error_count": str(result.error_count),
                    "return_code": str(result.return_code),
                    "duration_ms": str(result.duration_ms),
                    "summary_line": result.summary_line,
                    "log_path": result.log_path,
                    "notes": result.notes,
                }
            )


def build_summary_md(results: list[ValidatorResult], design_dir: Path) -> str:
    counts = Counter(result.status for result in results)
    generated_at = datetime.now(timezone.utc).isoformat(timespec="seconds")
    lines = [
        "# Content Validator Summary",
        "",
        f"- Validator count: {len(results)}",
        f"- PASS count: {counts.get('PASS', 0)}",
        f"- WARN count: {counts.get('WARN', 0)}",
        f"- FAIL count: {counts.get('FAIL', 0)}",
        f"- Generated at: {generated_at}",
        f"- Design dir: {design_dir.as_posix()}",
        "",
        "## Validator Results",
        "",
        "| Validator | Stage | Target | Status | Warnings | Errors | Duration ms |",
        "|---|---|---|---|---:|---:|---:|",
    ]
    for result in results:
        lines.append(
            f"| {result.validator_id} | {result.stage} | {result.target_artifact_id} | {result.status} | {result.warning_count} | {result.error_count} | {result.duration_ms} |"
        )

    lines.extend(["", "## Failure Details", ""])
    failures = [result for result in results if result.status == "FAIL"]
    if not failures:
        lines.append("No failed validators.")
    else:
        for result in failures:
            lines.append(
                f"- {result.validator_id}: script={result.validator_script}, log_path={result.log_path}, summary_line={result.summary_line}"
            )

    lines.extend(["", "## Warning Details", ""])
    warnings = [result for result in results if result.status == "WARN"]
    if not warnings:
        lines.append("No validator warnings.")
    else:
        for result in warnings:
            lines.append(
                f"- {result.validator_id}: warning_count={result.warning_count}, log_path={result.log_path}, summary_line={result.summary_line}"
            )

    lines.extend(
        [
            "",
            "## Runtime Export Readiness",
            "",
            "- This summary does not approve runtime export.",
            "- Runtime export still requires manual approval and runtime exporter implementation.",
            "- Only artifacts with PASS validators should be considered for later approval.",
            "",
            "## Next Steps",
            "",
            "1. v0.6d content package approval / manual review",
            "2. v0.7 runtime exporter should read manifest + report + validator summary",
            "3. runtime exporter must not directly scan data/design/generated_*.tsv",
            "",
        ]
    )
    return "\n".join(lines)


def write_text(path: Path, text: str) -> None:
    ensure_parent(path)
    path.write_text(text, encoding="utf-8")


def main() -> int:
    args = parse_args()
    design_dir = Path(args.design_dir)
    out_tsv = Path(args.out_tsv)
    out_md = Path(args.out_md)
    log_dir = design_dir / LOG_DIRNAME

    results = [run_validator(spec, design_dir, log_dir) for spec in VALIDATOR_SPECS]
    write_summary_tsv(out_tsv, results)
    write_text(out_md, build_summary_md(results, design_dir))

    counts = Counter(result.status for result in results)
    print(
        f"Wrote {out_tsv} and {out_md} for {len(results)} validators "
        f"(PASS={counts.get('PASS', 0)}, WARN={counts.get('WARN', 0)}, FAIL={counts.get('FAIL', 0)})."
    )
    return 1 if counts.get("FAIL", 0) > 0 else 0


if __name__ == "__main__":
    raise SystemExit(main())
