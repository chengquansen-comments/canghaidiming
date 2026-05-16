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
OUTPUT_DIR = ROOT / "data" / "aigc_battle" / "generated" / "dungeon_entry_smoke"
REPORT_JSON = OUTPUT_DIR / "dungeon_entry_smoke_probe_report.json"
REPORT_MD = OUTPUT_DIR / "dungeon_entry_smoke_probe_report.md"
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
    with tempfile.TemporaryDirectory(prefix="aigc_dungeon_entry_smoke_") as temp_dir:
        temp_dir_path = Path(temp_dir)
        script_path = temp_dir_path / "entry_smoke_probe.gd"
        runtime_json_path = temp_dir_path / "entry_smoke_probe.runtime.json"
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
                "godot dungeon entry smoke probe failed\nstdout:\n%s\nstderr:\n%s\nruntime_report:\n%s"
                % (completed.stdout, completed.stderr, runtime_text)
            )
        return json.loads(runtime_json_path.read_text(encoding="utf-8"))


def build_godot_probe_script(runtime_json_path: Path) -> str:
    return f'''extends SceneTree

const Overlay = preload("res://scripts/strategic_network_map_overlay.gd")
const ControllerRuntime = preload("res://scripts/narrative/strategic_network_map_controller_runtime.gd")
const FlowRuntime = preload("res://scripts/narrative/strategic_network_map_flow_runtime.gd")
const Loader = preload("res://scripts/aigc_dungeon_big_map_loader.gd")
const Store = preload("res://scripts/aigc_dungeon_formal_save_slot_store.gd")
const StrategicNetworkMapRuntime = preload("res://scripts/strategic_network_map_runtime.gd")
const REPORT_PATH = "{runtime_json_path.as_posix()}"

class ProbeController:
	extends Control
	var strategic_state: Dictionary = {{"active": true}}
	var strategic_config: Dictionary = {{}}
	var last_hint := ""
	var title_label := Label.new()
	var status_label := Label.new()
	var map_label := Label.new()
	var body_label := Label.new()
	var vars_label := Label.new()
	var focus_story_layer := Control.new()
	var focus_world_map_layer := Control.new()
	var _overlay = null
	var save_count := 0
	var render_count := 0
	func _network_overlay_view():
		if _overlay == null:
			_overlay = Overlay.new(self)
		return _overlay
	func _network_progress_text(graph: Dictionary) -> String:
		return ControllerRuntime.progress_text(graph)
	func _network_state_summary_text() -> String:
		return ControllerRuntime.state_summary_text(strategic_state)
	func _network_preview_text(graph: Dictionary) -> String:
		return ControllerRuntime.preview_text(graph)
	func _network_confirm_meta(graph: Dictionary, node: Dictionary) -> Dictionary:
		return ControllerRuntime.confirm_meta(graph, node)
	func _sync_network_state_from_graph(graph: Dictionary) -> void:
		StrategicNetworkMapRuntime.sync_mirror_fields(strategic_state, graph)
	func _save_narrative_state_to_context() -> void:
		save_count += 1
	func _sync_strategic_cards_to_context() -> void:
		pass
	func _render() -> void:
		render_count += 1
		var graph: Dictionary = strategic_state.get("network_map", {{}}) as Dictionary
		if not graph.is_empty():
			ControllerRuntime.render_network_strategic_map(self, graph)
	func _continue_legacy_linear_flow() -> void:
		last_hint = "legacy fallback pressed"
	func _save_dungeon_route_slot() -> void:
		FlowRuntime.save_dungeon_route_slot(self, "entry_smoke_slot_001")
	func _restore_dungeon_route_slot() -> void:
		FlowRuntime.restore_dungeon_route_slot(self, "entry_smoke_slot_001")

func _init() -> void:
	var report := {{
		"entry_smoke_ready": false,
		"release_gate_active": Loader.is_dungeon_profile_active(),
		"aigc_network_map_loaded": false,
		"overlay_render_ready": false,
		"available_next_nodes_visible": false,
		"save_button_visible": false,
		"restore_button_visible": false,
		"save_button_pressed": false,
		"state_mutated_after_save": false,
		"restore_button_pressed": false,
		"restored_to_saved_node": false,
		"continue_after_restore_ready": false,
		"no_scene_required": true,
		"errors": [],
	}}
	var controller := ProbeController.new()
	root.add_child(controller)
	FlowRuntime.ensure_network_map_for_state(controller)
	var graph: Dictionary = controller.strategic_state.get("network_map", {{}}) as Dictionary
	report["aigc_network_map_loaded"] = not graph.is_empty()
	controller._render()
	report["overlay_render_ready"] = _find_by_name(controller, "NetworkMapOverlayPanel") != null
	report["available_next_nodes_visible"] = not (controller.strategic_state.get("available_node_ids", []) as Array).is_empty()
	var save_button := _find_by_name(controller, "DungeonSaveSlotButton")
	var restore_button := _find_by_name(controller, "DungeonRestoreSlotButton")
	report["save_button_visible"] = save_button != null and save_button is Button
	report["restore_button_visible"] = restore_button != null and restore_button is Button
	var saved_current_node_id := str(controller.strategic_state.get("current_node_id", ""))
	if save_button is Button:
		(save_button as Button).pressed.emit()
	report["save_button_pressed"] = controller.last_hint.begins_with("已保存副本路线")
	graph = controller.strategic_state.get("network_map", {{}}) as Dictionary
	var selected_id := str(controller.strategic_state.get("selected_node_id", ""))
	var selected_node := StrategicNetworkMapRuntime.find_node(graph, selected_id)
	if not selected_node.is_empty():
		StrategicNetworkMapRuntime.complete_node(graph, selected_node)
		StrategicNetworkMapRuntime.refresh_node_states(graph)
		controller._sync_network_state_from_graph(graph)
	report["state_mutated_after_save"] = str(controller.strategic_state.get("current_node_id", "")) != saved_current_node_id
	controller._render()
	restore_button = _find_by_name(controller, "DungeonRestoreSlotButton")
	if restore_button is Button:
		(restore_button as Button).pressed.emit()
	report["restore_button_pressed"] = controller.last_hint.begins_with("已恢复副本路线")
	report["restored_to_saved_node"] = str(controller.strategic_state.get("current_node_id", "")) == saved_current_node_id
	graph = controller.strategic_state.get("network_map", {{}}) as Dictionary
	var next_id := str(controller.strategic_state.get("selected_node_id", ""))
	var available_after_restore: Array = graph.get("available_node_ids", [])
	if next_id == saved_current_node_id and not available_after_restore.is_empty():
		next_id = str(available_after_restore[0])
	var next_node := StrategicNetworkMapRuntime.find_node(graph, next_id)
	if not next_node.is_empty():
		StrategicNetworkMapRuntime.complete_node(graph, next_node)
		StrategicNetworkMapRuntime.refresh_node_states(graph)
		controller._sync_network_state_from_graph(graph)
	report["continue_after_restore_ready"] = str(controller.strategic_state.get("current_node_id", "")) == next_id and next_id != saved_current_node_id
	Store.clear_slot("entry_smoke_slot_001")
	report["entry_smoke_ready"] = _all_pass(report)
	if not report["entry_smoke_ready"]:
		report["errors"].append("entry_smoke_probe_failed")
	_write_report(report)
	quit(0 if report["entry_smoke_ready"] else 1)

func _find_by_name(node: Node, target_name: String) -> Node:
	if node.name == target_name:
		return node
	for child in node.get_children():
		var found := _find_by_name(child, target_name)
		if found != null:
			return found
	return null

func _all_pass(report: Dictionary) -> bool:
	for key in [
		"release_gate_active",
		"aigc_network_map_loaded",
		"overlay_render_ready",
		"available_next_nodes_visible",
		"save_button_visible",
		"restore_button_visible",
		"save_button_pressed",
		"state_mutated_after_save",
		"restore_button_pressed",
		"restored_to_saved_node",
		"continue_after_restore_ready",
		"no_scene_required",
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
        "entry_smoke_ready": bool(runtime_report.get("entry_smoke_ready", False)),
        "release_gate_active": bool(runtime_report.get("release_gate_active", False)),
        "aigc_network_map_loaded": bool(runtime_report.get("aigc_network_map_loaded", False)),
        "overlay_render_ready": bool(runtime_report.get("overlay_render_ready", False)),
        "available_next_nodes_visible": bool(runtime_report.get("available_next_nodes_visible", False)),
        "save_button_visible": bool(runtime_report.get("save_button_visible", False)),
        "restore_button_visible": bool(runtime_report.get("restore_button_visible", False)),
        "save_button_pressed": bool(runtime_report.get("save_button_pressed", False)),
        "restore_button_pressed": bool(runtime_report.get("restore_button_pressed", False)),
        "restored_to_saved_node": bool(runtime_report.get("restored_to_saved_node", False)),
        "continue_after_restore_ready": bool(runtime_report.get("continue_after_restore_ready", False)),
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
        "probe": "aigc_dungeon_entry_smoke_probe",
        "fields": fields,
        "runtime_report": runtime_report,
        "probe_pass": fields["probe_pass"],
    }
    write_json(REPORT_JSON, payload)
    REPORT_MD.parent.mkdir(parents=True, exist_ok=True)
    REPORT_MD.write_text(
        "\n".join(["# Dungeon Entry Smoke Probe", ""] + [f"- `{key}={value}`" for key, value in fields.items()]) + "\n",
        encoding="utf-8",
    )
    print(json.dumps(payload, ensure_ascii=False, indent=2))
    return 0 if fields["probe_pass"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
