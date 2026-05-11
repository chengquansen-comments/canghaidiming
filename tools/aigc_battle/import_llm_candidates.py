#!/usr/bin/env python3
from __future__ import annotations

import argparse
import importlib.util
import json
import sys
from collections import Counter, defaultdict
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[2]
MECHANICS_DIR = ROOT / "data" / "aigc_battle" / "mechanics"
GENERATED_DIR = ROOT / "data" / "aigc_battle" / "generated"
CANDIDATE_DIR = ROOT / "data" / "aigc_battle" / "llm_candidates"
BUILD_SCRIPT_PATH = ROOT / "tools" / "aigc_battle" / "build_content_for_profile.py"

builder_spec = importlib.util.spec_from_file_location("aigc_build_module", BUILD_SCRIPT_PATH)
builder = importlib.util.module_from_spec(builder_spec)
assert builder_spec and builder_spec.loader
builder_spec.loader.exec_module(builder)


def main(argv: list[str]) -> int:
    args = parse_args(argv)
    profile_id = args.profile_id
    mechanic_profile = read_json(MECHANICS_DIR / profile_id / "mechanic_profile.json")
    content_recipe = read_json(MECHANICS_DIR / profile_id / "content_recipe.json")
    candidate_import = content_recipe.get("candidate_import", {})
    if not candidate_import.get("enabled", False):
        raise SystemExit("candidate import is not enabled for this profile")

    source_dir = ROOT / str(candidate_import.get("candidate_source_dir", ""))
    cards_path = Path(args.cards) if args.cards else source_dir / "llm_card_candidates.valid.jsonl"
    decks_path = Path(args.decks) if args.decks else source_dir / "llm_deck_candidates.valid.jsonl"
    if not cards_path.is_absolute():
        cards_path = ROOT / cards_path
    if not decks_path.is_absolute():
        decks_path = ROOT / decks_path

    story_encounters = builder.index_rows(builder.read_tsv(builder.STORY_ENCOUNTERS_PATH), "encounter_id")
    inventory = builder.build_formal_sequence_inventory(content_recipe, story_encounters)
    if not inventory:
        raise SystemExit("formal sequence inventory is empty")
    inventory = builder.annotate_inventory_balance(inventory, story_encounters, content_recipe["balance_policy"], content_recipe)

    card_candidates = read_jsonl(cards_path)
    deck_candidates = read_jsonl(decks_path)
    output_dir = GENERATED_DIR / profile_id
    output_dir.mkdir(parents=True, exist_ok=True)

    accepted_cards, rejected_cards = normalize_cards(card_candidates, mechanic_profile, content_recipe)
    accepted_card_map = {item["candidate_id"]: item for item in accepted_cards}
    accepted_decks, rejected_decks = normalize_decks(deck_candidates, accepted_card_map, mechanic_profile, content_recipe)

    summary = {
        "mechanic_profile_id": profile_id,
        "content_pack_id": content_recipe["content_pack_id"],
        "input_card_candidate_count": len(card_candidates),
        "accepted_card_candidate_count": len(accepted_cards),
        "rejected_card_candidate_count": len(rejected_cards),
        "input_deck_candidate_count": len(deck_candidates),
        "accepted_deck_candidate_count": len(accepted_decks),
        "rejected_deck_candidate_count": len(rejected_decks),
        "deterministic_fill_used": False,
        "generated_battle_slot_count": 0,
        "generated_deck_count": 0,
        "generated_card_count": len(accepted_cards),
        "import_ready_for_validation": False,
        "rejected_card_candidate_ids": [item["candidate_id"] for item in rejected_cards],
        "rejected_deck_candidate_ids": [item["candidate_id"] for item in rejected_decks],
        "realm_metadata_checked": True,
        "invalid_realm_candidate_count": 0,
        "realm_filtered_card_ref_count": 0,
        "deck_candidate_rejected_by_realm_count": 0,
    }
    summary["invalid_realm_candidate_count"] = sum(
        1
        for item in [*rejected_cards, *rejected_decks]
        for reason in item.get("rejection_reasons", [])
        if "realm" in str(reason) or "wujing" in str(reason) or "closing_form" in str(reason)
    )

    if args.expect_invalid:
        summary["import_ready_for_validation"] = False
        invalid_attempt_path = output_dir / "imported_candidate_summary.invalid_attempt.json"
        write_json(invalid_attempt_path, summary)
        if summary["rejected_card_candidate_count"] == 0 and summary["rejected_deck_candidate_count"] == 0:
            raise SystemExit("expected invalid candidates, but none were rejected")
        print(f"llm candidate invalid import rejected: {profile_id}")
        return 0

    if summary["rejected_card_candidate_count"] or summary["rejected_deck_candidate_count"]:
        write_json(output_dir / "imported_candidate_summary.invalid_attempt.json", summary)
        raise SystemExit("llm candidate import rejected: invalid candidates detected")

    card_pool = build_generated_card_pool(accepted_cards, mechanic_profile, content_recipe)
    card_by_id = {card["card_id"]: card for card in card_pool}
    card_by_candidate_id = {card["candidate_id"]: card for card in card_pool}

    deck_pool: list[dict[str, Any]] = []
    battle_slots: list[dict[str, Any]] = []
    rewards: list[dict[str, Any]] = []
    mappings: list[dict[str, Any]] = []
    fill_used = False
    matching_decks = defaultdict(list)
    for deck in accepted_decks:
        key = (str(deck["enemy_role"]), str(deck["difficulty_tier"]))
        matching_decks[key].append(deck)

    for entry in inventory:
        encounter_tier = str(entry["encounter_tier"])
        encounter_kind = str(entry["encounter_kind"])
        player_wujing_cap = int(entry["player_wujing_cap"])
        enemy_role = builder.infer_enemy_role(entry, story_encounters[str(entry["formal_encounter_id"])], content_recipe["balance_policy"])
        sequence_position = int(entry["sequence_position"])
        reward_plan_id = f"{profile_id}_reward_{sequence_position:03d}"
        deck_id = f"{profile_id}_deck_{sequence_position:03d}"
        battle_slot_id = f"{profile_id}_slot_{sequence_position:03d}"

        candidate_deck = None
        key = (enemy_role, encounter_tier)
        if matching_decks.get(key):
            candidate_deck = matching_decks[key].pop(0)

        if candidate_deck is not None:
            legal_candidate_ids = [
                cid for cid in candidate_deck["card_candidate_ids"]
                if builder.card_allowed_for_player_cap(card_by_candidate_id[cid], player_wujing_cap)
            ]
            filtered_count = len(candidate_deck["card_candidate_ids"]) - len(legal_candidate_ids)
            summary["realm_filtered_card_ref_count"] += filtered_count
            if filtered_count > 0:
                summary["deck_candidate_rejected_by_realm_count"] += 1
                card_ids = fill_deck_card_ids(profile_id, enemy_role, encounter_tier, encounter_kind, card_by_candidate_id, mechanic_profile, player_wujing_cap)
                fill_strategy = "deterministic_fill_from_valid_candidates"
                fill_used = True
            else:
                card_ids = [card_by_candidate_id[cid]["card_id"] for cid in legal_candidate_ids]
            if len(card_ids) < int(mechanic_profile["deck_constraints"]["min_deck_size"]):
                card_ids = fill_deck_card_ids(profile_id, enemy_role, encounter_tier, encounter_kind, card_by_candidate_id, mechanic_profile, player_wujing_cap)
                fill_strategy = "deterministic_fill_from_valid_candidates"
                fill_used = True
            else:
                fill_strategy = "candidate_deck_import"
        else:
            card_ids = fill_deck_card_ids(profile_id, enemy_role, encounter_tier, encounter_kind, card_by_candidate_id, mechanic_profile, player_wujing_cap)
            fill_strategy = "deterministic_fill_from_valid_candidates"
            fill_used = True

        deck_power_score = round(sum(float(card_by_id[card_id]["power_score"]) for card_id in card_ids), 2)
        target_power_min = int(entry["target_power_min"])
        target_power_max = int(entry["target_power_max"])
        deck_pool.append(
            {
                "mechanic_profile_id": profile_id,
                "content_pack_id": content_recipe["content_pack_id"],
                "deck_id": deck_id,
                "enemy_role": enemy_role,
                "difficulty_tier": encounter_kind,
                "sequence_position": sequence_position,
                "encounter_tier": encounter_tier,
                "encounter_kind": encounter_kind,
                "player_wujing_cap": player_wujing_cap,
                "target_power_min": target_power_min,
                "target_power_max": target_power_max,
                "card_ids": card_ids,
                "deck_power_score": deck_power_score,
                "power_range_pass": target_power_min <= deck_power_score <= target_power_max,
                "realm_eligibility_checked": True,
                "invalid_realm_card_count": 0,
                "tags": [encounter_tier, encounter_kind, enemy_role, "llm_candidate_import"],
                "source": "llm_candidate_import",
                "fill_strategy": fill_strategy,
            }
        )
        rewards.append(
            {
                "mechanic_profile_id": profile_id,
                "content_pack_id": content_recipe["content_pack_id"],
                "reward_plan_id": reward_plan_id,
                "reward_type": "resource" if entry["reward_tier"] == "boss" else "card_pick",
                "reward_tier": entry["reward_tier"],
                "sequence_position": sequence_position,
                "encounter_tier": encounter_tier,
                "player_wujing_cap": player_wujing_cap,
                "reward_items": builder.build_reward_items(sequence_position, str(entry["reward_tier"]), encounter_kind),
                "source": {
                    "formal_encounter_id": entry["formal_encounter_id"],
                    "formal_battle_id": entry["formal_battle_id"],
                    "content_source": "llm_candidate_import",
                },
            }
        )
        battle_slots.append(
            {
                "mechanic_profile_id": profile_id,
                "content_pack_id": content_recipe["content_pack_id"],
                "battle_slot_id": battle_slot_id,
                "enemy_role": enemy_role,
                "difficulty_tier": encounter_kind,
                "sequence_position": sequence_position,
                "encounter_tier": encounter_tier,
                "encounter_kind": encounter_kind,
                "player_wujing_cap": player_wujing_cap,
                "target_power_min": target_power_min,
                "target_power_max": target_power_max,
                "reward_tier": entry["reward_tier"],
                "deck_id": deck_id,
                "reward_plan_id": reward_plan_id,
                "source": {
                    "target_sequence_id": entry["target_sequence_id"],
                    "formal_encounter_id": entry["formal_encounter_id"],
                    "formal_battle_id": entry["formal_battle_id"],
                    "node_id": entry["node_id"],
                    "content_source": "llm_candidate_import",
                },
            }
        )
        mappings.append(
            {
                "mechanic_profile_id": profile_id,
                "content_pack_id": content_recipe["content_pack_id"],
                "target_sequence_id": entry["target_sequence_id"],
                "formal_encounter_id": entry["formal_encounter_id"],
                "formal_battle_id": entry["formal_battle_id"],
                "generated_battle_slot_id": battle_slot_id,
                "generated_deck_id": deck_id,
                "reward_plan_id": reward_plan_id,
                "replacement_mode": "full_sequence",
                "sequence_position": sequence_position,
                "encounter_tier": encounter_tier,
                "encounter_kind": encounter_kind,
                "player_wujing_cap": player_wujing_cap,
                "target_power_min": target_power_min,
                "target_power_max": target_power_max,
                "reward_tier": entry["reward_tier"],
            }
        )

    balance_summary = builder.build_sequence_balance_summary(
        mechanic_profile,
        content_recipe,
        inventory,
        deck_pool,
        rewards,
        content_recipe["balance_policy"],
    )
    content_pack_summary = {
        "mechanic_profile_id": profile_id,
        "content_pack_id": content_recipe["content_pack_id"],
        "target_sequence_id": content_recipe["target_sequence_id"],
        "formal_encounter_total_count": len(inventory),
        "generated_battle_slot_count": len(battle_slots),
        "generated_deck_count": len(deck_pool),
        "generated_card_count": len(card_pool),
        "generated_reward_count": len(rewards),
        "replacement_mode": "full_sequence",
        "content_source": "llm_candidate_import",
    }
    summary.update(
        {
            "deterministic_fill_used": fill_used,
            "generated_battle_slot_count": len(battle_slots),
            "generated_deck_count": len(deck_pool),
            "generated_card_count": len(card_pool),
            "import_ready_for_validation": len(deck_pool) == len(inventory) and len(card_pool) > 0,
        }
    )

    write_json(output_dir / "formal_sequence_inventory.generated.json", inventory)
    write_json(output_dir / "imported_candidate_summary.json", summary)
    write_json(output_dir / "card_pool.generated.json", card_pool)
    write_json(output_dir / "enemy_deck_pool.generated.json", deck_pool)
    write_json(output_dir / "battle_slot_bindings.generated.json", battle_slots)
    write_json(output_dir / "rewards.generated.json", rewards)
    write_json(output_dir / "formal_sequence_mapping.generated.json", mappings)
    write_json(output_dir / "content_pack_summary.json", content_pack_summary)
    write_json(output_dir / "sequence_balance_summary.json", balance_summary)
    builder.write_markdown_balance_summary(output_dir / "sequence_balance_summary.md", balance_summary)
    print(f"imported llm candidates: {profile_id}")
    return 0


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("profile_id")
    parser.add_argument("--cards")
    parser.add_argument("--decks")
    parser.add_argument("--expect-invalid", action="store_true")
    return parser.parse_args(argv[1:])


def read_json(path: Path) -> Any:
    return json.loads(path.read_text(encoding="utf-8"))


def read_jsonl(path: Path) -> list[dict[str, Any]]:
    lines = []
    with path.open("r", encoding="utf-8") as handle:
        for raw in handle:
            text = raw.strip()
            if not text:
                continue
            lines.append(json.loads(text))
    return lines


def write_json(path: Path, payload: Any) -> None:
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def normalize_cards(card_candidates: list[dict[str, Any]], mechanic_profile: dict[str, Any], content_recipe: dict[str, Any]) -> tuple[list[dict[str, Any]], list[dict[str, Any]]]:
    accepted: list[dict[str, Any]] = []
    rejected: list[dict[str, Any]] = []
    card_constraints = mechanic_profile["card_constraints"]
    weapon_styles = set(str(item) for item in mechanic_profile["weapon_styles"])
    card_types = set(str(item) for item in mechanic_profile["card_types"])
    allowed_runtime_effects = set(str(item) for item in mechanic_profile["allowed_runtime_effects"])
    weights = mechanic_profile["power_model"]
    for candidate in card_candidates:
        reasons = []
        candidate_id = str(candidate.get("candidate_id", "")).strip()
        if not candidate_id:
            reasons.append("missing_candidate_id")
        if str(candidate.get("card_type", "")) not in card_types:
            reasons.append("invalid_card_type")
        if str(candidate.get("weapon_style", "")) not in weapon_styles:
            reasons.append("invalid_weapon_style")
        cost = int(candidate.get("cost", 0))
        if cost < int(card_constraints["min_cost"]) or cost > int(card_constraints["max_cost"]):
            reasons.append("invalid_cost")
        effects = candidate.get("effects", [])
        if not isinstance(effects, list) or not effects:
            reasons.append("missing_effects")
        effect_power = {"damage": 0, "gain_block": 0, "gain_momentum": 0, "break_momentum": 0}
        for effect in effects if isinstance(effects, list) else []:
            effect_type = str(effect.get("type", ""))
            if effect_type not in allowed_runtime_effects:
                reasons.append(f"unsupported_effect:{effect_type}")
                continue
            effect_power[effect_type] += int(effect.get("value", 0))
        power_score = round(
            effect_power["damage"] * float(weights.get("damage_weight", 1.0))
            + effect_power["gain_block"] * float(weights.get("block_weight", 1.0))
            + effect_power["gain_momentum"] * float(weights.get("gain_momentum_weight", 0.8))
            + effect_power["break_momentum"] * float(weights.get("break_momentum_weight", 0.8)),
            2,
        )
        if power_score < float(card_constraints["min_power_score"]) or power_score > float(card_constraints["max_power_score"]):
            reasons.append("power_score_out_of_bounds")
        normalized = {
            "candidate_id": candidate_id,
            "name": str(candidate.get("name", candidate_id)),
            "card_type": str(candidate.get("card_type", "attack")),
            "weapon_style": str(candidate.get("weapon_style", "generic")),
            "cost": cost,
            "effects": effects,
            "tags": [str(tag) for tag in candidate.get("tags", [])],
            "difficulty_tier": str(candidate.get("difficulty_tier", "early")),
            "source": str(candidate.get("source", "llm_candidate_fixture")),
            "required_wujing": candidate.get("required_wujing"),
            "closing_form_tier": candidate.get("closing_form_tier"),
            "power_score": power_score,
            "rejection_reasons": reasons,
        }
        if builder.is_realm_gated_card_type(normalized["card_type"], normalized["tags"]):
            if normalized["required_wujing"] is None:
                reasons.append("missing_required_wujing")
            if normalized["closing_form_tier"] is None:
                reasons.append("missing_closing_form_tier")
            if normalized["required_wujing"] is not None and int(normalized["required_wujing"]) <= 0:
                reasons.append("invalid_required_wujing")
            if normalized["closing_form_tier"] is not None and int(normalized["closing_form_tier"]) <= 0:
                reasons.append("invalid_closing_form_tier")
        if reasons:
            rejected.append(normalized)
        else:
            accepted.append(normalized)
    return accepted, rejected


def build_generated_card_pool(accepted_cards: list[dict[str, Any]], mechanic_profile: dict[str, Any], content_recipe: dict[str, Any]) -> list[dict[str, Any]]:
    profile_id = str(mechanic_profile["mechanic_profile_id"])
    content_pack_id = str(content_recipe["content_pack_id"])
    cards = []
    for candidate in accepted_cards:
        effects = candidate["effects"]
        effect_map = {effect['type']: int(effect.get('value', 0)) for effect in effects}
        card_id = f"{profile_id}_{candidate['candidate_id']}"
        cards.append(
            {
                "mechanic_profile_id": profile_id,
                "content_pack_id": content_pack_id,
                "card_id": card_id,
                "id": card_id,
                "candidate_id": candidate["candidate_id"],
                "name": candidate["name"],
                "card_type": candidate["card_type"],
                "weapon_style": candidate["weapon_style"],
                "style": "枪" if candidate["weapon_style"] == "spearman" else "刀",
                "cost": candidate["cost"],
                "min": 0,
                "max": 4 if candidate["weapon_style"] == "spearman" else 2,
                "role": builder.runtime_role_for_card(candidate["card_type"]),
                "gain": effect_map.get("gain_momentum", 0),
                "break": effect_map.get("break_momentum", 0),
                "damage": effect_map.get("damage", 0),
                "guard": effect_map.get("gain_block", 0),
                "effects": effects,
                "tags": list(candidate["tags"]) + ["llm_candidate_import"],
                "difficulty_tier": candidate["difficulty_tier"],
                "required_wujing": int(candidate["required_wujing"]) if candidate.get("required_wujing") is not None else 1,
                "closing_form_tier": int(candidate["closing_form_tier"]) if candidate.get("closing_form_tier") is not None else 1,
                "power_score": candidate["power_score"],
                "source": "llm_candidate_import",
            }
        )
    return cards


def normalize_decks(deck_candidates: list[dict[str, Any]], accepted_card_map: dict[str, dict[str, Any]], mechanic_profile: dict[str, Any], content_recipe: dict[str, Any]) -> tuple[list[dict[str, Any]], list[dict[str, Any]]]:
    accepted: list[dict[str, Any]] = []
    rejected: list[dict[str, Any]] = []
    min_size = int(mechanic_profile["deck_constraints"]["min_deck_size"])
    max_size = int(mechanic_profile["deck_constraints"]["max_deck_size"])
    max_same = int(mechanic_profile["deck_constraints"]["max_same_card"])
    for candidate in deck_candidates:
        reasons = []
        candidate_id = str(candidate.get("candidate_id", "")).strip()
        card_candidate_ids = [str(item) for item in candidate.get("card_candidate_ids", [])]
        if not candidate_id:
            reasons.append("missing_candidate_id")
        if not card_candidate_ids:
            reasons.append("missing_card_candidate_ids")
        if len(card_candidate_ids) > max_size:
            reasons.append("deck_size_too_large")
        counts = Counter(card_candidate_ids)
        for cid, count in counts.items():
            if cid not in accepted_card_map:
                reasons.append(f"missing_card:{cid}")
            if count > max_same:
                reasons.append(f"too_many_copies:{cid}")
        normalized = {
            "candidate_id": candidate_id,
            "enemy_role": str(candidate.get("enemy_role", "blademaster")),
            "difficulty_tier": str(candidate.get("difficulty_tier", candidate.get("intended_tier", "early"))),
            "card_candidate_ids": card_candidate_ids,
            "tags": [str(tag) for tag in candidate.get("tags", [])],
            "intended_tier": str(candidate.get("intended_tier", candidate.get("difficulty_tier", "early"))),
            "source": str(candidate.get("source", "llm_candidate_fixture")),
            "rejection_reasons": reasons,
        }
        if reasons:
            rejected.append(normalized)
        else:
            accepted.append(normalized)
    return accepted, rejected


def fill_deck_card_ids(
    profile_id: str,
    enemy_role: str,
    encounter_tier: str,
    encounter_kind: str,
    card_by_candidate_id: dict[str, dict[str, Any]],
    mechanic_profile: dict[str, Any],
    player_wujing_cap: int,
) -> list[str]:
    card_index = {card["card_id"]: card for card in card_by_candidate_id.values()}
    result = builder.build_deck_card_ids(
        profile_id,
        enemy_role,
        encounter_tier,
        encounter_kind,
        card_index,
        mechanic_profile,
        player_wujing_cap,
    )
    if len(result) < int(mechanic_profile["deck_constraints"]["min_deck_size"]):
        raise SystemExit("deterministic fill produced undersized deck")
    return result


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
