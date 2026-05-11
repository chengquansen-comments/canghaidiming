#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import sys
from collections import Counter, defaultdict
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from tools.aigc_battle import switch_active_profile as switch_lib


LLM_DIR = ROOT / "data" / "aigc_battle" / "llm_candidates"
REPORT_DIR = ROOT / "data" / "aigc_battle" / "generated" / "ai_production" / "import_reports"


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description="import llm production candidates")
    parser.add_argument("--profile", required=True)
    parser.add_argument("--input", required=True)
    args = parser.parse_args(argv[1:])
    profile_id = args.profile
    switch_lib.ensure_safe_id(profile_id, "profile_id")
    input_path = Path(args.input)
    if not input_path.is_absolute():
        input_path = ROOT / input_path
    if not input_path.exists():
        raise SystemExit("candidate input not found")
    if (ROOT / "data" / "aigc_battle" / "llm_candidates").resolve() not in input_path.resolve().parents and input_path.resolve() != (ROOT / "data" / "aigc_battle" / "llm_candidates").resolve():
        raise SystemExit("candidate input must live under data/aigc_battle/llm_candidates/")

    mechanic_profile = read_json(ROOT / "data" / "aigc_battle" / "mechanics" / profile_id / "mechanic_profile.json")
    root_generated_dir = switch_lib.resolve_generated_dir(profile_id)
    existing_cards = {str(card.get("card_id", card.get("id", ""))): card for card in read_json(root_generated_dir / "card_pool.generated.json")}
    allowed_effects = set(str(item) for item in mechanic_profile.get("allowed_runtime_effects", []))
    allowed_styles = set(str(item) for item in mechanic_profile.get("weapon_styles", []))
    allowed_card_types = set(str(item) for item in mechanic_profile.get("card_types", []))
    followup_constraints = mechanic_profile.get("runtime_primitive_constraints", {}).get("weapon_followup", {})
    allowed_followup_triggers = set(str(item) for item in followup_constraints.get("allowed_triggers", []))
    max_bonus_damage = int(followup_constraints.get("max_bonus_damage", 999))
    max_bonus_momentum = int(followup_constraints.get("max_bonus_momentum", 999))
    max_bonus_block = int(followup_constraints.get("max_bonus_block", 999))

    raw_rows = read_jsonl(input_path)
    accepted: list[dict[str, Any]] = []
    rejected: list[dict[str, Any]] = []
    accepted_cards_by_ref: dict[str, dict[str, Any]] = {}
    rejected_counter: Counter[str] = Counter()
    warnings_by_candidate: dict[str, list[str]] = defaultdict(list)

    for raw in raw_rows:
        normalized = flatten_candidate(raw)
        reasons: list[str] = []
        warnings: list[str] = []
        candidate_type = str(normalized.get("candidate_type", ""))
        candidate_id = str(normalized.get("candidate_id", "")).strip()
        if not candidate_id:
            reasons.append("missing_candidate_id")
        if candidate_type not in {"card_candidate", "deck_candidate", "reward_candidate", "battle_slot_candidate"}:
            reasons.append("invalid_candidate_type")
        if str(normalized.get("mechanic_profile_id", "")) != profile_id:
            reasons.append("mechanic_profile_mismatch")
        if any(key in normalized for key in ["runtime_manifest_path", "active_profile_path", "file_path"]):
            reasons.append("forbidden_path_field")
        if any("/" in str(value) or ".." in str(value) for key, value in normalized.items() if key.endswith("_path")):
            reasons.append("path_traversal_field")
        if candidate_type == "card_candidate":
            validate_card_candidate(normalized, allowed_card_types, allowed_styles, allowed_effects, allowed_followup_triggers, max_bonus_damage, max_bonus_momentum, max_bonus_block, reasons)
        elif candidate_type == "deck_candidate":
            validate_deck_candidate(normalized, reasons, warnings)
        elif candidate_type == "reward_candidate":
            validate_reward_candidate(normalized, reasons)
        elif candidate_type == "battle_slot_candidate":
            validate_battle_slot_candidate(normalized, reasons)

        if reasons:
            rejected.append(with_rejection(raw, normalized, reasons))
            for reason in reasons:
                rejected_counter[reason] += 1
            continue
        normalized["warnings"] = warnings
        accepted.append(normalized)
        if candidate_type == "card_candidate":
            accepted_cards_by_ref[str(normalized.get("candidate_id"))] = normalized
            accepted_cards_by_ref[str(normalized.get("card_id"))] = normalized
        if warnings:
            warnings_by_candidate[candidate_id].extend(warnings)

    existing_card_ids = set(existing_cards.keys())
    accepted_card_ids = {str(item.get("card_id", "")) for item in accepted if item.get("candidate_type") == "card_candidate"}
    for item in list(accepted):
        if item.get("candidate_type") == "deck_candidate":
            refs = [str(ref) for ref in item.get("card_refs", [])]
            invalid_refs = [ref for ref in refs if ref not in accepted_cards_by_ref and ref not in existing_card_ids]
            if invalid_refs:
                accepted.remove(item)
                reasons = ["invalid_deck_card_ref"] + [f"missing_ref:{ref}" for ref in invalid_refs]
                rejected.append(with_rejection(item, item, reasons))
                for reason in reasons:
                    rejected_counter[reason] += 1
                continue
            if not (int(item.get("target_power_min", 0)) <= float(item.get("deck_power_score", 0) or 0) <= int(item.get("target_power_max", 0))):
                item.setdefault("warnings", []).append("deck_power_out_of_target_range")

    accepted_path = accepted_candidates_path(profile_id)
    rejected_path = rejected_candidates_path(profile_id)
    write_jsonl(accepted_path, accepted)
    write_jsonl(rejected_path, rejected)

    accepted_by_type = Counter(str(item.get("candidate_type", "")) for item in accepted)
    rejected_by_type = Counter(str(flatten_candidate(item).get("candidate_type", "")) for item in rejected)
    report = {
        "mechanic_profile_id": profile_id,
        "input_candidate_count": len(raw_rows),
        "accepted_candidate_count": len(accepted),
        "rejected_candidate_count": len(rejected),
        "accepted_by_type": dict(accepted_by_type),
        "rejected_by_type": dict(rejected_by_type),
        "rejection_reasons": dict(rejected_counter),
        "unsupported_effect_count": rejected_counter.get("unsupported_runtime_effect", 0),
        "realm_invalid_count": sum(value for key, value in rejected_counter.items() if "required_wujing" in key or "closing_form_tier" in key or "realm" in key),
        "followup_invalid_count": sum(value for key, value in rejected_counter.items() if "followup" in key),
        "deck_ref_invalid_count": sum(value for key, value in rejected_counter.items() if "deck_card_ref" in key or "missing_ref:" in key),
        "ready_for_ai_pack_build": len(accepted) > 0 and accepted_by_type.get("deck_candidate", 0) > 0 and accepted_by_type.get("battle_slot_candidate", 0) > 0,
        "accepted_candidates_path": to_relative(accepted_path),
        "rejected_candidates_path": to_relative(rejected_path),
    }
    report_path = import_report_json_path(profile_id)
    write_json(report_path, report)
    write_markdown(import_report_md_path(profile_id), report)
    print(json.dumps(report, ensure_ascii=False, indent=2))
    return 0


def flatten_candidate(raw: dict[str, Any]) -> dict[str, Any]:
    content = raw.get("content", {})
    if isinstance(content, dict):
        merged = dict(content)
        for key in ["candidate_id", "candidate_type", "mechanic_profile_id", "target_sequence_id", "source"]:
            if key in raw:
                merged[key] = raw[key]
        return merged
    return dict(raw)


def validate_card_candidate(
    candidate: dict[str, Any],
    allowed_card_types: set[str],
    allowed_styles: set[str],
    allowed_effects: set[str],
    allowed_followup_triggers: set[str],
    max_bonus_damage: int,
    max_bonus_momentum: int,
    max_bonus_block: int,
    reasons: list[str],
) -> None:
    required = ["card_id", "name", "card_type", "weapon_style", "cost", "effects", "tags", "difficulty_tier", "power_score", "required_wujing", "closing_form_tier", "runtime_effects"]
    for field in required:
        if field not in candidate:
            reasons.append(f"missing_{field}")
    if str(candidate.get("card_type", "")) not in allowed_card_types:
        reasons.append("invalid_card_type")
    if str(candidate.get("weapon_style", "")) not in allowed_styles:
        reasons.append("invalid_weapon_style")
    if int(candidate.get("required_wujing", 0)) < 0:
        reasons.append("invalid_required_wujing")
    if int(candidate.get("closing_form_tier", 0)) < 0:
        reasons.append("invalid_closing_form_tier")
    runtime_effects = candidate.get("runtime_effects", [])
    if not isinstance(runtime_effects, list) or not runtime_effects:
        reasons.append("missing_runtime_effects")
    for effect in runtime_effects if isinstance(runtime_effects, list) else []:
        if str(effect) not in allowed_effects:
            reasons.append("unsupported_runtime_effect")
    trigger = str(candidate.get("followup_trigger", ""))
    if trigger and allowed_followup_triggers and trigger not in allowed_followup_triggers:
        reasons.append("invalid_followup_trigger")
    bonus = candidate.get("followup_bonus", {})
    if bonus and isinstance(bonus, dict):
        if int(bonus.get("bonus_damage", 0)) > max_bonus_damage:
            reasons.append("followup_bonus_damage_out_of_range")
        if int(bonus.get("bonus_momentum", 0)) > max_bonus_momentum:
            reasons.append("followup_bonus_momentum_out_of_range")
        if int(bonus.get("bonus_block", 0)) > max_bonus_block:
            reasons.append("followup_bonus_block_out_of_range")


def validate_deck_candidate(candidate: dict[str, Any], reasons: list[str], warnings: list[str]) -> None:
    required = ["deck_id", "encounter_tier", "enemy_role", "card_refs", "deck_power_score", "target_power_min", "target_power_max"]
    for field in required:
        if field not in candidate:
            reasons.append(f"missing_{field}")
    refs = candidate.get("card_refs", [])
    if not isinstance(refs, list) or not refs:
        reasons.append("missing_card_refs")
    if candidate.get("followup_chain_count", 0) and not candidate.get("followup_groups", []):
        warnings.append("followup_groups_missing")


def validate_reward_candidate(candidate: dict[str, Any], reasons: list[str]) -> None:
    required = ["reward_plan_id", "reward_type", "reward_tier", "reward_items"]
    for field in required:
        if field not in candidate:
            reasons.append(f"missing_{field}")


def validate_battle_slot_candidate(candidate: dict[str, Any], reasons: list[str]) -> None:
    required = ["formal_encounter_id", "generated_battle_slot_id", "deck_id", "reward_plan_id", "encounter_tier", "player_wujing_cap", "target_power_min", "target_power_max", "runtime_primitives"]
    for field in required:
        if field not in candidate:
            reasons.append(f"missing_{field}")
    runtime_primitives = candidate.get("runtime_primitives", [])
    if not isinstance(runtime_primitives, list):
        reasons.append("invalid_runtime_primitives")


def with_rejection(raw: dict[str, Any], normalized: dict[str, Any], reasons: list[str]) -> dict[str, Any]:
    payload = dict(raw)
    payload["normalized_candidate"] = normalized
    payload["rejection_reasons"] = reasons
    return payload


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


def write_jsonl(path: Path, rows: list[dict[str, Any]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    text = "\n".join(json.dumps(row, ensure_ascii=False) for row in rows)
    path.write_text((text + "\n") if text else "", encoding="utf-8")


def write_markdown(path: Path, report: dict[str, Any]) -> None:
    lines = [
        "# Candidate Import Report",
        "",
        f"- input_candidate_count: {report['input_candidate_count']}",
        f"- accepted_candidate_count: {report['accepted_candidate_count']}",
        f"- rejected_candidate_count: {report['rejected_candidate_count']}",
        f"- ready_for_ai_pack_build: {str(report['ready_for_ai_pack_build']).lower()}",
        "",
        "## rejection_reasons",
    ]
    for key, value in sorted(report["rejection_reasons"].items()):
        lines.append(f"- {key}: {value}")
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def accepted_candidates_path(profile_id: str) -> Path:
    return LLM_DIR / profile_id / "accepted_candidates.jsonl"


def rejected_candidates_path(profile_id: str) -> Path:
    return LLM_DIR / profile_id / "rejected_candidates.jsonl"


def import_report_json_path(profile_id: str) -> Path:
    return REPORT_DIR / f"{profile_id}__candidate_import_report.json"


def import_report_md_path(profile_id: str) -> Path:
    return REPORT_DIR / f"{profile_id}__candidate_import_report.md"


def to_relative(path: Path) -> str:
    return path.relative_to(ROOT).as_posix()


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
