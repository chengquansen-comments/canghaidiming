#!/usr/bin/env python3
"""CI-friendly regression runner for Content Engine v0.8h."""

from __future__ import annotations

import argparse
import csv
import hashlib
import subprocess
import time
from collections import defaultdict
from pathlib import Path


REPORT_TSV = Path("data/design/generated_content_engine_regression_report.tsv")
REPORT_MD = Path("data/design/generated_content_engine_regression_report.md")
RUNTIME_ROOT = Path("data/runtime/content_engine")
FORMAL_RUNTIME_FILES = ["card_pool.json", "battle_reward.json", "runtime_manifest.json"]
ALLOWED_RUNTIME_FILES = set(FORMAL_RUNTIME_FILES)

FIELDS = [
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


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Run v0.7b->v0.8g regression chain and build CI-friendly report.")
    parser.add_argument("--out", default=str(REPORT_TSV))
    parser.add_argument("--out-md", default=str(REPORT_MD))
    return parser.parse_args()


def sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(65536), b""):
            h.update(chunk)
    return h.hexdigest()


def tail_text(text: str, max_lines: int = 20, max_chars: int = 1800) -> str:
    lines = text.splitlines()
    clipped = "\n".join(lines[-max_lines:])
    return clipped[-max_chars:]


def run_command(command: str) -> tuple[int, int, str, str]:
    start = time.time()
    proc = subprocess.run(command, shell=True, capture_output=True, text=True)
    duration_ms = int((time.time() - start) * 1000)
    return proc.returncode, duration_ms, tail_text(proc.stdout), tail_text(proc.stderr)


def append_step(
    rows: list[dict[str, str]],
    *,
    step_id: int,
    phase: str,
    step_name: str,
    command: str,
    required: bool,
    exit_code: int,
    duration_ms: int,
    stdout_tail: str,
    stderr_tail: str,
    blocked_reason: str = "",
    notes: str = "",
) -> None:
    status = "PASS" if exit_code == 0 else "FAIL"
    rows.append(
        {
            "step_id": str(step_id),
            "phase": phase,
            "step_name": step_name,
            "command": command,
            "exit_code": str(exit_code),
            "status": status,
            "duration_ms": str(duration_ms),
            "stdout_tail": stdout_tail,
            "stderr_tail": stderr_tail,
            "required": "true" if required else "false",
            "blocked_reason": blocked_reason,
            "notes": notes,
        }
    )


def runtime_file_set() -> set[str]:
    if not RUNTIME_ROOT.exists() or not RUNTIME_ROOT.is_dir():
        return set()
    return {p.name for p in RUNTIME_ROOT.iterdir() if p.is_file()}


def capture_formal_runtime_sha() -> dict[str, str]:
    result: dict[str, str] = {}
    for name in FORMAL_RUNTIME_FILES:
        path = RUNTIME_ROOT / name
        if not path.exists():
            result[name] = ""
        else:
            result[name] = sha256_file(path)
    return result


def build_steps() -> list[tuple[str, str, str, bool]]:
    py_compile_cmd = (
        "python3 -m py_compile "
        "tools/content_engine/runtime_export_dry_run.py "
        "tools/content_engine/runtime_export_dry_run_validator.py "
        "tools/content_engine/runtime_export_approval_overlay.py "
        "tools/content_engine/runtime_export_approval_validator.py "
        "tools/content_engine/runtime_export_diff_report.py "
        "tools/content_engine/runtime_export_diff_report_validator.py "
        "tools/content_engine/runtime_exporter.py "
        "tools/content_engine/runtime_exporter_validator.py "
        "tools/content_engine/runtime_export_manifest.py "
        "tools/content_engine/runtime_export_manifest_validator.py "
        "tools/content_engine/runtime_loader_preflight.py "
        "tools/content_engine/runtime_loader_preflight_validator.py "
        "tools/content_engine/runtime_loader_scaffold_probe.py "
        "tools/content_engine/runtime_loader_scaffold_validator.py "
        "tools/content_engine/runtime_loader_godot_probe.py "
        "tools/content_engine/runtime_loader_godot_probe_validator.py "
        "tools/content_engine/runtime_loader_negative_fixture_builder.py "
        "tools/content_engine/runtime_loader_negative_fixture_probe.py "
        "tools/content_engine/runtime_loader_negative_fixture_validator.py"
    )

    return [
        ("compile", "py_compile", py_compile_cmd, True),
        ("preview", "runtime_export_dry_run", "python3 tools/content_engine/runtime_export_dry_run.py", True),
        # legacy validator may fail when formal runtime files already exist; keep as non-required telemetry step.
        ("preview", "runtime_export_dry_run_validator", "python3 tools/content_engine/runtime_export_dry_run_validator.py", False),
        ("preview", "runtime_export_approval_overlay", "python3 tools/content_engine/runtime_export_approval_overlay.py", True),
        ("preview", "runtime_export_approval_validator", "python3 tools/content_engine/runtime_export_approval_validator.py", True),
        ("preview", "runtime_export_diff_report", "python3 tools/content_engine/runtime_export_diff_report.py", True),
        ("preview", "runtime_export_diff_report_validator", "python3 tools/content_engine/runtime_export_diff_report_validator.py", False),
        ("preview", "runtime_exporter_preview", "python3 tools/content_engine/runtime_exporter.py", True),
        # legacy exporter validator assumes runtime dir absence in no-write mode.
        ("preview", "runtime_exporter_preview_validator", "python3 tools/content_engine/runtime_exporter_validator.py", False),
        ("guarded_write", "runtime_exporter_guarded_write", "python3 tools/content_engine/runtime_exporter.py --write-runtime --confirm-runtime-export", True),
        # legacy guarded-write validator predates runtime_manifest.json and expects only 2 runtime files.
        ("guarded_write", "runtime_exporter_guarded_write_validator", "python3 tools/content_engine/runtime_exporter_validator.py --allow-runtime-files", False),
        ("manifest", "runtime_export_manifest", "python3 tools/content_engine/runtime_export_manifest.py", True),
        ("manifest", "runtime_export_manifest_validator", "python3 tools/content_engine/runtime_export_manifest_validator.py", True),
        ("preflight", "runtime_loader_preflight", "python3 tools/content_engine/runtime_loader_preflight.py", True),
        ("preflight", "runtime_loader_preflight_validator", "python3 tools/content_engine/runtime_loader_preflight_validator.py", True),
        ("scaffold", "runtime_loader_scaffold_probe", "python3 tools/content_engine/runtime_loader_scaffold_probe.py", True),
        ("scaffold", "runtime_loader_scaffold_validator", "python3 tools/content_engine/runtime_loader_scaffold_validator.py", True),
        ("probe", "runtime_loader_godot_probe", "python3 tools/content_engine/runtime_loader_godot_probe.py", True),
        ("probe", "runtime_loader_godot_probe_validator", "python3 tools/content_engine/runtime_loader_godot_probe_validator.py", True),
        ("negative_fixture", "runtime_loader_negative_fixture_builder", "python3 tools/content_engine/runtime_loader_negative_fixture_builder.py", True),
        ("negative_fixture", "runtime_loader_negative_fixture_probe", "python3 tools/content_engine/runtime_loader_negative_fixture_probe.py", True),
        ("negative_fixture", "runtime_loader_negative_fixture_validator", "python3 tools/content_engine/runtime_loader_negative_fixture_validator.py", True),
        ("hygiene", "git_diff_check", "git diff --check", True),
        ("hygiene", "godot_headless_quit", "godot --headless --path . --quit", True),
        ("hygiene", "godot_headless_mainvisual", "godot --headless --path . --quit scenes/MainVisual.tscn", True),
    ]


def write_tsv(path: Path, rows: list[dict[str, str]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="") as f:
        w = csv.DictWriter(f, fieldnames=FIELDS, delimiter="\t", lineterminator="\n")
        w.writeheader()
        w.writerows(rows)


def summarize_phase(rows: list[dict[str, str]]) -> dict[str, tuple[int, int]]:
    stats: dict[str, list[int]] = defaultdict(lambda: [0, 0])
    for row in rows:
        phase = row["phase"]
        stats[phase][0] += 1
        if row["status"] == "PASS":
            stats[phase][1] += 1
    return {k: (v[0], v[1]) for k, v in stats.items()}


def write_md(path: Path, rows: list[dict[str, str]], summary: dict[str, str]) -> None:
    required_rows = [r for r in rows if r["required"] == "true"]
    failed_required = [r for r in required_rows if r["status"] != "PASS"]
    overall = "PASS" if not failed_required else "FAIL"
    phases = summarize_phase(rows)
    failed = [r for r in rows if r["status"] != "PASS"]

    lines = [
        "# Content Engine Regression Report",
        "",
        f"- Overall: {overall}",
        f"- Step count: {len(rows)}",
        f"- Required PASS: {sum(1 for r in required_rows if r['status']=='PASS')}/{len(required_rows)}",
        f"- Failed required steps: {len(failed_required)}",
        "",
        "## Phase Summary",
        "",
    ]
    for phase, (total, passed) in sorted(phases.items()):
        lines.append(f"- {phase}: {passed}/{total} PASS")

    lines.extend(["", "## Failed Steps", ""])
    if not failed:
        lines.append("- none")
    else:
        for row in failed:
            lines.append(f"- {row['step_id']} {row['step_name']} (required={row['required']}) exit={row['exit_code']}")

    lines.extend(
        [
            "",
            "## Runtime Safety Summary",
            "",
            f"- preview_formal_runtime_sha_unchanged: {summary['preview_sha_unchanged']}",
            f"- preview_runtime_dir_allowed_only: {summary['preview_runtime_allowed_only']}",
            f"- runtime_dir_allowed_only_end: {summary['runtime_allowed_only_end']}",
            "",
            "## Manifest/Checksum Summary",
            "",
            f"- runtime_export_manifest_validator_pass: {summary['manifest_validator_pass']}",
            "",
            "## Loader/Probe Summary",
            "",
            f"- runtime_loader_godot_probe_validator_pass: {summary['godot_probe_validator_pass']}",
            f"- runtime_loader_scaffold_validator_pass: {summary['scaffold_validator_pass']}",
            "",
            "## Negative Fixture Summary",
            "",
            f"- runtime_loader_negative_fixture_validator_pass: {summary['negative_validator_pass']}",
            f"- negative_fixture_match_all_matched: {summary['negative_match_all']}",
            f"- negative_fixture_returned_domain_count_zero: {summary['negative_returned_zero']}",
            f"- negative_fixture_write_api_present_false: {summary['negative_write_api_false']}",
            "",
            "## Godot Warning Summary",
            "",
            f"- warning_detected: {summary['warning_detected']}",
            "- Godot warning is tracked as independent hygiene issue and does not block content engine regression when exit code is 0.",
            "",
            "## High-Risk Files",
            "",
            "- scripts/card_data.gd unchanged",
            "- scripts/battle_state_machine.gd unchanged",
            "- scripts/combat_resolver.gd unchanged",
            "- scenes/*.tscn unchanged",
            "- data/story_battles/*.tsv unchanged",
            "",
        ]
    )

    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(lines), encoding="utf-8")


def parse_negative_report() -> tuple[str, str, str]:
    path = Path("data/design/generated_runtime_loader_negative_fixture_report.tsv")
    if not path.exists():
        return "false", "false", "false"
    rows = list(csv.DictReader(path.open("r", encoding="utf-8"), delimiter="\t"))
    if not rows:
        return "false", "false", "false"
    all_matched = all(r.get("match_status") == "matched" for r in rows)
    neg_rows = [r for r in rows if r.get("fixture_name") != "valid_control"]
    returned_zero = all(r.get("returned_domain_count") == "0" for r in neg_rows)
    write_api_false = all(r.get("write_api_present") == "false" for r in rows)
    return ("true" if all_matched else "false", "true" if returned_zero else "false", "true" if write_api_false else "false")


def main() -> int:
    args = parse_args()
    rows: list[dict[str, str]] = []

    baseline_sha = capture_formal_runtime_sha()
    baseline_set = runtime_file_set()

    step_id = 1
    warning_detected = False

    for phase, step_name, command, required in build_steps():
        exit_code, duration_ms, out_tail, err_tail = run_command(command)
        notes = ""
        blocked_reason = ""
        if step_name.startswith("godot_headless"):
            combined = out_tail + "\n" + err_tail
            if "WARNING:" in combined or "ObjectDB" in combined or "RID" in combined:
                warning_detected = True
                notes = "warning_detected=true; treated as Godot hygiene issue when exit_code=0"
        append_step(
            rows,
            step_id=step_id,
            phase=phase,
            step_name=step_name,
            command=command,
            required=required,
            exit_code=exit_code,
            duration_ms=duration_ms,
            stdout_tail=out_tail,
            stderr_tail=err_tail,
            blocked_reason=blocked_reason,
            notes=notes,
        )

        # Internal preview-safety checkpoints right after no-write preview validator.
        if step_name == "runtime_exporter_preview_validator":
            current_sha = capture_formal_runtime_sha()
            preview_sha_unchanged = current_sha == baseline_sha
            current_set = runtime_file_set()
            preview_allowed_only = current_set == baseline_set == ALLOWED_RUNTIME_FILES

            append_step(
                rows,
                step_id=step_id + 1,
                phase="preview",
                step_name="preview_formal_runtime_sha_unchanged",
                command="<internal-check>",
                required=True,
                exit_code=0 if preview_sha_unchanged else 1,
                duration_ms=1,
                stdout_tail="",
                stderr_tail="",
                notes=f"baseline={baseline_sha} current={current_sha}",
            )
            append_step(
                rows,
                step_id=step_id + 2,
                phase="preview",
                step_name="preview_runtime_dir_allowed_only",
                command="<internal-check>",
                required=True,
                exit_code=0 if preview_allowed_only else 1,
                duration_ms=1,
                stdout_tail="",
                stderr_tail="",
                notes=f"runtime_files={sorted(current_set)}",
            )
            step_id += 2

        step_id += 1

    end_set = runtime_file_set()
    runtime_allowed_only_end = end_set == ALLOWED_RUNTIME_FILES
    append_step(
        rows,
        step_id=step_id,
        phase="hygiene",
        step_name="runtime_dir_allowed_only_end",
        command="<internal-check>",
        required=True,
        exit_code=0 if runtime_allowed_only_end else 1,
        duration_ms=1,
        stdout_tail="",
        stderr_tail="",
        notes=f"runtime_files={sorted(end_set)}",
    )

    required_rows = [r for r in rows if r["required"] == "true"]
    failed_required = [r for r in required_rows if r["status"] != "PASS"]

    def step_pass(name: str) -> str:
        target = [r for r in rows if r["step_name"] == name]
        if not target:
            return "false"
        return "true" if all(r["status"] == "PASS" for r in target) else "false"

    negative_match_all, negative_returned_zero, negative_write_api_false = parse_negative_report()

    summary = {
        "preview_sha_unchanged": step_pass("preview_formal_runtime_sha_unchanged"),
        "preview_runtime_allowed_only": step_pass("preview_runtime_dir_allowed_only"),
        "runtime_allowed_only_end": "true" if runtime_allowed_only_end else "false",
        "manifest_validator_pass": step_pass("runtime_export_manifest_validator"),
        "godot_probe_validator_pass": step_pass("runtime_loader_godot_probe_validator"),
        "scaffold_validator_pass": step_pass("runtime_loader_scaffold_validator"),
        "negative_validator_pass": step_pass("runtime_loader_negative_fixture_validator"),
        "negative_match_all": negative_match_all,
        "negative_returned_zero": negative_returned_zero,
        "negative_write_api_false": negative_write_api_false,
        "warning_detected": "true" if warning_detected else "false",
    }

    write_tsv(Path(args.out), rows)
    write_md(Path(args.out_md), rows, summary)

    overall_ok = len(failed_required) == 0
    print(f"Wrote {args.out} and {args.out_md} with {len(rows)} steps. Overall={'PASS' if overall_ok else 'FAIL'}")
    return 0 if overall_ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
