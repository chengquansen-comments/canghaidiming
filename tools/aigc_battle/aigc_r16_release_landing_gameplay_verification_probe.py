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
from tools.aigc_battle import aigc_preview_runtime_control as preview_lib
from tools.aigc_battle import aigc_release_gate as release_lib
from tools.aigc_battle import aigc_release_switch_smoke_probe as smoke_probe_lib
from tools.aigc_battle import aigc_release_rollback_probe as rollback_probe_lib
from tools.aigc_battle import aigc_release_switch_console as switch_lib


TARGET_PROFILE_ID = "weapon_followup_v0_1"
TARGET_PACK_ID = "weapon_followup_v0_1__formal_sequence_12_fast_v1__release_drill_005"
TARGET_TEMPLATE_ID = "formal_sequence_12_fast_v1"
EXPECTED_ENCOUNTER_COUNT = 12

OUT_DIR = ROOT / "data" / "aigc_battle" / "generated" / "release_landing"
REPORT_JSON = OUT_DIR / "r16_release_landing_gameplay_verification_probe_report.json"
REPORT_MD = OUT_DIR / "r16_release_landing_gameplay_verification_probe_report.md"
PACK_RESOLVER_PATH = ROOT / "data" / "aigc_battle" / "pack_resolver.json"
CURRENT_RELEASE_PATH = ROOT / "data" / "aigc_battle" / "release_channels" / "current_release.json"
ACTIVE_PROFILE_PATH = ROOT / "data" / "aigc_battle" / "runtime" / "active_profile.json"
FALLBACK_RELEASE_PATH = ROOT / "data" / "aigc_battle" / "release_channels" / "fallback_release.json"
ACCEPTANCE_DIR = ROOT / "data" / "aigc_battle" / "acceptance"
PROMOTION_DIR = ROOT / "data" / "aigc_battle" / "promotion"
PROMOTION_REVIEW_DIR = PROMOTION_DIR / "human_review_notes"
RELEASE_SWITCH_SMOKE_REPORT = ROOT / "data" / "aigc_battle" / "generated" / "release_switch" / "release_switch_smoke_report.json"
RELEASE_ROLLBACK_REPORT = ROOT / "data" / "aigc_battle" / "generated" / "release_switch" / "release_rollback_probe_report.json"


def main(argv: list[str]) -> int:
    if len(argv) != 1:
        raise SystemExit("usage: python3 tools/aigc_battle/aigc_r16_release_landing_gameplay_verification_probe.py")
    report = run_probe()
    print(json.dumps(report, ensure_ascii=False, indent=2))
    return 0 if bool(report.get("probe_pass", False)) else 1


def run_probe() -> dict[str, Any]:
    previous_current = read_json(CURRENT_RELEASE_PATH)
    previous_active = read_json(ACTIVE_PROFILE_PATH)
    fallback_before = read_json(FALLBACK_RELEASE_PATH)
    actual_switch_done = False
    rollback_performed = False

    report: dict[str, Any] = {
        "release_landing_ready": False,
        "selected_release_candidate_profile_id": TARGET_PROFILE_ID,
        "selected_release_candidate_pack_id": TARGET_PACK_ID,
        "selected_release_candidate_valid": False,
        "previous_current_profile_id": str(previous_current.get("mechanic_profile_id", "")),
        "previous_current_pack_id": str(previous_current.get("content_pack_id", "")),
        "new_current_profile_id": "",
        "new_current_pack_id": "",
        "pre_switch_acceptance_ready": False,
        "pre_switch_acceptance_pass": False,
        "pre_switch_risk_level": "",
        "pre_switch_warning_current_allowed": False,
        "dry_run_set_current_ready": False,
        "actual_set_current_ready": False,
        "current_release_written": False,
        "active_profile_written": False,
        "current_release_points_to_new_candidate": False,
        "active_profile_points_to_new_candidate": False,
        "formal_entry_uses_new_current": False,
        "gameplay_entry_verification_ready": False,
        "runtime_manifest_loaded": False,
        "sequence_template_visible": False,
        "content_pack_visible": False,
        "sequence_template_id": "",
        "content_pack_id": "",
        "expected_encounter_count": 0,
        "generated_loadout_count": 0,
        "generated_loadout_count_matches_template": False,
        "fallback_loadout_count": 0,
        "reward_coverage_complete": False,
        "post_switch_acceptance_ready": False,
        "post_switch_acceptance_pass": False,
        "post_switch_risk_level": "",
        "warning_current": False,
        "rollback_previous_current_ready": False,
        "rollback_fallback_ready": False,
        "fallback_pack_resolved": False,
        "rollback_not_performed": True,
        "rollback_available": False,
        "fallback_release_unchanged": False,
        "active_profile_matches_current_release": False,
        "forbidden_files_untouched": True,
        "scene_untouched": True,
        "probe_pass": False,
        "error_stage": "",
        "error": "",
    }

    try:
        run_serial([sys.executable, "tools/aigc_battle/build_pack_resolver.py"])
        run_serial([sys.executable, "tools/aigc_battle/build_aigc_content_index.py"])
        run_serial([sys.executable, "tools/aigc_battle/build_aigc_detail_views.py"])
        run_serial([sys.executable, "tools/aigc_battle/build_aigc_review_workspace.py"])

        resolver_entry = resolve_target_entry(TARGET_PROFILE_ID, TARGET_PACK_ID)
        acceptance_before = load_acceptance_report(TARGET_PROFILE_ID, TARGET_PACK_ID)
        promotion_report = load_promotion_report(TARGET_PROFILE_ID, TARGET_PACK_ID)
        human_review = load_human_review_note(TARGET_PROFILE_ID, TARGET_PACK_ID)
        runtime_manifest = preview_lib.read_required_json(ROOT / str(resolver_entry.get("runtime_manifest_path", "")))

        if (
            bool(promotion_report.get("promotion_allowed", False))
            and bool(promotion_report.get("promoted_to_release_candidate", False))
            and bool(acceptance_before.get("acceptance_pass", False))
            and str(human_review.get("status", "")) == "accepted"
            and not switch_lib.is_release_candidate(TARGET_PROFILE_ID, TARGET_PACK_ID)
        ):
            run_serial(
                [
                    sys.executable,
                    "tools/aigc_battle/aigc_candidate_promotion_gate.py",
                    "--profile",
                    TARGET_PROFILE_ID,
                    "--pack",
                    TARGET_PACK_ID,
                ]
            )
            promotion_report = load_promotion_report(TARGET_PROFILE_ID, TARGET_PACK_ID)

        report["selected_release_candidate_valid"] = bool(
            resolver_entry
            and bool(resolver_entry.get("resolver_entry_valid", False))
            and switch_lib.is_release_candidate(TARGET_PROFILE_ID, TARGET_PACK_ID)
            and bool(promotion_report)
            and bool(acceptance_before)
            and str(human_review.get("status", "")) == "accepted"
            and str(runtime_manifest.get("sequence_template_id", "")) == TARGET_TEMPLATE_ID
            and int(runtime_manifest.get("total_encounter_count", 0) or 0) == EXPECTED_ENCOUNTER_COUNT
        )
        if not report["selected_release_candidate_valid"]:
            raise SystemExit("target release candidate validation failed")

        run_serial(
            [
                sys.executable,
                "tools/aigc_battle/aigc_acceptance_run.py",
                "--profile",
                TARGET_PROFILE_ID,
                "--pack",
                TARGET_PACK_ID,
                "--samples",
                "1",
            ]
        )
        acceptance_pre = load_acceptance_report(TARGET_PROFILE_ID, TARGET_PACK_ID)
        report["pre_switch_acceptance_ready"] = bool(acceptance_pre.get("report_ready", False))
        report["pre_switch_acceptance_pass"] = bool(acceptance_pre.get("acceptance_pass", False))
        report["pre_switch_risk_level"] = str(acceptance_pre.get("risk_level", ""))
        report["pre_switch_warning_current_allowed"] = str(acceptance_pre.get("risk_level", "")) == "warning"
        if not report["pre_switch_acceptance_pass"]:
            raise SystemExit("pre-switch acceptance failed")

        dry_run = switch_lib.set_current_release(TARGET_PROFILE_ID, TARGET_PACK_ID, dry_run=True, auto_smoke=False)
        report["dry_run_set_current_ready"] = bool(dry_run.get("switch_allowed", False) and dry_run.get("report_ready", False))
        if not report["dry_run_set_current_ready"]:
            raise SystemExit("dry-run set-current failed")

        actual = switch_lib.set_current_release(TARGET_PROFILE_ID, TARGET_PACK_ID, dry_run=False, auto_smoke=True)
        actual_switch_done = True
        report["actual_set_current_ready"] = bool(actual.get("switch_allowed", False) and actual.get("report_ready", False))
        report["current_release_written"] = bool(actual.get("current_release_written", False))
        report["active_profile_written"] = bool(actual.get("active_profile_written", False))
        if not report["actual_set_current_ready"]:
            raise SystemExit(f"actual set-current failed: {actual.get('switch_error', '')}")

        smoke = switch_lib.smoke_current_release()
        current_after_switch = release_lib.read_release_channel("current", required=True)
        active_after_switch = preview_lib.read_active_profile()
        runtime_manifest_after = preview_lib.read_required_json(ROOT / str(current_after_switch.get("runtime_manifest_path", "")))

        report["new_current_profile_id"] = str(current_after_switch.get("mechanic_profile_id", ""))
        report["new_current_pack_id"] = str(current_after_switch.get("content_pack_id", ""))
        report["current_release_points_to_new_candidate"] = (
            report["new_current_profile_id"] == TARGET_PROFILE_ID and report["new_current_pack_id"] == TARGET_PACK_ID
        )
        report["active_profile_points_to_new_candidate"] = (
            str(active_after_switch.get("active_mechanic_profile_id", active_after_switch.get("mechanic_profile_id", "")))
            == TARGET_PROFILE_ID
            and str(active_after_switch.get("active_content_pack_id", active_after_switch.get("content_pack_id", "")))
            == TARGET_PACK_ID
        )
        report["formal_entry_uses_new_current"] = bool(smoke.get("formal_entry_uses_new_current", False))
        report["runtime_manifest_loaded"] = bool(runtime_manifest_after)
        report["sequence_template_id"] = str(runtime_manifest_after.get("sequence_template_id", ""))
        report["content_pack_id"] = str(runtime_manifest_after.get("content_pack_id", ""))
        report["sequence_template_visible"] = report["sequence_template_id"] == TARGET_TEMPLATE_ID
        report["content_pack_visible"] = report["content_pack_id"] == TARGET_PACK_ID
        report["expected_encounter_count"] = int(smoke.get("expected_encounter_count", 0))
        report["generated_loadout_count"] = int(smoke.get("generated_loadout_count", 0))
        report["generated_loadout_count_matches_template"] = (
            report["generated_loadout_count"] == EXPECTED_ENCOUNTER_COUNT == report["expected_encounter_count"]
        )
        report["fallback_loadout_count"] = int(smoke.get("fallback_loadout_count", 0))
        report["reward_coverage_complete"] = bool(smoke.get("reward_coverage_complete", False))
        report["gameplay_entry_verification_ready"] = all(
            [
                report["current_release_points_to_new_candidate"],
                report["active_profile_points_to_new_candidate"],
                report["formal_entry_uses_new_current"],
                report["runtime_manifest_loaded"],
                report["sequence_template_visible"],
                report["content_pack_visible"],
                report["generated_loadout_count_matches_template"],
                report["fallback_loadout_count"] == 0,
                report["reward_coverage_complete"],
            ]
        )
        if not report["gameplay_entry_verification_ready"]:
            raise SystemExit("gameplay entry verification failed")

        run_serial(
            [
                sys.executable,
                "tools/aigc_battle/aigc_acceptance_run.py",
                "--profile",
                TARGET_PROFILE_ID,
                "--pack",
                TARGET_PACK_ID,
                "--samples",
                "1",
                "--allow-current",
            ]
        )
        acceptance_post = load_acceptance_report(TARGET_PROFILE_ID, TARGET_PACK_ID)
        report["post_switch_acceptance_ready"] = bool(acceptance_post.get("report_ready", False))
        report["post_switch_acceptance_pass"] = bool(acceptance_post.get("acceptance_pass", False))
        report["post_switch_risk_level"] = str(acceptance_post.get("risk_level", ""))
        report["warning_current"] = str(acceptance_post.get("risk_level", "")) == "warning"
        if not report["post_switch_acceptance_ready"] or str(acceptance_post.get("risk_level", "")) == "fail":
            raise SystemExit("post-switch acceptance failed")

        rollback_probe = rollback_probe_lib.run_probe()
        report["rollback_previous_current_ready"] = bool(rollback_probe.get("previous_current_rollback_ready", False))
        report["rollback_fallback_ready"] = bool(rollback_probe.get("fallback_rollback_ready", False))
        report["fallback_pack_resolved"] = bool(rollback_probe.get("fallback_pack_resolved", False))
        report["rollback_available"] = report["rollback_previous_current_ready"] and report["rollback_fallback_ready"]

        run_serial([sys.executable, "tools/aigc_battle/build_pack_resolver.py"])
        run_serial([sys.executable, "tools/aigc_battle/build_aigc_content_index.py"])
        run_serial([sys.executable, "tools/aigc_battle/build_aigc_detail_views.py"])
        run_serial([sys.executable, "tools/aigc_battle/build_aigc_review_workspace.py"])

        final_current = read_json(CURRENT_RELEASE_PATH)
        final_active = read_json(ACTIVE_PROFILE_PATH)
        final_fallback = read_json(FALLBACK_RELEASE_PATH)
        report["new_current_profile_id"] = str(final_current.get("mechanic_profile_id", ""))
        report["new_current_pack_id"] = str(final_current.get("content_pack_id", ""))
        report["fallback_release_unchanged"] = fallback_before == final_fallback
        report["active_profile_matches_current_release"] = preview_lib.active_matches_current(final_active, final_current)
        report["rollback_not_performed"] = not rollback_performed
        report["release_landing_ready"] = True
        report["probe_pass"] = all(
            [
                report["release_landing_ready"],
                report["selected_release_candidate_valid"],
                report["pre_switch_acceptance_pass"],
                report["dry_run_set_current_ready"],
                report["actual_set_current_ready"],
                report["current_release_points_to_new_candidate"],
                report["active_profile_points_to_new_candidate"],
                report["formal_entry_uses_new_current"],
                report["gameplay_entry_verification_ready"],
                report["sequence_template_id"] == TARGET_TEMPLATE_ID,
                report["content_pack_id"] == TARGET_PACK_ID,
                report["generated_loadout_count_matches_template"],
                report["fallback_loadout_count"] == 0,
                report["reward_coverage_complete"],
                report["post_switch_acceptance_ready"],
                report["rollback_previous_current_ready"],
                report["rollback_fallback_ready"],
                report["active_profile_matches_current_release"],
                report["fallback_release_unchanged"],
            ]
        )
    except Exception as exc:  # noqa: BLE001
        report["error_stage"] = infer_error_stage(report)
        report["error"] = str(exc)
        if actual_switch_done:
            rollback = switch_lib.rollback_previous_current(dry_run=False)
            rollback_performed = bool(rollback.get("rollback_performed", False))
            if not rollback_performed:
                fallback_rollback = switch_lib.rollback_fallback(dry_run=False)
                rollback_performed = bool(fallback_rollback.get("rollback_performed", False))
        report["rollback_not_performed"] = not rollback_performed
        report["release_landing_ready"] = False
        report["probe_pass"] = False
    finally:
        final_current = read_json(CURRENT_RELEASE_PATH)
        final_active = read_json(ACTIVE_PROFILE_PATH)
        final_fallback = read_json(FALLBACK_RELEASE_PATH)
        report["new_current_profile_id"] = str(final_current.get("mechanic_profile_id", report.get("new_current_profile_id", "")))
        report["new_current_pack_id"] = str(final_current.get("content_pack_id", report.get("new_current_pack_id", "")))
        report["fallback_release_unchanged"] = fallback_before == final_fallback
        report["active_profile_matches_current_release"] = preview_lib.active_matches_current(final_active, final_current)
        report["forbidden_files_untouched"] = forbidden_files_untouched()
        report["scene_untouched"] = scene_untouched()
        write_json(REPORT_JSON, report)
        REPORT_MD.write_text(build_markdown(report), encoding="utf-8")
    return report


def resolve_target_entry(profile_id: str, content_pack_id: str) -> dict[str, Any]:
    resolver = read_json(PACK_RESOLVER_PATH)
    for entry in resolver.get("entries", []):
        if str(entry.get("mechanic_profile_id", "")) == profile_id and str(entry.get("content_pack_id", "")) == content_pack_id:
            return entry
    raise SystemExit("target pack not found in pack_resolver")


def load_acceptance_report(profile_id: str, content_pack_id: str) -> dict[str, Any]:
    path = ACCEPTANCE_DIR / f"{profile_id}__{content_pack_id}__acceptance_report.json"
    return read_json(path) if path.exists() else {}


def load_promotion_report(profile_id: str, content_pack_id: str) -> dict[str, Any]:
    path = PROMOTION_DIR / f"{profile_id}__{content_pack_id}__promotion_report.json"
    return read_json(path) if path.exists() else {}


def load_human_review_note(profile_id: str, content_pack_id: str) -> dict[str, Any]:
    path = PROMOTION_REVIEW_DIR / f"{profile_id}__{content_pack_id}.json"
    return read_json(path) if path.exists() else {}


def run_serial(command: list[str]) -> None:
    subprocess.run(command, cwd=ROOT, check=True)


def infer_error_stage(report: dict[str, Any]) -> str:
    if not report.get("pre_switch_acceptance_pass", False):
        return "pre_switch_acceptance"
    if not report.get("dry_run_set_current_ready", False):
        return "dry_run_set_current"
    if not report.get("actual_set_current_ready", False):
        return "actual_set_current"
    if not report.get("gameplay_entry_verification_ready", False):
        return "gameplay_entry_verification"
    if not report.get("post_switch_acceptance_ready", False):
        return "post_switch_acceptance"
    return "runtime"


def forbidden_files_untouched() -> bool:
    blocked = {
        "scripts/combat_resolver.gd",
        "scripts/battle_state_machine.gd",
        "scripts/card_data.gd",
        "scripts/fighter_data.gd",
    }
    changed = subprocess.run(
        ["git", "diff", "--name-only", "--", *sorted(blocked)],
        cwd=ROOT,
        check=True,
        capture_output=True,
        text=True,
    ).stdout.splitlines()
    return not any(line.strip() for line in changed)


def scene_untouched() -> bool:
    changed = subprocess.run(
        ["git", "diff", "--name-only", "--", "*.tscn"],
        cwd=ROOT,
        check=True,
        capture_output=True,
        text=True,
    ).stdout.splitlines()
    return not any(line.strip() for line in changed)


def read_json(path: Path) -> dict[str, Any]:
    if not path.exists():
        return {}
    return json.loads(path.read_text(encoding="utf-8"))


def write_json(path: Path, payload: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def build_markdown(report: dict[str, Any]) -> str:
    lines = ["# R16 Release Landing & Gameplay Verification", ""]
    for key in [
        "release_landing_ready",
        "selected_release_candidate_valid",
        "pre_switch_acceptance_pass",
        "dry_run_set_current_ready",
        "actual_set_current_ready",
        "formal_entry_uses_new_current",
        "gameplay_entry_verification_ready",
        "sequence_template_id",
        "content_pack_id",
        "generated_loadout_count_matches_template",
        "fallback_loadout_count",
        "reward_coverage_complete",
        "post_switch_acceptance_ready",
        "rollback_previous_current_ready",
        "rollback_fallback_ready",
        "active_profile_matches_current_release",
        "probe_pass",
    ]:
        lines.append(f"- {key}: `{report.get(key, '')}`")
    if report.get("error"):
        lines.extend(["", f"- error_stage: `{report.get('error_stage', '')}`", f"- error: `{report.get('error', '')}`"])
    return "\n".join(lines) + "\n"


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
