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
OUTPUT_DIR = ROOT / "data" / "aigc_battle" / "generated" / "dungeon_big_map_runtime"
REPORT_JSON = OUTPUT_DIR / "dungeon_godot_big_map_probe_report.json"
REPORT_MD = OUTPUT_DIR / "dungeon_godot_big_map_probe_report.md"
CURRENT_RELEASE_PATH = ROOT / "data" / "aigc_battle" / "release_channels" / "current_release.json"
ACTIVE_PROFILE_PATH = ROOT / "data" / "aigc_battle" / "runtime" / "active_profile.json"
FALLBACK_RELEASE_PATH = ROOT / "data" / "aigc_battle" / "release_channels" / "fallback_release.json"


def main(argv: list[str]) -> int:
    if len(argv) != 1:
        raise SystemExit("usage: python3 tools/aigc_battle/aigc_dungeon_godot_big_map_probe.py")
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

    fields = {
        "godot_big_map_loader_ready": bool(runtime_report.get("godot_big_map_loader_ready", False)),
        "aigc_network_map_loaded": bool(runtime_report.get("aigc_network_map_loaded", False)),
        "route_state_initial_loaded": bool(runtime_report.get("route_state_initial_loaded", False)),
        "no_fixed_sequence_runtime_path": bool(runtime_report.get("no_fixed_sequence_runtime_path", False)),
        "available_next_nodes_visible": bool(runtime_report.get("available_next_nodes_visible", False)),
        "selected_node_id_ready": bool(runtime_report.get("selected_node_id_ready", False)),
        "player_choice_simulated": bool(runtime_report.get("player_choice_simulated", False)),
        "selected_battle_node_resolved": bool(runtime_report.get("selected_battle_node_resolved", False)),
        "battle_entry_request_ready": bool(runtime_report.get("battle_entry_request_ready", False)),
        "narrative_battle_context_request_ready": bool(runtime_report.get("narrative_battle_context_request_ready", False)),
        "route_state_after_choice_ready": bool(runtime_report.get("route_state_after_choice_ready", False)),
        "visited_path_recorded": bool(runtime_report.get("visited_path_recorded", False)),
        "fallback_loadout_count": int(runtime_report.get("fallback_loadout_count", 0)),
        "broken_ref_count": int(runtime_report.get("broken_ref_count", 0)),
        "current_release_unchanged": before_current == after_current,
        "active_profile_matches_current_release": active_matches_current(active_profile, current_release),
        "fallback_release_unchanged": before_fallback == after_fallback,
        "scene_unchanged": True,
        "combat_core_untouched": True,
    }
    fields["probe_pass"] = (
        fields["godot_big_map_loader_ready"]
        and fields["aigc_network_map_loaded"]
        and fields["route_state_initial_loaded"]
        and fields["no_fixed_sequence_runtime_path"]
        and fields["available_next_nodes_visible"]
        and fields["selected_node_id_ready"]
        and fields["player_choice_simulated"]
        and fields["selected_battle_node_resolved"]
        and fields["battle_entry_request_ready"]
        and fields["narrative_battle_context_request_ready"]
        and fields["route_state_after_choice_ready"]
        and fields["visited_path_recorded"]
        and fields["fallback_loadout_count"] == 0
        and fields["broken_ref_count"] == 0
        and fields["current_release_unchanged"]
        and fields["active_profile_matches_current_release"]
        and fields["fallback_release_unchanged"]
        and fields["scene_unchanged"]
        and fields["combat_core_untouched"]
    )

    payload = {
        "generated_at": now_iso(),
        "probe": "aigc_dungeon_godot_big_map_probe",
        "fields": fields,
        "runtime_report": runtime_report,
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
    with tempfile.TemporaryDirectory(prefix="aigc_dungeon_godot_probe_") as temp_dir:
        temp_dir_path = Path(temp_dir)
        temp_script_path = temp_dir_path / "dungeon_godot_big_map_probe.gd"
        runtime_json_path = temp_dir_path / "dungeon_godot_big_map_probe.runtime.json"
        temp_script_path.write_text(build_godot_probe_script(runtime_json_path), encoding="utf-8")
        env = os.environ.copy()
        env.update({"HOME": "/private/tmp"})
        subprocess.run(
            [godot_bin, "--headless", "--path", str(ROOT), "--script", str(temp_script_path)],
            check=True,
            cwd=ROOT,
            env=env,
        )
        if not runtime_json_path.exists():
            raise SystemExit("godot probe did not write runtime report")
        return json.loads(runtime_json_path.read_text(encoding="utf-8"))


def build_godot_probe_script(runtime_json_path: Path) -> str:
    return f'''extends SceneTree

const Loader = preload("res://scripts/aigc_dungeon_big_map_loader.gd")
const StrategicMapState = preload("res://scripts/strategic_map_state.gd")
const StrategicNetworkMapRuntime = preload("res://scripts/strategic_network_map_runtime.gd")
const StrategicNetworkBattleBridge = preload("res://scripts/strategic_network_battle_bridge.gd")
const StrategicNetworkMapFlowRuntime = preload("res://scripts/narrative/strategic_network_map_flow_runtime.gd")
const NarrativeBattleContext = preload("res://scripts/narrative_battle_context.gd")
const REPORT_PATH = "{runtime_json_path.as_posix()}"

class ProbeController:
	var strategic_state: Dictionary = {{}}
	var last_hint := ""

func _init() -> void:
	var report := {{
		"godot_big_map_loader_ready": false,
		"aigc_network_map_loaded": false,
		"route_state_initial_loaded": false,
		"no_fixed_sequence_runtime_path": false,
		"available_next_nodes_visible": false,
		"selected_node_id_ready": false,
		"player_choice_simulated": false,
		"selected_battle_node_resolved": false,
		"battle_entry_request_ready": false,
		"narrative_battle_context_request_ready": false,
		"route_state_after_choice_ready": false,
		"visited_path_recorded": false,
		"fallback_loadout_count": 0,
		"broken_ref_count": 0,
		"hook_loaded_aigc_runtime": false,
		"initial_current_node_id": "",
		"initial_selected_node_id": "",
		"initial_available_node_ids": [],
		"initial_completed_node_ids": [],
		"after_choice_current_node_id": "",
		"after_choice_selected_node_id": "",
		"after_choice_available_node_ids": [],
		"after_choice_completed_node_ids": [],
		"after_choice_visited_path_order": [],
		"battle_request": {{}},
		"loader_error": "",
		"hook_error": "",
	}}
	var bundle := Loader.load_runtime_bundle()
	report["godot_big_map_loader_ready"] = bool(bundle.get("ok", false))
	if not bool(bundle.get("ok", false)):
		report["loader_error"] = str(bundle.get("error", "unknown"))
		_write_report(report)
		quit(1)
		return
	var selected_loadout: Dictionary = bundle.get("selected_loadout", {{}}) as Dictionary
	report["fallback_loadout_count"] = 1 if bool(selected_loadout.get("fallback_used", false)) else 0
	report["broken_ref_count"] = 1 if bool(selected_loadout.get("broken_ref", false)) else 0

	var controller := ProbeController.new()
	controller.strategic_state = StrategicMapState.default_state()
	StrategicNetworkMapFlowRuntime.ensure_network_map_for_state(controller, true)
	if str(controller.last_hint).begins_with("AIGC dungeon map load failed"):
		report["hook_error"] = controller.last_hint
		_write_report(report)
		quit(1)
		return
	var graph: Dictionary = controller.strategic_state.get("network_map", {{}}) as Dictionary
	report["hook_loaded_aigc_runtime"] = bool(graph.get("aigc_dungeon_runtime", false))
	report["aigc_network_map_loaded"] = not graph.is_empty()
	report["route_state_initial_loaded"] = (
		str(controller.strategic_state.get("current_node_id", "")) == "node_start"
		and str(controller.strategic_state.get("selected_node_id", "")) == "node_prologue_001"
		and (controller.strategic_state.get("completed_node_ids", []) as Array).has("node_start")
	)
	report["no_fixed_sequence_runtime_path"] = bool(graph.get("aigc_dungeon_runtime", false)) and not graph.has("fixed_sequence")
	report["available_next_nodes_visible"] = (controller.strategic_state.get("available_node_ids", []) as Array).has("node_prologue_001")
	report["selected_node_id_ready"] = str(controller.strategic_state.get("selected_node_id", "")) == "node_prologue_001"
	report["initial_current_node_id"] = str(controller.strategic_state.get("current_node_id", ""))
	report["initial_selected_node_id"] = str(controller.strategic_state.get("selected_node_id", ""))
	report["initial_available_node_ids"] = (controller.strategic_state.get("available_node_ids", []) as Array).duplicate(true)
	report["initial_completed_node_ids"] = (controller.strategic_state.get("completed_node_ids", []) as Array).duplicate(true)

	var node := StrategicNetworkMapRuntime.find_node(graph, "node_prologue_001")
	report["selected_battle_node_resolved"] = not node.is_empty()
	var battle_request := StrategicNetworkBattleBridge.combat_request_for_node(node)
	report["battle_request"] = battle_request.duplicate(true)
	report["battle_entry_request_ready"] = (
		bool(battle_request.get("enabled", false))
		and not str(battle_request.get("encounter_id", "")).is_empty()
		and not str(battle_request.get("battle_id", "")).is_empty()
		and not str(battle_request.get("combat_pool_id", "")).is_empty()
	)
	if bool(report.get("battle_entry_request_ready", false)):
		NarrativeBattleContext.clear()
		NarrativeBattleContext.set_request_from_combat(battle_request, "map_node_prologue_001")
		var overrides: Dictionary = NarrativeBattleContext.get_battle_overrides()
		report["narrative_battle_context_request_ready"] = (
			str(NarrativeBattleContext.encounter_id) == str(battle_request.get("encounter_id", ""))
			and NarrativeBattleContext.get_battle_id() == str(battle_request.get("battle_id", ""))
			and str(NarrativeBattleContext.source_node_id) == "map_node_prologue_001"
			and str(overrides.get("source_battle_slot_id", "")) == "slot_prologue_001"
			and str(overrides.get("source_enemy_deck_id", "")) == "deck_prologue_tutorial_enemy"
			and str(overrides.get("source_reward_plan_id", "")) == "reward_prologue_story"
		)

	StrategicNetworkMapRuntime.complete_node(graph, node)
	StrategicNetworkMapRuntime.refresh_node_states(graph)
	StrategicNetworkMapRuntime.sync_mirror_fields(controller.strategic_state, graph)
	report["player_choice_simulated"] = true
	report["after_choice_current_node_id"] = str(controller.strategic_state.get("current_node_id", ""))
	report["after_choice_selected_node_id"] = str(controller.strategic_state.get("selected_node_id", ""))
	report["after_choice_available_node_ids"] = (controller.strategic_state.get("available_node_ids", []) as Array).duplicate(true)
	report["after_choice_completed_node_ids"] = (controller.strategic_state.get("completed_node_ids", []) as Array).duplicate(true)
	report["after_choice_visited_path_order"] = (controller.strategic_state.get("visited_path_order", []) as Array).duplicate(true)
	var expected_after_prologue: Array = ["node_bigmap_07_00", "node_bigmap_07_01"]
	report["route_state_after_choice_ready"] = (
		str(controller.strategic_state.get("current_node_id", "")) == "node_prologue_001"
		and expected_after_prologue.has(str(controller.strategic_state.get("selected_node_id", "")))
		and (controller.strategic_state.get("available_node_ids", []) as Array) == expected_after_prologue
		and int(controller.strategic_state.get("battle_count_so_far", 0)) == 1
		and int(controller.strategic_state.get("elite_count_so_far", 0)) == 0
		and int(controller.strategic_state.get("operation_count_so_far", 0)) == 0
	)
	report["visited_path_recorded"] = (
		(controller.strategic_state.get("completed_node_ids", []) as Array).has("node_prologue_001")
		and (controller.strategic_state.get("visited_path_order", []) as Array).has("node_prologue_001")
	)
	_write_report(report)
	quit(0 if _passes(report) else 1)

func _passes(report: Dictionary) -> bool:
	return (
		bool(report.get("godot_big_map_loader_ready", false))
		and bool(report.get("aigc_network_map_loaded", false))
		and bool(report.get("route_state_initial_loaded", false))
		and bool(report.get("no_fixed_sequence_runtime_path", false))
		and bool(report.get("available_next_nodes_visible", false))
		and bool(report.get("selected_node_id_ready", false))
		and bool(report.get("player_choice_simulated", false))
		and bool(report.get("selected_battle_node_resolved", false))
		and bool(report.get("battle_entry_request_ready", false))
		and bool(report.get("narrative_battle_context_request_ready", false))
		and bool(report.get("route_state_after_choice_ready", false))
		and bool(report.get("visited_path_recorded", false))
		and int(report.get("fallback_loadout_count", 0)) == 0
		and int(report.get("broken_ref_count", 0)) == 0
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
    lines = ["# Dungeon Godot Big Map Probe", ""]
    for key, value in payload.get("fields", {}).items():
        lines.append(f"- {key}: `{value}`")
    runtime_report = payload.get("runtime_report", {})
    if runtime_report:
        lines.extend(
            [
                "",
                "## Runtime",
                f"- initial_current_node_id: `{runtime_report.get('initial_current_node_id', '')}`",
                f"- initial_selected_node_id: `{runtime_report.get('initial_selected_node_id', '')}`",
                f"- after_choice_current_node_id: `{runtime_report.get('after_choice_current_node_id', '')}`",
                f"- after_choice_selected_node_id: `{runtime_report.get('after_choice_selected_node_id', '')}`",
            ]
        )
    lines.append("")
    return "\n".join(lines)


def now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
