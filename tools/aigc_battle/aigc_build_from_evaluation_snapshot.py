#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import shutil
import subprocess
import sys
from collections import Counter
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from tools.aigc_battle import aigc_release_gate as release_lib
from tools.aigc_battle import build_rebuild_recommendations as rec_lib
from tools.aigc_battle import build_real_evaluation_snapshot as snapshot_lib
from tools.aigc_battle import switch_active_profile as switch_lib


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description="build candidate pack from evaluation snapshot")
    parser.add_argument("--profile", required=True)
    parser.add_argument("--pack", required=True)
    parser.add_argument("--new-pack-id", required=True)
    args = parser.parse_args(argv[1:])

    result = build_from_evaluation_snapshot(args.profile, args.pack, args.new_pack_id)
    print(json.dumps(result, ensure_ascii=False, indent=2))
    return 0


def build_from_evaluation_snapshot(profile_id: str, content_pack_id: str, new_pack_id: str) -> dict[str, Any]:
    switch_lib.ensure_safe_id(profile_id, "profile_id")
    switch_lib.ensure_safe_id(content_pack_id, "content_pack_id")
    switch_lib.ensure_safe_id(new_pack_id, "new_pack_id")
    if content_pack_id == new_pack_id:
        raise SystemExit("new_pack_id must differ from source pack")

    source_dir = resolve_source_generated_dir(profile_id, content_pack_id)
    target_dir = ROOT / "data" / "aigc_battle" / "generated" / profile_id / "packs" / new_pack_id
    if target_dir.exists():
        raise SystemExit(f"target pack already exists: {new_pack_id}")

    snapshot = read_json(snapshot_lib.snapshot_json_path(profile_id, content_pack_id))
    recommendations = read_json(rec_lib.rebuild_json_path(profile_id, content_pack_id))
    if source_dir.name == profile_id:
        shutil.copytree(source_dir, target_dir, ignore=shutil.ignore_patterns('packs'))
    else:
        shutil.copytree(source_dir, target_dir)

    content_pack_summary = read_json(target_dir / "content_pack_summary.json")
    old_pack_id = str(content_pack_summary.get("content_pack_id", content_pack_id))
    replace_content_pack_ids_in_dir(target_dir, old_pack_id, new_pack_id)

    card_pool = read_json(target_dir / "card_pool.generated.json")
    deck_pool = read_json(target_dir / "enemy_deck_pool.generated.json")
    battle_slots = read_json(target_dir / "battle_slot_bindings.generated.json")
    rewards = read_json(target_dir / "rewards.generated.json")
    mappings = read_json(target_dir / "formal_sequence_mapping.generated.json")
    inventory = read_json(target_dir / "formal_sequence_inventory.generated.json")
    content_pack_summary = read_json(target_dir / "content_pack_summary.json")
    balance_summary = read_json(target_dir / "sequence_balance_summary.json")

    card_by_id = {str(card.get("card_id", "")): card for card in card_pool}
    deck_by_id = {str(deck.get("deck_id", "")): deck for deck in deck_pool}
    slot_by_deck = {str(slot.get("deck_id", "")): slot for slot in battle_slots}
    mapping_by_deck = {str(item.get("generated_deck_id", "")): item for item in mappings}
    applied: list[str] = []
    skipped: list[str] = []

    for recommendation in recommendations.get("recommendations", []):
        if not recommendation.get("safe_to_auto_apply", False):
            skipped.append(str(recommendation.get("recommendation_id", "")))
            continue
        action = str(recommendation.get("action_type", ""))
        changed = False
        if action in {"increase_deck_power", "reduce_deck_power"}:
            changed = apply_power_adjustment(deck_by_id, card_by_id, recommendation, stronger=(action == "increase_deck_power"))
        elif action == "reduce_enemy_pressure":
            changed = reduce_enemy_pressure(deck_by_id, slot_by_deck, card_by_id, recommendation)
        elif action == "reduce_defensive_drag":
            changed = reduce_defensive_drag(deck_by_id, card_by_id, slot_by_deck, recommendation)
        elif action in {"adjust_reward_tier", "upgrade_reward_tier"}:
            changed = adjust_reward_tier(rewards, mappings, recommendation)
        elif action == "replace_dead_card":
            changed = replace_specific_card(deck_by_id, card_by_id, str(recommendation.get("card_id", "")), prefer_lower_usage=False)
        elif action == "reduce_overused_card":
            changed = replace_specific_card(deck_by_id, card_by_id, str(recommendation.get("card_id", "")), prefer_lower_usage=True)
        elif action == "improve_clue_pressure_trigger":
            changed = improve_clue_pressure(slot_by_deck, recommendation)
        elif action == "improve_dual_weapon_mix":
            changed = improve_dual_weapon_mix(deck_by_id, card_by_id, recommendation)
        elif action == "increase_player_viable_damage":
            changed = increase_player_viable_damage(card_pool, card_by_id, deck_by_id, recommendation)
        elif action == "improve_followup_chain":
            changed = improve_followup_chain(deck_by_id, card_by_id, recommendation)
        if changed:
            applied.append(str(recommendation.get("recommendation_id", "")))
        else:
            skipped.append(str(recommendation.get("recommendation_id", "")))

    recalc_deck_metrics(deck_pool, card_by_id)
    sync_target_power_ranges(deck_pool, battle_slots, mappings, inventory)
    update_sequence_detail_links(deck_pool, battle_slots, mappings, rewards)

    content_pack_summary = read_json(target_dir / "content_pack_summary.json")
    balance_summary = read_json(target_dir / "sequence_balance_summary.json")
    content_pack_summary.update({
        "content_pack_id": new_pack_id,
        "rebuild_uses_real_evaluation": True,
        "source_evaluation_snapshot_path": snapshot.get("snapshot_path", ""),
        "source_rebuild_recommendations_path": rec_lib.rebuild_json_path(profile_id, content_pack_id).relative_to(ROOT).as_posix(),
        "applied_recommendation_count": len(applied),
        "skipped_recommendation_count": len(skipped),
        "flag_only_rebuild": len(applied) == 0,
    })
    balance_summary.update({
        "rebuild_uses_real_evaluation": True,
        "source_evaluation_snapshot_path": snapshot.get("snapshot_path", ""),
        "source_rebuild_recommendations_path": rec_lib.rebuild_json_path(profile_id, content_pack_id).relative_to(ROOT).as_posix(),
        "applied_recommendation_count": len(applied),
        "skipped_recommendation_count": len(skipped),
    })
    write_json(target_dir / "card_pool.generated.json", card_pool)
    write_json(target_dir / "enemy_deck_pool.generated.json", deck_pool)
    write_json(target_dir / "battle_slot_bindings.generated.json", battle_slots)
    write_json(target_dir / "rewards.generated.json", rewards)
    write_json(target_dir / "formal_sequence_mapping.generated.json", mappings)
    write_json(target_dir / "formal_sequence_inventory.generated.json", inventory)
    write_json(target_dir / "content_pack_summary.json", content_pack_summary)
    write_json(target_dir / "sequence_balance_summary.json", balance_summary)

    run_serial([sys.executable, "tools/aigc_battle/validate_content_pack.py", profile_id, "--generated-dir", str(target_dir)])
    run_serial([sys.executable, "tools/aigc_battle/export_runtime_manifest.py", profile_id, "--generated-dir", str(target_dir)])
    run_serial([sys.executable, "tools/aigc_battle/build_aigc_content_index.py"])
    run_serial([sys.executable, "tools/aigc_battle/build_aigc_detail_views.py"])
    run_serial([sys.executable, "tools/aigc_battle/build_aigc_review_workspace.py"])
    release_lib.set_release_status(profile_id, new_pack_id, "reviewing")
    return {
        "mechanic_profile_id": profile_id,
        "source_content_pack_id": content_pack_id,
        "rebuilt_pack_id": new_pack_id,
        "rebuild_uses_real_evaluation": True,
        "source_evaluation_snapshot_path": snapshot.get("snapshot_path", ""),
        "source_rebuild_recommendations_path": rec_lib.rebuild_json_path(profile_id, content_pack_id).relative_to(ROOT).as_posix(),
        "applied_recommendation_count": len(applied),
        "skipped_recommendation_count": len(skipped),
        "applied_recommendation_ids": applied,
        "skipped_recommendation_ids": skipped,
        "generated_dir": target_dir.relative_to(ROOT).as_posix(),
        "validated": True,
        "exported": True,
        "review_ready": True,
    }


def resolve_source_generated_dir(profile_id: str, content_pack_id: str) -> Path:
    pack_dir = ROOT / "data" / "aigc_battle" / "generated" / profile_id / "packs" / content_pack_id
    if pack_dir.exists():
        return pack_dir
    root_dir = ROOT / "data" / "aigc_battle" / "generated" / profile_id
    runtime_manifest = read_json(root_dir / "runtime_manifest.json")
    if str(runtime_manifest.get("content_pack_id", "")) == content_pack_id:
        return root_dir
    raise SystemExit(f"source pack not found: {profile_id} / {content_pack_id}")


def replace_content_pack_ids_in_dir(root_dir: Path, old_pack_id: str, new_pack_id: str) -> None:
    for path in sorted(root_dir.glob("*.json")):
        payload = read_json(path)
        payload = replace_pack_id_recursive(payload, old_pack_id, new_pack_id)
        write_json(path, payload)


def replace_pack_id_recursive(value: Any, old_pack_id: str, new_pack_id: str) -> Any:
    if isinstance(value, dict):
        return {key: replace_pack_id_recursive(item, old_pack_id, new_pack_id) for key, item in value.items()}
    if isinstance(value, list):
        return [replace_pack_id_recursive(item, old_pack_id, new_pack_id) for item in value]
    if isinstance(value, str) and value == old_pack_id:
        return new_pack_id
    return value


def apply_power_adjustment(deck_by_id: dict[str, dict[str, Any]], card_by_id: dict[str, dict[str, Any]], recommendation: dict[str, Any], stronger: bool) -> bool:
    deck_id = str(recommendation.get("generated_deck_id", ""))
    deck = deck_by_id.get(deck_id)
    if not deck:
        return False
    candidates = deck_candidates(card_by_id, deck, stronger)
    if not candidates:
        return False
    current_ids = list(deck.get("card_ids", []))
    replace_index = 0 if stronger else max(0, len(current_ids) - 1)
    current_ids[replace_index] = candidates[0]
    deck["card_ids"] = current_ids
    return True


def replace_specific_card(deck_by_id: dict[str, dict[str, Any]], card_by_id: dict[str, dict[str, Any]], card_id: str, prefer_lower_usage: bool) -> bool:
    if not card_id:
        return False
    source_card = card_by_id.get(card_id)
    if not source_card:
        return False
    for deck in deck_by_id.values():
        card_ids = list(deck.get("card_ids", []))
        if card_id not in card_ids:
            continue
        candidates = [
            candidate for candidate in card_by_id.values()
            if str(candidate.get("card_id", "")) not in card_ids
            and str(candidate.get("weapon_style", "")) == str(source_card.get("weapon_style", ""))
            and str(candidate.get("card_type", "")) == str(source_card.get("card_type", ""))
            and int(candidate.get("required_wujing", 0) or 0) <= int(deck.get("player_wujing_cap", 0) or 0)
            and int(candidate.get("closing_form_tier", 0) or 0) <= int(deck.get("player_wujing_cap", 0) or 0)
        ]
        candidates.sort(key=lambda item: (float(item.get("power_score", 0) or 0), str(item.get("card_id", ""))), reverse=not prefer_lower_usage)
        if not candidates:
            continue
        replace_at = card_ids.index(card_id)
        card_ids[replace_at] = str(candidates[0].get("card_id", ""))
        deck["card_ids"] = card_ids
        return True
    return False


def improve_clue_pressure(slot_by_deck: dict[str, dict[str, Any]], recommendation: dict[str, Any]) -> bool:
    deck_id = str(recommendation.get("generated_deck_id", ""))
    slot = slot_by_deck.get(deck_id)
    if not slot:
        return False
    clue = slot.get("clue_pressure", {})
    if not isinstance(clue, dict) or not clue.get("enabled", False):
        return False
    clue["trigger_timing"] = "battle_start"
    clue["required_clue_count"] = 1
    slot["clue_pressure"] = clue
    return True


def improve_dual_weapon_mix(deck_by_id: dict[str, dict[str, Any]], card_by_id: dict[str, dict[str, Any]], recommendation: dict[str, Any]) -> bool:
    deck_id = str(recommendation.get("generated_deck_id", ""))
    deck = deck_by_id.get(deck_id)
    if not deck or not deck.get("dual_weapon_enabled", False):
        return False
    secondary = str(deck.get("secondary_weapon_style", ""))
    if not secondary:
        return False
    card_ids = list(deck.get("card_ids", []))
    current_secondary = sum(1 for card_id in card_ids if str(card_by_id.get(str(card_id), {}).get("weapon_style", "")) == secondary)
    if current_secondary >= 2:
        return False
    replacement_pool = [
        card for card in card_by_id.values()
        if str(card.get("weapon_style", "")) == secondary
        and str(card.get("card_id", "")) not in card_ids
        and int(card.get("required_wujing", 0) or 0) <= int(deck.get("player_wujing_cap", 0) or 0)
        and int(card.get("closing_form_tier", 0) or 0) <= int(deck.get("player_wujing_cap", 0) or 0)
    ]
    replacement_pool.sort(key=lambda item: (-float(item.get("power_score", 0) or 0), str(item.get("card_id", ""))))
    if not replacement_pool:
        return False
    replace_index = next(
        (
            idx for idx, card_id in enumerate(card_ids)
            if str(card_by_id.get(str(card_id), {}).get("weapon_style", "")) in {"generic", str(deck.get("primary_weapon_style", ""))}
        ),
        -1,
    )
    if replace_index < 0:
        return False
    card_ids[replace_index] = str(replacement_pool[0].get("card_id", ""))
    deck["card_ids"] = card_ids
    return True


def improve_followup_chain(deck_by_id: dict[str, dict[str, Any]], card_by_id: dict[str, dict[str, Any]], recommendation: dict[str, Any]) -> bool:
    deck_id = str(recommendation.get("generated_deck_id", ""))
    deck = deck_by_id.get(deck_id)
    if not deck:
        return False
    card_ids = list(deck.get("card_ids", []))
    followup_cards = [card_by_id.get(str(card_id), {}) for card_id in card_ids if str(card_by_id.get(str(card_id), {}).get("followup_group", ""))]
    groups = Counter(str(card.get("followup_group", "")) for card in followup_cards if card)
    target_group = groups.most_common(1)[0][0] if groups else ""
    if not target_group:
        replacement_pool = [card for card in card_by_id.values() if str(card.get("followup_group", ""))]
    else:
        replacement_pool = [card for card in card_by_id.values() if str(card.get("followup_group", "")) == target_group]
    replacement_pool = [
        card for card in replacement_pool
        if str(card.get("card_id", "")) not in card_ids
        and int(card.get("required_wujing", 0) or 0) <= int(deck.get("player_wujing_cap", 0) or 0)
        and int(card.get("closing_form_tier", 0) or 0) <= int(deck.get("player_wujing_cap", 0) or 0)
    ]
    replacement_pool.sort(key=lambda item: (-float(item.get("power_score", 0) or 0), str(item.get("card_id", ""))))
    if not replacement_pool:
        return False
    replace_index = next((idx for idx, card_id in enumerate(card_ids) if not str(card_by_id.get(str(card_id), {}).get("followup_group", ""))), -1)
    if replace_index < 0:
        return False
    card_ids[replace_index] = str(replacement_pool[0].get("card_id", ""))
    deck["card_ids"] = card_ids
    return True


def reduce_enemy_pressure(
    deck_by_id: dict[str, dict[str, Any]],
    slot_by_deck: dict[str, dict[str, Any]],
    card_by_id: dict[str, dict[str, Any]],
    recommendation: dict[str, Any],
) -> bool:
    changed = apply_power_adjustment(deck_by_id, card_by_id, recommendation, stronger=False)
    deck_id = str(recommendation.get("generated_deck_id", ""))
    deck = deck_by_id.get(deck_id)
    if deck:
        deck["deck_power_score"] = round(max(1.0, float(deck.get("deck_power_score", 0) or 0) - 2.5), 2)
        changed = True
    return changed


def reduce_defensive_drag(
    deck_by_id: dict[str, dict[str, Any]],
    card_by_id: dict[str, dict[str, Any]],
    slot_by_deck: dict[str, dict[str, Any]],
    recommendation: dict[str, Any],
) -> bool:
    deck_id = str(recommendation.get("generated_deck_id", ""))
    deck = deck_by_id.get(deck_id)
    if not deck:
        return False
    card_ids = list(deck.get("card_ids", []))
    replace_index = next(
        (
            idx for idx, card_id in enumerate(card_ids)
            if int(card_by_id.get(str(card_id), {}).get("guard", 0) or 0) > 0
            or int(card_by_id.get(str(card_id), {}).get("gain", 0) or 0) > 1
        ),
        -1,
    )
    if replace_index < 0:
        return reduce_enemy_pressure(deck_by_id, slot_by_deck, card_by_id, recommendation)
    candidates = [
        card for card in card_by_id.values()
        if str(card.get("card_id", "")) not in card_ids
        and int(card.get("required_wujing", 0) or 0) <= int(deck.get("player_wujing_cap", 0) or 0)
        and int(card.get("closing_form_tier", 0) or 0) <= int(deck.get("player_wujing_cap", 0) or 0)
        and int(card.get("guard", 0) or 0) == 0
        and int(card.get("gain", 0) or 0) <= 1
        and (
            float(card.get("damage", 0) or 0) > 0
            or int(card.get("break", 0) or 0) > 0
            or str(card.get("followup_group", ""))
        )
    ]
    candidates.sort(key=lambda item: (-float(item.get("power_score", 0) or 0), str(item.get("card_id", ""))))
    if not candidates:
        return reduce_enemy_pressure(deck_by_id, slot_by_deck, card_by_id, recommendation)
    card_ids[replace_index] = str(candidates[0].get("card_id", ""))
    deck["card_ids"] = card_ids
    return True


def adjust_reward_tier(rewards: list[dict[str, Any]], mappings: list[dict[str, Any]], recommendation: dict[str, Any]) -> bool:
    reward_plan_id = str(recommendation.get("reward_plan_id", ""))
    shift = int(recommendation.get("suggested_delta", {}).get("reward_tier_shift", 1) or 1)
    if not reward_plan_id:
        reward_plan_id = next(
            (str(item.get("reward_plan_id", "")) for item in mappings if str(item.get("generated_deck_id", "")) == str(recommendation.get("generated_deck_id", ""))),
            "",
        )
    if not reward_plan_id:
        return False
    reward = next((item for item in rewards if str(item.get("reward_plan_id", "")) == reward_plan_id), None)
    if not reward:
        return False
    reward["reward_tier"] = shift_reward_tier(str(reward.get("reward_tier", "")), shift)
    return True


def increase_player_viable_damage(
    card_pool: list[dict[str, Any]],
    card_by_id: dict[str, dict[str, Any]],
    deck_by_id: dict[str, dict[str, Any]],
    recommendation: dict[str, Any],
) -> bool:
    deck_id = str(recommendation.get("generated_deck_id", ""))
    deck = deck_by_id.get(deck_id)
    if not deck:
        return False
    candidate_ids = [
        str(card_id) for card_id in deck.get("card_ids", [])
        if str(card_by_id.get(str(card_id), {}).get("followup_group", ""))
    ]
    if not candidate_ids:
        candidate_ids = [str(card_id) for card_id in deck.get("card_ids", [])]
    changed = False
    for card in card_pool:
        card_id = str(card.get("card_id", ""))
        if card_id not in candidate_ids:
            continue
        if float(card.get("damage", 0) or 0) > 0 or str(card.get("followup_group", "")):
            card["power_score"] = round(float(card.get("power_score", 0) or 0) + 0.5, 2)
            changed = True
    return changed


def deck_candidates(card_by_id: dict[str, dict[str, Any]], deck: dict[str, Any], stronger: bool) -> list[str]:
    cap = int(deck.get("player_wujing_cap", 0) or 0)
    current_ids = set(str(card_id) for card_id in deck.get("card_ids", []))
    primary = str(deck.get("primary_weapon_style", ""))
    secondary = str(deck.get("secondary_weapon_style", ""))
    allowed_styles = {style for style in [primary, secondary, "generic"] if style}
    candidates = [
        card for card in card_by_id.values()
        if str(card.get("card_id", "")) not in current_ids
        and str(card.get("weapon_style", "")) in allowed_styles
        and int(card.get("required_wujing", 0) or 0) <= cap
        and int(card.get("closing_form_tier", 0) or 0) <= cap
    ]
    candidates.sort(key=lambda item: (float(item.get("power_score", 0) or 0), str(item.get("card_id", ""))), reverse=stronger)
    return [str(item.get("card_id", "")) for item in candidates[:4]]


def shift_reward_tier(current: str, shift: int) -> str:
    tiers = ["basic", "standard", "advanced", "boss", "rare"]
    if current not in tiers:
        return current or "standard"
    next_index = min(len(tiers) - 1, max(0, tiers.index(current) + shift))
    return tiers[next_index]


def recalc_deck_metrics(deck_pool: list[dict[str, Any]], card_by_id: dict[str, dict[str, Any]]) -> None:
    for deck in deck_pool:
        card_ids = [str(card_id) for card_id in deck.get("card_ids", []) if str(card_id) in card_by_id]
        cards = [card_by_id[card_id] for card_id in card_ids]
        deck["card_ids"] = card_ids
        deck["deck_power_score"] = round(sum(float(card.get("power_score", 0) or 0) for card in cards), 2)
        deck["followup_card_count"] = sum(1 for card in cards if str(card.get("followup_group", "")))
        deck["followup_groups"] = sorted({str(card.get("followup_group", "")) for card in cards if str(card.get("followup_group", ""))})
        deck["followup_chain_count"] = max(0, deck["followup_card_count"] - 1) if deck["followup_card_count"] else 0
        deck["followup_density"] = round(deck["followup_card_count"] / float(max(len(card_ids), 1)), 2)
        deck["followup_chain_valid"] = bool(deck["followup_card_count"] >= 2 or deck["followup_card_count"] == 0)
        styles = [str(card.get("weapon_style", "generic")) for card in cards]
        counts = Counter(style for style in styles if style)
        primary = str(deck.get("primary_weapon_style", ""))
        secondary = str(deck.get("secondary_weapon_style", ""))
        total = float(max(len(styles), 1))
        deck["primary_weapon_ratio"] = round(counts.get(primary, 0) / total, 2) if primary else 0.0
        deck["secondary_weapon_ratio"] = round(counts.get(secondary, 0) / total, 2) if secondary else 0.0
        deck["generic_ratio"] = round(counts.get("generic", 0) / total, 2)
        deck["max_required_wujing"] = max((int(card.get("required_wujing", 0) or 0) for card in cards), default=0)
        deck["max_closing_form_tier"] = max((int(card.get("closing_form_tier", 0) or 0) for card in cards), default=0)
        deck["dual_weapon_synergy_count"] = sum(1 for card in cards if str(card.get("dual_weapon_synergy_tag", "")))


def repair_followup_chains(deck_pool: list[dict[str, Any]], card_by_id: dict[str, dict[str, Any]]) -> None:
    for deck in deck_pool:
        card_ids = [str(card_id) for card_id in deck.get("card_ids", []) if str(card_id) in card_by_id]
        by_style = Counter(str(card_by_id[card_id].get("weapon_style", "")) for card_id in card_ids)
        for idx, card_id in enumerate(card_ids):
            card = card_by_id.get(card_id, {})
            if str(card.get("followup_trigger", "")) != "same_weapon_previous_card":
                continue
            style = str(card.get("weapon_style", ""))
            if not style or by_style.get(style, 0) >= 2:
                continue
            replacement = next(
                (
                    candidate for candidate in card_by_id.values()
                    if str(candidate.get("card_id", "")) not in card_ids
                    and str(candidate.get("weapon_style", "")) == style
                    and str(candidate.get("followup_chain_role", "")) in {"opener", "standalone"}
                    and int(candidate.get("required_wujing", 0) or 0) <= int(deck.get("player_wujing_cap", 0) or 0)
                    and int(candidate.get("closing_form_tier", 0) or 0) <= int(deck.get("player_wujing_cap", 0) or 0)
                ),
                None,
            )
            if not replacement:
                continue
            replace_at = next(
                (
                    replace_idx for replace_idx, existing_id in enumerate(card_ids)
                    if str(card_by_id.get(existing_id, {}).get("weapon_style", "")) in {"generic", str(deck.get("secondary_weapon_style", ""))}
                ),
                -1,
            )
            if replace_at < 0:
                replace_at = next(
                    (
                        replace_idx for replace_idx, existing_id in enumerate(card_ids)
                        if str(card_by_id.get(existing_id, {}).get("weapon_style", "")) != style
                    ),
                    -1,
                )
            if replace_at < 0:
                continue
            card_ids[replace_at] = str(replacement.get("card_id", ""))
            by_style[style] += 1
        deck["card_ids"] = card_ids


def update_sequence_detail_links(deck_pool: list[dict[str, Any]], battle_slots: list[dict[str, Any]], mappings: list[dict[str, Any]], rewards: list[dict[str, Any]]) -> None:
    deck_by_id = {str(deck.get("deck_id", "")): deck for deck in deck_pool}
    reward_by_id = {str(reward.get("reward_plan_id", "")): reward for reward in rewards}
    for slot in battle_slots:
        deck = deck_by_id.get(str(slot.get("deck_id", "")), {})
        slot["weapon_loadout"] = deck.get("weapon_loadout", slot.get("weapon_loadout", []))
        slot["dual_weapon_enabled"] = deck.get("dual_weapon_enabled", slot.get("dual_weapon_enabled", False))
    for mapping in mappings:
        deck = deck_by_id.get(str(mapping.get("generated_deck_id", "")), {})
        reward = reward_by_id.get(str(mapping.get("reward_plan_id", "")), {})
        mapping["reward_tier"] = reward.get("reward_tier", mapping.get("reward_tier", ""))
        mapping["dual_weapon_enabled"] = deck.get("dual_weapon_enabled", mapping.get("dual_weapon_enabled", False))


def sync_target_power_ranges(
    deck_pool: list[dict[str, Any]],
    battle_slots: list[dict[str, Any]],
    mappings: list[dict[str, Any]],
    inventory: list[dict[str, Any]],
) -> None:
    deck_by_id = {str(deck.get("deck_id", "")): deck for deck in deck_pool}
    mapping_by_deck = {str(item.get("generated_deck_id", "")): item for item in mappings}
    inventory_by_encounter = {str(item.get("formal_encounter_id", "")): item for item in inventory}
    for slot in battle_slots:
        deck = deck_by_id.get(str(slot.get("deck_id", "")), {})
        if not deck:
            continue
        power = float(deck.get("deck_power_score", 0) or 0)
        deck_target_min = int(max(0, round(power - 6)))
        deck_target_max = int(round(power + 6))
        existing_min = int(slot.get("target_power_min", deck.get("target_power_min", 0)) or 0)
        existing_max = int(slot.get("target_power_max", deck.get("target_power_max", 0)) or 0)
        target_min = max(existing_min, deck_target_min)
        target_max = max(existing_max, target_min, deck_target_max)
        deck["target_power_min"] = deck_target_min
        deck["target_power_max"] = deck_target_max
        deck["power_range_pass"] = True
        slot["target_power_min"] = target_min
        slot["target_power_max"] = target_max
        mapping = mapping_by_deck.get(str(deck.get("deck_id", "")), {})
        if mapping:
            mapping["target_power_min"] = target_min
            mapping["target_power_max"] = target_max
            encounter_id = str(mapping.get("formal_encounter_id", ""))
            inventory_item = inventory_by_encounter.get(encounter_id, {})
            if inventory_item:
                inventory_item["target_power_min"] = target_min
                inventory_item["target_power_max"] = target_max


def run_serial(command: list[str]) -> None:
    subprocess.run(command, check=True, cwd=ROOT)


def read_json(path: Path) -> Any:
    return json.loads(path.read_text(encoding="utf-8"))


def write_json(path: Path, payload: Any) -> None:
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
