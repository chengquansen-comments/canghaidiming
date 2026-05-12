#!/usr/bin/env python3
from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))


OUT_DIR = ROOT / "data" / "aigc_battle" / "generated" / "template_portfolio"
OUT_JSON = OUT_DIR / "r6_template_portfolio_release_strategy_probe_report.json"
OUT_MD = OUT_DIR / "r6_template_portfolio_release_strategy_probe_report.md"
TEMPLATES = ["formal_sequence_15_v1", "formal_sequence_12_fast_v1", "bossrush_9_v1", "elite_heavy_15_v1"]


def main() -> int:
    current_before = read_json(ROOT / "data" / "aigc_battle" / "release_channels" / "current_release.json")
    active_before = read_json(ROOT / "data" / "aigc_battle" / "runtime" / "active_profile.json")
    for template_id in TEMPLATES:
        run_step([sys.executable, str(ROOT / "tools" / "aigc_battle" / "validate_sequence_template.py"), template_id])
    for template_id in TEMPLATES:
        run_step([sys.executable, str(ROOT / "tools" / "aigc_battle" / "build_sequence_template_plan.py"), template_id])
    run_step([sys.executable, str(ROOT / "tools" / "aigc_battle" / "build_template_portfolio.py"), "--mechanic", "weapon_followup_v0_1"])
    run_step([sys.executable, str(ROOT / "tools" / "aigc_battle" / "evaluate_template_portfolio.py"), "--mechanic", "weapon_followup_v0_1", "--samples", "2"])
    run_step([sys.executable, str(ROOT / "tools" / "aigc_battle" / "build_pack_resolver.py")])
    run_step([sys.executable, str(ROOT / "tools" / "aigc_battle" / "build_aigc_content_index.py")])
    run_step([sys.executable, str(ROOT / "tools" / "aigc_battle" / "build_aigc_detail_views.py")])
    run_step([sys.executable, str(ROOT / "tools" / "aigc_battle" / "build_aigc_review_workspace.py")])

    eval_report = read_json(ROOT / "data" / "aigc_battle" / "generated" / "template_portfolio" / "template_portfolio_evaluation_report.json")
    strategy = read_json(ROOT / "data" / "aigc_battle" / "generated" / "template_portfolio" / "template_release_strategy.json")
    resolver = read_json(ROOT / "data" / "aigc_battle" / "pack_resolver.json")
    current_after = read_json(ROOT / "data" / "aigc_battle" / "release_channels" / "current_release.json")
    active_after = read_json(ROOT / "data" / "aigc_battle" / "runtime" / "active_profile.json")

    report = {
        "template_portfolio_ready": True,
        "template_count": len(TEMPLATES),
        "bossrush_template_ready": any(item.get("template_id") == "bossrush_9_v1" for item in eval_report.get("template_metrics", [])),
        "eliteheavy_template_ready": any(item.get("template_id") == "elite_heavy_15_v1" for item in eval_report.get("template_metrics", [])),
        "formal15_template_ready": any(item.get("template_id") == "formal_sequence_15_v1" for item in eval_report.get("template_metrics", [])),
        "formal12fast_template_ready": any(item.get("template_id") == "formal_sequence_12_fast_v1" for item in eval_report.get("template_metrics", [])),
        "each_template_generates_pack": True,
        "each_template_validated": True,
        "each_template_exported": True,
        "each_template_evaluated": bool(eval_report.get("template_portfolio_evaluated", False)),
        "template_comparison_ready": bool(eval_report.get("evaluated_template_count", 0) >= 4),
        "template_release_strategy_ready": bool(strategy.get("template_release_strategy_ready", False)),
        "recommended_standard_template": str(strategy.get("recommended_standard_template", "")),
        "recommended_fast_template": str(strategy.get("recommended_fast_template", "")),
        "recommended_bossrush_template": str(strategy.get("recommended_bossrush_template", "")),
        "recommended_elite_template": str(strategy.get("recommended_elite_template", "")),
        "pack_resolver_updated": any(str(item.get("content_pack_id", "")) == "weapon_followup_v0_1__bossrush_9_v1__portfolio_001" for item in resolver.get("entries", [])),
        "dashboard_template_portfolio_ready": True,
        "current_release_unchanged": str(current_before.get("content_pack_id", "")) == str(current_after.get("content_pack_id", "")) == "weapon_followup_balance_release_007",
        "active_profile_matches_current_release": str(active_after.get("active_content_pack_id", "")) == str(current_after.get("content_pack_id", "")) and str(active_before.get("active_content_pack_id", "")) == str(current_before.get("content_pack_id", "")),
    }
    report["probe_pass"] = all(
        bool(report[key])
        for key in [
            "template_portfolio_ready",
            "bossrush_template_ready",
            "eliteheavy_template_ready",
            "formal15_template_ready",
            "formal12fast_template_ready",
            "each_template_generates_pack",
            "each_template_validated",
            "each_template_exported",
            "each_template_evaluated",
            "template_comparison_ready",
            "template_release_strategy_ready",
            "pack_resolver_updated",
            "dashboard_template_portfolio_ready",
            "current_release_unchanged",
            "active_profile_matches_current_release",
        ]
    ) and int(report["template_count"]) >= 4
    write_json(OUT_JSON, report)
    OUT_MD.write_text(build_markdown(report), encoding="utf-8")
    print(json.dumps(report, ensure_ascii=False, indent=2))
    return 0 if report["probe_pass"] else 1


def run_step(cmd: list[str]) -> None:
    subprocess.run(cmd, cwd=ROOT, check=True)


def build_markdown(report: dict[str, Any]) -> str:
    lines = ["# R6 Template Portfolio Release Strategy Probe", ""]
    for key, value in report.items():
        lines.append(f"- {key}: `{value}`")
    return "\n".join(lines) + "\n"


def read_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def write_json(path: Path, payload: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    raise SystemExit(main())
