#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import sys
from collections import Counter
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from tools.aigc_battle import build_aigc_detail_views as detail_lib
from tools.aigc_battle import build_aigc_review_workspace as review_lib
from tools.aigc_battle import switch_active_profile as switch_lib


LLM_DIR = ROOT / "data" / "aigc_battle" / "llm_candidates"
DIFF_DIR = ROOT / "data" / "aigc_battle" / "generated" / "ai_production" / "diff"


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description="diff accepted llm candidates vs current pack")
    parser.add_argument("--profile", required=True)
    parser.add_argument("--pack", required=True)
    args = parser.parse_args(argv[1:])
    profile_id = args.profile
    content_pack_id = args.pack
    switch_lib.ensure_safe_id(profile_id, "profile_id")
    switch_lib.ensure_safe_id(content_pack_id, "content_pack_id")

    accepted = read_jsonl(LLM_DIR / profile_id / "accepted_candidates.jsonl")
    pack_detail = read_json(detail_lib.detail_pack_json_path(profile_id, content_pack_id))
    pack_review = read_json(review_lib.pack_review_json_path(profile_id, content_pack_id))
    existing_cards = {str(item.get("card_id", "")): item for item in pack_detail.get("card_pool_detail", [])}
    existing_decks = {str(item.get("deck_id", "")): item for item in pack_review.get("deck_review_table", [])}
    existing_rewards = {str(item.get("reward_plan_id", "")): item for item in pack_review.get("reward_review_table", [])}

    new_card_count = changed_card_count = new_deck_count = changed_deck_count = new_reward_count = changed_reward_count = 0
    weapon_style_delta = Counter()
    card_type_delta = Counter()
    effect_type_delta = Counter()
    realm_requirement_delta = Counter()
    followup_chain_delta = {"new_followup_cards": 0, "new_followup_decks": 0}
    power_delta: list[dict[str, Any]] = []

    for item in accepted:
        kind = str(item.get("candidate_type", ""))
        if kind == "card_candidate":
            card_id = str(item.get("card_id", ""))
            if card_id in existing_cards:
                changed_card_count += 1
            else:
                new_card_count += 1
            weapon_style_delta[str(item.get("weapon_style", ""))] += 1
            card_type_delta[str(item.get("card_type", ""))] += 1
            for effect in item.get("runtime_effects", []):
                effect_type_delta[str(effect)] += 1
            realm_requirement_delta[f"w{item.get('required_wujing', 0)}_c{item.get('closing_form_tier', 0)}"] += 1
            if item.get("followup_trigger"):
                followup_chain_delta["new_followup_cards"] += 1
        elif kind == "deck_candidate":
            deck_id = str(item.get("deck_id", ""))
            if deck_id in existing_decks:
                changed_deck_count += 1
                power_delta.append({
                    "deck_id": deck_id,
                    "before": float(existing_decks[deck_id].get("deck_power_score", 0) or 0),
                    "after": float(item.get("deck_power_score", 0) or 0),
                })
            else:
                new_deck_count += 1
            if item.get("followup_chain_count", 0):
                followup_chain_delta["new_followup_decks"] += 1
        elif kind == "reward_candidate":
            reward_id = str(item.get("reward_plan_id", ""))
            if reward_id in existing_rewards:
                changed_reward_count += 1
            else:
                new_reward_count += 1

    removed_card_count = 0
    diff = {
        "mechanic_profile_id": profile_id,
        "content_pack_id": content_pack_id,
        "new_card_count": new_card_count,
        "changed_card_count": changed_card_count,
        "removed_card_count": removed_card_count,
        "new_deck_count": new_deck_count,
        "changed_deck_count": changed_deck_count,
        "new_reward_count": new_reward_count,
        "changed_reward_count": changed_reward_count,
        "power_delta_summary": summarize_power_delta(power_delta),
        "weapon_style_delta": dict(weapon_style_delta),
        "card_type_delta": dict(card_type_delta),
        "effect_type_delta": dict(effect_type_delta),
        "realm_requirement_delta": dict(realm_requirement_delta),
        "followup_chain_delta": followup_chain_delta,
        "risk_delta_prediction": build_risk_delta_prediction(accepted, changed_card_count, changed_deck_count),
        "candidate_diff_ready": True,
    }
    write_json(diff_json_path(profile_id), diff)
    write_markdown(diff_md_path(profile_id), diff)
    print(json.dumps(diff, ensure_ascii=False, indent=2))
    return 0


def summarize_power_delta(rows: list[dict[str, Any]]) -> dict[str, Any]:
    if not rows:
        return {"changed_deck_count": 0, "avg_delta": 0.0, "max_increase": 0.0, "max_decrease": 0.0}
    deltas = [round(item["after"] - item["before"], 2) for item in rows]
    return {
        "changed_deck_count": len(rows),
        "avg_delta": round(sum(deltas) / len(deltas), 2),
        "max_increase": max(deltas),
        "max_decrease": min(deltas),
        "rows": rows,
    }


def build_risk_delta_prediction(accepted: list[dict[str, Any]], changed_card_count: int, changed_deck_count: int) -> dict[str, Any]:
    warnings: list[str] = []
    if any(item.get("warnings") for item in accepted):
        warnings.append("candidate_import_warnings_present")
    if changed_deck_count > 0:
        warnings.append("deck_balance_shift_expected")
    if changed_card_count > 0:
        warnings.append("card_pool_behavior_shift_expected")
    if any(str(item.get("candidate_type")) == "battle_slot_candidate" for item in accepted):
        warnings.append("slot_binding_shift_expected")
    return {"predicted_warning_flags": warnings, "risk_count": len(warnings)}


def diff_json_path(profile_id: str) -> Path:
    return DIFF_DIR / f"{profile_id}__candidate_diff.json"


def diff_md_path(profile_id: str) -> Path:
    return DIFF_DIR / f"{profile_id}__candidate_diff.md"


def read_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def read_jsonl(path: Path) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    for line in path.read_text(encoding="utf-8").splitlines():
        clean = line.strip()
        if clean:
            rows.append(json.loads(clean))
    return rows


def write_json(path: Path, payload: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def write_markdown(path: Path, diff: dict[str, Any]) -> None:
    lines = [
        "# Candidate Diff",
        "",
        f"- new_card_count: {diff['new_card_count']}",
        f"- changed_card_count: {diff['changed_card_count']}",
        f"- new_deck_count: {diff['new_deck_count']}",
        f"- changed_deck_count: {diff['changed_deck_count']}",
        f"- new_reward_count: {diff['new_reward_count']}",
        f"- changed_reward_count: {diff['changed_reward_count']}",
        f"- candidate_diff_ready: {str(diff['candidate_diff_ready']).lower()}",
    ]
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
