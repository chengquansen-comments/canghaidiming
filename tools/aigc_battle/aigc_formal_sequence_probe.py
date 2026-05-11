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
RUNTIME_DIR = ROOT / "data" / "aigc_battle" / "runtime"
GENERATED_DIR = ROOT / "data" / "aigc_battle" / "generated"


def main(argv: list[str]) -> int:
    if len(argv) > 2:
        print("usage: python tools/aigc_battle/aigc_formal_sequence_probe.py [profile_id]", file=sys.stderr)
        return 1
    profile_id = argv[1] if len(argv) == 2 else read_active_profile_id()
    generated_dir = GENERATED_DIR / profile_id
    active_profile_path = RUNTIME_DIR / "active_profile.json"
    runtime_manifest_path = generated_dir / "runtime_manifest.json"
    inventory_path = generated_dir / "formal_sequence_inventory.generated.json"
    validation_report_path = generated_dir / "validation_report.json"
    for path in [active_profile_path, runtime_manifest_path, inventory_path, validation_report_path]:
        if not path.exists():
            raise SystemExit(f"probe missing file: {path}")

    godot_bin = shutil.which("godot4") or shutil.which("godot")
    if godot_bin is None:
        raise SystemExit("godot/godot4 command not found")

    report_json_path = generated_dir / "formal_sequence_probe_report.json"
    with tempfile.TemporaryDirectory(prefix="aigc_battle_probe_") as temp_dir:
        temp_script_path = Path(temp_dir) / "formal_sequence_probe.gd"
        temp_script_path.write_text(build_godot_probe_script(profile_id, report_json_path), encoding="utf-8")
        command = [godot_bin, "--headless", "--path", str(ROOT), "--script", str(temp_script_path)]
        env = os.environ.copy()
        env.update({"HOME": "/private/tmp"})
        subprocess.run(command, check=True, cwd=ROOT, env=env)

    report = read_json(report_json_path)
    write_markdown_report(generated_dir / "formal_sequence_probe_report.md", report)
    print("formal sequence probe complete")
    return 0 if report.get("all_formal_battles_use_generated_loadout", False) else 1


def build_godot_probe_script(profile_id: str, report_json_path: Path) -> str:
    return f'''extends SceneTree

const Loader = preload("res://scripts/aigc_battle/aigc_battle_runtime_manifest_loader.gd")
const INVENTORY_PATH = "res://data/aigc_battle/generated/{profile_id}/formal_sequence_inventory.generated.json"
const REPORT_PATH = "{report_json_path.as_posix()}"

func _init() -> void:
	var report := {{
		"godot_active_manifest_loaded": false,
		"formal_sequence_mapping_loaded": false,
		"formal_encounter_total_count": 0,
		"generated_loadout_count": 0,
		"fallback_loadout_count": 0,
		"all_formal_battles_use_generated_loadout": false,
		"generated_decks_applied": false,
		"generated_cards_available": false,
		"generated_rewards_available": false,
		"player_can_progress_through_generated_sequence": false
	}}
	if not Loader.load_active_manifest():
		report["error"] = Loader.get_last_error()
		_write_report(report)
		quit(1)
		return
	report["godot_active_manifest_loaded"] = Loader.is_loaded()
	var summary: Dictionary = Loader.get_manifest_summary()
	var inventory: Array = _read_inventory()
	report["formal_encounter_total_count"] = inventory.size()
	report["formal_sequence_mapping_loaded"] = int(summary.get("formal_sequence_mapping_count", 0)) >= inventory.size()
	var all_cards_ready := true
	var all_rewards_ready := true
	var all_decks_ready := true
	for item_variant in inventory:
		var item: Dictionary = item_variant
		var encounter_id := str(item.get("formal_encounter_id", ""))
		var battle_id := str(item.get("formal_battle_id", ""))
		if not Loader.has_generated_loadout(encounter_id, battle_id):
			report["fallback_loadout_count"] = int(report.get("fallback_loadout_count", 0)) + 1
			all_cards_ready = false
			all_rewards_ready = false
			all_decks_ready = false
			continue
		var loadout: Dictionary = Loader.get_generated_loadout(encounter_id, battle_id)
		report["generated_loadout_count"] = int(report.get("generated_loadout_count", 0)) + 1
		if str(loadout.get("loadout_source", "")) != "generated_manifest":
			report["fallback_loadout_count"] = int(report.get("fallback_loadout_count", 0)) + 1
		if str(loadout.get("generated_deck_id", "")).is_empty():
			all_decks_ready = false
		var cards: Array = loadout.get("cards", [])
		if cards.is_empty():
			all_cards_ready = false
		var reward: Dictionary = loadout.get("reward", {{}})
		if reward.is_empty() or str(loadout.get("reward_plan_id", "")).is_empty():
			all_rewards_ready = false
	report["generated_decks_applied"] = all_decks_ready
	report["generated_cards_available"] = all_cards_ready
	report["generated_rewards_available"] = all_rewards_ready
	report["all_formal_battles_use_generated_loadout"] = int(report.get("generated_loadout_count", 0)) == inventory.size() and int(report.get("fallback_loadout_count", 0)) == 0
	report["player_can_progress_through_generated_sequence"] = bool(report.get("all_formal_battles_use_generated_loadout", false)) and all_decks_ready and all_cards_ready and all_rewards_ready
	_write_report(report)
	quit(0 if bool(report.get("all_formal_battles_use_generated_loadout", false)) else 1)

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


def write_markdown_report(path: Path, report: dict[str, Any]) -> None:
    lines = [
        "# AIGC Battle v1 Formal Sequence Probe",
        "",
        f"- godot_active_manifest_loaded: {str(report['godot_active_manifest_loaded']).lower()}",
        f"- formal_sequence_mapping_loaded: {str(report['formal_sequence_mapping_loaded']).lower()}",
        f"- formal_encounter_total_count: {report['formal_encounter_total_count']}",
        f"- generated_loadout_count: {report['generated_loadout_count']}",
        f"- fallback_loadout_count: {report['fallback_loadout_count']}",
        f"- all_formal_battles_use_generated_loadout: {str(report['all_formal_battles_use_generated_loadout']).lower()}",
        f"- generated_decks_applied: {str(report['generated_decks_applied']).lower()}",
        f"- generated_cards_available: {str(report['generated_cards_available']).lower()}",
        f"- generated_rewards_available: {str(report['generated_rewards_available']).lower()}",
        f"- player_can_progress_through_generated_sequence: {str(report['player_can_progress_through_generated_sequence']).lower()}",
        "",
        "说明：本轮 probe 验证 active_manifest 与 formal sequence mapping 的逐 encounter 命中，不执行完整自动通关。",
    ]
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def read_active_profile_id() -> str:
    active_profile = read_json(RUNTIME_DIR / "active_profile.json")
    return str(active_profile["active_mechanic_profile_id"])


def read_json(path: Path) -> Any:
    return json.loads(path.read_text(encoding="utf-8"))


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
