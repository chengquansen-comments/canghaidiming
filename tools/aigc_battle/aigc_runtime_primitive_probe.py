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
PROFILE_ID = "posture_opening_pressure_v0_1"


def main(argv: list[str]) -> int:
    if len(argv) != 1:
        print("usage: python3 tools/aigc_battle/aigc_runtime_primitive_probe.py", file=sys.stderr)
        return 1

    run_serial([sys.executable, "tools/aigc_battle/build_content_for_profile.py", PROFILE_ID])
    run_serial([sys.executable, "tools/aigc_battle/validate_content_pack.py", PROFILE_ID])
    run_serial([sys.executable, "tools/aigc_battle/export_runtime_manifest.py", PROFILE_ID])
    run_serial([sys.executable, "tools/aigc_battle/switch_active_profile.py", PROFILE_ID])
    run_serial([sys.executable, "tools/aigc_battle/aigc_formal_sequence_probe.py"])
    run_serial([sys.executable, "tools/aigc_battle/aigc_full_sequence_reward_probe.py"])
    run_serial([sys.executable, "tools/aigc_battle/aigc_sequence_balance_probe.py"])

    generated_dir = GENERATED_DIR / PROFILE_ID
    report_json_path = generated_dir / "runtime_primitive_probe_report.json"
    for path in [
        generated_dir / "runtime_manifest.json",
        generated_dir / "formal_sequence_inventory.generated.json",
        generated_dir / "validation_report.json",
        RUNTIME_DIR / "active_profile.json",
    ]:
        if not path.exists():
            raise SystemExit(f"runtime primitive probe missing file: {path}")

    godot_bin = shutil.which("godot4") or shutil.which("godot")
    if godot_bin is None:
        raise SystemExit("godot/godot4 command not found")

    with tempfile.TemporaryDirectory(prefix="aigc_runtime_primitive_probe_") as temp_dir:
        temp_script_path = Path(temp_dir) / "runtime_primitive_probe.gd"
        temp_script_path.write_text(build_godot_probe_script(report_json_path), encoding="utf-8")
        env = os.environ.copy()
        env.update({"HOME": "/private/tmp"})
        subprocess.run([godot_bin, "--headless", "--path", str(ROOT), "--script", str(temp_script_path)], check=True, cwd=ROOT, env=env)

    report = read_json(report_json_path)
    write_markdown_report(generated_dir / "runtime_primitive_probe_report.md", report)
    print("runtime primitive probe complete")
    return 0 if report.get("probe_pass", False) else 1


def build_godot_probe_script(report_json_path: Path) -> str:
    template = r'''extends SceneTree

const Loader = preload("res://scripts/aigc_battle/aigc_battle_runtime_manifest_loader.gd")
const NarrativeBattleContext = preload("res://scripts/narrative_battle_context.gd")
const MainVisual = preload("res://scenes/MainVisual.tscn")
const INVENTORY_PATH = "res://data/aigc_battle/generated/__PROFILE_ID__/formal_sequence_inventory.generated.json"
const REPORT_PATH = "__REPORT_PATH__"

func _init() -> void:
	var report := {
		"active_profile_loaded": false,
		"runtime_manifest_loaded": false,
		"new_runtime_primitive_id": "opening_pressure",
		"new_runtime_effect_supported": true,
		"profile_declares_new_primitive": false,
		"generated_sequence_uses_new_primitive": false,
		"opening_pressure_slot_count": 0,
		"formal_encounter_total_count": 0,
		"opening_pressure_all_slots_covered": false,
		"opening_pressure_values_in_range": false,
		"opening_pressure_curve_ready": false,
		"manifest_exports_opening_pressure": false,
		"godot_loader_reads_opening_pressure": false,
		"opening_pressure_applied_count": 0,
		"opening_pressure_applied_fields": [],
		"formal_sequence_shows_new_primitive": false,
		"runtime_primitive_apply_blocked": true,
		"fallback_loadout_count": 0,
		"mechanic_expansion_full_sequence_playable": false,
		"probe_pass": false
	}
	if not Loader.load_active_manifest():
		report["error"] = Loader.get_last_error()
		_write_report(report)
		quit(1)
		return
	report["active_profile_loaded"] = true
	report["runtime_manifest_loaded"] = Loader.is_loaded()
	var summary: Dictionary = Loader.get_manifest_summary()
	var inventory: Array = _read_inventory()
	report["formal_encounter_total_count"] = inventory.size()
	var runtime_primitives: Array = summary.get("runtime_primitives", [])
	report["profile_declares_new_primitive"] = runtime_primitives.has("opening_pressure")
	report["manifest_exports_opening_pressure"] = runtime_primitives.has("opening_pressure")
	var primitive_summary: Dictionary = summary.get("runtime_primitive_summary", {})
	report["opening_pressure_curve_ready"] = bool(primitive_summary.get("opening_pressure_curve_ready", false))
	var applied_fields_set := {}
	var loader_reads_ok := true
	var values_in_range_ok := true
	var all_slots_covered := true
	for item_variant in inventory:
		var item: Dictionary = item_variant
		var encounter_id := str(item.get("formal_encounter_id", ""))
		var battle_id := str(item.get("formal_battle_id", ""))
		var loadout: Dictionary = Loader.get_generated_loadout(encounter_id, battle_id)
		if loadout.is_empty() or str(loadout.get("loadout_source", "")) != "generated_manifest":
			report["fallback_loadout_count"] = int(report.get("fallback_loadout_count", 0)) + 1
			all_slots_covered = false
			loader_reads_ok = false
			continue
		var opening_pressure: Dictionary = Loader.get_opening_pressure(encounter_id, battle_id)
		if opening_pressure.is_empty():
			all_slots_covered = false
			loader_reads_ok = false
			continue
		report["opening_pressure_slot_count"] = int(report.get("opening_pressure_slot_count", 0)) + 1
		var momentum_bonus := int(opening_pressure.get("enemy_start_momentum_bonus", 0))
		var block_bonus := int(opening_pressure.get("enemy_start_block_bonus", 0))
		if momentum_bonus < 0 or momentum_bonus > 4 or block_bonus < 0 or block_bonus > 8:
			values_in_range_ok = false
		if not (loadout.get("runtime_primitives", []) as Array).has("opening_pressure"):
			loader_reads_ok = false
		var node: Node = await _start_visual_battle(encounter_id, battle_id, str(item.get("node_id", "narrative_probe")))
		if int(node.get("last_opening_pressure_enemy_momentum_bonus")) != momentum_bonus:
			loader_reads_ok = false
		if int(node.get("last_opening_pressure_enemy_block_bonus")) != block_bonus:
			loader_reads_ok = false
		if not bool(node.get("last_opening_pressure_applied")):
			loader_reads_ok = false
		else:
			report["opening_pressure_applied_count"] = int(report.get("opening_pressure_applied_count", 0)) + 1
		for field_variant in node.get("last_opening_pressure_applied_fields"):
			applied_fields_set[str(field_variant)] = true
		node.queue_free()
		await process_frame
	report["generated_sequence_uses_new_primitive"] = int(report.get("opening_pressure_slot_count", 0)) == inventory.size() and inventory.size() > 0
	report["opening_pressure_all_slots_covered"] = all_slots_covered and int(report.get("opening_pressure_slot_count", 0)) == inventory.size()
	report["opening_pressure_values_in_range"] = values_in_range_ok
	report["godot_loader_reads_opening_pressure"] = loader_reads_ok
	report["opening_pressure_applied_fields"] = applied_fields_set.keys()
	report["formal_sequence_shows_new_primitive"] = int(report.get("opening_pressure_applied_count", 0)) == inventory.size()
	report["runtime_primitive_apply_blocked"] = not bool(report.get("formal_sequence_shows_new_primitive", false))
	report["mechanic_expansion_full_sequence_playable"] = bool(report.get("profile_declares_new_primitive", false)) and bool(report.get("generated_sequence_uses_new_primitive", false)) and bool(report.get("opening_pressure_all_slots_covered", false)) and bool(report.get("opening_pressure_values_in_range", false)) and bool(report.get("opening_pressure_curve_ready", false)) and bool(report.get("manifest_exports_opening_pressure", false)) and bool(report.get("godot_loader_reads_opening_pressure", false)) and int(report.get("opening_pressure_applied_count", 0)) == inventory.size() and int(report.get("fallback_loadout_count", 0)) == 0
	report["probe_pass"] = bool(report.get("mechanic_expansion_full_sequence_playable", false)) and not bool(report.get("runtime_primitive_apply_blocked", true))
	_write_report(report)
	quit(0 if bool(report.get("probe_pass", false)) else 1)

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


def write_markdown_report(path: Path, report: dict[str, Any]) -> None:
    lines = [
        "# AIGC Battle v7 Runtime Primitive Probe",
        "",
        f"- new_runtime_primitive_id: {report['new_runtime_primitive_id']}",
        f"- profile_declares_new_primitive: {str(report['profile_declares_new_primitive']).lower()}",
        f"- generated_sequence_uses_new_primitive: {str(report['generated_sequence_uses_new_primitive']).lower()}",
        f"- opening_pressure_slot_count: {report['opening_pressure_slot_count']}",
        f"- formal_encounter_total_count: {report['formal_encounter_total_count']}",
        f"- opening_pressure_all_slots_covered: {str(report['opening_pressure_all_slots_covered']).lower()}",
        f"- opening_pressure_values_in_range: {str(report['opening_pressure_values_in_range']).lower()}",
        f"- opening_pressure_curve_ready: {str(report['opening_pressure_curve_ready']).lower()}",
        f"- manifest_exports_opening_pressure: {str(report['manifest_exports_opening_pressure']).lower()}",
        f"- godot_loader_reads_opening_pressure: {str(report['godot_loader_reads_opening_pressure']).lower()}",
        f"- opening_pressure_applied_count: {report['opening_pressure_applied_count']}",
        f"- opening_pressure_applied_fields: {report['opening_pressure_applied_fields']}",
        f"- runtime_primitive_apply_blocked: {str(report['runtime_primitive_apply_blocked']).lower()}",
        f"- fallback_loadout_count: {report['fallback_loadout_count']}",
        f"- mechanic_expansion_full_sequence_playable: {str(report['mechanic_expansion_full_sequence_playable']).lower()}",
        f"- probe_pass: {str(report['probe_pass']).lower()}",
    ]
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
