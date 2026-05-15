#!/usr/bin/env python3
from __future__ import annotations

import argparse
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


TARGET_CURRENT_PROFILE_ID = "weapon_followup_v0_1"
TARGET_CURRENT_PACK_ID = "weapon_followup_v0_1__formal_sequence_12_fast_v1__release_drill_005"
TARGET_CURRENT_TEMPLATE_ID = "formal_sequence_12_fast_v1"
TARGET_CURRENT_BUILD_VARIANT = "release_drill_005"
TARGET_EXPECTED_ENCOUNTER_COUNT = 12
PREVIOUS_CURRENT_PROFILE_ID = "weapon_followup_v0_1"
PREVIOUS_CURRENT_PACK_ID = "weapon_followup_balance_release_007"
FALLBACK_PROFILE_ID = "posture_opening_pressure_v0_1"
FALLBACK_PACK_ID = "posture_opening_pressure_v0_1_formal_sequence_pack_001"
WARNING_PACK_ID = "r9_fast_candidate_pack_001"

DATA_DIR = ROOT / "data" / "aigc_battle"
PRODUCTION_CONTRACT_DIR = DATA_DIR / "production_contract"
GENERATED_DIR = DATA_DIR / "generated" / "production_closeout"
PACK_RESOLVER_PATH = DATA_DIR / "pack_resolver.json"
CURRENT_RELEASE_PATH = DATA_DIR / "release_channels" / "current_release.json"
ACTIVE_PROFILE_PATH = DATA_DIR / "runtime" / "active_profile.json"
FALLBACK_RELEASE_PATH = DATA_DIR / "release_channels" / "fallback_release.json"
ACCEPTANCE_REPORT_PATH = DATA_DIR / "generated" / "acceptance" / "latest_acceptance_report.json"
SMOKE_REPORT_PATH = DATA_DIR / "generated" / "release_switch" / "release_switch_smoke_report.json"
PREVIEW_RESTORE_REPORT_PATH = DATA_DIR / "generated" / "preview_runtime" / "preview_restore_probe_report.json"
PROMOTION_PROBE_REPORT_PATH = DATA_DIR / "generated" / "promotion" / "candidate_promotion_probe_report.json"
ROLLBACK_REPORT_PATH = DATA_DIR / "generated" / "release_switch" / "release_rollback_probe_report.json"

PLAN_JSON = GENERATED_DIR / "production_closeout_plan.json"
PLAN_MD = GENERATED_DIR / "production_closeout_plan.md"
CLEANUP_JSON = GENERATED_DIR / "production_closeout_cleanup_report.json"
CLEANUP_MD = GENERATED_DIR / "production_closeout_cleanup_report.md"
VERIFY_JSON = GENERATED_DIR / "production_closeout_verification_report.json"
VERIFY_MD = GENERATED_DIR / "production_closeout_verification_report.md"


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description="production closeout tool")
    parser.add_argument("--plan", action="store_true")
    parser.add_argument("--apply-safe-cleanup", action="store_true")
    parser.add_argument("--verify", action="store_true")
    args = parser.parse_args(argv[1:])

    selected = [args.plan, args.apply_safe_cleanup, args.verify]
    if sum(1 for item in selected if item) != 1:
        raise SystemExit("exactly one of --plan / --apply-safe-cleanup / --verify is required")

    if args.plan:
        payload = build_cleanup_plan()
        write_json(PLAN_JSON, payload)
        PLAN_MD.write_text(build_markdown("Production Closeout Plan", payload), encoding="utf-8")
    elif args.apply_safe_cleanup:
        payload = apply_safe_cleanup()
        write_json(CLEANUP_JSON, payload)
        CLEANUP_MD.write_text(build_markdown("Production Closeout Cleanup Report", payload), encoding="utf-8")
    else:
        payload = verify_closeout()
        write_json(VERIFY_JSON, payload)
        VERIFY_MD.write_text(build_markdown("Production Closeout Verification Report", payload), encoding="utf-8")

    print(json.dumps(payload, ensure_ascii=False, indent=2))
    return 0 if bool(payload.get("report_ready", payload.get("production_closeout_ready", False))) else 1


def build_cleanup_plan() -> dict[str, Any]:
    inventory = read_required_json(PRODUCTION_CONTRACT_DIR / "deprecated_probe_inventory.json")
    policy = read_required_json(PRODUCTION_CONTRACT_DIR / "generated_file_policy.json")
    current_release = read_required_json(CURRENT_RELEASE_PATH)
    active_profile = read_required_json(ACTIVE_PROFILE_PATH)
    fallback_release = read_required_json(FALLBACK_RELEASE_PATH)
    resolver = read_required_json(PACK_RESOLVER_PATH)

    local_cleanable_count = int(inventory.get("local_cleanable_count", 0) or 0)
    safe_paths = [resolve_inventory_path(path) for path in inventory.get("safe_to_delete_now", [])]
    cleanup_candidates = [path for path in safe_paths if path.exists()]
    protected_paths = build_protected_paths(current_release, active_profile, fallback_release)

    return {
        "generated_at": now_iso(),
        "cleanup_plan_ready": True,
        "current_release_pack": str(current_release.get("content_pack_id", "")),
        "active_profile_pack": str(active_profile.get("active_content_pack_id", "")),
        "fallback_release_pack": str(fallback_release.get("content_pack_id", "")),
        "resolver_entry_count": int(len(resolver.get("entries", []))),
        "generated_file_policy_ready": bool(policy.get("generated_file_policy_ready", False)),
        "local_cleanable_count_before": local_cleanable_count,
        "safe_cleanup_candidates": [to_relative(path) for path in cleanup_candidates],
        "protected_file_count": len(protected_paths),
        "protected_paths": protected_paths,
        "report_ready": True,
    }


def apply_safe_cleanup() -> dict[str, Any]:
    plan = build_cleanup_plan()
    inventory = read_required_json(PRODUCTION_CONTRACT_DIR / "deprecated_probe_inventory.json")
    deleted_paths: list[str] = []
    cleanup_error = ""
    try:
        for relative_path in plan.get("safe_cleanup_candidates", []):
            path = ROOT / str(relative_path)
            if path.exists():
                path.unlink()
                deleted_paths.append(relative_path)
    except Exception as exc:  # noqa: BLE001
        cleanup_error = str(exc)

    return {
        "generated_at": now_iso(),
        "cleanup_plan_ready": bool(plan.get("cleanup_plan_ready", False)),
        "safe_cleanup_applied": cleanup_error == "",
        "local_cleanable_count_before": int(plan.get("local_cleanable_count_before", 0)),
        "local_cleanable_removed_count": len(deleted_paths),
        "protected_file_count": int(plan.get("protected_file_count", 0)),
        "skipped_historical_report_count": int(inventory.get("historical_report_count", 0) or 0),
        "skipped_deprecated_candidate_count": int(inventory.get("deprecated_candidate_count", 0) or 0),
        "deleted_paths": deleted_paths,
        "protected_paths": plan.get("protected_paths", []),
        "cleanup_error": cleanup_error,
        "report_ready": cleanup_error == "",
    }


def verify_closeout() -> dict[str, Any]:
    current_release = read_required_json(CURRENT_RELEASE_PATH)
    active_profile = read_required_json(ACTIVE_PROFILE_PATH)
    fallback_release = read_required_json(FALLBACK_RELEASE_PATH)
    resolver = read_required_json(PACK_RESOLVER_PATH)

    target_entry = resolve_entry(resolver, TARGET_CURRENT_PROFILE_ID, TARGET_CURRENT_PACK_ID)
    previous_entry = resolve_entry(resolver, PREVIOUS_CURRENT_PROFILE_ID, PREVIOUS_CURRENT_PACK_ID)
    fallback_entry = resolve_entry(resolver, FALLBACK_PROFILE_ID, FALLBACK_PACK_ID)
    warning_entry = resolve_entry(resolver, TARGET_CURRENT_PROFILE_ID, WARNING_PACK_ID)

    resolver_channel_consistency_fixed = bool(
        target_entry
        and str(target_entry.get("channel", "")) == "current"
        and bool(target_entry.get("active", False))
        and str(target_entry.get("release_status", "")) == "current"
        and bool(target_entry.get("release_landing_current", False))
        and bool(target_entry.get("gameplay_entry_verified", False))
        and bool(target_entry.get("resolver_channel_consistency_valid", False))
    )
    current_release_marker_correct = bool(target_entry and target_entry.get("current_release_marker", False))
    previous_current_marker_correct = bool(
        previous_entry
        and bool(previous_entry.get("previous_current_marker", False))
        and not bool(previous_entry.get("current_release_marker", False))
    )
    fallback_release_marker_correct = bool(fallback_entry and fallback_entry.get("fallback_release_marker", False))
    warning_pack_still_blocked = bool(
        warning_entry
        and not bool(warning_entry.get("release_candidate_valid", False))
        and not bool(warning_entry.get("release_switch_allowed", False))
    )

    run_serial(
        [
            sys.executable,
            "tools/aigc_battle/aigc_acceptance_run.py",
            "--profile",
            TARGET_CURRENT_PROFILE_ID,
            "--pack",
            TARGET_CURRENT_PACK_ID,
            "--samples",
            "1",
            "--allow-current",
        ]
    )
    run_serial(
        [
            sys.executable,
            "tools/aigc_battle/aigc_release_switch_smoke_probe.py",
            "--profile",
            TARGET_CURRENT_PROFILE_ID,
            "--pack",
            TARGET_CURRENT_PACK_ID,
        ]
    )
    run_serial([sys.executable, "tools/aigc_battle/aigc_preview_restore_probe.py"])
    run_serial([sys.executable, "tools/aigc_battle/aigc_candidate_promotion_probe.py"])
    run_serial([sys.executable, "tools/aigc_battle/aigc_release_rollback_probe.py"])

    acceptance = read_required_json(ACCEPTANCE_REPORT_PATH)
    smoke = read_required_json(SMOKE_REPORT_PATH)
    preview_restore = read_required_json(PREVIEW_RESTORE_REPORT_PATH)
    promotion_probe = read_required_json(PROMOTION_PROBE_REPORT_PATH)
    rollback_probe = read_required_json(ROLLBACK_REPORT_PATH)

    active_matches = preview_lib.active_matches_current(active_profile, current_release)
    fallback_unchanged = (
        str(fallback_release.get("mechanic_profile_id", "")) == FALLBACK_PROFILE_ID
        and str(fallback_release.get("content_pack_id", "")) == FALLBACK_PACK_ID
    )
    current_is_release_drill = (
        str(current_release.get("mechanic_profile_id", "")) == TARGET_CURRENT_PROFILE_ID
        and str(current_release.get("content_pack_id", "")) == TARGET_CURRENT_PACK_ID
        and str(current_release.get("sequence_template_id", "")) == TARGET_CURRENT_TEMPLATE_ID
        and str(current_release.get("build_variant", "")) == TARGET_CURRENT_BUILD_VARIANT
    )

    final_acceptance_status = str(acceptance.get("risk_level", ""))
    production_closeout_ready = all(
        [
            resolver_channel_consistency_fixed,
            current_release_marker_correct,
            previous_current_marker_correct,
            fallback_release_marker_correct,
            warning_pack_still_blocked,
            bool(acceptance.get("acceptance_pass", False)),
            bool(smoke.get("smoke_pass", False)),
            bool(preview_restore.get("probe_pass", False)),
            bool(promotion_probe.get("probe_pass", False)),
            bool(rollback_probe.get("probe_pass", False)),
            current_is_release_drill,
            active_matches,
            fallback_unchanged,
        ]
    )

    return {
        "generated_at": now_iso(),
        "production_closeout_ready": production_closeout_ready,
        "resolver_channel_consistency_fixed": resolver_channel_consistency_fixed,
        "current_release_marker_correct": current_release_marker_correct,
        "previous_current_marker_correct": previous_current_marker_correct,
        "fallback_release_marker_correct": fallback_release_marker_correct,
        "warning_pack_still_blocked": warning_pack_still_blocked,
        "final_current_acceptance_pass": bool(acceptance.get("acceptance_pass", False)),
        "final_current_smoke_pass": bool(smoke.get("smoke_pass", False)),
        "final_preview_restore_pass": bool(preview_restore.get("probe_pass", False)),
        "final_promotion_negative_cases_pass": bool(promotion_probe.get("probe_pass", False)),
        "final_release_rollback_pass": bool(rollback_probe.get("probe_pass", False)),
        "active_profile_matches_current_release": active_matches,
        "fallback_release_unchanged": fallback_unchanged,
        "current_release_is_release_drill_005": current_is_release_drill,
        "current_landed_pack": TARGET_CURRENT_PACK_ID,
        "current_sequence_template": TARGET_CURRENT_TEMPLATE_ID,
        "current_encounter_count": TARGET_EXPECTED_ENCOUNTER_COUNT,
        "previous_current_pack": PREVIOUS_CURRENT_PACK_ID,
        "final_acceptance_status": final_acceptance_status,
        "report_ready": production_closeout_ready,
    }


def run_serial(command: list[str]) -> None:
    completed = subprocess.run(command, cwd=ROOT, text=True, capture_output=True)
    if completed.returncode != 0:
        raise SystemExit(
            f"command failed: {' '.join(command)}\nstdout:\n{completed.stdout}\nstderr:\n{completed.stderr}"
        )


def resolve_entry(resolver: dict[str, Any], profile_id: str, content_pack_id: str) -> dict[str, Any]:
    for entry in resolver.get("entries", []):
        if (
            str(entry.get("mechanic_profile_id", "")) == profile_id
            and str(entry.get("content_pack_id", "")) == content_pack_id
        ):
            return entry
    return {}


def build_protected_paths(
    current_release: dict[str, Any],
    active_profile: dict[str, Any],
    fallback_release: dict[str, Any],
) -> list[str]:
    protected = {
        to_relative(CURRENT_RELEASE_PATH),
        to_relative(FALLBACK_RELEASE_PATH),
        to_relative(ACTIVE_PROFILE_PATH),
        to_relative(PACK_RESOLVER_PATH),
        "data/aigc_battle/production_contract",
        "data/aigc_battle/acceptance",
        "data/aigc_battle/promotion",
        "data/aigc_battle/release_switch",
        "data/aigc_battle/generated/release_landing",
        "data/aigc_battle/generated/review",
        "data/aigc_battle/generated/details",
        "data/aigc_battle/generated/aigc_content_index.json",
        "data/aigc_battle/generated/aigc_content_index.md",
        "data/aigc_battle/generated/aigc_content_index.html",
    }
    for payload in [current_release, fallback_release]:
        runtime_manifest_path = str(payload.get("runtime_manifest_path", ""))
        if runtime_manifest_path:
            protected.add(runtime_manifest_path)
            protected.add(str(Path(runtime_manifest_path).parent))
    active_runtime_manifest_path = str(active_profile.get("runtime_manifest_path", ""))
    if active_runtime_manifest_path:
        protected.add(active_runtime_manifest_path)
        protected.add(str(Path(active_runtime_manifest_path).parent))
    protected.add("data/aigc_battle/generated/weapon_followup_v0_1/packs/weapon_followup_balance_release_007")
    protected.add("data/aigc_battle/generated/weapon_followup_v0_1/packs/weapon_followup_v0_1__formal_sequence_12_fast_v1__release_drill_005")
    return sorted(protected)


def resolve_inventory_path(relative_path: str) -> Path:
    candidate = str(relative_path).strip()
    if candidate.startswith("/"):
        return Path(candidate)
    if candidate.startswith("data/"):
        return ROOT / candidate
    return DATA_DIR / candidate


def read_required_json(path: Path) -> dict[str, Any]:
    if not path.exists():
        raise SystemExit(f"required file not found: {path}")
    return json.loads(path.read_text(encoding="utf-8"))


def write_json(path: Path, payload: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def build_markdown(title: str, payload: dict[str, Any]) -> str:
    lines = [f"# {title}", ""]
    for key, value in payload.items():
        if isinstance(value, (dict, list)):
            lines.append(f"- {key}:")
            lines.append("```json")
            lines.append(json.dumps(value, ensure_ascii=False, indent=2))
            lines.append("```")
        else:
            lines.append(f"- {key}: `{value}`")
    lines.append("")
    return "\n".join(lines)


def to_relative(path: Path) -> str:
    try:
        return path.relative_to(ROOT).as_posix()
    except ValueError:
        return path.as_posix()


def now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
