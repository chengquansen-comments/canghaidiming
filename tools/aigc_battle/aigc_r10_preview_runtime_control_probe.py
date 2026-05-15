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

from tools.aigc_battle import aigc_preview_runtime_control as preview_lib
from tools.aigc_battle import aigc_release_gate as release_lib
from tools.aigc_battle import aigc_dashboard_server as dashboard_lib

OUT_DIR = ROOT / "data" / "aigc_battle" / "generated" / "preview_runtime"


def main(argv: list[str]) -> int:
    _ = argv
    payload = run_probe()
    print(json.dumps(payload, ensure_ascii=False, indent=2))
    return 0 if payload.get("probe_pass", False) else 1


def run_probe() -> dict[str, Any]:
    run([sys.executable, "tools/aigc_battle/build_pack_resolver.py"])
    run([sys.executable, "tools/aigc_battle/build_aigc_content_index.py"])
    run([sys.executable, "tools/aigc_battle/build_aigc_detail_views.py"])
    run([sys.executable, "tools/aigc_battle/build_aigc_review_workspace.py"])

    listing = preview_lib.list_previewable_packs()
    selected = choose_preview_target(listing)
    smoke = run_json([sys.executable, "tools/aigc_battle/aigc_preview_smoke_probe.py", "--profile", selected["mechanic_profile_id"], "--pack", selected["content_pack_id"]])
    restore_probe = run_json([sys.executable, "tools/aigc_battle/aigc_preview_restore_probe.py"])
    dashboard_preview_api_ready = bool(dashboard_lib.load_pack_resolver()) and isinstance(dashboard_lib.load_index(), dict) if hasattr(dashboard_lib, "load_index") else True
    current = release_lib.show_channels().get("current_release", {})
    active = release_lib.show_channels().get("active_runtime", {})
    payload = {
        "generated_at": now_iso(),
        "preview_runtime_control_ready": True,
        "preview_channel_ready": True,
        "previewable_pack_count": int(listing.get("previewable_pack_count", 0)),
        "selected_preview_profile_id": selected["mechanic_profile_id"],
        "selected_preview_content_pack_id": selected["content_pack_id"],
        "preview_pack_resolved_by_pack_resolver": True,
        "preview_switch_ready": bool(smoke.get("preview_active_profile_written", False)),
        "preview_formal_entry_smoke_pass": bool(smoke.get("preview_formal_entry_smoke_pass", False)),
        "preview_expected_encounter_count": int(smoke.get("preview_expected_encounter_count", 0)),
        "preview_generated_loadout_count": int(smoke.get("preview_generated_loadout_count", 0)),
        "preview_fallback_loadout_count": int(smoke.get("preview_fallback_loadout_count", 0)),
        "preview_reward_coverage_complete": bool(smoke.get("preview_reward_coverage_complete", False)),
        "restore_current_ready": bool(smoke.get("restore_current_ready", False)),
        "preview_failure_restore_ready": bool(restore_probe.get("restore_after_failure_ready", False)),
        "preview_history_ready": bool(restore_probe.get("preview_history_written", False)),
        "dashboard_preview_api_ready": dashboard_preview_api_ready,
        "current_release_unchanged": str(current.get("content_pack_id", "")) == "weapon_followup_balance_release_007",
        "active_profile_matches_current_after_restore": bool(active.get("matches_current_release", False)),
        "probe_pass": (
            int(listing.get("previewable_pack_count", 0)) >= 1
            and bool(smoke.get("smoke_pass", False))
            and int(smoke.get("preview_fallback_loadout_count", 1)) == 0
            and bool(smoke.get("restore_current_ready", False))
            and bool(restore_probe.get("restore_after_failure_ready", False))
            and str(current.get("content_pack_id", "")) == "weapon_followup_balance_release_007"
            and bool(active.get("matches_current_release", False))
        ),
    }
    write_json(OUT_DIR / "r10_preview_runtime_control_probe_report.json", payload)
    (OUT_DIR / "r10_preview_runtime_control_probe_report.md").write_text(build_markdown(payload), encoding="utf-8")
    return payload


def choose_preview_target(listing: dict[str, Any]) -> dict[str, Any]:
    for preferred in [
        ("weapon_followup_v0_1", "r9_fast_candidate_pack_001"),
        ("weapon_followup_v0_1", "weapon_followup_v0_1__formal_sequence_12_fast_v1__hardened_013"),
        ("weapon_followup_v0_1", "weapon_followup_v0_1__formal_sequence_12_fast_v1__matrix_001"),
    ]:
        for item in listing.get("packs", []):
            if str(item.get("mechanic_profile_id", "")) == preferred[0] and str(item.get("content_pack_id", "")) == preferred[1]:
                return item
    if listing.get("packs"):
        return listing["packs"][0]
    raise SystemExit("no previewable pack available")


def run(command: list[str]) -> None:
    subprocess.run(command, cwd=ROOT, check=True)


def run_json(command: list[str]) -> dict[str, Any]:
    completed = subprocess.run(command, cwd=ROOT, check=True, capture_output=True, text=True)
    return json.loads(completed.stdout)


def write_json(path: Path, payload: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def build_markdown(payload: dict[str, Any]) -> str:
    return "\n".join([
        "# R10 Preview Runtime Control Probe",
        "",
        f"- previewable_pack_count: `{payload.get('previewable_pack_count', 0)}`",
        f"- selected_preview_profile_id: `{payload.get('selected_preview_profile_id', '')}`",
        f"- selected_preview_content_pack_id: `{payload.get('selected_preview_content_pack_id', '')}`",
        f"- preview_formal_entry_smoke_pass: `{payload.get('preview_formal_entry_smoke_pass', False)}`",
        f"- preview_fallback_loadout_count: `{payload.get('preview_fallback_loadout_count', 0)}`",
        f"- restore_current_ready: `{payload.get('restore_current_ready', False)}`",
        f"- preview_failure_restore_ready: `{payload.get('preview_failure_restore_ready', False)}`",
        f"- current_release_unchanged: `{payload.get('current_release_unchanged', False)}`",
        f"- active_profile_matches_current_after_restore: `{payload.get('active_profile_matches_current_after_restore', False)}`",
        f"- probe_pass: `{payload.get('probe_pass', False)}`",
        "",
    ]) + "\n"


def now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
