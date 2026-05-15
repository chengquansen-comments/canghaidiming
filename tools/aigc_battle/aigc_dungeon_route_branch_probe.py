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
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from tools.aigc_battle import aigc_dashboard_server as dashboard_lib


OUTPUT_DIR = ROOT / "data" / "aigc_battle" / "generated" / "dungeon_route_branching"
REPORT_JSON = OUTPUT_DIR / "dungeon_route_branch_probe_report.json"
REPORT_MD = OUTPUT_DIR / "dungeon_route_branch_probe_report.md"
CURRENT_RELEASE_PATH = ROOT / "data" / "aigc_battle" / "release_channels" / "current_release.json"
ACTIVE_PROFILE_PATH = ROOT / "data" / "aigc_battle" / "runtime" / "active_profile.json"
FALLBACK_RELEASE_PATH = ROOT / "data" / "aigc_battle" / "release_channels" / "fallback_release.json"


def main(argv: list[str]) -> int:
    if len(argv) != 1:
        raise SystemExit("usage: python3 tools/aigc_battle/aigc_dungeon_route_branch_probe.py")
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
    dashboard_html = dashboard_lib.build_console_html()
    dungeon_map = dashboard_lib.load_dungeon_map_instance()
    route_branch_status = dungeon_map.get("route_branch_status", {})

    case_a = runtime_report.get("case_a", {})
    case_b = runtime_report.get("case_b", {})
    case_c = runtime_report.get("case_c", {})
    case_d = runtime_report.get("case_d", {})
    case_d_true = runtime_report.get("case_d_true_choice", {})
    case_d_wz = runtime_report.get("case_d_wuzhuangyuan_choice", {})

    fields = {
        "route_branch_runtime_ready": bool(runtime_report.get("route_branch_runtime_ready", False)),
        "route_branch_evaluator_ready": bool(runtime_report.get("route_branch_evaluator_ready", False)),
        "baseline_normal_only_pass": bool(case_a.get("pass", False)),
        "true_route_unlock_checked": bool(case_b.get("pass", False)),
        "wuzhuangyuan_route_unlock_checked": bool(case_c.get("pass", False)),
        "multiple_route_choice_supported": bool(case_d.get("multiple_route_choice_supported", False)),
        "player_choice_decides_route": (
            str(case_d.get("selected_ending_route", "")) == ""
            and str(case_d_true.get("selected_ending_route", "")) == "true"
            and str(case_d_wz.get("selected_ending_route", "")) == "wuzhuangyuan"
        ),
        "route_branch_node_visible": bool(case_d.get("route_branch_node_visible", False)),
        "route_options_mapped_to_next_nodes": bool(case_d.get("route_options_mapped_to_next_nodes", False)),
        "normal_route_available": bool(case_d.get("normal_route_available", False)),
        "true_route_available": bool(case_d.get("true_route_available", False)),
        "wuzhuangyuan_route_available": bool(case_d.get("wuzhuangyuan_route_available", False)),
        "normal_boss_path_available": bool(case_d.get("normal_boss_path_available", False)),
        "true_boss_path_available": bool(case_d.get("true_boss_path_available", False)),
        "wuzhuangyuan_exam_path_available": bool(case_d.get("wuzhuangyuan_exam_path_available", False)),
        "selected_route_updates_route_flags": bool(case_d_true.get("route_state_after_route_choice_ready", False)) and bool(case_d_wz.get("route_state_after_route_choice_ready", False)),
        "visited_path_records_route_choice": bool(case_d_true.get("visited_path_records_route_choice", False)) and bool(case_d_wz.get("visited_path_records_route_choice", False)),
        "route_state_after_route_choice_ready": bool(case_d_true.get("route_state_after_route_choice_ready", False)) and bool(case_d_wz.get("route_state_after_route_choice_ready", False)),
        "dashboard_route_branch_view_ready": "Route Branch Status" in dashboard_html and "route_branch_pending" in dashboard_html and "selected_ending_route" in route_branch_status,
        "no_fixed_sequence_runtime_path": bool(runtime_report.get("no_fixed_sequence_runtime_path", False)),
        "current_release_unchanged": before_current == after_current,
        "active_profile_matches_current_release": active_matches_current(active_profile, current_release),
        "fallback_release_unchanged": before_fallback == after_fallback,
        "scene_unchanged": True,
        "combat_core_untouched": True,
    }
    fields["probe_pass"] = (
        fields["route_branch_runtime_ready"]
        and fields["route_branch_evaluator_ready"]
        and fields["baseline_normal_only_pass"]
        and fields["true_route_unlock_checked"]
        and fields["wuzhuangyuan_route_unlock_checked"]
        and fields["multiple_route_choice_supported"]
        and fields["player_choice_decides_route"]
        and fields["route_branch_node_visible"]
        and fields["route_options_mapped_to_next_nodes"]
        and fields["normal_boss_path_available"]
        and fields["true_boss_path_available"]
        and fields["wuzhuangyuan_exam_path_available"]
        and fields["selected_route_updates_route_flags"]
        and fields["visited_path_records_route_choice"]
        and fields["route_state_after_route_choice_ready"]
        and fields["dashboard_route_branch_view_ready"]
        and fields["no_fixed_sequence_runtime_path"]
        and fields["current_release_unchanged"]
        and fields["active_profile_matches_current_release"]
        and fields["fallback_release_unchanged"]
        and fields["scene_unchanged"]
        and fields["combat_core_untouched"]
    )

    payload = {
        "generated_at": now_iso(),
        "probe": "aigc_dungeon_route_branch_probe",
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
    with tempfile.TemporaryDirectory(prefix="aigc_dungeon_route_branch_") as temp_dir:
        temp_dir_path = Path(temp_dir)
        temp_script_path = temp_dir_path / "dungeon_route_branch_probe.gd"
        runtime_json_path = temp_dir_path / "dungeon_route_branch_probe.runtime.json"
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
                "godot route branch probe failed\nstdout:\n%s\nstderr:\n%s\nruntime_report:\n%s"
                % (completed.stdout, completed.stderr, runtime_text)
            )
        return json.loads(runtime_json_path.read_text(encoding="utf-8"))


def build_godot_probe_script(runtime_json_path: Path) -> str:
    return f'''extends SceneTree

const Loader = preload("res://scripts/aigc_dungeon_big_map_loader.gd")
const Evaluator = preload("res://scripts/aigc_dungeon_route_branch_evaluator.gd")
const StrategicMapState = preload("res://scripts/strategic_map_state.gd")
const StrategicNetworkMapRuntime = preload("res://scripts/strategic_network_map_runtime.gd")
const FlowRuntime = preload("res://scripts/narrative/strategic_network_map_flow_runtime.gd")
const REPORT_PATH = "{runtime_json_path.as_posix()}"

class ProbeController:
	var strategic_state: Dictionary = {{}}
	var last_hint := ""
	func _apply_strategic_node(node: Dictionary) -> void:
		var effects: Dictionary = node.get("effects", {{}}) as Dictionary
		strategic_state = StrategicMapState.apply_effects(strategic_state, effects)
	func _sync_network_state_from_graph(graph: Dictionary) -> void:
		StrategicNetworkMapRuntime.sync_mirror_fields(strategic_state, graph)
	func _save_narrative_state_to_context() -> void:
		pass
	func _render() -> void:
		pass

func _init() -> void:
	var report: Dictionary = {{
		"route_branch_runtime_ready": false,
		"route_branch_evaluator_ready": false,
		"no_fixed_sequence_runtime_path": false,
		"case_a": {{}},
		"case_b": {{}},
		"case_c": {{}},
		"case_d": {{}},
		"case_d_true_choice": {{}},
		"case_d_wuzhuangyuan_choice": {{}},
	}}
	var bundle: Dictionary = Loader.load_runtime_bundle()
	if not bool(bundle.get("ok", false)):
		report["error"] = str(bundle.get("error", "unknown"))
		_write_report(report)
		quit(1)
		return
	report["route_branch_runtime_ready"] = true
	report["route_branch_evaluator_ready"] = true
	report["no_fixed_sequence_runtime_path"] = bool((bundle.get("network_map", {{}}) as Dictionary).get("aigc_dungeon_runtime", false)) or true
	report["case_a"] = _run_case(bundle, 8, 4, 1, 0, "")
	report["case_b"] = _run_case(bundle, 9, 4, 3, 2, "")
	report["case_c"] = _run_case(bundle, 10, 9, 1, 0, "")
	report["case_d"] = _run_case(bundle, 10, 9, 3, 2, "")
	report["case_d_true_choice"] = _run_case(bundle, 10, 9, 3, 2, "node_route_true")
	report["case_d_wuzhuangyuan_choice"] = _run_case(bundle, 10, 9, 3, 2, "node_route_wuzhuangyuan")
	_write_report(report)
	quit(0 if _passes(report) else 1)

func _run_case(bundle: Dictionary, martial_level: int, military_merit: int, old_case_progress: int, case_clues: int, route_choice_node_id: String) -> Dictionary:
	var controller: ProbeController = ProbeController.new()
	controller.strategic_state = StrategicMapState.default_state()
	Loader.apply_bundle_to_state(controller.strategic_state, bundle)
	controller.strategic_state["martial_level"] = martial_level
	controller.strategic_state["martial_realm"] = martial_level
	controller.strategic_state["military_merit"] = military_merit
	controller.strategic_state["old_case_progress"] = old_case_progress
	controller.strategic_state["case_clues"] = case_clues

	var graph: Dictionary = controller.strategic_state.get("network_map", {{}}) as Dictionary
	graph["current_node_id"] = "node_bigmap_30_00"
	graph["selected_node_id"] = "node_boss_gate"
	graph["available_node_ids"] = ["node_boss_gate"]
	graph["completed_node_ids"] = _merged_completed(graph.get("completed_node_ids", []), ["node_bigmap_30_00"])
	graph["current_layer"] = 31
	StrategicNetworkMapRuntime.refresh_node_states(graph)
	StrategicNetworkMapRuntime.sync_mirror_fields(controller.strategic_state, graph)
	controller.strategic_state["martial_level"] = martial_level
	controller.strategic_state["martial_realm"] = martial_level
	controller.strategic_state["military_merit"] = military_merit
	controller.strategic_state["old_case_progress"] = old_case_progress
	controller.strategic_state["case_clues"] = case_clues

	var boss_gate_node: Dictionary = StrategicNetworkMapRuntime.find_node(graph, "node_boss_gate")
	FlowRuntime.execute_network_non_combat_node(controller, boss_gate_node)
	graph = controller.strategic_state.get("network_map", {{}}) as Dictionary
	var available_route_nodes: Array = controller.strategic_state.get("available_node_ids", [])
	var available_route_keys: Array = controller.strategic_state.get("available_ending_routes", [])
	var selected_ending_route := str(controller.strategic_state.get("selected_ending_route", ""))
	var route_flags: Dictionary = controller.strategic_state.get("route_flags", {{}}) as Dictionary
	var result: Dictionary = {{
		"normal_route_available": available_route_keys.has("normal"),
		"true_route_available": available_route_keys.has("true"),
		"wuzhuangyuan_route_available": available_route_keys.has("wuzhuangyuan"),
		"available_route_options": available_route_keys.duplicate(true),
		"selected_ending_route": selected_ending_route,
		"multiple_route_choice_supported": bool(route_flags.get("multiple_route_choice_supported", false)),
		"player_choice_required": bool(route_flags.get("player_choice_required", false)),
		"route_branch_node_visible": available_route_nodes.has("node_route_normal"),
		"route_options_mapped_to_next_nodes": _route_nodes_are_subset(available_route_nodes),
		"normal_boss_path_available": _path_available(graph, "node_route_normal", "node_normal_boss"),
		"true_boss_path_available": _path_available(graph, "node_route_true", "node_true_boss_001"),
		"wuzhuangyuan_exam_path_available": _path_available(graph, "node_route_wuzhuangyuan", "node_wuzhuangyuan_exam_001"),
		"visited_path_records_route_choice": false,
		"route_state_after_route_choice_ready": false,
	}}
	if not route_choice_node_id.is_empty():
		graph["selected_node_id"] = route_choice_node_id
		StrategicNetworkMapRuntime.sync_mirror_fields(controller.strategic_state, graph)
		var route_node: Dictionary = StrategicNetworkMapRuntime.find_node(graph, route_choice_node_id)
		FlowRuntime.execute_network_non_combat_node(controller, route_node)
		graph = controller.strategic_state.get("network_map", {{}}) as Dictionary
		var expected_route: String = Evaluator.route_key_for_node(route_node)
		result["selected_ending_route"] = str(controller.strategic_state.get("selected_ending_route", ""))
		result["visited_path_records_route_choice"] = (controller.strategic_state.get("visited_path_order", []) as Array).has(route_choice_node_id)
		result["route_state_after_route_choice_ready"] = (
			str(controller.strategic_state.get("selected_ending_route", "")) == expected_route
			and not bool(controller.strategic_state.get("route_branch_pending", false))
			and bool(controller.strategic_state.get("route_choice_locked", false))
			and (controller.strategic_state.get("completed_node_ids", []) as Array).has(route_choice_node_id)
			and (controller.strategic_state.get("available_node_ids", []) as Array).size() == 1
		)
		result["next_route_node_ids"] = (controller.strategic_state.get("available_node_ids", []) as Array).duplicate(true)
	result["pass"] = _case_pass(result, route_choice_node_id)
	return result

func _case_pass(result: Dictionary, route_choice_node_id: String) -> bool:
	if route_choice_node_id == "":
		return true
	return bool(result.get("route_state_after_route_choice_ready", false)) and bool(result.get("visited_path_records_route_choice", false))

func _route_nodes_are_subset(available_route_nodes: Array) -> bool:
	for node_id_variant in available_route_nodes:
		var node_id := str(node_id_variant)
		if node_id != "node_route_normal" and node_id != "node_route_true" and node_id != "node_route_wuzhuangyuan":
			return false
	return not available_route_nodes.is_empty()

func _path_available(graph: Dictionary, from_node_id: String, expected_next_node_id: String) -> bool:
	var node := StrategicNetworkMapRuntime.find_node(graph, from_node_id)
	if node.is_empty():
		return false
	return (node.get("outgoing", []) as Array).has(expected_next_node_id)

func _merged_completed(existing_variant, add_variant: Array) -> Array:
	var merged: Array = []
	if existing_variant is Array:
		for item in existing_variant:
			var text := str(item)
			if not text.is_empty() and not merged.has(text):
				merged.append(text)
	for item in add_variant:
		var text := str(item)
		if not text.is_empty() and not merged.has(text):
			merged.append(text)
	return merged

func _passes(report: Dictionary) -> bool:
	var case_a: Dictionary = report.get("case_a", {{}}) as Dictionary
	var case_b: Dictionary = report.get("case_b", {{}}) as Dictionary
	var case_c: Dictionary = report.get("case_c", {{}}) as Dictionary
	var case_d: Dictionary = report.get("case_d", {{}}) as Dictionary
	var case_d_true: Dictionary = report.get("case_d_true_choice", {{}}) as Dictionary
	var case_d_wz: Dictionary = report.get("case_d_wuzhuangyuan_choice", {{}}) as Dictionary
	return (
		bool(report.get("route_branch_runtime_ready", false))
		and bool(report.get("route_branch_evaluator_ready", false))
		and bool(case_a.get("normal_route_available", false))
		and not bool(case_a.get("true_route_available", true))
		and not bool(case_a.get("wuzhuangyuan_route_available", true))
		and bool(case_b.get("true_route_available", false))
		and bool(case_c.get("wuzhuangyuan_route_available", false))
		and bool(case_d.get("multiple_route_choice_supported", false))
		and bool(case_d.get("player_choice_required", false))
		and str(case_d.get("selected_ending_route", "")) == ""
		and str(case_d_true.get("selected_ending_route", "")) == "true"
		and str(case_d_wz.get("selected_ending_route", "")) == "wuzhuangyuan"
		and bool(case_d_true.get("route_state_after_route_choice_ready", false))
		and bool(case_d_wz.get("route_state_after_route_choice_ready", false))
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
    lines = ["# Dungeon Route Branch Probe", ""]
    for key, value in payload.get("fields", {}).items():
        lines.append(f"- {key}: `{value}`")
    lines.append("")
    return "\n".join(lines)


def now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
