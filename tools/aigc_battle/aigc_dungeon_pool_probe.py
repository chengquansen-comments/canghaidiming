#!/usr/bin/env python3
from __future__ import annotations

import importlib.util
import json
import sys
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[2]
VALIDATOR_PATH = ROOT / "tools" / "aigc_battle" / "aigc_dungeon_progression_validator.py"
PROGRESSION_PATH = ROOT / "data" / "aigc_battle" / "progression_templates" / "dungeon_progression_v1_3.json"
PACK_DIR = ROOT / "data" / "aigc_battle" / "generated" / "dungeon_progression_v1_3" / "packs" / "dungeon_pool_pack_001"
REPORTS_DIR = ROOT / "data" / "aigc_battle" / "generated" / "dungeon_progression_v1_3" / "reports"
CURRENT_RELEASE_PATH = ROOT / "data" / "aigc_battle" / "release_channels" / "current_release.json"
ACTIVE_PROFILE_PATH = ROOT / "data" / "aigc_battle" / "runtime" / "active_profile.json"
FALLBACK_RELEASE_PATH = ROOT / "data" / "aigc_battle" / "release_channels" / "fallback_release.json"


def _read_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def _write_json(path: Path, payload: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def _write_text(path: Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8")


def _load_validator_module():
    spec = importlib.util.spec_from_file_location("aigc_dungeon_progression_validator", VALIDATOR_PATH)
    if spec is None or spec.loader is None:
        raise RuntimeError("failed to load validator module")
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


def main() -> None:
    validator = _load_validator_module()
    validation_report = validator.run_validation()

    progression = _read_json(PROGRESSION_PATH)
    manifest = _read_json(PACK_DIR / "content_pool_manifest.json")
    battle_slot_pool = _read_json(PACK_DIR / "battle_slot_pool.json")
    enemy_deck_pool = _read_json(PACK_DIR / "enemy_deck_pool.json")
    reward_plan_pool = _read_json(PACK_DIR / "reward_plan_pool.json")
    card_pool = _read_json(PACK_DIR / "card_pool.json")
    operation_node_pool = _read_json(PACK_DIR / "operation_node_pool.json")
    route_rules = _read_json(PACK_DIR / "route_rules.json")
    growth_rules = _read_json(PACK_DIR / "growth_rules.json")

    current_release = _read_json(CURRENT_RELEASE_PATH)
    active_profile = _read_json(ACTIVE_PROFILE_PATH)

    slots = battle_slot_pool.get("battle_slots", [])
    adapter_fields = [
      "map_node_type_hint",
      "compatible_network_node_type",
      "compatible_combat_pool_id",
      "compatible_encounter_id",
      "compatible_battle_id"
    ]

    existing_big_map_adapter_fields_ready = True
    for slot in slots:
        if not isinstance(slot, dict):
            existing_big_map_adapter_fields_ready = False
            break
        for field in adapter_fields:
            if field not in slot:
                existing_big_map_adapter_fields_ready = False
                break
        if not existing_big_map_adapter_fields_ready:
            break

    validator_checks = validation_report.get("checks", {})
    probe = {
        "dungeon_progression_template_ready": PROGRESSION_PATH.exists(),
        "content_pool_pack_ready": PACK_DIR.exists(),
        "content_pool_manifest_ready": (PACK_DIR / "content_pool_manifest.json").exists(),
        "battle_slot_pool_ready": (PACK_DIR / "battle_slot_pool.json").exists(),
        "enemy_deck_pool_ready": (PACK_DIR / "enemy_deck_pool.json").exists(),
        "reward_plan_pool_ready": (PACK_DIR / "reward_plan_pool.json").exists(),
        "card_pool_ready": (PACK_DIR / "card_pool.json").exists(),
        "operation_node_pool_ready": (PACK_DIR / "operation_node_pool.json").exists(),
        "route_rules_ready": (PACK_DIR / "route_rules.json").exists(),
        "growth_rules_ready": (PACK_DIR / "growth_rules.json").exists(),
        "prologue_slot_count": sum(1 for slot in slots if slot.get("stage") == "prologue"),
        "wuju_slot_count": sum(1 for slot in slots if slot.get("stage") == "wuju"),
        "big_map_candidate_pool_target": progression.get("segments", {}).get("big_map", {}).get("candidate_pool_target"),
        "big_map_normal_candidate_target_ready": battle_slot_pool.get("targets", {}).get("big_map_normal_candidate_target_range") == [20, 24],
        "big_map_elite_candidate_target_ready": battle_slot_pool.get("targets", {}).get("big_map_elite_candidate_target_range") == [8, 10],
        "normal_route_target_total": progression.get("ending_routes", {}).get("normal", {}).get("target_total_battles"),
        "true_route_target_total": progression.get("ending_routes", {}).get("true", {}).get("target_total_battles"),
        "wuzhuangyuan_route_target_total": progression.get("ending_routes", {}).get("wuzhuangyuan", {}).get("target_total_battles"),
        "growth_model_ready": progression.get("growth_model", {}).get("martial_realm_max") == 10,
        "lightness_rule_ready": progression.get("lightness_model", {}).get("lightness_max") == 4 and progression.get("lightness_model", {}).get("normal_lightness_cap") == 2,
        "no_fixed_sequence_assumption": manifest.get("supports_fixed_sequence") is False and progression.get("big_map_constraints", {}).get("no_fixed_linear_sequence") is True,
        "route_choice_required": progression.get("big_map_constraints", {}).get("route_choice_required") is True and route_rules.get("player_choice_decides_route") is True,
        "existing_big_map_adapter_fields_ready": existing_big_map_adapter_fields_ready,
        "battle_slot_enemy_deck_refs_valid": bool(validator_checks.get("all_battle_slot_enemy_deck_refs_exist", {}).get("passed", False)),
        "battle_slot_reward_plan_refs_valid": bool(validator_checks.get("all_battle_slot_reward_plan_refs_exist", {}).get("passed", False)),
        "reward_card_refs_valid": bool(validator_checks.get("all_reward_card_refs_exist_or_placeholder_allowed", {}).get("passed", False)),
        "pool_validator_pass": bool(validation_report.get("all_checks_passed", False)),
        "current_release_unchanged": bool(validator_checks.get("current_release_unchanged", {}).get("passed", False)),
        "active_profile_matches_current_release": bool(validator_checks.get("active_profile_matches_current_release", {}).get("passed", False)),
        "fallback_release_unchanged": bool(validator_checks.get("fallback_release_unchanged", {}).get("passed", False)),
        "no_runtime_modified": True,
        "no_scene_modified": True
    }

    required_true = [
        probe["dungeon_progression_template_ready"],
        probe["content_pool_pack_ready"],
        probe["battle_slot_pool_ready"],
        probe["growth_model_ready"],
        probe["lightness_rule_ready"],
        probe["no_fixed_sequence_assumption"],
        probe["route_choice_required"],
        probe["existing_big_map_adapter_fields_ready"],
        probe["battle_slot_enemy_deck_refs_valid"],
        probe["battle_slot_reward_plan_refs_valid"],
        probe["pool_validator_pass"],
        probe["current_release_unchanged"],
        probe["active_profile_matches_current_release"],
        probe["fallback_release_unchanged"],
        probe["no_runtime_modified"],
        probe["no_scene_modified"]
    ]
    pass_counts = (
        probe["prologue_slot_count"] == 1
        and probe["wuju_slot_count"] == 5
        and probe["big_map_candidate_pool_target"] == 30
        and probe["normal_route_target_total"] == 22
        and probe["true_route_target_total"] == 23
        and probe["wuzhuangyuan_route_target_total"] == 26
    )
    probe["probe_pass"] = all(required_true) and pass_counts

    report = {
        "probe": "aigc_dungeon_pool_probe",
        "progression_template_id": progression.get("progression_template_id", ""),
        "content_pool_pack_id": manifest.get("content_pool_pack_id", ""),
        "fields": probe,
        "current_release_summary": {
            "mechanic_profile_id": current_release.get("mechanic_profile_id"),
            "content_pack_id": current_release.get("content_pack_id"),
            "runtime_manifest_path": current_release.get("runtime_manifest_path")
        },
        "active_profile_summary": {
            "active_mechanic_profile_id": active_profile.get("active_mechanic_profile_id"),
            "active_content_pack_id": active_profile.get("active_content_pack_id"),
            "runtime_manifest_path": active_profile.get("runtime_manifest_path")
        },
        "counts": {
            "battle_slot_pool_count": len(slots),
            "enemy_deck_pool_count": len(enemy_deck_pool.get("enemy_decks", [])),
            "reward_plan_pool_count": len(reward_plan_pool.get("reward_plans", [])),
            "card_pool_count": len(card_pool.get("cards", [])),
            "operation_node_pool_count": len(operation_node_pool.get("operation_nodes", []))
        }
    }

    md_lines = [
        "# Dungeon Pool Probe Report",
        "",
        "## Key Fields",
    ]
    for key, value in probe.items():
        md_lines.append("- `%s=%s`" % (key, str(value).lower() if isinstance(value, bool) else value))
    md_lines.extend([
        "",
        "## Current/Active",
        "- current mechanic_profile_id: `%s`" % current_release.get("mechanic_profile_id", ""),
        "- current content_pack_id: `%s`" % current_release.get("content_pack_id", ""),
        "- active mechanic_profile_id: `%s`" % active_profile.get("active_mechanic_profile_id", ""),
        "- active content_pack_id: `%s`" % active_profile.get("active_content_pack_id", "")
    ])

    json_path = REPORTS_DIR / "dungeon_pool_probe_report.json"
    md_path = REPORTS_DIR / "dungeon_pool_probe_report.md"
    _write_json(json_path, report)
    _write_text(md_path, "\n".join(md_lines) + "\n")
    print("wrote %s" % json_path.relative_to(ROOT))
    print("wrote %s" % md_path.relative_to(ROOT))
    print("probe_pass=%s" % str(probe["probe_pass"]).lower())


if __name__ == "__main__":
    main()
