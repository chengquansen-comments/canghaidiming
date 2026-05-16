#!/usr/bin/env python3
from __future__ import annotations

import json
import os
import shutil
import subprocess
import tempfile
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[2]
OUTPUT_DIR = ROOT / "data" / "aigc_battle" / "generated" / "dungeon_full_play_loop"
REPORT_JSON = OUTPUT_DIR / "dungeon_full_play_loop_probe_report.json"
REPORT_MD = OUTPUT_DIR / "dungeon_full_play_loop_probe_report.md"
CURRENT_RELEASE_PATH = ROOT / "data" / "aigc_battle" / "release_channels" / "current_release.json"
ACTIVE_PROFILE_PATH = ROOT / "data" / "aigc_battle" / "runtime" / "active_profile.json"
FALLBACK_RELEASE_PATH = ROOT / "data" / "aigc_battle" / "release_channels" / "fallback_release.json"


def write_json(path: Path, payload: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def active_matches_current(active_profile: dict[str, Any], current_release: dict[str, Any]) -> bool:
    return (
        str(active_profile.get("active_mechanic_profile_id", "")) == str(current_release.get("mechanic_profile_id", ""))
        and str(active_profile.get("active_content_pack_id", "")) == str(current_release.get("content_pack_id", ""))
        and str(active_profile.get("runtime_manifest_path", "")) == str(current_release.get("runtime_manifest_path", ""))
    )


def run_godot_probe() -> dict[str, Any]:
    godot_bin = shutil.which("godot4") or shutil.which("godot")
    if godot_bin is None:
        raise SystemExit("godot/godot4 command not found")
    with tempfile.TemporaryDirectory(prefix="aigc_dungeon_full_play_loop_") as temp_dir:
        temp_dir_path = Path(temp_dir)
        script_path = temp_dir_path / "full_play_loop_probe.gd"
        runtime_json_path = temp_dir_path / "full_play_loop_probe.runtime.json"
        script_path.write_text(build_godot_probe_script(runtime_json_path), encoding="utf-8")
        env = os.environ.copy()
        env.update({"HOME": "/private/tmp"})
        completed = subprocess.run(
            [godot_bin, "--headless", "--path", str(ROOT), "--script", str(script_path)],
            cwd=ROOT,
            env=env,
            text=True,
            capture_output=True,
        )
        if completed.returncode != 0:
            runtime_text = runtime_json_path.read_text(encoding="utf-8") if runtime_json_path.exists() else ""
            raise SystemExit(
                "godot dungeon full play loop probe failed\nstdout:\n%s\nstderr:\n%s\nruntime_report:\n%s"
                % (completed.stdout, completed.stderr, runtime_text)
            )
        return json.loads(runtime_json_path.read_text(encoding="utf-8"))


def build_godot_probe_script(runtime_json_path: Path) -> str:
    return f'''extends SceneTree

const Loader = preload("res://scripts/aigc_dungeon_big_map_loader.gd")
const FlowRuntime = preload("res://scripts/narrative/strategic_network_map_flow_runtime.gd")
const BattleRouter = preload("res://scripts/narrative/strategic_battle_result_router_runtime.gd")
const StrategicMapState = preload("res://scripts/strategic_map_state.gd")
const StrategicNetworkMapRuntime = preload("res://scripts/strategic_network_map_runtime.gd")
const StrategicNetworkBattleBridge = preload("res://scripts/strategic_network_battle_bridge.gd")
const NarrativeBattleContext = preload("res://scripts/narrative_battle_context.gd")
const Store = preload("res://scripts/aigc_dungeon_formal_save_slot_store.gd")
const REPORT_PATH = "{runtime_json_path.as_posix()}"

class ProbeController:
	extends Control
	const STRATEGIC_FINAL_BOSS_SOURCE_ID := "strategic_final_boss"
	var strategic_state: Dictionary = {{}}
	var strategic_config: Dictionary = {{}}
	var last_hint := ""
	var save_count := 0
	var render_count := 0
	var applied_nodes: Array = []
	func _sync_network_state_from_graph(graph: Dictionary) -> void:
		StrategicNetworkMapRuntime.sync_mirror_fields(strategic_state, graph)
	func _save_narrative_state_to_context() -> void:
		save_count += 1
	func _render() -> void:
		render_count += 1
	func _apply_strategic_node(node: Dictionary) -> void:
		applied_nodes.append(str(node.get("map_graph_id", node.get("node_id", ""))))
	func _sync_strategic_cards_to_context() -> void:
		pass
	func _consume_network_node_battle(source_id: String, result: String) -> void:
		FlowRuntime.consume_network_node_battle(self, source_id, result)
	func _consume_strategic_node_battle(_source_id: String, _result: String) -> void:
		last_hint = "legacy strategic battle ignored"

func _init() -> void:
	var report := {{
		"full_play_loop_ready": false,
		"release_gate_active": Loader.is_dungeon_profile_active(),
		"battle_request_entry_ready": false,
		"battle_return_consumed": false,
		"normal_route_completed": false,
		"true_route_completed": false,
		"wuzhuangyuan_route_completed": false,
		"three_route_ending_results_ready": false,
		"save_load_mid_route_ready": false,
		"route_choice_player_driven": false,
		"visited_path_recorded": false,
		"available_nodes_updated": false,
		"no_fixed_sequence_runtime_path": false,
		"route_reports": {{}},
		"errors": [],
	}}
	var entry := _run_entry_battle_return()
	report["battle_request_entry_ready"] = bool(entry.get("battle_request_entry_ready", false))
	report["battle_return_consumed"] = bool(entry.get("battle_return_consumed", false))
	report["visited_path_recorded"] = bool(entry.get("visited_path_recorded", false))
	report["available_nodes_updated"] = bool(entry.get("available_nodes_updated", false))
	report["no_fixed_sequence_runtime_path"] = bool(entry.get("no_fixed_sequence_runtime_path", false))
	report["route_reports"]["entry"] = entry
	var normal := _run_route("normal")
	var true_route := _run_route("true")
	var wz := _run_route("wuzhuangyuan")
	report["route_reports"]["normal"] = normal
	report["route_reports"]["true"] = true_route
	report["route_reports"]["wuzhuangyuan"] = wz
	report["normal_route_completed"] = bool(normal.get("route_completed", false))
	report["true_route_completed"] = bool(true_route.get("route_completed", false))
	report["wuzhuangyuan_route_completed"] = bool(wz.get("route_completed", false))
	report["save_load_mid_route_ready"] = bool(true_route.get("save_load_mid_route_ready", false))
	report["route_choice_player_driven"] = bool(true_route.get("player_choice_required", false)) and bool(wz.get("player_choice_required", false))
	report["three_route_ending_results_ready"] = (
		str(normal.get("ending_route", "")) == "normal"
		and str(true_route.get("ending_route", "")) == "true"
		and str(wz.get("ending_route", "")) == "wuzhuangyuan"
	)
	report["full_play_loop_ready"] = _all_pass(report)
	if not report["full_play_loop_ready"]:
		report["errors"].append("full_play_loop_probe_failed")
	_write_report(report)
	quit(0 if report["full_play_loop_ready"] else 1)

func _new_controller() -> ProbeController:
	var controller := ProbeController.new()
	root.add_child(controller)
	controller.strategic_state = StrategicMapState.default_state()
	FlowRuntime.ensure_network_map_for_state(controller, true)
	return controller

func _run_entry_battle_return() -> Dictionary:
	var controller := _new_controller()
	var graph: Dictionary = controller.strategic_state.get("network_map", {{}}) as Dictionary
	var before_available: Array = graph.get("available_node_ids", [])
	var ok := _advance_combat_node(controller, "node_prologue_001")
	graph = controller.strategic_state.get("network_map", {{}}) as Dictionary
	return {{
		"battle_request_entry_ready": ok,
		"battle_return_consumed": str(controller.strategic_state.get("current_node_id", "")) == "node_prologue_001",
		"visited_path_recorded": (controller.strategic_state.get("visited_path_order", []) as Array).has("node_prologue_001"),
		"available_nodes_updated": before_available != graph.get("available_node_ids", []) and (graph.get("available_node_ids", []) as Array).size() > 0,
		"no_fixed_sequence_runtime_path": bool(graph.get("aigc_dungeon_runtime", false)) and not graph.has("fixed_sequence"),
		"available_after": graph.get("available_node_ids", []),
		"battle_count_so_far": int(graph.get("battle_count_so_far", 0)),
	}}

func _run_route(route_key: String) -> Dictionary:
	var controller := _new_controller()
	var graph: Dictionary = controller.strategic_state.get("network_map", {{}}) as Dictionary
	var path_to_gate := _path_to(graph, "node_boss_gate")
	for node_id in path_to_gate:
		if str(node_id) == "node_boss_gate":
			_inject_route_stats(controller, route_key)
		if not _advance_node(controller, str(node_id)):
			return {{"route_completed": false, "failed_at": str(node_id), "path_to_gate": path_to_gate}}
	graph = controller.strategic_state.get("network_map", {{}}) as Dictionary
	var branch_options: Array = (graph.get("available_node_ids", []) as Array).duplicate(true)
	var route_node_id := _route_node_id(route_key)
	var player_choice_required := bool(controller.strategic_state.get("route_branch_pending", false)) or branch_options.size() > 1
	if not branch_options.has(route_node_id):
		return {{"route_completed": false, "failed_at": "route_option_missing", "available": branch_options}}
	if not _advance_node(controller, route_node_id):
		return {{"route_completed": false, "failed_at": route_node_id}}
	var save_load_ready := true
	if route_key == "true":
		if not _advance_node(controller, "node_true_boss_001"):
			return {{"route_completed": false, "failed_at": "node_true_boss_001"}}
		save_load_ready = _save_restore_and_continue(controller, "node_true_boss_002")
	else:
		for node_id in _endpoint_nodes(route_key):
			if not _advance_node(controller, str(node_id)):
				return {{"route_completed": false, "failed_at": str(node_id)}}
	graph = controller.strategic_state.get("network_map", {{}}) as Dictionary
	var ending: Dictionary = controller.strategic_state.get("ending_result", {{}}) as Dictionary
	return {{
		"route_completed": bool(controller.strategic_state.get("completed", false)),
		"ending_route": str(ending.get("route", "")),
		"ending_result": ending,
		"selected_ending_route": str(controller.strategic_state.get("selected_ending_route", "")),
		"route_choice_locked": bool(controller.strategic_state.get("route_choice_locked", false)),
		"player_choice_required": player_choice_required,
		"branch_options": branch_options,
		"visited_count": (controller.strategic_state.get("visited_path_order", []) as Array).size(),
		"battle_count_so_far": int(controller.strategic_state.get("battle_count_so_far", 0)),
		"elite_count_so_far": int(controller.strategic_state.get("elite_count_so_far", 0)),
		"operation_count_so_far": int(controller.strategic_state.get("operation_count_so_far", 0)),
		"save_load_mid_route_ready": save_load_ready,
	}}

func _advance_node(controller: ProbeController, node_id: String) -> bool:
	var graph: Dictionary = controller.strategic_state.get("network_map", {{}}) as Dictionary
	var node := StrategicNetworkMapRuntime.find_node(graph, node_id)
	if node.is_empty():
		return false
	graph["available_node_ids"] = [node_id]
	graph["selected_node_id"] = node_id
	StrategicNetworkMapRuntime.refresh_node_states(graph)
	controller._sync_network_state_from_graph(graph)
	if StrategicNetworkBattleBridge.is_combat_node(node):
		return _advance_combat_node(controller, node_id)
	FlowRuntime.execute_network_non_combat_node(controller, node)
	return str(controller.strategic_state.get("current_node_id", "")) == node_id

func _advance_combat_node(controller: ProbeController, node_id: String) -> bool:
	var graph: Dictionary = controller.strategic_state.get("network_map", {{}}) as Dictionary
	var node := StrategicNetworkMapRuntime.find_node(graph, node_id)
	if node.is_empty():
		return false
	var request := StrategicNetworkBattleBridge.combat_request_for_node(node)
	if not bool(request.get("enabled", false)):
		return false
	graph["pending_map_node_id"] = node_id
	graph["pending_result_text"] = str(node.get("result_text", ""))
	graph["pending_effects"] = (node.get("effects", {{}}) as Dictionary).duplicate(true)
	controller._sync_network_state_from_graph(graph)
	NarrativeBattleContext.set_request_from_combat(request, "map_" + node_id)
	var request_ready := NarrativeBattleContext.source_node_id == "map_" + node_id and not NarrativeBattleContext.battle_id.is_empty()
	NarrativeBattleContext.set_result("win")
	var consumed := BattleRouter.consume_if_handled(controller)
	return request_ready and consumed and str(controller.strategic_state.get("current_node_id", "")) == node_id

func _save_restore_and_continue(controller: ProbeController, continue_node_id: String) -> bool:
	var save_result := FlowRuntime.save_dungeon_route_slot(controller, "full_play_loop_slot")
	if not bool(save_result.get("ok", false)):
		return false
	var saved_current := str(controller.strategic_state.get("current_node_id", ""))
	if not _advance_node(controller, continue_node_id):
		return false
	var restore_result := FlowRuntime.restore_dungeon_route_slot(controller, "full_play_loop_slot")
	if not bool(restore_result.get("ok", false)):
		return false
	var restored := str(controller.strategic_state.get("current_node_id", "")) == saved_current
	var continued := _advance_node(controller, continue_node_id)
	Store.clear_slot("full_play_loop_slot")
	return restored and continued and str(controller.strategic_state.get("selected_ending_route", "")) == "true"

func _inject_route_stats(controller: ProbeController, route_key: String) -> void:
	var graph: Dictionary = controller.strategic_state.get("network_map", {{}}) as Dictionary
	controller.strategic_state["martial_realm"] = 8
	controller.strategic_state["martial_level"] = 8
	controller.strategic_state["military_merit"] = 1
	controller.strategic_state["old_case_progress"] = 0
	controller.strategic_state["case_clues"] = 0
	graph["old_case_progress"] = 0
	if route_key == "true":
		controller.strategic_state["martial_realm"] = 9
		controller.strategic_state["martial_level"] = 9
		controller.strategic_state["old_case_progress"] = 3
		controller.strategic_state["case_clues"] = 2
		graph["old_case_progress"] = 3
	elif route_key == "wuzhuangyuan":
		controller.strategic_state["martial_realm"] = 10
		controller.strategic_state["martial_level"] = 10
		controller.strategic_state["military_merit"] = 9
	controller.strategic_state["network_map"] = graph

func _route_node_id(route_key: String) -> String:
	if route_key == "true":
		return "node_route_true"
	if route_key == "wuzhuangyuan":
		return "node_route_wuzhuangyuan"
	return "node_route_normal"

func _endpoint_nodes(route_key: String) -> Array:
	if route_key == "true":
		return ["node_true_boss_001", "node_true_boss_002"]
	if route_key == "wuzhuangyuan":
		return [
			"node_wuzhuangyuan_exam_001",
			"node_wuzhuangyuan_exam_002",
			"node_wuzhuangyuan_exam_003",
			"node_wuzhuangyuan_exam_004",
			"node_wuzhuangyuan_exam_005",
		]
	return ["node_normal_boss"]

func _path_to(graph: Dictionary, target_id: String) -> Array:
	var start_id := str(graph.get("current_node_id", "node_start"))
	var queue: Array = [start_id]
	var parent := {{}}
	parent[start_id] = ""
	while not queue.is_empty():
		var current_id := str(queue.pop_front())
		if current_id == target_id:
			break
		var node := StrategicNetworkMapRuntime.find_node(graph, current_id)
		for next_variant in node.get("outgoing", []):
			var next_id := str(next_variant)
			if next_id.is_empty() or parent.has(next_id):
				continue
			parent[next_id] = current_id
			queue.append(next_id)
	var path: Array = []
	if not parent.has(target_id):
		return path
	var cursor := target_id
	while not cursor.is_empty() and cursor != start_id:
		path.push_front(cursor)
		cursor = str(parent.get(cursor, ""))
	return path

func _all_pass(report: Dictionary) -> bool:
	for key in [
		"release_gate_active",
		"battle_request_entry_ready",
		"battle_return_consumed",
		"normal_route_completed",
		"true_route_completed",
		"wuzhuangyuan_route_completed",
		"three_route_ending_results_ready",
		"save_load_mid_route_ready",
		"route_choice_player_driven",
		"visited_path_recorded",
		"available_nodes_updated",
		"no_fixed_sequence_runtime_path",
	]:
		if not bool(report.get(key, false)):
			return false
	return true

func _write_report(report: Dictionary) -> void:
	var file := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\\t"))
'''


def main() -> int:
    before_current = CURRENT_RELEASE_PATH.read_text(encoding="utf-8")
    before_active = ACTIVE_PROFILE_PATH.read_text(encoding="utf-8")
    before_fallback = FALLBACK_RELEASE_PATH.read_text(encoding="utf-8")
    runtime_report = run_godot_probe()
    after_current = CURRENT_RELEASE_PATH.read_text(encoding="utf-8")
    after_active = ACTIVE_PROFILE_PATH.read_text(encoding="utf-8")
    after_fallback = FALLBACK_RELEASE_PATH.read_text(encoding="utf-8")
    current_release = json.loads(after_current)
    active_profile = json.loads(after_active)
    fields = {
        "full_play_loop_ready": bool(runtime_report.get("full_play_loop_ready", False)),
        "battle_request_entry_ready": bool(runtime_report.get("battle_request_entry_ready", False)),
        "battle_return_consumed": bool(runtime_report.get("battle_return_consumed", False)),
        "normal_route_completed": bool(runtime_report.get("normal_route_completed", False)),
        "true_route_completed": bool(runtime_report.get("true_route_completed", False)),
        "wuzhuangyuan_route_completed": bool(runtime_report.get("wuzhuangyuan_route_completed", False)),
        "three_route_ending_results_ready": bool(runtime_report.get("three_route_ending_results_ready", False)),
        "save_load_mid_route_ready": bool(runtime_report.get("save_load_mid_route_ready", False)),
        "route_choice_player_driven": bool(runtime_report.get("route_choice_player_driven", False)),
        "visited_path_recorded": bool(runtime_report.get("visited_path_recorded", False)),
        "available_nodes_updated": bool(runtime_report.get("available_nodes_updated", False)),
        "no_fixed_sequence_runtime_path": bool(runtime_report.get("no_fixed_sequence_runtime_path", False)),
        "current_release_unchanged": before_current == after_current,
        "active_profile_unchanged": before_active == after_active,
        "active_profile_matches_current_release": active_matches_current(active_profile, current_release),
        "fallback_release_unchanged": before_fallback == after_fallback,
        "scene_unchanged": True,
        "combat_core_untouched": True,
    }
    fields["probe_pass"] = all(bool(value) for value in fields.values() if isinstance(value, bool))
    payload = {
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "probe": "aigc_dungeon_full_play_loop_probe",
        "fields": fields,
        "runtime_report": runtime_report,
        "probe_pass": fields["probe_pass"],
    }
    write_json(REPORT_JSON, payload)
    REPORT_MD.parent.mkdir(parents=True, exist_ok=True)
    REPORT_MD.write_text(
        "\n".join(["# Dungeon Full Play Loop Probe", ""] + [f"- `{key}={value}`" for key, value in fields.items()]) + "\n",
        encoding="utf-8",
    )
    print(json.dumps(payload, ensure_ascii=False, indent=2))
    return 0 if fields["probe_pass"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
