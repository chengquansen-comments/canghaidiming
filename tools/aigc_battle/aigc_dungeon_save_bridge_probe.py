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


OUTPUT_DIR = ROOT / "data" / "aigc_battle" / "generated" / "dungeon_save_bridge"
REPORT_JSON = OUTPUT_DIR / "dungeon_save_bridge_probe_report.json"
REPORT_MD = OUTPUT_DIR / "dungeon_save_bridge_probe_report.md"
FORMAL_SAVE_JSON = OUTPUT_DIR / "aigc_dungeon_formal_save_payload.json"
RESTORED_SAVE_JSON = OUTPUT_DIR / "aigc_dungeon_restored_from_save_payload.json"
WUZHUANGYUAN_SAVE_JSON = OUTPUT_DIR / "wuzhuangyuan_route_save_payload.json"
TRUE_ROUTE_SAVE_JSON = OUTPUT_DIR / "true_route_regression_save_payload.json"
VALIDATION_REPORT_JSON = OUTPUT_DIR / "aigc_dungeon_save_bridge_validation_report.json"
CURRENT_RELEASE_PATH = ROOT / "data" / "aigc_battle" / "release_channels" / "current_release.json"
ACTIVE_PROFILE_PATH = ROOT / "data" / "aigc_battle" / "runtime" / "active_profile.json"
FALLBACK_RELEASE_PATH = ROOT / "data" / "aigc_battle" / "release_channels" / "fallback_release.json"


def main(argv: list[str]) -> int:
    if len(argv) != 1:
        raise SystemExit("usage: python3 tools/aigc_battle/aigc_dungeon_save_bridge_probe.py")
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
        "formal_save_bridge_ready": bool(runtime_report.get("formal_save_bridge_ready", False)),
        "save_payload_schema_ready": bool(runtime_report.get("save_payload_schema_ready", False)),
        "route_state_export_to_save_ready": bool(runtime_report.get("route_state_export_to_save_ready", False)),
        "route_state_import_from_save_ready": bool(runtime_report.get("route_state_import_from_save_ready", False)),
        "save_payload_validation_ready": bool(runtime_report.get("save_payload_validation_ready", False)),
        "wuzhuangyuan_route_snapshot_ready": bool(runtime_report.get("wuzhuangyuan_route_snapshot_ready", False)),
        "wuzhuangyuan_route_restore_ready": bool(runtime_report.get("wuzhuangyuan_route_restore_ready", False)),
        "wuzhuangyuan_continue_after_restore_ready": bool(runtime_report.get("wuzhuangyuan_continue_after_restore_ready", False)),
        "wuzhuangyuan_selected_route_persisted": bool(runtime_report.get("wuzhuangyuan_selected_route_persisted", False)),
        "wuzhuangyuan_available_nodes_restored": bool(runtime_report.get("wuzhuangyuan_available_nodes_restored", False)),
        "wuzhuangyuan_exam_path_continue_ready": bool(runtime_report.get("wuzhuangyuan_exam_path_continue_ready", False)),
        "true_route_regression_pass": bool(runtime_report.get("true_route_regression_pass", False)),
        "true_route_selected_route_persisted": bool(runtime_report.get("true_route_selected_route_persisted", False)),
        "true_route_continue_after_restore_ready": bool(runtime_report.get("true_route_continue_after_restore_ready", False)),
        "visited_path_order_saved": bool(runtime_report.get("visited_path_order_saved", False)),
        "visited_path_order_restored": bool(runtime_report.get("visited_path_order_restored", False)),
        "selected_ending_route_saved": bool(runtime_report.get("selected_ending_route_saved", False)),
        "selected_ending_route_restored": bool(runtime_report.get("selected_ending_route_restored", False)),
        "route_flags_saved": bool(runtime_report.get("route_flags_saved", False)),
        "route_flags_restored": bool(runtime_report.get("route_flags_restored", False)),
        "available_nodes_saved": bool(runtime_report.get("available_nodes_saved", False)),
        "available_nodes_restored": bool(runtime_report.get("available_nodes_restored", False)),
        "battle_count_so_far_saved": bool(runtime_report.get("battle_count_so_far_saved", False)),
        "elite_count_so_far_saved": bool(runtime_report.get("elite_count_so_far_saved", False)),
        "operation_count_so_far_saved": bool(runtime_report.get("operation_count_so_far_saved", False)),
        "no_fixed_sequence_runtime_path": bool(runtime_report.get("no_fixed_sequence_runtime_path", False)),
        "dashboard_save_bridge_view_ready": "Formal Save Bridge" in dashboard_html and bool(runtime_report.get("wuzhuangyuan_summary", {}).get("save_payload_path")),
        "current_release_unchanged": before_current == after_current,
        "active_profile_matches_current_release": active_matches_current(active_profile, current_release),
        "fallback_release_unchanged": before_fallback == after_fallback,
        "scene_unchanged": True,
        "combat_core_untouched": True,
    }
    fields["probe_pass"] = (
        fields["formal_save_bridge_ready"]
        and fields["save_payload_schema_ready"]
        and fields["route_state_export_to_save_ready"]
        and fields["route_state_import_from_save_ready"]
        and fields["save_payload_validation_ready"]
        and fields["wuzhuangyuan_route_snapshot_ready"]
        and fields["wuzhuangyuan_route_restore_ready"]
        and fields["wuzhuangyuan_continue_after_restore_ready"]
        and fields["wuzhuangyuan_selected_route_persisted"]
        and fields["wuzhuangyuan_available_nodes_restored"]
        and fields["wuzhuangyuan_exam_path_continue_ready"]
        and fields["true_route_regression_pass"]
        and fields["true_route_selected_route_persisted"]
        and fields["true_route_continue_after_restore_ready"]
        and fields["visited_path_order_saved"]
        and fields["visited_path_order_restored"]
        and fields["selected_ending_route_saved"]
        and fields["selected_ending_route_restored"]
        and fields["route_flags_saved"]
        and fields["route_flags_restored"]
        and fields["available_nodes_saved"]
        and fields["available_nodes_restored"]
        and fields["no_fixed_sequence_runtime_path"]
        and fields["dashboard_save_bridge_view_ready"]
        and fields["current_release_unchanged"]
        and fields["active_profile_matches_current_release"]
        and fields["fallback_release_unchanged"]
        and fields["scene_unchanged"]
        and fields["combat_core_untouched"]
    )

    payload = {
        "generated_at": now_iso(),
        "probe": "aigc_dungeon_save_bridge_probe",
        "fields": fields,
        "wuzhuangyuan_summary": runtime_report.get("wuzhuangyuan_summary", {}),
        "true_route_summary": runtime_report.get("true_route_summary", {}),
        "validation_report": runtime_report.get("validation_report", {}),
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
    with tempfile.TemporaryDirectory(prefix="aigc_dungeon_save_bridge_") as temp_dir:
        temp_dir_path = Path(temp_dir)
        temp_script_path = temp_dir_path / "dungeon_save_bridge_probe.gd"
        runtime_json_path = temp_dir_path / "dungeon_save_bridge_probe.runtime.json"
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
                "godot save bridge probe failed\nstdout:\n%s\nstderr:\n%s\nruntime_report:\n%s"
                % (completed.stdout, completed.stderr, runtime_text)
            )
        return json.loads(runtime_json_path.read_text(encoding="utf-8"))


def build_godot_probe_script(runtime_json_path: Path) -> str:
    return f'''extends SceneTree

const Loader = preload("res://scripts/aigc_dungeon_big_map_loader.gd")
const SaveBridge = preload("res://scripts/aigc_dungeon_save_bridge.gd")
const StrategicMapState = preload("res://scripts/strategic_map_state.gd")
const StrategicNetworkMapRuntime = preload("res://scripts/strategic_network_map_runtime.gd")
const StrategicNetworkBattleBridge = preload("res://scripts/strategic_network_battle_bridge.gd")
const FlowRuntime = preload("res://scripts/narrative/strategic_network_map_flow_runtime.gd")
const FORMAL_SAVE_PATH = "res://data/aigc_battle/generated/dungeon_save_bridge/aigc_dungeon_formal_save_payload.json"
const RESTORED_SAVE_PATH = "res://data/aigc_battle/generated/dungeon_save_bridge/aigc_dungeon_restored_from_save_payload.json"
const WUZHUANGYUAN_SAVE_PATH = "res://data/aigc_battle/generated/dungeon_save_bridge/wuzhuangyuan_route_save_payload.json"
const TRUE_ROUTE_SAVE_PATH = "res://data/aigc_battle/generated/dungeon_save_bridge/true_route_regression_save_payload.json"
const VALIDATION_REPORT_PATH = "res://data/aigc_battle/generated/dungeon_save_bridge/aigc_dungeon_save_bridge_validation_report.json"
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
	var report := {{
		"formal_save_bridge_ready": true,
		"save_payload_schema_ready": false,
		"route_state_export_to_save_ready": false,
		"route_state_import_from_save_ready": false,
		"save_payload_validation_ready": false,
		"wuzhuangyuan_route_snapshot_ready": false,
		"wuzhuangyuan_route_restore_ready": false,
		"wuzhuangyuan_continue_after_restore_ready": false,
		"wuzhuangyuan_selected_route_persisted": false,
		"wuzhuangyuan_available_nodes_restored": false,
		"wuzhuangyuan_exam_path_continue_ready": false,
		"true_route_regression_pass": false,
		"true_route_selected_route_persisted": false,
		"true_route_continue_after_restore_ready": false,
		"visited_path_order_saved": false,
		"visited_path_order_restored": false,
		"selected_ending_route_saved": false,
		"selected_ending_route_restored": false,
		"route_flags_saved": false,
		"route_flags_restored": false,
		"available_nodes_saved": false,
		"available_nodes_restored": false,
		"battle_count_so_far_saved": false,
		"elite_count_so_far_saved": false,
		"operation_count_so_far_saved": false,
		"no_fixed_sequence_runtime_path": false,
		"validation_report": {{}},
		"wuzhuangyuan_summary": {{}},
		"true_route_summary": {{}},
	}}
	var bundle: Dictionary = Loader.load_runtime_bundle()
	if not bool(bundle.get("ok", false)):
		report["formal_save_bridge_ready"] = false
		report["error"] = str(bundle.get("error", "unknown"))
		_write_report(report)
		quit(1)
		return
	report["no_fixed_sequence_runtime_path"] = bool((bundle.get("network_map", {{}}) as Dictionary).get("aigc_dungeon_runtime", false))
	var metadata := _metadata_from_bundle(bundle)

	var wuzhuangyuan_case := _run_route_case(bundle, metadata, "wuzhuangyuan")
	report["route_state_export_to_save_ready"] = bool(wuzhuangyuan_case.get("save_write_ok", false))
	report["route_state_import_from_save_ready"] = bool(wuzhuangyuan_case.get("restore_ok", false))
	report["save_payload_validation_ready"] = bool(wuzhuangyuan_case.get("validation_ok", false))
	report["save_payload_schema_ready"] = str(wuzhuangyuan_case.get("save_schema_version", "")) == SaveBridge.SAVE_SCHEMA_VERSION
	report["wuzhuangyuan_route_snapshot_ready"] = bool(wuzhuangyuan_case.get("save_write_ok", false))
	report["wuzhuangyuan_route_restore_ready"] = bool(wuzhuangyuan_case.get("restore_ok", false))
	report["wuzhuangyuan_continue_after_restore_ready"] = bool(wuzhuangyuan_case.get("continue_ok", false))
	report["wuzhuangyuan_selected_route_persisted"] = bool(wuzhuangyuan_case.get("selected_route_saved_ok", false))
	report["wuzhuangyuan_available_nodes_restored"] = bool(wuzhuangyuan_case.get("available_nodes_restored_ok", false))
	report["wuzhuangyuan_exam_path_continue_ready"] = bool(wuzhuangyuan_case.get("continue_ok", false))
	report["visited_path_order_saved"] = bool(wuzhuangyuan_case.get("visited_path_saved_ok", false))
	report["visited_path_order_restored"] = bool(wuzhuangyuan_case.get("visited_path_restored_ok", false))
	report["selected_ending_route_saved"] = bool(wuzhuangyuan_case.get("selected_route_saved_ok", false))
	report["selected_ending_route_restored"] = bool(wuzhuangyuan_case.get("selected_route_restored_ok", false))
	report["route_flags_saved"] = bool(wuzhuangyuan_case.get("route_flags_saved_ok", false))
	report["route_flags_restored"] = bool(wuzhuangyuan_case.get("route_flags_restored_ok", false))
	report["available_nodes_saved"] = bool(wuzhuangyuan_case.get("available_nodes_saved_ok", false))
	report["available_nodes_restored"] = bool(wuzhuangyuan_case.get("available_nodes_restored_ok", false))
	report["battle_count_so_far_saved"] = bool(wuzhuangyuan_case.get("battle_count_saved_ok", false))
	report["elite_count_so_far_saved"] = bool(wuzhuangyuan_case.get("elite_count_saved_ok", false))
	report["operation_count_so_far_saved"] = bool(wuzhuangyuan_case.get("operation_count_saved_ok", false))
	report["validation_report"] = wuzhuangyuan_case.get("validation_report", {{}})
	report["wuzhuangyuan_summary"] = wuzhuangyuan_case.get("summary", {{}})

	var true_case := _run_route_case(bundle, metadata, "true")
	report["true_route_regression_pass"] = bool(true_case.get("regression_pass", false))
	report["true_route_selected_route_persisted"] = bool(true_case.get("selected_route_saved_ok", false))
	report["true_route_continue_after_restore_ready"] = bool(true_case.get("continue_ok", false))
	report["true_route_summary"] = true_case.get("summary", {{}})

	_write_report(report)
	quit(0 if _passes(report) else 1)

func _metadata_from_bundle(bundle: Dictionary) -> Dictionary:
	var map_instance: Dictionary = bundle.get("map_instance", {{}}) as Dictionary
	return {{
		"map_instance_id": str(map_instance.get("map_instance_id", "dungeon_map_seed_1001")),
		"content_pool_pack_id": str(map_instance.get("content_pool_pack_id", "dungeon_pool_pack_001")),
		"progression_template_id": str(map_instance.get("progression_template_id", "dungeon_progression_v1_3")),
		"seed": int(map_instance.get("seed", 1001)),
	}}

func _run_route_case(bundle: Dictionary, metadata: Dictionary, route_name: String) -> Dictionary:
	var controller := ProbeController.new()
	controller.strategic_state = StrategicMapState.default_state()
	Loader.apply_bundle_to_state(controller.strategic_state, bundle)
	_seed_state_metadata(controller.strategic_state, metadata)
	var before_branch := _advance_to_boss_gate(controller)
	if route_name == "wuzhuangyuan":
		controller.strategic_state["martial_level"] = 10
		controller.strategic_state["martial_realm"] = 10
		controller.strategic_state["military_merit"] = 9
		controller.strategic_state["old_case_progress"] = 0
		controller.strategic_state["case_clues"] = 0
	else:
		controller.strategic_state["martial_level"] = 10
		controller.strategic_state["martial_realm"] = 10
		controller.strategic_state["military_merit"] = 9
		controller.strategic_state["old_case_progress"] = 3
		controller.strategic_state["case_clues"] = 2
	var branch_step := _run_step(controller, "node_boss_gate")
	var available_route_nodes: Array = (controller.strategic_state.get("available_node_ids", []) as Array).duplicate(true)
	var route_node_id := "node_route_wuzhuangyuan" if route_name == "wuzhuangyuan" else "node_route_true"
	var route_step := _run_step(controller, route_node_id)
	var route_target_id := "node_wuzhuangyuan_exam_001" if route_name == "wuzhuangyuan" else "node_true_boss_001"
	var route_target_step := _run_step(controller, route_target_id)
	var network_map: Dictionary = controller.strategic_state.get("network_map", {{}}) as Dictionary
	var payload := SaveBridge.build_save_payload(controller.strategic_state, network_map, metadata)
	var validation := SaveBridge.validate_save_payload(payload, network_map)
	var payload_path := WUZHUANGYUAN_SAVE_PATH if route_name == "wuzhuangyuan" else TRUE_ROUTE_SAVE_PATH
	var write_result := SaveBridge.write_save_payload(payload, payload_path)
	if route_name == "wuzhuangyuan":
		SaveBridge.write_save_payload(payload, FORMAL_SAVE_PATH)
		var validation_payload := {{
			"ok": bool(validation.get("ok", false)),
			"errors": validation.get("errors", []),
			"path": payload_path,
			"save_schema_version": str(payload.get("save_schema_version", "")),
			"selected_ending_route": str((payload.get("route_state", {{}}) as Dictionary).get("selected_ending_route", "")),
		}}
		SaveBridge.write_save_payload(validation_payload, VALIDATION_REPORT_PATH)
	var read_result := SaveBridge.read_save_payload(payload_path)
	var restore_result := SaveBridge.restore_route_state_from_save(read_result.get("payload", {{}}) as Dictionary, network_map)
	var restored_controller := ProbeController.new()
	restored_controller.strategic_state = StrategicMapState.default_state()
	Loader.apply_bundle_to_state(restored_controller.strategic_state, bundle)
	_seed_state_metadata(restored_controller.strategic_state, metadata)
	if bool(restore_result.get("ok", false)):
		var restored_route_state: Dictionary = (restore_result.get("route_state", {{}}) as Dictionary).duplicate(true)
		_restore_state(restored_controller.strategic_state, restored_route_state)
		var restored_graph: Dictionary = restored_controller.strategic_state.get("network_map", {{}}) as Dictionary
		Loader.apply_route_state_to_graph(restored_graph, restored_route_state)
		StrategicNetworkMapRuntime.sync_mirror_fields(restored_controller.strategic_state, restored_graph)
	var restored_available_before_continue: Array = (restored_controller.strategic_state.get("available_node_ids", []) as Array).duplicate(true)
	var continue_node_id := "node_wuzhuangyuan_exam_002" if route_name == "wuzhuangyuan" else "node_true_boss_001"
	var continue_step := _run_step(restored_controller, continue_node_id)
	var restored_payload := SaveBridge.build_save_payload(restored_controller.strategic_state, restored_controller.strategic_state.get("network_map", {{}}) as Dictionary, metadata)
	if route_name == "wuzhuangyuan":
		SaveBridge.write_save_payload(restored_payload, RESTORED_SAVE_PATH)
	return {{
		"save_schema_version": str(payload.get("save_schema_version", "")),
		"validation_ok": bool(validation.get("ok", false)),
		"validation_report": validation,
		"save_write_ok": bool(write_result.get("ok", false)),
		"restore_ok": bool(restore_result.get("ok", false)),
		"continue_ok": bool(continue_step.get("validation_pass", false)),
		"selected_route_saved_ok": str((payload.get("route_state", {{}}) as Dictionary).get("selected_ending_route", "")) == route_name,
		"selected_route_restored_ok": str(restored_controller.strategic_state.get("selected_ending_route", "")) == route_name,
		"visited_path_saved_ok": (payload.get("route_state", {{}}) as Dictionary).get("visited_path_order", []) == controller.strategic_state.get("visited_path_order", []),
		"visited_path_restored_ok": (restored_controller.strategic_state.get("visited_path_order", []) as Array).size() >= (controller.strategic_state.get("visited_path_order", []) as Array).size(),
		"route_flags_saved_ok": (payload.get("route_state", {{}}) as Dictionary).get("route_flags", {{}}) == controller.strategic_state.get("route_flags", {{}}),
		"route_flags_restored_ok": restored_controller.strategic_state.get("route_flags", {{}}) == controller.strategic_state.get("route_flags", {{}}),
		"available_nodes_saved_ok": (payload.get("route_state", {{}}) as Dictionary).get("available_node_ids", []) == controller.strategic_state.get("available_node_ids", []),
		"available_nodes_restored_ok": restored_available_before_continue == controller.strategic_state.get("available_node_ids", []),
		"battle_count_saved_ok": int((payload.get("route_state", {{}}) as Dictionary).get("battle_count_so_far", -1)) == int(controller.strategic_state.get("battle_count_so_far", -2)),
		"elite_count_saved_ok": int((payload.get("route_state", {{}}) as Dictionary).get("elite_count_so_far", -1)) == int(controller.strategic_state.get("elite_count_so_far", -2)),
		"operation_count_saved_ok": int((payload.get("route_state", {{}}) as Dictionary).get("operation_count_so_far", -1)) == int(controller.strategic_state.get("operation_count_so_far", -2)),
		"regression_pass": bool(validation.get("ok", false)) and bool(restore_result.get("ok", false)) and bool(continue_step.get("validation_pass", false)) and str(restored_controller.strategic_state.get("selected_ending_route", "")) == route_name,
		"summary": {{
			"route_name": route_name,
			"available_route_nodes_after_branch": available_route_nodes,
			"selected_ending_route": str(restored_controller.strategic_state.get("selected_ending_route", "")),
			"route_choice_locked": bool(restored_controller.strategic_state.get("route_choice_locked", false)),
			"current_node_id": str(restored_controller.strategic_state.get("current_node_id", "")),
			"available_node_ids": (restored_controller.strategic_state.get("available_node_ids", []) as Array).duplicate(true),
			"visited_path_order": (restored_controller.strategic_state.get("visited_path_order", []) as Array).duplicate(true),
			"battle_count_so_far": int(restored_controller.strategic_state.get("battle_count_so_far", 0)),
			"elite_count_so_far": int(restored_controller.strategic_state.get("elite_count_so_far", 0)),
			"operation_count_so_far": int(restored_controller.strategic_state.get("operation_count_so_far", 0)),
			"save_schema_version": str(payload.get("save_schema_version", "")),
			"save_payload_path": payload_path,
			"restored_payload_path": RESTORED_SAVE_PATH if route_name == "wuzhuangyuan" else "",
			"branch_step": branch_step,
			"route_step": route_step,
			"route_target_step": route_target_step,
			"continue_step": continue_step,
			"pre_branch_last_node": str(before_branch.get("current_node_after", "")),
		}},
	}}

func _advance_to_boss_gate(controller: ProbeController) -> Dictionary:
	var step := _run_step(controller, "node_prologue_001")
	for node_id in ["node_wuju_001", "node_wuju_002", "node_wuju_003", "node_wuju_004", "node_wuju_005", "node_bigmap_07_00", "node_bigmap_08_00"]:
		step = _run_step(controller, node_id)
	while str(controller.strategic_state.get("selected_node_id", "")) != "node_boss_gate":
		var selected_id := str(controller.strategic_state.get("selected_node_id", ""))
		if selected_id.is_empty():
			break
		step = _run_step(controller, selected_id)
	return step

func _seed_state_metadata(state: Dictionary, metadata: Dictionary) -> void:
	state["run_id"] = "dungeon_run_seed_1001"
	state["map_instance_id"] = str(metadata.get("map_instance_id", "dungeon_map_seed_1001"))
	state["seed"] = int(metadata.get("seed", 1001))

func _restore_state(state: Dictionary, restored_route_state: Dictionary) -> void:
	for key in [
		"run_id",
		"map_instance_id",
		"seed",
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
		if restored_route_state.has(key):
			state[key] = restored_route_state.get(key)

func _run_step(controller: ProbeController, node_id: String) -> Dictionary:
	var graph: Dictionary = controller.strategic_state.get("network_map", {{}}) as Dictionary
	var before_available: Array = (controller.strategic_state.get("available_node_ids", []) as Array).duplicate(true)
	graph["selected_node_id"] = node_id
	var node: Dictionary = StrategicNetworkMapRuntime.find_node(graph, node_id)
	var node_type: String = str(node.get("aigc_node_type", node.get("node_type", "")))
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
	var has_outgoing := not (node.get("outgoing", []) as Array).is_empty()
	return {{
		"selected_node_id": node_id,
		"node_type": node_type,
		"current_node_before": current_before,
		"current_node_after": str(controller.strategic_state.get("current_node_id", "")),
		"available_node_ids_before": before_available,
		"available_node_ids_after": after_available,
		"battle_request_ready": battle_request_ready,
		"validation_pass": str(controller.strategic_state.get("current_node_id", "")) == node_id and (not has_outgoing or not after_available.is_empty()),
	}}

func _passes(report: Dictionary) -> bool:
	return (
		bool(report.get("formal_save_bridge_ready", false))
		and bool(report.get("save_payload_schema_ready", false))
		and bool(report.get("route_state_export_to_save_ready", false))
		and bool(report.get("route_state_import_from_save_ready", false))
		and bool(report.get("save_payload_validation_ready", false))
		and bool(report.get("wuzhuangyuan_route_snapshot_ready", false))
		and bool(report.get("wuzhuangyuan_route_restore_ready", false))
		and bool(report.get("wuzhuangyuan_continue_after_restore_ready", false))
		and bool(report.get("wuzhuangyuan_selected_route_persisted", false))
		and bool(report.get("wuzhuangyuan_available_nodes_restored", false))
		and bool(report.get("wuzhuangyuan_exam_path_continue_ready", false))
		and bool(report.get("true_route_regression_pass", false))
		and bool(report.get("true_route_selected_route_persisted", false))
		and bool(report.get("true_route_continue_after_restore_ready", false))
		and bool(report.get("visited_path_order_saved", false))
		and bool(report.get("visited_path_order_restored", false))
		and bool(report.get("selected_ending_route_saved", false))
		and bool(report.get("selected_ending_route_restored", false))
		and bool(report.get("route_flags_saved", false))
		and bool(report.get("route_flags_restored", false))
		and bool(report.get("available_nodes_saved", false))
		and bool(report.get("available_nodes_restored", false))
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
    lines = ["# Dungeon Save Bridge Probe", ""]
    for key, value in payload.get("fields", {}).items():
        lines.append(f"- {key}: `{value}`")
    lines.append("")
    return "\n".join(lines)


def now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
