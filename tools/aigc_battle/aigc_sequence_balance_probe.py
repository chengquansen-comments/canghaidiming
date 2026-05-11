#!/usr/bin/env python3
from __future__ import annotations

import json
import sys
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[2]
RUNTIME_DIR = ROOT / "data" / "aigc_battle" / "runtime"
GENERATED_DIR = ROOT / "data" / "aigc_battle" / "generated"


def main(argv: list[str]) -> int:
    if len(argv) > 2:
        print("usage: python tools/aigc_battle/aigc_sequence_balance_probe.py [profile_id]", file=sys.stderr)
        return 1
    profile_id = argv[1] if len(argv) == 2 else read_active_profile_id()
    active_profile = read_json(RUNTIME_DIR / "active_profile.json")
    runtime_manifest_path = ROOT / str(active_profile["runtime_manifest_path"])
    runtime_manifest = read_json(runtime_manifest_path)
    generated_dir = GENERATED_DIR / profile_id
    balance_summary = read_json(generated_dir / "sequence_balance_summary.json")

    battle_slots = runtime_manifest.get("battle_slots", [])
    decks = runtime_manifest.get("enemy_decks", [])
    rewards = runtime_manifest.get("rewards", [])
    mappings = runtime_manifest.get("formal_sequence_mapping", [])

    battle_slots_with_balance_metadata_count = sum(
        1
        for slot in battle_slots
        if all(field in slot for field in ["sequence_position", "encounter_tier", "encounter_kind", "target_power_min", "target_power_max", "reward_tier"])
    )
    decks_with_power_range_count = sum(
        1
        for deck in decks
        if float(deck.get("target_power_min", -1)) <= float(deck.get("deck_power_score", -999)) <= float(deck.get("target_power_max", -1))
    )
    rewards_with_tier_count = sum(1 for reward in rewards if str(reward.get("reward_tier", "")).strip())

    report = {
        "active_profile_loaded": True,
        "runtime_manifest_loaded": True,
        "formal_encounter_total_count": len(mappings),
        "battle_slots_with_balance_metadata_count": battle_slots_with_balance_metadata_count,
        "decks_with_power_range_count": decks_with_power_range_count,
        "rewards_with_tier_count": rewards_with_tier_count,
        "sequence_balance_curve_ready": bool(balance_summary.get("sequence_balance_curve_ready", False)),
        "all_decks_within_power_range": bool(balance_summary.get("all_decks_within_power_range", False)),
        "elite_decks_stronger_than_normal": bool(balance_summary.get("elite_decks_stronger_than_normal", False)),
        "boss_decks_stronger_than_elite": bool(balance_summary.get("boss_decks_stronger_than_elite", False)),
        "late_avg_power_over_early": float(balance_summary.get("late_avg_power_over_early", 0)),
        "sequence_balance_pass": bool(balance_summary.get("sequence_balance_pass", False)) and battle_slots_with_balance_metadata_count == len(battle_slots) and decks_with_power_range_count == len(decks) and rewards_with_tier_count == len(rewards),
    }
    write_json(generated_dir / "sequence_balance_probe_report.json", report)
    write_markdown(generated_dir / "sequence_balance_probe_report.md", report)
    print("sequence balance probe complete")
    return 0 if report["sequence_balance_pass"] else 1


def read_active_profile_id() -> str:
    active_profile = read_json(RUNTIME_DIR / "active_profile.json")
    return str(active_profile["active_mechanic_profile_id"])


def read_json(path: Path) -> Any:
    return json.loads(path.read_text(encoding="utf-8"))


def write_json(path: Path, payload: Any) -> None:
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def write_markdown(path: Path, report: dict[str, Any]) -> None:
    lines = [
        "# AIGC Battle v3 平衡探针",
        "",
        f"- formal_encounter_total_count: {report['formal_encounter_total_count']}",
        f"- battle_slots_with_balance_metadata_count: {report['battle_slots_with_balance_metadata_count']}",
        f"- decks_with_power_range_count: {report['decks_with_power_range_count']}",
        f"- rewards_with_tier_count: {report['rewards_with_tier_count']}",
        f"- sequence_balance_curve_ready: {str(report['sequence_balance_curve_ready']).lower()}",
        f"- all_decks_within_power_range: {str(report['all_decks_within_power_range']).lower()}",
        f"- boss_decks_stronger_than_elite: {str(report['boss_decks_stronger_than_elite']).lower()}",
        f"- late_avg_power_over_early: {report['late_avg_power_over_early']}",
        f"- sequence_balance_pass: {str(report['sequence_balance_pass']).lower()}",
    ]
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
