#!/usr/bin/env python3
from __future__ import annotations

import json
import sys
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))


OUT_DIR = ROOT / "data" / "aigc_battle" / "generated" / "template_portfolio"
OUT_JSON = OUT_DIR / "template_portfolio_probe_report.json"
OUT_MD = OUT_DIR / "template_portfolio_probe_report.md"


def main() -> int:
    summary = read_json(ROOT / "data" / "aigc_battle" / "generated" / "template_portfolio" / "template_portfolio_summary.json")
    build_report = read_json(ROOT / "data" / "aigc_battle" / "generated" / "template_portfolio" / "template_portfolio_build_report.json")
    resolver = read_json(ROOT / "data" / "aigc_battle" / "pack_resolver.json")
    current_release = read_json(ROOT / "data" / "aigc_battle" / "release_channels" / "current_release.json")
    stage_plan_ready = all(
        (ROOT / "data" / "aigc_battle" / "generated" / "sequence_template_validation" / f"{template_id}_stage_plan.json").exists()
        for template_id in summary.get("template_ids", [])
    )
    resolver_pack_ids = {str(item.get("content_pack_id", "")) for item in resolver.get("entries", [])}
    expected_pack_ids = {
        "weapon_followup_v0_1__formal_sequence_12_fast_v1__portfolio_001",
        "weapon_followup_v0_1__bossrush_9_v1__portfolio_001",
        "weapon_followup_v0_1__elite_heavy_15_v1__portfolio_001",
    }
    report = {
        "template_count": int(summary.get("template_count", 0) or 0),
        "bossrush_9_v1_valid": "bossrush_9_v1" in summary.get("template_ids", []),
        "elite_heavy_15_v1_valid": "elite_heavy_15_v1" in summary.get("template_ids", []),
        "each_template_stage_plan_ready": stage_plan_ready,
        "each_template_generates_pack": bool(build_report.get("each_template_generates_pack", False)),
        "each_template_validated": bool(build_report.get("each_template_validated", False)),
        "each_template_exported": bool(build_report.get("each_template_exported", False)),
        "pack_resolver_has_template_packs": expected_pack_ids.issubset(resolver_pack_ids),
        "current_release_unchanged": str(current_release.get("content_pack_id", "")) == "weapon_followup_balance_release_007",
    }
    report["probe_pass"] = all(report.values())
    write_json(OUT_JSON, report)
    OUT_MD.write_text(build_markdown(report), encoding="utf-8")
    print(json.dumps(report, ensure_ascii=False, indent=2))
    return 0 if report["probe_pass"] else 1


def build_markdown(report: dict[str, Any]) -> str:
    lines = ["# Template Portfolio Probe", ""]
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
