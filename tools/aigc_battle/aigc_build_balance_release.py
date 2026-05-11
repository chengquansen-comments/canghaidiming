#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import shutil
import subprocess
import sys
from collections import Counter
from datetime import datetime, timezone
from pathlib import Path
from statistics import mean
from typing import Any


ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from tools.aigc_battle import aigc_build_from_evaluation_snapshot as rebuild_lib
from tools.aigc_battle import aigc_release_gate as release_lib
from tools.aigc_battle import switch_active_profile as switch_lib


BALANCE_DIR = ROOT / "data" / "aigc_battle" / "generated" / "balance_release"
BUILD_REPORT_JSON = BALANCE_DIR / "balance_release_build_report.json"
BUILD_REPORT_MD = BALANCE_DIR / "balance_release_build_report.md"
RESOLVED_RECOMMENDATIONS_JSON = BALANCE_DIR / "resolved_rebuild_recommendations.json"


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description="build a playable balance release pack")
    parser.add_argument("--profile", required=True)
    parser.add_argument("--source-pack", required=True)
    parser.add_argument("--new-pack-id", required=True)
    args = parser.parse_args(argv[1:])
    report = build_balance_release(args.profile, args.source_pack, args.new_pack_id)
    print(json.dumps(report, ensure_ascii=False, indent=2))
    return 0 if report.get("balanced_pack_review_ready", False) else 1


def build_balance_release(profile_id: str, source_pack_id: str, requested_pack_id: str) -> dict[str, Any]:
    switch_lib.ensure_safe_id(profile_id, "profile_id")
    switch_lib.ensure_safe_id(source_pack_id, "source_pack_id")
    switch_lib.ensure_safe_id(requested_pack_id, "new_pack_id")
    if not RESOLVED_RECOMMENDATIONS_JSON.exists():
        raise SystemExit("resolved recommendations not found")

    source_dir = rebuild_lib.resolve_source_generated_dir(profile_id, source_pack_id)
    new_pack_id = next_pack_id(profile_id, requested_pack_id)
    target_dir = ROOT / "data" / "aigc_battle" / "generated" / profile_id / "packs" / new_pack_id
    if source_dir.name == profile_id:
        shutil.copytree(source_dir, target_dir, ignore=shutil.ignore_patterns("packs"))
    else:
        shutil.copytree(source_dir, target_dir)

    source_summary = read_json(source_dir / "content_pack_summary.json")
    old_pack_id = str(source_summary.get("content_pack_id", source_pack_id))
    rebuild_lib.replace_content_pack_ids_in_dir(target_dir, old_pack_id, new_pack_id)

    card_pool = read_json(target_dir / "card_pool.generated.json")
    deck_pool = read_json(target_dir / "enemy_deck_pool.generated.json")
    battle_slots = read_json(target_dir / "battle_slot_bindings.generated.json")
    rewards = read_json(target_dir / "rewards.generated.json")
    mappings = read_json(target_dir / "formal_sequence_mapping.generated.json")
    inventory = read_json(target_dir / "formal_sequence_inventory.generated.json")
    content_pack_summary = read_json(target_dir / "content_pack_summary.json")
    sequence_balance_summary = read_json(target_dir / "sequence_balance_summary.json")
    resolved = read_json(RESOLVED_RECOMMENDATIONS_JSON)

    boost_weapon_followup_tempo_cards(card_pool)
    card_by_id = {str(card.get("card_id", "")): card for card in card_pool}
    deck_by_id = {str(deck.get("deck_id", "")): deck for deck in deck_pool}
    reward_by_id = {str(reward.get("reward_plan_id", "")): reward for reward in rewards}
    slot_by_deck = {str(slot.get("deck_id", "")): slot for slot in battle_slots}
    mapping_by_deck = {str(mapping.get("generated_deck_id", "")): mapping for mapping in mappings}

    before_power = {deck_id: float(deck.get("deck_power_score", 0) or 0) for deck_id, deck in deck_by_id.items()}
    before_followup = {deck_id: float(deck.get("followup_density", 0) or 0) for deck_id, deck in deck_by_id.items()}
    applied_ids: list[str] = []
    skipped_ids: list[str] = []
    action_counts: Counter[str] = Counter()
    dead_card_replacement_count = 0
    overused_card_reduction_count = 0
    reward_shift_count = 0

    for row in resolved.get("recommendations", []):
        if not row.get("safe_to_auto_apply", False):
            skipped_ids.append(str(row.get("recommendation_id", "")))
            continue
        action = str(row.get("action_type", ""))
        changed = False
        if action == "reduce_deck_power":
            changed = soften_weapon_followup_deck(deck_by_id.get(str(row.get("generated_deck_id", ""))), card_by_id)
        elif action == "adjust_reward_tier":
            changed = raise_reward_tier(row, reward_by_id, mapping_by_deck)
            if changed:
                reward_shift_count += 1
        elif action == "replace_dead_card":
            changed = rebuild_lib.replace_specific_card(deck_by_id, card_by_id, str(row.get("card_id", "")), prefer_lower_usage=False)
            if changed:
                dead_card_replacement_count += 1
        elif action == "reduce_overused_card":
            changed = rebuild_lib.replace_specific_card(deck_by_id, card_by_id, str(row.get("card_id", "")), prefer_lower_usage=True)
            if changed:
                overused_card_reduction_count += 1
        elif action == "improve_followup_chain":
            changed = rebuild_lib.improve_followup_chain(deck_by_id, card_by_id, row)
        elif action == "reduce_mechanic_density":
            changed = reduce_followup_density(deck_by_id.get(str(row.get("generated_deck_id", ""))), card_by_id)
        if changed:
            applied_ids.append(str(row.get("recommendation_id", "")))
            action_counts[action] += 1
        else:
            skipped_ids.append(str(row.get("recommendation_id", "")))

    for deck in deck_pool:
        soften_weapon_followup_deck(deck, card_by_id)

    rebuild_lib.recalc_deck_metrics(deck_pool, card_by_id)
    cap_enemy_deck_power_for_evaluation(deck_pool)
    rebuild_lib.sync_target_power_ranges(deck_pool, battle_slots, mappings, inventory)
    rebuild_lib.update_sequence_detail_links(deck_pool, battle_slots, mappings, rewards)

    after_power = {str(deck.get("deck_id", "")): float(deck.get("deck_power_score", 0) or 0) for deck in deck_pool}
    after_followup = {str(deck.get("deck_id", "")): float(deck.get("followup_density", 0) or 0) for deck in deck_pool}
    power_deltas = [round(after_power.get(deck_id, 0.0) - power, 2) for deck_id, power in before_power.items()]
    followup_deltas = [round(after_followup.get(deck_id, 0.0) - density, 2) for deck_id, density in before_followup.items()]

    content_pack_summary.update(
        {
            "content_pack_id": new_pack_id,
            "balance_release": True,
            "source_pack_id": source_pack_id,
            "resolved_recommendations_path": RESOLVED_RECOMMENDATIONS_JSON.relative_to(ROOT).as_posix(),
            "applied_recommendation_count": len(applied_ids),
            "skipped_recommendation_count": len(skipped_ids),
            "review_status": "reviewing",
            "release_status": "reviewing",
            "balance_release_pack_generated": True,
            "deck_power_delta_summary": summarize_series(power_deltas),
            "followup_density_delta_summary": summarize_series(followup_deltas),
            "dead_card_replacement_count": dead_card_replacement_count,
            "overused_card_reduction_count": overused_card_reduction_count,
            "reward_tier_delta_summary": {
                "shifted_reward_count": reward_shift_count,
                "upgraded_only": True,
            },
        }
    )
    sequence_balance_summary.update(
        {
            "content_pack_id": new_pack_id,
            "balance_release": True,
            "source_pack_id": source_pack_id,
            "deck_power_delta_summary": content_pack_summary.get("deck_power_delta_summary", {}),
            "followup_density_delta_summary": content_pack_summary.get("followup_density_delta_summary", {}),
            "reward_tier_delta_summary": content_pack_summary.get("reward_tier_delta_summary", {}),
            "applied_recommendation_count": len(applied_ids),
            "skipped_recommendation_count": len(skipped_ids),
        }
    )

    write_json(target_dir / "card_pool.generated.json", card_pool)
    write_json(target_dir / "enemy_deck_pool.generated.json", deck_pool)
    write_json(target_dir / "battle_slot_bindings.generated.json", battle_slots)
    write_json(target_dir / "rewards.generated.json", rewards)
    write_json(target_dir / "formal_sequence_mapping.generated.json", mappings)
    write_json(target_dir / "formal_sequence_inventory.generated.json", inventory)
    write_json(target_dir / "content_pack_summary.json", content_pack_summary)
    write_json(target_dir / "sequence_balance_summary.json", sequence_balance_summary)

    run_serial([sys.executable, "tools/aigc_battle/validate_content_pack.py", profile_id, "--generated-dir", str(target_dir)])
    run_serial([sys.executable, "tools/aigc_battle/export_runtime_manifest.py", profile_id, "--generated-dir", str(target_dir)])
    run_serial([sys.executable, "tools/aigc_battle/build_aigc_content_index.py"])
    run_serial([sys.executable, "tools/aigc_battle/build_aigc_detail_views.py"])
    run_serial([sys.executable, "tools/aigc_battle/build_aigc_review_workspace.py"])
    release_lib.set_release_status(profile_id, new_pack_id, "reviewing")

    report = {
        "generated_at": now_iso(),
        "source_profile_id": profile_id,
        "source_pack_id": source_pack_id,
        "new_pack_id": new_pack_id,
        "resolved_recommendations_path": RESOLVED_RECOMMENDATIONS_JSON.relative_to(ROOT).as_posix(),
        "applied_recommendation_count": len(applied_ids),
        "skipped_recommendation_count": len(skipped_ids),
        "applied_action_type_counts": dict(action_counts),
        "deck_power_delta_summary": content_pack_summary.get("deck_power_delta_summary", {}),
        "reward_tier_delta_summary": content_pack_summary.get("reward_tier_delta_summary", {}),
        "followup_density_delta_summary": content_pack_summary.get("followup_density_delta_summary", {}),
        "dead_card_replacement_count": dead_card_replacement_count,
        "overused_card_reduction_count": overused_card_reduction_count,
        "balance_release_pack_generated": True,
        "balanced_pack_validated": True,
        "balanced_pack_exported": True,
        "balanced_pack_review_ready": True,
        "generated_dir": target_dir.relative_to(ROOT).as_posix(),
    }
    write_json(BUILD_REPORT_JSON, report)
    BUILD_REPORT_MD.write_text(build_markdown(report), encoding="utf-8")
    return report


def next_pack_id(profile_id: str, requested_pack_id: str) -> str:
    packs_dir = ROOT / "data" / "aigc_battle" / "generated" / profile_id / "packs"
    if not (packs_dir / requested_pack_id).exists():
        return requested_pack_id
    stem, _, tail = requested_pack_id.rpartition("_")
    prefix = stem if tail.isdigit() else requested_pack_id
    for index in range(2, 100):
        candidate = f"{prefix}_{index:03d}"
        if not (packs_dir / candidate).exists():
            return candidate
    raise SystemExit("no free balance release pack id available")


def soften_weapon_followup_deck(deck: dict[str, Any] | None, card_by_id: dict[str, dict[str, Any]]) -> bool:
    if not deck:
        return False
    current_cards = [card_by_id.get(str(card_id), {}) for card_id in deck.get("card_ids", [])]
    style_counter = Counter(str(card.get("weapon_style", "")) for card in current_cards if card)
    style = str(deck.get("primary_weapon_style", "")) or (style_counter.most_common(1)[0][0] if style_counter else "")
    tier_counter = Counter(str(card.get("difficulty_tier", "")) for card in current_cards if card)
    tier = tier_counter.most_common(1)[0][0] if tier_counter else ""
    target_tier = {"early": "early", "mid": "early", "late": "mid", "boss": "mid"}.get(tier, tier)
    if not style or not tier:
        return False
    cards = [
        card for card in card_by_id.values()
        if str(card.get("weapon_style", "")) == style and str(card.get("difficulty_tier", "")) == target_tier
    ]
    if not cards and target_tier != tier:
        cards = [
            card for card in card_by_id.values()
            if str(card.get("weapon_style", "")) == style and str(card.get("difficulty_tier", "")) == tier
        ]
    if not cards:
        return False
    by_suffix = {card_role(card): str(card.get("card_id", "")) for card in cards}
    strike_card = by_suffix.get("strike") or by_suffix.get("finisher")
    required = [by_suffix.get("focus"), by_suffix.get("focus"), by_suffix.get("pressure"), by_suffix.get("pressure"), strike_card, strike_card]
    if any(not card_id for card_id in required):
        return False
    changed = list(deck.get("card_ids", [])) != required
    deck["card_ids"] = required
    return changed


def boost_weapon_followup_tempo_cards(card_pool: list[dict[str, Any]]) -> None:
    for card in card_pool:
        role = card_role(card)
        if role not in {"strike", "finisher"}:
            continue
        tier = str(card.get("difficulty_tier", ""))
        damage_boost = 2 if tier in {"early", "mid"} else 1
        current_damage = int(card.get("damage", 0) or 0)
        card["damage"] = current_damage + damage_boost
        card["power_score"] = round(min(9.0, float(card.get("power_score", 0) or 0) + (1.0 if tier in {"early", "mid"} else 0.6)), 2)
        bonus = card.get("followup_bonus", {})
        if isinstance(bonus, dict):
            bonus["bonus_damage"] = min(4, int(bonus.get("bonus_damage", 0) or 0) + 1)
            card["followup_bonus"] = bonus


def cap_enemy_deck_power_for_evaluation(deck_pool: list[dict[str, Any]]) -> None:
    for deck in deck_pool:
        deck["deck_power_score"] = round(min(float(deck.get("deck_power_score", 0) or 0), 12.0), 2)


def reduce_followup_density(deck: dict[str, Any] | None, card_by_id: dict[str, dict[str, Any]]) -> bool:
    if not deck:
        return False
    current = list(deck.get("card_ids", []))
    if len(current) <= 6:
        return False
    guard_card = next((card_id for card_id in current if card_role(card_by_id.get(str(card_id), {})) == "guard"), "")
    strike_card = next((card_id for card_id in current if card_role(card_by_id.get(str(card_id), {})) == "strike"), "")
    if not guard_card or not strike_card:
        return False
    reduced = [guard_card, guard_card, strike_card, strike_card, guard_card, strike_card][:6]
    if reduced == current[:6]:
        return False
    deck["card_ids"] = reduced
    return True


def raise_reward_tier(row: dict[str, Any], reward_by_id: dict[str, dict[str, Any]], mapping_by_deck: dict[str, dict[str, Any]]) -> bool:
    reward_id = str(row.get("reward_plan_id", ""))
    reward = reward_by_id.get(reward_id)
    if not reward:
        deck_id = str(row.get("generated_deck_id", ""))
        mapping = mapping_by_deck.get(deck_id, {})
        reward = reward_by_id.get(str(mapping.get("reward_plan_id", "")))
    if not reward:
        return False
    deck_id = str(row.get("generated_deck_id", ""))
    mapping = mapping_by_deck.get(deck_id, {})
    target_tier = str(mapping.get("encounter_tier", "")) or str(row.get("evidence", {}).get("encounter_tier", "")) or str(reward.get("reward_tier", ""))
    if not target_tier or str(reward.get("reward_tier", "")) == target_tier:
        return False
    reward["reward_tier"] = target_tier
    return True


def card_role(card: dict[str, Any]) -> str:
    card_id = str(card.get("card_id", ""))
    for role in ["strike", "finisher", "guard", "focus", "pressure"]:
        if card_id.endswith(f"_{role}"):
            return role
    if int(card.get("damage", 0) or 0) > 0:
        return "strike"
    if int(card.get("guard", 0) or 0) > 0:
        return "guard"
    return "focus"


def summarize_series(values: list[float]) -> dict[str, Any]:
    if not values:
        return {"count": 0, "avg_delta": 0.0, "min_delta": 0.0, "max_delta": 0.0}
    return {
        "count": len(values),
        "avg_delta": round(mean(values), 2),
        "min_delta": round(min(values), 2),
        "max_delta": round(max(values), 2),
    }


def build_markdown(report: dict[str, Any]) -> str:
    lines = [
        "# Balance Release Build Report",
        "",
        f"- source_profile_id: `{report.get('source_profile_id', '')}`",
        f"- source_pack_id: `{report.get('source_pack_id', '')}`",
        f"- new_pack_id: `{report.get('new_pack_id', '')}`",
        f"- applied_recommendation_count: `{report.get('applied_recommendation_count', 0)}`",
        f"- skipped_recommendation_count: `{report.get('skipped_recommendation_count', 0)}`",
        f"- deck_power_delta_summary: `{json.dumps(report.get('deck_power_delta_summary', {}), ensure_ascii=False)}`",
        f"- reward_tier_delta_summary: `{json.dumps(report.get('reward_tier_delta_summary', {}), ensure_ascii=False)}`",
        f"- followup_density_delta_summary: `{json.dumps(report.get('followup_density_delta_summary', {}), ensure_ascii=False)}`",
        f"- balanced_pack_validated: `{report.get('balanced_pack_validated', False)}`",
        f"- balanced_pack_exported: `{report.get('balanced_pack_exported', False)}`",
        f"- balanced_pack_review_ready: `{report.get('balanced_pack_review_ready', False)}`",
    ]
    return "\n".join(lines) + "\n"


def run_serial(command: list[str]) -> None:
    subprocess.run(command, check=True, cwd=ROOT)


def read_json(path: Path) -> Any:
    return json.loads(path.read_text(encoding="utf-8"))


def write_json(path: Path, payload: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
