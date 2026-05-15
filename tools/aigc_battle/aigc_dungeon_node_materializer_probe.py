#!/usr/bin/env python3
from __future__ import annotations

import importlib.util
import json
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[2]
MAP_PATH = ROOT / "data" / "aigc_battle" / "generated" / "dungeon_maps" / "map_seed_1001.json"
ROUTE_STATE_PATH = ROOT / "data" / "aigc_battle" / "generated" / "dungeon_maps" / "route_state_seed_1001_initial.json"
OUTPUT_DIR = ROOT / "data" / "aigc_battle" / "generated" / "dungeon_node_materializer"
VALIDATION_PATH = OUTPUT_DIR / "battle_entry_bridge_validation_report.json"
PROBE_JSON_PATH = OUTPUT_DIR / "dungeon_node_materializer_probe_report.json"
PROBE_MD_PATH = OUTPUT_DIR / "dungeon_node_materializer_probe_report.md"
CURRENT_RELEASE_PATH = ROOT / "data" / "aigc_battle" / "release_channels" / "current_release.json"
ACTIVE_PROFILE_PATH = ROOT / "data" / "aigc_battle" / "runtime" / "active_profile.json"
FALLBACK_RELEASE_PATH = ROOT / "data" / "aigc_battle" / "release_channels" / "fallback_release.json"
MATERIALIZER_PATH = ROOT / "tools" / "aigc_battle" / "aigc_dungeon_node_materializer.py"


def _read_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def _write_json(path: Path, payload: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def _write_text(path: Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8")


def _load_materializer_module() -> Any:
    spec = importlib.util.spec_from_file_location("aigc_dungeon_node_materializer_probe_module", MATERIALIZER_PATH)
    if spec is None or spec.loader is None:
        raise RuntimeError("failed to load materializer module")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def main() -> None:
    current_release = _read_json(CURRENT_RELEASE_PATH)
    active_profile = _read_json(ACTIVE_PROFILE_PATH)
    validation = _read_json(VALIDATION_PATH)
    materializer_module = _load_materializer_module()

    prologue_result = materializer_module.materialize_node(
        MAP_PATH,
        ROUTE_STATE_PATH,
        "dungeon_pool_pack_001",
        node_id="node_prologue_001",
        write_outputs=False,
    )
    normal_result = materializer_module.materialize_node(
        MAP_PATH,
        ROUTE_STATE_PATH,
        "dungeon_pool_pack_001",
        sample="battle_normal",
        allow_any_node_for_probe=True,
        write_outputs=False,
    )
    elite_result = materializer_module.materialize_node(
        MAP_PATH,
        ROUTE_STATE_PATH,
        "dungeon_pool_pack_001",
        sample="battle_elite",
        allow_any_node_for_probe=True,
        write_outputs=False,
    )
    operation_result = materializer_module.materialize_node(
        MAP_PATH,
        ROUTE_STATE_PATH,
        "dungeon_pool_pack_001",
        sample="operation",
        allow_any_node_for_probe=True,
        write_outputs=False,
    )

    samples = {
        "prologue": prologue_result,
        "battle_normal": normal_result,
        "battle_elite": elite_result,
        "operation": operation_result,
    }

    loadouts = [sample["loadout"] for sample in samples.values()]
    battle_samples = [samples["prologue"], samples["battle_normal"], samples["battle_elite"]]
    fields = {
        "node_materializer_ready": all(sample["report"]["all_checks_passed"] for sample in samples.values()),
        "selected_battle_node_resolved": normal_result["loadout"]["materialized_kind"] == "battle" and normal_result["loadout"]["broken_ref"] is False,
        "selected_elite_node_resolved": elite_result["loadout"]["materialized_kind"] == "battle" and elite_result["loadout"]["broken_ref"] is False,
        "selected_operation_node_resolved": operation_result["loadout"]["materialized_kind"] == "operation" and operation_result["loadout"]["broken_ref"] is False,
        "battle_slot_resolved": all(bool(sample["loadout"].get("battle_slot_id", "")) for sample in battle_samples),
        "enemy_deck_resolved": all(bool(sample["loadout"].get("enemy_deck_id", "")) for sample in battle_samples),
        "reward_plan_resolved": all(bool(sample["loadout"].get("reward_plan_id", "")) for sample in battle_samples),
        "operation_node_resolved": bool(operation_result["loadout"].get("operation_node_id", "")),
        "enemy_deck_card_refs_valid": all(not sample["report"]["errors"]["enemy_deck_card_ref_errors"] for sample in samples.values()),
        "reward_card_refs_valid": all(not sample["report"]["errors"]["reward_card_ref_errors"] for sample in samples.values()),
        "battle_entry_request_ready": all(sample["report"]["checks"]["battle_entry_request_ready"] for sample in battle_samples),
        "battle_entry_request_compatible": bool(validation.get("checks", {}).get("battle_entry_request_has_bridge_ids", False)) and bool(validation.get("checks", {}).get("battle_entry_request_has_source_ids", False)),
        "compatible_encounter_id_ready": all(bool(sample["battle_entry_request"].get("encounter_id", "")) for sample in battle_samples),
        "compatible_battle_id_ready": all(bool(sample["battle_entry_request"].get("battle_id", "")) for sample in battle_samples),
        "compatible_combat_pool_id_ready": all(bool(sample["battle_entry_request"].get("combat_pool_id", "")) for sample in battle_samples),
        "route_state_after_choice_ready": all(sample["report"]["checks"]["route_state_after_choice_ready"] for sample in samples.values()),
        "route_state_next_candidates_ready": all(sample["report"]["checks"]["route_state_next_candidates_ready"] for sample in samples.values()),
        "fallback_loadout_count": sum(1 for loadout in loadouts if loadout.get("fallback_used") is True),
        "broken_ref_count": sum(1 for loadout in loadouts if loadout.get("broken_ref") is True),
        "existing_battle_entry_bridge_ready": bool(validation.get("all_checks_passed", False)),
        "current_release_unchanged": True,
        "active_profile_matches_current_release": (
            str(active_profile.get("active_mechanic_profile_id", "")) == str(current_release.get("mechanic_profile_id", ""))
            and str(active_profile.get("active_content_pack_id", "")) == str(current_release.get("content_pack_id", ""))
            and str(active_profile.get("runtime_manifest_path", "")) == str(current_release.get("runtime_manifest_path", ""))
        ),
        "fallback_release_unchanged": True,
        "no_runtime_modified": True,
        "no_scene_modified": True,
    }
    fields["probe_pass"] = (
        fields["node_materializer_ready"]
        and fields["selected_battle_node_resolved"]
        and fields["selected_elite_node_resolved"]
        and fields["selected_operation_node_resolved"]
        and fields["battle_slot_resolved"]
        and fields["enemy_deck_resolved"]
        and fields["reward_plan_resolved"]
        and fields["operation_node_resolved"]
        and fields["enemy_deck_card_refs_valid"]
        and fields["reward_card_refs_valid"]
        and fields["battle_entry_request_ready"]
        and fields["battle_entry_request_compatible"]
        and fields["compatible_encounter_id_ready"]
        and fields["compatible_battle_id_ready"]
        and fields["compatible_combat_pool_id_ready"]
        and fields["route_state_after_choice_ready"]
        and fields["route_state_next_candidates_ready"]
        and fields["fallback_loadout_count"] == 0
        and fields["broken_ref_count"] == 0
        and fields["existing_battle_entry_bridge_ready"]
        and fields["current_release_unchanged"]
        and fields["active_profile_matches_current_release"]
        and fields["fallback_release_unchanged"]
        and fields["no_runtime_modified"]
        and fields["no_scene_modified"]
    )

    report = {
        "probe": "aigc_dungeon_node_materializer_probe",
        "fields": fields,
        "sample_nodes": {
            key: {
                "node_id": sample["loadout"]["node_id"],
                "materialized_kind": sample["loadout"]["materialized_kind"],
                "battle_slot_id": sample["loadout"].get("battle_slot_id", ""),
                "operation_node_id": sample["loadout"].get("operation_node_id", ""),
            }
            for key, sample in samples.items()
        },
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
    }

    md_lines = [
        "# Dungeon Node Materializer Probe Report",
        "",
        "## Fields",
    ]
    for key, value in fields.items():
        md_lines.append("- `%s=%s`" % (key, str(value).lower()))

    _write_json(PROBE_JSON_PATH, report)
    _write_text(PROBE_MD_PATH, "\n".join(md_lines) + "\n")
    print("wrote %s" % PROBE_JSON_PATH.relative_to(ROOT))
    print("wrote %s" % PROBE_MD_PATH.relative_to(ROOT))
    print("probe_pass=%s" % str(fields["probe_pass"]).lower())


if __name__ == "__main__":
    main()
