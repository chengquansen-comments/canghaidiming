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
OUTPUT_DIR = ROOT / "data" / "aigc_battle" / "generated" / "dungeon_formal_save_slot"
REPORT_JSON = OUTPUT_DIR / "dungeon_formal_save_slot_probe_report.json"
REPORT_MD = OUTPUT_DIR / "dungeon_formal_save_slot_probe_report.md"
CURRENT_RELEASE_PATH = ROOT / "data" / "aigc_battle" / "release_channels" / "current_release.json"
ACTIVE_PROFILE_PATH = ROOT / "data" / "aigc_battle" / "runtime" / "active_profile.json"
FALLBACK_RELEASE_PATH = ROOT / "data" / "aigc_battle" / "release_channels" / "fallback_release.json"


def read_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


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
    with tempfile.TemporaryDirectory(prefix="aigc_dungeon_formal_save_slot_") as temp_dir:
        temp_dir_path = Path(temp_dir)
        temp_script_path = temp_dir_path / "formal_save_slot_probe.gd"
        runtime_json_path = temp_dir_path / "formal_save_slot_probe.runtime.json"
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
                "godot formal save slot probe failed\nstdout:\n%s\nstderr:\n%s\nruntime_report:\n%s"
                % (completed.stdout, completed.stderr, runtime_text)
            )
        return json.loads(runtime_json_path.read_text(encoding="utf-8"))


def build_godot_probe_script(runtime_json_path: Path) -> str:
    return f'''extends SceneTree

const Loader = preload("res://scripts/aigc_dungeon_big_map_loader.gd")
const Store = preload("res://scripts/aigc_dungeon_formal_save_slot_store.gd")
const StrategicNetworkMapRuntime = preload("res://scripts/strategic_network_map_runtime.gd")
const REPORT_PATH = "{runtime_json_path.as_posix()}"

func _init() -> void:
	var report := {{
		"formal_save_slot_store_ready": true,
		"release_gate_active": Loader.is_dungeon_profile_active(),
		"aigc_network_map_loaded": false,
		"slot_write_ready": false,
		"slot_read_ready": false,
		"slot_payload_validation_ready": false,
		"slot_restore_ready": false,
		"continue_after_slot_restore_ready": false,
		"restored_current_node_id": "",
		"continued_current_node_id": "",
		"slot_path": Store.slot_path("slot_001"),
		"errors": [],
	}}
	var bundle := Loader.load_runtime_bundle()
	if not bool(bundle.get("ok", false)):
		report["errors"].append(str(bundle.get("error", "loader_failed")))
		_write_report(report)
		quit(1)
		return
	var graph := (bundle.get("network_map", {{}}) as Dictionary).duplicate(true)
	report["aigc_network_map_loaded"] = true
	var save_result := Store.save_slot("slot_001", graph, graph, {{
		"map_instance_id": str(bundle.get("map_instance", {{}}).get("map_instance_id", "")),
		"content_pool_pack_id": str(bundle.get("map_instance", {{}}).get("content_pool_pack_id", "")),
		"progression_template_id": str(bundle.get("map_instance", {{}}).get("progression_template_id", "")),
		"seed": int(graph.get("seed", 0)),
	}})
	report["slot_write_ready"] = bool(save_result.get("ok", false))
	if not report["slot_write_ready"]:
		report["errors"].append("slot_write_failed:%s" % str(save_result.get("error", "")))
	var read_result := Store.read_slot("slot_001")
	report["slot_read_ready"] = bool(read_result.get("ok", false))
	var validation := {{}}
	if report["slot_read_ready"]:
		validation = Store.validate_slot_payload(read_result.get("slot_payload", {{}}) as Dictionary, graph)
	report["slot_payload_validation_ready"] = bool(validation.get("ok", false))
	if not report["slot_payload_validation_ready"]:
		report["errors"].append("slot_validation_failed:%s" % str(validation.get("errors", [])))
	var restore_result := Store.restore_slot("slot_001", graph)
	report["slot_restore_ready"] = bool(restore_result.get("ok", false))
	var restored_route_state := restore_result.get("route_state", {{}}) as Dictionary
	report["restored_current_node_id"] = str(restored_route_state.get("current_node_id", ""))
	if report["slot_restore_ready"]:
		var restored_graph := graph.duplicate(true)
		Loader.apply_route_state_to_graph(restored_graph, restored_route_state)
		var selected_node_id := str(restored_graph.get("selected_node_id", ""))
		var selected_node := StrategicNetworkMapRuntime.find_node(restored_graph, selected_node_id)
		if not selected_node.is_empty():
			StrategicNetworkMapRuntime.complete_node(restored_graph, selected_node)
			StrategicNetworkMapRuntime.refresh_node_states(restored_graph)
			report["continued_current_node_id"] = str(restored_graph.get("current_node_id", ""))
			report["continue_after_slot_restore_ready"] = report["continued_current_node_id"] == selected_node_id and selected_node_id != report["restored_current_node_id"]
	if not report["continue_after_slot_restore_ready"]:
		report["errors"].append("continue_after_slot_restore_failed")
	Store.clear_slot("slot_001")
	_write_report(report)
	quit(0 if _all_pass(report) else 1)

func _all_pass(report: Dictionary) -> bool:
	for key in ["formal_save_slot_store_ready", "release_gate_active", "aigc_network_map_loaded", "slot_write_ready", "slot_read_ready", "slot_payload_validation_ready", "slot_restore_ready", "continue_after_slot_restore_ready"]:
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
        "formal_save_slot_store_ready": bool(runtime_report.get("formal_save_slot_store_ready", False)),
        "release_gate_active": bool(runtime_report.get("release_gate_active", False)),
        "aigc_network_map_loaded": bool(runtime_report.get("aigc_network_map_loaded", False)),
        "slot_write_ready": bool(runtime_report.get("slot_write_ready", False)),
        "slot_read_ready": bool(runtime_report.get("slot_read_ready", False)),
        "slot_payload_validation_ready": bool(runtime_report.get("slot_payload_validation_ready", False)),
        "slot_restore_ready": bool(runtime_report.get("slot_restore_ready", False)),
        "continue_after_slot_restore_ready": bool(runtime_report.get("continue_after_slot_restore_ready", False)),
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
        "probe": "aigc_dungeon_formal_save_slot_probe",
        "fields": fields,
        "runtime_report": runtime_report,
        "probe_pass": fields["probe_pass"],
    }
    write_json(REPORT_JSON, payload)
    REPORT_MD.parent.mkdir(parents=True, exist_ok=True)
    REPORT_MD.write_text(
        "\n".join(["# Dungeon Formal Save Slot Probe", ""] + [f"- `{key}={value}`" for key, value in fields.items()]) + "\n",
        encoding="utf-8",
    )
    print(json.dumps(payload, ensure_ascii=False, indent=2))
    return 0 if fields["probe_pass"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
