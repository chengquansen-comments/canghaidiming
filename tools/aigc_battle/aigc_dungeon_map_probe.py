#!/usr/bin/env python3
from __future__ import annotations

import json
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[2]
MAP_DIR = ROOT / "data" / "aigc_battle" / "generated" / "dungeon_maps"
MAP_PATH = MAP_DIR / "map_seed_1001.json"
ROUTE_STATE_PATH = MAP_DIR / "route_state_seed_1001_initial.json"
COMPATIBLE_PATH = MAP_DIR / "big_map_compatible_seed_1001.json"
VALIDATION_PATH = MAP_DIR / "map_generation_report.json"
PROBE_JSON_PATH = MAP_DIR / "dungeon_map_probe_report.json"
PROBE_MD_PATH = MAP_DIR / "dungeon_map_probe_report.md"
CURRENT_RELEASE_PATH = ROOT / "data" / "aigc_battle" / "release_channels" / "current_release.json"
ACTIVE_PROFILE_PATH = ROOT / "data" / "aigc_battle" / "runtime" / "active_profile.json"


def _read_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def _write_json(path: Path, payload: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def _write_text(path: Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8")


def main() -> None:
    map_instance = _read_json(MAP_PATH)
    route_state = _read_json(ROUTE_STATE_PATH)
    compatible = _read_json(COMPATIBLE_PATH)
    validation = _read_json(VALIDATION_PATH)
    checks = validation.get("checks", {})

    current_release = _read_json(CURRENT_RELEASE_PATH)
    active_profile = _read_json(ACTIVE_PROFILE_PATH)

    fields = {
        "map_instance_ready": MAP_PATH.exists(),
        "route_state_initial_ready": ROUTE_STATE_PATH.exists(),
        "big_map_compatible_instance_ready": COMPATIBLE_PATH.exists(),
        "no_fixed_linear_sequence": bool(map_instance.get("no_fixed_linear_sequence", False)),
        "layer_count_ready": int(compatible.get("layer_count", 0)) > 0,
        "route_choice_available": bool(map_instance.get("route_choice_available", False)),
        "branching_edges_ready": bool(checks.get("map_has_branching", False)),
        "available_next_nodes_ready": len(route_state.get("available_next_node_ids", [])) > 0,
        "edge_connectivity_valid": bool(checks.get("edge_connectivity_valid", False)),
        "sampled_route_metrics_ready": bool(checks.get("sampled_route_metrics_ready", False)),
        "sampled_big_map_battle_count_between_14_and_16": bool(checks.get("sampled_big_map_battle_count_between_14_and_16", False)),
        "sampled_operation_count_between_7_and_10": bool(checks.get("sampled_operation_count_between_7_and_10", False)),
        "sampled_elite_count_between_3_and_5": bool(checks.get("sampled_elite_count_between_3_and_5", False)),
        "compatible_network_map_root_ready": bool(checks.get("big_map_compatible_root_fields_ready", False)),
        "compatible_network_map_nodes_ready": bool(checks.get("big_map_compatible_nodes_ready", False)),
        "compatible_map_graph_id_ready": bool(checks.get("compatible_map_graph_id_ready", False)),
        "compatible_battle_entry_fields_ready": bool(checks.get("compatible_battle_entry_fields_ready", False)),
        "story_beat_binding_ready": bool(checks.get("story_beat_ids_unique", False)) and bool(checks.get("compatible_story_beat_fields_ready", False)),
        "compatible_story_beat_fields_ready": bool(checks.get("compatible_story_beat_fields_ready", False)),
        "compatible_result_text_preserved": bool(checks.get("compatible_result_text_preserved", False)),
        "compatible_battle_difficulty_ready": bool(checks.get("compatible_battle_difficulty_ready", False)),
        "existing_big_map_node_schema_compatible": bool(checks.get("big_map_compatible_root_fields_ready", False)) and bool(checks.get("big_map_compatible_nodes_ready", False)),
        "current_release_unchanged": bool(checks.get("current_release_unchanged", False)),
        "active_profile_matches_current_release": (
            str(active_profile.get("active_mechanic_profile_id", "")) == str(current_release.get("mechanic_profile_id", ""))
            and str(active_profile.get("active_content_pack_id", "")) == str(current_release.get("content_pack_id", ""))
            and str(active_profile.get("runtime_manifest_path", "")) == str(current_release.get("runtime_manifest_path", ""))
        ),
        "fallback_release_unchanged": bool(checks.get("fallback_release_unchanged", False)),
        "no_runtime_modified": bool(checks.get("no_runtime_modified", False)),
        "no_scene_modified": bool(checks.get("no_scene_modified", False)),
    }
    fields["probe_pass"] = all(fields.values())

    report = {
        "probe": "aigc_dungeon_map_probe",
        "fields": fields,
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
        "sampled_routes": validation.get("sampled_routes", []),
    }

    md_lines = [
        "# Dungeon Map Probe Report",
        "",
        "## Fields",
    ]
    for key, value in fields.items():
        md_lines.append(f"- `{key}={str(value).lower()}`")

    _write_json(PROBE_JSON_PATH, report)
    _write_text(PROBE_MD_PATH, "\n".join(md_lines) + "\n")
    print("wrote %s" % PROBE_JSON_PATH.relative_to(ROOT))
    print("wrote %s" % PROBE_MD_PATH.relative_to(ROOT))
    print("probe_pass=%s" % str(fields["probe_pass"]).lower())


if __name__ == "__main__":
    main()
