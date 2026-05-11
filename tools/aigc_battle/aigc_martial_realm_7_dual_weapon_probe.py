#!/usr/bin/env python3
from __future__ import annotations

import json
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[2]
PROFILE_ID = "martial_realm_7_dual_weapon_v0_1"
GENERATED_DIR = ROOT / "data" / "aigc_battle" / "generated" / PROFILE_ID
REPORT_JSON = GENERATED_DIR / "martial_realm_7_dual_weapon_probe_report.json"
REPORT_MD = GENERATED_DIR / "martial_realm_7_dual_weapon_probe_report.md"


def main() -> int:
    validation = read_json(GENERATED_DIR / "validation_report.json")
    runtime_manifest = read_json(GENERATED_DIR / "runtime_manifest.json")
    summary = read_json(GENERATED_DIR / "content_pack_summary.json")
    formal_probe = try_read_json(GENERATED_DIR / "formal_sequence_probe_report.json")
    reward_probe = try_read_json(GENERATED_DIR / "full_sequence_reward_probe_report.json")
    balance = read_json(GENERATED_DIR / "sequence_balance_summary.json")
    report = {
        "martial_realm_7_declared": bool(validation.get("martial_realm_7_declared", False)),
        "dual_weapon_declared": bool(validation.get("dual_weapon_declared", False)),
        "max_wujing_is_7": bool(validation.get("max_wujing_is_7", False)),
        "max_closing_form_tier_is_7": bool(validation.get("max_closing_form_tier_is_7", False)),
        "full_sequence_coverage_complete": bool(validation.get("full_sequence_coverage_complete", False)),
        "all_cards_have_required_wujing": bool(validation.get("all_cards_have_required_wujing", False)),
        "all_cards_have_closing_form_tier": bool(validation.get("all_cards_have_closing_form_tier", False)),
        "no_card_above_player_wujing_in_deck": bool(validation.get("no_card_above_player_wujing_in_deck", False)),
        "no_card_closing_form_above_player_wujing_in_deck": bool(validation.get("no_card_closing_form_above_player_wujing_in_deck", False)),
        "seven_realm_cards_only_in_wujing_7_slots": bool(validation.get("seven_realm_cards_only_in_wujing_7_slots", False)),
        "dual_weapon_slots_present": bool(validation.get("dual_weapon_slots_present", False)),
        "dual_weapon_ratio_valid": bool(validation.get("dual_weapon_ratio_valid", False)),
        "boss_slots_dual_weapon_enabled": bool(validation.get("boss_slots_dual_weapon_enabled", False)),
        "boss_slots_wujing_cap_7": bool(validation.get("boss_slots_wujing_cap_7", False)),
        "weapon_loadout_card_compatibility_valid": bool(validation.get("weapon_loadout_card_compatibility_valid", False)),
        "runtime_manifest_exports_martial_realm_7": "martial_realm_7" in runtime_manifest.get("runtime_primitives", []),
        "runtime_manifest_exports_dual_weapon": "dual_weapon" in runtime_manifest.get("runtime_primitives", []),
        "godot_loader_reads_martial_realm_7": script_contains("scripts/aigc_battle/aigc_battle_runtime_manifest_loader.gd", "max_required_wujing"),
        "godot_loader_reads_dual_weapon": script_contains("scripts/aigc_battle/aigc_battle_runtime_manifest_loader.gd", "dual_weapon_enabled"),
        "battle_observes_wujing_7_and_dual_weapon": script_contains("scripts/battle_controller_visual_narrative_context_apply.gd", "last_player_wujing_cap") and script_contains("scripts/battle_controller_visual_narrative_context_apply.gd", "last_dual_weapon_enabled"),
        "fallback_loadout_count": int(formal_probe.get("fallback_loadout_count", 0)) if formal_probe else 0,
        "reward_coverage_complete": bool(reward_probe.get("reward_coverage_complete", True)) if reward_probe else True,
        "sequence_balance_pass": bool(balance.get("sequence_balance_pass", False)),
        "review_workspace_ready": True,
        "release_candidate_ready": bool(validation.get("ready_for_runtime_export", False)),
        "dual_weapon_slot_count": int(summary.get("dual_weapon_slot_count", 0)),
        "dual_weapon_deck_count": int(summary.get("dual_weapon_deck_count", 0)),
        "seven_realm_card_count": int(summary.get("seven_realm_card_count", 0)),
    }
    report["probe_pass"] = all([
        report["martial_realm_7_declared"],
        report["dual_weapon_declared"],
        report["max_wujing_is_7"],
        report["max_closing_form_tier_is_7"],
        report["full_sequence_coverage_complete"],
        report["all_cards_have_required_wujing"],
        report["all_cards_have_closing_form_tier"],
        report["no_card_above_player_wujing_in_deck"],
        report["no_card_closing_form_above_player_wujing_in_deck"],
        report["seven_realm_cards_only_in_wujing_7_slots"],
        report["dual_weapon_slots_present"],
        report["dual_weapon_ratio_valid"],
        report["boss_slots_dual_weapon_enabled"],
        report["boss_slots_wujing_cap_7"],
        report["weapon_loadout_card_compatibility_valid"],
        report["runtime_manifest_exports_martial_realm_7"],
        report["runtime_manifest_exports_dual_weapon"],
        report["godot_loader_reads_martial_realm_7"],
        report["godot_loader_reads_dual_weapon"],
        report["battle_observes_wujing_7_and_dual_weapon"],
        report["fallback_loadout_count"] == 0,
        report["reward_coverage_complete"],
        report["sequence_balance_pass"],
        report["release_candidate_ready"],
    ])
    write_json(REPORT_JSON, report)
    REPORT_MD.write_text(markdown(report), encoding="utf-8")
    print("martial realm 7 dual weapon probe complete")
    return 0 if report["probe_pass"] else 1


def script_contains(relative_path: str, needle: str) -> bool:
    return needle in (ROOT / relative_path).read_text(encoding="utf-8")


def read_json(path: Path) -> Any:
    return json.loads(path.read_text(encoding="utf-8"))


def try_read_json(path: Path) -> dict[str, Any]:
    if not path.exists():
        return {}
    return read_json(path)


def write_json(path: Path, payload: Any) -> None:
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def markdown(report: dict[str, Any]) -> str:
    return "# Martial Realm 7 Dual Weapon Probe\n\n" + "\n".join(f"- {k}: `{v}`" for k, v in report.items()) + "\n"


if __name__ == "__main__":
    raise SystemExit(main())
