#!/usr/bin/env python3
from __future__ import annotations

import json
import argparse
import sys
from collections import Counter
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[2]
MECHANICS_DIR = ROOT / "data" / "aigc_battle" / "mechanics"
GENERATED_DIR = ROOT / "data" / "aigc_battle" / "generated"
RUNTIME_EFFECT_SUPPORT = {
    "godot_formal_sequence_v1": {"damage", "gain_block", "gain_momentum", "break_momentum"},
}
RUNTIME_PRIMITIVE_SUPPORT = {
    "godot_formal_sequence_v1": {"opening_pressure", "weapon_followup", "clue_pressure", "martial_realm_7", "dual_weapon"},
}


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("profile_id")
    parser.add_argument("--generated-dir", dest="generated_dir", default="")
    args = parser.parse_args(argv[1:])
    profile_id = args.profile_id
    mechanic_profile = read_json(MECHANICS_DIR / profile_id / "mechanic_profile.json")
    content_recipe = read_json(MECHANICS_DIR / profile_id / "content_recipe.json")
    generated_dir = Path(args.generated_dir) if args.generated_dir else GENERATED_DIR / profile_id
    inventory = read_json(generated_dir / "formal_sequence_inventory.generated.json")
    card_pool = read_json(generated_dir / "card_pool.generated.json")
    deck_pool = read_json(generated_dir / "enemy_deck_pool.generated.json")
    battle_slots = read_json(generated_dir / "battle_slot_bindings.generated.json")
    rewards = read_json(generated_dir / "rewards.generated.json")
    mappings = read_json(generated_dir / "formal_sequence_mapping.generated.json")
    balance_summary = read_json(generated_dir / "sequence_balance_summary.json")
    content_pack_summary = read_json(generated_dir / "content_pack_summary.json")
    imported_candidate_summary_path = generated_dir / "imported_candidate_summary.json"
    imported_candidate_summary = read_json(imported_candidate_summary_path) if imported_candidate_summary_path.exists() else None

    errors: list[str] = []
    warnings: list[str] = []
    profile_id_expected = str(mechanic_profile["mechanic_profile_id"])
    content_pack_id_expected = str(content_pack_summary.get("content_pack_id", content_recipe["content_pack_id"]))
    allowed_runtime_effects = set(str(item) for item in mechanic_profile.get("allowed_runtime_effects", []))
    allowed_design_effects = set(str(item) for item in mechanic_profile.get("allowed_design_effects", []))
    runtime_support_level = str(mechanic_profile.get("runtime_support_level", ""))
    runtime_supported_effects = set(RUNTIME_EFFECT_SUPPORT.get(runtime_support_level, set()))
    runtime_supported_primitives = set(RUNTIME_PRIMITIVE_SUPPORT.get(runtime_support_level, set()))
    declared_runtime_primitives = [str(item) for item in mechanic_profile.get("runtime_primitives", [])]
    runtime_primitive_constraints = mechanic_profile.get("runtime_primitive_constraints", {})
    eligibility_rules = mechanic_profile.get("card_eligibility_rules", {})
    weapon_styles = set(str(item) for item in mechanic_profile.get("weapon_styles", []))
    card_constraints = mechanic_profile.get("card_constraints", {})
    deck_constraints = mechanic_profile.get("deck_constraints", {})

    check_profile_object("card_pool", card_pool, profile_id_expected, content_pack_id_expected, errors)
    check_profile_object("enemy_deck_pool", deck_pool, profile_id_expected, content_pack_id_expected, errors)
    check_profile_object("battle_slots", battle_slots, profile_id_expected, content_pack_id_expected, errors)
    check_profile_object("rewards", rewards, profile_id_expected, content_pack_id_expected, errors)
    check_profile_object("formal_sequence_mapping", mappings, profile_id_expected, content_pack_id_expected, errors)

    inventory_ids = [str(item.get("formal_encounter_id", "")) for item in inventory]
    inventory_set = set(inventory_ids)
    mapping_by_encounter = {str(item.get("formal_encounter_id", "")): item for item in mappings}
    slot_ids = {str(item.get("battle_slot_id", "")) for item in battle_slots}
    deck_by_id = {str(item.get("deck_id", "")): item for item in deck_pool}
    reward_by_id = {str(item.get("reward_plan_id", "")): item for item in rewards}
    card_by_id = {str(item.get("card_id", "")): item for item in card_pool}

    if not inventory:
        errors.append("formal sequence inventory is empty")
    missing_encounters = sorted(inventory_set.difference(mapping_by_encounter))
    if missing_encounters:
        errors.append(f"uncovered formal encounters: {missing_encounters}")
    coverage_count = len(inventory_set.intersection(mapping_by_encounter))
    total_count = len(inventory_set)
    full_sequence_coverage_complete = coverage_count == total_count and total_count > 0

    unsupported_card_effects: list[str] = []
    unsupported_design_effects = sorted(allowed_design_effects - allowed_runtime_effects)
    unsupported_runtime_effect_whitelist = sorted(allowed_runtime_effects - runtime_supported_effects)
    runtime_primitives_supported = all(item in runtime_supported_primitives for item in declared_runtime_primitives)
    opening_pressure_declared = "opening_pressure" in declared_runtime_primitives
    weapon_followup_declared = "weapon_followup" in declared_runtime_primitives
    clue_pressure_declared = "clue_pressure" in declared_runtime_primitives
    martial_realm_7_declared = "martial_realm_7" in declared_runtime_primitives
    dual_weapon_declared = "dual_weapon" in declared_runtime_primitives
    opening_pressure_slots_count = 0
    opening_pressure_all_slots_covered = True
    opening_pressure_values_in_range = True
    weapon_followup_cards_present = not weapon_followup_declared
    weapon_followup_decks_present = not weapon_followup_declared
    weapon_followup_all_slots_covered = True
    weapon_followup_chain_valid = True
    weapon_followup_values_in_range = True
    weapon_followup_curve_ready = bool(balance_summary.get("weapon_followup_curve_ready", not weapon_followup_declared))
    weapon_followup_runtime_export_allowed = not weapon_followup_declared
    weapon_followup_playable = not weapon_followup_declared
    clue_pressure_all_slots_covered = True
    clue_pressure_tags_valid = True
    clue_pressure_effects_valid = True
    clue_pressure_values_in_range = True
    clue_pressure_curve_ready = not clue_pressure_declared
    clue_pressure_runtime_export_allowed = not clue_pressure_declared
    max_wujing_is_7 = (not martial_realm_7_declared) or int(mechanic_profile.get("max_wujing", 0)) == 7
    max_closing_form_tier_is_7 = (not martial_realm_7_declared) or int(mechanic_profile.get("max_closing_form_tier", 0)) == 7
    all_cards_have_required_wujing = True
    all_cards_have_closing_form_tier = True
    all_cards_required_wujing_in_range = True
    all_cards_closing_form_tier_in_range = True
    all_slots_have_player_wujing_cap = True
    all_decks_have_weapon_loadout = True
    dual_weapon_slots_present = not dual_weapon_declared
    dual_weapon_ratio_valid = True
    boss_slots_dual_weapon_enabled = True
    boss_slots_wujing_cap_7 = True
    no_card_closing_form_above_player_wujing_in_deck = True
    seven_realm_cards_only_in_wujing_7_slots = True
    weapon_loadout_card_compatibility_valid = True
    dual_weapon_generic_ratio_valid = True
    martial_realm_curve_ready = not martial_realm_7_declared
    dual_weapon_runtime_export_allowed = not dual_weapon_declared
    martial_realm_7_playable = not martial_realm_7_declared
    dual_weapon_playable = not dual_weapon_declared
    dual_weapon_slot_count = 0
    dual_weapon_deck_count = 0
    seven_realm_card_count = 0
    invalid_weapon_loadout_card_count = 0
    clue_pressure_slot_count = 0
    clue_pressure_tier_values: dict[str, list[int]] = {"early": [], "mid": [], "late": [], "boss": []}
    martial_cap_by_tier: dict[str, list[int]] = {"early": [], "mid": [], "late": [], "boss": []}
    allowed_clue_tags = set(str(item) for item in runtime_primitive_constraints.get("clue_pressure", {}).get("allowed_clue_tags", []))
    allowed_clue_effects = set(str(item) for item in runtime_primitive_constraints.get("clue_pressure", {}).get("allowed_pressure_effects", []))
    allowed_clue_timings = set(str(item) for item in runtime_primitive_constraints.get("clue_pressure", {}).get("allowed_trigger_timings", []))
    allowed_weapon_loadouts = {tuple(str(part) for part in item) for item in mechanic_profile.get("allowed_weapon_loadouts", []) if isinstance(item, list)}
    card_eligibility_rules_declared = bool(eligibility_rules)
    player_wujing_cap_present = True
    card_realm_metadata_present = True
    deck_card_realm_eligibility_valid = True
    no_card_above_player_wujing_in_deck = True
    invalid_realm_card_count = 0
    invalid_realm_card_refs: list[dict[str, Any]] = []
    missing_realm_metadata_count = 0
    missing_realm_metadata_refs: list[dict[str, Any]] = []

    for mapping in mappings:
        slot_id = str(mapping.get("generated_battle_slot_id", ""))
        deck_id = str(mapping.get("generated_deck_id", ""))
        reward_id = str(mapping.get("reward_plan_id", ""))
        if slot_id not in slot_ids:
            errors.append(f"mapping references missing battle slot: {slot_id}")
        if deck_id not in deck_by_id:
            errors.append(f"mapping references missing deck: {deck_id}")
        if reward_id not in reward_by_id:
            errors.append(f"mapping references missing reward: {reward_id}")
        if "sequence_position" not in mapping:
            errors.append("mapping missing sequence_position")

    mapped_slot_ids = {str(item.get("generated_battle_slot_id", "")) for item in mappings}
    orphan_slots = sorted(slot_ids.difference(mapped_slot_ids))
    if orphan_slots:
        errors.append(f"orphan generated battle slots: {orphan_slots}")

    min_card_power = float(card_constraints.get("min_power_score", 0))
    max_card_power = float(card_constraints.get("max_power_score", 999))
    for card in card_pool:
        card_id = str(card.get("card_id", ""))
        for effect in card.get("effects", []):
            effect_type = str(effect.get("type", ""))
            if effect_type not in allowed_runtime_effects:
                unsupported_card_effects.append(effect_type)
                errors.append(f"card {card_id} has unsupported runtime effect: {effect_type}")
        cost = int(card.get("cost", 0))
        if cost < int(card_constraints.get("min_cost", 0)) or cost > int(card_constraints.get("max_cost", 99)):
            errors.append(f"card {card_id} cost out of bounds: {cost}")
        weapon_style = str(card.get("weapon_style", ""))
        if weapon_style not in weapon_styles:
            errors.append(f"card {card_id} has unknown weapon_style: {weapon_style}")
        power_score = float(card.get("power_score", 0))
        if power_score < min_card_power or power_score > max_card_power:
            errors.append(f"card {card_id} power_score out of bounds: {power_score}")
        if is_realm_gated_card(card):
            if "required_wujing" not in card or "closing_form_tier" not in card:
                card_realm_metadata_present = False
        if martial_realm_7_declared:
            if "required_wujing" not in card:
                all_cards_have_required_wujing = False
                errors.append(f"card {card_id} missing required_wujing")
            if "closing_form_tier" not in card:
                all_cards_have_closing_form_tier = False
                errors.append(f"card {card_id} missing closing_form_tier")
            required_wujing = int(card.get("required_wujing", 0))
            closing_form_tier = int(card.get("closing_form_tier", 0))
            if not 1 <= required_wujing <= 7:
                all_cards_required_wujing_in_range = False
                errors.append(f"card {card_id} required_wujing out of range: {required_wujing}")
            if not 1 <= closing_form_tier <= 7:
                all_cards_closing_form_tier_in_range = False
                errors.append(f"card {card_id} closing_form_tier out of range: {closing_form_tier}")
            if required_wujing >= 7 or closing_form_tier >= 7:
                seven_realm_card_count += 1
        if weapon_followup_declared and str(card.get("followup_group", "")).strip():
            weapon_followup_cards_present = True
            trigger = str(card.get("followup_trigger", ""))
            if trigger and trigger not in set(str(item) for item in runtime_primitive_constraints.get("weapon_followup", {}).get("allowed_triggers", [])):
                errors.append(f"card {card_id} has invalid followup_trigger: {trigger}")
                weapon_followup_values_in_range = False
            bonus = card.get("followup_bonus", {})
            if not isinstance(bonus, dict):
                errors.append(f"card {card_id} followup_bonus is invalid")
                weapon_followup_values_in_range = False
            else:
                if int(bonus.get("bonus_damage", 0)) > int(runtime_primitive_constraints.get("weapon_followup", {}).get("max_bonus_damage", 0)):
                    errors.append(f"card {card_id} bonus_damage exceeds constraint")
                    weapon_followup_values_in_range = False
                if int(bonus.get("bonus_momentum", 0)) > int(runtime_primitive_constraints.get("weapon_followup", {}).get("max_bonus_momentum", 0)):
                    errors.append(f"card {card_id} bonus_momentum exceeds constraint")
                    weapon_followup_values_in_range = False
                if int(bonus.get("bonus_block", 0)) > int(runtime_primitive_constraints.get("weapon_followup", {}).get("max_bonus_block", 0)):
                    errors.append(f"card {card_id} bonus_block exceeds constraint")
                    weapon_followup_values_in_range = False

    min_deck_size = int(deck_constraints.get("min_deck_size", 0))
    max_deck_size = int(deck_constraints.get("max_deck_size", 999))
    max_same_card = int(deck_constraints.get("max_same_card", 999))
    all_decks_within_power_range = True
    for deck in deck_pool:
        deck_id = str(deck.get("deck_id", ""))
        card_ids = [str(card_id) for card_id in deck.get("card_ids", [])]
        if len(card_ids) < min_deck_size or len(card_ids) > max_deck_size:
            errors.append(f"deck {deck_id} size out of bounds: {len(card_ids)}")
        counts = Counter(card_ids)
        for card_id, count in counts.items():
            if card_id not in card_by_id:
                errors.append(f"deck {deck_id} references missing card: {card_id}")
            if count > max_same_card:
                errors.append(f"deck {deck_id} exceeds max copies for {card_id}: {count}")
        target_min = float(deck.get("target_power_min", -1))
        target_max = float(deck.get("target_power_max", -1))
        power_score = float(deck.get("deck_power_score", 0))
        if target_min < 0 or target_max < 0:
            errors.append(f"deck {deck_id} missing target power range")
        if not (target_min <= power_score <= target_max):
            errors.append(f"deck {deck_id} power out of range: {power_score} not in [{target_min}, {target_max}]")
            all_decks_within_power_range = False
        if not bool(deck.get("power_range_pass", False)):
            all_decks_within_power_range = False
        if martial_realm_7_declared:
            if "weapon_loadout" not in deck or not list(deck.get("weapon_loadout", [])):
                all_decks_have_weapon_loadout = False
                errors.append(f"deck {deck_id} missing weapon_loadout")
            if bool(deck.get("dual_weapon_enabled", False)):
                dual_weapon_deck_count += 1
            weapon_loadout = tuple(str(item) for item in deck.get("weapon_loadout", []))
            if dual_weapon_declared and allowed_weapon_loadouts and weapon_loadout not in allowed_weapon_loadouts:
                weapon_loadout_card_compatibility_valid = False
                errors.append(f"deck {deck_id} has invalid weapon_loadout: {list(weapon_loadout)}")
            primary_style = str(deck.get("primary_weapon_style", ""))
            secondary_style = str(deck.get("secondary_weapon_style", ""))
            generic_ratio = float(deck.get("generic_ratio", 0.0))
            if dual_weapon_declared and generic_ratio > float(runtime_primitive_constraints.get("dual_weapon", {}).get("max_generic_ratio", 1.0)):
                dual_weapon_generic_ratio_valid = False
                errors.append(f"deck {deck_id} generic_ratio exceeds constraint: {generic_ratio}")
            if bool(deck.get("dual_weapon_enabled", False)):
                if float(deck.get("primary_weapon_ratio", 0.0)) < float(runtime_primitive_constraints.get("dual_weapon", {}).get("min_primary_weapon_ratio", 0.0)):
                    dual_weapon_ratio_valid = False
                    errors.append(f"deck {deck_id} primary_weapon_ratio below constraint")
                if float(deck.get("secondary_weapon_ratio", 0.0)) < float(runtime_primitive_constraints.get("dual_weapon", {}).get("min_secondary_weapon_ratio", 0.0)):
                    dual_weapon_ratio_valid = False
                    errors.append(f"deck {deck_id} secondary_weapon_ratio below constraint")
                dual_weapon_slots_present = True
            for card_id in card_ids:
                card = card_by_id.get(card_id, {})
                style = str(card.get("weapon_style", ""))
                if style == "generic":
                    continue
                if style not in weapon_loadout:
                    invalid_weapon_loadout_card_count += 1
                    weapon_loadout_card_compatibility_valid = False
                    errors.append(f"deck {deck_id} card {card_id} incompatible with weapon_loadout")
                if primary_style and style == primary_style:
                    continue
                if secondary_style and style == secondary_style:
                    continue
        if weapon_followup_declared:
            followup_cards = [card_by_id.get(card_id, {}) for card_id in card_ids if bool(card_by_id.get(card_id, {}).get("followup_group"))]
            if followup_cards:
                weapon_followup_decks_present = True
                roles = {str(card.get("followup_chain_role", "")) for card in followup_cards}
                if not ({"opener", "standalone"} & roles):
                    errors.append(f"deck {deck_id} followup chain missing opener/standalone")
                    weapon_followup_chain_valid = False
                if roles and roles.issubset({"linker", "finisher"}):
                    errors.append(f"deck {deck_id} followup chain has no valid starting card")
                    weapon_followup_chain_valid = False
                if len([card for card in followup_cards if str(card.get("followup_trigger", "")) == "same_weapon_previous_card" and str(card.get("followup_chain_role", "")) in {"linker", "finisher"}]) > int(runtime_primitive_constraints.get("weapon_followup", {}).get("max_followup_links_per_deck", 999)):
                    errors.append(f"deck {deck_id} followup links exceed constraint")
                    weapon_followup_values_in_range = False
                for card in followup_cards:
                    trigger = str(card.get("followup_trigger", ""))
                    if trigger == "same_weapon_previous_card":
                        style = str(card.get("weapon_style", ""))
                        if style and not any(str(card_by_id.get(other_id, {}).get("weapon_style", "")) == style and other_id != str(card.get("card_id", "")) for other_id in card_ids):
                            errors.append(f"deck {deck_id} followup card {card.get('card_id', '')} lacks same-weapon predecessor")
                            weapon_followup_chain_valid = False

    for slot in battle_slots:
        deck_id = str(slot.get("deck_id", ""))
        reward_id = str(slot.get("reward_plan_id", ""))
        player_wujing_cap = slot.get("player_wujing_cap", None)
        if deck_id not in deck_by_id:
            errors.append(f"battle slot missing deck: {deck_id}")
        if reward_id not in reward_by_id:
            errors.append(f"battle slot missing reward: {reward_id}")
        for field in ["sequence_position", "encounter_tier", "encounter_kind", "target_power_min", "target_power_max", "reward_tier", "player_wujing_cap"]:
            if field not in slot:
                errors.append(f"battle slot missing field: {field}")
                if field == "player_wujing_cap":
                    player_wujing_cap_present = False
                    all_slots_have_player_wujing_cap = False
        slot_runtime_primitives = [str(item) for item in slot.get("runtime_primitives", [])]
        tier = str(slot.get("encounter_tier", ""))
        if martial_realm_7_declared and player_wujing_cap is not None and tier in martial_cap_by_tier:
            martial_cap_by_tier[tier].append(int(player_wujing_cap))
        if "opening_pressure" in slot_runtime_primitives:
            if not opening_pressure_declared:
                errors.append("battle slot declares opening_pressure but mechanic profile does not")
                opening_pressure_values_in_range = False
            opening_pressure_slots_count += 1
            opening_pressure = slot.get("opening_pressure", {})
            if not isinstance(opening_pressure, dict) or not opening_pressure:
                errors.append(f"battle slot {slot.get('battle_slot_id', '')} missing opening_pressure payload")
                opening_pressure_all_slots_covered = False
                opening_pressure_values_in_range = False
            else:
                constraints = runtime_primitive_constraints.get("opening_pressure", {})
                momentum_bonus = int(opening_pressure.get("enemy_start_momentum_bonus", 0))
                block_bonus = int(opening_pressure.get("enemy_start_block_bonus", 0))
                if momentum_bonus < int(constraints.get("enemy_start_momentum_bonus_min", 0)) or momentum_bonus > int(constraints.get("enemy_start_momentum_bonus_max", 0)):
                    errors.append(f"battle slot {slot.get('battle_slot_id', '')} opening_pressure momentum out of range: {momentum_bonus}")
                    opening_pressure_values_in_range = False
                if block_bonus < int(constraints.get("enemy_start_block_bonus_min", 0)) or block_bonus > int(constraints.get("enemy_start_block_bonus_max", 0)):
                    errors.append(f"battle slot {slot.get('battle_slot_id', '')} opening_pressure block out of range: {block_bonus}")
                    opening_pressure_values_in_range = False
        elif opening_pressure_declared:
            opening_pressure_all_slots_covered = False
            errors.append(f"battle slot {slot.get('battle_slot_id', '')} missing opening_pressure")
        if "weapon_followup" in slot_runtime_primitives:
            if not weapon_followup_declared:
                errors.append("battle slot declares weapon_followup but mechanic profile does not")
                weapon_followup_values_in_range = False
            followup_payload = slot.get("weapon_followup", {})
            if not isinstance(followup_payload, dict) or not bool(followup_payload.get("enabled", False)):
                errors.append(f"battle slot {slot.get('battle_slot_id', '')} missing weapon_followup payload")
                weapon_followup_all_slots_covered = False
                weapon_followup_chain_valid = False
            else:
                weapon_followup_all_slots_covered = weapon_followup_all_slots_covered and True
        elif weapon_followup_declared:
            weapon_followup_all_slots_covered = False
            errors.append(f"battle slot {slot.get('battle_slot_id', '')} missing weapon_followup")
        if "clue_pressure" in slot_runtime_primitives:
            clue_pressure_slot_count += 1
            clue_pressure_payload = slot.get("clue_pressure", {})
            if not clue_pressure_declared:
                errors.append("battle slot declares clue_pressure but mechanic profile does not")
                clue_pressure_effects_valid = False
            if not isinstance(clue_pressure_payload, dict) or not bool(clue_pressure_payload.get("enabled", False)):
                clue_pressure_all_slots_covered = False
                clue_pressure_values_in_range = False
                errors.append(f"battle slot {slot.get('battle_slot_id', '')} missing clue_pressure payload")
            else:
                clue_pressure_all_slots_covered = clue_pressure_all_slots_covered and True
                tags = [str(item) for item in clue_pressure_payload.get("clue_tags", [])]
                effect = str(clue_pressure_payload.get("pressure_effect", ""))
                value = int(clue_pressure_payload.get("pressure_value", 0))
                timing = str(clue_pressure_payload.get("trigger_timing", ""))
                if allowed_clue_tags and any(tag not in allowed_clue_tags for tag in tags):
                    clue_pressure_tags_valid = False
                    errors.append(f"battle slot {slot.get('battle_slot_id', '')} has invalid clue tag")
                else:
                    clue_pressure_tags_valid = clue_pressure_tags_valid and True
                if allowed_clue_effects and effect not in allowed_clue_effects:
                    clue_pressure_effects_valid = False
                    errors.append(f"battle slot {slot.get('battle_slot_id', '')} has invalid clue pressure effect")
                else:
                    clue_pressure_effects_valid = clue_pressure_effects_valid and True
                if allowed_clue_timings and timing not in allowed_clue_timings:
                    clue_pressure_values_in_range = False
                    errors.append(f"battle slot {slot.get('battle_slot_id', '')} has invalid clue timing")
                max_reduction = int(runtime_primitive_constraints.get("clue_pressure", {}).get("max_pressure_reduction_per_battle", 999))
                if value < 0 or value > max_reduction:
                    clue_pressure_values_in_range = False
                    errors.append(f"battle slot {slot.get('battle_slot_id', '')} clue pressure value out of range: {value}")
                if tier in clue_pressure_tier_values:
                    clue_pressure_tier_values[tier].append(value)
        elif clue_pressure_declared:
            clue_pressure_all_slots_covered = False
            clue_pressure_values_in_range = False
            errors.append(f"battle slot {slot.get('battle_slot_id', '')} missing clue_pressure")
        if martial_realm_7_declared:
            if player_wujing_cap is None:
                all_slots_have_player_wujing_cap = False
            if bool(slot.get("dual_weapon_enabled", False)):
                dual_weapon_slot_count += 1
            if dual_weapon_declared and tier == "boss" and not bool(slot.get("dual_weapon_enabled", False)):
                boss_slots_dual_weapon_enabled = False
                errors.append(f"boss slot {slot.get('battle_slot_id', '')} is not dual_weapon_enabled")
            if tier == "boss" and int(slot.get("player_wujing_cap", 0)) != 7:
                boss_slots_wujing_cap_7 = False
                errors.append(f"boss slot {slot.get('battle_slot_id', '')} player_wujing_cap is not 7")
        deck = deck_by_id.get(deck_id, {})
        for card_id in deck.get("card_ids", []):
            card = card_by_id.get(str(card_id), {})
            if not card or not is_realm_gated_card(card):
                continue
            if "required_wujing" not in card or "closing_form_tier" not in card:
                card_realm_metadata_present = False
                missing_realm_metadata_count += 1
                ref = build_realm_ref(slot, deck, card, "missing_realm_metadata")
                missing_realm_metadata_refs.append(ref)
                errors.append(f"card {card.get('card_id', '')} missing realm metadata in deck {deck_id}")
                deck_card_realm_eligibility_valid = False
                no_card_above_player_wujing_in_deck = False
                continue
            if player_wujing_cap is None:
                player_wujing_cap_present = False
                continue
            required_wujing = int(card.get("required_wujing", 1))
            closing_form_tier = int(card.get("closing_form_tier", 1))
            if required_wujing > int(player_wujing_cap) or closing_form_tier > int(player_wujing_cap):
                invalid_realm_card_count += 1
                closing_form_invalid = closing_form_tier > int(player_wujing_cap)
                reason = "required_wujing_above_player_cap" if required_wujing > int(player_wujing_cap) else "closing_form_tier_above_player_cap"
                ref = build_realm_ref(slot, deck, card, reason)
                invalid_realm_card_refs.append(ref)
                errors.append(f"card {card.get('card_id', '')} exceeds player_wujing_cap in deck {deck_id}")
                deck_card_realm_eligibility_valid = False
                no_card_above_player_wujing_in_deck = False
                if closing_form_invalid:
                    no_card_closing_form_above_player_wujing_in_deck = False
            if martial_realm_7_declared and int(card.get("required_wujing", 1)) >= 7 and int(player_wujing_cap) < 7:
                seven_realm_cards_only_in_wujing_7_slots = False
                errors.append(f"seven realm card {card.get('card_id', '')} appears below wujing 7 in deck {deck_id}")

    for reward in rewards:
        if not str(reward.get("reward_plan_id", "")).strip():
            errors.append("reward plan missing reward_plan_id")
        if not str(reward.get("reward_tier", "")).strip():
            errors.append(f"reward {reward.get('reward_plan_id', '')} missing reward_tier")

    mechanic_profile_valid = not check_profile_shape(mechanic_profile, ["mechanic_profile_id", "allowed_runtime_effects", "allowed_design_effects", "deck_constraints", "runtime_support_level"], errors, "mechanic_profile")
    content_recipe_valid = not check_profile_shape(content_recipe, ["content_recipe_id", "mechanic_profile_id", "content_pack_id", "target_sequence_id", "replacement_mode", "balance_policy"], errors, "content_recipe")
    formal_sequence_inventory_valid = not check_inventory_shape(inventory, errors)
    full_sequence_mapping_valid = not check_mapping_shape(mappings, errors)
    card_pool_matches_profile = not any(msg.startswith("card ") for msg in errors)
    enemy_deck_pool_matches_profile = not any(msg.startswith("deck ") for msg in errors)
    battle_slots_match_profile = not any(msg.startswith("battle slot") for msg in errors)
    rewards_match_profile = not any(msg.startswith("reward ") for msg in errors) and not any("reward plan" in msg for msg in errors)
    no_fallback_only_battle = full_sequence_coverage_complete

    sequence_balance_curve_ready = bool(balance_summary.get("sequence_balance_curve_ready", False))
    elite_decks_stronger_than_normal = bool(balance_summary.get("elite_decks_stronger_than_normal", False))
    boss_decks_stronger_than_elite = bool(balance_summary.get("boss_decks_stronger_than_elite", False))
    sequence_balance_pass = bool(balance_summary.get("sequence_balance_pass", False))
    if not sequence_balance_curve_ready:
        errors.append("sequence balance curve not ready")
    if not elite_decks_stronger_than_normal:
        errors.append("elite decks are not stronger than normal decks")
    if not boss_decks_stronger_than_elite:
        errors.append("boss decks are not stronger than elite or late decks")
    if float(balance_summary.get("late_avg_power_over_early", 0)) <= 0:
        errors.append("late average power does not exceed early average power")

    runtime_effects_supported = not unsupported_card_effects and not unsupported_runtime_effect_whitelist
    unsupported_design_effects_blocked = not unsupported_design_effects
    not_runtime_playable = not runtime_effects_supported or not unsupported_design_effects_blocked
    rebuild_policy_compatible = runtime_effects_supported and unsupported_design_effects_blocked and not not_runtime_playable
    llm_candidate_import_detected = imported_candidate_summary is not None
    llm_candidate_import_ready = bool(imported_candidate_summary.get("import_ready_for_validation", False)) if imported_candidate_summary else False
    invalid_candidate_rejected = (
        int(imported_candidate_summary.get("rejected_card_candidate_count", 0)) > 0
        or int(imported_candidate_summary.get("rejected_deck_candidate_count", 0)) > 0
    ) if imported_candidate_summary else False
    valid_candidate_exportable = llm_candidate_import_detected and llm_candidate_import_ready
    llm_full_sequence_coverage_complete = llm_candidate_import_detected and full_sequence_coverage_complete
    opening_pressure_curve_ready = bool(balance_summary.get("opening_pressure_curve_ready", not opening_pressure_declared))
    if weapon_followup_declared and not weapon_followup_curve_ready:
        errors.append("weapon_followup curve not ready")
    if clue_pressure_declared:
        clue_pressure_curve_ready = (
            clue_pressure_slot_count == total_count
            and all(clue_pressure_tier_values[tier] for tier in ["early", "mid", "late", "boss"])
            and average_ints(clue_pressure_tier_values["early"]) <= average_ints(clue_pressure_tier_values["mid"]) <= average_ints(clue_pressure_tier_values["late"]) <= average_ints(clue_pressure_tier_values["boss"])
        )
        if not clue_pressure_curve_ready:
            errors.append("clue_pressure curve not ready")
    if martial_realm_7_declared:
        martial_realm_curve_ready = (
            all(martial_cap_by_tier[tier] for tier in ["early", "mid", "late", "boss"])
            and max(martial_cap_by_tier["early"]) <= min(martial_cap_by_tier["mid"]) <= min(martial_cap_by_tier["late"]) <= min(martial_cap_by_tier["boss"])
        )
        if not martial_realm_curve_ready:
            errors.append("martial realm curve not ready")
    if dual_weapon_declared:
        dual_weapon_ratio_valid = dual_weapon_ratio_valid and dual_weapon_slot_count >= max(1, int(total_count * 0.3))
        if not dual_weapon_ratio_valid:
            errors.append("dual_weapon ratio is below minimum threshold")
    runtime_primitive_export_allowed = runtime_primitives_supported and (
        (not opening_pressure_declared)
        or (
            opening_pressure_all_slots_covered
            and opening_pressure_values_in_range
            and opening_pressure_curve_ready
            and opening_pressure_slots_count == total_count
        )
    )
    if weapon_followup_declared:
        weapon_followup_runtime_export_allowed = (
            runtime_primitives_supported
            and weapon_followup_cards_present
            and weapon_followup_decks_present
            and weapon_followup_all_slots_covered
            and weapon_followup_chain_valid
            and weapon_followup_values_in_range
            and weapon_followup_curve_ready
        )
        runtime_primitive_export_allowed = runtime_primitive_export_allowed and weapon_followup_runtime_export_allowed
        weapon_followup_playable = weapon_followup_runtime_export_allowed
    if clue_pressure_declared:
        clue_pressure_runtime_export_allowed = (
            runtime_primitives_supported
            and clue_pressure_all_slots_covered
            and clue_pressure_tags_valid
            and clue_pressure_effects_valid
            and clue_pressure_values_in_range
            and clue_pressure_curve_ready
            and clue_pressure_slot_count == total_count
        )
        runtime_primitive_export_allowed = runtime_primitive_export_allowed and clue_pressure_runtime_export_allowed
    if martial_realm_7_declared:
        martial_realm_7_playable = (
            runtime_primitives_supported
            and max_wujing_is_7
            and max_closing_form_tier_is_7
            and all_cards_have_required_wujing
            and all_cards_have_closing_form_tier
            and all_cards_required_wujing_in_range
            and all_cards_closing_form_tier_in_range
            and all_slots_have_player_wujing_cap
            and no_card_above_player_wujing_in_deck
            and no_card_closing_form_above_player_wujing_in_deck
            and seven_realm_cards_only_in_wujing_7_slots
            and martial_realm_curve_ready
        )
        runtime_primitive_export_allowed = runtime_primitive_export_allowed and martial_realm_7_playable
    if dual_weapon_declared:
        dual_weapon_playable = (
            runtime_primitives_supported
            and all_decks_have_weapon_loadout
            and dual_weapon_slots_present
            and dual_weapon_ratio_valid
            and boss_slots_dual_weapon_enabled
            and weapon_loadout_card_compatibility_valid
            and dual_weapon_generic_ratio_valid
        )
        dual_weapon_runtime_export_allowed = dual_weapon_playable
        runtime_primitive_export_allowed = runtime_primitive_export_allowed and dual_weapon_runtime_export_allowed
    runtime_primitive_playable = runtime_primitive_export_allowed
    runtime_export_allowed = (
        rebuild_policy_compatible
        and mechanic_profile_valid
        and content_recipe_valid
        and formal_sequence_inventory_valid
        and full_sequence_mapping_valid
        and card_pool_matches_profile
        and enemy_deck_pool_matches_profile
        and battle_slots_match_profile
        and rewards_match_profile
        and no_fallback_only_battle
        and full_sequence_coverage_complete
        and sequence_balance_pass
        and all_decks_within_power_range
        and runtime_primitive_export_allowed
        and not errors
    )
    llm_content_ready_for_runtime_export = (
        llm_candidate_import_detected
        and llm_candidate_import_ready
        and llm_full_sequence_coverage_complete
        and sequence_balance_pass
        and runtime_export_allowed
    ) if llm_candidate_import_detected else False
    rebuild_uses_snapshot = bool(content_pack_summary.get("rebuild_uses_snapshot", False))
    snapshot_source_path = str(content_pack_summary.get("snapshot_source_path", ""))
    flagged_deck_count = int(content_pack_summary.get("flagged_deck_count", 0))
    built_from_llm_candidates = bool(content_pack_summary.get("built_from_llm_candidates", False) or content_pack_summary.get("llm_candidate_source", False))
    accepted_candidate_count = int(content_pack_summary.get("accepted_candidate_count", 0))
    rejected_candidate_count = int(content_pack_summary.get("rejected_candidate_count", 0))
    deterministic_fill_used = bool(content_pack_summary.get("deterministic_fill_used", False))
    candidate_source_trace_ready = bool(content_pack_summary.get("candidate_source_trace_ready", False) or (content_pack_summary.get("candidate_import_report_path") and content_pack_summary.get("candidate_diff_report_path")))
    ai_pack_ready_for_review = built_from_llm_candidates and candidate_source_trace_ready
    rebuild_uses_real_telemetry = bool(content_pack_summary.get("rebuild_uses_real_telemetry", False))
    real_telemetry_snapshot_path = str(content_pack_summary.get("real_telemetry_snapshot_path", ""))
    real_telemetry_rebuild_valid = (not rebuild_uses_real_telemetry) or bool(real_telemetry_snapshot_path)
    if rebuild_uses_real_telemetry and not real_telemetry_rebuild_valid:
        errors.append("real telemetry rebuild metadata missing")
        ready_for_runtime_export = False
    snapshot_rebuild_valid = (
        (not rebuild_uses_snapshot)
        or (
            bool(snapshot_source_path)
            and bool(balance_summary.get("snapshot_rebuild_pass", False))
        )
    )
    if not card_eligibility_rules_declared:
        errors.append("card eligibility rules are not declared")
    if not player_wujing_cap_present:
        errors.append("player_wujing_cap is missing on battle slots")
    if not card_realm_metadata_present:
        errors.append("card realm metadata is missing")
    runtime_export_allowed = (
        runtime_export_allowed
        and card_eligibility_rules_declared
        and player_wujing_cap_present
        and card_realm_metadata_present
        and deck_card_realm_eligibility_valid
        and no_card_above_player_wujing_in_deck
        and invalid_realm_card_count == 0
        and missing_realm_metadata_count == 0
    )
    ready_for_runtime_export = runtime_export_allowed
    if llm_candidate_import_detected and not llm_candidate_import_ready:
        errors.append("llm candidate import summary is not ready for validation")
        ready_for_runtime_export = False
        runtime_export_allowed = False
    if llm_candidate_import_detected:
        rejected_ids = set(str(item) for item in imported_candidate_summary.get("rejected_card_candidate_ids", []))
        generated_candidate_ids = {str(card.get("candidate_id", "")) for card in card_pool if str(card.get("candidate_id", "")).strip()}
        leaked_rejected_ids = sorted(rejected_ids.intersection(generated_candidate_ids))
        if leaked_rejected_ids:
            errors.append(f"rejected llm card candidates leaked into generated outputs: {leaked_rejected_ids}")
            ready_for_runtime_export = False
            runtime_export_allowed = False
    if not runtime_primitives_supported:
        errors.append("runtime primitives are not supported by runtime_support_level")
    if opening_pressure_declared and not opening_pressure_curve_ready:
        errors.append("opening_pressure curve not ready")
    if weapon_followup_declared and not weapon_followup_cards_present:
        errors.append("weapon_followup cards are missing")
    if weapon_followup_declared and not weapon_followup_decks_present:
        errors.append("weapon_followup decks are missing")
    if martial_realm_7_declared and not max_wujing_is_7:
        errors.append("max_wujing is not 7")
    if martial_realm_7_declared and not max_closing_form_tier_is_7:
        errors.append("max_closing_form_tier is not 7")

    report = {
        "mechanic_profile_valid": mechanic_profile_valid,
        "content_recipe_valid": content_recipe_valid,
        "formal_sequence_inventory_valid": formal_sequence_inventory_valid,
        "full_sequence_mapping_valid": full_sequence_mapping_valid,
        "formal_encounter_coverage_count": coverage_count,
        "formal_encounter_total_count": total_count,
        "full_sequence_coverage_complete": full_sequence_coverage_complete,
        "card_pool_matches_profile": card_pool_matches_profile,
        "enemy_deck_pool_matches_profile": enemy_deck_pool_matches_profile,
        "battle_slots_match_profile": battle_slots_match_profile,
        "rewards_match_profile": rewards_match_profile,
        "no_fallback_only_battle": no_fallback_only_battle,
        "sequence_balance_curve_ready": sequence_balance_curve_ready,
        "all_decks_within_power_range": all_decks_within_power_range,
        "elite_decks_stronger_than_normal": elite_decks_stronger_than_normal,
        "boss_decks_stronger_than_elite": boss_decks_stronger_than_elite,
        "sequence_balance_pass": sequence_balance_pass,
        "runtime_effects_supported": runtime_effects_supported,
        "runtime_primitives_supported": runtime_primitives_supported,
        "opening_pressure_declared": opening_pressure_declared,
        "opening_pressure_slots_count": opening_pressure_slots_count,
        "opening_pressure_all_slots_covered": opening_pressure_all_slots_covered,
        "opening_pressure_values_in_range": opening_pressure_values_in_range,
        "opening_pressure_curve_ready": opening_pressure_curve_ready,
        "weapon_followup_declared": weapon_followup_declared,
        "weapon_followup_cards_present": weapon_followup_cards_present,
        "weapon_followup_decks_present": weapon_followup_decks_present,
        "weapon_followup_all_slots_covered": weapon_followup_all_slots_covered,
        "weapon_followup_chain_valid": weapon_followup_chain_valid,
        "weapon_followup_values_in_range": weapon_followup_values_in_range,
        "weapon_followup_curve_ready": weapon_followup_curve_ready,
        "weapon_followup_runtime_export_allowed": weapon_followup_runtime_export_allowed,
        "weapon_followup_playable": weapon_followup_playable,
        "clue_pressure_declared": clue_pressure_declared,
        "clue_pressure_all_slots_covered": clue_pressure_all_slots_covered,
        "clue_pressure_tags_valid": clue_pressure_tags_valid,
        "clue_pressure_effects_valid": clue_pressure_effects_valid,
        "clue_pressure_values_in_range": clue_pressure_values_in_range,
        "clue_pressure_curve_ready": clue_pressure_curve_ready,
        "clue_pressure_runtime_export_allowed": clue_pressure_runtime_export_allowed,
        "martial_realm_7_declared": martial_realm_7_declared,
        "dual_weapon_declared": dual_weapon_declared,
        "max_wujing_is_7": max_wujing_is_7,
        "max_closing_form_tier_is_7": max_closing_form_tier_is_7,
        "all_cards_have_required_wujing": all_cards_have_required_wujing,
        "all_cards_have_closing_form_tier": all_cards_have_closing_form_tier,
        "all_cards_required_wujing_in_range": all_cards_required_wujing_in_range,
        "all_cards_closing_form_tier_in_range": all_cards_closing_form_tier_in_range,
        "all_slots_have_player_wujing_cap": all_slots_have_player_wujing_cap,
        "all_decks_have_weapon_loadout": all_decks_have_weapon_loadout,
        "dual_weapon_slots_present": dual_weapon_slots_present,
        "dual_weapon_ratio_valid": dual_weapon_ratio_valid,
        "boss_slots_dual_weapon_enabled": boss_slots_dual_weapon_enabled,
        "boss_slots_wujing_cap_7": boss_slots_wujing_cap_7,
        "no_card_closing_form_above_player_wujing_in_deck": no_card_closing_form_above_player_wujing_in_deck,
        "seven_realm_cards_only_in_wujing_7_slots": seven_realm_cards_only_in_wujing_7_slots,
        "weapon_loadout_card_compatibility_valid": weapon_loadout_card_compatibility_valid,
        "dual_weapon_generic_ratio_valid": dual_weapon_generic_ratio_valid,
        "martial_realm_curve_ready": martial_realm_curve_ready,
        "dual_weapon_runtime_export_allowed": dual_weapon_runtime_export_allowed,
        "max_wujing": int(mechanic_profile.get("max_wujing", 0)),
        "max_closing_form_tier": int(mechanic_profile.get("max_closing_form_tier", 0)),
        "dual_weapon_slot_count": dual_weapon_slot_count,
        "dual_weapon_deck_count": dual_weapon_deck_count,
        "seven_realm_card_count": seven_realm_card_count,
        "invalid_weapon_loadout_card_count": invalid_weapon_loadout_card_count,
        "martial_realm_7_playable": martial_realm_7_playable,
        "dual_weapon_playable": dual_weapon_playable,
        "runtime_primitive_export_allowed": runtime_primitive_export_allowed,
        "runtime_primitive_playable": runtime_primitive_playable,
        "unsupported_design_effects_blocked": unsupported_design_effects_blocked,
        "rebuild_policy_compatible": rebuild_policy_compatible,
        "not_runtime_playable": not_runtime_playable,
        "runtime_export_allowed": runtime_export_allowed,
        "llm_candidate_import_detected": llm_candidate_import_detected,
        "llm_candidate_import_ready": llm_candidate_import_ready,
        "invalid_candidate_rejected": invalid_candidate_rejected,
        "valid_candidate_exportable": valid_candidate_exportable,
        "llm_full_sequence_coverage_complete": llm_full_sequence_coverage_complete,
        "llm_content_ready_for_runtime_export": llm_content_ready_for_runtime_export,
        "card_eligibility_rules_declared": card_eligibility_rules_declared,
        "player_wujing_cap_present": player_wujing_cap_present,
        "card_realm_metadata_present": card_realm_metadata_present,
        "deck_card_realm_eligibility_valid": deck_card_realm_eligibility_valid,
        "no_card_above_player_wujing_in_deck": no_card_above_player_wujing_in_deck,
        "invalid_realm_card_count": invalid_realm_card_count,
        "invalid_realm_card_refs": invalid_realm_card_refs,
        "missing_realm_metadata_count": missing_realm_metadata_count,
        "missing_realm_metadata_refs": missing_realm_metadata_refs,
        "rebuild_uses_snapshot": rebuild_uses_snapshot,
        "snapshot_source_path": snapshot_source_path,
        "snapshot_rebuild_valid": snapshot_rebuild_valid,
        "built_from_llm_candidates": built_from_llm_candidates,
        "accepted_candidate_count": accepted_candidate_count,
        "rejected_candidate_count": rejected_candidate_count,
        "deterministic_fill_used": deterministic_fill_used,
        "candidate_source_trace_ready": bool(candidate_source_trace_ready),
        "ai_pack_ready_for_review": bool(ai_pack_ready_for_review),
        "rebuild_uses_real_telemetry": rebuild_uses_real_telemetry,
        "real_telemetry_snapshot_path": real_telemetry_snapshot_path,
        "real_telemetry_rebuild_valid": real_telemetry_rebuild_valid,
        "flagged_deck_count": flagged_deck_count,
        "ready_for_runtime_export": ready_for_runtime_export,
        "errors": errors,
        "warnings": warnings,
    }
    write_json(generated_dir / "validation_report.json", report)
    write_markdown_report(generated_dir / "validation_report.md", report)
    print(f"validated content pack: {profile_id}")
    return 0 if ready_for_runtime_export else 1


def read_json(path: Path) -> Any:
    return json.loads(path.read_text(encoding="utf-8"))


def write_json(path: Path, payload: Any) -> None:
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def write_markdown_report(path: Path, report: dict[str, Any]) -> None:
    lines = [
        "# AIGC Battle v5 验证报告",
        "",
        f"- full_sequence_coverage_complete: {str(report['full_sequence_coverage_complete']).lower()}",
        f"- sequence_balance_pass: {str(report['sequence_balance_pass']).lower()}",
        f"- runtime_effects_supported: {str(report['runtime_effects_supported']).lower()}",
        f"- unsupported_design_effects_blocked: {str(report['unsupported_design_effects_blocked']).lower()}",
        f"- rebuild_policy_compatible: {str(report['rebuild_policy_compatible']).lower()}",
        f"- not_runtime_playable: {str(report['not_runtime_playable']).lower()}",
        f"- runtime_export_allowed: {str(report['runtime_export_allowed']).lower()}",
        f"- ready_for_runtime_export: {str(report['ready_for_runtime_export']).lower()}",
        f"- weapon_followup_declared: {str(report.get('weapon_followup_declared', False)).lower()}",
        f"- weapon_followup_chain_valid: {str(report.get('weapon_followup_chain_valid', True)).lower()}",
        f"- weapon_followup_runtime_export_allowed: {str(report.get('weapon_followup_runtime_export_allowed', True)).lower()}",
        "",
        "## 错误",
    ]
    if report["errors"]:
        lines.extend(f"- {item}" for item in report["errors"])
    else:
        lines.append("- 无")
    lines.append("")
    lines.append("## 警告")
    if report["warnings"]:
        lines.extend(f"- {item}" for item in report["warnings"])
    else:
        lines.append("- 无")
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def average_ints(values: list[int]) -> float:
    if not values:
        return 0.0
    return sum(values) / float(len(values))


def is_realm_gated_card(card: dict[str, Any]) -> bool:
    card_type = str(card.get("card_type", "")).lower()
    tags = {str(tag).lower() for tag in card.get("tags", [])}
    if card_type == "technique":
        return True
    if {"technique", "closing_form", "招式", "收式"} & tags:
        return True
    return False


def build_realm_ref(slot: dict[str, Any], deck: dict[str, Any], card: dict[str, Any], reason: str) -> dict[str, Any]:
    return {
        "battle_slot_id": str(slot.get("battle_slot_id", "")),
        "deck_id": str(deck.get("deck_id", "")),
        "card_id": str(card.get("card_id", "")),
        "card_name": str(card.get("name", "")),
        "player_wujing_cap": int(slot.get("player_wujing_cap", 0)),
        "card_required_wujing": card.get("required_wujing"),
        "card_closing_form_tier": card.get("closing_form_tier"),
        "reason": reason,
    }


def check_profile_object(
    label: str,
    rows: list[dict[str, Any]],
    expected_profile_id: str,
    expected_content_pack_id: str,
    errors: list[str],
) -> None:
    for row in rows:
        if str(row.get("mechanic_profile_id", "")) != expected_profile_id:
            errors.append(f"{label} has mismatched mechanic_profile_id")
        if str(row.get("content_pack_id", "")) != expected_content_pack_id:
            errors.append(f"{label} has mismatched content_pack_id")


def check_profile_shape(payload: dict[str, Any], fields: list[str], errors: list[str], label: str) -> bool:
    missing = [field for field in fields if field not in payload]
    if missing:
        errors.append(f"{label} missing fields: {missing}")
    return bool(missing)


def check_inventory_shape(inventory: list[dict[str, Any]], errors: list[str]) -> bool:
    missing_shape = False
    for item in inventory:
        for field in [
            "target_sequence_id",
            "formal_encounter_id",
            "formal_battle_id",
            "source_file",
            "node_id",
            "sequence_position",
            "encounter_tier",
            "encounter_kind",
            "target_power_min",
            "target_power_max",
            "reward_tier",
        ]:
            if field not in item:
                errors.append(f"inventory item missing field: {field}")
                missing_shape = True
    return missing_shape


def check_mapping_shape(mappings: list[dict[str, Any]], errors: list[str]) -> bool:
    missing_shape = False
    for item in mappings:
        for field in [
            "formal_encounter_id",
            "generated_battle_slot_id",
            "generated_deck_id",
            "reward_plan_id",
            "replacement_mode",
            "sequence_position",
            "encounter_tier",
            "encounter_kind",
            "target_power_min",
            "target_power_max",
            "reward_tier",
        ]:
            if field not in item:
                errors.append(f"mapping item missing field: {field}")
                missing_shape = True
    return missing_shape


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
