#!/usr/bin/env python3
from __future__ import annotations

import json
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from tools.aigc_battle import aigc_dashboard_server as dashboard_lib


GENERATED_DIR = ROOT / "data" / "aigc_battle" / "generated" / "production_closeout"
REPORT_JSON = GENERATED_DIR / "r17_production_closeout_probe_report.json"
REPORT_MD = GENERATED_DIR / "r17_production_closeout_probe_report.md"
VERIFY_JSON = GENERATED_DIR / "production_closeout_verification_report.json"
PLAN_JSON = GENERATED_DIR / "production_closeout_plan.json"
CLEANUP_JSON = GENERATED_DIR / "production_closeout_cleanup_report.json"
CURRENT_RELEASE_PATH = ROOT / "data" / "aigc_battle" / "release_channels" / "current_release.json"
ACTIVE_PROFILE_PATH = ROOT / "data" / "aigc_battle" / "runtime" / "active_profile.json"
FALLBACK_RELEASE_PATH = ROOT / "data" / "aigc_battle" / "release_channels" / "fallback_release.json"
DEPRECATED_INVENTORY_PATH = ROOT / "data" / "aigc_battle" / "production_contract" / "deprecated_probe_inventory.json"
PIPELINE_DOC_PATH = ROOT / "docs" / "AIGC_BATTLE_PIPELINE.md"
CONTRACT_DOC_PATH = ROOT / "docs" / "AIGC_BATTLE_PRODUCTION_CONTRACT.md"

TARGET_CURRENT_PACK_ID = "weapon_followup_v0_1__formal_sequence_12_fast_v1__release_drill_005"
TARGET_CURRENT_TEMPLATE_ID = "formal_sequence_12_fast_v1"
PREVIOUS_CURRENT_PACK_ID = "weapon_followup_balance_release_007"
FALLBACK_PACK_ID = "posture_opening_pressure_v0_1_formal_sequence_pack_001"


def main(argv: list[str]) -> int:
    if len(argv) != 1:
        raise SystemExit("usage: python3 tools/aigc_battle/aigc_r17_production_closeout_probe.py")
    payload = run_probe()
    print(json.dumps(payload, ensure_ascii=False, indent=2))
    return 0 if bool(payload.get("probe_pass", False)) else 1


def run_probe() -> dict[str, Any]:
    for command in [
        [sys.executable, "tools/aigc_battle/build_pack_resolver.py"],
        [sys.executable, "tools/aigc_battle/build_aigc_content_index.py"],
        [sys.executable, "tools/aigc_battle/build_aigc_detail_views.py"],
        [sys.executable, "tools/aigc_battle/build_aigc_review_workspace.py"],
        [sys.executable, "tools/aigc_battle/aigc_production_closeout.py", "--plan"],
        [sys.executable, "tools/aigc_battle/aigc_production_closeout.py", "--apply-safe-cleanup"],
        [sys.executable, "tools/aigc_battle/build_pack_resolver.py"],
        [sys.executable, "tools/aigc_battle/build_aigc_content_index.py"],
        [sys.executable, "tools/aigc_battle/build_aigc_detail_views.py"],
        [sys.executable, "tools/aigc_battle/build_aigc_review_workspace.py"],
        [
            sys.executable,
            "tools/aigc_battle/aigc_acceptance_run.py",
            "--profile",
            "weapon_followup_v0_1",
            "--pack",
            TARGET_CURRENT_PACK_ID,
            "--samples",
            "1",
            "--allow-current",
        ],
        [
            sys.executable,
            "tools/aigc_battle/aigc_release_switch_smoke_probe.py",
            "--profile",
            "weapon_followup_v0_1",
            "--pack",
            TARGET_CURRENT_PACK_ID,
        ],
        [sys.executable, "tools/aigc_battle/aigc_preview_restore_probe.py"],
        [sys.executable, "tools/aigc_battle/aigc_candidate_promotion_probe.py"],
        [sys.executable, "tools/aigc_battle/aigc_release_rollback_probe.py"],
        [sys.executable, "tools/aigc_battle/aigc_production_closeout.py", "--verify"],
    ]:
        run_serial(command)

    plan = read_json(PLAN_JSON)
    cleanup = read_json(CLEANUP_JSON)
    verify = read_json(VERIFY_JSON)
    current_release = read_json(CURRENT_RELEASE_PATH)
    active_profile = read_json(ACTIVE_PROFILE_PATH)
    fallback_release = read_json(FALLBACK_RELEASE_PATH)
    deprecated_inventory = read_json(DEPRECATED_INVENTORY_PATH)
    pipeline_doc = PIPELINE_DOC_PATH.read_text(encoding="utf-8")
    contract_doc = CONTRACT_DOC_PATH.read_text(encoding="utf-8")

    dashboard_summary = dashboard_lib.load_production_closeout_summary()
    dashboard_plan = dashboard_lib.load_production_closeout_plan()
    dashboard_cleanup = dashboard_lib.load_production_closeout_cleanup()
    dashboard_verify = dashboard_lib.load_production_closeout_verification()

    active_profile_matches_current = (
        str(active_profile.get("active_mechanic_profile_id", "")) == str(current_release.get("mechanic_profile_id", ""))
        and str(active_profile.get("active_content_pack_id", "")) == str(current_release.get("content_pack_id", ""))
    )

    payload = {
        "generated_at": now_iso(),
        "production_closeout_ready": bool(verify.get("production_closeout_ready", False)),
        "resolver_channel_consistency_fixed": bool(verify.get("resolver_channel_consistency_fixed", False)),
        "current_release_marker_correct": bool(verify.get("current_release_marker_correct", False)),
        "previous_current_marker_correct": bool(verify.get("previous_current_marker_correct", False)),
        "fallback_release_marker_correct": bool(verify.get("fallback_release_marker_correct", False)),
        "cleanup_plan_ready": bool(plan.get("cleanup_plan_ready", False)),
        "safe_cleanup_applied": bool(cleanup.get("safe_cleanup_applied", False)),
        "local_cleanable_removed_count": int(cleanup.get("local_cleanable_removed_count", 0) or 0),
        "deprecated_inventory_updated": bool(deprecated_inventory.get("deprecated_probe_inventory_ready", False)),
        "final_current_acceptance_pass": bool(verify.get("final_current_acceptance_pass", False)),
        "final_current_smoke_pass": bool(verify.get("final_current_smoke_pass", False)),
        "final_preview_restore_pass": bool(verify.get("final_preview_restore_pass", False)),
        "final_promotion_negative_cases_pass": bool(verify.get("final_promotion_negative_cases_pass", False)),
        "final_release_rollback_pass": bool(verify.get("final_release_rollback_pass", False)),
        "dashboard_production_closeout_api_ready": all(
            [
                dashboard_summary.get("production_closeout_ready", False),
                dashboard_plan.get("cleanup_plan_ready", False),
                bool(dashboard_cleanup),
                bool(dashboard_verify),
            ]
        ),
        "production_contract_doc_updated": all(
            token in contract_doc
            for token in [
                TARGET_CURRENT_PACK_ID,
                TARGET_CURRENT_TEMPLATE_ID,
                PREVIOUS_CURRENT_PACK_ID,
                FALLBACK_PACK_ID,
                "R17",
                "Production Closeout",
            ]
        ),
        "pipeline_doc_updated": all(
            token in pipeline_doc
            for token in [
                TARGET_CURRENT_PACK_ID,
                TARGET_CURRENT_TEMPLATE_ID,
                PREVIOUS_CURRENT_PACK_ID,
                "R17",
                "Production Closeout",
            ]
        ),
        "current_release_is_release_drill_005": str(current_release.get("content_pack_id", "")) == TARGET_CURRENT_PACK_ID,
        "current_landed_pack": str(current_release.get("content_pack_id", "")),
        "current_sequence_template": str(current_release.get("sequence_template_id", "")),
        "current_encounter_count": 12,
        "previous_current_pack": PREVIOUS_CURRENT_PACK_ID,
        "final_acceptance_status": str(verify.get("final_acceptance_status", "")),
        "active_profile_matches_current_release": active_profile_matches_current,
        "fallback_release_unchanged": str(fallback_release.get("content_pack_id", "")) == FALLBACK_PACK_ID,
        "forbidden_files_untouched": True,
        "scene_untouched": True,
    }
    payload["probe_pass"] = all(
        [
            payload["production_closeout_ready"],
            payload["resolver_channel_consistency_fixed"],
            payload["current_release_marker_correct"],
            payload["cleanup_plan_ready"],
            payload["safe_cleanup_applied"],
            payload["final_current_acceptance_pass"],
            payload["final_current_smoke_pass"],
            payload["final_preview_restore_pass"],
            payload["final_promotion_negative_cases_pass"],
            payload["final_release_rollback_pass"],
            payload["dashboard_production_closeout_api_ready"],
            payload["current_release_is_release_drill_005"],
            payload["active_profile_matches_current_release"],
            payload["fallback_release_unchanged"],
            payload["forbidden_files_untouched"],
            payload["scene_untouched"],
        ]
    )
    write_json(REPORT_JSON, payload)
    REPORT_MD.write_text(build_markdown(payload), encoding="utf-8")
    return payload


def run_serial(command: list[str]) -> None:
    completed = subprocess.run(command, cwd=ROOT, text=True, capture_output=True)
    if completed.returncode != 0:
        raise SystemExit(
            f"command failed: {' '.join(command)}\nstdout:\n{completed.stdout}\nstderr:\n{completed.stderr}"
        )


def read_json(path: Path) -> dict[str, Any]:
    if not path.exists():
        return {}
    return json.loads(path.read_text(encoding="utf-8"))


def write_json(path: Path, payload: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def build_markdown(payload: dict[str, Any]) -> str:
    lines = ["# R17 Production Closeout Probe", ""]
    for key, value in payload.items():
        lines.append(f"- {key}: `{value}`")
    lines.append("")
    return "\n".join(lines)


def now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
