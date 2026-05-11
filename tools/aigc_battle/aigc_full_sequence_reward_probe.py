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
        print("usage: python tools/aigc_battle/aigc_full_sequence_reward_probe.py [profile_id]", file=sys.stderr)
        return 1
    profile_id = argv[1] if len(argv) == 2 else read_active_profile_id()
    generated_dir = GENERATED_DIR / profile_id
    for rel in [
        ROOT / "data/aigc_battle/runtime/active_profile.json",
        generated_dir / "runtime_manifest.json",
        generated_dir / "formal_sequence_inventory.generated.json",
    ]:
        if not rel.exists():
            raise SystemExit(f"probe missing file: {rel}")
    godot_bin = shutil.which("godot4") or shutil.which("godot")
    if godot_bin is None:
        raise SystemExit("godot/godot4 command not found")

    report_json_path = generated_dir / "full_sequence_reward_probe_report.json"
    with tempfile.TemporaryDirectory(prefix="aigc_reward_probe_") as temp_dir:
        temp_script_path = Path(temp_dir) / "full_sequence_reward_probe.gd"
        temp_script_path.write_text(build_godot_probe_script(profile_id, report_json_path), encoding="utf-8")
        command = [godot_bin, "--headless", "--path", str(ROOT), "--script", str(temp_script_path)]
        env = os.environ.copy()
        env.update({"HOME": "/private/tmp"})
        subprocess.run(command, check=True, cwd=ROOT, env=env)

    report = read_json(report_json_path)
    write_markdown_report(generated_dir / "full_sequence_reward_probe_report.md", report)
    ok = (
        report.get("all_generated_slots_have_reward", False)
        and report.get("reward_source_is_manifest", False)
        and report.get("reward_visible_after_each_win", False)
        and report.get("reward_claimed", False)
        and report.get("formal_progression_continues", False)
        and report.get("full_sequence_loop_closed", False)
        and int(report.get("fallback_loadout_count", 0)) == 0
    )
    print("full sequence reward probe complete")
    return 0 if ok else 1


def build_godot_probe_script(profile_id: str, report_json_path: Path) -> str:
    return f'''extends SceneTree

const Loader = preload("res://scripts/aigc_battle/aigc_battle_runtime_manifest_loader.gd")
const StoryReturnScript = preload("res://scripts/battle_controller_visual_story_return.gd")
const INVENTORY_PATH = "res://data/aigc_battle/generated/{profile_id}/formal_sequence_inventory.generated.json"
const REPORT_PATH = "{report_json_path.as_posix()}"

func _init() -> void:
	var report := {{
		"active_profile_loaded": false,
		"runtime_manifest_loaded": false,
		"formal_encounter_total_count": 0,
		"all_generated_slots_have_reward": false,
		"generated_reward_count": 0,
		"missing_reward_count": 0,
		"reward_source_is_manifest": false,
		"reward_visible_after_each_win": false,
		"reward_claimed": false,
		"formal_progression_continues": false,
		"fallback_loadout_count": 0,
		"full_sequence_loop_closed": false
	}}
	if not Loader.load_active_manifest():
		report["error"] = Loader.get_last_error()
		_write_report(report)
		quit(1)
		return
	report["active_profile_loaded"] = true
	report["runtime_manifest_loaded"] = Loader.is_loaded()
	var inventory: Array = _read_inventory()
	report["formal_encounter_total_count"] = inventory.size()
	var source_ok := true
	var visible_ok := true
	var claimed_ok := true
	var progression_ok := true
	for item_variant in inventory:
		var item: Dictionary = item_variant
		var encounter_id := str(item.get("formal_encounter_id", ""))
		var battle_id := str(item.get("formal_battle_id", ""))
		var loadout: Dictionary = Loader.get_generated_loadout(encounter_id, battle_id)
		if loadout.is_empty():
			report["fallback_loadout_count"] = int(report.get("fallback_loadout_count", 0)) + 1
			report["missing_reward_count"] = int(report.get("missing_reward_count", 0)) + 1
			source_ok = false
			visible_ok = false
			claimed_ok = false
			progression_ok = false
			continue
		var reward: Dictionary = Loader.get_generated_reward(encounter_id, battle_id)
		if reward.is_empty():
			report["missing_reward_count"] = int(report.get("missing_reward_count", 0)) + 1
			source_ok = false
			visible_ok = false
			claimed_ok = false
			progression_ok = false
			continue
		report["generated_reward_count"] = int(report.get("generated_reward_count", 0)) + 1
		if str(loadout.get("reward_source", "")) != "generated_manifest":
			source_ok = false
		var controller = StoryReturnScript.new()
		controller.battle_loadout = {{
			"loadout_source": "generated_manifest",
			"reward_plan_id": str(loadout.get("reward_plan_id", "")),
			"generated_reward": reward.duplicate(true)
		}}
		controller._mark_generated_reward_visible(true)
		var text: String = controller._battle_result_body_text(true, "")
		if not controller.last_generated_reward_visible or text.find("本场奖励：") < 0:
			visible_ok = false
		controller._claim_generated_manifest_reward("win")
		if not controller.last_generated_reward_claimed:
			claimed_ok = false
		if not controller.last_formal_progression_continues:
			progression_ok = false
	report["all_generated_slots_have_reward"] = int(report.get("generated_reward_count", 0)) == inventory.size() and int(report.get("missing_reward_count", 0)) == 0
	report["reward_source_is_manifest"] = source_ok
	report["reward_visible_after_each_win"] = visible_ok
	report["reward_claimed"] = claimed_ok
	report["formal_progression_continues"] = progression_ok
	report["full_sequence_loop_closed"] = bool(report.get("all_generated_slots_have_reward", false)) and source_ok and visible_ok and claimed_ok and progression_ok and int(report.get("fallback_loadout_count", 0)) == 0
	_write_report(report)
	quit(0 if bool(report.get("full_sequence_loop_closed", false)) else 1)

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
        "# AIGC Battle v2 Reward Probe",
        "",
        f"- formal_encounter_total_count: {report['formal_encounter_total_count']}",
        f"- generated_reward_count: {report['generated_reward_count']}",
        f"- missing_reward_count: {report['missing_reward_count']}",
        f"- all_generated_slots_have_reward: {str(report['all_generated_slots_have_reward']).lower()}",
        f"- reward_source_is_manifest: {str(report['reward_source_is_manifest']).lower()}",
        f"- reward_visible_after_each_win: {str(report['reward_visible_after_each_win']).lower()}",
        f"- reward_claimed: {str(report['reward_claimed']).lower()}",
        f"- formal_progression_continues: {str(report['formal_progression_continues']).lower()}",
        f"- fallback_loadout_count: {report['fallback_loadout_count']}",
        f"- full_sequence_loop_closed: {str(report['full_sequence_loop_closed']).lower()}",
        "",
        "说明：本轮 probe 通过 manifest loader 与结算桥辅助方法验证奖励可见、领取与继续逻辑，不执行完整自动通关。",
    ]
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def read_active_profile_id() -> str:
    active_profile = read_json(RUNTIME_DIR / "active_profile.json")
    return str(active_profile["active_mechanic_profile_id"])


def read_json(path: Path) -> Any:
    return json.loads(path.read_text(encoding="utf-8"))


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
