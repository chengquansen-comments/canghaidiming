#!/usr/bin/env python3
"""验证 v1.0d-prep 一键交付验收报告。"""

from __future__ import annotations

import argparse
import csv
import re
from dataclasses import dataclass, field
from pathlib import Path

REPORT_TSV = Path("data/design/generated_content_engine_acceptance_report.tsv")
REPORT_MD = Path("data/design/generated_content_engine_acceptance_report.md")
REQUIRED_STEPS = {
    "content_engine_check": "python3 tools/content_engine/content_engine_check.py",
    "content_engine_regression_runner": "python3 tools/content_engine/content_engine_regression_runner.py",
    "content_engine_regression_validator": "python3 tools/content_engine/content_engine_regression_validator.py",
    "git_diff_check": "git diff --check",
    "godot_headless_quit": "godot --headless --path . --quit",
    "godot_headless_mainvisual": "godot --headless --path . --quit scenes/MainVisual.tscn",
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


def is_chinese_md(path: Path) -> bool:
    text = path.read_text(encoding="utf-8", errors="ignore")
    return len(re.findall(r"[\u4e00-\u9fff]", text)) >= 30


def read_rows(path: Path) -> list[dict[str, str]]:
    with path.open("r", encoding="utf-8", newline="") as f:
        return list(csv.DictReader(f, delimiter="\t"))


def main() -> int:
    parser = argparse.ArgumentParser(description="验证 content engine acceptance report")
    parser.add_argument("--report", default=str(REPORT_TSV))
    parser.add_argument("--report-md", default=str(REPORT_MD))
    args = parser.parse_args()

    report = ValidationReport()
    tsv = Path(args.report)
    md = Path(args.report_md)

    if not tsv.exists():
        report.fail(f"缺少 acceptance TSV 报告：{tsv.as_posix()}")
        print(report.format())
        return 1
    if not md.exists():
        report.fail(f"缺少 acceptance Markdown 报告：{md.as_posix()}")

    rows = read_rows(tsv)
    if not rows:
        report.fail("acceptance TSV 报告为空")
        print(report.format())
        return 1

    by_name = {r.get("step_name", ""): r for r in rows}
    for step_name, command in REQUIRED_STEPS.items():
        row = by_name.get(step_name)
        if row is None:
            report.fail(f"acceptance 报告缺少步骤：{step_name}")
            continue
        if row.get("command") != command:
            report.fail(f"步骤命令不匹配：{step_name}，期望 `{command}`，实际 `{row.get('command','')}`")
            continue
        exit_code = row.get("exit_code", "")
        status = row.get("status", "")
        severity = row.get("severity", "")
        if exit_code != "0":
            report.fail(f"步骤退出码非 0：{step_name} exit_code={exit_code}")
            continue
        if severity == "blocking" and status != "PASS":
            report.fail(f"blocking 步骤必须 PASS：{step_name} status={status}")
        else:
            report.pass_(f"步骤通过：{step_name}")

    for row in rows:
        step = row.get("step_name", "")
        status = row.get("status", "")
        severity = row.get("severity", "")
        if status == "NON_BLOCKING_WARNING":
            if not step.startswith("godot_headless") or severity != "non_blocking":
                report.fail(f"non-blocking warning 范围非法：{step} severity={severity}")
            else:
                report.pass_(f"Godot warning 正确归类为 non-blocking：{step}")
        if row.get("exit_code") != "0" and status != "FAIL":
            report.fail(f"exit_code 非 0 时状态必须 FAIL：{step}")

    blocking_fail = [r for r in rows if r.get("severity") == "blocking" and r.get("status") != "PASS"]
    if blocking_fail:
        report.fail("存在 blocking 失败步骤，不满足 acceptance 要求")
    else:
        report.pass_("所有 blocking 步骤均 PASS")

    if md.exists() and not is_chinese_md(md):
        report.fail("acceptance Markdown 中文说明约束未通过")
    elif md.exists():
        report.pass_("acceptance Markdown 中文说明约束通过")

    print(report.format())
    return 0 if report.ok() else 1


if __name__ == "__main__":
    raise SystemExit(main())
