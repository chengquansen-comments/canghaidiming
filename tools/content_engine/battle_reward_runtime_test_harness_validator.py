#!/usr/bin/env python3
"""验证 v1.0d-prep runtime_test harness 报告。"""

from __future__ import annotations

import argparse
import csv
import re
from dataclasses import dataclass, field
from pathlib import Path

REPORT_TSV = Path("data/design/generated_battle_reward_runtime_test_harness_report.tsv")
REPORT_MD = Path("data/design/generated_battle_reward_runtime_test_harness_report.md")
DOC_MD = Path("docs/BATTLE_REWARD_RUNTIME_TEST_PLAN.md")


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


def read_rows(path: Path) -> list[dict[str, str]]:
    with path.open("r", encoding="utf-8", newline="") as f:
        return list(csv.DictReader(f, delimiter="\t"))


def is_chinese_md(path: Path) -> bool:
    txt = path.read_text(encoding="utf-8", errors="ignore")
    return len(re.findall(r"[\u4e00-\u9fff]", txt)) >= 30


def get_summary_values(rows: list[dict[str, str]]) -> dict[str, str]:
    summary: dict[str, str] = {}
    for row in rows:
        if row.get("record_type") == "summary_value":
            summary[row.get("reward_id", "")] = row.get("runtime_candidate_status", "")
    return summary


def main() -> int:
    parser = argparse.ArgumentParser(description="验证 runtime test harness")
    parser.add_argument("--report", default=str(REPORT_TSV))
    parser.add_argument("--report-md", default=str(REPORT_MD))
    parser.add_argument("--doc", default=str(DOC_MD))
    args = parser.parse_args()

    report = ValidationReport()
    tsv = Path(args.report)
    md = Path(args.report_md)
    doc = Path(args.doc)

    if not tsv.exists():
        report.fail(f"缺少 harness TSV 报告：{tsv.as_posix()}")
        print(report.format())
        return 1
    if not md.exists():
        report.fail(f"缺少 harness Markdown 报告：{md.as_posix()}")
    if not doc.exists():
        report.fail(f"缺少 runtime_test 设计文档：{doc.as_posix()}")

    rows = read_rows(tsv)
    if not rows:
        report.fail("harness TSV 报告为空")
        print(report.format())
        return 1

    blocking_fail = [r for r in rows if r.get("severity") == "blocking" and r.get("status") != "PASS"]
    if blocking_fail:
        sample = "; ".join(f"{r.get('record_type')}:{r.get('detail')}" for r in blocking_fail[:8])
        report.fail(f"存在 blocking 失败项：{sample}")
    else:
        report.pass_("所有 blocking 项通过")

    summary = get_summary_values(rows)
    expected = {
        "runtime_test_harness_status": "pass",
        "runtime_test_harness_mode": "true",
        "runtime_loader_config_still_disabled": "true",
        "battle_reward_runtime_record_count": "45",
        "harness_runtime_candidate_readable": "true",
        "formal_selected_source": "legacy",
        "formal_runtime_effective": "false",
        "formal_flow_touched": "false",
        "runtime_dir_modified": "false",
        "formal_data_source_replaced": "false",
    }
    for key, value in expected.items():
        actual = summary.get(key)
        if actual != value:
            report.fail(f"{key} 不符合预期：期望 {value}，实际 {actual}")
        else:
            report.pass_(f"{key}={value}")

    if md.exists() and not is_chinese_md(md):
        report.fail("harness Markdown 中文说明约束未通过")
    elif md.exists():
        report.pass_("harness Markdown 中文说明约束通过")

    if doc.exists() and not is_chinese_md(doc):
        report.fail("runtime_test 文档中文说明约束未通过")
    elif doc.exists():
        report.pass_("runtime_test 文档中文说明约束通过")

    print(report.format())
    return 0 if report.ok() else 1


if __name__ == "__main__":
    raise SystemExit(main())
