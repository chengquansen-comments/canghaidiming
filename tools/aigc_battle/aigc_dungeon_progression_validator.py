#!/usr/bin/env python3
from __future__ import annotations

import hashlib
import json
from dataclasses import dataclass
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[2]
PROGRESSION_PATH = ROOT / "data" / "aigc_battle" / "progression_templates" / "dungeon_progression_v1_3.json"
PACK_DIR = ROOT / "data" / "aigc_battle" / "generated" / "dungeon_progression_v1_3" / "packs" / "dungeon_pool_pack_001"
REPORTS_DIR = ROOT / "data" / "aigc_battle" / "generated" / "dungeon_progression_v1_3" / "reports"
CURRENT_RELEASE_PATH = ROOT / "data" / "aigc_battle" / "release_channels" / "current_release.json"
ACTIVE_PROFILE_PATH = ROOT / "data" / "aigc_battle" / "runtime" / "active_profile.json"
FALLBACK_RELEASE_PATH = ROOT / "data" / "aigc_battle" / "release_channels" / "fallback_release.json"

PACK_FILES = {
    "content_pool_manifest": PACK_DIR / "content_pool_manifest.json",
    "battle_slot_pool": PACK_DIR / "battle_slot_pool.json",
    "enemy_deck_pool": PACK_DIR / "enemy_deck_pool.json",
    "reward_plan_pool": PACK_DIR / "reward_plan_pool.json",
    "card_pool": PACK_DIR / "card_pool.json",
    "operation_node_pool": PACK_DIR / "operation_node_pool.json",
    "route_rules": PACK_DIR / "route_rules.json",
    "growth_rules": PACK_DIR / "growth_rules.json",
}


@dataclass
class CheckResult:
    key: str
    passed: bool
    actual: Any
    expected: Any
    reason: str = ""

    def to_dict(self) -> dict[str, Any]:
        return {
            "passed": self.passed,
            "actual": self.actual,
            "expected": self.expected,
            "reason": self.reason,
        }


def _read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def _read_json(path: Path) -> dict[str, Any]:
    return json.loads(_read_text(path))


def _hash_text(text: str) -> str:
    return hashlib.sha256(text.encode("utf-8")).hexdigest()


def _write_json(path: Path, payload: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def _write_text(path: Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8")


def _battle_slot_counts(slots: list[dict[str, Any]]) -> dict[str, int]:
    return {
        "prologue": sum(1 for slot in slots if slot.get("stage") == "prologue"),
        "wuju": sum(1 for slot in slots if slot.get("stage") == "wuju"),
        "big_map_normal": sum(1 for slot in slots if slot.get("stage") == "big_map" and slot.get("battle_type") == "normal"),
        "big_map_elite": sum(1 for slot in slots if slot.get("stage") == "big_map" and slot.get("battle_type") == "elite"),
        "rare_event": sum(1 for slot in slots if slot.get("battle_type") == "rare_event"),
        "normal_boss": sum(1 for slot in slots if slot.get("route_type") == "normal" and slot.get("battle_type") == "boss"),
        "true_boss": sum(1 for slot in slots if slot.get("route_type") == "true" and slot.get("battle_type") == "boss"),
        "wuzhuangyuan_exam": sum(1 for slot in slots if slot.get("route_type") == "wuzhuangyuan" and slot.get("battle_type") == "capital_exam"),
    }


def run_validation() -> dict[str, Any]:
    current_release_before = _read_text(CURRENT_RELEASE_PATH)
    active_profile_before = _read_text(ACTIVE_PROFILE_PATH)
    fallback_release_before = _read_text(FALLBACK_RELEASE_PATH)

    progression = _read_json(PROGRESSION_PATH)
    pack_files = {name: _read_json(path) for name, path in PACK_FILES.items()}

    battle_slots = pack_files["battle_slot_pool"].get("battle_slots", [])
    enemy_decks = pack_files["enemy_deck_pool"].get("enemy_decks", [])
    reward_plans = pack_files["reward_plan_pool"].get("reward_plans", [])
    cards = pack_files["card_pool"].get("cards", [])
    operation_nodes = pack_files["operation_node_pool"].get("operation_nodes", [])

    enemy_deck_ids = {str(item.get("enemy_deck_id", "")) for item in enemy_decks if isinstance(item, dict)}
    reward_plan_ids = {str(item.get("reward_plan_id", "")) for item in reward_plans if isinstance(item, dict)}
    card_ids = {str(item.get("card_id", "")) for item in cards if isinstance(item, dict)}

    adapter_fields = [
        "map_node_type_hint",
        "compatible_network_node_type",
        "compatible_combat_pool_id",
        "compatible_encounter_id",
        "compatible_battle_id",
    ]

    checks: list[CheckResult] = []
    segments = progression.get("segments", {})
    big_map = segments.get("big_map", {})
    ending_routes = progression.get("ending_routes", {})
    growth_model = progression.get("growth_model", {})
    lightness_model = progression.get("lightness_model", {})
    constraints = progression.get("big_map_constraints", {})
    counts = _battle_slot_counts([slot for slot in battle_slots if isinstance(slot, dict)])

    checks.append(CheckResult("prologue_fixed_battle_count", segments.get("prologue", {}).get("fixed_battle_count") == 1, segments.get("prologue", {}).get("fixed_battle_count"), 1))
    checks.append(CheckResult("wuju_fixed_battle_count", segments.get("wuju", {}).get("fixed_battle_count") == 5, segments.get("wuju", {}).get("fixed_battle_count"), 5))
    checks.append(CheckResult("big_map_battle_count_target", big_map.get("battle_count_target") == 15, big_map.get("battle_count_target"), 15))
    checks.append(CheckResult("big_map_battle_count_min", big_map.get("battle_count_min") == 14, big_map.get("battle_count_min"), 14))
    checks.append(CheckResult("big_map_battle_count_max", big_map.get("battle_count_max") == 16, big_map.get("battle_count_max"), 16))
    checks.append(CheckResult("big_map_candidate_pool_target", big_map.get("candidate_pool_target") == 30, big_map.get("candidate_pool_target"), 30))
    checks.append(CheckResult("normal_route_target_total", ending_routes.get("normal", {}).get("target_total_battles") == 22, ending_routes.get("normal", {}).get("target_total_battles"), 22))
    checks.append(CheckResult("true_route_target_total", ending_routes.get("true", {}).get("target_total_battles") == 23, ending_routes.get("true", {}).get("target_total_battles"), 23))
    checks.append(CheckResult("wuzhuangyuan_route_target_total", ending_routes.get("wuzhuangyuan", {}).get("target_total_battles") == 26, ending_routes.get("wuzhuangyuan", {}).get("target_total_battles"), 26))
    checks.append(CheckResult("martial_realm_max", growth_model.get("martial_realm_max") == 10, growth_model.get("martial_realm_max"), 10))
    checks.append(CheckResult("lightness_max", lightness_model.get("lightness_max") == 4, lightness_model.get("lightness_max"), 4))
    checks.append(CheckResult("normal_lightness_cap", lightness_model.get("normal_lightness_cap") == 2, lightness_model.get("normal_lightness_cap"), 2))
    checks.append(CheckResult("no_fixed_linear_sequence", constraints.get("no_fixed_linear_sequence") is True, constraints.get("no_fixed_linear_sequence"), True))
    checks.append(CheckResult("route_choice_required", constraints.get("route_choice_required") is True, constraints.get("route_choice_required"), True))

    enemy_ref_errors = []
    reward_ref_errors = []
    adapter_field_errors = []
    for slot in battle_slots:
        if not isinstance(slot, dict):
            continue
        slot_id = str(slot.get("battle_slot_id", ""))
        if str(slot.get("enemy_deck_id", "")) not in enemy_deck_ids:
            enemy_ref_errors.append(slot_id)
        if str(slot.get("reward_plan_id", "")) not in reward_plan_ids:
            reward_ref_errors.append(slot_id)
        for field in adapter_fields:
            if field not in slot:
                adapter_field_errors.append("%s:%s" % [slot_id, field])

    reward_card_errors = []
    for reward in reward_plans:
        if not isinstance(reward, dict):
            continue
        reward_id = str(reward.get("reward_plan_id", ""))
        for card_id in reward.get("card_rewards", []):
            card_text = str(card_id)
            if card_text and card_text not in card_ids:
                reward_card_errors.append("%s:%s" % [reward_id, card_text])

    checks.append(CheckResult("all_battle_slot_enemy_deck_refs_exist", not enemy_ref_errors, enemy_ref_errors, []))
    checks.append(CheckResult("all_battle_slot_reward_plan_refs_exist", not reward_ref_errors, reward_ref_errors, []))
    checks.append(CheckResult("all_reward_card_refs_exist_or_placeholder_allowed", not reward_card_errors, reward_card_errors, []))
    checks.append(CheckResult("operation_node_pool_exists", len(operation_nodes) > 0, len(operation_nodes), ">0"))
    checks.append(CheckResult("existing_big_map_adapter_fields_exist", not adapter_field_errors, adapter_field_errors, []))

    current_release = json.loads(current_release_before)
    active_profile = json.loads(active_profile_before)
    fallback_release = json.loads(fallback_release_before)
    active_matches_current = (
        str(active_profile.get("active_mechanic_profile_id", "")) == str(current_release.get("mechanic_profile_id", ""))
        and str(active_profile.get("active_content_pack_id", "")) == str(current_release.get("content_pack_id", ""))
        and str(active_profile.get("runtime_manifest_path", "")) == str(current_release.get("runtime_manifest_path", ""))
    )

    current_release_after = _read_text(CURRENT_RELEASE_PATH)
    active_profile_after = _read_text(ACTIVE_PROFILE_PATH)
    fallback_release_after = _read_text(FALLBACK_RELEASE_PATH)

    checks.append(CheckResult("current_release_unchanged", current_release_before == current_release_after, _hash_text(current_release_after), _hash_text(current_release_before)))
    checks.append(CheckResult("active_profile_matches_current_release", active_matches_current, {
        "active_mechanic_profile_id": active_profile.get("active_mechanic_profile_id"),
        "active_content_pack_id": active_profile.get("active_content_pack_id"),
        "runtime_manifest_path": active_profile.get("runtime_manifest_path")
    }, {
        "mechanic_profile_id": current_release.get("mechanic_profile_id"),
        "content_pack_id": current_release.get("content_pack_id"),
        "runtime_manifest_path": current_release.get("runtime_manifest_path")
    }))
    checks.append(CheckResult("fallback_release_unchanged", fallback_release_before == fallback_release_after, _hash_text(fallback_release_after), _hash_text(fallback_release_before)))

    report = {
        "validator": "aigc_dungeon_progression_validator",
        "progression_template_path": str(PROGRESSION_PATH.relative_to(ROOT)),
        "pack_dir": str(PACK_DIR.relative_to(ROOT)),
        "summary": {
            "prologue_slot_count": counts["prologue"],
            "wuju_slot_count": counts["wuju"],
            "big_map_normal_candidate_count": counts["big_map_normal"],
            "big_map_elite_candidate_count": counts["big_map_elite"],
            "rare_event_candidate_count": counts["rare_event"],
            "normal_boss_count": counts["normal_boss"],
            "true_boss_count": counts["true_boss"],
            "wuzhuangyuan_exam_count": counts["wuzhuangyuan_exam"],
            "card_pool_count": len(cards),
            "enemy_deck_pool_count": len(enemy_decks),
            "reward_plan_pool_count": len(reward_plans),
            "operation_node_pool_count": len(operation_nodes)
        },
        "checks": {item.key: item.to_dict() for item in checks},
    }
    report["all_checks_passed"] = all(item.passed for item in checks)

    md_lines = [
        "# Dungeon Pool Validation Report",
        "",
        "## Summary",
        "- progression_template: `%s`" % PROGRESSION_PATH.relative_to(ROOT),
        "- content_pool_pack: `%s`" % PACK_DIR.relative_to(ROOT),
        "- all_checks_passed: `%s`" % str(report["all_checks_passed"]).lower(),
        "- prologue_slot_count: `%s`" % counts["prologue"],
        "- wuju_slot_count: `%s`" % counts["wuju"],
        "- big_map_normal_candidate_count: `%s`" % counts["big_map_normal"],
        "- big_map_elite_candidate_count: `%s`" % counts["big_map_elite"],
        "- rare_event_candidate_count: `%s`" % counts["rare_event"],
        "",
        "## Checks",
    ]
    for item in checks:
        status = "pass" if item.passed else "fail"
        md_lines.append("- `%s=%s` actual=`%s` expected=`%s`" % (item.key, status, item.actual, item.expected))

    report_json_path = REPORTS_DIR / "pool_validation_report.json"
    report_md_path = REPORTS_DIR / "pool_validation_report.md"
    pack_report_json_path = PACK_DIR / "pool_validation_report.json"
    pack_report_md_path = PACK_DIR / "pool_validation_report.md"

    _write_json(report_json_path, report)
    _write_text(report_md_path, "\n".join(md_lines) + "\n")
    _write_json(pack_report_json_path, report)
    _write_text(pack_report_md_path, "\n".join(md_lines) + "\n")
    return report


def main() -> None:
    report = run_validation()
    print("wrote %s" % (REPORTS_DIR / "pool_validation_report.json").relative_to(ROOT))
    print("wrote %s" % (REPORTS_DIR / "pool_validation_report.md").relative_to(ROOT))
    print("all_checks_passed=%s" % str(report["all_checks_passed"]).lower())


if __name__ == "__main__":
    main()
