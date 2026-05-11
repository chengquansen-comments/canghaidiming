#!/usr/bin/env python3
from __future__ import annotations

import json
import subprocess
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[2]
OUT_DIR = ROOT / "data" / "aigc_battle" / "generated" / "balance_release"
REPORT_JSON = OUT_DIR / "r4_playable_balance_release_probe_report.json"
REPORT_MD = OUT_DIR / "r4_playable_balance_release_probe_report.md"
BALANCE_BUILD_REPORT = OUT_DIR / "balance_release_build_report.json"
BALANCE_EVAL_REPORT = OUT_DIR / "balance_release_evaluation_report.json"
BALANCE_SMOKE_REPORT = OUT_DIR / "balance_release_smoke_report.json"
CONFLICT_REPORT = OUT_DIR / "recommendation_conflict_report.json"

PROFILE_ID = "weapon_followup_v0_1"
SOURCE_PACK_ID = "weapon_followup_v0_1_formal_sequence_pack_001"
DEFAULT_NEW_PACK_ID = "weapon_followup_balance_release_001"
PROBE_PORT = 8771


def main() -> int:
    previous_current = read_json(ROOT / "data" / "aigc_battle" / "release_channels" / "current_release.json")
    previous_current_profile_id = str(previous_current.get("mechanic_profile_id", ""))
    previous_current_pack_id = str(previous_current.get("content_pack_id", ""))
    rollback_performed = False
    smoke_report: dict[str, Any] = {}
    dashboard_ready = False

    run([sys.executable, "tools/aigc_battle/build_aigc_content_index.py"])
    run([sys.executable, "tools/aigc_battle/build_aigc_detail_views.py"])
    run([sys.executable, "tools/aigc_battle/build_aigc_review_workspace.py"])
    run([sys.executable, "tools/aigc_battle/resolve_rebuild_recommendation_conflicts.py", "--profile", PROFILE_ID, "--pack", SOURCE_PACK_ID])
    run([sys.executable, "tools/aigc_battle/aigc_build_balance_release.py", "--profile", PROFILE_ID, "--source-pack", SOURCE_PACK_ID, "--new-pack-id", DEFAULT_NEW_PACK_ID])

    build_report = read_json(BALANCE_BUILD_REPORT)
    balanced_pack_id = str(build_report.get("new_pack_id", ""))
    if not balanced_pack_id:
        raise SystemExit("balanced pack id missing in build report")

    run([sys.executable, "tools/aigc_battle/validate_content_pack.py", PROFILE_ID, "--pack", balanced_pack_id])
    run([sys.executable, "tools/aigc_battle/export_runtime_manifest.py", PROFILE_ID, "--pack", balanced_pack_id])
    run([
        sys.executable,
        "tools/aigc_battle/aigc_balance_release_evaluation_probe.py",
        "--profile",
        PROFILE_ID,
        "--source-pack",
        SOURCE_PACK_ID,
        "--balanced-pack",
        balanced_pack_id,
        "--samples",
        "3",
    ])
    evaluation_report = read_json(BALANCE_EVAL_REPORT)
    playable_balance_gate_pass = bool(evaluation_report.get("playable_balance_gate_pass", False))

    balanced_pack_marked_release_candidate = False
    current_release_updated = False
    active_profile_matches_current_release = False
    formal_entry_uses_balanced_release = False
    rollback_to_fallback_ready = False
    rollback_to_previous_current_ready = False

    if playable_balance_gate_pass:
        run([sys.executable, "tools/aigc_battle/aigc_release_gate.py", "set-status", "--profile", PROFILE_ID, "--pack", balanced_pack_id, "--status", "accepted"])
        run([sys.executable, "tools/aigc_battle/aigc_release_gate.py", "freeze", "--profile", PROFILE_ID, "--pack", balanced_pack_id])
        run([sys.executable, "tools/aigc_battle/aigc_release_gate.py", "mark-release-candidate", "--profile", PROFILE_ID, "--pack", balanced_pack_id])
        balanced_pack_marked_release_candidate = True
        run([sys.executable, "tools/aigc_battle/aigc_release_gate.py", "set-current", "--profile", PROFILE_ID, "--pack", balanced_pack_id])
        run([sys.executable, "tools/aigc_battle/aigc_release_gate.py", "activate-current"])
        current_release_updated = True

        try:
            run([sys.executable, "tools/aigc_battle/aigc_balance_release_smoke_probe.py", "--profile", PROFILE_ID, "--pack", balanced_pack_id])
            smoke_report = read_json(BALANCE_SMOKE_REPORT)
        except subprocess.CalledProcessError:
            smoke_report = read_json(BALANCE_SMOKE_REPORT) if BALANCE_SMOKE_REPORT.exists() else {}
            rollback_performed = rollback_to_previous_current(previous_current_profile_id, previous_current_pack_id)
            if not rollback_performed:
                run([sys.executable, "tools/aigc_battle/aigc_release_gate.py", "rollback-to-fallback"])
                rollback_performed = True
        formal_entry_uses_balanced_release = bool(smoke_report.get("formal_entry_uses_balanced_release", False))
        rollback_to_fallback_ready = bool(smoke_report.get("rollback_to_fallback_ready", False))
        rollback_to_previous_current_ready = bool(smoke_report.get("rollback_to_previous_current_ready", False))

    run([sys.executable, "tools/aigc_battle/build_aigc_content_index.py"])
    run([sys.executable, "tools/aigc_battle/build_aigc_detail_views.py"])
    run([sys.executable, "tools/aigc_battle/build_aigc_review_workspace.py"])

    dashboard_ready = check_dashboard_api()

    old_profiles_regression_pass = True
    for profile_id in [
        "posture_opening_pressure_v0_1",
        "weapon_followup_v0_1",
        "clue_pressure_v0_1",
        "martial_realm_7_dual_weapon_v0_1",
    ]:
        try:
            run([sys.executable, "tools/aigc_battle/validate_content_pack.py", profile_id])
            run([sys.executable, "tools/aigc_battle/export_runtime_manifest.py", profile_id])
        except subprocess.CalledProcessError:
            old_profiles_regression_pass = False
            break

    current_release = read_json(ROOT / "data" / "aigc_battle" / "release_channels" / "current_release.json")
    active_profile = read_json(ROOT / "data" / "aigc_battle" / "runtime" / "active_profile.json")
    active_profile_matches_current_release = (
        str(active_profile.get("active_mechanic_profile_id", "")) == str(current_release.get("mechanic_profile_id", ""))
        and str(active_profile.get("active_content_pack_id", "")) == str(current_release.get("content_pack_id", ""))
    )

    conflict_report = read_json(CONFLICT_REPORT)
    validation_report = read_json(ROOT / "data" / "aigc_battle" / "generated" / PROFILE_ID / "packs" / balanced_pack_id / "validation_report.json")
    export_ready = (ROOT / "data" / "aigc_battle" / "generated" / PROFILE_ID / "packs" / balanced_pack_id / "runtime_manifest.json").exists()

    report = {
        "playable_balance_release_ready": False,
        "recommendation_conflict_resolved": bool(conflict_report.get("conflict_resolved", False)),
        "pack_overall_too_hard": bool(conflict_report.get("pack_overall_too_hard", False)),
        "conflicting_recommendations_removed": int(conflict_report.get("removed_conflict_count", 0) or 0),
        "balanced_pack_id": balanced_pack_id,
        "balanced_pack_generated": bool(build_report.get("balance_release_pack_generated", False)),
        "balanced_pack_validated": bool(validation_report.get("ready_for_runtime_export", False)),
        "balanced_pack_exported": export_ready,
        "balanced_pack_evaluated": bool(BALANCE_EVAL_REPORT.exists()),
        "source_win_rate": float(evaluation_report.get("source_win_rate", 0) or 0),
        "balanced_win_rate": float(evaluation_report.get("balanced_win_rate", 0) or 0),
        "overall_win_rate_improved": bool(evaluation_report.get("overall_win_rate_improved", False)),
        "too_hard_candidates_reduced": bool(evaluation_report.get("too_hard_candidates_reduced", False)),
        "too_long_candidates_reduced": bool(evaluation_report.get("too_long_candidates_reduced", False)),
        "reward_mismatch_candidates_reduced": bool(evaluation_report.get("reward_mismatch_candidates_reduced", False)),
        "weapon_followup_trigger_rate_ready": float(evaluation_report.get("weapon_followup_trigger_rate", 0) or 0) >= 0.6,
        "playable_balance_gate_pass": playable_balance_gate_pass,
        "balanced_pack_marked_release_candidate": balanced_pack_marked_release_candidate,
        "current_release_updated": current_release_updated and str(current_release.get("content_pack_id", "")) == balanced_pack_id,
        "formal_entry_uses_balanced_release": formal_entry_uses_balanced_release,
        "rollback_to_fallback_ready": rollback_to_fallback_ready,
        "rollback_to_previous_current_ready": rollback_to_previous_current_ready,
        "dashboard_balance_release_ready": dashboard_ready,
        "old_profiles_regression_pass": old_profiles_regression_pass,
        "active_profile_matches_current_release": active_profile_matches_current_release,
        "rollback_performed": rollback_performed,
    }
    report["playable_balance_release_ready"] = (
        report["recommendation_conflict_resolved"]
        and report["balanced_pack_generated"]
        and report["balanced_pack_validated"]
        and report["balanced_pack_exported"]
        and report["balanced_pack_evaluated"]
        and report["overall_win_rate_improved"]
        and report["balanced_win_rate"] >= 0.30
        and report["too_hard_candidates_reduced"]
        and report["too_long_candidates_reduced"]
        and report["reward_mismatch_candidates_reduced"]
        and report["weapon_followup_trigger_rate_ready"]
        and report["playable_balance_gate_pass"]
        and report["balanced_pack_marked_release_candidate"]
        and report["current_release_updated"]
        and report["formal_entry_uses_balanced_release"]
        and report["rollback_to_fallback_ready"]
        and report["active_profile_matches_current_release"]
    )
    report["probe_pass"] = (
        report["playable_balance_release_ready"]
        and report["dashboard_balance_release_ready"]
        and report["old_profiles_regression_pass"]
    )
    write_json(REPORT_JSON, report)
    REPORT_MD.write_text(markdown(report), encoding="utf-8")
    print("r4 playable balance release probe complete")
    return 0 if report["probe_pass"] else 1


def rollback_to_previous_current(profile_id: str, content_pack_id: str) -> bool:
    if not profile_id or not content_pack_id:
        return False
    try:
        run([sys.executable, "tools/aigc_battle/aigc_release_gate.py", "set-current", "--profile", profile_id, "--pack", content_pack_id])
        run([sys.executable, "tools/aigc_battle/aigc_release_gate.py", "activate-current"])
    except subprocess.CalledProcessError:
        return False
    return True


def check_dashboard_api() -> bool:
    server = subprocess.Popen(
        [sys.executable, "tools/aigc_battle/aigc_dashboard_server.py", "--port", str(PROBE_PORT)],
        cwd=ROOT,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )
    try:
        for _ in range(20):
            time.sleep(0.5)
            try:
                fetch_json(f"http://127.0.0.1:{PROBE_PORT}/api/health")
                break
            except Exception:
                continue
        fetch_json(f"http://127.0.0.1:{PROBE_PORT}/api/balance-release/report")
        fetch_json(f"http://127.0.0.1:{PROBE_PORT}/api/balance-release/evaluation")
        fetch_json(f"http://127.0.0.1:{PROBE_PORT}/api/release/channels")
        invalid_rejected = False
        try:
            fetch_json(f"http://127.0.0.1:{PROBE_PORT}/api/pack-detail?profile_id=weapon_followup_v0_1&content_pack_id=../../bad")
        except urllib.error.HTTPError:
            invalid_rejected = True
        return invalid_rejected
    finally:
        server.terminate()
        try:
            server.wait(timeout=5)
        except subprocess.TimeoutExpired:
            server.kill()


def fetch_json(url: str) -> dict[str, Any]:
    with urllib.request.urlopen(url, timeout=5) as response:
        return json.loads(response.read().decode("utf-8"))


def run(command: list[str]) -> None:
    subprocess.run(command, check=True, cwd=ROOT)


def read_json(path: Path) -> Any:
    return json.loads(path.read_text(encoding="utf-8"))


def write_json(path: Path, payload: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def markdown(report: dict[str, Any]) -> str:
    lines = ["# R4 Playable Balance Release Probe", ""]
    for key, value in report.items():
        lines.append(f"- {key}: `{value}`")
    return "\n".join(lines) + "\n"


if __name__ == "__main__":
    raise SystemExit(main())
