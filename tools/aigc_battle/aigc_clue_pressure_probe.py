#!/usr/bin/env python3
from __future__ import annotations

import json
import sys
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[2]
PROFILE_ID = "clue_pressure_v0_1"
GENERATED_DIR = ROOT / "data" / "aigc_battle" / "generated" / PROFILE_ID
REPORT_JSON = GENERATED_DIR / "clue_pressure_probe_report.json"
REPORT_MD = GENERATED_DIR / "clue_pressure_probe_report.md"


def main() -> int:
    validation = read_json(GENERATED_DIR / "validation_report.json")
    runtime_manifest = read_json(GENERATED_DIR / "runtime_manifest.json")
    summary = read_json(GENERATED_DIR / "content_pack_summary.json")
    battle_slots = read_json(GENERATED_DIR / "battle_slot_bindings.generated.json")
    formal_probe = try_read_json(GENERATED_DIR / "formal_sequence_probe_report.json")
    reward_probe = try_read_json(GENERATED_DIR / "full_sequence_reward_probe_report.json")
    balance_probe = try_read_json(GENERATED_DIR / "sequence_balance_summary.json")
    report = {
        "clue_pressure_declared": bool(validation.get("clue_pressure_declared", False)),
        "full_sequence_coverage_complete": bool(validation.get("full_sequence_coverage_complete", False)),
        "clue_pressure_all_slots_covered": bool(validation.get("clue_pressure_all_slots_covered", False)),
        "clue_pressure_tags_valid": bool(validation.get("clue_pressure_tags_valid", False)),
        "clue_pressure_effects_valid": bool(validation.get("clue_pressure_effects_valid", False)),
        "clue_pressure_values_in_range": bool(validation.get("clue_pressure_values_in_range", False)),
        "runtime_manifest_exports_clue_pressure": "clue_pressure" in runtime_manifest.get("runtime_primitives", []),
        "godot_loader_reads_clue_pressure": script_contains("scripts/aigc_battle/aigc_battle_runtime_manifest_loader.gd", "get_clue_pressure"),
        "battle_applies_clue_pressure_effect": script_contains("scripts/battle_controller_visual_narrative_context_apply.gd", "_apply_clue_pressure_runtime_effect"),
        "clue_pressure_trigger_count": int(summary.get("clue_pressure_trigger_count", 0)),
        "fallback_loadout_count": int(formal_probe.get("fallback_loadout_count", 0)) if formal_probe else 0,
        "reward_coverage_complete": bool(reward_probe.get("reward_coverage_complete", True)) if reward_probe else len(read_json(GENERATED_DIR / "rewards.generated.json")) == len(battle_slots),
        "sequence_balance_pass": bool(balance_probe.get("sequence_balance_pass", False)),
        "review_workspace_ready": True,
        "release_candidate_ready": bool(validation.get("ready_for_runtime_export", False)),
    }
    report["probe_pass"] = all([
        report["clue_pressure_declared"],
        report["full_sequence_coverage_complete"],
        report["clue_pressure_all_slots_covered"],
        report["clue_pressure_tags_valid"],
        report["clue_pressure_effects_valid"],
        report["clue_pressure_values_in_range"],
        report["runtime_manifest_exports_clue_pressure"],
        report["godot_loader_reads_clue_pressure"],
        report["battle_applies_clue_pressure_effect"],
        report["clue_pressure_trigger_count"] > 0,
        report["fallback_loadout_count"] == 0,
        report["reward_coverage_complete"],
        report["sequence_balance_pass"],
        report["release_candidate_ready"],
    ])
    write_json(REPORT_JSON, report)
    REPORT_MD.write_text(markdown(report), encoding="utf-8")
    print("clue pressure probe complete")
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
    return "# Clue Pressure Probe\n\n" + "\n".join(f"- {k}: `{v}`" for k, v in report.items()) + "\n"


if __name__ == "__main__":
    raise SystemExit(main())
