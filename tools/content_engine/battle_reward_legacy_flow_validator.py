#!/usr/bin/env python3
"""验证 battle_reward 旧流程定位报告与 v1.0a 约束边界。"""

from __future__ import annotations

import argparse
import csv
import json
import re
import subprocess
import sys
from dataclasses import dataclass, field
from pathlib import Path


REPORT_TSV = Path("data/design/generated_battle_reward_legacy_flow_report.tsv")
REPORT_MD = Path("data/design/generated_battle_reward_legacy_flow_report.md")
PLAN_MD = Path("docs/BATTLE_REWARD_FORMAL_INTEGRATION_PLAN.md")
RUNTIME_DIR = Path("data/runtime/content_engine")
RUNTIME_CONFIG = RUNTIME_DIR / "runtime_loader_config.json"
CONTENT_ENGINE_CHECK = Path("tools/content_engine/content_engine_check.py")
READONLY_VALIDATOR = Path("tools/content_engine/battle_reward_readonly_integration_probe_validator.py")

REQUIRED_FIELDS = [
    "candidate_type",
    "file_path",
    "symbol_or_line",
    "matched_keyword",
    "evidence",
    "likely_role",
    "confidence",
    "risk_level",
    "recommended_action",
    "notes",
]
ALLOWED_CANDIDATE_TYPES = {
    "legacy_reward_source",
    "reward_generation_function",
    "battle_settlement_entry",
    "reward_display_entry",
    "reward_apply_entry",
    "debug_or_test_entry",
    "high_risk_touchpoint",
    "unknown_candidate",
}
ALLOWED_CONFIDENCE = {"high", "medium", "low"}
ALLOWED_RISK = {"low", "medium", "high"}
ALLOWED_RUNTIME_FILES = {
    "battle_reward.json",
    "card_pool.json",
    "runtime_manifest.json",
    "runtime_loader_config.json",
}
FORBIDDEN_HIGH_RISK = {
    "scripts/combat_resolver.gd",
    "scripts/battle_state_machine.gd",
    "scripts/card_data.gd",
}
FORBIDDEN_FORMAL_SOURCE_FILES = {
    "data/rewards.json",
    "data/enemy_manifest.json",
    "scripts/battle_controller_core_catalog.gd",
    "scripts/battle_controller_core_session_rewards.gd",
    "scripts/battle_controller_visual_story_return.gd",
    "scripts/narrative_demo_formal_controller.gd",
}
MD_REQUIRED_SECTIONS = [
    "当前 battle_reward content engine 状态",
    "当前旧奖励流程定位结果",
    "旧奖励数据源候选",
    "奖励生成函数候选",
    "战斗结算入口候选",
    "奖励展示入口候选",
    "奖励应用入口候选",
    "推荐的最小接入点",
    "不推荐直接修改的文件和原因",
    "battle_reward adapter 设计",
    "config mode 设计",
    "shadow 阶段方案",
    "runtime_test 阶段方案",
    "runtime_enabled 阶段方案",
    "fallback 和回滚方案",
    "验收标准",
    "风险清单",
    "后续 v1.0b / v1.0c / v1.0d / v1.0e 建议",
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
    parser = argparse.ArgumentParser(description="验证 battle_reward 旧流程定位报告及 v1.0a 边界。")
    parser.add_argument("--report", default=str(REPORT_TSV))
    parser.add_argument("--report-md", default=str(REPORT_MD))
    parser.add_argument("--plan", default=str(PLAN_MD))
    return parser.parse_args()


def read_tsv(path: Path) -> list[dict[str, str]]:
    with path.open("r", encoding="utf-8", newline="") as f:
        reader = csv.DictReader(f, delimiter="\t")
        fields = reader.fieldnames or []
        missing = [field for field in REQUIRED_FIELDS if field not in fields]
        if missing:
            raise ValueError(f"{path} missing columns: {', '.join(missing)}")
        return list(reader)


def git_changed_paths() -> list[str]:
    out = subprocess.check_output(["git", "status", "--porcelain"], text=True)
    paths: list[str] = []
    for line in out.splitlines():
        if len(line) < 4:
            continue
        raw = line[3:]
        if " -> " in raw:
            raw = raw.split(" -> ", 1)[1]
        paths.append(raw)
    return sorted(set(paths))


def is_markdown_mostly_chinese(path: Path) -> bool:
    text = path.read_text(encoding="utf-8", errors="ignore")
    if not text.strip():
        return False
    cjk_count = len(re.findall(r"[\u4e00-\u9fff]", text))
    # 允许技术字段、枚举值、路径名为英文，但正文必须存在足量中文说明。
    return cjk_count >= 20


def config_disabled(cfg: dict) -> bool:
    return (
        cfg.get("content_engine_runtime_enabled") is False
        and cfg.get("read_only_probe_enabled") is False
        and str(cfg.get("integration_mode", "")) == "disabled"
        and str(cfg.get("fallback_mode", "")) == "existing_data_source"
    )


def count_existing_gd_references() -> int:
    targets = [
        "content_engine_runtime_loader.gd",
        "ContentEngineRuntimeLoader",
        "content_engine_runtime_gate.gd",
        "ContentEngineRuntimeGate",
        "content_engine_battle_reward_probe.gd",
        "CONTENT_ENGINE_BATTLE_REWARD_PROBE_JSON_BEGIN",
        "battle_reward_readonly_integration_probe.gd",
        "BATTLE_REWARD_READONLY_INTEGRATION_PROBE_JSON_BEGIN",
        "battle_reward_legacy_flow_probe",
        "battle_reward_legacy_flow_validator",
    ]
    excluded = {"content_engine_runtime_loader.gd", "content_engine_runtime_gate.gd"}
    count = 0
    for gd in Path("scripts").glob("*.gd"):
        if gd.name in excluded:
            continue
        text = gd.read_text(encoding="utf-8", errors="ignore")
        if any(token in text for token in targets):
            count += 1
    return count


def run_cmd(cmd: list[str]) -> tuple[int, str]:
    proc = subprocess.run(cmd, capture_output=True, text=True)
    output = (proc.stdout or "") + (proc.stderr or "")
    return proc.returncode, output


def main() -> int:
    args = parse_args()
    report = ValidationReport()

    report_path = Path(args.report)
    report_md_path = Path(args.report_md)
    plan_path = Path(args.plan)

    if not report_path.exists():
        report.fail(f"missing report: {report_path.as_posix()}")
        print(report.format())
        return 1
    if not report_md_path.exists():
        report.fail(f"missing markdown report: {report_md_path.as_posix()}")
    if not plan_path.exists():
        report.fail(f"missing integration plan: {plan_path.as_posix()}")

    rows: list[dict[str, str]] = []
    try:
        rows = read_tsv(report_path)
    except ValueError as exc:
        report.fail(str(exc))
        print(report.format())
        return 1

    if not rows:
        report.fail("legacy flow report must contain at least one row")
    else:
        report.pass_(f"legacy flow report row_count={len(rows)}")

    for idx, row in enumerate(rows, start=1):
        for field in REQUIRED_FIELDS:
            if row.get(field, "").strip() == "":
                report.fail(f"row#{idx} field empty: {field}")
        if row.get("candidate_type", "") not in ALLOWED_CANDIDATE_TYPES:
            report.fail(f"row#{idx} invalid candidate_type: {row.get('candidate_type', '')}")
        if row.get("confidence", "") not in ALLOWED_CONFIDENCE:
            report.fail(f"row#{idx} invalid confidence: {row.get('confidence', '')}")
        if row.get("risk_level", "") not in ALLOWED_RISK:
            report.fail(f"row#{idx} invalid risk_level: {row.get('risk_level', '')}")

    changed_paths = git_changed_paths()

    # Markdown 中文约束：检查所有新增/修改 markdown。
    changed_md = [p for p in changed_paths if p.lower().endswith(".md")]
    required_md = {
        report_md_path.as_posix(),
        plan_path.as_posix(),
    }
    for md in sorted(required_md):
        if md not in changed_md:
            report.fail(f"required markdown not changed/new in this task: {md}")
    for md in changed_md:
        md_path = Path(md)
        if not md_path.exists():
            report.fail(f"markdown file missing on disk: {md}")
            continue
        if not is_markdown_mostly_chinese(md_path):
            report.fail(f"markdown not Chinese-dominant: {md}")
    if changed_md:
        report.pass_(f"markdown Chinese check passed for {len(changed_md)} files")

    # 设计文档章节完整性
    if plan_path.exists():
        plan_text = plan_path.read_text(encoding="utf-8", errors="ignore")
        for section in MD_REQUIRED_SECTIONS:
            if section not in plan_text:
                report.fail(f"integration plan missing section: {section}")
        report.pass_("integration plan section check finished")

    # 高风险文件和禁止范围
    for path in changed_paths:
        if path in FORBIDDEN_HIGH_RISK:
            report.fail(f"high-risk file modified: {path}")
        if path.startswith("data/story_battles/") and path.endswith(".tsv"):
            report.fail(f"story battle tsv modified: {path}")
        if path.startswith("scenes/") and path.endswith(".tscn"):
            report.fail(f"scene file modified: {path}")
        if path in FORBIDDEN_FORMAL_SOURCE_FILES:
            report.fail(f"formal reward source replaced/touched: {path}")

    # runtime config / runtime 目录
    if not RUNTIME_CONFIG.exists():
        report.fail("runtime_loader_config.json missing")
    else:
        try:
            cfg = json.loads(RUNTIME_CONFIG.read_text(encoding="utf-8"))
        except json.JSONDecodeError:
            cfg = {}
            report.fail("runtime_loader_config.json parse failed")
        if not config_disabled(cfg if isinstance(cfg, dict) else {}):
            report.fail("runtime_loader_config is not disabled")
        else:
            report.pass_("runtime_loader_config remains disabled")

    runtime_files = {p.name for p in RUNTIME_DIR.iterdir() if p.is_file()} if RUNTIME_DIR.exists() else set()
    if runtime_files != ALLOWED_RUNTIME_FILES:
        report.fail(f"runtime dir mismatch: expected={sorted(ALLOWED_RUNTIME_FILES)} actual={sorted(runtime_files)}")
    else:
        report.pass_("runtime dir allowlist check passed")

    # 现有 .gd 文件不可引用 loader/gate/probe
    gd_ref_count = count_existing_gd_references()
    if gd_ref_count != 0:
        report.fail(f"existing .gd references loader/gate/probe found: {gd_ref_count}")
    else:
        report.pass_("no existing .gd references loader/gate/probe")

    # 依赖脚本校验
    rc_check, _ = run_cmd([sys.executable, str(CONTENT_ENGINE_CHECK)])
    if rc_check != 0:
        report.fail("content_engine_check.py failed")
    else:
        report.pass_("content_engine_check.py passed")

    rc_readonly, _ = run_cmd([sys.executable, str(READONLY_VALIDATOR)])
    if rc_readonly != 0:
        report.fail("battle_reward_readonly_integration_probe_validator.py failed")
    else:
        report.pass_("battle_reward_readonly_integration_probe_validator.py passed")

    print(report.format())
    return 0 if report.ok() else 1


if __name__ == "__main__":
    raise SystemExit(main())
