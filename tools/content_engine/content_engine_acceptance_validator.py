#!/usr/bin/env python3
"""验证 v1.0d-final 一键交付验收报告（Determinism Hardening）。"""

from __future__ import annotations

import argparse
import csv
import re
from dataclasses import dataclass, field
from pathlib import Path

REPORT_TSV = Path("data/design/generated_content_engine_acceptance_report.tsv")
REPORT_MD = Path("data/design/generated_content_engine_acceptance_report.md")
SUMMARY_TSV = Path("data/design/generated_content_engine_acceptance_summary.tsv")
SUMMARY_MD = Path("data/design/generated_content_engine_acceptance_summary.md")

REQUIRED_CHECK_IDS = {
    "battle_reward_shadow_freeze_probe",
    "battle_reward_shadow_freeze_validator",
    "battle_reward_runtime_test_harness",
    "battle_reward_runtime_test_harness_validator",
    "full_preview_readonly_probe_py",
    "full_preview_readonly_probe_godot",
    "full_preview_readonly_validator",
    "full_package_shadow_compare_probe",
    "full_package_shadow_compare_validator",
    "full_package_candidate_path_probe",
    "full_package_candidate_path_validator",
    "full_package_whitelist_test_enable_probe",
    "full_package_whitelist_test_enable_validator",
    "full_package_runtime_readiness_audit",
    "full_package_runtime_readiness_validator",
    "content_engine_regression_runner",
    "content_engine_regression_validator",
}
ALLOWED_SUMMARY_STATUS_PREFIX = ("pass", "missing_report", "empty_report", "stale_report", "invalid_report", "PASS", "FAIL")


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


def is_non_empty_file(path: Path) -> bool:
    return path.exists() and path.is_file() and path.stat().st_size > 0


def main() -> int:
    parser = argparse.ArgumentParser(description="验证 content engine acceptance summary")
    parser.add_argument("--report", default=str(REPORT_TSV))
    parser.add_argument("--report-md", default=str(REPORT_MD))
    parser.add_argument("--summary", default=str(SUMMARY_TSV))
    parser.add_argument("--summary-md", default=str(SUMMARY_MD))
    args = parser.parse_args()

    report = ValidationReport()
    report_tsv = Path(args.report)
    report_md = Path(args.report_md)
    summary_tsv = Path(args.summary)
    summary_md = Path(args.summary_md)

    # 优先使用 summary 作为主入口
    for path, label in [
        (summary_tsv, "acceptance summary TSV"),
        (summary_md, "acceptance summary Markdown"),
        (report_tsv, "acceptance step TSV"),
        (report_md, "acceptance step Markdown"),
    ]:
        if not path.exists():
            report.fail(f"missing_report: 缺少 {label}：{path.as_posix()}")
        elif not is_non_empty_file(path):
            report.fail(f"empty_report: 空文件 {label}：{path.as_posix()}")
        else:
            report.pass_(f"{label} 存在且非空")

    if report.failures:
        print(report.format())
        return 1

    summary_rows = read_rows(summary_tsv)
    step_rows = read_rows(report_tsv)

    if not summary_rows:
        report.fail("empty_report: acceptance summary TSV 无内容")
        print(report.format())
        return 1
    if not step_rows:
        report.fail("empty_report: acceptance step TSV 无内容")
        print(report.format())
        return 1

    run_ids = {row.get("run_id", "") for row in summary_rows if row.get("run_id", "")}
    if len(run_ids) != 1:
        report.fail(f"invalid_report: summary run_id 不唯一，count={len(run_ids)}")
        print(report.format())
        return 1
    run_id = next(iter(run_ids))
    report.pass_(f"summary run_id 唯一：{run_id}")

    step_run_ids = {row.get("run_id", "") for row in step_rows if row.get("run_id", "")}
    if step_run_ids != {run_id}:
        report.fail(f"stale_report: step report run_id 与 summary 不一致，summary={run_id} step={sorted(step_run_ids)}")
    else:
        report.pass_("step report run_id 与 summary 一致")

    check_ids = {row.get("check_id", "") for row in summary_rows}
    missing_checks = sorted(REQUIRED_CHECK_IDS - check_ids)
    if missing_checks:
        report.fail(f"invalid_report: summary 缺少 check_id：{missing_checks}")
    else:
        report.pass_("summary 覆盖全部 required check_id")

    # 校验每个 summary 记录的状态与文件状态一致
    for row in summary_rows:
        status = row.get("status", "")
        if not status.startswith(ALLOWED_SUMMARY_STATUS_PREFIX):
            report.fail(f"invalid_report: 未知 summary 状态 `{status}` check_id={row.get('check_id','')}")
            continue

        report_path = row.get("required_report_path", "none")
        exists = row.get("report_exists", "")
        non_empty = row.get("report_non_empty", "")
        row_run_id = row.get("report_run_id", "")

        if row_run_id != run_id:
            report.fail(f"stale_report: report_run_id 不匹配 check_id={row.get('check_id','')} expected={run_id} actual={row_run_id}")

        if report_path == "none":
            if status not in {"PASS", "pass"}:
                report.fail(f"invalid_report: validator 步骤状态异常 check_id={row.get('check_id','')} status={status}")
            continue

        p = Path(report_path)
        real_exists = p.exists() and p.is_file()
        real_non_empty = real_exists and p.stat().st_size > 0

        if exists != ("true" if real_exists else "false"):
            report.fail(f"invalid_report: report_exists 不一致 path={report_path}")
        if non_empty != ("true" if real_non_empty else "false"):
            report.fail(f"invalid_report: report_non_empty 不一致 path={report_path}")

        if status == "missing_report":
            report.fail(f"missing_report: {report_path}")
        elif status == "empty_report":
            report.fail(f"empty_report: {report_path}")
        elif status == "stale_report":
            report.fail(f"stale_report: {report_path}")
        elif status.startswith("invalid_report"):
            report.fail(f"invalid_report: {report_path} ({status})")
        elif status == "pass":
            report.pass_(f"pass: {report_path}")
        elif status in {"PASS", "FAIL"}:
            report.pass_(f"step_status: {row.get('check_id','')}={status}")

    # 必须保证关键边界仍通过（来自对应子报告）
    freeze_report = Path("data/design/generated_battle_reward_shadow_freeze_report.tsv")
    if freeze_report.exists() and freeze_report.stat().st_size > 0:
        rows = read_rows(freeze_report)
        idx = {r.get("check_id", ""): r for r in rows}
        for key, expected in [
            ("shadow_freeze_status", "pass"),
            ("selected_reward_source", "legacy"),
            ("selected_reward_runtime_effective", "false"),
            ("runtime_reward_candidate_only", "true"),
            ("runtime_loader_config_disabled", "true"),
            ("runtime_dir_whitelist_status", "pass"),
        ]:
            actual = idx.get(key, {}).get("actual")
            if actual != expected:
                report.fail(f"invalid_report: shadow freeze 约束失败 {key} expected={expected} actual={actual}")
            else:
                report.pass_(f"shadow freeze 约束通过 {key}={expected}")

    harness_report = Path("data/design/generated_battle_reward_runtime_test_harness_report.tsv")
    if harness_report.exists() and harness_report.stat().st_size > 0:
        rows = read_rows(harness_report)
        summary_values = {
            r.get("reward_id", ""): r.get("runtime_candidate_status", "")
            for r in rows
            if r.get("record_type") == "summary_value"
        }
        for key, expected in [
            ("formal_selected_source", "legacy"),
            ("formal_runtime_effective", "false"),
            ("formal_flow_touched", "false"),
            ("runtime_dir_modified", "false"),
            ("formal_data_source_replaced", "false"),
        ]:
            actual = summary_values.get(key)
            if actual != expected:
                report.fail(f"invalid_report: harness 约束失败 {key} expected={expected} actual={actual}")
            else:
                report.pass_(f"harness 约束通过 {key}={expected}")

    if not is_chinese_md(summary_md):
        report.fail("invalid_report: acceptance summary Markdown 中文说明约束未通过")
    else:
        report.pass_("acceptance summary Markdown 中文说明约束通过")

    if not is_chinese_md(report_md):
        report.fail("invalid_report: acceptance step Markdown 中文说明约束未通过")
    else:
        report.pass_("acceptance step Markdown 中文说明约束通过")

    print(report.format())
    return 0 if report.ok() else 1


if __name__ == "__main__":
    raise SystemExit(main())
