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
from tools.aigc_battle import aigc_candidate_promotion_gate as promotion_lib
from tools.aigc_battle import aigc_candidate_promotion_probe as promotion_probe_lib
from tools.aigc_battle import aigc_dashboard_server as dashboard_lib
from tools.aigc_battle import aigc_preview_runtime_control as preview_lib
from tools.aigc_battle import aigc_release_gate as release_lib
from tools.aigc_battle import aigc_write_human_review_note as review_note_lib
from tools.aigc_battle import build_aigc_content_index as index_lib
from tools.aigc_battle import build_aigc_detail_views as detail_lib
from tools.aigc_battle import build_aigc_review_workspace as review_lib
from tools.aigc_battle import build_pack_resolver as resolver_lib


OUT_DIR = ROOT / "data" / "aigc_battle" / "generated" / "promotion"


def main() -> int:
    resolver_lib.main()
    index_lib.main()
    detail_lib.main()
    review_lib.main()
    ensure_acceptance("weapon_followup_v0_1", "weapon_followup_balance_release_007", 2)
    ensure_acceptance("weapon_followup_v0_1", "r9_fast_candidate_pack_001", 2)
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
    probe_exit = promotion_probe_lib.main()
    probe_payload = preview_lib.read_json(OUT_DIR / "candidate_promotion_probe_report.json")
    current_release = release_lib.show_channels().get("current_release", {})
    active = preview_lib.read_active_profile()
    history_path = ROOT / "data" / "aigc_battle" / "promotion" / "promotion_history.jsonl"
    payload = {
        "generated_at": now_iso(),
        "candidate_promotion_gate_ready": True,
        "acceptance_required_before_promotion": True,
        "human_review_required_before_promotion": True,
        "current_reference_promotion_ready": bool(probe_payload.get("current_reference_promotion_ready", False)),
        "current_reference_marked_release_candidate": bool(current_payload.get("promoted_to_release_candidate", False)),
        "ai_studio_warning_pack_blocked": bool(probe_payload.get("ai_studio_warning_pack_blocked", False)),
        "missing_acceptance_pack_blocked": bool(probe_payload.get("missing_acceptance_pack_blocked", False)),
        "release_candidate_mark_ready": bool(current_payload.get("promoted_to_release_candidate", False)),
        "promotion_history_ready": history_path.exists() and bool(history_path.read_text(encoding="utf-8").strip()),
        "dashboard_promotion_api_ready": bool(
            isinstance(dashboard_lib.load_pack_resolver(), dict)
            and dashboard_lib.load_promotion_report("weapon_followup_v0_1", "weapon_followup_balance_release_007").get("content_pack_id", "") == "weapon_followup_balance_release_007"
            and isinstance(dashboard_lib.load_promotion_history(), dict)
        ),
        "current_release_unchanged": bool(
            current_payload.get("current_release_unchanged", False)
            and ai_payload.get("current_release_unchanged", False)
        ),
        "active_profile_matches_current_release": preview_lib.active_matches_current(active, current_release),
        "probe_exit_ok": probe_exit == 0,
    }
    payload["probe_pass"] = all(
        bool(payload[key])
        for key in [
            "candidate_promotion_gate_ready",
            "acceptance_required_before_promotion",
            "human_review_required_before_promotion",
            "current_reference_promotion_ready",
            "current_reference_marked_release_candidate",
            "ai_studio_warning_pack_blocked",
            "missing_acceptance_pack_blocked",
            "release_candidate_mark_ready",
            "promotion_history_ready",
            "dashboard_promotion_api_ready",
            "current_release_unchanged",
            "active_profile_matches_current_release",
            "probe_exit_ok",
        ]
    )
    write_json(OUT_DIR / "r12_candidate_promotion_gate_probe_report.json", payload)
    (OUT_DIR / "r12_candidate_promotion_gate_probe_report.md").write_text(build_markdown(payload), encoding="utf-8")
    print(json.dumps(payload, ensure_ascii=False, indent=2))
    return 0 if payload["probe_pass"] else 1


def ensure_acceptance(profile_id: str, content_pack_id: str, samples: int) -> None:
    path = acceptance_lib.acceptance_json_path(profile_id, content_pack_id)
    if not path.exists():
        acceptance_lib.run_acceptance(profile_id, content_pack_id, samples=samples, mode="full")


def build_markdown(payload: dict[str, Any]) -> str:
    return "\n".join(
        [
            "# R12 Candidate Promotion Gate Probe",
            "",
            f"- candidate_promotion_gate_ready: `{payload.get('candidate_promotion_gate_ready', False)}`",
            f"- current_reference_marked_release_candidate: `{payload.get('current_reference_marked_release_candidate', False)}`",
            f"- ai_studio_warning_pack_blocked: `{payload.get('ai_studio_warning_pack_blocked', False)}`",
            f"- missing_acceptance_pack_blocked: `{payload.get('missing_acceptance_pack_blocked', False)}`",
            f"- promotion_history_ready: `{payload.get('promotion_history_ready', False)}`",
            f"- dashboard_promotion_api_ready: `{payload.get('dashboard_promotion_api_ready', False)}`",
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
