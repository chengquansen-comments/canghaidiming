#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from tools.aigc_battle import build_sequence_template_plan as plan_lib
from tools.aigc_battle import load_sequence_template as template_lib

GENERATED_DIR = ROOT / "data" / "aigc_battle" / "generated" / "template_portfolio"
SUMMARY_JSON = GENERATED_DIR / "template_portfolio_summary.json"
SUMMARY_MD = GENERATED_DIR / "template_portfolio_summary.md"
BUILD_JSON = GENERATED_DIR / "template_portfolio_build_report.json"
BUILD_MD = GENERATED_DIR / "template_portfolio_build_report.md"
CURRENT_RELEASE_PATH = ROOT / "data" / "aigc_battle" / "release_channels" / "current_release.json"
TEMPLATES = [
    "formal_sequence_15_v1",
    "formal_sequence_12_fast_v1",
    "bossrush_9_v1",
    "elite_heavy_15_v1",
]
PORTFOLIO_PACKS = [
    ("formal_sequence_12_fast_v1", "portfolio_001", "weapon_followup_v0_1__formal_sequence_12_fast_v1__portfolio_001"),
    ("bossrush_9_v1", "portfolio_001", "weapon_followup_v0_1__bossrush_9_v1__portfolio_001"),
    ("elite_heavy_15_v1", "portfolio_001", "weapon_followup_v0_1__elite_heavy_15_v1__portfolio_001"),
]


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description="Build R6 template portfolio packs")
    parser.add_argument("--mechanic", required=True)
    args = parser.parse_args(argv[1:])
    profile_id = str(args.mechanic).strip()
    if profile_id != "weapon_followup_v0_1":
        raise SystemExit("R6 portfolio currently targets weapon_followup_v0_1 only")
    GENERATED_DIR.mkdir(parents=True, exist_ok=True)
    summary = build_template_portfolio_summary()
    write_json(SUMMARY_JSON, summary)
    SUMMARY_MD.write_text(build_summary_markdown(summary), encoding="utf-8")
    build_report = build_portfolio_packs(profile_id)
    write_json(BUILD_JSON, build_report)
    BUILD_MD.write_text(build_build_markdown(build_report), encoding="utf-8")
    print(f"built template portfolio: templates={summary['template_count']} packs={build_report['template_pack_count']}")
    return 0 if build_report["each_template_generates_pack"] and build_report["each_template_validated"] and build_report["each_template_exported"] else 1


def build_template_portfolio_summary() -> dict[str, Any]:
    templates: list[dict[str, Any]] = []
    for template_id in TEMPLATES:
        payload = template_lib.load_sequence_template(template_id)
        plan = plan_lib.build_sequence_template_plan(template_id)
        templates.append(
            {
                "sequence_template_id": template_id,
                "target_sequence_id": str(payload.get("target_sequence_id", "")),
                "total_encounter_count": int(payload.get("total_encounter_count", 0) or 0),
                "stage_counts": payload.get("stage_counts", {}),
                "encounter_kind_distribution": flatten_kind_distribution(payload),
                "power_curve": stage_curve(payload, "deck_power_range"),
                "reward_curve": stage_curve(payload, "reward_tiers"),
                "realm_curve": {
                    "max_wujing": int(payload.get("realm_curve", {}).get("max_wujing", 0) or 0),
                    "stage_wujing_caps": payload.get("realm_curve", {}).get("stage_wujing_caps", {}),
                },
                "mechanic_density_curve": stage_curve(payload, "mechanic_density_range"),
                "difficulty_curve": {stage: str(payload.get("stages", {}).get(stage, {}).get("difficulty_label", "")) for stage in payload.get("stage_order", [])},
                "stage_plan_path": to_relative(ROOT / "data" / "aigc_battle" / "generated" / "sequence_template_validation" / f"{template_id}_stage_plan.json"),
                "positions": [int(item.get("sequence_position", 0) or 0) for item in plan],
            }
        )
    return {
        "generated_at": now_iso(),
        "template_count": len(templates),
        "template_ids": [item["sequence_template_id"] for item in templates],
        "total_encounter_counts": {item["sequence_template_id"]: item["total_encounter_count"] for item in templates},
        "stage_counts_by_template": {item["sequence_template_id"]: item["stage_counts"] for item in templates},
        "encounter_kind_distribution_by_template": {item["sequence_template_id"]: item["encounter_kind_distribution"] for item in templates},
        "power_curve_by_template": {item["sequence_template_id"]: item["power_curve"] for item in templates},
        "reward_curve_by_template": {item["sequence_template_id"]: item["reward_curve"] for item in templates},
        "realm_curve_by_template": {item["sequence_template_id"]: item["realm_curve"] for item in templates},
        "mechanic_density_curve_by_template": {item["sequence_template_id"]: item["mechanic_density_curve"] for item in templates},
        "templates": templates,
        "template_portfolio_ready": True,
    }


def build_portfolio_packs(profile_id: str) -> dict[str, Any]:
    current_release = read_json(CURRENT_RELEASE_PATH)
    built_pack_ids: list[str] = []
    validated_pack_ids: list[str] = []
    exported_pack_ids: list[str] = []
    failed_pack_ids: list[str] = []
    failures: list[dict[str, Any]] = []

    reference_pack_id = str(current_release.get("content_pack_id", ""))
    reference_template_id = str(current_release.get("sequence_template_id", template_lib.DEFAULT_SEQUENCE_TEMPLATE_ID))

    for template_id, build_variant, pack_id in PORTFOLIO_PACKS:
        try:
            run_step([
                sys.executable,
                str(ROOT / "tools" / "aigc_battle" / "build_content_for_profile.py"),
                profile_id,
                "--sequence-template",
                template_id,
                "--build-variant",
                build_variant,
                "--pack-id",
                pack_id,
            ])
            built_pack_ids.append(pack_id)
            run_step([sys.executable, str(ROOT / "tools" / "aigc_battle" / "validate_content_pack.py"), profile_id, "--pack", pack_id])
            validated_pack_ids.append(pack_id)
            run_step([sys.executable, str(ROOT / "tools" / "aigc_battle" / "export_runtime_manifest.py"), profile_id, "--pack", pack_id])
            exported_pack_ids.append(pack_id)
        except subprocess.CalledProcessError as exc:
            failed_pack_ids.append(pack_id)
            failures.append({"content_pack_id": pack_id, "template_id": template_id, "returncode": exc.returncode})
            break

    successful_templates = len(built_pack_ids) == len(PORTFOLIO_PACKS)
    return {
        "generated_at": now_iso(),
        "mechanic_profile_id": profile_id,
        "template_pack_count": 4,
        "reference_current_release": {
            "source": "current_release",
            "sequence_template_id": reference_template_id,
            "content_pack_id": reference_pack_id,
            "build_variant": str(current_release.get("build_variant", "")),
        },
        "built_pack_ids": [reference_pack_id] + built_pack_ids,
        "validated_pack_ids": [reference_pack_id] + validated_pack_ids,
        "exported_pack_ids": [reference_pack_id] + exported_pack_ids,
        "failed_pack_ids": failed_pack_ids,
        "failures": failures,
        "each_template_generates_pack": successful_templates,
        "each_template_validated": successful_templates and len(validated_pack_ids) == len(PORTFOLIO_PACKS),
        "each_template_exported": successful_templates and len(exported_pack_ids) == len(PORTFOLIO_PACKS),
        "current_release_unchanged": str(read_json(CURRENT_RELEASE_PATH).get("content_pack_id", "")) == reference_pack_id,
        "portfolio_entries": [
            {
                "sequence_template_id": reference_template_id,
                "content_pack_id": reference_pack_id,
                "build_variant": str(current_release.get("build_variant", "")),
                "source": "current_release_reference",
                "total_encounter_count": int(current_release.get("total_encounter_count", 15) or 15),
            }
        ] + [
            {
                "sequence_template_id": template_id,
                "content_pack_id": pack_id,
                "build_variant": build_variant,
                "source": "portfolio_build",
                "total_encounter_count": int(template_lib.load_sequence_template(template_id).get("total_encounter_count", 0) or 0),
            }
            for template_id, build_variant, pack_id in PORTFOLIO_PACKS
        ],
    }


def flatten_kind_distribution(payload: dict[str, Any]) -> dict[str, dict[str, int]]:
    result: dict[str, dict[str, int]] = {}
    for stage in payload.get("stage_order", []):
        stage_payload = payload.get("stages", {}).get(stage, {})
        result[stage] = {str(kind): int(count) for kind, count in stage_payload.get("preferred_encounter_kind_counts", {}).items()}
    return result


def stage_curve(payload: dict[str, Any], key: str) -> dict[str, Any]:
    return {stage: payload.get("stages", {}).get(stage, {}).get(key, []) for stage in payload.get("stage_order", [])}


def build_summary_markdown(summary: dict[str, Any]) -> str:
    lines = [
        "# Template Portfolio Summary",
        "",
        f"- template_count: `{summary.get('template_count', 0)}`",
        f"- template_ids: `{', '.join(summary.get('template_ids', []))}`",
    ]
    for item in summary.get("templates", []):
        lines.extend(
            [
                "",
                f"## {item.get('sequence_template_id', '')}",
                f"- total_encounter_count: `{item.get('total_encounter_count', 0)}`",
                f"- stage_counts: `{json.dumps(item.get('stage_counts', {}), ensure_ascii=False)}`",
                f"- difficulty_curve: `{json.dumps(item.get('difficulty_curve', {}), ensure_ascii=False)}`",
            ]
        )
    return "\n".join(lines) + "\n"


def build_build_markdown(report: dict[str, Any]) -> str:
    lines = [
        "# Template Portfolio Build Report",
        "",
        f"- template_pack_count: `{report.get('template_pack_count', 0)}`",
        f"- built_pack_ids: `{', '.join(report.get('built_pack_ids', []))}`",
        f"- validated_pack_ids: `{', '.join(report.get('validated_pack_ids', []))}`",
        f"- exported_pack_ids: `{', '.join(report.get('exported_pack_ids', []))}`",
        f"- failed_pack_ids: `{', '.join(report.get('failed_pack_ids', [])) or '-'}`",
        f"- current_release_unchanged: `{report.get('current_release_unchanged', False)}`",
    ]
    return "\n".join(lines) + "\n"


def run_step(cmd: list[str]) -> None:
    subprocess.run(cmd, cwd=ROOT, check=True)


def read_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def write_json(path: Path, payload: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def to_relative(path: Path) -> str:
    return path.relative_to(ROOT).as_posix()


def now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
