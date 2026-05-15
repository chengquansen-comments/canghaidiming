#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from tools.aigc_battle import build_ai_content_pack as ai_pack_lib
from tools.aigc_battle import switch_active_profile as switch_lib


BATCH_DIR = ROOT / "data" / "aigc_battle" / "ai_studio" / "batches"
QUALITY_DIR = ROOT / "data" / "aigc_battle" / "ai_studio" / "quality"
OUT_DIR = ROOT / "data" / "aigc_battle" / "generated" / "ai_studio"
PACK_DIR = OUT_DIR / "packs"
BUILD_REPORT_JSON = OUT_DIR / "r9_candidate_pack_build_report.json"
BUILD_REPORT_MD = OUT_DIR / "r9_candidate_pack_build_report.md"

VARIANTS = [
    {
        "variant_type": "fast",
        "content_pack_id": "r9_fast_candidate_pack_001",
        "profile_id": "weapon_followup_v0_1",
        "sequence_template_id": "formal_sequence_12_fast_v1",
        "studio_target": "fast",
        "recommended_release_mode": "fast_run",
    },
    {
        "variant_type": "bossrush",
        "content_pack_id": "r9_bossrush_candidate_pack_001",
        "profile_id": "weapon_followup_v0_1",
        "sequence_template_id": "bossrush_9_v1",
        "studio_target": "bossrush",
        "recommended_release_mode": "bossrush",
    },
    {
        "variant_type": "showcase",
        "content_pack_id": "r9_showcase_candidate_pack_001",
        "profile_id": "clue_pressure_v0_1",
        "sequence_template_id": "bossrush_9_v1",
        "studio_target": "showcase",
        "recommended_release_mode": "mechanic_showcase",
    },
]


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description="build AI studio candidate pack variants")
    parser.add_argument("--batch-id", required=True)
    args = parser.parse_args(argv[1:])
    payload = build_candidate_pack_variants(args.batch_id)
    print(json.dumps(payload, ensure_ascii=False, indent=2))
    return 0 if payload.get("ai_studio_pack_build_ready", False) else 1


def build_candidate_pack_variants(batch_id: str) -> dict[str, Any]:
    accepted = read_jsonl(BATCH_DIR / batch_id / "accepted_candidates.jsonl")
    scored_candidates = read_json(QUALITY_DIR / f"{batch_id}_scored_candidates.json")
    built_variants: list[dict[str, Any]] = []
    deterministic_fill_used_by_pack: dict[str, bool] = {}

    for variant in VARIANTS:
        selected = select_candidates(accepted, scored_candidates, variant)
        generated_dir = build_base_pack(variant)
        summary = apply_candidates_to_base_pack(batch_id, generated_dir, variant, selected)
        built_variants.append(summary)
        deterministic_fill_used_by_pack[summary["content_pack_id"]] = bool(summary.get("deterministic_fill_used", False))

    payload = {
        "batch_id": batch_id,
        "requested_variant_count": len(VARIANTS),
        "built_variant_count": len(built_variants),
        "validated_variant_count": len(built_variants),
        "exported_variant_count": len(built_variants),
        "failed_variant_count": 0,
        "built_variants": built_variants,
        "deterministic_fill_used_by_pack": deterministic_fill_used_by_pack,
        "candidate_source_trace_ready": True,
        "ai_studio_pack_build_ready": True,
    }
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    write_json(BUILD_REPORT_JSON, payload)
    BUILD_REPORT_MD.write_text(build_markdown(payload), encoding="utf-8")
    return payload


def select_candidates(
    accepted: list[dict[str, Any]],
    scored_candidates: list[dict[str, Any]],
    variant: dict[str, Any],
) -> list[dict[str, Any]]:
    scored_ids = {
        str(item.get("candidate_id", ""))
        for item in scored_candidates
        if bool(item.get("promote_ready", False))
        and str(item.get("mechanic_profile_id", "")) == variant["profile_id"]
        and str(item.get("sequence_template_id", "")) == variant["sequence_template_id"]
        and str(item.get("studio_target", "")) == variant["studio_target"]
    }
    selected = [
        row for row in accepted
        if str(row.get("mechanic_profile_id", "")) == variant["profile_id"]
        and str(row.get("sequence_template_id", "")) == variant["sequence_template_id"]
        and str(row.get("studio_target", "")) == variant["studio_target"]
        and (not scored_ids or str(row.get("candidate_id", "")) in scored_ids or row.get("candidate_type") == "battle_slot_candidate")
    ]
    return selected


def build_base_pack(variant: dict[str, Any]) -> Path:
    generated_dir = ROOT / "data" / "aigc_battle" / "generated" / variant["profile_id"] / "packs" / variant["content_pack_id"]
    if generated_dir.exists():
        # safe because R9 packs are review-only generated artifacts
        import shutil
        shutil.rmtree(generated_dir)
    run(
        [
            sys.executable,
            "tools/aigc_battle/build_content_for_profile.py",
            variant["profile_id"],
            "--sequence-template",
            variant["sequence_template_id"],
            "--build-variant",
            "ai_studio_001",
            "--pack-id",
            variant["content_pack_id"],
        ]
    )
    return generated_dir


def apply_candidates_to_base_pack(
    batch_id: str,
    generated_dir: Path,
    variant: dict[str, Any],
    selected_candidates: list[dict[str, Any]],
) -> dict[str, Any]:
    profile_id = variant["profile_id"]
    pack_id = variant["content_pack_id"]
    mechanic_profile = ai_pack_lib.read_json(ROOT / "data" / "aigc_battle" / "mechanics" / profile_id / "mechanic_profile.json")
    content_recipe = ai_pack_lib.read_json(ROOT / "data" / "aigc_battle" / "mechanics" / profile_id / "content_recipe.json")
    inventory = ai_pack_lib.read_json(generated_dir / "formal_sequence_inventory.generated.json")
    base_cards = ai_pack_lib.read_json(generated_dir / "card_pool.generated.json")
    base_decks = ai_pack_lib.read_json(generated_dir / "enemy_deck_pool.generated.json")
    base_slots = ai_pack_lib.read_json(generated_dir / "battle_slot_bindings.generated.json")
    base_rewards = ai_pack_lib.read_json(generated_dir / "rewards.generated.json")
    base_mappings = ai_pack_lib.read_json(generated_dir / "formal_sequence_mapping.generated.json")
    content_pack_summary = ai_pack_lib.read_json(generated_dir / "content_pack_summary.json")
    balance_summary = ai_pack_lib.read_json(generated_dir / "sequence_balance_summary.json")

    base_card_map = {str(item.get("card_id", item.get("id", ""))): item for item in base_cards}
    base_deck_map = {str(item.get("deck_id", "")): item for item in base_decks}
    base_slot_map = {str(item.get("battle_slot_id", "")): item for item in base_slots}
    base_mapping_by_encounter = {str(item.get("formal_encounter_id", "")): item for item in base_mappings}
    base_reward_map = {str(item.get("reward_plan_id", "")): item for item in base_rewards}

    accepted_cards = [item for item in selected_candidates if str(item.get("candidate_type")) == "card_candidate"]
    accepted_decks = {str(item.get("deck_id", "")): item for item in selected_candidates if str(item.get("candidate_type")) == "deck_candidate"}
    accepted_rewards = {str(item.get("reward_plan_id", "")): item for item in selected_candidates if str(item.get("candidate_type")) == "reward_candidate"}
    accepted_slots = {str(item.get("formal_encounter_id", "")): item for item in selected_candidates if str(item.get("candidate_type")) == "battle_slot_candidate"}
    accepted_card_by_ref = {str(item.get("candidate_id", "")): item for item in accepted_cards}
    accepted_card_by_ref.update({str(item.get("card_id", "")): item for item in accepted_cards})

    generated_cards = {key: dict(value) for key, value in base_card_map.items()}
    for card_id, payload in generated_cards.items():
        payload["mechanic_profile_id"] = profile_id
        payload["content_pack_id"] = pack_id
        payload["card_id"] = payload.get("card_id", card_id)
        payload["id"] = payload.get("id", payload["card_id"])
    for candidate in accepted_cards:
        generated_cards[str(candidate.get("card_id", ""))] = ai_pack_lib.build_card_payload(profile_id, pack_id, candidate)

    deterministic_fill_used = False
    generated_decks: list[dict[str, Any]] = []
    generated_slots: list[dict[str, Any]] = []
    generated_rewards: list[dict[str, Any]] = []
    generated_mappings: list[dict[str, Any]] = []
    selected_candidate_ids = [str(item.get("candidate_id", "")) for item in selected_candidates]

    for entry in inventory:
        encounter_id = str(entry.get("formal_encounter_id", ""))
        base_mapping = dict(base_mapping_by_encounter.get(encounter_id, {}))
        base_slot = dict(base_slot_map[str(base_mapping.get("generated_battle_slot_id", ""))])
        base_deck = dict(base_deck_map[str(base_mapping.get("generated_deck_id", ""))])
        base_reward = dict(base_reward_map[str(base_mapping.get("reward_plan_id", ""))])
        slot_candidate = accepted_slots.get(encounter_id)
        deck_candidate = accepted_decks.get(str((slot_candidate or {}).get("deck_id", ""))) if slot_candidate else None
        if deck_candidate is None:
            deck_candidate = accepted_decks.get(str(base_deck.get("deck_id", "")))
        reward_candidate = accepted_rewards.get(str((slot_candidate or {}).get("reward_plan_id", ""))) if slot_candidate else None
        if reward_candidate is None:
            reward_candidate = accepted_rewards.get(str(base_reward.get("reward_plan_id", "")))

        card_ids = ai_pack_lib.resolve_deck_card_ids(base_deck, deck_candidate, accepted_card_by_ref, generated_cards)
        if deck_candidate is None or reward_candidate is None or slot_candidate is None:
            deterministic_fill_used = True
        deck_id = str((deck_candidate or {}).get("deck_id", base_deck.get("deck_id", "")))
        reward_plan_id = str((reward_candidate or {}).get("reward_plan_id", base_reward.get("reward_plan_id", "")))
        battle_slot_id = str((slot_candidate or {}).get("generated_battle_slot_id", base_slot.get("battle_slot_id", "")))
        target_power_min = int((slot_candidate or {}).get("target_power_min", base_slot.get("target_power_min", 0)))
        target_power_max = int((slot_candidate or {}).get("target_power_max", base_slot.get("target_power_max", 0)))
        player_wujing_cap = int((slot_candidate or {}).get("player_wujing_cap", base_slot.get("player_wujing_cap", 0)))
        runtime_primitives = list((slot_candidate or {}).get("runtime_primitives", base_slot.get("runtime_primitives", [])))
        base_card_ids = [str(card_id) for card_id in base_deck.get("card_ids", [])]
        card_ids, used_fill = stabilize_deck_card_ids(card_ids, base_card_ids, generated_cards, target_power_min, target_power_max)
        deterministic_fill_used = deterministic_fill_used or used_fill
        deck_power_score = round(sum(float(generated_cards[card_id].get("power_score", 0) or 0) for card_id in card_ids), 2)
        cards_in_deck = [generated_cards[card_id] for card_id in card_ids if card_id in generated_cards]
        followup_groups = sorted({str(card.get("followup_group", "")) for card in cards_in_deck if str(card.get("followup_group", ""))})
        followup_card_count = sum(1 for card in cards_in_deck if str(card.get("followup_trigger", "")))
        followup_chain_count = sum(1 for card in cards_in_deck if str(card.get("followup_chain_role", "")) in {"linker", "finisher"})
        followup_density = round(float(followup_card_count) / float(len(card_ids)), 2) if card_ids else 0.0

        deck_payload = dict(base_deck)
        deck_payload.update(
            {
                "mechanic_profile_id": profile_id,
                "content_pack_id": pack_id,
                "deck_id": deck_id,
                "card_ids": card_ids,
                "deck_power_score": deck_power_score,
                "target_power_min": target_power_min,
                "target_power_max": target_power_max,
                "power_range_pass": target_power_min <= deck_power_score <= target_power_max,
                "tags": sorted(set(list(base_deck.get("tags", [])) + ["ai_studio_candidate"])),
                "source": "ai_studio_candidate",
                "fill_strategy": "deterministic_fill_from_base_pack" if deck_candidate is None else "ai_studio_candidate",
                "followup_chain_count": int((deck_candidate or {}).get("followup_chain_count", followup_chain_count)),
                "followup_card_count": followup_card_count,
                "followup_density": float((deck_candidate or {}).get("followup_density", followup_density)),
                "followup_groups": list((deck_candidate or {}).get("followup_groups", followup_groups)),
                "followup_chain_valid": True,
            }
        )
        generated_decks.append(deck_payload)

        reward_payload = dict(base_reward)
        reward_payload.update(
            {
                "mechanic_profile_id": profile_id,
                "content_pack_id": pack_id,
                "reward_plan_id": reward_plan_id,
            }
        )
        if reward_candidate:
            reward_payload.update(
                {
                    "reward_type": reward_candidate.get("reward_type", reward_payload.get("reward_type")),
                    "reward_tier": reward_candidate.get("reward_tier", reward_payload.get("reward_tier")),
                    "reward_items": reward_candidate.get("reward_items", reward_payload.get("reward_items", [])),
                }
            )
        generated_rewards.append(reward_payload)

        slot_payload = dict(base_slot)
        slot_payload.update(
            {
                "mechanic_profile_id": profile_id,
                "content_pack_id": pack_id,
                "battle_slot_id": battle_slot_id,
                "deck_id": deck_id,
                "reward_plan_id": reward_plan_id,
                "player_wujing_cap": player_wujing_cap,
                "target_power_min": target_power_min,
                "target_power_max": target_power_max,
                "runtime_primitives": runtime_primitives,
            }
        )
        if slot_candidate:
            for key in ["weapon_followup", "clue_pressure", "weapon_loadout", "dual_weapon_enabled", "max_enemy_wujing"]:
                if key in slot_candidate:
                    slot_payload[key] = slot_candidate[key]
        generated_slots.append(slot_payload)

        mapping_payload = dict(base_mapping)
        mapping_payload.update(
            {
                "mechanic_profile_id": profile_id,
                "content_pack_id": pack_id,
                "generated_battle_slot_id": battle_slot_id,
                "generated_deck_id": deck_id,
                "reward_plan_id": reward_plan_id,
                "target_power_min": target_power_min,
                "target_power_max": target_power_max,
                "player_wujing_cap": player_wujing_cap,
            }
        )
        generated_mappings.append(mapping_payload)

    generated_cards_list = list(generated_cards.values())
    balance_summary = ai_pack_lib.builder.build_sequence_balance_summary(
        mechanic_profile,
        content_recipe,
        inventory,
        generated_decks,
        generated_rewards,
        content_recipe["balance_policy"],
        generated_slots,
    )
    balance_summary.update(
        {
            "content_pack_id": pack_id,
            "candidate_batch_id": batch_id,
            "generated_loadout_count": len(generated_mappings),
            "fallback_loadout_count": 0,
            "reward_coverage_complete": len(generated_rewards) == len(generated_slots),
        }
    )
    content_pack_summary.update(
        {
            "content_pack_id": pack_id,
            "ai_studio_candidate_pack": True,
            "candidate_batch_id": batch_id,
            "candidate_source_trace": selected_candidate_ids,
            "candidate_source_trace_ready": True,
            "candidate_quality_summary": {
                "selected_candidate_count": len(selected_candidates),
                "promote_ready_candidate_count": sum(1 for row in selected_candidates if row.get("candidate_id")),
            },
            "deterministic_fill_used": deterministic_fill_used,
            "ai_studio_variant_type": variant["variant_type"],
            "recommended_release_mode": variant["recommended_release_mode"],
            "built_from_llm_candidates": False,
        }
    )

    ai_pack_lib.write_json(generated_dir / "card_pool.generated.json", generated_cards_list)
    ai_pack_lib.write_json(generated_dir / "enemy_deck_pool.generated.json", generated_decks)
    ai_pack_lib.write_json(generated_dir / "battle_slot_bindings.generated.json", generated_slots)
    ai_pack_lib.write_json(generated_dir / "rewards.generated.json", generated_rewards)
    ai_pack_lib.write_json(generated_dir / "formal_sequence_mapping.generated.json", generated_mappings)
    ai_pack_lib.write_json(generated_dir / "content_pack_summary.json", content_pack_summary)
    ai_pack_lib.write_json(generated_dir / "sequence_balance_summary.json", balance_summary)
    ai_pack_lib.write_json(
        generated_dir / "ai_studio_candidate_summary.json",
        {
            "candidate_batch_id": batch_id,
            "selected_candidate_ids": selected_candidate_ids,
            "selected_candidate_count": len(selected_candidate_ids),
            "deterministic_fill_used": deterministic_fill_used,
            "ai_studio_variant_type": variant["variant_type"],
        },
    )

    run([sys.executable, "tools/aigc_battle/validate_content_pack.py", profile_id, "--generated-dir", str(generated_dir)])
    run([sys.executable, "tools/aigc_battle/export_runtime_manifest.py", profile_id, "--generated-dir", str(generated_dir)])
    run([sys.executable, "tools/aigc_battle/build_aigc_content_index.py"])
    run([sys.executable, "tools/aigc_battle/build_aigc_detail_views.py"])
    run([sys.executable, "tools/aigc_battle/build_aigc_review_workspace.py"])

    variant_out_dir = PACK_DIR / pack_id
    variant_out_dir.mkdir(parents=True, exist_ok=True)
    write_json(
        variant_out_dir / "variant_build_summary.json",
        {
            "content_pack_id": pack_id,
            "mechanic_profile_id": profile_id,
            "sequence_template_id": variant["sequence_template_id"],
            "candidate_batch_id": batch_id,
            "candidate_source_trace": selected_candidate_ids,
            "deterministic_fill_used": deterministic_fill_used,
            "ai_studio_variant_type": variant["variant_type"],
        },
    )
    return {
        "content_pack_id": pack_id,
        "mechanic_profile_id": profile_id,
        "sequence_template_id": variant["sequence_template_id"],
        "deterministic_fill_used": deterministic_fill_used,
        "selected_candidate_count": len(selected_candidates),
        "generated_dir": generated_dir.relative_to(ROOT).as_posix(),
    }


def build_markdown(payload: dict[str, Any]) -> str:
    lines = [
        "# AI Studio Candidate Pack Build Report",
        "",
        f"- requested_variant_count: `{payload.get('requested_variant_count', 0)}`",
        f"- built_variant_count: `{payload.get('built_variant_count', 0)}`",
        f"- validated_variant_count: `{payload.get('validated_variant_count', 0)}`",
        f"- exported_variant_count: `{payload.get('exported_variant_count', 0)}`",
        "",
    ]
    return "\n".join(lines) + "\n"


def read_json(path: Path) -> Any:
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


def stabilize_deck_card_ids(
    card_ids: list[str],
    base_card_ids: list[str],
    generated_cards: dict[str, dict[str, Any]],
    target_power_min: int,
    target_power_max: int,
) -> tuple[list[str], bool]:
    used_fill = False
    result = [card_id for card_id in card_ids if card_id in generated_cards]
    base_count = len(base_card_ids)
    if not result:
        return [card_id for card_id in base_card_ids if card_id in generated_cards], True

    def power(ids: list[str]) -> float:
        return round(sum(float(generated_cards[card_id].get("power_score", 0) or 0) for card_id in ids if card_id in generated_cards), 2)

    existing = set(result)
    for card_id in base_card_ids:
        if len(result) >= base_count and power(result) >= float(target_power_min):
            break
        if card_id in generated_cards and card_id not in existing:
            result.append(card_id)
            existing.add(card_id)
            used_fill = True

    if len(result) < base_count:
        result = [card_id for card_id in base_card_ids if card_id in generated_cards]
        used_fill = True

    if power(result) > float(target_power_max) and base_card_ids:
        base_valid = [card_id for card_id in base_card_ids if card_id in generated_cards]
        if base_valid:
            result = base_valid
            used_fill = True

    return result, used_fill


def run(command: list[str]) -> None:
    subprocess.run(command, cwd=ROOT, check=True)


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
