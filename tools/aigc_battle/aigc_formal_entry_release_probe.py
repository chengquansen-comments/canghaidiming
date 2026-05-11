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
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from tools.aigc_battle import aigc_release_gate as release_lib

REPORT_DIR = ROOT / 'data' / 'aigc_battle' / 'generated' / 'release_smoke'
REPORT_JSON = REPORT_DIR / 'formal_entry_release_probe_report.json'
REPORT_MD = REPORT_DIR / 'formal_entry_release_probe_report.md'


def main(argv: list[str]) -> int:
    if len(argv) != 1:
        print('usage: python3 tools/aigc_battle/aigc_formal_entry_release_probe.py', file=sys.stderr)
        return 1
    current = release_lib.read_release_channel('current', required=True)
    activation = release_lib.activate_current_release()
    active_profile = activation.get('active_profile', {})
    generated_dir = (ROOT / str(active_profile.get('runtime_manifest_path', ''))).parent
    inventory_path = generated_dir / 'formal_sequence_inventory.generated.json'
    if not inventory_path.exists():
        raise SystemExit(f'formal entry probe missing file: {inventory_path}')

    run_serial([sys.executable, 'tools/aigc_battle/aigc_formal_sequence_probe.py'])
    run_serial([sys.executable, 'tools/aigc_battle/aigc_full_sequence_reward_probe.py'])
    formal_sequence_report = read_json(generated_dir / 'formal_sequence_probe_report.json')
    reward_report = read_json(generated_dir / 'full_sequence_reward_probe_report.json')
    godot_report = run_godot_probe(inventory_path, REPORT_JSON)

    current_release_loaded = bool(current)
    active_profile_matches_current_release = bool(activation.get('active_profile_matches_current_release', False))
    full_sequence_generated_loadout_count = int(godot_report.get('full_sequence_generated_loadout_count', 0))
    formal_encounter_total_count = int(godot_report.get('formal_encounter_total_count', 0))
    fallback_loadout_count = int(godot_report.get('fallback_loadout_count', 0))
    reward_coverage_complete = bool(reward_report.get('all_generated_slots_have_reward', False)) and int(reward_report.get('fallback_loadout_count', 0)) == 0
    release_runtime_primitive_ready = bool(godot_report.get('release_runtime_primitive_ready', False))
    report = {
        'current_release_loaded': current_release_loaded,
        'active_profile_matches_current_release': active_profile_matches_current_release,
        'formal_entry_probe_ready': True,
        'formal_entry_uses_release_pack': bool(godot_report.get('formal_entry_uses_release_pack', False)),
        'formal_entry_not_debug_only': bool(godot_report.get('formal_entry_not_debug_only', False)),
        'formal_entry_not_mini_route': bool(godot_report.get('formal_entry_not_mini_route', False)),
        'full_sequence_generated_loadout_count': full_sequence_generated_loadout_count,
        'formal_encounter_total_count': formal_encounter_total_count,
        'fallback_loadout_count': fallback_loadout_count,
        'reward_coverage_complete': reward_coverage_complete,
        'release_runtime_primitive_ready': release_runtime_primitive_ready,
        'release_pack_source_confirmed': bool(godot_report.get('release_pack_source_confirmed', False)),
        'probe_pass': (
            current_release_loaded
            and active_profile_matches_current_release
            and bool(godot_report.get('formal_entry_uses_release_pack', False))
            and bool(godot_report.get('formal_entry_not_debug_only', False))
            and bool(godot_report.get('formal_entry_not_mini_route', False))
            and full_sequence_generated_loadout_count == 15
            and fallback_loadout_count == 0
            and reward_coverage_complete
            and release_runtime_primitive_ready
            and bool(godot_report.get('release_pack_source_confirmed', False))
            and bool(formal_sequence_report.get('all_formal_battles_use_generated_loadout', False))
        ),
    }
    write_json(REPORT_JSON, report)
    REPORT_MD.write_text(build_markdown(report), encoding='utf-8')
    print('formal entry release probe complete')
    return 0 if report['probe_pass'] else 1


def run_godot_probe(inventory_path: Path, report_json_path: Path) -> dict[str, Any]:
    godot_bin = shutil.which('godot4') or shutil.which('godot')
    if godot_bin is None:
        raise SystemExit('godot/godot4 command not found')
    inventory_res_path = 'res://' + inventory_path.relative_to(ROOT).as_posix()
    with tempfile.TemporaryDirectory(prefix='aigc_formal_entry_release_probe_') as temp_dir:
        temp_script_path = Path(temp_dir) / 'formal_entry_release_probe.gd'
        temp_script_path.write_text(build_godot_probe_script(inventory_res_path, report_json_path), encoding='utf-8')
        env = os.environ.copy()
        env.update({'HOME': '/private/tmp'})
        subprocess.run([godot_bin, '--headless', '--path', str(ROOT), '--script', str(temp_script_path)], check=True, cwd=ROOT, env=env)
    return read_json(report_json_path)


def build_godot_probe_script(inventory_res_path: str, report_json_path: Path) -> str:
    return r'''extends SceneTree

const Loader = preload("res://scripts/aigc_battle/aigc_battle_runtime_manifest_loader.gd")
const NarrativeBattleContext = preload("res://scripts/narrative_battle_context.gd")
const MainVisual = preload("res://scenes/MainVisual.tscn")
const INVENTORY_PATH = "__INVENTORY_PATH__"
const REPORT_PATH = "__REPORT_PATH__"

func _init() -> void:
	var report := {
		"formal_entry_uses_release_pack": false,
		"formal_entry_not_debug_only": false,
		"formal_entry_not_mini_route": false,
		"full_sequence_generated_loadout_count": 0,
		"formal_encounter_total_count": 0,
		"fallback_loadout_count": 0,
		"release_runtime_primitive_ready": false,
		"release_pack_source_confirmed": false
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
	for item_variant in inventory:
		var item: Dictionary = item_variant
		var encounter_id := str(item.get("formal_encounter_id", ""))
		var battle_id := str(item.get("formal_battle_id", ""))
		var node_id := str(item.get("node_id", "formal_release_probe"))
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
		if str(node.get("last_release_content_pack_id")) != str(loadout.get("content_pack_id", "")):
			release_pack_ok = false
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
	report["formal_entry_not_mini_route"] = inventory.size() == 15
	report["release_runtime_primitive_ready"] = primitive_ok
	report["release_pack_source_confirmed"] = release_pack_ok and source_ok
	_write_report(report)
	quit(0 if bool(report.get("formal_entry_uses_release_pack", false)) and bool(report.get("release_pack_source_confirmed", false)) else 1)

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
'''.replace('__INVENTORY_PATH__', inventory_res_path).replace('__REPORT_PATH__', report_json_path.as_posix())


def run_serial(command: list[str]) -> None:
    subprocess.run(command, check=True, cwd=ROOT)


def read_json(path: Path) -> Any:
    return json.loads(path.read_text(encoding='utf-8'))


def write_json(path: Path, payload: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')


def build_markdown(report: dict[str, Any]) -> str:
    lines = [
        '# R1 Formal Entry Release Probe',
        '',
        f"- current_release_loaded: `{report['current_release_loaded']}`",
        f"- active_profile_matches_current_release: `{report['active_profile_matches_current_release']}`",
        f"- formal_entry_probe_ready: `{report['formal_entry_probe_ready']}`",
        f"- formal_entry_uses_release_pack: `{report['formal_entry_uses_release_pack']}`",
        f"- formal_entry_not_debug_only: `{report['formal_entry_not_debug_only']}`",
        f"- formal_entry_not_mini_route: `{report['formal_entry_not_mini_route']}`",
        f"- full_sequence_generated_loadout_count: `{report['full_sequence_generated_loadout_count']}`",
        f"- formal_encounter_total_count: `{report['formal_encounter_total_count']}`",
        f"- fallback_loadout_count: `{report['fallback_loadout_count']}`",
        f"- reward_coverage_complete: `{report['reward_coverage_complete']}`",
        f"- release_runtime_primitive_ready: `{report['release_runtime_primitive_ready']}`",
        f"- release_pack_source_confirmed: `{report['release_pack_source_confirmed']}`",
        f"- probe_pass: `{report['probe_pass']}`",
    ]
    return '\n'.join(lines) + '\n'


if __name__ == '__main__':
    raise SystemExit(main(sys.argv))
