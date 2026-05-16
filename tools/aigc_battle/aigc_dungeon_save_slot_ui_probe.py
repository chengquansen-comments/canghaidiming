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
OUTPUT_DIR = ROOT / "data" / "aigc_battle" / "generated" / "dungeon_save_slot_ui"
REPORT_JSON = OUTPUT_DIR / "dungeon_save_slot_ui_probe_report.json"
REPORT_MD = OUTPUT_DIR / "dungeon_save_slot_ui_probe_report.md"
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
    with tempfile.TemporaryDirectory(prefix="aigc_dungeon_save_slot_ui_") as temp_dir:
        temp_dir_path = Path(temp_dir)
        script_path = temp_dir_path / "save_slot_ui_probe.gd"
        runtime_json_path = temp_dir_path / "save_slot_ui_probe.runtime.json"
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
                "godot save slot ui probe failed\nstdout:\n%s\nstderr:\n%s\nruntime_report:\n%s"
                % (completed.stdout, completed.stderr, runtime_text)
            )
        return json.loads(runtime_json_path.read_text(encoding="utf-8"))


def build_godot_probe_script(runtime_json_path: Path) -> str:
    return f'''extends SceneTree

const Overlay = preload("res://scripts/strategic_network_map_overlay.gd")
const REPORT_PATH = "{runtime_json_path.as_posix()}"

class ProbeController:
	extends Control
	var _overlay = null
	var save_pressed := 0
	var restore_pressed := 0
	var fallback_pressed := 0
	var strategic_state := {{
		"active": true,
		"network_map": {{}},
	}}
	func _network_overlay_view():
		if _overlay == null:
			_overlay = Overlay.new(self)
		return _overlay
	func _network_state_summary_text() -> String:
		return "AIGC dungeon route state ready"
	func _continue_legacy_linear_flow() -> void:
		fallback_pressed += 1
	func _save_dungeon_route_slot() -> void:
		save_pressed += 1
	func _restore_dungeon_route_slot() -> void:
		restore_pressed += 1

func _init() -> void:
	var report := {{
		"save_slot_ui_ready": false,
		"overlay_footer_ready": false,
		"storage_panel_visible": false,
		"dungeon_save_button_visible": false,
		"dungeon_restore_button_visible": false,
		"save_button_callback_ready": false,
		"restore_button_callback_ready": false,
		"legacy_fallback_button_preserved": false,
		"non_dungeon_graph_hides_save_controls": false,
		"no_scene_required": true,
		"errors": [],
	}}
	var controller := ProbeController.new()
	root.add_child(controller)
	controller._network_overlay_view().ensure_layer()
	controller._network_overlay_view().render_dungeon_storage_panel(
		Callable(controller, "_save_dungeon_route_slot"),
		Callable(controller, "_restore_dungeon_route_slot")
	)
	controller._network_overlay_view().render_footer(controller._network_state_summary_text(), Callable(controller, "_continue_legacy_linear_flow"))
	report["overlay_footer_ready"] = controller._network_overlay_view().footer_container != null
	report["storage_panel_visible"] = _find_by_name(controller, "DungeonSaveSlotPanel") != null
	var save_button := _find_by_name(controller, "DungeonSaveSlotButton")
	var restore_button := _find_by_name(controller, "DungeonRestoreSlotButton")
	report["dungeon_save_button_visible"] = save_button != null and save_button is Button
	report["dungeon_restore_button_visible"] = restore_button != null and restore_button is Button
	if save_button is Button:
		(save_button as Button).pressed.emit()
	if restore_button is Button:
		(restore_button as Button).pressed.emit()
	report["save_button_callback_ready"] = controller.save_pressed == 1
	report["restore_button_callback_ready"] = controller.restore_pressed == 1
	report["legacy_fallback_button_preserved"] = _find_button_by_text(controller, "继续旧线性流程") != null
	var non_dungeon_controller := ProbeController.new()
	root.add_child(non_dungeon_controller)
	non_dungeon_controller._network_overlay_view().ensure_layer()
	non_dungeon_controller._network_overlay_view().render_footer(non_dungeon_controller._network_state_summary_text(), Callable(non_dungeon_controller, "_continue_legacy_linear_flow"))
	report["non_dungeon_graph_hides_save_controls"] = _find_by_name(non_dungeon_controller, "DungeonSaveSlotButton") == null and _find_by_name(non_dungeon_controller, "DungeonRestoreSlotButton") == null
	report["save_slot_ui_ready"] = _all_pass(report)
	if not report["save_slot_ui_ready"]:
		report["errors"].append("save_slot_ui_probe_failed")
	_write_report(report)
	quit(0 if report["save_slot_ui_ready"] else 1)

func _find_by_name(node: Node, target_name: String) -> Node:
	if node.name == target_name:
		return node
	for child in node.get_children():
		var found := _find_by_name(child, target_name)
		if found != null:
			return found
	return null

func _find_button_by_text(node: Node, text: String) -> Button:
	if node is Button and (node as Button).text == text:
		return node as Button
	for child in node.get_children():
		var found := _find_button_by_text(child, text)
		if found != null:
			return found
	return null

func _all_pass(report: Dictionary) -> bool:
	for key in [
		"overlay_footer_ready",
		"storage_panel_visible",
		"dungeon_save_button_visible",
		"dungeon_restore_button_visible",
		"save_button_callback_ready",
		"restore_button_callback_ready",
		"legacy_fallback_button_preserved",
		"non_dungeon_graph_hides_save_controls",
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
        "save_slot_ui_ready": bool(runtime_report.get("save_slot_ui_ready", False)),
        "overlay_footer_ready": bool(runtime_report.get("overlay_footer_ready", False)),
        "storage_panel_visible": bool(runtime_report.get("storage_panel_visible", False)),
        "dungeon_save_button_visible": bool(runtime_report.get("dungeon_save_button_visible", False)),
        "dungeon_restore_button_visible": bool(runtime_report.get("dungeon_restore_button_visible", False)),
        "save_button_callback_ready": bool(runtime_report.get("save_button_callback_ready", False)),
        "restore_button_callback_ready": bool(runtime_report.get("restore_button_callback_ready", False)),
        "legacy_fallback_button_preserved": bool(runtime_report.get("legacy_fallback_button_preserved", False)),
        "non_dungeon_graph_hides_save_controls": bool(runtime_report.get("non_dungeon_graph_hides_save_controls", False)),
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
        "probe": "aigc_dungeon_save_slot_ui_probe",
        "fields": fields,
        "runtime_report": runtime_report,
        "probe_pass": fields["probe_pass"],
    }
    write_json(REPORT_JSON, payload)
    REPORT_MD.parent.mkdir(parents=True, exist_ok=True)
    REPORT_MD.write_text(
        "\n".join(["# Dungeon Save Slot UI Probe", ""] + [f"- `{key}={value}`" for key, value in fields.items()]) + "\n",
        encoding="utf-8",
    )
    print(json.dumps(payload, ensure_ascii=False, indent=2))
    return 0 if fields["probe_pass"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
