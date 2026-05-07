#!/usr/bin/env python3
"""验证 battle_reward runtime adapter scaffold 探测结果。"""

from __future__ import annotations

import argparse
import csv
import re
from dataclasses import dataclass, field
from pathlib import Path


REPORT_TSV = Path("data/design/generated_battle_reward_runtime_adapter_scaffold_report.tsv")
REPORT_MD = Path("data/design/generated_battle_reward_runtime_adapter_scaffold_report.md")
RUNTIME_DIR = Path("data/runtime/content_engine")
ALLOWED_RUNTIME_FILES = {
    "battle_reward.json",
    "card_pool.json",
    "runtime_manifest.json",
    "runtime_loader_config.json",
}
REQUIRED_FIELDS = [
    "adapter_file_exists",
    "adapter_class_declared",
    "adapter_resolve_api_present",
    "adapter_referenced_by_main_flow",
    "dangerous_call_count",
    "dangerous_calls",
    "runtime_loader_config_disabled",
    "runtime_battle_reward_exists",
    "runtime_battle_reward_record_count",
    "read_only",
    "formal_data_source_replaced",
    "combat_flow_touched",
    "battle_state_touched",
    "config_enabled",
    "selected_reward_runtime_effective",
    "selected_reward_is_legacy",
    "runtime_only_as_candidate_or_compare",
    "high_risk_modified_count",
    "high_risk_modified_files",
    "formal_reward_source_modified_count",
    "formal_reward_source_modified_files",
    "blocked_reason",
    "notes",
]


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
    parser = argparse.ArgumentParser(description="验证 battle_reward runtime adapter scaffold probe 结果")
    parser.add_argument("--report", default=str(REPORT_TSV))
    parser.add_argument("--report-md", default=str(REPORT_MD))
    return parser.parse_args()


def read_tsv(path: Path) -> list[dict[str, str]]:
    with path.open("r", encoding="utf-8", newline="") as f:
        reader = csv.DictReader(f, delimiter="\t")
        fields = reader.fieldnames or []
        missing = [x for x in REQUIRED_FIELDS if x not in fields]
        if missing:
            raise ValueError(f"报告字段缺失: {', '.join(missing)}")
        return list(reader)


def parse_int(value: str, field_name: str, report: ValidationReport) -> int:
    try:
        return int(value)
    except ValueError:
        report.fail(f"字段 {field_name} 不是整数: {value}")
        return -1


def is_chinese_markdown(path: Path) -> bool:
    text = path.read_text(encoding="utf-8", errors="ignore")
    return len(re.findall(r"[\u4e00-\u9fff]", text)) >= 20


def main() -> int:
    args = parse_args()
    report = ValidationReport()

    report_path = Path(args.report)
    report_md_path = Path(args.report_md)

    if not report_path.exists():
        report.fail(f"缺少 probe 报告: {report_path.as_posix()}")
        print(report.format())
        return 1
    if not report_md_path.exists():
        report.fail(f"缺少 probe Markdown 报告: {report_md_path.as_posix()}")

    rows = read_tsv(report_path)
    if len(rows) != 1:
        report.fail(f"报告行数必须为 1，当前为 {len(rows)}")
        print(report.format())
        return 1
    row = rows[0]

    dangerous_count = parse_int(row["dangerous_call_count"], "dangerous_call_count", report)
    runtime_count = parse_int(row["runtime_battle_reward_record_count"], "runtime_battle_reward_record_count", report)
    high_risk_count = parse_int(row["high_risk_modified_count"], "high_risk_modified_count", report)
    formal_source_count = parse_int(row["formal_reward_source_modified_count"], "formal_reward_source_modified_count", report)

    checks = [
        ("adapter_file_exists", "true", "adapter 文件必须存在"),
        ("adapter_class_declared", "true", "adapter 类声明缺失"),
        ("adapter_resolve_api_present", "true", "resolve_reward 接口缺失"),
        ("adapter_referenced_by_main_flow", "false", "adapter 被正式主流程引用"),
        ("runtime_loader_config_disabled", "true", "runtime_loader_config 必须保持 disabled"),
        ("runtime_battle_reward_exists", "true", "runtime battle_reward.json 必须存在"),
        ("read_only", "true", "adapter 必须保持只读"),
        ("formal_data_source_replaced", "false", "formal_data_source_replaced 必须为 false"),
        ("combat_flow_touched", "false", "combat_flow_touched 必须为 false"),
        ("battle_state_touched", "false", "battle_state_touched 必须为 false"),
        ("config_enabled", "false", "config_enabled 必须为 false"),
        ("selected_reward_runtime_effective", "false", "selected_reward_runtime_effective 必须为 false"),
        ("selected_reward_is_legacy", "true", "selected_reward 必须保持 legacy"),
        ("runtime_only_as_candidate_or_compare", "true", "runtime 只能做候选/对比"),
    ]

    for field, expected, fail_msg in checks:
        if row.get(field, "") != expected:
            report.fail(f"{fail_msg}（{field}={row.get(field, '')}）")

    if dangerous_count != 0:
        report.fail(f"adapter 存在危险调用: {row.get('dangerous_calls', '')}")
    if runtime_count != 45:
        report.fail(f"runtime battle_reward 记录数必须为 45，当前为 {runtime_count}")
    if high_risk_count != 0:
        report.fail(f"检测到高风险文件变更: {row.get('high_risk_modified_files', '')}")
    if formal_source_count != 0:
        report.fail(f"检测到正式奖励源变更: {row.get('formal_reward_source_modified_files', '')}")

    runtime_files = {p.name for p in RUNTIME_DIR.iterdir() if p.is_file()} if RUNTIME_DIR.exists() else set()
    if runtime_files != ALLOWED_RUNTIME_FILES:
        report.fail(f"runtime 目录文件不合法: expected={sorted(ALLOWED_RUNTIME_FILES)} actual={sorted(runtime_files)}")
    else:
        report.pass_("runtime 目录白名单校验通过")

    if not is_chinese_markdown(report_md_path):
        report.fail("probe Markdown 报告中文说明不足")
    else:
        report.pass_("probe Markdown 中文说明校验通过")

    print(report.format())
    return 0 if report.ok() else 1


if __name__ == "__main__":
    raise SystemExit(main())
