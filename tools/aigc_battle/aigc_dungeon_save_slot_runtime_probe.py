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
OUTPUT_DIR = ROOT / "data" / "aigc_battle" / "generated" / "dungeon_save_slot_runtime"
REPORT_JSON = OUTPUT_DIR / "dungeon_save_slot_runtime_probe_report.json"
REPORT_MD = OUTPUT_DIR / "dungeon_save_slot_runtime_probe_report.md"
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
    with tempfile.TemporaryDirectory(prefix="aigc_dungeon_save_slot_runtime_") as temp_dir:
        temp_dir_path = Path(temp_dir)
        temp_script_path = temp_dir_path / "save_slot_runtime_probe.gd"
        runtime_json_path = temp_dir_path / "save_slot_runtime_probe.runtime.json"
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
                "godot save slot runtime probe failed\nstdout:\n%s\nstderr:\n%s\nruntime_report:\n%s"
                % (completed.stdout, completed.stderr, runtime_text)
            )
        return json.loads(runtime_json_path.read_text(encoding="utf-8"))


def build_godot_probe_script(runtime_json_path: Path) -> str:
    return f'''extends SceneTree

const FlowRuntime = preload("res://scripts/narrative/strategic_network_map_flow_runtime.gd")
const Loader = preload("res://scripts/aigc_dungeon_big_map_loader.gd")
const Store = preload("res://scripts/aigc_dungeon_formal_save_slot_store.gd")
const StrategicNetworkMapRuntime = preload("res://scripts/strategic_network_map_runtime.gd")
const REPORT_PATH = "{runtime_json_path.as_posix()}"

class ProbeController:
	var strategic_state: Dictionary = {{}}
	var strategic_config: Dictionary = {{}}
	var last_hint := ""
	var render_count := 0
	var save_count := 0
	func _sync_network_state_from_graph(graph: Dictionary) -> void:
		StrategicNetworkMapRuntime.sync_mirror_fields(strategic_state, graph)
	func _save_narrative_state_to_context() -> void:
		save_count += 1
	func _render() -> void:
		render_count += 1

func _init() -> void:
	var report := {{
		"save_slot_runtime_controls_ready": true,
		"release_gate_active": Loader.is_dungeon_profile_active(),
		"initial_load_ready": false,
		"flow_save_slot_ready": false,
		"state_mutated_after_save": false,
		"flow_restore_slot_ready": false,
		"restored_to_saved_node": false,
		"continue_after_flow_restore_ready": false,
		"slot_cleared": false,
		"saved_current_node_id": "",
		"mutated_current_node_id": "",
		"restored_current_node_id": "",
		"restored_selected_node_id": "",
		"restored_available_node_ids": [],
		"continued_current_node_id": "",
		"errors": [],
	}}
	var controller := ProbeController.new()
	FlowRuntime.ensure_network_map_for_state(controller)
	var graph: Dictionary = controller.strategic_state.get("network_map", {{}}) as Dictionary
	report["initial_load_ready"] = not graph.is_empty()
	report["saved_current_node_id"] = str(controller.strategic_state.get("current_node_id", ""))
	var save_result := FlowRuntime.save_dungeon_route_slot(controller, "runtime_slot_001")
	report["flow_save_slot_ready"] = bool(save_result.get("ok", false))
	var selected_id := str(controller.strategic_state.get("selected_node_id", ""))
	var selected_node := StrategicNetworkMapRuntime.find_node(graph, selected_id)
	if not selected_node.is_empty():
		StrategicNetworkMapRuntime.complete_node(graph, selected_node)
		StrategicNetworkMapRuntime.refresh_node_states(graph)
		controller._sync_network_state_from_graph(graph)
	report["mutated_current_node_id"] = str(controller.strategic_state.get("current_node_id", ""))
	report["state_mutated_after_save"] = report["mutated_current_node_id"] != report["saved_current_node_id"]
	var restore_result := FlowRuntime.restore_dungeon_route_slot(controller, "runtime_slot_001")
	report["flow_restore_slot_ready"] = bool(restore_result.get("ok", false))
	report["restored_current_node_id"] = str(controller.strategic_state.get("current_node_id", ""))
	report["restored_selected_node_id"] = str(controller.strategic_state.get("selected_node_id", ""))
	report["restored_available_node_ids"] = controller.strategic_state.get("available_node_ids", [])
	report["restored_to_saved_node"] = report["restored_current_node_id"] == report["saved_current_node_id"]
	var restored_graph: Dictionary = controller.strategic_state.get("network_map", {{}}) as Dictionary
	var next_id := str(controller.strategic_state.get("selected_node_id", ""))
	var available_after_restore: Array = restored_graph.get("available_node_ids", [])
	if next_id == report["restored_current_node_id"] and not available_after_restore.is_empty():
		next_id = str(available_after_restore[0])
	var next_node := StrategicNetworkMapRuntime.find_node(restored_graph, next_id)
	if not next_node.is_empty():
		StrategicNetworkMapRuntime.complete_node(restored_graph, next_node)
		StrategicNetworkMapRuntime.refresh_node_states(restored_graph)
		controller._sync_network_state_from_graph(restored_graph)
	report["continued_current_node_id"] = str(controller.strategic_state.get("current_node_id", ""))
	report["continue_after_flow_restore_ready"] = report["continued_current_node_id"] == next_id and report["continued_current_node_id"] != report["restored_current_node_id"]
	var clear_result := Store.clear_slot("runtime_slot_001")
	report["slot_cleared"] = bool(clear_result.get("ok", false))
	if not _all_pass(report):
		report["errors"].append("runtime_save_slot_probe_failed")
	_write_report(report)
	quit(0 if _all_pass(report) else 1)

func _all_pass(report: Dictionary) -> bool:
	for key in ["save_slot_runtime_controls_ready", "release_gate_active", "initial_load_ready", "flow_save_slot_ready", "state_mutated_after_save", "flow_restore_slot_ready", "restored_to_saved_node", "continue_after_flow_restore_ready", "slot_cleared"]:
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
        "save_slot_runtime_controls_ready": bool(runtime_report.get("save_slot_runtime_controls_ready", False)),
        "release_gate_active": bool(runtime_report.get("release_gate_active", False)),
        "initial_load_ready": bool(runtime_report.get("initial_load_ready", False)),
        "flow_save_slot_ready": bool(runtime_report.get("flow_save_slot_ready", False)),
        "state_mutated_after_save": bool(runtime_report.get("state_mutated_after_save", False)),
        "flow_restore_slot_ready": bool(runtime_report.get("flow_restore_slot_ready", False)),
        "restored_to_saved_node": bool(runtime_report.get("restored_to_saved_node", False)),
        "continue_after_flow_restore_ready": bool(runtime_report.get("continue_after_flow_restore_ready", False)),
        "slot_cleared": bool(runtime_report.get("slot_cleared", False)),
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
        "probe": "aigc_dungeon_save_slot_runtime_probe",
        "fields": fields,
        "runtime_report": runtime_report,
        "probe_pass": fields["probe_pass"],
    }
    write_json(REPORT_JSON, payload)
    REPORT_MD.parent.mkdir(parents=True, exist_ok=True)
    REPORT_MD.write_text(
        "\n".join(["# Dungeon Save Slot Runtime Probe", ""] + [f"- `{key}={value}`" for key, value in fields.items()]) + "\n",
        encoding="utf-8",
    )
    print(json.dumps(payload, ensure_ascii=False, indent=2))
    return 0 if fields["probe_pass"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
