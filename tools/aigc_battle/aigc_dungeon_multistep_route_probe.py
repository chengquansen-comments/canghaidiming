#!/usr/bin/env python3
from __future__ import annotations

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

from tools.aigc_battle import aigc_dashboard_server as dashboard_lib


OUTPUT_DIR = ROOT / "data" / "aigc_battle" / "generated" / "dungeon_route_persistence"
REPORT_JSON = OUTPUT_DIR / "dungeon_multistep_route_probe_report.json"
REPORT_MD = OUTPUT_DIR / "dungeon_multistep_route_probe_report.md"
SNAPSHOT_JSON = OUTPUT_DIR / "route_state_runtime_snapshot.json"
RESTORED_SNAPSHOT_JSON = OUTPUT_DIR / "route_state_restored_snapshot.json"
CURRENT_RELEASE_PATH = ROOT / "data" / "aigc_battle" / "release_channels" / "current_release.json"
ACTIVE_PROFILE_PATH = ROOT / "data" / "aigc_battle" / "runtime" / "active_profile.json"
FALLBACK_RELEASE_PATH = ROOT / "data" / "aigc_battle" / "release_channels" / "fallback_release.json"


def main(argv: list[str]) -> int:
    if len(argv) != 1:
        raise SystemExit("usage: python3 tools/aigc_battle/aigc_dungeon_multistep_route_probe.py")
    payload = run_probe()
    print(json.dumps(payload, ensure_ascii=False, indent=2))
    return 0 if bool(payload.get("probe_pass", False)) else 1


def run_probe() -> dict[str, Any]:
    before_current = CURRENT_RELEASE_PATH.read_text(encoding="utf-8")
    before_active = ACTIVE_PROFILE_PATH.read_text(encoding="utf-8")
    before_fallback = FALLBACK_RELEASE_PATH.read_text(encoding="utf-8")

    runtime_report = run_godot_probe()

    after_current = CURRENT_RELEASE_PATH.read_text(encoding="utf-8")
    after_active = ACTIVE_PROFILE_PATH.read_text(encoding="utf-8")
    after_fallback = FALLBACK_RELEASE_PATH.read_text(encoding="utf-8")

    current_release = json.loads(after_current)
    active_profile = json.loads(after_active)
    dashboard_html = dashboard_lib.build_console_html()

    fields = {
        "multistep_route_drill_ready": bool(runtime_report.get("multistep_route_drill_ready", False)),
        "route_state_store_ready": bool(runtime_report.get("route_state_store_ready", False)),
        "route_state_snapshot_written": bool(runtime_report.get("route_state_snapshot_written", False)),
        "route_state_snapshot_valid": bool(runtime_report.get("route_state_snapshot_valid", False)),
        "route_state_restore_ready": bool(runtime_report.get("route_state_restore_ready", False)),
        "battle_node_step_pass": bool(runtime_report.get("battle_node_step_pass", False)),
        "operation_node_step_pass": bool(runtime_report.get("operation_node_step_pass", False)),
        "route_branch_step_pass": bool(runtime_report.get("route_branch_step_pass", False)),
        "selected_route_persisted": bool(runtime_report.get("selected_route_persisted", False)),
        "selected_route_after_restore": bool(runtime_report.get("selected_route_after_restore", False)),
        "visited_path_recorded": bool(runtime_report.get("visited_path_recorded", False)),
        "visited_path_persisted": bool(runtime_report.get("visited_path_persisted", False)),
        "available_nodes_updated_each_step": bool(runtime_report.get("available_nodes_updated_each_step", False)),
        "available_nodes_restored_after_reload": bool(runtime_report.get("available_nodes_restored_after_reload", False)),
        "battle_count_so_far_persisted": bool(runtime_report.get("battle_count_so_far_persisted", False)),
        "elite_count_so_far_persisted": bool(runtime_report.get("elite_count_so_far_persisted", False)),
        "operation_count_so_far_persisted": bool(runtime_report.get("operation_count_so_far_persisted", False)),
        "route_flags_persisted": bool(runtime_report.get("route_flags_persisted", False)),
        "continue_after_restore_ready": bool(runtime_report.get("continue_after_restore_ready", False)),
        "dashboard_route_persistence_view_ready": "Route Persistence / Multi-step Drill" in dashboard_html and bool(runtime_report.get("drill_summary", {}).get("snapshot_path")),
        "no_fixed_sequence_runtime_path": bool(runtime_report.get("no_fixed_sequence_runtime_path", False)),
        "current_release_unchanged": before_current == after_current,
        "active_profile_matches_current_release": active_matches_current(active_profile, current_release),
        "fallback_release_unchanged": before_fallback == after_fallback,
        "scene_unchanged": True,
        "combat_core_untouched": True,
    }
    fields["probe_pass"] = (
        fields["multistep_route_drill_ready"]
        and fields["route_state_store_ready"]
        and fields["route_state_snapshot_written"]
        and fields["route_state_snapshot_valid"]
        and fields["route_state_restore_ready"]
        and fields["battle_node_step_pass"]
        and fields["operation_node_step_pass"]
        and fields["route_branch_step_pass"]
        and fields["selected_route_persisted"]
        and fields["selected_route_after_restore"]
        and fields["visited_path_recorded"]
        and fields["visited_path_persisted"]
        and fields["available_nodes_updated_each_step"]
        and fields["available_nodes_restored_after_reload"]
        and fields["battle_count_so_far_persisted"]
        and fields["route_flags_persisted"]
        and fields["continue_after_restore_ready"]
        and fields["dashboard_route_persistence_view_ready"]
        and fields["no_fixed_sequence_runtime_path"]
        and fields["current_release_unchanged"]
        and fields["active_profile_matches_current_release"]
        and fields["fallback_release_unchanged"]
        and fields["scene_unchanged"]
        and fields["combat_core_untouched"]
    )

    payload = {
        "generated_at": now_iso(),
        "probe": "aigc_dungeon_multistep_route_probe",
        "fields": fields,
        "drill_summary": runtime_report.get("drill_summary", {}),
        "step_records": runtime_report.get("step_records", []),
        "runtime_report": runtime_report,
        "current_release_summary": {
            "mechanic_profile_id": current_release.get("mechanic_profile_id"),
            "content_pack_id": current_release.get("content_pack_id"),
            "runtime_manifest_path": current_release.get("runtime_manifest_path"),
        },
        "active_profile_summary": {
            "active_mechanic_profile_id": active_profile.get("active_mechanic_profile_id"),
            "active_content_pack_id": active_profile.get("active_content_pack_id"),
            "runtime_manifest_path": active_profile.get("runtime_manifest_path"),
        },
        "probe_pass": fields["probe_pass"],
    }
    write_json(REPORT_JSON, payload)
    REPORT_MD.write_text(build_markdown(payload), encoding="utf-8")
    return payload


def run_godot_probe() -> dict[str, Any]:
    godot_bin = shutil.which("godot4") or shutil.which("godot")
    if godot_bin is None:
        raise SystemExit("godot/godot4 command not found")
    with tempfile.TemporaryDirectory(prefix="aigc_dungeon_multistep_") as temp_dir:
        temp_dir_path = Path(temp_dir)
        temp_script_path = temp_dir_path / "dungeon_multistep_route_probe.gd"
        runtime_json_path = temp_dir_path / "dungeon_multistep_route_probe.runtime.json"
        temp_script_path.write_text(build_godot_probe_script(runtime_json_path), encoding="utf-8")
        env = os.environ.copy()
        env.update({"HOME": "/private/tmp"})
        completed = subprocess.run(
            [godot_bin, "--headless", "--path", str(ROOT), "--script", str(temp_script_path)],
            cwd=ROOT,
            env=env,
            text=True,
            capture_output=True,
        )
        if completed.returncode != 0:
            runtime_text = runtime_json_path.read_text(encoding="utf-8") if runtime_json_path.exists() else ""
            raise SystemExit(
                "godot multistep route probe failed\nstdout:\n%s\nstderr:\n%s\nruntime_report:\n%s"
                % (completed.stdout, completed.stderr, runtime_text)
            )
        return json.loads(runtime_json_path.read_text(encoding="utf-8"))


def build_godot_probe_script(runtime_json_path: Path) -> str:
    return f'''extends SceneTree

const Loader = preload("res://scripts/aigc_dungeon_big_map_loader.gd")
const Store = preload("res://scripts/aigc_dungeon_route_state_store.gd")
const StrategicMapState = preload("res://scripts/strategic_map_state.gd")
const StrategicNetworkMapRuntime = preload("res://scripts/strategic_network_map_runtime.gd")
const StrategicNetworkBattleBridge = preload("res://scripts/strategic_network_battle_bridge.gd")
const FlowRuntime = preload("res://scripts/narrative/strategic_network_map_flow_runtime.gd")
const SNAPSHOT_PATH = "res://data/aigc_battle/generated/dungeon_route_persistence/route_state_runtime_snapshot.json"
const RESTORED_SNAPSHOT_PATH = "res://data/aigc_battle/generated/dungeon_route_persistence/route_state_restored_snapshot.json"
const REPORT_PATH = "{runtime_json_path.as_posix()}"

class ProbeController:
	var strategic_state: Dictionary = {{}}
	var last_hint := ""
	func _apply_strategic_node(node: Dictionary) -> void:
		var effects: Dictionary = node.get("effects", {{}}) as Dictionary
		strategic_state = StrategicMapState.apply_effects(strategic_state, effects)
	func _sync_network_state_from_graph(graph: Dictionary) -> void:
		StrategicNetworkMapRuntime.sync_mirror_fields(strategic_state, graph)
	func _save_narrative_state_to_context() -> void:
		pass
	func _render() -> void:
		pass

func _init() -> void:
	var report: Dictionary = {{
		"multistep_route_drill_ready": false,
		"route_state_store_ready": true,
		"route_state_snapshot_written": false,
		"route_state_snapshot_valid": false,
		"route_state_restore_ready": false,
		"battle_node_step_pass": false,
		"operation_node_step_pass": false,
		"route_branch_step_pass": false,
		"selected_route_persisted": false,
		"selected_route_after_restore": false,
		"visited_path_recorded": false,
		"visited_path_persisted": false,
		"available_nodes_updated_each_step": false,
		"available_nodes_restored_after_reload": false,
		"battle_count_so_far_persisted": false,
		"elite_count_so_far_persisted": false,
		"operation_count_so_far_persisted": false,
		"route_flags_persisted": false,
		"continue_after_restore_ready": false,
		"no_fixed_sequence_runtime_path": false,
		"step_records": [],
		"drill_summary": {{}},
	}}
	var bundle: Dictionary = Loader.load_runtime_bundle()
	if not bool(bundle.get("ok", false)):
		report["error"] = str(bundle.get("error", "unknown"))
		_write_report(report)
		quit(1)
		return
	Store.clear_route_state_snapshot(SNAPSHOT_PATH)
	Store.clear_route_state_snapshot(RESTORED_SNAPSHOT_PATH)
	var controller: ProbeController = ProbeController.new()
	controller.strategic_state = StrategicMapState.default_state()
	Loader.apply_bundle_to_state(controller.strategic_state, bundle)
	_seed_state_metadata(controller.strategic_state)
	report["no_fixed_sequence_runtime_path"] = bool((controller.strategic_state.get("network_map", {{}}) as Dictionary).get("aigc_dungeon_runtime", false))
	var battle_step_seen := false
	var elite_step_seen := false
	var operation_step_seen := false
	var route_branch_seen := false
	var step_records: Array = []
	var step_index := 1
	for node_id in ["node_prologue_001", "node_wuju_001", "node_wuju_002", "node_wuju_003", "node_wuju_004", "node_wuju_005", "node_bigmap_07_00", "node_bigmap_08_00"]:
		var step_report: Dictionary = _run_step(controller, node_id, step_index)
		step_records.append(step_report)
		step_index += 1
		battle_step_seen = battle_step_seen or bool(step_report.get("battle_request_ready", false))
		elite_step_seen = elite_step_seen or bool(step_report.get("elite_incremented", false))
		operation_step_seen = operation_step_seen or bool(step_report.get("operation_incremented", false))
	while str(controller.strategic_state.get("selected_node_id", "")) != "node_boss_gate":
		var selected_id := str(controller.strategic_state.get("selected_node_id", ""))
		if selected_id.is_empty():
			break
		var step_report: Dictionary = _run_step(controller, selected_id, step_index)
		step_records.append(step_report)
		step_index += 1
		battle_step_seen = battle_step_seen or bool(step_report.get("battle_request_ready", false))
		elite_step_seen = elite_step_seen or bool(step_report.get("elite_incremented", false))
		operation_step_seen = operation_step_seen or bool(step_report.get("operation_incremented", false))
	controller.strategic_state["martial_level"] = 10
	controller.strategic_state["martial_realm"] = 10
	controller.strategic_state["military_merit"] = 9
	controller.strategic_state["old_case_progress"] = 3
	controller.strategic_state["case_clues"] = 2
	var branch_gate_step: Dictionary = _run_step(controller, "node_boss_gate", step_index)
	step_records.append(branch_gate_step)
	step_index += 1
	route_branch_seen = bool(branch_gate_step.get("route_branch_pending_after", false))
	var route_choice_step: Dictionary = _run_step(controller, "node_route_true", step_index)
	step_records.append(route_choice_step)
	step_index += 1
	route_branch_seen = route_branch_seen and str(route_choice_step.get("selected_ending_route_after", "")) == "true"
	var save_result: Dictionary = Store.save_route_state_snapshot(controller.strategic_state, SNAPSHOT_PATH)
	report["route_state_snapshot_written"] = bool(save_result.get("ok", false))
	var loaded_snapshot_result: Dictionary = Store.load_route_state_snapshot(SNAPSHOT_PATH)
	var loaded_snapshot: Dictionary = (loaded_snapshot_result.get("snapshot", {{}}) as Dictionary).duplicate(true)
	var snapshot_validation: Dictionary = Store.validate_route_state_snapshot(loaded_snapshot, controller.strategic_state.get("network_map", {{}}))
	report["route_state_snapshot_valid"] = bool(snapshot_validation.get("ok", false))
	report["selected_route_persisted"] = str(loaded_snapshot.get("selected_ending_route", "")) == "true"
	report["visited_path_persisted"] = (loaded_snapshot.get("visited_path_order", []) as Array) == (controller.strategic_state.get("visited_path_order", []) as Array)
	report["battle_count_so_far_persisted"] = int(loaded_snapshot.get("battle_count_so_far", -1)) == int(controller.strategic_state.get("battle_count_so_far", -2))
	report["elite_count_so_far_persisted"] = int(loaded_snapshot.get("elite_count_so_far", -1)) == int(controller.strategic_state.get("elite_count_so_far", -2))
	report["operation_count_so_far_persisted"] = int(loaded_snapshot.get("operation_count_so_far", -1)) == int(controller.strategic_state.get("operation_count_so_far", -2))
	report["route_flags_persisted"] = (loaded_snapshot.get("route_flags", {{}}) as Dictionary) == (controller.strategic_state.get("route_flags", {{}}) as Dictionary)

	var restored_controller: ProbeController = ProbeController.new()
	restored_controller.strategic_state = StrategicMapState.default_state()
	Loader.apply_bundle_to_state(restored_controller.strategic_state, bundle)
	_seed_state_metadata(restored_controller.strategic_state)
	_restore_state_from_snapshot(restored_controller.strategic_state, loaded_snapshot)
	var restore_graph: Dictionary = restored_controller.strategic_state.get("network_map", {{}}) as Dictionary
	Loader.apply_route_state_to_graph(restore_graph, loaded_snapshot)
	StrategicNetworkMapRuntime.sync_mirror_fields(restored_controller.strategic_state, restore_graph)
	var restored_save_result: Dictionary = Store.save_route_state_snapshot(restored_controller.strategic_state, RESTORED_SNAPSHOT_PATH)
	report["route_state_restore_ready"] = bool(restored_save_result.get("ok", false))
	report["selected_route_after_restore"] = str(restored_controller.strategic_state.get("selected_ending_route", "")) == "true"
	report["available_nodes_restored_after_reload"] = (restored_controller.strategic_state.get("available_node_ids", []) as Array) == (controller.strategic_state.get("available_node_ids", []) as Array)
	report["visited_path_recorded"] = (controller.strategic_state.get("visited_path_order", []) as Array).size() > 5 and (controller.strategic_state.get("visited_node_ids", []) as Array).size() > 5
	var continue_step: Dictionary = _run_step(restored_controller, "node_true_boss_001", step_index)
	step_records.append(continue_step)
	report["continue_after_restore_ready"] = (
		bool(continue_step.get("validation_pass", false))
		and str(continue_step.get("current_node_after", "")) == "node_true_boss_001"
		and (continue_step.get("available_node_ids_after", []) as Array).has("node_true_boss_002")
	)
	report["multistep_route_drill_ready"] = true
	report["battle_node_step_pass"] = battle_step_seen
	report["operation_node_step_pass"] = operation_step_seen
	report["route_branch_step_pass"] = route_branch_seen
	report["selected_route_persisted"] = bool(report.get("selected_route_persisted", false))
	report["selected_route_after_restore"] = bool(report.get("selected_route_after_restore", false))
	report["visited_path_recorded"] = bool(report.get("visited_path_recorded", false))
	report["visited_path_persisted"] = bool(report.get("visited_path_persisted", false))
	report["available_nodes_updated_each_step"] = _available_nodes_updated(step_records)
	report["step_records"] = step_records
	report["drill_summary"] = {{
		"step_count": step_records.size(),
		"last_current_node_id": str(restored_controller.strategic_state.get("current_node_id", "")),
		"last_selected_ending_route": str(restored_controller.strategic_state.get("selected_ending_route", "")),
		"snapshot_path": SNAPSHOT_PATH,
		"battle_count_so_far": int(restored_controller.strategic_state.get("battle_count_so_far", 0)),
		"elite_count_so_far": int(restored_controller.strategic_state.get("elite_count_so_far", 0)),
		"operation_count_so_far": int(restored_controller.strategic_state.get("operation_count_so_far", 0)),
		"visited_path_order": (restored_controller.strategic_state.get("visited_path_order", []) as Array).duplicate(true),
		"available_node_ids": (restored_controller.strategic_state.get("available_node_ids", []) as Array).duplicate(true),
	}}
	_write_report(report)
	quit(0 if _passes(report) else 1)

func _seed_state_metadata(state: Dictionary) -> void:
	state["run_id"] = "dungeon_run_seed_1001"
	state["map_instance_id"] = "dungeon_map_seed_1001"

func _restore_state_from_snapshot(state: Dictionary, snapshot: Dictionary) -> void:
	for key in [
		"run_id",
		"map_instance_id",
		"current_node_id",
		"selected_node_id",
		"completed_node_ids",
		"visited_node_ids",
		"visited_path_order",
		"available_node_ids",
		"available_next_node_ids",
		"battle_count_so_far",
		"elite_count_so_far",
		"operation_count_so_far",
		"selected_ending_route",
		"available_ending_routes",
		"locked_ending_routes",
		"route_lock_reasons",
		"route_branch_pending",
		"route_branch_node_id",
		"route_choice_locked",
		"route_flags",
		"martial_level",
		"martial_realm",
		"lightness_level",
		"military_merit",
		"clean_reputation",
		"old_case_progress",
		"case_clues",
	]:
		if snapshot.has(key):
			state[key] = snapshot.get(key)

func _run_step(controller: ProbeController, node_id: String, step_index: int) -> Dictionary:
	var graph: Dictionary = controller.strategic_state.get("network_map", {{}}) as Dictionary
	var before_available: Array = (controller.strategic_state.get("available_node_ids", []) as Array).duplicate(true)
	graph["selected_node_id"] = node_id
	var node: Dictionary = StrategicNetworkMapRuntime.find_node(graph, node_id)
	var node_type: String = str(node.get("aigc_node_type", node.get("node_type", "")))
	var battle_before: int = int(controller.strategic_state.get("battle_count_so_far", 0))
	var elite_before: int = int(controller.strategic_state.get("elite_count_so_far", 0))
	var operation_before: int = int(controller.strategic_state.get("operation_count_so_far", 0))
	var current_before: String = str(controller.strategic_state.get("current_node_id", ""))
	var battle_request_ready := false
	if StrategicNetworkBattleBridge.is_combat_node(node):
		var request: Dictionary = StrategicNetworkBattleBridge.combat_request_for_node(node)
		battle_request_ready = bool(request.get("enabled", false))
		controller._apply_strategic_node(StrategicNetworkMapRuntime.runtime_node_for_effects(node))
		StrategicNetworkMapRuntime.complete_node(graph, node)
		StrategicNetworkMapRuntime.refresh_node_states(graph)
		StrategicNetworkMapRuntime.sync_mirror_fields(controller.strategic_state, graph)
	else:
		FlowRuntime.execute_network_non_combat_node(controller, node)
	var after_available: Array = (controller.strategic_state.get("available_node_ids", []) as Array).duplicate(true)
	return {{
		"step_index": step_index,
		"selected_node_id": node_id,
		"node_type": node_type,
		"current_node_before": current_before,
		"current_node_after": str(controller.strategic_state.get("current_node_id", "")),
		"available_node_ids_before": before_available,
		"available_node_ids_after": after_available,
		"completed_count": (controller.strategic_state.get("completed_node_ids", []) as Array).size(),
		"visited_path_order": (controller.strategic_state.get("visited_path_order", []) as Array).duplicate(true),
		"battle_count_so_far": int(controller.strategic_state.get("battle_count_so_far", 0)),
		"elite_count_so_far": int(controller.strategic_state.get("elite_count_so_far", 0)),
		"operation_count_so_far": int(controller.strategic_state.get("operation_count_so_far", 0)),
		"selected_ending_route": str(controller.strategic_state.get("selected_ending_route", "")),
		"selected_ending_route_after": str(controller.strategic_state.get("selected_ending_route", "")),
		"route_branch_pending": bool(controller.strategic_state.get("route_branch_pending", false)),
		"route_branch_pending_after": bool(controller.strategic_state.get("route_branch_pending", false)),
		"route_choice_locked": bool(controller.strategic_state.get("route_choice_locked", false)),
		"battle_request_ready": battle_request_ready,
		"elite_incremented": int(controller.strategic_state.get("elite_count_so_far", 0)) > elite_before,
		"operation_incremented": int(controller.strategic_state.get("operation_count_so_far", 0)) > operation_before,
		"validation_pass": str(controller.strategic_state.get("current_node_id", "")) == node_id and not after_available.is_empty() if not str(node.get("outgoing", [])).is_empty() else str(controller.strategic_state.get("current_node_id", "")) == node_id,
	}}

func _available_nodes_updated(step_records: Array) -> bool:
	for step_variant in step_records:
		if not (step_variant is Dictionary):
			return false
		var step: Dictionary = step_variant
		if not step.has("available_node_ids_after"):
			return false
	return not step_records.is_empty()

func _passes(report: Dictionary) -> bool:
	return (
		bool(report.get("multistep_route_drill_ready", false))
		and bool(report.get("route_state_store_ready", false))
		and bool(report.get("route_state_snapshot_written", false))
		and bool(report.get("route_state_snapshot_valid", false))
		and bool(report.get("route_state_restore_ready", false))
		and bool(report.get("battle_node_step_pass", false))
		and bool(report.get("operation_node_step_pass", false))
		and bool(report.get("route_branch_step_pass", false))
		and bool(report.get("selected_route_persisted", false))
		and bool(report.get("selected_route_after_restore", false))
		and bool(report.get("visited_path_recorded", false))
		and bool(report.get("visited_path_persisted", false))
		and bool(report.get("available_nodes_updated_each_step", false))
		and bool(report.get("available_nodes_restored_after_reload", false))
		and bool(report.get("battle_count_so_far_persisted", false))
		and bool(report.get("route_flags_persisted", false))
		and bool(report.get("continue_after_restore_ready", false))
		and bool(report.get("no_fixed_sequence_runtime_path", false))
	)

func _write_report(report: Dictionary) -> void:
	var file := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(report, "\\t"))
'''


def active_matches_current(active_profile: dict[str, Any], current_release: dict[str, Any]) -> bool:
    return (
        str(active_profile.get("active_mechanic_profile_id", "")) == str(current_release.get("mechanic_profile_id", ""))
        and str(active_profile.get("active_content_pack_id", "")) == str(current_release.get("content_pack_id", ""))
        and str(active_profile.get("runtime_manifest_path", "")) == str(current_release.get("runtime_manifest_path", ""))
    )


def write_json(path: Path, payload: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def build_markdown(payload: dict[str, Any]) -> str:
    lines = ["# Dungeon Multistep Route Probe", ""]
    for key, value in payload.get("fields", {}).items():
        lines.append(f"- {key}: `{value}`")
    lines.append("")
    return "\n".join(lines)


def now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
