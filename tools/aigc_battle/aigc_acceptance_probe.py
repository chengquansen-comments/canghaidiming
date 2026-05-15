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

from tools.aigc_battle import aigc_acceptance_run as acceptance_lib
from tools.aigc_battle import aigc_release_gate as release_lib
from tools.aigc_battle import aigc_preview_runtime_control as preview_lib


OUT_DIR = ROOT / "data" / "aigc_battle" / "generated" / "acceptance"


def main() -> int:
    current_report = acceptance_lib.run_acceptance("weapon_followup_v0_1", "weapon_followup_balance_release_007", samples=2, mode="full")
    ai_studio_report = acceptance_lib.run_acceptance("weapon_followup_v0_1", "r9_fast_candidate_pack_001", samples=2, mode="full")
    invalid_report = acceptance_lib.run_acceptance("invalid_profile", "invalid_pack", samples=1, mode="full")
    current_release = release_lib.show_channels().get("current_release", {})
    active_after = preview_lib.read_active_profile()
    payload = {
        "generated_at": now_iso(),
        "current_reference_acceptance_ready": bool(
            current_report.get("acceptance_pass", False)
            and current_report.get("acceptance_recommendation") == "current_reference_pass"
        ),
        "ai_studio_pack_acceptance_ready": bool(
            ai_studio_report.get("validate_pass", False)
            and ai_studio_report.get("export_pass", False)
            and ai_studio_report.get("preview_formal_entry_smoke_pass", False)
            and ai_studio_report.get("evaluation_ready", False)
            and ai_studio_report.get("active_profile_matches_current_release", False)
            and ai_studio_report.get("acceptance_recommendation") in {"ready_for_review", "needs_balance"}
        ),
        "invalid_pack_rejected": bool(
            not invalid_report.get("acceptance_pass", False)
            and (
                not invalid_report.get("pack_resolved", False)
                or not invalid_report.get("pack_acceptable", True)
            )
        ),
        "acceptance_restore_ready": bool(
            current_report.get("active_profile_matches_current_release", False)
            and ai_studio_report.get("active_profile_matches_current_release", False)
            and invalid_report.get("active_profile_matches_current_release", False)
        ),
        "current_release_unchanged": bool(
            current_report.get("current_release_unchanged", False)
            and ai_studio_report.get("current_release_unchanged", False)
            and invalid_report.get("current_release_unchanged", False)
        ),
        "active_profile_matches_current_release": preview_lib.active_matches_current(active_after, current_release),
    }
    payload["probe_pass"] = all(
        bool(payload[key])
        for key in [
            "current_reference_acceptance_ready",
            "ai_studio_pack_acceptance_ready",
            "invalid_pack_rejected",
            "acceptance_restore_ready",
            "current_release_unchanged",
            "active_profile_matches_current_release",
        ]
    )
    write_json(OUT_DIR / "acceptance_probe_report.json", payload)
    (OUT_DIR / "acceptance_probe_report.md").write_text(build_markdown(payload), encoding="utf-8")
    print(json.dumps(payload, ensure_ascii=False, indent=2))
    return 0 if payload["probe_pass"] else 1


def build_markdown(payload: dict[str, Any]) -> str:
    return "\n".join(
        [
            "# Acceptance Probe Report",
            "",
            f"- current_reference_acceptance_ready: `{payload.get('current_reference_acceptance_ready', False)}`",
            f"- ai_studio_pack_acceptance_ready: `{payload.get('ai_studio_pack_acceptance_ready', False)}`",
            f"- invalid_pack_rejected: `{payload.get('invalid_pack_rejected', False)}`",
            f"- acceptance_restore_ready: `{payload.get('acceptance_restore_ready', False)}`",
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
