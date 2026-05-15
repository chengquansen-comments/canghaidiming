#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import os
import shutil
import subprocess
import sys
import tempfile
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from tools.aigc_battle import aigc_preview_runtime_control as preview_lib
from tools.aigc_battle import aigc_release_gate as release_lib
from tools.aigc_battle import switch_active_profile as switch_lib


PACK_RESOLVER_PATH = ROOT / "data" / "aigc_battle" / "pack_resolver.json"
PROMOTION_DIR = ROOT / "data" / "aigc_battle" / "promotion"
PROMOTION_REVIEW_DIR = PROMOTION_DIR / "human_review_notes"
ACCEPTANCE_DIR = ROOT / "data" / "aigc_battle" / "acceptance"
RELEASE_SWITCH_DIR = ROOT / "data" / "aigc_battle" / "release_switch"
GENERATED_DIR = ROOT / "data" / "aigc_battle" / "generated" / "release_switch"
HISTORY_PATH = RELEASE_SWITCH_DIR / "release_switch_history.jsonl"
LATEST_JSON = RELEASE_SWITCH_DIR / "latest_release_switch_report.json"
LATEST_MD = RELEASE_SWITCH_DIR / "latest_release_switch_report.md"
SMOKE_JSON = GENERATED_DIR / "release_switch_smoke_report.json"
SMOKE_MD = GENERATED_DIR / "release_switch_smoke_report.md"
NEGATIVE_JSON = GENERATED_DIR / "release_switch_negative_cases_report.json"
NEGATIVE_MD = GENERATED_DIR / "release_switch_negative_cases_report.md"
ROLLBACK_JSON = GENERATED_DIR / "release_rollback_probe_report.json"
ROLLBACK_MD = GENERATED_DIR / "release_rollback_probe_report.md"
FORMAL_ENTRY_REPORT = ROOT / "data" / "aigc_battle" / "generated" / "release_smoke" / "formal_entry_release_probe_report.json"


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description="release switch console")
    parser.add_argument("--list-candidates", action="store_true")
    parser.add_argument("--status", action="store_true")
    parser.add_argument("--set-current", action="store_true")
    parser.add_argument("--smoke-current", action="store_true")
    parser.add_argument("--rollback-previous-current", action="store_true")
    parser.add_argument("--rollback-fallback", action="store_true")
    parser.add_argument("--profile")
    parser.add_argument("--pack")
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args(argv[1:])

    if args.list_candidates:
        payload = list_release_candidates()
    elif args.status:
        payload = switch_status()
    elif args.set_current:
        if not args.profile or not args.pack:
            raise SystemExit("--set-current requires --profile and --pack")
        payload = set_current_release(args.profile, args.pack, dry_run=bool(args.dry_run), auto_smoke=True)
    elif args.smoke_current:
        payload = smoke_current_release()
    elif args.rollback_previous_current:
        payload = rollback_previous_current(dry_run=bool(args.dry_run))
    elif args.rollback_fallback:
        payload = rollback_fallback(dry_run=bool(args.dry_run))
    else:
        raise SystemExit("one action flag is required")
    print(json.dumps(payload, ensure_ascii=False, indent=2))
    return 0 if bool(payload.get("report_ready", True)) else 1


def list_release_candidates() -> dict[str, Any]:
    resolver = preview_lib.read_required_json(PACK_RESOLVER_PATH)
    seen: set[tuple[str, str]] = set()
    candidates: list[dict[str, Any]] = []
    for entry in resolver.get("entries", []):
        profile_id = str(entry.get("mechanic_profile_id", ""))
        content_pack_id = str(entry.get("content_pack_id", ""))
        key = (profile_id, content_pack_id)
        if key in seen:
            continue
        if is_release_candidate_entry(entry):
            seen.add(key)
            candidates.append(
                {
                    "mechanic_profile_id": profile_id,
                    "content_pack_id": content_pack_id,
                    "sequence_template_id": str(entry.get("sequence_template_id", "")),
                    "build_variant": str(entry.get("build_variant", "")),
                    "channel": str(entry.get("channel", "")),
                    "runtime_manifest_path": str(entry.get("runtime_manifest_path", "")),
                    "validation_report_path": str(entry.get("validation_report_path", "")),
                    "release_candidate_valid": True,
                    "current_release_marker": bool(entry.get("channel") == "current"),
                }
            )
    payload = {
        "release_candidate_list_ready": True,
        "release_candidate_count": len(candidates),
        "candidates": candidates,
        "report_ready": True,
    }
    append_history(
        action="list_candidates",
        target_profile_id="",
        target_content_pack_id="",
        previous_current=read_current_release_ref(),
        new_current=read_current_release_ref(),
        result="ok",
        error="",
    )
    return payload


def switch_status() -> dict[str, Any]:
    channels = release_lib.show_channels()
    latest_report = preview_lib.read_json(LATEST_JSON) if LATEST_JSON.exists() else {}
    candidates = list_release_candidates()
    current = channels.get("current_release", {})
    fallback = channels.get("fallback_release", {})
    active = preview_lib.read_active_profile()
    return {
        "current_release": current,
        "fallback_release": fallback,
        "active_profile": active,
        "release_candidate_count": int(candidates.get("release_candidate_count", 0)),
        "latest_release_switch_report": latest_report,
        "current_release_matches_active_profile": preview_lib.active_matches_current(active, current),
        "rollback_available": bool(current and fallback),
        "report_ready": True,
    }


def set_current_release(
    profile_id: str,
    content_pack_id: str,
    *,
    dry_run: bool = False,
    auto_smoke: bool = True,
) -> dict[str, Any]:
    switch_lib.ensure_safe_id(profile_id, "profile_id")
    switch_lib.ensure_safe_id(content_pack_id, "content_pack_id")
    current_before = release_lib.read_release_channel("current", required=True)
    fallback = release_lib.read_release_channel("fallback", required=True)
    report = build_base_report("set_current", profile_id, content_pack_id, dry_run, current_before, fallback)
    try:
        entry = resolve_switch_entry(profile_id, content_pack_id)
        promotion_report = load_promotion_report(profile_id, content_pack_id)
        acceptance_report = load_acceptance_report(profile_id, content_pack_id)
        human_review = load_human_review_note(profile_id, content_pack_id)
        validated = release_lib.validate_release_pack(profile_id, content_pack_id, allow_archived=False)

        report["target_sequence_template_id"] = str(validated.get("sequence_template_id", entry.get("sequence_template_id", "")))
        report["target_build_variant"] = str(validated.get("build_variant", entry.get("build_variant", "")))
        report["release_candidate_valid"] = True
        report["promotion_report_found"] = True
        report["acceptance_report_found"] = bool(acceptance_report)
        report["human_review_accepted"] = str(human_review.get("status", "")) == "accepted"
        report["switch_allowed"] = True
        report["idempotent_current_activation"] = (
            profile_id == str(current_before.get("mechanic_profile_id", ""))
            and content_pack_id == str(current_before.get("content_pack_id", ""))
        )

        if dry_run:
            report["current_release_written"] = False
            report["active_profile_written"] = False
            append_history(
                action="dry_run_set_current",
                target_profile_id=profile_id,
                target_content_pack_id=content_pack_id,
                previous_current=current_ref_from_channel(current_before),
                new_current={"mechanic_profile_id": profile_id, "content_pack_id": content_pack_id},
                result="ok",
                error="",
            )
            return finalize_report(report)

        release_lib.set_release_channel("current", profile_id, content_pack_id)
        activation = release_lib.activate_current_release()
        report["current_release_written"] = True
        report["active_profile_written"] = bool(activation.get("active_profile_matches_current_release", False))

        append_history(
            action="set_current",
            target_profile_id=profile_id,
            target_content_pack_id=content_pack_id,
            previous_current=current_ref_from_channel(current_before),
            new_current={"mechanic_profile_id": profile_id, "content_pack_id": content_pack_id},
            result="ok",
            error="",
        )

        if auto_smoke:
            smoke = smoke_current_release()
            report["formal_entry_smoke_pass"] = bool(smoke.get("smoke_pass", False))
            report["formal_entry_uses_new_current"] = bool(smoke.get("formal_entry_uses_new_current", False))
            report["generated_loadout_count"] = int(smoke.get("generated_loadout_count", 0))
            report["expected_encounter_count"] = int(smoke.get("expected_encounter_count", 0))
            report["fallback_loadout_count"] = int(smoke.get("fallback_loadout_count", 0))
            report["reward_coverage_complete"] = bool(smoke.get("reward_coverage_complete", False))
            if not report["formal_entry_smoke_pass"]:
                report["switch_error"] = "formal entry smoke failed after set-current"
                rollback_payload = rollback_after_failed_smoke(current_before)
                report["rollback_performed"] = bool(rollback_payload.get("rollback_performed", False))
            else:
                # Keep candidate eligibility visible after idempotent/validated activation.
                release_lib.mark_release_candidate(profile_id, content_pack_id)
        return finalize_report(report)
    except SystemExit as exc:
        report["switch_error"] = str(exc)
        report["switch_allowed"] = False
        append_history(
            action="switch_blocked",
            target_profile_id=profile_id,
            target_content_pack_id=content_pack_id,
            previous_current=current_ref_from_channel(current_before),
            new_current=current_ref_from_channel(current_before),
            result="blocked",
            error=str(exc),
        )
        return finalize_report(report)
    except Exception as exc:  # noqa: BLE001
        report["switch_error"] = str(exc)
        report["switch_allowed"] = False
        append_history(
            action="switch_blocked",
            target_profile_id=profile_id,
            target_content_pack_id=content_pack_id,
            previous_current=current_ref_from_channel(current_before),
            new_current=current_ref_from_channel(current_before),
            result="blocked",
            error=str(exc),
        )
        return finalize_report(report)


def smoke_current_release() -> dict[str, Any]:
    current = release_lib.read_release_channel("current", required=True)
    current_before = current_ref_from_channel(current)
    result = {
        "release_switch_run_id": f"release_switch_smoke_{int(datetime.now(timezone.utc).timestamp())}",
        "timestamp": now_iso(),
        "action": "smoke_current",
        "target_profile_id": str(current.get("mechanic_profile_id", "")),
        "target_content_pack_id": str(current.get("content_pack_id", "")),
        "target_sequence_template_id": str(current.get("sequence_template_id", "")),
        "target_build_variant": str(current.get("build_variant", "")),
        "release_candidate_valid": is_release_candidate(current_before["mechanic_profile_id"], current_before["content_pack_id"]),
        "promotion_report_found": promotion_report_path(current_before["mechanic_profile_id"], current_before["content_pack_id"]).exists(),
        "acceptance_report_found": acceptance_report_path(current_before["mechanic_profile_id"], current_before["content_pack_id"]).exists(),
        "human_review_accepted": str(load_human_review_note(current_before["mechanic_profile_id"], current_before["content_pack_id"]).get("status", "")) == "accepted",
        "dry_run": False,
        "idempotent_current_activation": True,
        "previous_current": current_before,
        "new_current": current_before,
        "fallback_release": current_ref_from_channel(release_lib.read_release_channel("fallback", required=True)),
        "current_release_written": False,
        "active_profile_written": False,
        "formal_entry_smoke_pass": False,
        "generated_loadout_count": 0,
        "expected_encounter_count": 0,
        "fallback_loadout_count": 0,
        "reward_coverage_complete": False,
        "rollback_available": True,
        "rollback_performed": False,
        "current_release_matches_active_profile": False,
        "switch_allowed": True,
        "switch_error": "",
        "smoke_pass": False,
        "report_ready": True,
    }
    try:
        formal = run_current_formal_entry_probe(current)
        write_json(FORMAL_ENTRY_REPORT, formal)
        result["formal_entry_smoke_pass"] = bool(formal.get("probe_pass", False))
        result["formal_entry_uses_new_current"] = bool(formal.get("formal_entry_uses_release_pack", False))
        result["generated_loadout_count"] = int(formal.get("full_sequence_generated_loadout_count", 0))
        result["expected_encounter_count"] = int(formal.get("formal_encounter_total_count", 0))
        result["fallback_loadout_count"] = int(formal.get("fallback_loadout_count", 0))
        result["reward_coverage_complete"] = bool(formal.get("reward_coverage_complete", False))
        result["current_release_matches_active_profile"] = bool(formal.get("active_profile_matches_current_release", False))
        result["smoke_pass"] = (
            result["formal_entry_smoke_pass"]
            and result["formal_entry_uses_new_current"]
            and result["fallback_loadout_count"] == 0
            and result["reward_coverage_complete"]
            and result["current_release_matches_active_profile"]
        )
        if not result["smoke_pass"]:
            rollback_payload = rollback_after_failed_smoke(current)
            result["rollback_performed"] = bool(rollback_payload.get("rollback_performed", False))
            result["switch_error"] = "formal entry smoke failed"
        append_history(
            action="smoke_current",
            target_profile_id=str(current.get("mechanic_profile_id", "")),
            target_content_pack_id=str(current.get("content_pack_id", "")),
            previous_current=current_before,
            new_current=current_before,
            result="ok" if result["smoke_pass"] else "fail",
            error=result["switch_error"],
        )
    except Exception as exc:  # noqa: BLE001
        result["switch_error"] = str(exc)
        rollback_payload = rollback_after_failed_smoke(current)
        result["rollback_performed"] = bool(rollback_payload.get("rollback_performed", False))
        append_history(
            action="smoke_current",
            target_profile_id=str(current.get("mechanic_profile_id", "")),
            target_content_pack_id=str(current.get("content_pack_id", "")),
            previous_current=current_before,
            new_current=current_before,
            result="fail",
            error=str(exc),
        )
    write_json(SMOKE_JSON, result)
    SMOKE_MD.write_text(build_markdown(result), encoding="utf-8")
    write_json(LATEST_JSON, result)
    LATEST_MD.write_text(build_markdown(result), encoding="utf-8")
    return result


def run_current_formal_entry_probe(current: dict[str, Any]) -> dict[str, Any]:
    runtime_manifest_path = ROOT / str(current.get("runtime_manifest_path", ""))
    if not runtime_manifest_path.exists():
        raise SystemExit(f"current runtime manifest missing: {runtime_manifest_path}")
    generated_dir = runtime_manifest_path.parent
    inventory_path = generated_dir / "formal_sequence_inventory.generated.json"
    if not inventory_path.exists():
        raise SystemExit(f"formal entry probe missing file: {inventory_path}")
    runtime_manifest = preview_lib.read_required_json(runtime_manifest_path)
    expected_count = int(runtime_manifest.get("total_encounter_count", 0) or 0)

    godot_bin = shutil.which("godot4") or shutil.which("godot")
    if godot_bin is None:
        raise SystemExit("godot/godot4 command not found")

    temp_report = FORMAL_ENTRY_REPORT.with_name("formal_entry_release_probe_runtime.json")
    inventory_res_path = "res://" + inventory_path.relative_to(ROOT).as_posix()
    with tempfile.TemporaryDirectory(prefix="aigc_release_switch_smoke_") as temp_dir:
        temp_script_path = Path(temp_dir) / "formal_entry_current_probe.gd"
        temp_script_path.write_text(
            build_current_formal_entry_probe_script(
                inventory_res_path=inventory_res_path,
                report_json_path=temp_report,
                expected_count=expected_count,
                expected_pack_id=str(current.get("content_pack_id", "")),
            ),
            encoding="utf-8",
        )
        env = os.environ.copy()
        env.update({"HOME": "/private/tmp"})
        completed = subprocess.run(
            [godot_bin, "--headless", "--path", str(ROOT), "--script", str(temp_script_path)],
            cwd=ROOT,
            env=env,
            capture_output=True,
            text=True,
        )
    if not temp_report.exists():
        stderr = completed.stderr.strip() if completed.stderr else ""
        stdout = completed.stdout.strip() if completed.stdout else ""
        detail = stderr or stdout or f"godot probe exited with code {completed.returncode}"
        raise SystemExit(detail)
    godot_report = preview_lib.read_required_json(temp_report)
    godot_report["godot_exit_code"] = int(completed.returncode)
    if temp_report.exists():
        temp_report.unlink()
    return {
        "current_release_loaded": True,
        "active_profile_matches_current_release": preview_lib.active_matches_current(preview_lib.read_active_profile(), current),
        "formal_entry_probe_ready": True,
        "formal_entry_uses_release_pack": bool(godot_report.get("formal_entry_uses_release_pack", False)),
        "formal_entry_not_debug_only": bool(godot_report.get("formal_entry_not_debug_only", False)),
        "formal_entry_not_mini_route": bool(godot_report.get("formal_entry_not_mini_route", False)),
        "full_sequence_generated_loadout_count": int(godot_report.get("full_sequence_generated_loadout_count", 0)),
        "formal_encounter_total_count": int(godot_report.get("formal_encounter_total_count", 0)),
        "fallback_loadout_count": int(godot_report.get("fallback_loadout_count", 0)),
        "reward_coverage_complete": bool(godot_report.get("reward_coverage_complete", False)),
        "release_runtime_primitive_ready": bool(godot_report.get("release_runtime_primitive_ready", False)),
        "release_pack_source_confirmed": bool(godot_report.get("release_pack_source_confirmed", False)),
        "probe_pass": bool(godot_report.get("probe_pass", False)),
    }


def build_current_formal_entry_probe_script(
    *,
    inventory_res_path: str,
    report_json_path: Path,
    expected_count: int,
    expected_pack_id: str,
) -> str:
    return r'''extends SceneTree

const Loader = preload("res://scripts/aigc_battle/aigc_battle_runtime_manifest_loader.gd")
const NarrativeBattleContext = preload("res://scripts/narrative_battle_context.gd")
const MainVisual = preload("res://scenes/MainVisual.tscn")
const INVENTORY_PATH = "__INVENTORY_PATH__"
const REPORT_PATH = "__REPORT_PATH__"
const EXPECTED_COUNT = __EXPECTED_COUNT__
const EXPECTED_PACK_ID = "__EXPECTED_PACK_ID__"

func _init() -> void:
	var report := {
		"formal_entry_uses_release_pack": false,
		"formal_entry_not_debug_only": false,
		"formal_entry_not_mini_route": false,
		"full_sequence_generated_loadout_count": 0,
		"formal_encounter_total_count": 0,
		"fallback_loadout_count": 0,
		"reward_coverage_complete": false,
		"release_runtime_primitive_ready": false,
		"release_pack_source_confirmed": false,
		"probe_pass": false
	}
	if not Loader.load_active_manifest():
		report["error"] = Loader.get_last_error()
		_write_report(report)
		quit(1)
		return
	var inventory: Array = _read_inventory()
	var summary: Dictionary = Loader.get_manifest_summary()
	report["formal_encounter_total_count"] = inventory.size()
	var runtime_primitives: Array = summary.get("runtime_primitives", [])
	var source_ok := true
	var release_pack_ok := true
	var primitive_ok := inventory.size() > 0
	var reward_ok := inventory.size() > 0
	for item_variant in inventory:
		var item: Dictionary = item_variant
		var encounter_id := str(item.get("formal_encounter_id", ""))
		var battle_id := str(item.get("formal_battle_id", ""))
		var node_id := str(item.get("node_id", "release_switch_smoke_probe"))
		var node: Node = await _start_visual_battle(encounter_id, battle_id, node_id)
		var loadout: Dictionary = node.get("battle_loadout")
		if str(loadout.get("loadout_source", "")) == "generated_manifest":
			report["full_sequence_generated_loadout_count"] = int(report.get("full_sequence_generated_loadout_count", 0)) + 1
		else:
			report["fallback_loadout_count"] = int(report.get("fallback_loadout_count", 0)) + 1
			source_ok = false
		if str(node.get("last_release_channel")) != "current":
			release_pack_ok = false
		if not bool(node.get("last_formal_entry_uses_release_pack")):
			release_pack_ok = false
		if bool(node.get("last_formal_entry_fallback_used")):
			source_ok = false
		if str(node.get("last_release_content_pack_id")) != EXPECTED_PACK_ID:
			release_pack_ok = false
		if str(loadout.get("content_pack_id", "")) != EXPECTED_PACK_ID:
			release_pack_ok = false
		var reward: Dictionary = Loader.get_generated_reward(encounter_id, battle_id)
		if reward.is_empty() or str(loadout.get("reward_plan_id", "")).is_empty():
			reward_ok = false
		if runtime_primitives.has("weapon_followup"):
			var loadout_followup: Dictionary = loadout.get("weapon_followup", {})
			if not bool(node.get("last_weapon_followup_enabled")) and not bool(loadout_followup.get("enabled", false)):
				primitive_ok = false
		elif runtime_primitives.has("opening_pressure"):
			var loadout_pressure: Dictionary = loadout.get("opening_pressure", {})
			if not bool(node.get("last_opening_pressure_applied")) and loadout_pressure.is_empty():
				primitive_ok = false
		node.queue_free()
		await process_frame
	report["formal_entry_uses_release_pack"] = int(report.get("full_sequence_generated_loadout_count", 0)) == inventory.size() and int(report.get("fallback_loadout_count", 0)) == 0 and source_ok
	report["formal_entry_not_debug_only"] = inventory.size() > 0 and int(report.get("full_sequence_generated_loadout_count", 0)) == inventory.size()
	report["formal_entry_not_mini_route"] = inventory.size() == EXPECTED_COUNT and inventory.size() > 0
	report["reward_coverage_complete"] = reward_ok and int(report.get("fallback_loadout_count", 0)) == 0 and inventory.size() == EXPECTED_COUNT
	report["release_runtime_primitive_ready"] = primitive_ok
	report["release_pack_source_confirmed"] = release_pack_ok and source_ok
	report["probe_pass"] = bool(report.get("formal_entry_uses_release_pack", false)) and bool(report.get("reward_coverage_complete", false)) and bool(report.get("release_pack_source_confirmed", false))
	_write_report(report)
	quit(0 if bool(report.get("probe_pass", false)) else 1)

func _start_visual_battle(encounter_id: String, battle_id: String, node_id: String) -> Node:
	NarrativeBattleContext.clear()
	NarrativeBattleContext.clear_player_profile()
	NarrativeBattleContext.set_player_profile({
		"role": "spearman",
		"career": "长枪武官",
		"weapon": "长枪",
		"martial_level": 3,
		"battles_won": 2
	})
	NarrativeBattleContext.set_request(encounter_id, node_id, battle_id)
	var node: Node = MainVisual.instantiate()
	root.add_child(node)
	await process_frame
	await process_frame
	if node.has_method("_try_recommended_role_entry"):
		node.call("_try_recommended_role_entry", "spearman")
	await process_frame
	await process_frame
	return node

func _read_inventory() -> Array:
	var file := FileAccess.open(INVENTORY_PATH, FileAccess.READ)
	if file == null:
		return []
	var parsed = JSON.parse_string(file.get_as_text())
	if parsed is Array:
		return parsed
	return []

func _write_report(report: Dictionary) -> void:
	var file := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(report, "\t"))
'''.replace("__INVENTORY_PATH__", inventory_res_path).replace("__REPORT_PATH__", report_json_path.as_posix()).replace("__EXPECTED_COUNT__", str(expected_count)).replace("__EXPECTED_PACK_ID__", expected_pack_id)


def rollback_previous_current(*, dry_run: bool = False) -> dict[str, Any]:
    current = release_lib.read_release_channel("current", required=True)
    fallback = release_lib.read_release_channel("fallback", required=True)
    previous = resolve_previous_current_ref()
    ready = bool(previous.get("mechanic_profile_id")) and bool(previous.get("content_pack_id"))
    result = {
        "release_switch_run_id": f"release_switch_rollback_previous_{int(datetime.now(timezone.utc).timestamp())}",
        "timestamp": now_iso(),
        "action": "rollback_previous_current",
        "target_profile_id": str(previous.get("mechanic_profile_id", "")),
        "target_content_pack_id": str(previous.get("content_pack_id", "")),
        "previous_current_rollback_ready": ready,
        "fallback_release": current_ref_from_channel(fallback),
        "dry_run": dry_run,
        "rollback_performed": False,
        "current_release_matches_active_profile": preview_lib.active_matches_current(preview_lib.read_active_profile(), current),
        "report_ready": True,
    }
    if dry_run or not ready:
        append_history(
            action="rollback_previous_current",
            target_profile_id=str(previous.get("mechanic_profile_id", "")),
            target_content_pack_id=str(previous.get("content_pack_id", "")),
            previous_current=current_ref_from_channel(current),
            new_current=current_ref_from_channel(current),
            result="ok" if ready else "blocked",
            error="" if ready else "previous current not available",
        )
        return result
    release_lib.set_release_channel("current", str(previous.get("mechanic_profile_id", "")), str(previous.get("content_pack_id", "")))
    activation = release_lib.activate_current_release()
    result["rollback_performed"] = bool(activation.get("active_profile_matches_current_release", False))
    result["current_release_matches_active_profile"] = bool(activation.get("active_profile_matches_current_release", False))
    append_history(
        action="rollback_previous_current",
        target_profile_id=str(previous.get("mechanic_profile_id", "")),
        target_content_pack_id=str(previous.get("content_pack_id", "")),
        previous_current=current_ref_from_channel(current),
        new_current=previous,
        result="ok",
        error="",
    )
    return result


def rollback_fallback(*, dry_run: bool = False) -> dict[str, Any]:
    current = release_lib.read_release_channel("current", required=True)
    fallback = release_lib.read_release_channel("fallback", required=True)
    fallback_ref = current_ref_from_channel(fallback)
    ready = False
    error = ""
    try:
        release_lib.validate_release_pack(str(fallback.get("mechanic_profile_id", "")), str(fallback.get("content_pack_id", "")), allow_archived=True)
        ready = True
    except SystemExit as exc:
        error = str(exc)
    result = {
        "release_switch_run_id": f"release_switch_rollback_fallback_{int(datetime.now(timezone.utc).timestamp())}",
        "timestamp": now_iso(),
        "action": "rollback_fallback",
        "target_profile_id": str(fallback.get("mechanic_profile_id", "")),
        "target_content_pack_id": str(fallback.get("content_pack_id", "")),
        "fallback_rollback_ready": ready,
        "fallback_pack_resolved": ready,
        "dry_run": dry_run,
        "rollback_performed": False,
        "current_release_matches_active_profile": preview_lib.active_matches_current(preview_lib.read_active_profile(), current),
        "switch_error": error,
        "report_ready": True,
    }
    if dry_run or not ready:
        append_history(
            action="rollback_fallback",
            target_profile_id=str(fallback.get("mechanic_profile_id", "")),
            target_content_pack_id=str(fallback.get("content_pack_id", "")),
            previous_current=current_ref_from_channel(current),
            new_current=current_ref_from_channel(current) if dry_run or not ready else fallback_ref,
            result="ok" if ready else "blocked",
            error=error,
        )
        return result
    release_lib.set_release_channel("current", str(fallback.get("mechanic_profile_id", "")), str(fallback.get("content_pack_id", "")))
    activation = release_lib.activate_current_release()
    result["rollback_performed"] = bool(activation.get("active_profile_matches_current_release", False))
    result["current_release_matches_active_profile"] = bool(activation.get("active_profile_matches_current_release", False))
    append_history(
        action="rollback_fallback",
        target_profile_id=str(fallback.get("mechanic_profile_id", "")),
        target_content_pack_id=str(fallback.get("content_pack_id", "")),
        previous_current=current_ref_from_channel(current),
        new_current=fallback_ref,
        result="ok",
        error="",
    )
    return result


def rollback_after_failed_smoke(previous_current_channel: dict[str, Any]) -> dict[str, Any]:
    previous_ref = current_ref_from_channel(previous_current_channel)
    current_after = release_lib.read_release_channel("current", required=True)
    if (
        previous_ref.get("mechanic_profile_id")
        and previous_ref.get("content_pack_id")
        and (
            previous_ref.get("mechanic_profile_id") != str(current_after.get("mechanic_profile_id", ""))
            or previous_ref.get("content_pack_id") != str(current_after.get("content_pack_id", ""))
        )
    ):
        payload = rollback_previous_current(dry_run=False)
        return {"rollback_performed": bool(payload.get("rollback_performed", False))}
    payload = rollback_fallback(dry_run=False)
    return {"rollback_performed": bool(payload.get("rollback_performed", False))}


def resolve_switch_entry(profile_id: str, content_pack_id: str) -> dict[str, Any]:
    resolver = preview_lib.read_required_json(PACK_RESOLVER_PATH)
    for entry in resolver.get("entries", []):
        if str(entry.get("mechanic_profile_id", "")) == profile_id and str(entry.get("content_pack_id", "")) == content_pack_id:
            if not is_switchable_target_entry(entry):
                raise SystemExit("pack is not a valid release switch target")
            return entry
    raise SystemExit("pack not found in pack_resolver")


def is_release_candidate_entry(entry: dict[str, Any]) -> bool:
    profile_id = str(entry.get("mechanic_profile_id", ""))
    content_pack_id = str(entry.get("content_pack_id", ""))
    if not profile_id or not content_pack_id:
        return False
    return is_release_candidate(profile_id, content_pack_id)


def is_switchable_target_entry(entry: dict[str, Any]) -> bool:
    profile_id = str(entry.get("mechanic_profile_id", ""))
    content_pack_id = str(entry.get("content_pack_id", ""))
    if not profile_id or not content_pack_id:
        return False
    return is_switchable_target(profile_id, content_pack_id)


def is_release_candidate(profile_id: str, content_pack_id: str) -> bool:
    if not meets_switch_prerequisites(profile_id, content_pack_id):
        return False
    try:
        manifest = release_lib.get_release_status(profile_id, content_pack_id)
    except SystemExit:
        return False
    return str(manifest.get("release_status", "")) == "release_candidate"


def is_switchable_target(profile_id: str, content_pack_id: str) -> bool:
    if is_release_candidate(profile_id, content_pack_id):
        return True
    if not meets_switch_prerequisites(profile_id, content_pack_id):
        return False
    current = release_lib.read_release_channel("current", required=True)
    return (
        str(current.get("mechanic_profile_id", "")) == profile_id
        and str(current.get("content_pack_id", "")) == content_pack_id
    )


def meets_switch_prerequisites(profile_id: str, content_pack_id: str) -> bool:
    promotion = load_promotion_report(profile_id, content_pack_id)
    acceptance = load_acceptance_report(profile_id, content_pack_id)
    human_review = load_human_review_note(profile_id, content_pack_id)
    return (
        bool(promotion)
        and bool(promotion.get("promotion_allowed", False))
        and bool(promotion.get("promoted_to_release_candidate", False))
        and bool(acceptance)
        and bool(acceptance.get("acceptance_pass", False))
        and str(acceptance.get("risk_level", "")) != "fail"
        and str(acceptance.get("acceptance_recommendation", "")) != "reject"
        and str(human_review.get("status", "")) == "accepted"
    )


def load_promotion_report(profile_id: str, content_pack_id: str) -> dict[str, Any]:
    path = promotion_report_path(profile_id, content_pack_id)
    return preview_lib.read_json(path) if path.exists() else {}


def load_acceptance_report(profile_id: str, content_pack_id: str) -> dict[str, Any]:
    path = acceptance_report_path(profile_id, content_pack_id)
    return preview_lib.read_json(path) if path.exists() else {}


def load_human_review_note(profile_id: str, content_pack_id: str) -> dict[str, Any]:
    path = human_review_note_path(profile_id, content_pack_id)
    return preview_lib.read_json(path) if path.exists() else {}


def read_switch_history() -> list[dict[str, Any]]:
    if not HISTORY_PATH.exists():
        return []
    rows: list[dict[str, Any]] = []
    for line in HISTORY_PATH.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line:
            continue
        try:
            rows.append(json.loads(line))
        except json.JSONDecodeError:
            continue
    return rows


def resolve_previous_current_ref() -> dict[str, Any]:
    for item in reversed(read_switch_history()):
        action = str(item.get("action", ""))
        previous = {
            "mechanic_profile_id": str(item.get("previous_current_profile_id", "")),
            "content_pack_id": str(item.get("previous_current_content_pack_id", "")),
        }
        if action == "set_current" and previous["mechanic_profile_id"] and previous["content_pack_id"]:
            return previous
    current = release_lib.read_release_channel("current", required=True)
    return current_ref_from_channel(current)


def build_base_report(
    action: str,
    profile_id: str,
    content_pack_id: str,
    dry_run: bool,
    current_before: dict[str, Any],
    fallback: dict[str, Any],
) -> dict[str, Any]:
    return {
        "release_switch_run_id": f"release_switch_{profile_id}_{content_pack_id}_{int(datetime.now(timezone.utc).timestamp())}",
        "timestamp": now_iso(),
        "action": action,
        "target_profile_id": profile_id,
        "target_content_pack_id": content_pack_id,
        "target_sequence_template_id": "",
        "target_build_variant": "",
        "release_candidate_valid": False,
        "promotion_report_found": False,
        "acceptance_report_found": False,
        "human_review_accepted": False,
        "dry_run": dry_run,
        "idempotent_current_activation": False,
        "previous_current": current_ref_from_channel(current_before),
        "new_current": {"mechanic_profile_id": profile_id, "content_pack_id": content_pack_id},
        "fallback_release": current_ref_from_channel(fallback),
        "current_release_written": False,
        "active_profile_written": False,
        "formal_entry_smoke_pass": False,
        "formal_entry_uses_new_current": False,
        "generated_loadout_count": 0,
        "expected_encounter_count": 0,
        "fallback_loadout_count": 0,
        "reward_coverage_complete": False,
        "rollback_available": True,
        "rollback_performed": False,
        "current_release_matches_active_profile": False,
        "switch_allowed": False,
        "switch_error": "",
        "report_ready": True,
    }


def finalize_report(report: dict[str, Any]) -> dict[str, Any]:
    current = release_lib.read_release_channel("current", required=True)
    active = preview_lib.read_active_profile()
    report["current_release_matches_active_profile"] = preview_lib.active_matches_current(active, current)
    write_json(LATEST_JSON, report)
    LATEST_MD.write_text(build_markdown(report), encoding="utf-8")
    return report


def append_history(
    *,
    action: str,
    target_profile_id: str,
    target_content_pack_id: str,
    previous_current: dict[str, Any],
    new_current: dict[str, Any],
    result: str,
    error: str,
) -> None:
    RELEASE_SWITCH_DIR.mkdir(parents=True, exist_ok=True)
    fallback = release_lib.read_release_channel("fallback", required=True)
    row = {
        "event_id": f"release_switch_{action}_{datetime.now(timezone.utc).timestamp()}",
        "timestamp": now_iso(),
        "action": action,
        "target_profile_id": target_profile_id,
        "target_content_pack_id": target_content_pack_id,
        "previous_current_profile_id": str(previous_current.get("mechanic_profile_id", "")),
        "previous_current_content_pack_id": str(previous_current.get("content_pack_id", "")),
        "new_current_profile_id": str(new_current.get("mechanic_profile_id", "")),
        "new_current_content_pack_id": str(new_current.get("content_pack_id", "")),
        "fallback_profile_id": str(fallback.get("mechanic_profile_id", "")),
        "fallback_content_pack_id": str(fallback.get("content_pack_id", "")),
        "result": result,
        "error": error,
    }
    with HISTORY_PATH.open("a", encoding="utf-8") as handle:
        handle.write(json.dumps(row, ensure_ascii=False) + "\n")


def current_ref_from_channel(channel: dict[str, Any]) -> dict[str, Any]:
    return {
        "mechanic_profile_id": str(channel.get("mechanic_profile_id", "")),
        "content_pack_id": str(channel.get("content_pack_id", "")),
    }


def read_current_release_ref() -> dict[str, Any]:
    return current_ref_from_channel(release_lib.read_release_channel("current", required=True))


def promotion_report_path(profile_id: str, content_pack_id: str) -> Path:
    return PROMOTION_DIR / f"{profile_id}__{content_pack_id}__promotion_report.json"


def acceptance_report_path(profile_id: str, content_pack_id: str) -> Path:
    return ACCEPTANCE_DIR / f"{profile_id}__{content_pack_id}__acceptance_report.json"


def human_review_note_path(profile_id: str, content_pack_id: str) -> Path:
    return PROMOTION_REVIEW_DIR / f"{profile_id}__{content_pack_id}.json"


def run_serial(command: list[str]) -> None:
    subprocess.run(command, check=True, cwd=ROOT)


def write_json(path: Path, payload: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def build_markdown(payload: dict[str, Any]) -> str:
    lines = [
        "# Release Switch Report",
        "",
        f"- action: `{payload.get('action', '')}`",
        f"- target_profile_id: `{payload.get('target_profile_id', '')}`",
        f"- target_content_pack_id: `{payload.get('target_content_pack_id', '')}`",
        f"- release_candidate_valid: `{payload.get('release_candidate_valid', False)}`",
        f"- promotion_report_found: `{payload.get('promotion_report_found', False)}`",
        f"- acceptance_report_found: `{payload.get('acceptance_report_found', False)}`",
        f"- human_review_accepted: `{payload.get('human_review_accepted', False)}`",
        f"- dry_run: `{payload.get('dry_run', False)}`",
        f"- idempotent_current_activation: `{payload.get('idempotent_current_activation', False)}`",
        f"- current_release_written: `{payload.get('current_release_written', False)}`",
        f"- active_profile_written: `{payload.get('active_profile_written', False)}`",
        f"- formal_entry_smoke_pass: `{payload.get('formal_entry_smoke_pass', False)}`",
        f"- generated_loadout_count: `{payload.get('generated_loadout_count', 0)}`",
        f"- expected_encounter_count: `{payload.get('expected_encounter_count', 0)}`",
        f"- fallback_loadout_count: `{payload.get('fallback_loadout_count', 0)}`",
        f"- reward_coverage_complete: `{payload.get('reward_coverage_complete', False)}`",
        f"- current_release_matches_active_profile: `{payload.get('current_release_matches_active_profile', False)}`",
        f"- switch_allowed: `{payload.get('switch_allowed', False)}`",
        f"- switch_error: `{payload.get('switch_error', '')}`",
        "",
    ]
    return "\n".join(lines) + "\n"


def now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
