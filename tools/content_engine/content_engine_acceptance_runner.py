#!/usr/bin/env python3
"""v1.0d-prep 一键交付验收执行器。"""

from __future__ import annotations

import argparse
import csv
import subprocess
import time
from pathlib import Path

REPORT_TSV = Path("data/design/generated_content_engine_acceptance_report.tsv")
REPORT_MD = Path("data/design/generated_content_engine_acceptance_report.md")
FIELDS = ["step_id", "step_name", "command", "exit_code", "status", "duration_ms", "severity", "detail"]
GODOT_STEPS = {"godot_headless_quit", "godot_headless_mainvisual"}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="运行 content engine 交付级验收。")
    parser.add_argument("--out", default=str(REPORT_TSV))
    parser.add_argument("--out-md", default=str(REPORT_MD))
    return parser.parse_args()


def tail_text(text: str, max_lines: int = 24, max_chars: int = 2000) -> str:
    clipped = "\n".join(text.splitlines()[-max_lines:])
    return clipped[-max_chars:].strip()


def has_non_blocking_godot_warning(output: str) -> bool:
    lower = output.lower()
    return ("objectdb" in lower) or ("rid" in output) or ("resource" in lower and "leak" in lower) or ("warning:" in lower)


def run_step(step_id: int, step_name: str, command: str) -> tuple[dict[str, str], str]:
    started = time.time()
    proc = subprocess.run(command, shell=True, capture_output=True, text=True)
    duration_ms = int((time.time() - started) * 1000)
    combined = ((proc.stdout or "") + "\n" + (proc.stderr or "")).strip()

    if proc.returncode != 0:
        status = "FAIL"
        severity = "blocking"
    else:
        if step_name in GODOT_STEPS and has_non_blocking_godot_warning(combined):
            status = "NON_BLOCKING_WARNING"
            severity = "non_blocking"
        else:
            status = "PASS"
            severity = "blocking"

    row = {
        "step_id": str(step_id),
        "step_name": step_name,
        "command": command,
        "exit_code": str(proc.returncode),
        "status": status,
        "duration_ms": str(duration_ms),
        "severity": severity,
        "detail": tail_text(combined) or "none",
    }
    return row, combined


def write_tsv(path: Path, rows: list[dict[str, str]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=FIELDS, delimiter="\t", lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)


def write_md(path: Path, rows: list[dict[str, str]]) -> None:
    blocking_fail = [r for r in rows if r["severity"] == "blocking" and r["status"] != "PASS"]
    warning_count = sum(1 for r in rows if r["status"] == "NON_BLOCKING_WARNING")
    acceptance_status = "PASS" if not blocking_fail else "FAIL"

    lines = [
        "# Content Engine 交付验收报告",
        "",
        f"- acceptance_status={acceptance_status}",
        f"- blocking_fail_count={len(blocking_fail)}",
        f"- non_blocking_warning_count={warning_count}",
        "",
        "## 步骤明细",
        "",
        "| step_id | step_name | exit_code | status | duration_ms | severity |",
        "|---|---|---|---|---|---|",
    ]
    for row in rows:
        lines.append(
            f"| {row['step_id']} | {row['step_name']} | {row['exit_code']} | {row['status']} | {row['duration_ms']} | {row['severity']} |"
        )

    lines.extend(
        [
            "",
            "## 说明",
            "",
            "- 本报告用于 v1.0d-prep 交付验收，不改变任何正式奖励流程。",
            "- Godot 在退出码为 0 时出现 RID/ObjectDB/resource leak warning，按 non-blocking hygiene issue 记录。",
            "- 仅 blocking 失败会使 acceptance_status 失败。",
            "",
        ]
    )
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(lines), encoding="utf-8")


def main() -> int:
    args = parse_args()
    steps = [
        ("content_engine_check", "python3 tools/content_engine/content_engine_check.py"),
        ("content_engine_regression_runner", "python3 tools/content_engine/content_engine_regression_runner.py"),
        ("content_engine_regression_validator", "python3 tools/content_engine/content_engine_regression_validator.py"),
        ("git_diff_check", "git diff --check"),
        ("godot_headless_quit", "godot --headless --path . --quit"),
        ("godot_headless_mainvisual", "godot --headless --path . --quit scenes/MainVisual.tscn"),
    ]

    rows: list[dict[str, str]] = []
    for idx, (name, cmd) in enumerate(steps, start=1):
        row, _ = run_step(idx, name, cmd)
        rows.append(row)

    write_tsv(Path(args.out), rows)
    write_md(Path(args.out_md), rows)

    blocking_fail = [r for r in rows if r["severity"] == "blocking" and r["status"] != "PASS"]
    print(f"Wrote {args.out} and {args.out_md}. acceptance_status={'PASS' if not blocking_fail else 'FAIL'}")
    return 0 if not blocking_fail else 1


if __name__ == "__main__":
    raise SystemExit(main())
