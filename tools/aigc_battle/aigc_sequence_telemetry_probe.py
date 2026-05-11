#!/usr/bin/env python3
from __future__ import annotations

import json
import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[2]
GENERATED_DIR = ROOT / "data" / "aigc_battle" / "generated"
RUNTIME_DIR = ROOT / "data" / "aigc_battle" / "runtime"
TELEMETRY_PATH = ROOT / "data" / "aigc_battle" / "telemetry" / "aigc_sequence_telemetry.jsonl"
PROFILE_ID = "posture_opening_pressure_v0_1"


def main(argv: list[str]) -> int:
    if len(argv) != 1:
        print("usage: python3 tools/aigc_battle/aigc_sequence_telemetry_probe.py", file=sys.stderr)
        return 1
    run_serial([sys.executable, "tools/aigc_battle/switch_active_profile.py", PROFILE_ID])
    generated_dir = GENERATED_DIR / PROFILE_ID
    runtime_manifest_path = generated_dir / "runtime_manifest.json"
    inventory_path = generated_dir / "formal_sequence_inventory.generated.json"
    for path in [RUNTIME_DIR / "active_profile.json", runtime_manifest_path, inventory_path]:
        if not path.exists():
            raise SystemExit(f"telemetry probe missing file: {path}")
    TELEMETRY_PATH.parent.mkdir(parents=True, exist_ok=True)
    TELEMETRY_PATH.write_text("", encoding="utf-8")

    godot_bin = shutil.which("godot4") or shutil.which("godot")
    if godot_bin is None:
        raise SystemExit("godot/godot4 command not found")

    report_json_path = generated_dir / "telemetry_probe_report.json"
    with tempfile.TemporaryDirectory(prefix="aigc_sequence_telemetry_probe_") as temp_dir:
        temp_script_path = Path(temp_dir) / "telemetry_probe.gd"
        temp_script_path.write_text(build_godot_probe_script(report_json_path), encoding="utf-8")
        env = os.environ.copy()
        env.update({"HOME": "/private/tmp"})
        subprocess.run([godot_bin, "--headless", "--path", str(ROOT), "--script", str(temp_script_path)], check=True, cwd=ROOT, env=env)

    report = read_json(report_json_path)
    write_markdown(generated_dir / "telemetry_probe_report.md", report)
    print("sequence telemetry probe complete")
    return 0 if report.get("telemetry_probe_pass", False) else 1


def build_godot_probe_script(report_json_path: Path) -> str:
    template = r'''extends SceneTree

const Loader = preload("res://scripts/aigc_battle/aigc_battle_runtime_manifest_loader.gd")
const NarrativeBattleContext = preload("res://scripts/narrative_battle_context.gd")
const MainVisual = preload("res://scenes/MainVisual.tscn")
const INVENTORY_PATH = "res://data/aigc_battle/generated/__PROFILE_ID__/formal_sequence_inventory.generated.json"
const TELEMETRY_RES_PATH = "res://data/aigc_battle/telemetry/aigc_sequence_telemetry.jsonl"
const REPORT_PATH = "__REPORT_PATH__"

func _init() -> void:
	var report := {
		"active_profile_loaded": false,
		"runtime_manifest_loaded": false,
		"telemetry_path": ProjectSettings.globalize_path(TELEMETRY_RES_PATH),
		"formal_encounter_total_count": 0,
		"telemetry_event_count": 0,
		"generated_telemetry_event_count": 0,
		"fallback_telemetry_event_count": 0,
		"all_formal_encounters_have_telemetry": false,
		"telemetry_profile_id_matched": false,
		"telemetry_content_pack_id_matched": false,
		"telemetry_runtime_primitives_recorded": false,
		"telemetry_reward_claimed_recorded": false,
		"telemetry_return_flow_recorded": false,
		"telemetry_detail_level": "minimal",
		"telemetry_probe_pass": false
	}
	if not Loader.load_active_manifest():
		report["error"] = Loader.get_last_error()
		_write_report(report)
		quit(1)
		return
	report["active_profile_loaded"] = true
	report["runtime_manifest_loaded"] = Loader.is_loaded()
	var inventory: Array = _read_inventory()
	report["formal_encounter_total_count"] = inventory.size()
	for item_variant in inventory:
		var item: Dictionary = item_variant
		var encounter_id := str(item.get("formal_encounter_id", ""))
		var battle_id := str(item.get("formal_battle_id", ""))
		var node: Node = await _start_visual_battle(encounter_id, battle_id, str(item.get("node_id", "telemetry_probe")))
		node.call("_mark_generated_reward_visible", true)
		node.call("_claim_generated_manifest_reward", "win")
		node.call("_append_generated_telemetry_event", "win")
		await process_frame
		node.queue_free()
		await process_frame
	var events: Array = _read_telemetry_events()
	report["telemetry_event_count"] = events.size()
	var encounter_hits := {}
	var profile_id := ""
	var content_pack_id := ""
	var profile_match := true
	var pack_match := true
	var primitives_ok := true
	var reward_ok := true
	var return_ok := true
	for event_variant in events:
		var event: Dictionary = event_variant
		if str(event.get("loadout_source", "")) != "generated_manifest":
			report["fallback_telemetry_event_count"] = int(report.get("fallback_telemetry_event_count", 0)) + 1
			continue
		report["generated_telemetry_event_count"] = int(report.get("generated_telemetry_event_count", 0)) + 1
		encounter_hits[str(event.get("formal_encounter_id", ""))] = true
		if profile_id.is_empty():
			profile_id = str(event.get("mechanic_profile_id", ""))
			content_pack_id = str(event.get("content_pack_id", ""))
		profile_match = profile_match and str(event.get("mechanic_profile_id", "")) == profile_id and not profile_id.is_empty()
		pack_match = pack_match and str(event.get("content_pack_id", "")) == content_pack_id and not content_pack_id.is_empty()
		primitives_ok = primitives_ok and (event.get("runtime_primitives", []) as Array).has("opening_pressure")
		reward_ok = reward_ok and bool(event.get("reward_claimed", false))
		return_ok = return_ok and bool(event.get("return_flow_completed", false))
	report["all_formal_encounters_have_telemetry"] = encounter_hits.size() == inventory.size() and inventory.size() > 0
	report["telemetry_profile_id_matched"] = profile_match
	report["telemetry_content_pack_id_matched"] = pack_match
	report["telemetry_runtime_primitives_recorded"] = primitives_ok
	report["telemetry_reward_claimed_recorded"] = reward_ok
	report["telemetry_return_flow_recorded"] = return_ok
	report["telemetry_probe_pass"] = bool(report.get("all_formal_encounters_have_telemetry", false)) and int(report.get("generated_telemetry_event_count", 0)) >= inventory.size() and int(report.get("fallback_telemetry_event_count", 0)) == 0 and profile_match and pack_match
	_write_report(report)
	quit(0 if bool(report.get("telemetry_probe_pass", false)) else 1)

func _start_visual_battle(encounter_id: String, battle_id: String, node_id: String) -> Node:
	NarrativeBattleContext.clear()
	NarrativeBattleContext.clear_player_profile()
	NarrativeBattleContext.set_player_profile({
		"role": "spearman",
		"career": "长枪武官",
		"weapon": "长枪",
		"martial_level": 2,
		"battles_won": 1
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

func _read_telemetry_events() -> Array:
	var file := FileAccess.open(ProjectSettings.globalize_path(TELEMETRY_RES_PATH), FileAccess.READ)
	if file == null:
		return []
	var events: Array = []
	for line in file.get_as_text().split("\n"):
		var clean := line.strip_edges()
		if clean.is_empty():
			continue
		var parsed = JSON.parse_string(clean)
		if parsed is Dictionary:
			events.append(parsed)
	return events

func _write_report(report: Dictionary) -> void:
	var file := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(report, "\t"))
'''
    return template.replace("__PROFILE_ID__", PROFILE_ID).replace("__REPORT_PATH__", report_json_path.as_posix())


def run_serial(command: list[str]) -> None:
    subprocess.run(command, check=True, cwd=ROOT)


def read_json(path: Path) -> Any:
    return json.loads(path.read_text(encoding="utf-8"))


def write_markdown(path: Path, report: dict[str, Any]) -> None:
    lines = [
        "# AIGC Battle v8 Telemetry Probe",
        "",
        f"- telemetry_path: {report['telemetry_path']}",
        f"- formal_encounter_total_count: {report['formal_encounter_total_count']}",
        f"- telemetry_event_count: {report['telemetry_event_count']}",
        f"- generated_telemetry_event_count: {report['generated_telemetry_event_count']}",
        f"- fallback_telemetry_event_count: {report['fallback_telemetry_event_count']}",
        f"- all_formal_encounters_have_telemetry: {str(report['all_formal_encounters_have_telemetry']).lower()}",
        f"- telemetry_profile_id_matched: {str(report['telemetry_profile_id_matched']).lower()}",
        f"- telemetry_content_pack_id_matched: {str(report['telemetry_content_pack_id_matched']).lower()}",
        f"- telemetry_runtime_primitives_recorded: {str(report['telemetry_runtime_primitives_recorded']).lower()}",
        f"- telemetry_reward_claimed_recorded: {str(report['telemetry_reward_claimed_recorded']).lower()}",
        f"- telemetry_return_flow_recorded: {str(report['telemetry_return_flow_recorded']).lower()}",
        f"- telemetry_detail_level: {report['telemetry_detail_level']}",
        f"- telemetry_probe_pass: {str(report['telemetry_probe_pass']).lower()}",
    ]
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
