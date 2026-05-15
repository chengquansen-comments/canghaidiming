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

from tools.aigc_battle import aigc_candidate_promotion_gate as promotion_lib
from tools.aigc_battle import aigc_preview_runtime_control as preview_lib
from tools.aigc_battle import aigc_release_gate as release_lib
from tools.aigc_battle import aigc_write_human_review_note as review_note_lib


OUT_DIR = ROOT / "data" / "aigc_battle" / "generated" / "promotion"


def main() -> int:
    review_note_lib.write_human_review_note(
        "weapon_followup_v0_1",
        "weapon_followup_balance_release_007",
        "accepted",
        "codex_probe",
        "current reference accepted for promotion gate probe",
    )
    review_note_lib.write_human_review_note(
        "weapon_followup_v0_1",
        "r9_fast_candidate_pack_001",
        "needs_balance",
        "codex_probe",
        "accepted acceptance run but still needs balance, should not promote",
    )
    current_payload = promotion_lib.run_promotion_gate("weapon_followup_v0_1", "weapon_followup_balance_release_007")
    ai_payload = promotion_lib.run_promotion_gate("weapon_followup_v0_1", "r9_fast_candidate_pack_001")
    missing_payload = promotion_lib.run_promotion_gate("weapon_followup_v0_1", "weapon_followup_v0_1__formal_sequence_12_fast_v1__matrix_001")
    current_release = release_lib.show_channels().get("current_release", {})
    active = preview_lib.read_active_profile()
    payload = {
        "generated_at": now_iso(),
        "current_reference_promotion_ready": bool(current_payload.get("promotion_allowed", False) and current_payload.get("promoted_to_release_candidate", False)),
        "ai_studio_warning_pack_blocked": bool(not ai_payload.get("promotion_allowed", False) and not ai_payload.get("promoted_to_release_candidate", False)),
        "missing_acceptance_pack_blocked": bool(not missing_payload.get("acceptance_report_found", False) and not missing_payload.get("promotion_allowed", False)),
        "human_review_required": True,
        "acceptance_required": True,
        "release_candidate_mark_ready": bool(current_payload.get("promoted_to_release_candidate", False)),
        "current_release_unchanged": bool(
            current_payload.get("current_release_unchanged", False)
            and ai_payload.get("current_release_unchanged", False)
            and missing_payload.get("current_release_unchanged", False)
        ),
        "active_profile_matches_current_release": preview_lib.active_matches_current(active, current_release),
    }
    payload["probe_pass"] = all(
        bool(payload[key])
        for key in [
            "current_reference_promotion_ready",
            "ai_studio_warning_pack_blocked",
            "missing_acceptance_pack_blocked",
            "human_review_required",
            "acceptance_required",
            "release_candidate_mark_ready",
            "current_release_unchanged",
            "active_profile_matches_current_release",
        ]
    )
    write_json(OUT_DIR / "candidate_promotion_probe_report.json", payload)
    (OUT_DIR / "candidate_promotion_probe_report.md").write_text(build_markdown(payload), encoding="utf-8")
    print(json.dumps(payload, ensure_ascii=False, indent=2))
    return 0 if payload["probe_pass"] else 1


def build_markdown(payload: dict[str, Any]) -> str:
    return "\n".join(
        [
            "# Candidate Promotion Probe",
            "",
            f"- current_reference_promotion_ready: `{payload.get('current_reference_promotion_ready', False)}`",
            f"- ai_studio_warning_pack_blocked: `{payload.get('ai_studio_warning_pack_blocked', False)}`",
            f"- missing_acceptance_pack_blocked: `{payload.get('missing_acceptance_pack_blocked', False)}`",
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
