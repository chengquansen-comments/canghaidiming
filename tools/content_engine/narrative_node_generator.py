#!/usr/bin/env python3
"""Generate Content Engine v0.5c narrative node skeleton plan (design-layer only)."""

from __future__ import annotations

import argparse
import csv
import re
from dataclasses import dataclass
from pathlib import Path


OUTPUT_FIELDS = [
    "narrative_node_id",
    "source_type",
    "source_id",
    "scope",
    "route_type",
    "stage",
    "trigger_stage",
    "node_kind",
    "narrative_role",
    "route_affinity",
    "risk_level",
    "hook_tags",
    "route_gate_tags",
    "old_case_tags",
    "military_merit_tags",
    "clean_reputation_tags",
    "lightness_tags",
    "wuzhuangyuan_tags",
    "expected_player_realm",
    "expected_lightness_level",
    "required_flags",
    "optional_flags",
    "blocked_by_flags",
    "preview_key",
    "result_key",
    "choice_count",
    "choice_profile",
    "effect_profile",
    "should_write_body",
    "body_style",
    "line_budget",
    "source_operation_node_id",
    "source_reward_plan_id",
    "notes",
]

INPUT_FILES = [
    "generated_operation_node_plan.tsv",
    "generated_battle_reward_plan.tsv",
    "generated_route_progression_curve.tsv",
    "generated_battle_slot_plan.tsv",
]


@dataclass(frozen=True)
class NarrativeNode:
    narrative_node_id: str
    source_type: str
    source_id: str
    scope: str
    route_type: str
    stage: str
    trigger_stage: str
    node_kind: str
    narrative_role: str
    route_affinity: str
    risk_level: str
    hook_tags: list[str]
    route_gate_tags: list[str]
    old_case_tags: list[str]
    military_merit_tags: list[str]
    clean_reputation_tags: list[str]
    lightness_tags: list[str]
    wuzhuangyuan_tags: list[str]
    expected_player_realm: str
    expected_lightness_level: str
    required_flags: list[str]
    optional_flags: list[str]
    blocked_by_flags: list[str]
    preview_key: str
    result_key: str
    choice_count: int
    choice_profile: str
    effect_profile: str
    should_write_body: bool
    body_style: str
    line_budget: int
    source_operation_node_id: str
    source_reward_plan_id: str
    notes: str

    def to_row(self) -> dict[str, str]:
        return {
            "narrative_node_id": self.narrative_node_id,
            "source_type": self.source_type,
            "source_id": self.source_id,
            "scope": self.scope,
            "route_type": self.route_type,
            "stage": self.stage,
            "trigger_stage": self.trigger_stage,
            "node_kind": self.node_kind,
            "narrative_role": self.narrative_role,
            "route_affinity": self.route_affinity,
            "risk_level": self.risk_level,
            "hook_tags": join_tags(self.hook_tags),
            "route_gate_tags": join_tags(self.route_gate_tags),
            "old_case_tags": join_tags(self.old_case_tags),
            "military_merit_tags": join_tags(self.military_merit_tags),
            "clean_reputation_tags": join_tags(self.clean_reputation_tags),
            "lightness_tags": join_tags(self.lightness_tags),
            "wuzhuangyuan_tags": join_tags(self.wuzhuangyuan_tags),
            "expected_player_realm": self.expected_player_realm,
            "expected_lightness_level": self.expected_lightness_level,
            "required_flags": join_tags(self.required_flags),
            "optional_flags": join_tags(self.optional_flags),
            "blocked_by_flags": join_tags(self.blocked_by_flags),
            "preview_key": self.preview_key,
            "result_key": self.result_key,
            "choice_count": str(self.choice_count),
            "choice_profile": self.choice_profile,
            "effect_profile": self.effect_profile,
            "should_write_body": "true" if self.should_write_body else "false",
            "body_style": self.body_style,
            "line_budget": str(self.line_budget),
            "source_operation_node_id": self.source_operation_node_id,
            "source_reward_plan_id": self.source_reward_plan_id,
            "notes": self.notes,
        }


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Generate deterministic narrative node skeletons for Content Engine v0.5c.")
    parser.add_argument("--design-dir", default="data/design")
    parser.add_argument("--out", default="data/design/generated_narrative_node_plan.tsv")
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


def as_int(value: str, default: int = 0) -> int:
    try:
        return int(round(float((value or "").strip())))
    except ValueError:
        return default


def split_tags(value: str) -> list[str]:
    out: list[str] = []
    for part in (value or "").split(","):
        token = part.strip()
        if not token or token.lower() == "none":
            continue
        out.append(token)
    return out


def merge_tags(*groups: list[str]) -> list[str]:
    merged: list[str] = []
    seen: set[str] = set()
    for group in groups:
        for token in group:
            if not token or token in seen:
                continue
            seen.add(token)
            merged.append(token)
    return merged


def join_tags(tags: list[str]) -> str:
    return ",".join(tags) if tags else "none"


def route_affinity_from_route_type(route_type: str) -> str:
    mapping = {
        "common": "common",
        "normal": "normal",
        "true_route": "true_route",
        "wuzhuangyuan": "wuzhuangyuan",
        "optional": "optional",
    }
    return mapping.get(route_type, "mixed")


def max_realm_from_text(text: str) -> int:
    digits = [int(item) for item in re.findall(r"\d+", text or "")]
    return max(digits) if digits else 0


def classify_tag_slices(hook_tags: list[str], route_gate_tags: list[str], row: dict[str, str]) -> dict[str, list[str]]:
    tag_union = merge_tags(hook_tags, route_gate_tags)
    old_case_tags = [tag for tag in tag_union if "old_case" in tag or "true_route" in tag or "evidence" in tag]
    military_tags = [tag for tag in tag_union if "military" in tag or "merit" in tag]
    clean_tags = [tag for tag in tag_union if "clean" in tag or "reputation" in tag]
    lightness_tags = [tag for tag in tag_union if "lightness" in tag]
    wuzhuangyuan_tags = [tag for tag in tag_union if "wuzhuangyuan" in tag]

    if as_int(row.get("clean_reputation_reward", "0"), 0) != 0:
        clean_tags = merge_tags(clean_tags, ["clean_reputation_shift"])
    cap_unlock = row.get("lightness_cap_unlock", "")
    if cap_unlock in {"cap_3", "cap_4"}:
        lightness_tags = merge_tags(lightness_tags, [cap_unlock])
    if row.get("route_type", "") == "wuzhuangyuan":
        wuzhuangyuan_tags = merge_tags(wuzhuangyuan_tags, ["wuzhuangyuan_offer"])
    return {
        "old_case_tags": old_case_tags,
        "military_merit_tags": military_tags,
        "clean_reputation_tags": clean_tags,
        "lightness_tags": lightness_tags,
        "wuzhuangyuan_tags": wuzhuangyuan_tags,
    }


def operation_node_kind(row: dict[str, str]) -> str:
    node_type = row.get("node_type", "")
    if node_type == "old_case":
        return "old_case_clue"
    if node_type == "military_gate" and "wuzhuangyuan" in row.get("route_type", ""):
        return "route_offer"
    if node_type == "military_gate":
        return "military_gate"
    if node_type == "lightness_encounter":
        return "lightness_encounter"
    if node_type == "boss_prepare":
        return "boss_prepare"
    return "operation_hook"


def operation_narrative_role(row: dict[str, str], node_kind: str) -> str:
    if node_kind == "old_case_clue":
        return "clue"
    if node_kind == "military_gate":
        return "pressure"
    if node_kind == "route_offer":
        return "route_unlock"
    if node_kind == "lightness_encounter":
        return "choice"
    if node_kind == "boss_prepare":
        return "preparation"
    return "setup"


def operation_flags(row: dict[str, str], route_affinity: str, node_kind: str) -> tuple[list[str], list[str], list[str]]:
    required: list[str] = []
    optional: list[str] = []
    blocked: list[str] = []
    route_tags = split_tags(row.get("route_gate_tags", ""))
    hook_tags = split_tags(row.get("narrative_hook_tags", ""))

    if route_affinity == "wuzhuangyuan" or "wuzhuangyuan_offer" in hook_tags:
        required = merge_tags(required, ["martial_realm_10", "high_military_merit"])
        blocked = merge_tags(blocked, ["low_military_merit"])
    if route_affinity == "true_route" or node_kind == "old_case_clue":
        required = merge_tags(required, ["old_case_progress", "true_route_candidate"])
        blocked = merge_tags(blocked, ["old_case_failed"])
    if max_realm_from_text(row.get("expected_player_realm", "")) >= 9 and route_affinity in {"true_route", "wuzhuangyuan"}:
        optional = merge_tags(optional, ["realm_9_or_10"])
    if "high_military_merit" in route_tags and "high_military_merit" not in required:
        optional = merge_tags(optional, ["high_military_merit"])
    if row.get("lightness_cap_unlock", "") == "cap_3":
        optional = merge_tags(optional, ["lightness_3"])
    if as_int(row.get("clean_reputation_reward", "0"), 0) > 0:
        optional = merge_tags(optional, ["clean_reputation_high"])
    return required, optional, blocked


def build_operation_nodes(rows: list[dict[str, str]]) -> list[NarrativeNode]:
    out: list[NarrativeNode] = []
    for row in rows:
        operation_id = row.get("operation_node_id", "")
        node_kind = operation_node_kind(row)
        route_affinity = route_affinity_from_route_type(row.get("route_type", ""))
        hook_tags = split_tags(row.get("narrative_hook_tags", ""))
        if node_kind == "boss_prepare":
            hook_tags = merge_tags(hook_tags, ["boss_prepare"])
        if node_kind == "route_offer":
            hook_tags = merge_tags(hook_tags, ["wuzhuangyuan_offer"])
        route_gate_tags = split_tags(row.get("route_gate_tags", ""))
        if node_kind == "old_case_clue":
            route_gate_tags = merge_tags(route_gate_tags, ["old_case_progress", "true_route_candidate"])
        slices = classify_tag_slices(hook_tags, route_gate_tags, row)
        required_flags, optional_flags, blocked_flags = operation_flags(row, route_affinity, node_kind)
        choice_count = 2 if node_kind in {"lightness_encounter", "route_offer"} else 1
        effect_profile = {
            "old_case_clue": "clue_progress_mark",
            "military_gate": "merit_gate_mark",
            "route_offer": "route_offer_mark",
            "lightness_encounter": "lightness_route_mark",
            "boss_prepare": "boss_preparation_mark",
        }.get(node_kind, "operation_context_mark")
        out.append(
            NarrativeNode(
                narrative_node_id=f"nar_op_{operation_id}",
                source_type="operation_node",
                source_id=operation_id,
                scope=row.get("scope", "big_map"),
                route_type=row.get("route_type", "common"),
                stage=row.get("stage", "big_map"),
                trigger_stage=row.get("stage", "big_map"),
                node_kind=node_kind,
                narrative_role=operation_narrative_role(row, node_kind),
                route_affinity=route_affinity,
                risk_level=row.get("risk_level", "low"),
                hook_tags=hook_tags,
                route_gate_tags=route_gate_tags,
                old_case_tags=slices["old_case_tags"],
                military_merit_tags=slices["military_merit_tags"],
                clean_reputation_tags=slices["clean_reputation_tags"],
                lightness_tags=slices["lightness_tags"],
                wuzhuangyuan_tags=slices["wuzhuangyuan_tags"],
                expected_player_realm=row.get("expected_player_realm", ""),
                expected_lightness_level=row.get("expected_lightness_level", ""),
                required_flags=required_flags,
                optional_flags=optional_flags,
                blocked_by_flags=blocked_flags,
                preview_key=f"preview.operation.{operation_id}",
                result_key=f"result.operation.{operation_id}",
                choice_count=choice_count,
                choice_profile="short_branch" if choice_count > 1 else "single_continue",
                effect_profile=effect_profile,
                should_write_body=False,
                body_style="none",
                line_budget=0,
                source_operation_node_id=operation_id,
                source_reward_plan_id="",
                notes=f"v0.5c operation skeleton from {operation_id}.",
            )
        )
    return out


def should_include_battle_reward(row: dict[str, str]) -> bool:
    battle_type = row.get("battle_type", "")
    return (
        as_int(row.get("old_case_progress_reward", "0"), 0) > 0
        or as_int(row.get("military_merit_reward", "0"), 0) >= 3
        or as_bool(row.get("can_trigger_realm_10", "false"))
        or as_bool(row.get("can_trigger_lightness_breakthrough", "false"))
        or as_bool(row.get("can_trigger_wuzhuangyuan_route", "false"))
        or battle_type in {"boss", "true_boss", "wuzhuangyuan_exam"}
    )


def battle_node_kind(row: dict[str, str]) -> str:
    battle_type = row.get("battle_type", "")
    reward_profile = row.get("reward_profile", "")
    if battle_type == "wuzhuangyuan_exam" and reward_profile == "wuzhuangyuan_final":
        return "route_offer"
    if battle_type in {"boss", "true_boss"} and row.get("route_type", "") == "true_route":
        return "ending_hint"
    if battle_type == "wuzhuangyuan_exam":
        return "battle_hook"
    if as_int(row.get("old_case_progress_reward", "0"), 0) > 0:
        return "old_case_clue"
    return "battle_hook"


def battle_narrative_role(row: dict[str, str], node_kind: str) -> str:
    battle_type = row.get("battle_type", "")
    if node_kind == "old_case_clue":
        return "clue"
    if node_kind == "route_offer":
        return "route_unlock"
    if node_kind == "ending_hint":
        return "ending_bridge"
    if battle_type in {"boss", "true_boss"}:
        return "consequence"
    if as_bool(row.get("can_trigger_realm_10", "false")) or as_bool(row.get("can_trigger_lightness_breakthrough", "false")):
        return "choice"
    return "pressure"


def battle_route_affinity(row: dict[str, str]) -> str:
    route_type = row.get("route_type", "")
    if route_type in {"normal", "true_route", "wuzhuangyuan"}:
        return route_type
    if as_bool(row.get("can_trigger_wuzhuangyuan_route", "false")) and as_bool(row.get("can_trigger_realm_10", "false")):
        return "mixed"
    return "common"


def battle_hook_tags(row: dict[str, str], node_kind: str) -> list[str]:
    tags: list[str] = []
    battle_type = row.get("battle_type", "")
    if as_int(row.get("old_case_progress_reward", "0"), 0) > 0:
        tags.append("old_case")
    if as_int(row.get("military_merit_reward", "0"), 0) >= 3:
        tags.append("military_gate")
    if as_bool(row.get("can_trigger_lightness_breakthrough", "false")):
        tags.append("lightness_encounter")
    if as_bool(row.get("can_trigger_wuzhuangyuan_route", "false")):
        tags.append("wuzhuangyuan_offer")
    if battle_type == "elite":
        tags.append("elite_pressure")
    if battle_type in {"boss", "true_boss"}:
        tags.append("boss_prepare")
    if row.get("route_type", "") == "true_route" or battle_type == "true_boss":
        tags.append("true_boss_hint")
    if battle_type == "wuzhuangyuan_exam":
        tags.append("wuzhuangyuan_offer")
    if node_kind == "route_offer":
        tags.append("route_offer")
    return merge_tags(tags)


def battle_route_gate_tags(row: dict[str, str]) -> list[str]:
    tags: list[str] = []
    if as_int(row.get("old_case_progress_reward", "0"), 0) > 0:
        tags.append("old_case_progress")
    if as_int(row.get("military_merit_reward", "0"), 0) >= 3:
        tags.append("high_military_merit")
    if as_bool(row.get("can_trigger_realm_10", "false")):
        tags.append("realm_10_candidate")
    if as_bool(row.get("can_trigger_wuzhuangyuan_route", "false")):
        tags.append("wuzhuangyuan_candidate")
    if row.get("route_type", "") == "true_route":
        tags.append("true_route_candidate")
    if row.get("lightness_cap_unlock", "") == "cap_3":
        tags.append("lightness_cap_3")
    if row.get("lightness_cap_unlock", "") == "cap_4":
        tags.append("lightness_cap_4")
    if as_bool(row.get("can_trigger_lightness_breakthrough", "false")) and "lightness_cap_3" not in tags:
        tags.append("lightness_cap_3")
    return merge_tags(tags)


def battle_flags(row: dict[str, str], route_affinity: str, route_gate_tags: list[str]) -> tuple[list[str], list[str], list[str]]:
    required: list[str] = []
    optional: list[str] = []
    blocked: list[str] = []
    if route_affinity == "wuzhuangyuan" or as_bool(row.get("can_trigger_wuzhuangyuan_route", "false")):
        required = merge_tags(required, ["martial_realm_10", "high_military_merit"])
        blocked = merge_tags(blocked, ["low_military_merit"])
    if route_affinity == "true_route":
        required = merge_tags(required, ["old_case_progress", "true_route_candidate"])
        optional = merge_tags(optional, ["realm_9_or_10"])
        blocked = merge_tags(blocked, ["old_case_failed"])
    if "realm_10_candidate" in route_gate_tags:
        optional = merge_tags(optional, ["realm_10_candidate"])
    if as_int(row.get("clean_reputation_reward", "0"), 0) > 0:
        optional = merge_tags(optional, ["clean_reputation_high"])
    if row.get("lightness_cap_unlock", "") == "cap_3":
        optional = merge_tags(optional, ["lightness_3"])
    if row.get("lightness_cap_unlock", "") == "cap_4":
        optional = merge_tags(optional, ["lightness_4"])
    if as_int(row.get("old_case_progress_reward", "0"), 0) >= 2:
        optional = merge_tags(optional, ["key_evidence"])
    return required, optional, blocked


def build_battle_nodes(rows: list[dict[str, str]], slot_stage_by_id: dict[str, str]) -> list[NarrativeNode]:
    out: list[NarrativeNode] = []
    for row in rows:
        if not should_include_battle_reward(row):
            continue
        reward_id = row.get("reward_plan_id", "")
        stage = slot_stage_by_id.get(row.get("battle_slot_id", ""), "big_map")
        node_kind = battle_node_kind(row)
        route_affinity = battle_route_affinity(row)
        hook_tags = battle_hook_tags(row, node_kind)
        route_gate_tags = battle_route_gate_tags(row)
        slices = classify_tag_slices(hook_tags, route_gate_tags, row)
        required_flags, optional_flags, blocked_flags = battle_flags(row, route_affinity, route_gate_tags)
        effect_profile = {
            "old_case_clue": "clue_progress_mark",
            "route_offer": "route_offer_mark",
            "ending_hint": "ending_bridge_mark",
            "battle_hook": "battle_outcome_mark",
        }.get(node_kind, "battle_outcome_mark")
        choice_count = 2 if node_kind in {"route_offer", "ending_hint"} else 1
        out.append(
            NarrativeNode(
                narrative_node_id=f"nar_battle_{reward_id}",
                source_type="battle_reward",
                source_id=reward_id,
                scope=row.get("scope", "big_map"),
                route_type=row.get("route_type", "common"),
                stage=stage,
                trigger_stage=stage,
                node_kind=node_kind,
                narrative_role=battle_narrative_role(row, node_kind),
                route_affinity=route_affinity,
                risk_level=row.get("risk_level", "medium"),
                hook_tags=hook_tags,
                route_gate_tags=route_gate_tags,
                old_case_tags=slices["old_case_tags"],
                military_merit_tags=slices["military_merit_tags"],
                clean_reputation_tags=slices["clean_reputation_tags"],
                lightness_tags=slices["lightness_tags"],
                wuzhuangyuan_tags=slices["wuzhuangyuan_tags"],
                expected_player_realm=row.get("expected_player_realm", ""),
                expected_lightness_level=row.get("expected_lightness_level", ""),
                required_flags=required_flags,
                optional_flags=optional_flags,
                blocked_by_flags=blocked_flags,
                preview_key=f"preview.battle.{reward_id}",
                result_key=f"result.battle.{reward_id}",
                choice_count=choice_count,
                choice_profile="short_choice" if choice_count > 1 else "single_continue",
                effect_profile=effect_profile,
                should_write_body=False,
                body_style="none",
                line_budget=0,
                source_operation_node_id="",
                source_reward_plan_id=reward_id,
                notes=f"v0.5c battle skeleton from {reward_id}.",
            )
        )
    return out


def checkpoint_row(rows: list[dict[str, str]], route: str, checkpoint: str) -> dict[str, str]:
    for row in rows:
        if row.get("route") == route and row.get("checkpoint") == checkpoint:
            return row
    return {}


def build_route_hint_nodes(route_rows: list[dict[str, str]]) -> list[NarrativeNode]:
    true_row = checkpoint_row(route_rows, "true_route", "true_after_boss_1")
    wz_row = checkpoint_row(route_rows, "wuzhuangyuan", "wuzhuangyuan_before_exam")
    normal_row = checkpoint_row(route_rows, "normal", "normal_after_boss")
    boss_row = checkpoint_row(route_rows, "elite", "elite_after_big_map")
    return [
        NarrativeNode(
            narrative_node_id="nar_route_true_hint_01",
            source_type="route_hint",
            source_id="true_route_hint_01",
            scope="route_curve",
            route_type="true_route",
            stage="big_map_late",
            trigger_stage="true_after_boss_1",
            node_kind="ending_hint",
            narrative_role="foreshadow",
            route_affinity="true_route",
            risk_level="route",
            hook_tags=["old_case", "true_boss_hint"],
            route_gate_tags=["old_case_progress", "true_route_candidate"],
            old_case_tags=["old_case", "old_case_progress"],
            military_merit_tags=[],
            clean_reputation_tags=[],
            lightness_tags=[],
            wuzhuangyuan_tags=[],
            expected_player_realm=true_row.get("expected_realm_default", "10"),
            expected_lightness_level=true_row.get("expected_lightness_default", "2"),
            required_flags=["old_case_progress", "key_evidence", "true_route_candidate"],
            optional_flags=["realm_9_or_10"],
            blocked_by_flags=["old_case_failed"],
            preview_key="preview.route.true_route_hint_01",
            result_key="result.route.true_route_hint_01",
            choice_count=1,
            choice_profile="single_continue",
            effect_profile="route_hint_mark",
            should_write_body=False,
            body_style="none",
            line_budget=0,
            source_operation_node_id="",
            source_reward_plan_id="",
            notes="True route foreshadow skeleton; no full text in v0.5c.",
        ),
        NarrativeNode(
            narrative_node_id="nar_route_wuzhuangyuan_hint_01",
            source_type="wuzhuangyuan_offer",
            source_id="wuzhuangyuan_offer_hint_01",
            scope="route_curve",
            route_type="wuzhuangyuan",
            stage="big_map_late",
            trigger_stage="wuzhuangyuan_before_exam",
            node_kind="route_offer",
            narrative_role="route_unlock",
            route_affinity="wuzhuangyuan",
            risk_level="route",
            hook_tags=["wuzhuangyuan_offer", "military_gate"],
            route_gate_tags=["high_military_merit", "realm_10_candidate", "wuzhuangyuan_candidate"],
            old_case_tags=[],
            military_merit_tags=["high_military_merit"],
            clean_reputation_tags=[],
            lightness_tags=[],
            wuzhuangyuan_tags=["wuzhuangyuan_offer", "wuzhuangyuan_candidate"],
            expected_player_realm=wz_row.get("expected_realm_default", "10"),
            expected_lightness_level=wz_row.get("expected_lightness_default", "3"),
            required_flags=["martial_realm_10", "high_military_merit"],
            optional_flags=["clean_reputation_high"],
            blocked_by_flags=["low_military_merit"],
            preview_key="preview.route.wuzhuangyuan_offer_hint_01",
            result_key="result.route.wuzhuangyuan_offer_hint_01",
            choice_count=2,
            choice_profile="short_choice",
            effect_profile="route_offer_mark",
            should_write_body=False,
            body_style="none",
            line_budget=0,
            source_operation_node_id="op_wuzhuangyuan_offer_01",
            source_reward_plan_id="",
            notes="Wuzhuangyuan offer skeleton; keeps institution-route framing.",
        ),
        NarrativeNode(
            narrative_node_id="nar_route_normal_ending_hint_01",
            source_type="route_hint",
            source_id="normal_ending_hint_01",
            scope="route_curve",
            route_type="normal",
            stage="boss_prepare",
            trigger_stage="normal_after_boss",
            node_kind="ending_hint",
            narrative_role="ending_bridge",
            route_affinity="normal",
            risk_level="route",
            hook_tags=["boss_prepare"],
            route_gate_tags=[],
            old_case_tags=[],
            military_merit_tags=[],
            clean_reputation_tags=[],
            lightness_tags=[],
            wuzhuangyuan_tags=[],
            expected_player_realm=normal_row.get("expected_realm_default", "9"),
            expected_lightness_level=normal_row.get("expected_lightness_default", "2"),
            required_flags=[],
            optional_flags=["clean_reputation_high"],
            blocked_by_flags=[],
            preview_key="preview.route.normal_ending_hint_01",
            result_key="result.route.normal_ending_hint_01",
            choice_count=1,
            choice_profile="single_continue",
            effect_profile="ending_bridge_mark",
            should_write_body=False,
            body_style="none",
            line_budget=0,
            source_operation_node_id="op_boss_prepare_01",
            source_reward_plan_id="",
            notes="Normal ending bridge skeleton; allows partial closure.",
        ),
        NarrativeNode(
            narrative_node_id="nar_boss_prepare_01",
            source_type="boss_prepare",
            source_id="boss_prepare_hint_01",
            scope="route_curve",
            route_type="common",
            stage="boss_prepare",
            trigger_stage="elite_after_big_map",
            node_kind="boss_prepare",
            narrative_role="preparation",
            route_affinity="common",
            risk_level="route",
            hook_tags=["boss_prepare", "elite_pressure"],
            route_gate_tags=[],
            old_case_tags=[],
            military_merit_tags=[],
            clean_reputation_tags=[],
            lightness_tags=[],
            wuzhuangyuan_tags=[],
            expected_player_realm=boss_row.get("expected_realm_default", "10"),
            expected_lightness_level=boss_row.get("expected_lightness_default", "2"),
            required_flags=[],
            optional_flags=["realm_9_or_10"],
            blocked_by_flags=[],
            preview_key="preview.route.boss_prepare_hint_01",
            result_key="result.route.boss_prepare_hint_01",
            choice_count=1,
            choice_profile="single_continue",
            effect_profile="boss_preparation_mark",
            should_write_body=False,
            body_style="none",
            line_budget=0,
            source_operation_node_id="op_boss_prepare_01",
            source_reward_plan_id="",
            notes="Boss preparation hint skeleton for late-stage pacing.",
        ),
    ]


def build_stage_lookup(slot_rows: list[dict[str, str]]) -> dict[str, str]:
    return {row.get("battle_slot_id", ""): row.get("stage", "") for row in slot_rows}


def load_optional_narrative_doc() -> str:
    path = Path("docs/NARRATIVE.md")
    if not path.exists():
        return ""
    return path.read_text(encoding="utf-8")


def main() -> int:
    args = parse_args()
    design_dir = Path(args.design_dir)
    out_path = Path(args.out)
    must_exist(design_dir)

    operation_rows = read_tsv(design_dir / "generated_operation_node_plan.tsv")
    reward_rows = read_tsv(design_dir / "generated_battle_reward_plan.tsv")
    route_rows = read_tsv(design_dir / "generated_route_progression_curve.tsv")
    slot_rows = read_tsv(design_dir / "generated_battle_slot_plan.tsv")
    _ = load_optional_narrative_doc()

    slot_stage_lookup = build_stage_lookup(slot_rows)
    operation_nodes = build_operation_nodes(operation_rows)
    battle_nodes = build_battle_nodes(reward_rows, slot_stage_lookup)
    hint_nodes = build_route_hint_nodes(route_rows)
    all_nodes = operation_nodes + battle_nodes + hint_nodes

    write_tsv(out_path, [node.to_row() for node in all_nodes])
    print(f"WROTE: {out_path}")
    print(f"NARRATIVE_NODES: {len(all_nodes)}")
    print(f"SOURCE_OPERATION: {len(operation_nodes)}")
    print(f"SOURCE_BATTLE_REWARD: {len(battle_nodes)}")
    print(f"SOURCE_ROUTE_HINT: {len(hint_nodes)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
