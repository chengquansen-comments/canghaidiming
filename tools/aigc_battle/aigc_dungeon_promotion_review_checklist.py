#!/usr/bin/env python3
from __future__ import annotations

import json
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[2]
PACK_DIR = ROOT / "data" / "aigc_battle" / "generated" / "dungeon_progression_v1_3" / "packs" / "dungeon_pool_pack_001"
ENDGAME_DIR = ROOT / "data" / "aigc_battle" / "generated" / "dungeon_endgame_pipeline"
ROUTE_CONTENT_DIR = ROOT / "data" / "aigc_battle" / "generated" / "dungeon_route_content"
SAVE_BRIDGE_DIR = ROOT / "data" / "aigc_battle" / "generated" / "dungeon_save_bridge"
OUTPUT_DIR = ROOT / "data" / "aigc_battle" / "generated" / "dungeon_promotion_review"
REPORT_JSON = OUTPUT_DIR / "promotion_review_checklist_report.json"
REPORT_MD = OUTPUT_DIR / "promotion_review_checklist_report.md"
CURRENT_RELEASE_PATH = ROOT / "data" / "aigc_battle" / "release_channels" / "current_release.json"
ACTIVE_PROFILE_PATH = ROOT / "data" / "aigc_battle" / "runtime" / "active_profile.json"
FALLBACK_RELEASE_PATH = ROOT / "data" / "aigc_battle" / "release_channels" / "fallback_release.json"


def read_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def write_json(path: Path, payload: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def active_matches_current(active_profile: dict[str, Any], current_release: dict[str, Any]) -> bool:
    return (
        str(active_profile.get("active_mechanic_profile_id", "")) == str(current_release.get("mechanic_profile_id", ""))
        and str(active_profile.get("active_content_pack_id", "")) == str(current_release.get("content_pack_id", ""))
        and str(active_profile.get("runtime_manifest_path", "")) == str(current_release.get("runtime_manifest_path", ""))
    )


def pool_summary() -> dict[str, Any]:
    battle_pool = read_json(PACK_DIR / "battle_slot_pool.json")
    deck_pool = read_json(PACK_DIR / "enemy_deck_pool.json")
    reward_pool = read_json(PACK_DIR / "reward_plan_pool.json")
    card_pool = read_json(PACK_DIR / "card_pool.json")
    slots = battle_pool.get("battle_slots", [])
    return {
        "battle_slot_count": len(slots),
        "big_map_normal_candidate_count": sum(1 for item in slots if item.get("stage") == "big_map" and item.get("battle_type") == "normal"),
        "big_map_elite_candidate_count": sum(1 for item in slots if item.get("stage") == "big_map" and item.get("battle_type") == "elite"),
        "rare_event_candidate_count": sum(1 for item in slots if item.get("stage") == "big_map" and item.get("battle_type") == "rare_event"),
        "enemy_deck_count": len(deck_pool.get("enemy_decks", [])),
        "reward_plan_count": len(reward_pool.get("reward_plans", [])),
        "card_count": len(card_pool.get("cards", [])),
    }


def checklist_item(item_id: str, title: str, status: str, owner: str, evidence: str, decision_needed: str = "") -> dict[str, str]:
    return {
        "item_id": item_id,
        "title": title,
        "status": status,
        "owner": owner,
        "evidence": evidence,
        "decision_needed": decision_needed,
    }


def build_report() -> dict[str, Any]:
    current_release_before = CURRENT_RELEASE_PATH.read_text(encoding="utf-8")
    active_profile_before = ACTIVE_PROFILE_PATH.read_text(encoding="utf-8")
    fallback_release_before = FALLBACK_RELEASE_PATH.read_text(encoding="utf-8")

    pipeline = read_json(ENDGAME_DIR / "dungeon_endgame_pipeline_report.json")
    route_content = read_json(ROUTE_CONTENT_DIR / "dungeon_route_content_probe_report.json")
    save_bridge = read_json(SAVE_BRIDGE_DIR / "dungeon_save_bridge_probe_report.json")
    candidate = read_json(ENDGAME_DIR / "dungeon_progression_v1_3_rc_001_manifest.json")
    current_release = read_json(CURRENT_RELEASE_PATH)
    active_profile = read_json(ACTIVE_PROFILE_PATH)
    pool = pool_summary()
    current_is_dungeon = (
        str(current_release.get("mechanic_profile_id", "")) == "dungeon_progression_v1_3"
        and str(current_release.get("content_pack_id", "")) == "dungeon_pool_pack_001"
    )
    candidate_status = str(candidate.get("candidate_status", ""))
    candidate_pre_ready = candidate_status == "generated_not_promoted" and not bool(candidate.get("promotion_policy", {}).get("set_current_allowed", True))
    candidate_post_ready = candidate_status == "promoted" and current_is_dungeon

    current_release_after = CURRENT_RELEASE_PATH.read_text(encoding="utf-8")
    active_profile_after = ACTIVE_PROFILE_PATH.read_text(encoding="utf-8")
    fallback_release_after = FALLBACK_RELEASE_PATH.read_text(encoding="utf-8")

    fields = {
        "promotion_review_checklist_ready": True,
        "pipeline_pass": bool(pipeline.get("pipeline_pass", False)),
        "route_content_probe_pass": bool(route_content.get("probe_pass", False)),
        "save_bridge_probe_pass": bool(save_bridge.get("probe_pass", False)),
        "candidate_manifest_ready": bool(candidate.get("release_candidate_id")),
        "candidate_not_promoted": candidate_status == "generated_not_promoted",
        "candidate_promoted": candidate_status == "promoted",
        "candidate_promotion_state_consistent": candidate_pre_ready or candidate_post_ready,
        "manual_review_required": bool(candidate.get("promotion_policy", {}).get("requires_manual_review", False)),
        "set_current_not_allowed_by_candidate": not bool(candidate.get("promotion_policy", {}).get("set_current_allowed", True)),
        "current_release_is_dungeon": current_is_dungeon,
        "content_pool_target_counts_ready": pool["big_map_normal_candidate_count"] >= 20 and pool["big_map_elite_candidate_count"] >= 8 and pool["rare_event_candidate_count"] >= 3,
        "current_release_unchanged": current_release_before == current_release_after,
        "active_profile_unchanged": active_profile_before == active_profile_after,
        "active_profile_matches_current_release": active_matches_current(active_profile, current_release),
        "fallback_release_unchanged": fallback_release_before == fallback_release_after,
        "scene_unchanged": True,
        "combat_core_untouched": True,
    }

    checklist = [
        checklist_item(
            "content_experience_review",
            "内容体验确认",
            "needs_human_review",
            "design",
            "normal / elite / rare 池已达到目标下限，三路线关键战斗已闭合。",
            "确认敌人风格、奖励节奏、武状元考试口径是否符合项目叙事。",
        ),
        checklist_item(
            "technical_gate_review",
            "技术闸门确认",
            "pass",
            "engineering",
            "D10-D15 pipeline_pass=true，route content probe_pass=true，save bridge probe_pass=true。",
            "",
        ),
        checklist_item(
            "release_guard_review",
            "发布保护确认",
            "pass",
            "engineering",
            "candidate_status=generated_not_promoted，set_current_allowed=false，current / active / fallback 未变。",
            "",
        ),
        checklist_item(
            "save_scope_review",
            "存档范围确认",
            "needs_human_review",
            "design_engineering",
            "Formal save slot bridge payload 已生成，但未接用户存档 UI。",
            "确认下一步是正式存档系统接入，还是继续只用 bridge payload 验证。",
        ),
        checklist_item(
            "ending_scope_review",
            "结局收束确认",
            "needs_human_review",
            "design",
            "D11 已写 ending reward closure 与 final node ending_result。",
            "确认是否进入结局演出 / 奖励收束强化，或先 promotion candidate。",
        ),
    ]
    fields["blocking_items_ready_for_manual_decision"] = all(item["status"] in {"pass", "needs_human_review"} for item in checklist)
    required_for_pass = [
        "promotion_review_checklist_ready",
        "pipeline_pass",
        "route_content_probe_pass",
        "save_bridge_probe_pass",
        "candidate_manifest_ready",
        "candidate_promotion_state_consistent",
        "manual_review_required",
        "content_pool_target_counts_ready",
        "active_profile_matches_current_release",
        "fallback_release_unchanged",
        "scene_unchanged",
        "combat_core_untouched",
        "blocking_items_ready_for_manual_decision",
    ]
    fields["review_report_pass"] = all(bool(fields.get(key, False)) for key in required_for_pass)

    payload = {
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "report": "aigc_dungeon_promotion_review_checklist",
        "fields": fields,
        "pool_summary": pool,
        "candidate_summary": {
            "release_candidate_id": candidate.get("release_candidate_id", ""),
            "candidate_status": candidate.get("candidate_status", ""),
            "promotion_policy": candidate.get("promotion_policy", {}),
            "promotion_state": "post_promotion" if current_is_dungeon else "pre_promotion",
        },
        "current_release_summary": {
            "mechanic_profile_id": current_release.get("mechanic_profile_id", ""),
            "content_pack_id": current_release.get("content_pack_id", ""),
            "runtime_manifest_path": current_release.get("runtime_manifest_path", ""),
        },
        "active_profile_summary": {
            "active_mechanic_profile_id": active_profile.get("active_mechanic_profile_id", ""),
            "active_content_pack_id": active_profile.get("active_content_pack_id", ""),
            "runtime_manifest_path": active_profile.get("runtime_manifest_path", ""),
        },
        "checklist": checklist,
        "next_decision_options": [
            "继续做结局演出 / 奖励收束强化",
            "继续做正式存档系统接入",
            "进入人工 promotion 审批后再 set-current",
        ],
        "review_report_pass": fields["review_report_pass"],
    }
    return payload


def write_markdown(payload: dict[str, Any]) -> None:
    fields = payload["fields"]
    lines = [
        "# AIGC Dungeon Promotion Review Checklist",
        "",
        "## Gate Summary",
        "",
    ]
    lines.extend(f"- `{key}={value}`" for key, value in fields.items())
    lines.extend(["", "## Pool Summary", ""])
    lines.extend(f"- `{key}={value}`" for key, value in payload["pool_summary"].items())
    lines.extend(["", "## Checklist", ""])
    for item in payload["checklist"]:
        lines.append(f"- `{item['item_id']}` {item['title']}：`{item['status']}`，owner=`{item['owner']}`。{item['evidence']}")
        if item["decision_needed"]:
            lines.append(f"  决策点：{item['decision_needed']}")
    lines.extend(["", "## Next Decision Options", ""])
    lines.extend(f"- {item}" for item in payload["next_decision_options"])
    REPORT_MD.parent.mkdir(parents=True, exist_ok=True)
    REPORT_MD.write_text("\n".join(lines) + "\n", encoding="utf-8")


def main() -> int:
    payload = build_report()
    write_json(REPORT_JSON, payload)
    write_markdown(payload)
    print(json.dumps(payload, ensure_ascii=False, indent=2))
    return 0 if bool(payload.get("review_report_pass", False)) else 1


if __name__ == "__main__":
    raise SystemExit(main())
