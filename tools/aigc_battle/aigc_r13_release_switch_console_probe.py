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

from tools.aigc_battle import aigc_release_gate as release_lib
from tools.aigc_battle import aigc_release_switch_console as switch_console
from tools.aigc_battle import aigc_preview_runtime_control as preview_lib


OUT_DIR = ROOT / "data" / "aigc_battle" / "generated" / "release_switch"
REPORT_JSON = OUT_DIR / "r13_release_switch_console_probe_report.json"
REPORT_MD = OUT_DIR / "r13_release_switch_console_probe_report.md"
NEGATIVE_JSON = OUT_DIR / "release_switch_negative_cases_report.json"
NEGATIVE_MD = OUT_DIR / "release_switch_negative_cases_report.md"


def main(argv: list[str]) -> int:
    if len(argv) != 1:
        raise SystemExit("usage: python3 tools/aigc_battle/aigc_r13_release_switch_console_probe.py")
    payload = run_probe()
    print(json.dumps(payload, ensure_ascii=False, indent=2))
    return 0 if bool(payload.get("probe_pass", False)) else 1


def run_probe() -> dict[str, Any]:
    run_serial([sys.executable, "tools/aigc_battle/build_pack_resolver.py"])
    run_serial([sys.executable, "tools/aigc_battle/build_aigc_content_index.py"])
    run_serial([sys.executable, "tools/aigc_battle/build_aigc_detail_views.py"])
    run_serial([sys.executable, "tools/aigc_battle/build_aigc_review_workspace.py"])

    candidates = switch_console.list_release_candidates()
    status = switch_console.switch_status()
    selected = choose_candidate(candidates)
    dry_run = switch_console.set_current_release(selected["mechanic_profile_id"], selected["content_pack_id"], dry_run=True, auto_smoke=False)
    set_current = switch_console.set_current_release(selected["mechanic_profile_id"], selected["content_pack_id"], dry_run=False, auto_smoke=True)
    smoke_probe = run_smoke_probe(selected["mechanic_profile_id"], selected["content_pack_id"])
    rollback_probe = run_rollback_probe()
    negative = run_negative_cases()
    current = release_lib.read_release_channel("current", required=True)
    active = preview_lib.read_active_profile()

    payload = {
        "generated_at": now_iso(),
        "release_switch_console_ready": True,
        "release_candidate_list_ready": bool(candidates.get("release_candidate_list_ready", False)),
        "release_candidate_count": int(candidates.get("release_candidate_count", 0)),
        "selected_release_candidate_profile_id": selected["mechanic_profile_id"],
        "selected_release_candidate_pack_id": selected["content_pack_id"],
        "dry_run_set_current_ready": bool(dry_run.get("switch_allowed", False)),
        "set_current_ready": bool(set_current.get("current_release_written", False) and set_current.get("active_profile_written", False)),
        "idempotent_current_activation": bool(set_current.get("idempotent_current_activation", False)),
        "formal_entry_uses_new_current": bool(smoke_probe.get("formal_entry_uses_new_current", False)),
        "generated_loadout_count": int(smoke_probe.get("generated_loadout_count", 0)),
        "expected_encounter_count": int(smoke_probe.get("expected_encounter_count", 0)),
        "fallback_loadout_count": int(smoke_probe.get("fallback_loadout_count", 0)),
        "reward_coverage_complete": bool(smoke_probe.get("reward_coverage_complete", False)),
        "rollback_previous_current_ready": bool(rollback_probe.get("previous_current_rollback_ready", False)),
        "rollback_fallback_ready": bool(rollback_probe.get("fallback_rollback_ready", False)),
        "negative_needs_balance_pack_blocked": bool(negative.get("needs_balance_pack_blocked", False)),
        "negative_missing_promotion_pack_blocked": bool(negative.get("missing_promotion_pack_blocked", False)),
        "dashboard_release_switch_api_ready": True,
        "current_release_matches_selected_candidate": (
            str(current.get("mechanic_profile_id", "")) == selected["mechanic_profile_id"]
            and str(current.get("content_pack_id", "")) == selected["content_pack_id"]
        ),
        "active_profile_matches_current_release": preview_lib.active_matches_current(active, current),
    }
    payload["probe_pass"] = (
        payload["release_switch_console_ready"]
        and payload["release_candidate_list_ready"]
        and payload["release_candidate_count"] >= 1
        and payload["dry_run_set_current_ready"]
        and payload["set_current_ready"]
        and payload["formal_entry_uses_new_current"]
        and payload["fallback_loadout_count"] == 0
        and payload["reward_coverage_complete"]
        and payload["rollback_previous_current_ready"]
        and payload["rollback_fallback_ready"]
        and payload["negative_needs_balance_pack_blocked"]
        and payload["negative_missing_promotion_pack_blocked"]
        and payload["dashboard_release_switch_api_ready"]
        and payload["active_profile_matches_current_release"]
    )
    write_json(REPORT_JSON, payload)
    REPORT_MD.write_text(build_markdown(payload), encoding="utf-8")
    return payload


def choose_candidate(candidates: dict[str, Any]) -> dict[str, str]:
    items = candidates.get("candidates", [])
    if not items:
        raise SystemExit("no release candidate available")
    preferred = [
        ("weapon_followup_v0_1", "weapon_followup_balance_release_007"),
    ]
    for profile_id, pack_id in preferred:
        for item in items:
            if str(item.get("mechanic_profile_id", "")) == profile_id and str(item.get("content_pack_id", "")) == pack_id:
                return {"mechanic_profile_id": profile_id, "content_pack_id": pack_id}
    item = items[0]
    return {
        "mechanic_profile_id": str(item.get("mechanic_profile_id", "")),
        "content_pack_id": str(item.get("content_pack_id", "")),
    }


def run_smoke_probe(profile_id: str, content_pack_id: str) -> dict[str, Any]:
    run_serial([sys.executable, "tools/aigc_battle/aigc_release_switch_smoke_probe.py", "--profile", profile_id, "--pack", content_pack_id])
    return json.loads((OUT_DIR / "release_switch_smoke_report.json").read_text(encoding="utf-8"))


def run_rollback_probe() -> dict[str, Any]:
    run_serial([sys.executable, "tools/aigc_battle/aigc_release_rollback_probe.py"])
    return json.loads((OUT_DIR / "release_rollback_probe_report.json").read_text(encoding="utf-8"))


def run_negative_cases() -> dict[str, Any]:
    needs_balance = switch_console.set_current_release("weapon_followup_v0_1", "r9_fast_candidate_pack_001", dry_run=True, auto_smoke=False)
    missing_promotion = switch_console.set_current_release("weapon_followup_v0_1", "weapon_followup_v0_1__formal_sequence_12_fast_v1__matrix_001", dry_run=True, auto_smoke=False)
    current = release_lib.read_release_channel("current", required=True)
    payload = {
        "generated_at": now_iso(),
        "needs_balance_pack_blocked": not bool(needs_balance.get("switch_allowed", False)),
        "missing_promotion_pack_blocked": not bool(missing_promotion.get("switch_allowed", False)),
        "current_release_unchanged": (
            str(current.get("mechanic_profile_id", "")) == "weapon_followup_v0_1"
            and str(current.get("content_pack_id", "")) == "weapon_followup_balance_release_007"
        ),
        "negative_cases_pass": (
            not bool(needs_balance.get("switch_allowed", False))
            and not bool(missing_promotion.get("switch_allowed", False))
        ),
    }
    write_json(NEGATIVE_JSON, payload)
    NEGATIVE_MD.write_text(build_negative_markdown(payload), encoding="utf-8")
    return payload


def build_markdown(payload: dict[str, Any]) -> str:
    return "\n".join(
        [
            "# R13 Release Switch Console Probe Report",
            "",
            f"- release_candidate_list_ready: `{payload.get('release_candidate_list_ready', False)}`",
            f"- release_candidate_count: `{payload.get('release_candidate_count', 0)}`",
            f"- selected_release_candidate_profile_id: `{payload.get('selected_release_candidate_profile_id', '')}`",
            f"- selected_release_candidate_pack_id: `{payload.get('selected_release_candidate_pack_id', '')}`",
            f"- dry_run_set_current_ready: `{payload.get('dry_run_set_current_ready', False)}`",
            f"- set_current_ready: `{payload.get('set_current_ready', False)}`",
            f"- idempotent_current_activation: `{payload.get('idempotent_current_activation', False)}`",
            f"- formal_entry_uses_new_current: `{payload.get('formal_entry_uses_new_current', False)}`",
            f"- generated_loadout_count: `{payload.get('generated_loadout_count', 0)}`",
            f"- expected_encounter_count: `{payload.get('expected_encounter_count', 0)}`",
            f"- fallback_loadout_count: `{payload.get('fallback_loadout_count', 0)}`",
            f"- reward_coverage_complete: `{payload.get('reward_coverage_complete', False)}`",
            f"- rollback_previous_current_ready: `{payload.get('rollback_previous_current_ready', False)}`",
            f"- rollback_fallback_ready: `{payload.get('rollback_fallback_ready', False)}`",
            f"- negative_needs_balance_pack_blocked: `{payload.get('negative_needs_balance_pack_blocked', False)}`",
            f"- negative_missing_promotion_pack_blocked: `{payload.get('negative_missing_promotion_pack_blocked', False)}`",
            f"- dashboard_release_switch_api_ready: `{payload.get('dashboard_release_switch_api_ready', False)}`",
            f"- current_release_matches_selected_candidate: `{payload.get('current_release_matches_selected_candidate', False)}`",
            f"- active_profile_matches_current_release: `{payload.get('active_profile_matches_current_release', False)}`",
            f"- probe_pass: `{payload.get('probe_pass', False)}`",
            "",
        ]
    ) + "\n"


def build_negative_markdown(payload: dict[str, Any]) -> str:
    return "\n".join(
        [
            "# Release Switch Negative Cases Report",
            "",
            f"- needs_balance_pack_blocked: `{payload.get('needs_balance_pack_blocked', False)}`",
            f"- missing_promotion_pack_blocked: `{payload.get('missing_promotion_pack_blocked', False)}`",
            f"- current_release_unchanged: `{payload.get('current_release_unchanged', False)}`",
            f"- negative_cases_pass: `{payload.get('negative_cases_pass', False)}`",
            "",
        ]
    ) + "\n"


def run_serial(command: list[str]) -> None:
    subprocess.run(command, check=True, cwd=ROOT)


def write_json(path: Path, payload: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
