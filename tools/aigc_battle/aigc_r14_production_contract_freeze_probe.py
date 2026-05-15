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

from tools.aigc_battle import aigc_production_contract_freeze as freeze_lib
from tools.aigc_battle import aigc_dashboard_server as dashboard_lib


GENERATED_DIR = ROOT / "data" / "aigc_battle" / "generated" / "production_freeze"
REPORT_JSON_PATH = GENERATED_DIR / "r14_production_contract_freeze_probe_report.json"
REPORT_MD_PATH = GENERATED_DIR / "r14_production_contract_freeze_probe_report.md"
CURRENT_RELEASE_PATH = ROOT / "data" / "aigc_battle" / "release_channels" / "current_release.json"
ACTIVE_PROFILE_PATH = ROOT / "data" / "aigc_battle" / "runtime" / "active_profile.json"


def main(argv: list[str]) -> int:
    report = run_probe()
    print(json.dumps(report, ensure_ascii=False, indent=2))
    return 0 if report.get("probe_pass", False) else 1


def run_probe() -> dict[str, Any]:
    before_current = read_json(CURRENT_RELEASE_PATH)
    before_active = read_json(ACTIVE_PROFILE_PATH)
    run_command(["python3", "tools/aigc_battle/build_pack_resolver.py"])
    freeze_report = freeze_lib.freeze_production_contract(write=True)
    run_command(["python3", "tools/aigc_battle/build_aigc_content_index.py"])
    run_command(["python3", "tools/aigc_battle/build_aigc_detail_views.py"])
    run_command(["python3", "tools/aigc_battle/build_aigc_review_workspace.py"])
    run_command([
        "python3",
        "tools/aigc_battle/aigc_acceptance_run.py",
        "--profile",
        "weapon_followup_v0_1",
        "--pack",
        "weapon_followup_balance_release_007",
        "--samples",
        "1",
    ])
    run_command(["python3", "tools/aigc_battle/aigc_preview_restore_probe.py"])
    run_command(["python3", "tools/aigc_battle/aigc_candidate_promotion_probe.py"])
    run_command(["python3", "tools/aigc_battle/aigc_r13_release_switch_console_probe.py"])

    acceptance_probe = read_json(ROOT / "data" / "aigc_battle" / "generated" / "acceptance" / "latest_acceptance_report.json")
    preview_restore = read_json(ROOT / "data" / "aigc_battle" / "generated" / "preview_runtime" / "preview_restore_probe_report.json")
    promotion_probe = read_json(ROOT / "data" / "aigc_battle" / "generated" / "promotion" / "candidate_promotion_probe_report.json")
    release_switch_probe = read_json(ROOT / "data" / "aigc_battle" / "generated" / "release_switch" / "r13_release_switch_console_probe_report.json")

    dashboard_ok = bool(dashboard_lib.load_production_contract_summary().get("production_contract_ready", False))
    dashboard_ok = dashboard_ok and bool(dashboard_lib.load_production_contract_schema().get("schema_manifest_ready", False))
    dashboard_ok = dashboard_ok and bool(dashboard_lib.load_production_file_policy().get("generated_file_policy_ready", False))
    dashboard_ok = dashboard_ok and bool(dashboard_lib.load_minimal_acceptance_command().get("minimal_acceptance_command_ready", False))
    dashboard_ok = dashboard_ok and bool(dashboard_lib.load_deprecated_probe_inventory().get("deprecated_probe_inventory_ready", False))

    after_current = read_json(CURRENT_RELEASE_PATH)
    after_active = read_json(ACTIVE_PROFILE_PATH)
    report = {
        "generated_at": now_iso(),
        "production_contract_frozen": bool(freeze_report.get("production_contract_frozen", False)),
        "schema_manifest_ready": bool(freeze_report.get("schema_manifest_ready", False)),
        "generated_file_policy_ready": bool(freeze_report.get("generated_file_policy_ready", False)),
        "minimal_acceptance_command_ready": bool(freeze_report.get("minimal_acceptance_command_ready", False)),
        "deprecated_probe_inventory_ready": bool(freeze_report.get("deprecated_probe_inventory_ready", False)),
        "production_contract_doc_ready": bool(freeze_report.get("production_contract_doc_ready", False)),
        "dashboard_production_contract_api_ready": dashboard_ok,
        "current_release_acceptance_pass": bool(acceptance_probe.get("acceptance_pass", False)),
        "preview_restore_pass": bool(preview_restore.get("probe_pass", False)),
        "promotion_negative_cases_pass": bool(
            promotion_probe.get("ai_studio_warning_pack_blocked", False)
            and promotion_probe.get("missing_acceptance_pack_blocked", False)
        ),
        "release_switch_negative_cases_pass": bool(
            release_switch_probe.get("negative_needs_balance_pack_blocked", False)
            and release_switch_probe.get("negative_missing_promotion_pack_blocked", False)
        ),
        "current_release_unchanged": current_identity(before_current) == current_identity(after_current),
        "active_profile_matches_current_release": (
            str(after_active.get("active_mechanic_profile_id", "")) == str(after_current.get("mechanic_profile_id", ""))
            and str(after_active.get("active_content_pack_id", "")) == str(after_current.get("content_pack_id", ""))
        ),
    }
    report["probe_pass"] = all(
        [
            report["production_contract_frozen"],
            report["schema_manifest_ready"],
            report["generated_file_policy_ready"],
            report["minimal_acceptance_command_ready"],
            report["deprecated_probe_inventory_ready"],
            report["production_contract_doc_ready"],
            report["current_release_acceptance_pass"],
            report["preview_restore_pass"],
            report["promotion_negative_cases_pass"],
            report["release_switch_negative_cases_pass"],
            report["current_release_unchanged"],
            report["active_profile_matches_current_release"],
            report["dashboard_production_contract_api_ready"],
        ]
    )
    write_json(REPORT_JSON_PATH, report)
    REPORT_MD_PATH.write_text(build_markdown(report), encoding="utf-8")
    return report


def run_command(args: list[str]) -> None:
    subprocess.run(args, cwd=ROOT, check=True)


def read_json(path: Path) -> dict[str, Any]:
    if not path.exists():
        return {}
    return json.loads(path.read_text(encoding="utf-8"))


def write_json(path: Path, payload: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def build_markdown(report: dict[str, Any]) -> str:
    lines = ["# R14 Production Contract Freeze Probe", ""]
    for key in [
        "production_contract_frozen",
        "schema_manifest_ready",
        "generated_file_policy_ready",
        "minimal_acceptance_command_ready",
        "deprecated_probe_inventory_ready",
        "production_contract_doc_ready",
        "dashboard_production_contract_api_ready",
        "current_release_acceptance_pass",
        "preview_restore_pass",
        "promotion_negative_cases_pass",
        "release_switch_negative_cases_pass",
        "current_release_unchanged",
        "active_profile_matches_current_release",
        "probe_pass",
    ]:
        lines.append(f"- {key}: `{report.get(key, False)}`")
    return "\n".join(lines) + "\n"


def current_identity(payload: dict[str, Any]) -> tuple[str, str, str, str]:
    return (
        str(payload.get("mechanic_profile_id", "")),
        str(payload.get("content_pack_id", "")),
        str(payload.get("sequence_template_id", "")),
        str(payload.get("build_variant", "")),
    )


def now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
