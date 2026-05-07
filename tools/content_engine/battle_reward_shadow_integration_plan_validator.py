#!/usr/bin/env python3
"""验证 battle_reward shadow integration plan 探测报告。"""

from __future__ import annotations

import argparse
import csv
import re
from dataclasses import dataclass, field
from pathlib import Path


REPORT_TSV = Path("data/design/generated_battle_reward_shadow_integration_plan_report.tsv")
REPORT_MD = Path("data/design/generated_battle_reward_shadow_integration_plan_report.md")
PLAN_MD = Path("docs/BATTLE_REWARD_SHADOW_INTEGRATION_PLAN.md")
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
    parser = argparse.ArgumentParser(description="验证 battle_reward shadow integration plan")
    parser.add_argument("--report", default=str(REPORT_TSV))
    parser.add_argument("--report-md", default=str(REPORT_MD))
    parser.add_argument("--plan", default=str(PLAN_MD))
    return parser.parse_args()


def read_tsv(path: Path) -> list[dict[str, str]]:
    with path.open("r", encoding="utf-8", newline="") as f:
        return list(csv.DictReader(f, delimiter="\t"))


def is_chinese_md(path: Path) -> bool:
    txt = path.read_text(encoding="utf-8", errors="ignore")
    return len(re.findall(r"[\u4e00-\u9fff]", txt)) >= 30


def pick_latest_check(rows: list[dict[str, str]], check_id: str) -> dict[str, str] | None:
    matches = [r for r in rows if r.get("check_id", "") == check_id]
    return matches[-1] if matches else None


def require_pass(rows: list[dict[str, str]], report: ValidationReport, check_id: str, message: str) -> None:
    row = pick_latest_check(rows, check_id)
    if row is None:
        report.fail(f"缺少检查项 {check_id}：{message}")
        return
    if row.get("status") != "PASS":
        report.fail(f"检查项 {check_id} 未通过：{message}；actual={row.get('actual', '')}")
    else:
        report.pass_(f"{check_id} 通过")


def require_actual_equals(rows: list[dict[str, str]], report: ValidationReport, check_id: str, expected: str, message: str) -> None:
    row = pick_latest_check(rows, check_id)
    if row is None:
        report.fail(f"缺少检查项 {check_id}：{message}")
        return
    actual = row.get("actual", "")
    if actual != expected:
        report.fail(f"{check_id} 实际值异常：期望 {expected}，实际 {actual}；{message}")
    else:
        report.pass_(f"{check_id}={expected}")


def require_actual_in_set(rows: list[dict[str, str]], report: ValidationReport, check_id: str, allowed: set[str], message: str) -> None:
    row = pick_latest_check(rows, check_id)
    if row is None:
        report.fail(f"缺少检查项 {check_id}：{message}")
        return
    actual = row.get("actual", "")
    if actual not in allowed:
        report.fail(f"{check_id} 实际值异常：允许 {sorted(allowed)}，实际 {actual}；{message}")
    else:
        report.pass_(f"{check_id}={actual}")


def main() -> int:
    args = parse_args()
    report = ValidationReport()

    report_path = Path(args.report)
    report_md_path = Path(args.report_md)
    plan_path = Path(args.plan)

    if not report_path.exists():
        report.fail(f"缺少 probe 报告：{report_path.as_posix()}")
        print(report.format())
        return 1
    if not report_md_path.exists():
        report.fail(f"缺少 probe Markdown 报告：{report_md_path.as_posix()}")
    if not plan_path.exists():
        report.fail(f"缺少 shadow 设计文档：{plan_path.as_posix()}")

    rows = read_tsv(report_path)
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

    if not is_chinese_md(report_md_path):
        report.fail("shadow probe Markdown 中文说明约束未通过")
    else:
        report.pass_("shadow probe Markdown 中文说明约束通过")
    if plan_path.exists() and not is_chinese_md(plan_path):
        report.fail("shadow 设计文档中文说明约束未通过")
    elif plan_path.exists():
        report.pass_("shadow 设计文档中文说明约束通过")

    require_pass(rows, report, "runtime_loader_config_disabled", "runtime_loader_config_disabled=true")
    require_actual_equals(rows, report, "adapter_formal_flow_reference_count", "0", "adapter_formal_flow_reference_count=0")
    require_actual_in_set(rows, report, "canonical_controller_adapter_reference_count", {"0", "1", "2", "3", "4"}, "canonical_controller_adapter_reference_count 允许 v1.0c 最小接入引用")

    plan_text = plan_path.read_text(encoding="utf-8", errors="ignore") if plan_path.exists() else ""
    design_checks = [
        ("selected_reward_source_design", "selected_reward 必须来自 legacy"),
        ("runtime_reward_effective_design", "runtime_reward_effective=false"),
        ("formal_data_source_replaced_design", "不替换正式奖励源"),
        ("combat_flow_touched_design", "不修改 combat_result"),
        ("battle_state_touched_design", "不修改 battle_state"),
    ]
    for check_id, phrase in design_checks:
        ok = phrase in plan_text
        if not ok:
            report.fail(f"{check_id} 未满足：文档缺少“{phrase}”")
        else:
            report.pass_(f"{check_id} 通过")

    require_actual_equals(rows, report, "high_risk_files_touched", "false", "high_risk_files_touched=false")
    require_actual_equals(rows, report, "runtime_dir_whitelist_status", "pass", "runtime_dir_whitelist_status=pass")
    require_actual_equals(rows, report, "battle_reward_runtime_record_count", "45", "battle_reward_runtime_record_count=45")

    runtime_files = {p.name for p in RUNTIME_DIR.iterdir() if p.is_file()} if RUNTIME_DIR.exists() else set()
    if runtime_files != ALLOWED_RUNTIME_FILES:
        report.fail(f"runtime 目录白名单校验失败：expected={sorted(ALLOWED_RUNTIME_FILES)} actual={sorted(runtime_files)}")
    else:
        report.pass_("runtime 目录白名单复核通过")

    print(report.format())
    return 0 if report.ok() else 1


if __name__ == "__main__":
    raise SystemExit(main())
