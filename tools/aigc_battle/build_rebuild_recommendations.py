#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import sys
from collections import Counter
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from tools.aigc_battle import aigc_headless_evaluation_runner as eval_lib
from tools.aigc_battle import build_real_evaluation_snapshot as snapshot_lib

REBUILD_DIR = ROOT / "data" / "aigc_battle" / "evaluation" / "rebuild_recommendations"
SUMMARY_JSON = ROOT / "data" / "aigc_battle" / "generated" / "evaluation" / "r3_rebuild_recommendation_summary.json"
SUMMARY_MD = ROOT / "data" / "aigc_battle" / "generated" / "evaluation" / "r3_rebuild_recommendation_summary.md"


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description="build rebuild recommendations")
    parser.add_argument("--profile", default="")
    parser.add_argument("--pack", default="")
    parser.add_argument("--default-r3-pack-set", action="store_true")
    args = parser.parse_args(argv[1:])

    if args.default_r3_pack_set:
        packs = eval_lib.default_r3_pack_set()
        payloads = [build_recommendations(profile_id, pack_id) for profile_id, pack_id in packs]
        summary = build_summary(payloads)
        write_json(SUMMARY_JSON, summary)
        SUMMARY_MD.write_text(build_summary_markdown(summary), encoding="utf-8")
        print(f"built rebuild recommendations: packs={len(payloads)}")
        return 0

    if not args.profile:
        raise SystemExit("profile is required unless --default-r3-pack-set is used")
    build_recommendations(args.profile, args.pack or None)
    print(f"built rebuild recommendations: {args.profile}")
    return 0


def build_recommendations(profile_id: str, pack_id: str | None) -> dict[str, Any]:
    generated_dir = eval_lib.resolve_generated_dir(profile_id, pack_id)
    runtime_manifest = read_json(generated_dir / "runtime_manifest.json")
    content_pack_id = str(runtime_manifest.get("content_pack_id", pack_id or ""))
    snapshot = read_json(snapshot_lib.snapshot_json_path(profile_id, content_pack_id))
    validation_report = read_json(generated_dir / "validation_report.json")
    sequence_template_id = str(snapshot.get("sequence_template_id") or runtime_manifest.get("sequence_template_id", ""))
    recommendations: list[dict[str, Any]] = []
    action_counts: Counter[str] = Counter()

    for item in snapshot.get("too_easy_candidates", []):
        recommendations.append(recommendation(item, "medium", "increase_deck_power", profile_id, content_pack_id, safe=True, delta={"power_bias": +1, "swap_direction": "higher_power"}))
    for item in snapshot.get("too_hard_candidates", []):
        recommendations.append(recommendation(item, "medium", "reduce_deck_power", profile_id, content_pack_id, safe=True, delta={"power_bias": -1, "swap_direction": "lower_power"}))
    for item in snapshot.get("too_long_candidates", []):
        recommendations.append(recommendation(item, "medium", "increase_deck_power", profile_id, content_pack_id, safe=True, delta={"power_bias": +1, "reason": "too_long"}))
    for item in snapshot.get("reward_mismatch_candidates", []):
        recommendations.append(recommendation(item, "high", "adjust_reward_tier", profile_id, content_pack_id, safe=False, delta={"reward_tier_shift": +1}))
    for item in snapshot.get("mechanism_underused_candidates", []):
        action = mechanism_action(snapshot)
        safe = action in {"improve_clue_pressure_trigger", "improve_dual_weapon_mix", "improve_followup_chain"}
        recommendations.append(recommendation(item, "medium", action, profile_id, content_pack_id, safe=safe, delta={"mechanic_density_shift": 1}))
    for item in snapshot.get("card_dead_candidates", [])[:8]:
        recommendations.append({
            "recommendation_id": build_id(profile_id, content_pack_id, "replace_dead_card", item.get("card_id", "")),
            "severity": "medium",
            "action_type": "replace_dead_card",
            "mechanic_profile_id": profile_id,
            "content_pack_id": content_pack_id,
            "formal_encounter_id": "",
            "generated_deck_id": "",
            "card_id": str(item.get("card_id", "")),
            "reward_plan_id": "",
            "reason": "card_dead",
            "evidence": item,
            "suggested_delta": {"replacement_strategy": "same_style_same_tier_unused_card"},
            "safe_to_auto_apply": True,
            "requires_designer_review": False,
        })
    for item in snapshot.get("card_overused_candidates", [])[:8]:
        recommendations.append({
            "recommendation_id": build_id(profile_id, content_pack_id, "reduce_overused_card", item.get("card_id", "")),
            "severity": "medium",
            "action_type": "reduce_overused_card",
            "mechanic_profile_id": profile_id,
            "content_pack_id": content_pack_id,
            "formal_encounter_id": "",
            "generated_deck_id": "",
            "card_id": str(item.get("card_id", "")),
            "reward_plan_id": "",
            "reason": "card_overused",
            "evidence": item,
            "suggested_delta": {"replacement_strategy": "same_style_lower_usage_card"},
            "safe_to_auto_apply": True,
            "requires_designer_review": False,
        })

    for row in recommendations:
        action_counts[row["action_type"]] += 1

    payload = {
        "generated_at": now_iso(),
        "mechanic_profile_id": profile_id,
        "content_pack_id": content_pack_id,
        "sequence_template_id": sequence_template_id,
        "validation_ready": bool(validation_report.get("ready_for_runtime_export", False)),
        "recommendation_count": len(recommendations),
        "safe_to_auto_apply_count": sum(1 for row in recommendations if row.get("safe_to_auto_apply")),
        "requires_designer_review_count": sum(1 for row in recommendations if row.get("requires_designer_review")),
        "action_type_counts": dict(action_counts),
        "recommendations": recommendations,
    }
    write_json(rebuild_json_path(profile_id, content_pack_id), payload)
    rebuild_md_path(profile_id, content_pack_id).write_text(build_markdown(payload), encoding="utf-8")
    return payload


def recommendation(
    item: dict[str, Any],
    severity: str,
    action_type: str,
    profile_id: str,
    content_pack_id: str,
    safe: bool,
    delta: dict[str, Any],
) -> dict[str, Any]:
    stage = str(item.get("stage", ""))
    return {
        "recommendation_id": build_id(profile_id, content_pack_id, action_type, item.get("generated_battle_slot_id", "")),
        "severity": severity,
        "action_type": action_type,
        "mechanic_profile_id": profile_id,
        "content_pack_id": content_pack_id,
        "sequence_template_id": str(item.get("sequence_template_id", "")),
        "stage": stage,
        "stage_level_action": stage_level_action(action_type, stage),
        "formal_encounter_id": str(item.get("formal_encounter_id", "")),
        "generated_deck_id": str(item.get("generated_deck_id", "")),
        "card_id": str(item.get("card_id", "")),
        "reward_plan_id": str(item.get("reward_plan_id", "")),
        "reason": str(item.get("reason", action_type)),
        "evidence": item.get("evidence", item),
        "suggested_delta": delta,
        "safe_to_auto_apply": safe,
        "requires_designer_review": not safe,
    }


def mechanism_action(snapshot: dict[str, Any]) -> str:
    mechanic = snapshot.get("mechanic_profile_id", "")
    if "clue_pressure" in mechanic:
        return "improve_clue_pressure_trigger"
    if "dual_weapon" in mechanic:
        return "improve_dual_weapon_mix"
    return "improve_followup_chain"


def build_summary(payloads: list[dict[str, Any]]) -> dict[str, Any]:
    return {
        "generated_at": now_iso(),
        "pack_count": len(payloads),
        "packs": [
            {
                "mechanic_profile_id": payload.get("mechanic_profile_id", ""),
                "content_pack_id": payload.get("content_pack_id", ""),
                "sequence_template_id": payload.get("sequence_template_id", ""),
                "recommendation_count": payload.get("recommendation_count", 0),
                "safe_to_auto_apply_count": payload.get("safe_to_auto_apply_count", 0),
                "requires_designer_review_count": payload.get("requires_designer_review_count", 0),
                "action_type_counts": payload.get("action_type_counts", {}),
            }
            for payload in payloads
        ],
    }


def rebuild_json_path(profile_id: str, content_pack_id: str) -> Path:
    return REBUILD_DIR / f"{profile_id}__{content_pack_id}__rebuild_recommendations.json"


def rebuild_md_path(profile_id: str, content_pack_id: str) -> Path:
    return REBUILD_DIR / f"{profile_id}__{content_pack_id}__rebuild_recommendations.md"


def build_id(profile_id: str, content_pack_id: str, action_type: str, suffix: Any) -> str:
    return f"{profile_id}__{content_pack_id}__{action_type}__{suffix or 'global'}"


def build_markdown(payload: dict[str, Any]) -> str:
    lines = [
        "# Rebuild Recommendations",
        "",
        f"- mechanic_profile_id: `{payload.get('mechanic_profile_id', '')}`",
        f"- content_pack_id: `{payload.get('content_pack_id', '')}`",
        f"- sequence_template_id: `{payload.get('sequence_template_id', '')}`",
        f"- recommendation_count: `{payload.get('recommendation_count', 0)}`",
        f"- safe_to_auto_apply_count: `{payload.get('safe_to_auto_apply_count', 0)}`",
        f"- requires_designer_review_count: `{payload.get('requires_designer_review_count', 0)}`",
        "",
        "## Recommendations",
    ]
    for row in payload.get("recommendations", []):
        lines.append(
            f"- `{row.get('action_type', '')}` | severity={row.get('severity', '')} | "
            f"stage={row.get('stage', '') or '-'} | encounter={row.get('formal_encounter_id', '') or '-'} | "
            f"card={row.get('card_id', '') or '-'} | "
            f"safe={row.get('safe_to_auto_apply', False)}"
        )
    return "\n".join(lines) + "\n"


def build_summary_markdown(summary: dict[str, Any]) -> str:
    lines = [
        "# R3 Rebuild Recommendation Summary",
        "",
        f"- pack_count: `{summary.get('pack_count', 0)}`",
        "",
        "| Profile | Pack | Recommendations | Safe | Review |",
        "| --- | --- | ---: | ---: | ---: |",
    ]
    for row in summary.get("packs", []):
        lines.append(
            f"| `{row.get('mechanic_profile_id', '')}` | `{row.get('content_pack_id', '')}` | "
            f"{row.get('recommendation_count', 0)} | {row.get('safe_to_auto_apply_count', 0)} | "
            f"{row.get('requires_designer_review_count', 0)} |"
        )
    return "\n".join(lines) + "\n"


def stage_level_action(action_type: str, stage: str) -> str:
    if action_type in {"reduce_deck_power", "increase_deck_power"}:
        return "lower_stage_power" if action_type == "reduce_deck_power" else "increase_stage_mechanic_density"
    if action_type == "adjust_reward_tier":
        return "raise_stage_reward"
    if action_type in {"improve_clue_pressure_trigger", "improve_dual_weapon_mix", "improve_followup_chain"}:
        return "increase_stage_mechanic_density"
    if action_type == "reduce_mechanic_density":
        return "reduce_stage_mechanic_density"
    return ""


def read_json(path: Path) -> Any:
    return json.loads(path.read_text(encoding="utf-8"))


def write_json(path: Path, payload: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
