#!/usr/bin/env python3
from __future__ import annotations

import json
import sys
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[2]
MECHANICS_DIR = ROOT / "data" / "aigc_battle" / "mechanics"
GENERATED_DIR = ROOT / "data" / "aigc_battle" / "generated"
RUNTIME_EFFECT_SUPPORT = {
    "godot_formal_sequence_v1": {"damage", "gain_block", "gain_momentum", "break_momentum"},
}
RUNTIME_PRIMITIVE_SUPPORT = {
    "godot_formal_sequence_v1": {"opening_pressure"},
}


def main(argv: list[str]) -> int:
    if len(argv) != 3:
        print("usage: python tools/aigc_battle/diff_mechanic_profiles.py <from_profile> <to_profile>", file=sys.stderr)
        return 1
    from_dir = resolve_profile_dir(argv[1])
    to_dir = resolve_profile_dir(argv[2])
    from_profile = read_json(from_dir / "mechanic_profile.json")
    from_recipe = read_json(from_dir / "content_recipe.json")
    to_profile = read_json(to_dir / "mechanic_profile.json")
    to_recipe = read_json(to_dir / "content_recipe.json")

    report = diff_profiles(from_profile, from_recipe, to_profile, to_recipe)
    GENERATED_DIR.mkdir(parents=True, exist_ok=True)
    write_json(GENERATED_DIR / "profile_diff_report.json", report)
    write_markdown(GENERATED_DIR / "profile_diff_report.md", report)
    print("profile diff complete")
    return 0


def resolve_profile_dir(profile_input: str) -> Path:
    candidate = MECHANICS_DIR / profile_input
    if candidate.exists():
        return candidate
    path_candidate = Path(profile_input)
    if path_candidate.exists():
        return path_candidate
    raise SystemExit(f"profile path not found: {profile_input}")


def diff_profiles(
    from_profile: dict[str, Any],
    from_recipe: dict[str, Any],
    to_profile: dict[str, Any],
    to_recipe: dict[str, Any],
) -> dict[str, Any]:
    from_runtime_level = str(from_profile.get("runtime_support_level", ""))
    to_runtime_level = str(to_profile.get("runtime_support_level", ""))
    to_runtime_supported = set(RUNTIME_EFFECT_SUPPORT.get(to_runtime_level, set()))
    to_runtime_supported_primitives = set(RUNTIME_PRIMITIVE_SUPPORT.get(to_runtime_level, set()))

    resource_changes = diff_set_field(from_profile.get("resources", []), to_profile.get("resources", []))
    runtime_effect_changes = diff_set_field(from_profile.get("allowed_runtime_effects", []), to_profile.get("allowed_runtime_effects", []))
    runtime_effect_changes["unsupported_by_runtime_level"] = sorted(set(to_profile.get("allowed_runtime_effects", [])) - to_runtime_supported)
    design_effect_changes = diff_set_field(from_profile.get("allowed_design_effects", []), to_profile.get("allowed_design_effects", []))
    design_effect_changes["unsupported_by_runtime"] = sorted(set(to_profile.get("allowed_design_effects", [])) - set(to_profile.get("allowed_runtime_effects", [])))
    card_type_changes = diff_set_field(from_profile.get("card_types", []), to_profile.get("card_types", []))
    weapon_style_changes = diff_set_field(from_profile.get("weapon_styles", []), to_profile.get("weapon_styles", []))
    card_constraint_changes = diff_mapping(from_profile.get("card_constraints", {}), to_profile.get("card_constraints", {}))
    deck_constraint_changes = diff_mapping(from_profile.get("deck_constraints", {}), to_profile.get("deck_constraints", {}))
    runtime_primitive_changes = diff_set_field(from_profile.get("runtime_primitives", []), to_profile.get("runtime_primitives", []))
    runtime_primitive_changes["unsupported_by_runtime_level"] = sorted(set(to_profile.get("runtime_primitives", [])) - to_runtime_supported_primitives)
    runtime_primitive_playable = not runtime_primitive_changes["unsupported_by_runtime_level"]
    power_model_changed = from_profile.get("power_model", {}) != to_profile.get("power_model", {})
    balance_policy_changed = from_recipe.get("balance_policy", {}) != to_recipe.get("balance_policy", {})
    reward_policy_changed = from_recipe.get("reward_generation_policy", {}) != to_recipe.get("reward_generation_policy", {})
    deck_policy_changed = from_recipe.get("deck_generation_policy", {}) != to_recipe.get("deck_generation_policy", {})
    card_policy_changed = from_recipe.get("card_generation_policy", {}) != to_recipe.get("card_generation_policy", {})
    runtime_support_level_changed = from_runtime_level != to_runtime_level
    same_target_sequence_id = str(from_recipe.get("target_sequence_id", "")) == str(to_recipe.get("target_sequence_id", ""))
    same_replacement_mode = str(from_recipe.get("replacement_mode", "")) == str(to_recipe.get("replacement_mode", ""))
    target_sequence_changed = not same_target_sequence_id
    replacement_mode_changed = not same_replacement_mode

    reason_codes: list[str] = []
    not_runtime_playable = False
    change_type = "no_change"
    recommended_action = "no_rebuild_required"
    full_sequence_rebuild_required = False

    if design_effect_changes["unsupported_by_runtime"]:
        not_runtime_playable = True
        reason_codes.append("unsupported_design_effect_present")
    if runtime_effect_changes["unsupported_by_runtime_level"]:
        not_runtime_playable = True
        reason_codes.append("unsupported_runtime_effect_present")
    if runtime_primitive_changes["unsupported_by_runtime_level"]:
        not_runtime_playable = True
        reason_codes.append("unsupported_runtime_primitive_present")
    if to_runtime_level not in RUNTIME_EFFECT_SUPPORT:
        not_runtime_playable = True
        reason_codes.append("unknown_runtime_support_level")

    if not_runtime_playable:
        change_type = "not_runtime_playable"
        recommended_action = "block_runtime_export_until_runtime_support_exists"
    else:
        removed_resources = bool(resource_changes["removed"])
        removed_runtime_effects = bool(runtime_effect_changes["removed"])
        added_runtime_effects = bool(runtime_effect_changes["added"])
        added_runtime_primitives = bool(runtime_primitive_changes["added"])
        added_card_types = bool(card_type_changes["added"])
        added_weapon_styles = bool(weapon_style_changes["added"])
        breaking_card_constraints = any(key in {"min_cost", "max_cost"} for key in card_constraint_changes["changed_keys"])
        breaking_deck_constraints = any(key in {"min_deck_size", "max_deck_size", "max_same_card"} for key in deck_constraint_changes["changed_keys"])
        structural_sequence_change = target_sequence_changed or replacement_mode_changed

        if structural_sequence_change or removed_resources or removed_runtime_effects or breaking_card_constraints or breaking_deck_constraints:
            change_type = "full_sequence_regeneration"
            recommended_action = "rebuild_full_sequence_content_pack"
            full_sequence_rebuild_required = True
            if structural_sequence_change:
                reason_codes.append("sequence_scope_changed")
            if removed_resources:
                reason_codes.append("resource_removed")
            if removed_runtime_effects:
                reason_codes.append("runtime_effect_removed")
            if breaking_card_constraints or breaking_deck_constraints:
                reason_codes.append("constraint_breaking_change")
        elif added_runtime_effects or added_runtime_primitives or added_card_types or added_weapon_styles or bool(resource_changes["added"]):
            change_type = "partial_regeneration"
            recommended_action = "regenerate_cards_and_decks_then_validate_full_sequence"
            reason_codes.append("content_surface_added")
        elif any(
            [
                power_model_changed,
                balance_policy_changed,
                reward_policy_changed,
                deck_policy_changed,
                card_policy_changed,
                bool(card_constraint_changes["changed_keys"]),
                bool(deck_constraint_changes["changed_keys"]),
                runtime_support_level_changed,
            ]
        ):
            change_type = "value_rebalance"
            recommended_action = "rebuild_full_sequence_with_existing_runtime_effects"
            reason_codes.append("numeric_or_policy_rebalance")
        else:
            reason_codes.append("no_changes_detected")

    report = {
        "from_profile_id": str(from_profile.get("mechanic_profile_id", "")),
        "to_profile_id": str(to_profile.get("mechanic_profile_id", "")),
        "same_target_sequence_id": same_target_sequence_id,
        "same_replacement_mode": same_replacement_mode,
        "resource_changes": resource_changes,
        "runtime_effect_changes": runtime_effect_changes,
        "design_effect_changes": design_effect_changes,
        "card_type_changes": card_type_changes,
        "weapon_style_changes": weapon_style_changes,
        "card_constraint_changes": card_constraint_changes,
        "deck_constraint_changes": deck_constraint_changes,
        "runtime_primitive_changes": runtime_primitive_changes,
        "runtime_primitive_playable": runtime_primitive_playable,
        "power_model_changed": power_model_changed,
        "balance_policy_changed": balance_policy_changed,
        "reward_policy_changed": reward_policy_changed,
        "runtime_support_level_changed": runtime_support_level_changed,
        "target_sequence_changed": target_sequence_changed,
        "change_type": change_type,
        "recommended_action": recommended_action,
        "full_sequence_rebuild_required": full_sequence_rebuild_required,
        "not_runtime_playable": not_runtime_playable,
        "reason_codes": reason_codes,
    }
    return report


def diff_set_field(from_values: Any, to_values: Any) -> dict[str, Any]:
    from_set = {str(item) for item in from_values}
    to_set = {str(item) for item in to_values}
    return {
        "added": sorted(to_set - from_set),
        "removed": sorted(from_set - to_set),
        "changed": sorted(from_set ^ to_set),
    }


def diff_mapping(from_map: dict[str, Any], to_map: dict[str, Any]) -> dict[str, Any]:
    keys = sorted(set(from_map.keys()) | set(to_map.keys()))
    changed = {}
    for key in keys:
        if from_map.get(key) != to_map.get(key):
            changed[key] = {"from": from_map.get(key), "to": to_map.get(key)}
    return {
        "changed_keys": sorted(changed.keys()),
        "changes": changed,
    }


def read_json(path: Path) -> Any:
    return json.loads(path.read_text(encoding="utf-8"))


def write_json(path: Path, payload: Any) -> None:
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def write_markdown(path: Path, report: dict[str, Any]) -> None:
    lines = [
        "# AIGC Battle v5 Profile Diff",
        "",
        f"- from_profile_id: {report['from_profile_id']}",
        f"- to_profile_id: {report['to_profile_id']}",
        f"- same_target_sequence_id: {str(report['same_target_sequence_id']).lower()}",
        f"- same_replacement_mode: {str(report['same_replacement_mode']).lower()}",
        f"- power_model_changed: {str(report['power_model_changed']).lower()}",
        f"- balance_policy_changed: {str(report['balance_policy_changed']).lower()}",
        f"- change_type: {report['change_type']}",
        f"- recommended_action: {report['recommended_action']}",
        f"- not_runtime_playable: {str(report['not_runtime_playable']).lower()}",
        f"- reason_codes: {report['reason_codes']}",
    ]
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
