#!/usr/bin/env python3
from __future__ import annotations

import json
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from tools.aigc_battle import aigc_acceptance_probe as acceptance_probe_lib
from tools.aigc_battle import aigc_acceptance_run as acceptance_lib
from tools.aigc_battle import aigc_dashboard_server as dashboard_lib
from tools.aigc_battle import aigc_preview_runtime_control as preview_lib
from tools.aigc_battle import aigc_release_gate as release_lib
from tools.aigc_battle import build_aigc_content_index as index_lib
from tools.aigc_battle import build_aigc_detail_views as detail_lib
from tools.aigc_battle import build_aigc_review_workspace as review_lib
from tools.aigc_battle import build_pack_resolver as resolver_lib


OUT_DIR = ROOT / "data" / "aigc_battle" / "generated" / "acceptance"


def main() -> int:
    resolver_lib.main()
    index_lib.main()
    detail_lib.main()
    review_lib.main()
    current_report = acceptance_lib.run_acceptance("weapon_followup_v0_1", "weapon_followup_balance_release_007", samples=2, mode="full")
    ai_studio_report = acceptance_lib.run_acceptance("weapon_followup_v0_1", "r9_fast_candidate_pack_001", samples=2, mode="full")
    invalid_report = acceptance_lib.run_acceptance("invalid_profile", "invalid_pack", samples=1, mode="full")
    probe_exit = acceptance_probe_lib.main()
    probe_report = preview_lib.read_json(OUT_DIR / "acceptance_probe_report.json")
    current_release = release_lib.show_channels().get("current_release", {})
    active_after = preview_lib.read_active_profile()
    payload = {
        "generated_at": now_iso(),
        "one_click_acceptance_run_ready": True,
        "acceptance_cli_ready": True,
        "current_reference_acceptance_ready": bool(probe_report.get("current_reference_acceptance_ready", False)),
        "ai_studio_pack_acceptance_ready": bool(probe_report.get("ai_studio_pack_acceptance_ready", False)),
        "invalid_pack_rejected": bool(probe_report.get("invalid_pack_rejected", False)),
        "pack_resolved_by_pack_resolver": bool(
            current_report.get("pack_resolved_by_pack_resolver", False)
            and ai_studio_report.get("pack_resolved_by_pack_resolver", False)
        ),
        "validate_pass": bool(current_report.get("validate_pass", False) and ai_studio_report.get("validate_pass", False)),
        "export_pass": bool(current_report.get("export_pass", False) and ai_studio_report.get("export_pass", False)),
        "preview_smoke_pass": bool(
            current_report.get("preview_formal_entry_smoke_pass", False)
            and ai_studio_report.get("preview_formal_entry_smoke_pass", False)
        ),
        "evaluation_ready": bool(current_report.get("evaluation_ready", False) and ai_studio_report.get("evaluation_ready", False)),
        "risk_summary_ready": bool(current_report.get("risk_summary_ready", False) and ai_studio_report.get("risk_summary_ready", False)),
        "acceptance_report_ready": bool(
            current_report.get("report_ready", False)
            and ai_studio_report.get("report_ready", False)
            and invalid_report.get("report_ready", False)
        ),
        "dashboard_acceptance_api_ready": bool(
            isinstance(dashboard_lib.load_pack_resolver(), dict)
            and isinstance(dashboard_lib.load_acceptance_latest(), dict)
            and dashboard_lib.load_acceptance_report("weapon_followup_v0_1", "r9_fast_candidate_pack_001").get("content_pack_id", "") == "r9_fast_candidate_pack_001"
        ),
        "current_release_unchanged": bool(
            current_report.get("current_release_unchanged", False)
            and ai_studio_report.get("current_release_unchanged", False)
            and invalid_report.get("current_release_unchanged", False)
        ),
        "active_profile_matches_current_release": preview_lib.active_matches_current(active_after, current_release),
        "acceptance_probe_exit_ok": probe_exit == 0,
    }
    payload["probe_pass"] = all(
        bool(payload[key])
        for key in [
            "one_click_acceptance_run_ready",
            "acceptance_cli_ready",
            "current_reference_acceptance_ready",
            "ai_studio_pack_acceptance_ready",
            "invalid_pack_rejected",
            "pack_resolved_by_pack_resolver",
            "validate_pass",
            "export_pass",
            "preview_smoke_pass",
            "evaluation_ready",
            "risk_summary_ready",
            "acceptance_report_ready",
            "dashboard_acceptance_api_ready",
            "current_release_unchanged",
            "active_profile_matches_current_release",
            "acceptance_probe_exit_ok",
        ]
    )
    write_json(OUT_DIR / "r11_one_click_acceptance_run_probe_report.json", payload)
    (OUT_DIR / "r11_one_click_acceptance_run_probe_report.md").write_text(build_markdown(payload), encoding="utf-8")
    print(json.dumps(payload, ensure_ascii=False, indent=2))
    return 0 if payload["probe_pass"] else 1


def build_markdown(payload: dict[str, Any]) -> str:
    return "\n".join(
        [
            "# R11 One-Click Acceptance Run Probe",
            "",
            f"- one_click_acceptance_run_ready: `{payload.get('one_click_acceptance_run_ready', False)}`",
            f"- current_reference_acceptance_ready: `{payload.get('current_reference_acceptance_ready', False)}`",
            f"- ai_studio_pack_acceptance_ready: `{payload.get('ai_studio_pack_acceptance_ready', False)}`",
            f"- invalid_pack_rejected: `{payload.get('invalid_pack_rejected', False)}`",
            f"- validate_pass: `{payload.get('validate_pass', False)}`",
            f"- export_pass: `{payload.get('export_pass', False)}`",
            f"- preview_smoke_pass: `{payload.get('preview_smoke_pass', False)}`",
            f"- evaluation_ready: `{payload.get('evaluation_ready', False)}`",
            f"- risk_summary_ready: `{payload.get('risk_summary_ready', False)}`",
            f"- acceptance_report_ready: `{payload.get('acceptance_report_ready', False)}`",
            f"- dashboard_acceptance_api_ready: `{payload.get('dashboard_acceptance_api_ready', False)}`",
            f"- current_release_unchanged: `{payload.get('current_release_unchanged', False)}`",
            f"- active_profile_matches_current_release: `{payload.get('active_profile_matches_current_release', False)}`",
            f"- probe_pass: `{payload.get('probe_pass', False)}`",
            "",
        ]
    ) + "\n"


def write_json(path: Path, payload: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


if __name__ == "__main__":
    raise SystemExit(main())
