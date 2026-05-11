#!/usr/bin/env python3
from __future__ import annotations

import argparse
import importlib.util
import json
import shutil
import subprocess
import sys
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from tools.aigc_battle import aigc_release_gate as release_lib
from tools.aigc_battle import switch_active_profile as switch_lib


BUILD_SCRIPT_PATH = ROOT / "tools" / "aigc_battle" / "build_content_for_profile.py"
builder_spec = importlib.util.spec_from_file_location("aigc_build_module", BUILD_SCRIPT_PATH)
builder = importlib.util.module_from_spec(builder_spec)
assert builder_spec and builder_spec.loader
builder_spec.loader.exec_module(builder)


LLM_DIR = ROOT / "data" / "aigc_battle" / "llm_candidates"
AI_PRODUCTION_DIR = ROOT / "data" / "aigc_battle" / "generated" / "ai_production"


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description="build ai content pack from accepted llm candidates")
    parser.add_argument("--profile", required=True)
    parser.add_argument("--pack-id", required=True)
    args = parser.parse_args(argv[1:])
    profile_id = args.profile
    pack_id = args.pack_id
    switch_lib.ensure_safe_id(profile_id, "profile_id")
    switch_lib.ensure_safe_id(pack_id, "pack_id")
    if release_lib.release_manifest_path(profile_id, pack_id).exists():
        release_manifest = release_lib.get_release_status(profile_id, pack_id)
        if bool(release_manifest.get("frozen", False)):
            raise SystemExit("ai pack build blocked: frozen pack")
        if str(release_manifest.get("release_status", "")) == "archived":
            raise SystemExit("ai pack build blocked: archived pack")

    root_dir = switch_lib.resolve_generated_dir(profile_id)
    target_dir = switch_lib.resolve_generated_dir(profile_id, pack_id)
    if target_dir.exists():
        shutil.rmtree(target_dir)
    target_dir.mkdir(parents=True, exist_ok=True)

    accepted_path = LLM_DIR / profile_id / "accepted_candidates.jsonl"
    import_report_path = ROOT / "data" / "aigc_battle" / "generated" / "ai_production" / "import_reports" / f"{profile_id}__candidate_import_report.json"
    diff_report_path = ROOT / "data" / "aigc_battle" / "generated" / "ai_production" / "diff" / f"{profile_id}__candidate_diff.json"
    if not accepted_path.exists():
        raise SystemExit("accepted_candidates.jsonl not found")
    accepted = read_jsonl(accepted_path)
    import_report = read_json(import_report_path)
    diff_report = read_json(diff_report_path)

    mechanic_profile = read_json(ROOT / "data" / "aigc_battle" / "mechanics" / profile_id / "mechanic_profile.json")
    content_recipe = read_json(ROOT / "data" / "aigc_battle" / "mechanics" / profile_id / "content_recipe.json")
    inventory = read_json(root_dir / "formal_sequence_inventory.generated.json")
    base_cards = read_json(root_dir / "card_pool.generated.json")
    base_decks = read_json(root_dir / "enemy_deck_pool.generated.json")
    base_slots = read_json(root_dir / "battle_slot_bindings.generated.json")
    base_rewards = read_json(root_dir / "rewards.generated.json")
    base_mappings = read_json(root_dir / "formal_sequence_mapping.generated.json")
    base_card_map = {str(item.get("card_id", item.get("id", ""))): item for item in base_cards}
    base_deck_map = {str(item.get("deck_id", "")): item for item in base_decks}
    base_slot_map = {str(item.get("battle_slot_id", "")): item for item in base_slots}
    base_mapping_by_encounter = {str(item.get("formal_encounter_id", "")): item for item in base_mappings}
    base_reward_map = {str(item.get("reward_plan_id", "")): item for item in base_rewards}

    accepted_cards = [item for item in accepted if str(item.get("candidate_type")) == "card_candidate"]
    accepted_decks = {str(item.get("deck_id", "")): item for item in accepted if str(item.get("candidate_type")) == "deck_candidate"}
    accepted_rewards = {str(item.get("reward_plan_id", "")): item for item in accepted if str(item.get("candidate_type")) == "reward_candidate"}
    accepted_slots = {str(item.get("formal_encounter_id", "")): item for item in accepted if str(item.get("candidate_type")) == "battle_slot_candidate"}
    accepted_card_by_ref = {str(item.get("candidate_id", "")): item for item in accepted_cards}
    accepted_card_by_ref.update({str(item.get("card_id", "")): item for item in accepted_cards})

    generated_cards = {key: dict(value) for key, value in base_card_map.items()}
    for card_id, payload in generated_cards.items():
        payload["mechanic_profile_id"] = profile_id
        payload["content_pack_id"] = pack_id
        payload["card_id"] = payload.get("card_id", card_id)
        payload["id"] = payload.get("id", payload["card_id"])
    for candidate in accepted_cards:
        card_id = str(candidate.get("card_id", ""))
        card_payload = build_card_payload(profile_id, pack_id, candidate)
        generated_cards[card_id] = card_payload

    deterministic_fill_used = False
    generated_decks: list[dict[str, Any]] = []
    generated_slots: list[dict[str, Any]] = []
    generated_rewards: list[dict[str, Any]] = []
    generated_mappings: list[dict[str, Any]] = []
    adjusted_or_flagged_encounters: list[dict[str, Any]] = []

    for entry in inventory:
        encounter_id = str(entry.get("formal_encounter_id", ""))
        base_mapping = dict(base_mapping_by_encounter.get(encounter_id, {}))
        if not base_mapping:
            raise SystemExit(f"base mapping missing: {encounter_id}")
        base_slot = dict(base_slot_map[str(base_mapping.get("generated_battle_slot_id", ""))])
        base_deck = dict(base_deck_map[str(base_mapping.get("generated_deck_id", ""))])
        base_reward = dict(base_reward_map[str(base_mapping.get("reward_plan_id", ""))])
        slot_candidate = accepted_slots.get(encounter_id)
        deck_candidate = accepted_decks.get(str(slot_candidate.get("deck_id", ""))) if slot_candidate else None
        if deck_candidate is None:
            deck_candidate = accepted_decks.get(str(base_deck.get("deck_id", "")))
        reward_candidate = accepted_rewards.get(str(slot_candidate.get("reward_plan_id", ""))) if slot_candidate else None
        if reward_candidate is None:
            reward_candidate = accepted_rewards.get(str(base_reward.get("reward_plan_id", "")))

        card_ids = resolve_deck_card_ids(base_deck, deck_candidate, accepted_card_by_ref, generated_cards)
        if deck_candidate is None:
            deterministic_fill_used = True
            adjusted_or_flagged_encounters.append({"formal_encounter_id": encounter_id, "reason": "deterministic_fill_deck"})
        elif any(card_id in base_card_map and card_id not in {str(item.get("card_id", "")) for item in accepted_cards} for card_id in card_ids):
            deterministic_fill_used = True
            adjusted_or_flagged_encounters.append({"formal_encounter_id": encounter_id, "reason": "deterministic_fill_partial_cards"})

        deck_id = str((deck_candidate or {}).get("deck_id", base_deck.get("deck_id", "")))
        reward_plan_id = str((reward_candidate or {}).get("reward_plan_id", base_reward.get("reward_plan_id", "")))
        battle_slot_id = str((slot_candidate or {}).get("generated_battle_slot_id", base_slot.get("battle_slot_id", "")))
        target_power_min = int((slot_candidate or {}).get("target_power_min", base_slot.get("target_power_min", 0)))
        target_power_max = int((slot_candidate or {}).get("target_power_max", base_slot.get("target_power_max", 0)))
        player_wujing_cap = int((slot_candidate or {}).get("player_wujing_cap", base_slot.get("player_wujing_cap", 0)))
        runtime_primitives = list((slot_candidate or {}).get("runtime_primitives", base_slot.get("runtime_primitives", [])))
        deck_power_score = round(sum(float(generated_cards[card_id].get("power_score", 0) or 0) for card_id in card_ids), 2)
        cards_in_deck = [generated_cards[card_id] for card_id in card_ids if card_id in generated_cards]
        followup_groups = sorted({str(card.get("followup_group", "")) for card in cards_in_deck if str(card.get("followup_group", ""))})
        followup_card_count = sum(1 for card in cards_in_deck if str(card.get("followup_trigger", "")))
        followup_chain_count = sum(1 for card in cards_in_deck if str(card.get("followup_chain_role", "")) in {"linker", "finisher"})
        followup_density = round(float(followup_card_count) / float(len(card_ids)), 2) if card_ids else 0.0

        deck_payload = dict(base_deck)
        deck_payload.update({
            "mechanic_profile_id": profile_id,
            "content_pack_id": pack_id,
            "deck_id": deck_id,
            "card_ids": card_ids,
            "deck_power_score": deck_power_score,
            "target_power_min": target_power_min,
            "target_power_max": target_power_max,
            "power_range_pass": target_power_min <= deck_power_score <= target_power_max,
            "tags": sorted(set(list(base_deck.get("tags", [])) + ["llm_candidate_import"])),
            "source": "llm_candidate_import",
            "fill_strategy": "deterministic_fill_from_current_pack" if deck_candidate is None else "llm_candidate_import",
            "followup_chain_count": int(deck_candidate.get("followup_chain_count", followup_chain_count)) if deck_candidate else followup_chain_count,
            "followup_card_count": followup_card_count,
            "followup_density": float(deck_candidate.get("followup_density", followup_density)) if deck_candidate else followup_density,
            "followup_groups": list(deck_candidate.get("followup_groups", followup_groups)) if deck_candidate else followup_groups,
            "followup_chain_valid": True,
        })
        generated_decks.append(deck_payload)

        reward_payload = dict(base_reward)
        reward_payload.update({
            "mechanic_profile_id": profile_id,
            "content_pack_id": pack_id,
            "reward_plan_id": reward_plan_id,
            "source": {
                **dict(base_reward.get("source", {})),
                "content_source": "llm_candidate_import" if reward_candidate else dict(base_reward.get("source", {})).get("content_source", "generated"),
            },
        })
        if reward_candidate:
            reward_payload.update({
                "reward_type": reward_candidate.get("reward_type", reward_payload.get("reward_type")),
                "reward_tier": reward_candidate.get("reward_tier", reward_payload.get("reward_tier")),
                "reward_items": reward_candidate.get("reward_items", reward_payload.get("reward_items", [])),
            })
        else:
            deterministic_fill_used = True
        generated_rewards.append(reward_payload)

        slot_payload = dict(base_slot)
        slot_payload.update({
            "mechanic_profile_id": profile_id,
            "content_pack_id": pack_id,
            "battle_slot_id": battle_slot_id,
            "deck_id": deck_id,
            "reward_plan_id": reward_plan_id,
            "player_wujing_cap": player_wujing_cap,
            "target_power_min": target_power_min,
            "target_power_max": target_power_max,
            "runtime_primitives": runtime_primitives,
            "source": {
                **dict(base_slot.get("source", {})),
                "content_source": "llm_candidate_import" if slot_candidate else dict(base_slot.get("source", {})).get("content_source", "generated"),
            },
        })
        generated_slots.append(slot_payload)

        mapping_payload = dict(base_mapping)
        mapping_payload.update({
            "mechanic_profile_id": profile_id,
            "content_pack_id": pack_id,
            "generated_battle_slot_id": battle_slot_id,
            "generated_deck_id": deck_id,
            "reward_plan_id": reward_plan_id,
            "target_power_min": target_power_min,
            "target_power_max": target_power_max,
            "player_wujing_cap": player_wujing_cap,
        })
        generated_mappings.append(mapping_payload)

    generated_cards_list = list(generated_cards.values())
    balance_summary = builder.build_sequence_balance_summary(
        mechanic_profile,
        content_recipe,
        inventory,
        generated_decks,
        generated_rewards,
        content_recipe["balance_policy"],
        generated_slots,
    )
    balance_summary["content_pack_id"] = pack_id
    content_pack_summary = {
        "mechanic_profile_id": profile_id,
        "content_pack_id": pack_id,
        "target_sequence_id": content_recipe["target_sequence_id"],
        "formal_encounter_total_count": len(inventory),
        "generated_battle_slot_count": len(generated_slots),
        "generated_deck_count": len(generated_decks),
        "generated_card_count": len(generated_cards_list),
        "generated_reward_count": len(generated_rewards),
        "replacement_mode": content_recipe["replacement_mode"],
        "content_source": "llm_candidate_import",
        "llm_candidate_source": True,
        "candidate_import_report_path": to_relative(import_report_path),
        "candidate_diff_report_path": to_relative(diff_report_path),
        "accepted_candidate_count": int(import_report.get("accepted_candidate_count", 0)),
        "rejected_candidate_count": int(import_report.get("rejected_candidate_count", 0)),
        "deterministic_fill_used": deterministic_fill_used,
        "candidate_source_trace_ready": True,
        "ai_pack_ready_for_review": True,
        "built_from_llm_candidates": True,
    }

    write_json(target_dir / "formal_sequence_inventory.generated.json", inventory)
    write_json(target_dir / "card_pool.generated.json", generated_cards_list)
    write_json(target_dir / "enemy_deck_pool.generated.json", generated_decks)
    write_json(target_dir / "battle_slot_bindings.generated.json", generated_slots)
    write_json(target_dir / "rewards.generated.json", generated_rewards)
    write_json(target_dir / "formal_sequence_mapping.generated.json", generated_mappings)
    write_json(target_dir / "content_pack_summary.json", content_pack_summary)
    write_json(target_dir / "sequence_balance_summary.json", balance_summary)
    write_json(target_dir / "imported_candidate_summary.json", build_imported_candidate_summary(import_report, accepted_cards))
    builder.write_markdown_balance_summary(target_dir / "sequence_balance_summary.md", balance_summary)

    run([sys.executable, str(ROOT / "tools" / "aigc_battle" / "validate_content_pack.py"), profile_id, "--generated-dir", str(target_dir)])
    run([sys.executable, str(ROOT / "tools" / "aigc_battle" / "export_runtime_manifest.py"), profile_id, "--generated-dir", str(target_dir)])
    run([sys.executable, str(ROOT / "tools" / "aigc_battle" / "build_aigc_content_index.py")])
    run([sys.executable, str(ROOT / "tools" / "aigc_battle" / "build_aigc_detail_views.py")])
    run([sys.executable, str(ROOT / "tools" / "aigc_battle" / "build_aigc_review_workspace.py")])

    validation_report = read_json(target_dir / "validation_report.json")
    ai_report = {
        "mechanic_profile_id": profile_id,
        "ai_pack_id": pack_id,
        "built_from_llm_candidates": True,
        "deterministic_fill_used": deterministic_fill_used,
        "accepted_candidate_count": int(import_report.get("accepted_candidate_count", 0)),
        "rejected_candidate_count": int(import_report.get("rejected_candidate_count", 0)),
        "candidate_import_report_path": to_relative(import_report_path),
        "candidate_diff_report_path": to_relative(diff_report_path),
        "adjusted_or_flagged_encounters": adjusted_or_flagged_encounters,
        "ai_pack_validated": bool(validation_report.get("ready_for_runtime_export", False)),
        "ai_pack_exported": (target_dir / "runtime_manifest.json").exists(),
        "ai_pack_ready_for_review": True,
    }
    write_json(target_dir / "ai_candidate_build_report.json", ai_report)
    write_markdown(target_dir / "ai_candidate_build_report.md", ai_report)
    print(json.dumps(ai_report, ensure_ascii=False, indent=2))
    return 0


def build_card_payload(profile_id: str, pack_id: str, candidate: dict[str, Any]) -> dict[str, Any]:
    payload = {
        "mechanic_profile_id": profile_id,
        "content_pack_id": pack_id,
        "card_id": candidate["card_id"],
        "id": candidate["card_id"],
        "candidate_id": candidate.get("candidate_id", ""),
        "name": candidate.get("name", ""),
        "display_name": candidate.get("name", ""),
        "card_type": candidate.get("card_type", ""),
        "weapon_style": candidate.get("weapon_style", ""),
        "cost": int(candidate.get("cost", 0)),
        "effects": candidate.get("effects", []),
        "tags": candidate.get("tags", []),
        "difficulty_tier": candidate.get("difficulty_tier", ""),
        "power_score": float(candidate.get("power_score", 0) or 0),
        "required_wujing": int(candidate.get("required_wujing", 0)),
        "closing_form_tier": int(candidate.get("closing_form_tier", 0)),
        "runtime_effects": candidate.get("runtime_effects", []),
        "followup_group": candidate.get("followup_group", ""),
        "followup_trigger": candidate.get("followup_trigger", ""),
        "followup_bonus": candidate.get("followup_bonus", {}),
        "followup_chain_role": candidate.get("followup_chain_role", ""),
        "llm_candidate_source": True,
        "source": "llm_candidate_import",
    }
    return payload


def build_imported_candidate_summary(import_report: dict[str, Any], accepted_cards: list[dict[str, Any]]) -> dict[str, Any]:
    rejected_by_type = import_report.get("rejected_by_type", {})
    rejected_path = ROOT / str(import_report.get("rejected_candidates_path", ""))
    rejected_rows = read_jsonl(rejected_path) if rejected_path.exists() else []
    rejected_card_ids = [
        str(row.get("card_id", ""))
        for row in rejected_rows
        if str(row.get("candidate_type", "")) == "card_candidate" and str(row.get("card_id", "")).strip()
    ]
    return {
        "import_ready_for_validation": bool(import_report.get("ready_for_ai_pack_build", False)),
        "accepted_card_candidate_ids": [str(card.get("candidate_id", "")) for card in accepted_cards if str(card.get("candidate_id", "")).strip()],
        "rejected_card_candidate_count": int(rejected_by_type.get("card_candidate", 0)),
        "rejected_deck_candidate_count": int(rejected_by_type.get("deck_candidate", 0)),
        "rejected_card_candidate_ids": rejected_card_ids,
    }


def resolve_deck_card_ids(
    base_deck: dict[str, Any],
    deck_candidate: dict[str, Any] | None,
    accepted_card_by_ref: dict[str, dict[str, Any]],
    generated_cards: dict[str, dict[str, Any]],
) -> list[str]:
    if not deck_candidate:
        return [str(card_id) for card_id in base_deck.get("card_ids", [])]
    card_ids: list[str] = []
    for ref in deck_candidate.get("card_refs", []):
        ref = str(ref)
        if ref in accepted_card_by_ref:
            card_ids.append(str(accepted_card_by_ref[ref]["card_id"]))
        elif ref in generated_cards:
            card_ids.append(ref)
    if not card_ids:
        return [str(card_id) for card_id in base_deck.get("card_ids", [])]
    return card_ids


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


def write_markdown(path: Path, report: dict[str, Any]) -> None:
    lines = [
        "# AI Candidate Build Report",
        "",
        f"- ai_pack_id: {report['ai_pack_id']}",
        f"- built_from_llm_candidates: {str(report['built_from_llm_candidates']).lower()}",
        f"- deterministic_fill_used: {str(report['deterministic_fill_used']).lower()}",
        f"- ai_pack_validated: {str(report['ai_pack_validated']).lower()}",
        f"- ai_pack_exported: {str(report['ai_pack_exported']).lower()}",
        f"- ai_pack_ready_for_review: {str(report['ai_pack_ready_for_review']).lower()}",
    ]
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def run(cmd: list[str]) -> None:
    completed = subprocess.run(cmd, cwd=ROOT, capture_output=True, text=True)
    if completed.returncode != 0:
        raise SystemExit((completed.stderr or completed.stdout or "command failed").strip())


def to_relative(path: Path) -> str:
    return path.relative_to(ROOT).as_posix()


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
