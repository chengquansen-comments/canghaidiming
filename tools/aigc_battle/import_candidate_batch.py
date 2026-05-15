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

from tools.aigc_battle import load_sequence_template as template_lib
from tools.aigc_battle import switch_active_profile as switch_lib


STUDIO_DIR = ROOT / "data" / "aigc_battle" / "ai_studio"
CANDIDATE_DIR = STUDIO_DIR / "candidates"
BATCH_DIR = STUDIO_DIR / "batches"
MECHANICS_DIR = ROOT / "data" / "aigc_battle" / "mechanics"
ALLOWED_TYPES = {
    "card_candidate",
    "deck_candidate",
    "reward_candidate",
    "battle_slot_candidate",
    "sequence_adjustment_candidate",
    "balance_adjustment_candidate",
}
DANGEROUS_FIELDS = {
    "file_path",
    "runtime_manifest_path",
    "active_profile_path",
    "generated_dir",
    "absolute_path",
}


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description="import AI studio candidate batch")
    parser.add_argument("--batch-id", required=True)
    parser.add_argument("--input", required=True)
    args = parser.parse_args(argv[1:])
    payload = import_candidate_batch(args.batch_id, args.input)
    print(json.dumps(payload, ensure_ascii=False, indent=2))
    return 0 if payload.get("ready_for_quality_score", False) else 1


def import_candidate_batch(batch_id: str, input_arg: str) -> dict[str, Any]:
    switch_lib.ensure_safe_id(batch_id, "batch_id")
    input_path = Path(input_arg)
    if not input_path.is_absolute():
        input_path = ROOT / input_path
    if not input_path.exists():
        raise SystemExit("candidate batch input not found")
    if CANDIDATE_DIR.resolve() not in input_path.resolve().parents:
        raise SystemExit("candidate batch input must live under data/aigc_battle/ai_studio/candidates")

    rows = read_jsonl(input_path)
    mechanics = available_mechanics()
    templates = available_templates()
    seen_candidate_ids: set[str] = set()
    accepted: list[dict[str, Any]] = []
    rejected: list[dict[str, Any]] = []
    rejection_reasons: Counter[str] = Counter()
    accepted_by_type: Counter[str] = Counter()
    rejected_by_type: Counter[str] = Counter()

    for raw in rows:
        candidate = dict(raw)
        reasons: list[str] = []
        candidate_id = str(candidate.get("candidate_id", "")).strip()
        candidate_type = str(candidate.get("candidate_type", "")).strip()
        mechanic_profile_id = str(candidate.get("mechanic_profile_id", "")).strip()
        sequence_template_id = str(candidate.get("sequence_template_id", "")).strip()

        if not candidate_id:
            reasons.append("missing_candidate_id")
        elif candidate_id in seen_candidate_ids:
            reasons.append("duplicate_candidate_id")
        else:
            seen_candidate_ids.add(candidate_id)
        if candidate_type not in ALLOWED_TYPES:
            reasons.append("invalid_candidate_type")
        if mechanic_profile_id not in mechanics:
            reasons.append("invalid_mechanic_profile_id")
        if sequence_template_id not in templates:
            reasons.append("invalid_sequence_template_id")
        for field in DANGEROUS_FIELDS:
            if field in candidate:
                reasons.append("unsafe_field_rejected")
        if any(".." in str(value) or "/" in str(value) for key, value in candidate.items() if key.endswith("_path")):
            reasons.append("path_traversal_field")

        if not reasons:
            validate_candidate(candidate, mechanics[mechanic_profile_id], templates[sequence_template_id], reasons)

        if reasons:
            rejected.append({**candidate, "rejection_reasons": reasons})
            rejected_by_type[candidate_type] += 1
            for reason in reasons:
                rejection_reasons[reason] += 1
            continue

        accepted.append(candidate)
        accepted_by_type[candidate_type] += 1

    batch_dir = BATCH_DIR / batch_id
    batch_dir.mkdir(parents=True, exist_ok=True)
    accepted_path = batch_dir / "accepted_candidates.jsonl"
    rejected_path = batch_dir / "rejected_candidates.jsonl"
    write_jsonl(accepted_path, accepted)
    write_jsonl(rejected_path, rejected)
    report = {
        "batch_id": batch_id,
        "input_candidate_count": len(rows),
        "accepted_candidate_count": len(accepted),
        "rejected_candidate_count": len(rejected),
        "accepted_by_type": dict(accepted_by_type),
        "rejected_by_type": dict(rejected_by_type),
        "rejection_reasons": dict(rejection_reasons),
        "unsafe_field_rejected": int(rejection_reasons.get("unsafe_field_rejected", 0)),
        "unsupported_effect_rejected": int(rejection_reasons.get("unsupported_effect_rejected", 0)),
        "realm_invalid_rejected": sum(v for k, v in rejection_reasons.items() if "realm_invalid" in k or "required_wujing" in k or "closing_form_tier" in k),
        "ready_for_quality_score": len(accepted) > 0,
        "accepted_candidates_path": to_relative(accepted_path),
        "rejected_candidates_path": to_relative(rejected_path),
    }
    write_json(batch_dir / "import_report.json", report)
    return report


def available_mechanics() -> dict[str, dict[str, Any]]:
    payload: dict[str, dict[str, Any]] = {}
    for path in sorted(MECHANICS_DIR.glob("*/mechanic_profile.json")):
        data = json.loads(path.read_text(encoding="utf-8"))
        payload[str(data.get("mechanic_profile_id", path.parent.name))] = data
    return payload


def available_templates() -> dict[str, dict[str, Any]]:
    payload: dict[str, dict[str, Any]] = {}
    for path in sorted(template_lib.SEQUENCE_TEMPLATE_DIR.glob("*.json")):
        data = json.loads(path.read_text(encoding="utf-8"))
        payload[str(data.get("sequence_template_id", path.stem))] = data
    return payload


def validate_candidate(candidate: dict[str, Any], mechanic: dict[str, Any], template: dict[str, Any], reasons: list[str]) -> None:
    candidate_type = str(candidate.get("candidate_type", ""))
    allowed_effects = set(str(item) for item in mechanic.get("allowed_runtime_effects", []))
    allowed_styles = set(str(item) for item in mechanic.get("weapon_styles", []))
    max_wujing = int(mechanic.get("max_wujing", 7) or 7)

    runtime_effects = candidate.get("runtime_effects", [])
    if runtime_effects is not None:
        if not isinstance(runtime_effects, list):
            reasons.append("invalid_runtime_effects")
        else:
            for effect in runtime_effects:
                if str(effect) not in allowed_effects:
                    reasons.append("unsupported_effect_rejected")

    for key in ["required_wujing", "closing_form_tier", "player_wujing_cap", "max_enemy_wujing"]:
        if key in candidate:
            value = int(candidate.get(key, 0) or 0)
            if value < 0 or value > max_wujing:
                reasons.append(f"{key}_realm_invalid")

    if candidate_type == "card_candidate":
        required = ["card_id", "name", "card_type", "weapon_style", "cost", "power_score", "required_wujing", "closing_form_tier"]
        for field in required:
            if field not in candidate:
                reasons.append(f"missing_{field}")
        if str(candidate.get("weapon_style", "")) not in allowed_styles:
            reasons.append("weapon_style_invalid")
        if str(candidate.get("followup_trigger", "")) and "weapon_followup" not in mechanic.get("runtime_primitives", []):
            reasons.append("followup_invalid_for_mechanic")
    elif candidate_type == "deck_candidate":
        if not isinstance(candidate.get("card_refs", []), list) or not candidate.get("card_refs"):
            reasons.append("deck_refs_invalid")
        primary = str(candidate.get("primary_weapon_style", ""))
        secondary = str(candidate.get("secondary_weapon_style", ""))
        loadout = candidate.get("weapon_loadout", [])
        if loadout and any(str(item) not in allowed_styles for item in loadout):
            reasons.append("weapon_loadout_invalid")
        if primary and primary not in allowed_styles:
            reasons.append("primary_weapon_style_invalid")
        if secondary and secondary not in allowed_styles:
            reasons.append("secondary_weapon_style_invalid")
        if candidate.get("dual_weapon_enabled") and not mechanic.get("dual_weapon_enabled", False):
            reasons.append("dual_weapon_invalid_for_mechanic")
    elif candidate_type == "reward_candidate":
        if "reward_tier" not in candidate or "reward_items" not in candidate:
            reasons.append("reward_candidate_incomplete")
    elif candidate_type == "battle_slot_candidate":
        runtime_primitives = candidate.get("runtime_primitives", [])
        if not isinstance(runtime_primitives, list):
            reasons.append("runtime_primitives_invalid")
        else:
            known = set(str(item) for item in mechanic.get("runtime_primitives", []))
            if any(str(item) not in known for item in runtime_primitives):
                reasons.append("runtime_primitive_invalid")
        if "clue_pressure" in candidate and "clue_pressure" not in mechanic.get("runtime_primitives", []):
            reasons.append("clue_pressure_invalid_for_mechanic")
    elif candidate_type == "sequence_adjustment_candidate":
        if int(candidate.get("target_encounter_count", template.get("total_encounter_count", 0)) or 0) != int(template.get("total_encounter_count", 0) or 0):
            reasons.append("sequence_adjustment_out_of_template")
    elif candidate_type == "balance_adjustment_candidate":
        if str(candidate.get("action", "")) not in {"reduce_deck_power", "increase_reward_tier", "improve_followup_chain"}:
            reasons.append("balance_adjustment_action_invalid")


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
    text = "\n".join(json.dumps(row, ensure_ascii=False) for row in rows)
    path.write_text((text + "\n") if text else "", encoding="utf-8")


def to_relative(path: Path) -> str:
    return path.relative_to(ROOT).as_posix()


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
