#!/usr/bin/env python3
"""Generate Content Engine v0.5d route gate plan (design-layer only)."""

from __future__ import annotations

import argparse
import csv
from dataclasses import dataclass
from pathlib import Path


OUTPUT_FIELDS = [
    "route_gate_id",
    "route_id",
    "route_type",
    "ending_route",
    "gate_stage",
    "gate_kind",
    "priority",
    "required_flags",
    "optional_flags",
    "blocked_by_flags",
    "required_martial_realm_min",
    "required_military_merit_level",
    "required_clean_reputation_level",
    "required_old_case_progress_level",
    "required_lightness_level",
    "required_elite_battle_count",
    "required_boss_clear",
    "source_battle_reward_ids",
    "source_operation_node_ids",
    "source_narrative_node_ids",
    "source_route_gate_tags",
    "unlock_result",
    "fallback_route",
    "is_hard_gate",
    "is_player_choice",
    "risk_level",
    "notes",
]

INPUT_FILES = [
    "generated_battle_reward_plan.tsv",
    "generated_operation_node_plan.tsv",
    "generated_narrative_node_plan.tsv",
    "generated_route_progression_curve.tsv",
    "progression_numeric_config_v1_3.tsv",
]


@dataclass(frozen=True)
class RouteGate:
    route_gate_id: str
    route_id: str
    route_type: str
    ending_route: str
    gate_stage: str
    gate_kind: str
    priority: int
    required_flags: list[str]
    optional_flags: list[str]
    blocked_by_flags: list[str]
    required_martial_realm_min: str
    required_military_merit_level: str
    required_clean_reputation_level: str
    required_old_case_progress_level: str
    required_lightness_level: str
    required_elite_battle_count: str
    required_boss_clear: str
    source_battle_reward_ids: list[str]
    source_operation_node_ids: list[str]
    source_narrative_node_ids: list[str]
    source_route_gate_tags: list[str]
    unlock_result: str
    fallback_route: str
    is_hard_gate: bool
    is_player_choice: bool
    risk_level: str
    notes: str

    def to_row(self) -> dict[str, str]:
        return {
            "route_gate_id": self.route_gate_id,
            "route_id": self.route_id,
            "route_type": self.route_type,
            "ending_route": self.ending_route,
            "gate_stage": self.gate_stage,
            "gate_kind": self.gate_kind,
            "priority": str(self.priority),
            "required_flags": join_tokens(self.required_flags),
            "optional_flags": join_tokens(self.optional_flags),
            "blocked_by_flags": join_tokens(self.blocked_by_flags),
            "required_martial_realm_min": self.required_martial_realm_min,
            "required_military_merit_level": self.required_military_merit_level,
            "required_clean_reputation_level": self.required_clean_reputation_level,
            "required_old_case_progress_level": self.required_old_case_progress_level,
            "required_lightness_level": self.required_lightness_level,
            "required_elite_battle_count": self.required_elite_battle_count,
            "required_boss_clear": self.required_boss_clear,
            "source_battle_reward_ids": join_tokens(self.source_battle_reward_ids),
            "source_operation_node_ids": join_tokens(self.source_operation_node_ids),
            "source_narrative_node_ids": join_tokens(self.source_narrative_node_ids),
            "source_route_gate_tags": join_tokens(self.source_route_gate_tags),
            "unlock_result": self.unlock_result,
            "fallback_route": self.fallback_route,
            "is_hard_gate": as_bool_text(self.is_hard_gate),
            "is_player_choice": as_bool_text(self.is_player_choice),
            "risk_level": self.risk_level,
            "notes": self.notes,
        }


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Generate deterministic route gate plan for Content Engine v0.5d.")
    parser.add_argument("--design-dir", default="data/design")
    parser.add_argument("--out", default="data/design/generated_route_gate_plan.tsv")
    return parser.parse_args()


def must_exist(design_dir: Path) -> None:
    missing = [name for name in INPUT_FILES if not (design_dir / name).exists()]
    if missing:
        joined = ", ".join(str(design_dir / name) for name in missing)
        raise FileNotFoundError(f"Missing required design inputs: {joined}")


def read_tsv(path: Path) -> list[dict[str, str]]:
    with path.open("r", encoding="utf-8", newline="") as handle:
        return list(csv.DictReader(handle, delimiter="\t"))


def write_tsv(path: Path, rows: list[dict[str, str]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=OUTPUT_FIELDS, delimiter="\t", lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)


def as_bool(value: str) -> bool:
    return (value or "").strip().lower() in {"1", "true", "yes"}


def as_bool_text(value: bool) -> str:
    return "true" if value else "false"


def as_int(value: str, default: int = 0) -> int:
    try:
        return int(round(float((value or "").strip())))
    except ValueError:
        return default


def split_tokens(value: str) -> list[str]:
    out: list[str] = []
    for part in (value or "").split(","):
        token = part.strip()
        if not token or token.lower() == "none":
            continue
        out.append(token)
    return out


def unique_sorted(values: list[str]) -> list[str]:
    return sorted({value for value in values if value})


def join_tokens(values: list[str]) -> str:
    cleaned = unique_sorted(values)
    return ",".join(cleaned) if cleaned else "none"


def collect_battle_ids(rows: list[dict[str, str]], predicate: callable) -> list[str]:
    return unique_sorted([row.get("reward_plan_id", "") for row in rows if predicate(row)])


def collect_operation_ids(rows: list[dict[str, str]], predicate: callable) -> list[str]:
    return unique_sorted([row.get("operation_node_id", "") for row in rows if predicate(row)])


def collect_narrative_ids(rows: list[dict[str, str]], predicate: callable) -> list[str]:
    return unique_sorted([row.get("narrative_node_id", "") for row in rows if predicate(row)])


def row_tags(row: dict[str, str]) -> set[str]:
    tags: set[str] = set()
    for key in ["route_gate_tags", "hook_tags"]:
        tags.update(split_tokens(row.get(key, "")))
    return tags


def collect_narrative_tags(rows: list[dict[str, str]], predicate: callable) -> list[str]:
    tags: list[str] = []
    for row in rows:
        if not predicate(row):
            continue
        tags.extend(list(row_tags(row)))
    return unique_sorted(tags)


def gate_normal_ending_default() -> RouteGate:
    return RouteGate(
        route_gate_id="gate_normal_ending_default",
        route_id="normal_ending",
        route_type="normal",
        ending_route="normal",
        gate_stage="ending",
        gate_kind="default_fallback",
        priority=90,
        required_flags=[],
        optional_flags=["clean_reputation_high"],
        blocked_by_flags=[],
        required_martial_realm_min="8",
        required_military_merit_level="none",
        required_clean_reputation_level="none",
        required_old_case_progress_level="none",
        required_lightness_level="",
        required_elite_battle_count="",
        required_boss_clear="",
        source_battle_reward_ids=[],
        source_operation_node_ids=[],
        source_narrative_node_ids=[],
        source_route_gate_tags=[],
        unlock_result="fallback_normal_ending",
        fallback_route="none",
        is_hard_gate=False,
        is_player_choice=False,
        risk_level="low",
        notes="Normal ending fallback gate; default path when higher routes are not selected.",
    )


def build_gates(
    battle_rows: list[dict[str, str]],
    operation_rows: list[dict[str, str]],
    narrative_rows: list[dict[str, str]],
) -> list[RouteGate]:
    true_battle_ids = collect_battle_ids(
        battle_rows,
        lambda row: row.get("route_type") == "true_route"
        or row.get("ending_route") == "true_route"
        or (as_bool(row.get("can_trigger_realm_10", "")) and as_int(row.get("old_case_progress_reward", "0"), 0) > 0),
    )
    true_boss_ids = collect_battle_ids(
        battle_rows,
        lambda row: row.get("battle_slot_id") == "true_boss_01" or row.get("battle_type") == "true_boss",
    )
    normal_boss_ids = collect_battle_ids(
        battle_rows, lambda row: row.get("battle_type") == "boss" and row.get("route_type") == "normal"
    )
    wz_candidate_battle_ids = collect_battle_ids(battle_rows, lambda row: as_bool(row.get("can_trigger_wuzhuangyuan_route", "")))
    wz_exam_battle_ids = collect_battle_ids(battle_rows, lambda row: row.get("battle_type") == "wuzhuangyuan_exam")
    lightness_cap3_battle_ids = collect_battle_ids(
        battle_rows,
        lambda row: as_bool(row.get("can_trigger_lightness_breakthrough", ""))
        and row.get("lightness_cap_unlock") in {"cap_3"},
    )
    lightness_cap4_battle_ids = collect_battle_ids(
        battle_rows, lambda row: row.get("lightness_cap_unlock") == "cap_4" or row.get("lightness_reward_type") == "rare_breakthrough"
    )

    true_operation_ids = collect_operation_ids(
        operation_rows,
        lambda row: as_bool(row.get("can_support_true_ending", ""))
        or "true_route_candidate" in split_tokens(row.get("route_gate_tags", "")),
    )
    wz_operation_ids = collect_operation_ids(
        operation_rows,
        lambda row: as_bool(row.get("can_trigger_wuzhuangyuan_route", ""))
        or "wuzhuangyuan_candidate" in split_tokens(row.get("route_gate_tags", "")),
    )
    lightness_operation_ids = collect_operation_ids(
        operation_rows,
        lambda row: as_bool(row.get("can_trigger_lightness_breakthrough", "")) or row.get("lightness_cap_unlock") in {"cap_3", "cap_4"},
    )
    boss_prepare_operation_ids = collect_operation_ids(operation_rows, lambda row: as_bool(row.get("can_prepare_boss", "")))

    true_narrative_ids = collect_narrative_ids(
        narrative_rows,
        lambda row: row.get("route_affinity") == "true_route"
        or "old_case_progress" in split_tokens(row.get("route_gate_tags", ""))
        or "true_route_candidate" in split_tokens(row.get("route_gate_tags", "")),
    )
    wz_narrative_ids = collect_narrative_ids(
        narrative_rows,
        lambda row: row.get("route_affinity") == "wuzhuangyuan"
        or "wuzhuangyuan_candidate" in split_tokens(row.get("route_gate_tags", ""))
        or "wuzhuangyuan_offer" in split_tokens(row.get("hook_tags", "")),
    )
    lightness_narrative_ids = collect_narrative_ids(
        narrative_rows,
        lambda row: "lightness_cap_3" in split_tokens(row.get("route_gate_tags", ""))
        or "lightness_cap_4" in split_tokens(row.get("route_gate_tags", ""))
        or "lightness_3" in split_tokens(row.get("optional_flags", ""))
        or "lightness_4" in split_tokens(row.get("optional_flags", "")),
    )
    boss_prepare_narrative_ids = collect_narrative_ids(
        narrative_rows,
        lambda row: row.get("node_kind") == "boss_prepare" or "boss_prepare" in split_tokens(row.get("hook_tags", "")),
    )

    true_tags = collect_narrative_tags(
        narrative_rows,
        lambda row: row.get("route_affinity") == "true_route" or row.get("route_type") == "true_route",
    )
    wz_tags = collect_narrative_tags(
        narrative_rows, lambda row: row.get("route_affinity") == "wuzhuangyuan" or row.get("route_type") == "wuzhuangyuan"
    )
    lightness_tags = collect_narrative_tags(
        narrative_rows, lambda row: "lightness" in ",".join(split_tokens(row.get("route_gate_tags", "")))
    )
    boss_prepare_tags = collect_narrative_tags(
        narrative_rows, lambda row: row.get("node_kind") == "boss_prepare" or "boss_prepare" in split_tokens(row.get("hook_tags", ""))
    )

    gates: list[RouteGate] = []
    gates.append(gate_normal_ending_default())
    gates.append(
        RouteGate(
            route_gate_id="gate_normal_boss_access",
            route_id="normal_ending",
            route_type="normal",
            ending_route="normal",
            gate_stage="boss_prepare",
            gate_kind="boss_access",
            priority=80,
            required_flags=[],
            optional_flags=["stable_loadout"],
            blocked_by_flags=[],
            required_martial_realm_min="8",
            required_military_merit_level="none",
            required_clean_reputation_level="none",
            required_old_case_progress_level="none",
            required_lightness_level="0",
            required_elite_battle_count="",
            required_boss_clear="",
            source_battle_reward_ids=normal_boss_ids,
            source_operation_node_ids=boss_prepare_operation_ids,
            source_narrative_node_ids=collect_narrative_ids(
                narrative_rows, lambda row: row.get("route_affinity") in {"normal", "common"} and row.get("node_kind") == "boss_prepare"
            ),
            source_route_gate_tags=[],
            unlock_result="enter_normal_boss",
            fallback_route="normal_ending",
            is_hard_gate=False,
            is_player_choice=False,
            risk_level="medium",
            notes="Normal boss access supports realm 8-9 progression without high-route hard requirements.",
        )
    )
    gates.append(
        RouteGate(
            route_gate_id="gate_true_route_unlock",
            route_id="true_ending",
            route_type="true_route",
            ending_route="true_route",
            gate_stage="big_map_late",
            gate_kind="unlock",
            priority=20,
            required_flags=["old_case_progress_high", "true_route_candidate"],
            optional_flags=["key_evidence_enough", "clean_reputation_high", "realm_9_or_10"],
            blocked_by_flags=["true_route_failed", "old_case_failed"],
            required_martial_realm_min="9",
            required_military_merit_level="medium",
            required_clean_reputation_level="none",
            required_old_case_progress_level="high",
            required_lightness_level="",
            required_elite_battle_count="",
            required_boss_clear="",
            source_battle_reward_ids=true_battle_ids,
            source_operation_node_ids=true_operation_ids,
            source_narrative_node_ids=true_narrative_ids,
            source_route_gate_tags=unique_sorted(true_tags + ["old_case_progress", "true_route_candidate"]),
            unlock_result="enter_true_route",
            fallback_route="normal_ending",
            is_hard_gate=True,
            is_player_choice=False,
            risk_level="route",
            notes="True ending unlock is old-case route driven and should not be replaced by institution route.",
        )
    )
    gates.append(
        RouteGate(
            route_gate_id="gate_true_boss_unlock",
            route_id="true_boss",
            route_type="true_route",
            ending_route="true_route",
            gate_stage="after_true_boss_1",
            gate_kind="boss_access",
            priority=21,
            required_flags=["old_case_progress_high", "true_route_candidate", "martial_realm_10"],
            optional_flags=["key_evidence_enough", "clean_reputation_high"],
            blocked_by_flags=["true_route_failed"],
            required_martial_realm_min="10",
            required_military_merit_level="medium",
            required_clean_reputation_level="none",
            required_old_case_progress_level="high",
            required_lightness_level="",
            required_elite_battle_count="",
            required_boss_clear="true_boss_01",
            source_battle_reward_ids=true_boss_ids,
            source_operation_node_ids=true_operation_ids,
            source_narrative_node_ids=collect_narrative_ids(
                narrative_rows, lambda row: row.get("route_affinity") == "true_route" and row.get("node_kind") in {"ending_hint", "battle_hook"}
            ),
            source_route_gate_tags=unique_sorted(true_tags + ["old_case_progress", "true_route_candidate", "realm_10_candidate"]),
            unlock_result="enter_true_boss",
            fallback_route="normal_boss",
            is_hard_gate=True,
            is_player_choice=False,
            risk_level="boss",
            notes="True boss access follows realm-10 tuning and does not require lightness cap 4.",
        )
    )
    gates.append(
        RouteGate(
            route_gate_id="gate_wuzhuangyuan_candidate",
            route_id="wuzhuangyuan",
            route_type="wuzhuangyuan",
            ending_route="none",
            gate_stage="wuzhuangyuan_prepare",
            gate_kind="special_route",
            priority=30,
            required_flags=["martial_realm_10", "high_military_merit"],
            optional_flags=["elite_battle_count_4", "weapon_mastery_high", "lightness_3"],
            blocked_by_flags=["wuzhuangyuan_declined", "low_military_merit"],
            required_martial_realm_min="10",
            required_military_merit_level="high",
            required_clean_reputation_level="none",
            required_old_case_progress_level="low",
            required_lightness_level="",
            required_elite_battle_count="4",
            required_boss_clear="",
            source_battle_reward_ids=wz_candidate_battle_ids,
            source_operation_node_ids=wz_operation_ids,
            source_narrative_node_ids=wz_narrative_ids,
            source_route_gate_tags=unique_sorted(wz_tags + ["high_military_merit", "wuzhuangyuan_candidate"]),
            unlock_result="enter_wuzhuangyuan_exam",
            fallback_route="normal_ending",
            is_hard_gate=True,
            is_player_choice=False,
            risk_level="route",
            notes="Institution route candidate gate; does not require old-case high progression and not a true-ending replacement.",
        )
    )
    gates.append(
        RouteGate(
            route_gate_id="gate_wuzhuangyuan_exam_unlock",
            route_id="wuzhuangyuan",
            route_type="wuzhuangyuan",
            ending_route="wuzhuangyuan",
            gate_stage="wuzhuangyuan_prepare",
            gate_kind="player_choice",
            priority=31,
            required_flags=["martial_realm_10", "high_military_merit"],
            optional_flags=["elite_battle_count_4", "lightness_3", "clean_reputation_high"],
            blocked_by_flags=["wuzhuangyuan_declined"],
            required_martial_realm_min="10",
            required_military_merit_level="high",
            required_clean_reputation_level="none",
            required_old_case_progress_level="low",
            required_lightness_level="",
            required_elite_battle_count="4",
            required_boss_clear="",
            source_battle_reward_ids=wz_exam_battle_ids,
            source_operation_node_ids=wz_operation_ids,
            source_narrative_node_ids=collect_narrative_ids(
                narrative_rows,
                lambda row: row.get("route_affinity") in {"wuzhuangyuan", "mixed"}
                and row.get("node_kind") in {"route_offer", "ending_hint", "battle_hook"},
            ),
            source_route_gate_tags=unique_sorted(wz_tags + ["wuzhuangyuan_candidate"]),
            unlock_result="enter_wuzhuangyuan_exam",
            fallback_route="normal_ending",
            is_hard_gate=False,
            is_player_choice=True,
            risk_level="route",
            notes="Player-choice resolver when both true-route and wuzhuangyuan conditions are available.",
        )
    )
    gates.append(
        RouteGate(
            route_gate_id="gate_lightness_cap_3",
            route_id="lightness_breakthrough",
            route_type="optional",
            ending_route="none",
            gate_stage="big_map_late",
            gate_kind="rare_breakthrough",
            priority=60,
            required_flags=[],
            optional_flags=["rare_lightness_encounter", "master_hidden_teaching", "old_case_secret_pursuit"],
            blocked_by_flags=[],
            required_martial_realm_min="",
            required_military_merit_level="none",
            required_clean_reputation_level="none",
            required_old_case_progress_level="none",
            required_lightness_level="2",
            required_elite_battle_count="",
            required_boss_clear="",
            source_battle_reward_ids=lightness_cap3_battle_ids,
            source_operation_node_ids=lightness_operation_ids,
            source_narrative_node_ids=lightness_narrative_ids,
            source_route_gate_tags=unique_sorted(lightness_tags + ["lightness_cap_3"]),
            unlock_result="unlock_lightness_cap_3",
            fallback_route="none",
            is_hard_gate=False,
            is_player_choice=False,
            risk_level="rare",
            notes="Rare lightness breakthrough gate for cap 3; not a route hard gate.",
        )
    )
    gates.append(
        RouteGate(
            route_gate_id="gate_lightness_cap_4",
            route_id="lightness_breakthrough",
            route_type="optional",
            ending_route="none",
            gate_stage="ending",
            gate_kind="rare_breakthrough",
            priority=61,
            required_flags=[],
            optional_flags=[
                "rare_lightness_encounter_chain",
                "master_final_teaching",
                "wuzhuangyuan_final_trial_bonus",
                "true_route_hidden_pursuit_success",
            ],
            blocked_by_flags=[],
            required_martial_realm_min="",
            required_military_merit_level="none",
            required_clean_reputation_level="none",
            required_old_case_progress_level="none",
            required_lightness_level="3",
            required_elite_battle_count="",
            required_boss_clear="",
            source_battle_reward_ids=lightness_cap4_battle_ids,
            source_operation_node_ids=lightness_operation_ids,
            source_narrative_node_ids=collect_narrative_ids(
                narrative_rows,
                lambda row: "lightness_cap_4" in split_tokens(row.get("route_gate_tags", ""))
                or "lightness_4" in split_tokens(row.get("optional_flags", "")),
            ),
            source_route_gate_tags=unique_sorted(lightness_tags + ["lightness_cap_4"]),
            unlock_result="unlock_lightness_cap_4",
            fallback_route="none",
            is_hard_gate=False,
            is_player_choice=False,
            risk_level="rare",
            notes="Cap 4 is optional rare progression and cannot be a hard requirement for ending routes.",
        )
    )
    gates.append(
        RouteGate(
            route_gate_id="gate_boss_prepare_required",
            route_id="boss_prepare",
            route_type="support",
            ending_route="none",
            gate_stage="boss_prepare",
            gate_kind="preparation",
            priority=55,
            required_flags=[],
            optional_flags=["stable_loadout", "healing_stock_ok"],
            blocked_by_flags=[],
            required_martial_realm_min="",
            required_military_merit_level="none",
            required_clean_reputation_level="none",
            required_old_case_progress_level="none",
            required_lightness_level="",
            required_elite_battle_count="",
            required_boss_clear="",
            source_battle_reward_ids=normal_boss_ids + true_boss_ids,
            source_operation_node_ids=boss_prepare_operation_ids,
            source_narrative_node_ids=boss_prepare_narrative_ids,
            source_route_gate_tags=unique_sorted(boss_prepare_tags + ["boss_prepare"]),
            unlock_result="enable_boss_prepare",
            fallback_route="normal_boss",
            is_hard_gate=False,
            is_player_choice=False,
            risk_level="medium",
            notes="Preparation support gate sourced from can_prepare_boss operation nodes.",
        )
    )
    return gates


def main() -> int:
    args = parse_args()
    design_dir = Path(args.design_dir)
    out_path = Path(args.out)
    must_exist(design_dir)

    battle_rows = read_tsv(design_dir / "generated_battle_reward_plan.tsv")
    operation_rows = read_tsv(design_dir / "generated_operation_node_plan.tsv")
    narrative_rows = read_tsv(design_dir / "generated_narrative_node_plan.tsv")
    _ = read_tsv(design_dir / "generated_route_progression_curve.tsv")
    _ = read_tsv(design_dir / "progression_numeric_config_v1_3.tsv")

    gates = build_gates(battle_rows, operation_rows, narrative_rows)
    write_tsv(out_path, [gate.to_row() for gate in gates])
    print(f"WROTE: {out_path}")
    print(f"ROUTE_GATES: {len(gates)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
