#!/usr/bin/env python3
"""验证 v1.0d-prep battle_reward shadow freeze 探测报告。"""

from __future__ import annotations

import argparse
import csv
import re
from dataclasses import dataclass, field
from pathlib import Path

REPORT_TSV = Path("data/design/generated_battle_reward_shadow_freeze_report.tsv")
REPORT_MD = Path("data/design/generated_battle_reward_shadow_freeze_report.md")
DOC_MD = Path("docs/BATTLE_REWARD_SHADOW_FREEZE.md")


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


def row_by_id(rows: list[dict[str, str]]) -> dict[str, dict[str, str]]:
    result: dict[str, dict[str, str]] = {}
    for row in rows:
        check_id = row.get("check_id", "")
        if check_id:
            result[check_id] = row
    return result


def require_actual(index: dict[str, dict[str, str]], report: ValidationReport, key: str, expected: str) -> None:
    row = index.get(key)
    if row is None:
        report.fail(f"缺少检查项：{key}")
        return
    actual = row.get("actual", "")
    if actual != expected:
        report.fail(f"{key} 不符合预期：期望 {expected}，实际 {actual}")
    else:
        report.pass_(f"{key}={expected}")


def main() -> int:
    parser = argparse.ArgumentParser(description="验证 battle_reward shadow freeze")
    parser.add_argument("--report", default=str(REPORT_TSV))
    parser.add_argument("--report-md", default=str(REPORT_MD))
    parser.add_argument("--doc", default=str(DOC_MD))
    args = parser.parse_args()

    report = ValidationReport()
    tsv = Path(args.report)
    md = Path(args.report_md)
    doc = Path(args.doc)

    if not tsv.exists():
        report.fail(f"缺少 freeze probe 报告：{tsv.as_posix()}")
        print(report.format())
        return 1
    if not md.exists():
        report.fail(f"缺少 freeze probe Markdown：{md.as_posix()}")
    if not doc.exists():
        report.fail(f"缺少 freeze 说明文档：{doc.as_posix()}")

    rows = read_rows(tsv)
    if not rows:
        report.fail("freeze probe 报告为空")
        print(report.format())
        return 1

    blocking_fail = [r for r in rows if r.get("severity") == "blocking" and r.get("status") != "PASS"]
    if blocking_fail:
        sample = "; ".join(f"{r.get('check_id')}={r.get('actual')}" for r in blocking_fail[:8])
        report.fail(f"存在 blocking 失败项：{sample}")
    else:
        report.pass_("所有 blocking 项通过")

    if md.exists() and not is_chinese_md(md):
        report.fail("freeze probe Markdown 中文说明约束未通过")
    elif md.exists():
        report.pass_("freeze probe Markdown 中文说明约束通过")

    if doc.exists() and not is_chinese_md(doc):
        report.fail("freeze 文档中文说明约束未通过")
    elif doc.exists():
        report.pass_("freeze 文档中文说明约束通过")

    index = row_by_id(rows)
    require_actual(index, report, "shadow_freeze_status", "pass")
    require_actual(index, report, "selected_reward_source", "legacy")
    require_actual(index, report, "selected_reward_runtime_effective", "false")
    require_actual(index, report, "runtime_reward_candidate_only", "true")
    require_actual(index, report, "runtime_loader_config_disabled", "true")
    require_actual(index, report, "formal_data_source_replaced", "false")
    require_actual(index, report, "high_risk_files_touched", "false")
    require_actual(index, report, "runtime_dir_whitelist_status", "pass")
    require_actual(index, report, "battle_reward_runtime_record_count", "45")

    print(report.format())
    return 0 if report.ok() else 1


if __name__ == "__main__":
    raise SystemExit(main())
