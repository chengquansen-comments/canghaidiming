#!/usr/bin/env python3
from __future__ import annotations

import json
import sys
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[2]
GENERATED_DIR = ROOT / "data" / "aigc_battle" / "generated"
TELEMETRY_PATH = ROOT / "data" / "aigc_battle" / "telemetry" / "aigc_sequence_telemetry.jsonl"


def main(argv: list[str]) -> int:
    if len(argv) != 2:
        print("usage: python3 tools/aigc_battle/build_sequence_balance_snapshot.py <profile_id>", file=sys.stderr)
        return 1
    profile_id = argv[1]
    generated_dir = GENERATED_DIR / profile_id
    runtime_manifest = read_json(generated_dir / "runtime_manifest.json")
    balance_summary = read_json(generated_dir / "sequence_balance_summary.json")
    telemetry_events = read_jsonl(TELEMETRY_PATH)

    profile_events = [
        event for event in telemetry_events
        if str(event.get("mechanic_profile_id", "")) == str(runtime_manifest.get("mechanic_profile_id", ""))
        and str(event.get("content_pack_id", "")) == str(runtime_manifest.get("content_pack_id", ""))
    ]
    mappings = runtime_manifest.get("formal_sequence_mapping", [])
    encounter_ids = [str(item.get("formal_encounter_id", "")) for item in mappings]
    deck_by_encounter = {str(item.get("formal_encounter_id", "")): str(item.get("generated_deck_id", "")) for item in mappings}
    events_by_encounter: dict[str, list[dict[str, Any]]] = {}
    for event in profile_events:
        events_by_encounter.setdefault(str(event.get("formal_encounter_id", "")), []).append(event)

    missing_telemetry_encounters = [encounter_id for encounter_id in encounter_ids if encounter_id not in events_by_encounter]
    abnormal_decks: list[dict[str, Any]] = []
    weak_decks: list[dict[str, Any]] = []
    overpowered_decks: list[dict[str, Any]] = []
    reward_claim_summary = {"claimed": 0, "unclaimed": 0}
    recommendations: list[dict[str, Any]] = []

    for encounter_id in encounter_ids:
        encounter_events = events_by_encounter.get(encounter_id, [])
        if not encounter_events:
            recommendations.append({
                "formal_encounter_id": encounter_id,
                "deck_id": deck_by_encounter.get(encounter_id, ""),
                "action": "collect_more_telemetry",
                "reason": "missing_telemetry",
            })
            continue
        last_event = encounter_events[-1]
        deck_id = str(last_event.get("generated_deck_id", deck_by_encounter.get(encounter_id, "")))
        reward_claimed = bool(last_event.get("reward_claimed", False))
        if reward_claimed:
            reward_claim_summary["claimed"] += 1
        else:
            reward_claim_summary["unclaimed"] += 1
            abnormal_decks.append({
                "formal_encounter_id": encounter_id,
                "deck_id": deck_id,
                "issue": "reward_flow_candidate_issue",
            })
            recommendations.append({
                "formal_encounter_id": encounter_id,
                "deck_id": deck_id,
                "action": "inspect_reward_flow",
                "reason": "reward_not_claimed",
            })
        target_min = float(last_event.get("target_power_min", 0))
        target_max = float(last_event.get("target_power_max", 0))
        deck_power = float(last_event.get("deck_power_score", 0))
        if not (target_min <= deck_power <= target_max):
            abnormal_decks.append({
                "formal_encounter_id": encounter_id,
                "deck_id": deck_id,
                "issue": "deck_power_out_of_range",
                "deck_power_score": deck_power,
                "target_power_min": target_min,
                "target_power_max": target_max,
            })
            recommendations.append({
                "formal_encounter_id": encounter_id,
                "deck_id": deck_id,
                "action": "rebuild_target_range",
                "reason": "deck_power_out_of_range",
            })
        turn_count = int(last_event.get("turn_count", -1))
        player_hp_end = int(last_event.get("player_hp_end", -1))
        win = bool(last_event.get("win", False))
        if turn_count >= 0 and win and turn_count <= 2:
            weak_decks.append({
                "formal_encounter_id": encounter_id,
                "deck_id": deck_id,
                "issue": "weak_candidate",
                "turn_count": turn_count,
            })
            recommendations.append({
                "formal_encounter_id": encounter_id,
                "deck_id": deck_id,
                "action": "raise_target_range",
                "reason": "very_short_win",
            })
        elif turn_count >= 0 and (not win) and player_hp_end >= 0 and player_hp_end <= 3:
            overpowered_decks.append({
                "formal_encounter_id": encounter_id,
                "deck_id": deck_id,
                "issue": "overpowered_candidate",
                "player_hp_end": player_hp_end,
            })
            recommendations.append({
                "formal_encounter_id": encounter_id,
                "deck_id": deck_id,
                "action": "lower_target_range",
                "reason": "low_hp_loss",
            })
        elif turn_count < 0:
            recommendations.append({
                "formal_encounter_id": encounter_id,
                "deck_id": deck_id,
                "action": "flag_only",
                "reason": "telemetry_insufficient",
            })

    snapshot = {
        "mechanic_profile_id": runtime_manifest.get("mechanic_profile_id", ""),
        "content_pack_id": runtime_manifest.get("content_pack_id", ""),
        "target_sequence_id": runtime_manifest.get("target_sequence_id", ""),
        "snapshot_path": str((generated_dir / "sequence_balance_snapshot.json").resolve()),
        "telemetry_event_count": len(profile_events),
        "formal_encounter_total_count": len(encounter_ids),
        "encounters_with_telemetry_count": len(events_by_encounter),
        "missing_telemetry_encounters": missing_telemetry_encounters,
        "deck_result_summary": balance_summary.get("deck_power_by_encounter", []),
        "abnormal_decks": abnormal_decks,
        "weak_decks": weak_decks,
        "overpowered_decks": overpowered_decks,
        "reward_claim_summary": reward_claim_summary,
        "sequence_rebuild_recommendations": recommendations,
        "snapshot_ready": len(missing_telemetry_encounters) == 0 and len(profile_events) >= len(encounter_ids),
    }
    write_json(generated_dir / "sequence_balance_snapshot.json", snapshot)
    write_markdown(generated_dir / "sequence_balance_snapshot.md", snapshot)
    print(f"built sequence balance snapshot: {profile_id}")
    return 0 if snapshot["snapshot_ready"] else 1


def read_json(path: Path) -> Any:
    return json.loads(path.read_text(encoding="utf-8"))


def read_jsonl(path: Path) -> list[dict[str, Any]]:
    if not path.exists():
        return []
    events: list[dict[str, Any]] = []
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line:
            continue
        parsed = json.loads(line)
        if isinstance(parsed, dict):
            events.append(parsed)
    return events


def write_json(path: Path, payload: Any) -> None:
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def write_markdown(path: Path, snapshot: dict[str, Any]) -> None:
    lines = [
        "# AIGC Battle v8 Sequence Balance Snapshot",
        "",
        f"- snapshot_ready: {str(snapshot['snapshot_ready']).lower()}",
        f"- telemetry_event_count: {snapshot['telemetry_event_count']}",
        f"- formal_encounter_total_count: {snapshot['formal_encounter_total_count']}",
        f"- encounters_with_telemetry_count: {snapshot['encounters_with_telemetry_count']}",
        f"- missing_telemetry_encounters: {snapshot['missing_telemetry_encounters']}",
        f"- abnormal_decks: {snapshot['abnormal_decks']}",
        f"- weak_decks: {snapshot['weak_decks']}",
        f"- overpowered_decks: {snapshot['overpowered_decks']}",
        f"- sequence_rebuild_recommendations: {snapshot['sequence_rebuild_recommendations']}",
    ]
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
