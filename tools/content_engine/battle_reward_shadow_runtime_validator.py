#!/usr/bin/env python3
"""验证 battle_reward shadow runtime 探测报告。"""

from __future__ import annotations

import argparse
import csv
import re
from dataclasses import dataclass, field
from pathlib import Path


REPORT_TSV = Path("data/design/generated_battle_reward_shadow_runtime_report.tsv")
REPORT_MD = Path("data/design/generated_battle_reward_shadow_runtime_report.md")
DOC_MD = Path("docs/BATTLE_REWARD_SHADOW_RUNTIME.md")
RUNTIME_DIR = Path("data/runtime/content_engine")
ALLOWED_RUNTIME_FILES = {
    "battle_reward.json",
    "card_pool.json",
    "runtime_manifest.json",
    "runtime_loader_config.json",
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


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="验证 battle_reward shadow runtime")
    parser.add_argument("--report", default=str(REPORT_TSV))
    parser.add_argument("--report-md", default=str(REPORT_MD))
    parser.add_argument("--doc", default=str(DOC_MD))
    return parser.parse_args()


def read_rows(path: Path) -> list[dict[str, str]]:
    with path.open("r", encoding="utf-8", newline="") as f:
        return list(csv.DictReader(f, delimiter="\t"))


def get_row(rows: list[dict[str, str]], check_id: str) -> dict[str, str] | None:
    matches = [r for r in rows if r.get("check_id") == check_id]
    return matches[-1] if matches else None


def require_status_pass(rows: list[dict[str, str]], report: ValidationReport, check_id: str, hint: str) -> None:
    row = get_row(rows, check_id)
    if row is None:
        report.fail(f"缺少检查项 {check_id}：{hint}")
        return
    if row.get("status") != "PASS":
        report.fail(f"{check_id} 未通过：{hint}；actual={row.get('actual','')}")
    else:
        report.pass_(f"{check_id} 通过")


def require_actual(rows: list[dict[str, str]], report: ValidationReport, check_id: str, expected: str, hint: str) -> None:
    row = get_row(rows, check_id)
    if row is None:
        report.fail(f"缺少检查项 {check_id}：{hint}")
        return
    actual = row.get("actual", "")
    if actual != expected:
        report.fail(f"{check_id} 实际值不符：期望 {expected}，实际 {actual}；{hint}")
    else:
        report.pass_(f"{check_id}={expected}")


def is_chinese_md(path: Path) -> bool:
    txt = path.read_text(encoding="utf-8", errors="ignore")
    return len(re.findall(r"[\u4e00-\u9fff]", txt)) >= 30


def main() -> int:
    args = parse_args()
    report = ValidationReport()

    report_path = Path(args.report)
    report_md_path = Path(args.report_md)
    doc_path = Path(args.doc)

    if not report_path.exists():
        report.fail(f"缺少 probe 报告：{report_path.as_posix()}")
        print(report.format())
        return 1
    if not report_md_path.exists():
        report.fail(f"缺少 probe Markdown 报告：{report_md_path.as_posix()}")
    if not doc_path.exists():
        report.fail(f"缺少 shadow 运行文档：{doc_path.as_posix()}")

    rows = read_rows(report_path)
    if not rows:
        report.fail("probe 报告为空")
        print(report.format())
        return 1

    blocking_fail = [r for r in rows if r.get("severity") == "blocking" and r.get("status") != "PASS"]
    if blocking_fail:
        sample = "; ".join(f"{r.get('check_id')}={r.get('actual')}" for r in blocking_fail[:5])
        report.fail(f"存在 blocking 失败项：{sample}")
    else:
        report.pass_("所有 blocking 项通过")

    if report_md_path.exists() and not is_chinese_md(report_md_path):
        report.fail("shadow runtime probe Markdown 中文说明约束未通过")
    elif report_md_path.exists():
        report.pass_("shadow runtime probe Markdown 中文说明约束通过")
    if doc_path.exists() and not is_chinese_md(doc_path):
        report.fail("shadow runtime 文档中文说明约束未通过")
    elif doc_path.exists():
        report.pass_("shadow runtime 文档中文说明约束通过")

    require_status_pass(rows, report, "shadow_integration_present", "shadow_integration_present=true")
    require_actual(rows, report, "shadow_integration_file", "scripts/narrative_demo_canonical_controller.gd", "shadow 接入文件必须是 canonical")
    require_actual(rows, report, "shadow_integration_function", "_battle_reward_for_source", "shadow 接入函数必须是 _battle_reward_for_source")
    require_actual(rows, report, "adapter_formal_flow_reference_count", "0", "adapter 不能在未授权文件引用")

    require_actual(rows, report, "selected_reward_source", "legacy", "selected_reward_source=legacy")
    require_actual(rows, report, "selected_reward_runtime_effective", "false", "selected_reward_runtime_effective=false")
    require_status_pass(rows, report, "runtime_reward_candidate_only", "runtime_reward_candidate_only=true")

    require_actual(rows, report, "formal_data_source_replaced", "false", "formal_data_source_replaced=false")
    require_status_pass(rows, report, "runtime_loader_config_disabled", "runtime_loader_config_disabled=true")
    require_actual(rows, report, "battle_state_touched", "false", "battle_state_touched=false")
    require_actual(rows, report, "combat_result_touched", "false", "combat_result_touched=false")
    require_actual(rows, report, "high_risk_files_touched", "false", "high_risk_files_touched=false")
    require_actual(rows, report, "runtime_dir_whitelist_status", "pass", "runtime_dir_whitelist_status=pass")
    require_actual(rows, report, "battle_reward_runtime_record_count", "45", "battle_reward_runtime_record_count=45")
    require_actual(rows, report, "shadow_region_dangerous_call_count", "0", "shadow 接入区域禁止危险调用")

    runtime_files = {p.name for p in RUNTIME_DIR.iterdir() if p.is_file()} if RUNTIME_DIR.exists() else set()
    if runtime_files != ALLOWED_RUNTIME_FILES:
        report.fail(f"runtime 目录白名单不匹配：expected={sorted(ALLOWED_RUNTIME_FILES)} actual={sorted(runtime_files)}")
    else:
        report.pass_("runtime 目录白名单复核通过")

    print(report.format())
    return 0 if report.ok() else 1


if __name__ == "__main__":
    raise SystemExit(main())
