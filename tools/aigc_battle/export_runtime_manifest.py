#!/usr/bin/env python3
from __future__ import annotations

import json
import argparse
import sys
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[2]
MECHANICS_DIR = ROOT / "data" / "aigc_battle" / "mechanics"
GENERATED_DIR = ROOT / "data" / "aigc_battle" / "generated"


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("profile_id")
    parser.add_argument("--generated-dir", dest="generated_dir", default="")
    args = parser.parse_args(argv[1:])
    profile_id = args.profile_id
    generated_dir = Path(args.generated_dir) if args.generated_dir else GENERATED_DIR / profile_id
    mechanic_profile = read_json(MECHANICS_DIR / profile_id / "mechanic_profile.json")
    content_recipe = read_json(MECHANICS_DIR / profile_id / "content_recipe.json")
    validation_report = read_json(generated_dir / "validation_report.json")
    if not validation_report.get("runtime_export_allowed", False):
        raise SystemExit("runtime export blocked: validation_report.runtime_export_allowed is false")
    if validation_report.get("not_runtime_playable", False):
        raise SystemExit("runtime export blocked: profile is not runtime playable")
    if not validation_report.get("runtime_effects_supported", False):
        raise SystemExit("runtime export blocked: runtime effects are not supported")
    if not validation_report.get("runtime_primitive_export_allowed", True):
        raise SystemExit("runtime export blocked: runtime primitive export is not allowed")
    if not validation_report.get("runtime_primitives_supported", True):
        raise SystemExit("runtime export blocked: runtime primitives are not supported")
    if not validation_report.get("opening_pressure_all_slots_covered", True):
        raise SystemExit("runtime export blocked: opening_pressure does not cover all slots")
    if not validation_report.get("opening_pressure_values_in_range", True):
        raise SystemExit("runtime export blocked: opening_pressure values are out of range")
    if not validation_report.get("weapon_followup_runtime_export_allowed", True):
        raise SystemExit("runtime export blocked: weapon_followup export is not allowed")
    if not validation_report.get("weapon_followup_chain_valid", True):
        raise SystemExit("runtime export blocked: weapon_followup chain is invalid")
    if not validation_report.get("weapon_followup_values_in_range", True):
        raise SystemExit("runtime export blocked: weapon_followup values are out of range")
    if not validation_report.get("clue_pressure_runtime_export_allowed", True):
        raise SystemExit("runtime export blocked: clue_pressure export is not allowed")
    if not validation_report.get("martial_realm_7_playable", True):
        raise SystemExit("runtime export blocked: martial_realm_7 is not playable")
    if not validation_report.get("dual_weapon_playable", True):
        raise SystemExit("runtime export blocked: dual_weapon is not playable")
    if not validation_report.get("dual_weapon_runtime_export_allowed", True):
        raise SystemExit("runtime export blocked: dual_weapon export is not allowed")
    if not validation_report.get("unsupported_design_effects_blocked", False):
        raise SystemExit("runtime export blocked: unsupported design effects detected")
    if not validation_report.get("full_sequence_coverage_complete", False):
        raise SystemExit("runtime export blocked: full sequence coverage is incomplete")
    if not validation_report.get("sequence_balance_pass", False):
        raise SystemExit("runtime export blocked: sequence balance pass is false")
    if not validation_report.get("ready_for_runtime_export", False):
        raise SystemExit("runtime export blocked: validation report not ready")
    if not validation_report.get("deck_card_realm_eligibility_valid", False):
        raise SystemExit("runtime export blocked: deck card realm eligibility is invalid")
    if not validation_report.get("no_card_above_player_wujing_in_deck", False):
        raise SystemExit("runtime export blocked: card above player_wujing_cap detected")
    if int(validation_report.get("invalid_realm_card_count", 0)) > 0:
        raise SystemExit("runtime export blocked: invalid realm card count is greater than zero")
    if int(validation_report.get("missing_realm_metadata_count", 0)) > 0:
        raise SystemExit("runtime export blocked: missing realm metadata count is greater than zero")
    if validation_report.get("llm_candidate_import_detected", False) and not validation_report.get("llm_content_ready_for_runtime_export", False):
        raise SystemExit("runtime export blocked: llm content is not ready for runtime export")

    inventory = read_json(generated_dir / "formal_sequence_inventory.generated.json")
    card_pool = read_json(generated_dir / "card_pool.generated.json")
    deck_pool = read_json(generated_dir / "enemy_deck_pool.generated.json")
    battle_slots = read_json(generated_dir / "battle_slot_bindings.generated.json")
    rewards = read_json(generated_dir / "rewards.generated.json")
    mappings = read_json(generated_dir / "formal_sequence_mapping.generated.json")
    balance_summary = read_json(generated_dir / "sequence_balance_summary.json")
    content_pack_summary = read_json(generated_dir / "content_pack_summary.json") if (generated_dir / "content_pack_summary.json").exists() else {}
    imported_candidate_summary_path = generated_dir / "imported_candidate_summary.json"
    imported_candidate_summary = read_json(imported_candidate_summary_path) if imported_candidate_summary_path.exists() else None
    runtime_primitives = [str(item) for item in mechanic_profile.get("runtime_primitives", [])]

    inventory_ids = {str(item["formal_encounter_id"]) for item in inventory}
    mapping_ids = {str(item["formal_encounter_id"]) for item in mappings}
    if inventory_ids != mapping_ids:
        raise SystemExit("runtime manifest export blocked: inventory and mapping coverage differ")

    manifest = {
        "manifest_version": 1,
        "mechanic_profile_id": mechanic_profile["mechanic_profile_id"],
        "content_pack_id": str(content_pack_summary.get("content_pack_id", content_recipe["content_pack_id"])),
        "target_sequence_id": content_recipe["target_sequence_id"],
        "replacement_mode": "full_sequence",
        "runtime_supported_effects": mechanic_profile["allowed_runtime_effects"],
        "runtime_primitives": runtime_primitives,
        "runtime_primitive_summary": {
            "runtime_primitives_supported": validation_report.get("runtime_primitives_supported", True),
            "opening_pressure_declared": validation_report.get("opening_pressure_declared", False),
            "opening_pressure_slot_count": validation_report.get("opening_pressure_slots_count", 0),
            "opening_pressure_all_slots_covered": validation_report.get("opening_pressure_all_slots_covered", True),
            "opening_pressure_values_in_range": validation_report.get("opening_pressure_values_in_range", True),
            "opening_pressure_curve_ready": validation_report.get("opening_pressure_curve_ready", True),
            "weapon_followup_declared": validation_report.get("weapon_followup_declared", False),
            "weapon_followup_cards_present": validation_report.get("weapon_followup_cards_present", True),
            "weapon_followup_decks_present": validation_report.get("weapon_followup_decks_present", True),
            "weapon_followup_all_slots_covered": validation_report.get("weapon_followup_all_slots_covered", True),
            "weapon_followup_chain_valid": validation_report.get("weapon_followup_chain_valid", True),
            "weapon_followup_values_in_range": validation_report.get("weapon_followup_values_in_range", True),
            "weapon_followup_curve_ready": validation_report.get("weapon_followup_curve_ready", True),
            "weapon_followup_runtime_export_allowed": validation_report.get("weapon_followup_runtime_export_allowed", True),
            "clue_pressure_declared": validation_report.get("clue_pressure_declared", False),
            "clue_pressure_all_slots_covered": validation_report.get("clue_pressure_all_slots_covered", True),
            "clue_pressure_tags_valid": validation_report.get("clue_pressure_tags_valid", True),
            "clue_pressure_effects_valid": validation_report.get("clue_pressure_effects_valid", True),
            "clue_pressure_values_in_range": validation_report.get("clue_pressure_values_in_range", True),
            "clue_pressure_curve_ready": validation_report.get("clue_pressure_curve_ready", True),
            "clue_pressure_runtime_export_allowed": validation_report.get("clue_pressure_runtime_export_allowed", True),
            "martial_realm_7_declared": validation_report.get("martial_realm_7_declared", False),
            "dual_weapon_declared": validation_report.get("dual_weapon_declared", False),
            "max_wujing": validation_report.get("max_wujing", 0),
            "max_closing_form_tier": validation_report.get("max_closing_form_tier", 0),
            "max_wujing_is_7": validation_report.get("max_wujing_is_7", True),
            "max_closing_form_tier_is_7": validation_report.get("max_closing_form_tier_is_7", True),
            "dual_weapon_slot_count": validation_report.get("dual_weapon_slot_count", 0),
            "dual_weapon_deck_count": validation_report.get("dual_weapon_deck_count", 0),
            "seven_realm_card_count": validation_report.get("seven_realm_card_count", 0),
            "invalid_weapon_loadout_card_count": validation_report.get("invalid_weapon_loadout_card_count", 0),
            "martial_realm_7_playable": validation_report.get("martial_realm_7_playable", True),
            "dual_weapon_playable": validation_report.get("dual_weapon_playable", True),
            "dual_weapon_runtime_export_allowed": validation_report.get("dual_weapon_runtime_export_allowed", True),
            "runtime_primitive_playable": validation_report.get("runtime_primitive_playable", True),
        },
        "balance_summary": balance_summary,
        "sequence_balance_pass": bool(balance_summary.get("sequence_balance_pass", False)),
        "content_source": "llm_candidate_import" if imported_candidate_summary else "generated_pipeline",
        "candidate_import_summary": imported_candidate_summary if imported_candidate_summary else None,
        "cards": card_pool,
        "enemy_decks": deck_pool,
        "battle_slots": battle_slots,
        "rewards": rewards,
        "formal_sequence_mapping": mappings,
    }
    write_json(generated_dir / "runtime_manifest.json", manifest)
    print(f"exported runtime manifest: {profile_id}")
    return 0


def read_json(path: Path) -> Any:
    return json.loads(path.read_text(encoding="utf-8"))


def write_json(path: Path, payload: Any) -> None:
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
