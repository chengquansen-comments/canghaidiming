#!/usr/bin/env python3
"""Generate Content Engine v0.5a battle reward plan (design-layer only)."""

from __future__ import annotations

import argparse
import csv
from dataclasses import dataclass
from pathlib import Path


OUTPUT_FIELDS = [
    "reward_plan_id",
    "battle_slot_id",
    "deck_id",
    "deck_skeleton_id",
    "archetype_id",
    "scope",
    "route_type",
    "battle_type",
    "tier",
    "expected_player_realm",
    "expected_lightness_level",
    "reward_profile",
    "martial_xp_reward",
    "weapon_xp_reward",
    "military_merit_reward",
    "clean_reputation_reward",
    "old_case_progress_reward",
    "lightness_reward_type",
    "lightness_cap_unlock",
    "card_reward_pool",
    "resource_reward_type",
    "resource_reward_amount",
    "risk_level",
    "can_trigger_realm_10",
    "can_trigger_lightness_breakthrough",
    "can_trigger_wuzhuangyuan_route",
    "ending_route",
    "source_route_checkpoint",
    "source_deck_id",
    "notes",
]

INPUT_FILES = [
    "generated_battle_slot_plan.tsv",
    "generated_enemy_deck_skeleton.tsv",
    "generated_enemy_deck_sets.tsv",
    "generated_enemy_archetype_pool.tsv",
    "generated_route_progression_curve.tsv",
    "progression_numeric_config_v1_3.tsv",
]


@dataclass(frozen=True)
class DeckInfo:
    deck_id: str
    deck_skeleton_id: str
    archetype_id: str
    scope: str
    route_type: str
    battle_type: str
    tier: str
    deck_variant_role: str


@dataclass(frozen=True)
class SlotInfo:
    battle_slot_id: str
    route_type: str
    battle_type: str
    expected_player_realm: str
    expected_lightness_level: str
    enemy_pool_scope: str
    stage: str


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Generate deterministic battle reward plan for Content Engine v0.5a.")
    parser.add_argument("--design-dir", default="data/design")
    parser.add_argument("--out", default="data/design/generated_battle_reward_plan.tsv")
    return parser.parse_args()


def must_exist(design_dir: Path) -> None:
    missing = [name for name in INPUT_FILES if not (design_dir / name).exists()]
    if missing:
        text = ", ".join(str(design_dir / item) for item in missing)
        raise FileNotFoundError(f"Missing required design inputs: {text}")


def read_tsv(path: Path) -> list[dict[str, str]]:
    with path.open("r", encoding="utf-8", newline="") as handle:
        return list(csv.DictReader(handle, delimiter="\t"))


def write_tsv(path: Path, rows: list[dict[str, str]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=OUTPUT_FIELDS, delimiter="\t", lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)


def to_bool(value: bool) -> str:
    return "true" if value else "false"


def parse_slots(rows: list[dict[str, str]]) -> dict[str, SlotInfo]:
    return {
        row.get("battle_slot_id", ""): SlotInfo(
            battle_slot_id=row.get("battle_slot_id", ""),
            route_type=row.get("route_type", ""),
            battle_type=row.get("battle_type", ""),
            expected_player_realm=row.get("expected_player_realm", ""),
            expected_lightness_level=row.get("expected_lightness_level", ""),
            enemy_pool_scope=row.get("enemy_pool_scope", ""),
            stage=row.get("stage", ""),
        )
        for row in rows
    }


def parse_decks(rows: list[dict[str, str]]) -> list[DeckInfo]:
    by_id: dict[str, DeckInfo] = {}
    for row in rows:
        deck_id = row.get("deck_id", "")
        if deck_id in by_id:
            continue
        by_id[deck_id] = DeckInfo(
            deck_id=deck_id,
            deck_skeleton_id=row.get("deck_skeleton_id", ""),
            archetype_id=row.get("archetype_id", ""),
            scope=row.get("scope", ""),
            route_type=row.get("route_type", ""),
            battle_type=row.get("battle_type", ""),
            tier=row.get("tier", ""),
            deck_variant_role=row.get("deck_variant_role", ""),
        )
    return sorted(by_id.values(), key=lambda item: item.deck_id)


def row_base(
    reward_plan_id: str,
    slot: SlotInfo,
    reward_profile: str,
    martial_xp: int,
    weapon_xp: int,
    merit: int,
    clean_rep: int,
    old_case: int,
    lightness_type: str,
    lightness_cap: str,
    card_pool: str,
    resource_type: str,
    resource_amount: int,
    risk: str,
    can_realm_10: bool,
    can_lightness_break: bool,
    can_wz: bool,
    ending_route: str,
    checkpoint: str,
    notes: str,
    deck: DeckInfo | None = None,
) -> dict[str, str]:
    return {
        "reward_plan_id": reward_plan_id,
        "battle_slot_id": slot.battle_slot_id,
        "deck_id": "" if deck is None else deck.deck_id,
        "deck_skeleton_id": "" if deck is None else deck.deck_skeleton_id,
        "archetype_id": "" if deck is None else deck.archetype_id,
        "scope": slot.enemy_pool_scope if deck is None else deck.scope,
        "route_type": slot.route_type if deck is None else deck.route_type,
        "battle_type": slot.battle_type if deck is None else deck.battle_type,
        "tier": "" if deck is None else deck.tier,
        "expected_player_realm": slot.expected_player_realm,
        "expected_lightness_level": slot.expected_lightness_level,
        "reward_profile": reward_profile,
        "martial_xp_reward": str(martial_xp),
        "weapon_xp_reward": str(weapon_xp),
        "military_merit_reward": str(merit),
        "clean_reputation_reward": str(clean_rep),
        "old_case_progress_reward": str(old_case),
        "lightness_reward_type": lightness_type,
        "lightness_cap_unlock": lightness_cap,
        "card_reward_pool": card_pool,
        "resource_reward_type": resource_type,
        "resource_reward_amount": str(resource_amount),
        "risk_level": risk,
        "can_trigger_realm_10": to_bool(can_realm_10),
        "can_trigger_lightness_breakthrough": to_bool(can_lightness_break),
        "can_trigger_wuzhuangyuan_route": to_bool(can_wz),
        "ending_route": ending_route,
        "source_route_checkpoint": checkpoint,
        "source_deck_id": "" if deck is None else deck.deck_id,
        "notes": notes,
    }


def choose_boss_decks(decks: list[DeckInfo]) -> dict[str, DeckInfo]:
    out: dict[str, DeckInfo] = {}
    for deck in decks:
        if deck.scope == "boss_normal":
            out["normal_boss"] = deck
        if deck.scope == "boss_true" and deck.archetype_id == "true_boss_gatekeeper":
            out["true_gate"] = deck
        if deck.scope == "boss_true" and deck.archetype_id == "true_boss_hidden_commander" and deck.deck_variant_role == "phase_1":
            out["true_final_phase_1"] = deck
        if deck.scope == "boss_true" and deck.archetype_id == "true_boss_hidden_commander" and deck.deck_variant_role == "phase_2":
            out["true_final_phase_2"] = deck
    return out


def choose_exam_decks(decks: list[DeckInfo]) -> list[DeckInfo]:
    exam = [deck for deck in decks if deck.scope == "wuzhuangyuan_exam"]
    final = [deck for deck in exam if deck.archetype_id == "exam_imperial_final_examiner"]
    others = sorted([deck for deck in exam if deck.archetype_id != "exam_imperial_final_examiner"], key=lambda item: item.deck_id)
    return others + final


def reward_rows(
    slots: dict[str, SlotInfo],
    decks: list[DeckInfo],
) -> list[dict[str, str]]:
    out: list[dict[str, str]] = []
    normal_decks = [deck for deck in decks if deck.scope == "big_map_normal"]
    elite_decks = [deck for deck in decks if deck.scope == "big_map_elite"]
    boss_decks = choose_boss_decks(decks)
    exam_decks = choose_exam_decks(decks)

    out.extend(fixed_pre_big_map_rows(slots))
    out.extend(normal_pool_rows(slots["big_map_normal_pool"], normal_decks))
    out.extend(elite_pool_rows(slots["big_map_elite_pool"], elite_decks))
    out.extend(boss_rows(slots, boss_decks))
    out.extend(exam_rows(slots, exam_decks))
    return out


def fixed_pre_big_map_rows(slots: dict[str, SlotInfo]) -> list[dict[str, str]]:
    return [
        row_base(
            reward_plan_id="rw_prologue_01",
            slot=slots["prologue_01"],
            reward_profile="tutorial",
            martial_xp=3,
            weapon_xp=0,
            merit=0,
            clean_rep=1,
            old_case=0,
            lightness_type="none",
            lightness_cap="none",
            card_pool="none",
            resource_type="heal",
            resource_amount=1,
            risk="low",
            can_realm_10=False,
            can_lightness_break=False,
            can_wz=False,
            ending_route="none",
            checkpoint="normal_after_wuju",
            notes="序章教学奖励，不承担路线分流。",
        ),
        row_base(
            reward_plan_id="rw_wuju_weapon_01",
            slot=slots["wuju_weapon_01"],
            reward_profile="weapon_trial",
            martial_xp=5,
            weapon_xp=4,
            merit=1,
            clean_rep=0,
            old_case=0,
            lightness_type="practice",
            lightness_cap="cap_1",
            card_pool="weapon_basic",
            resource_type="supply",
            resource_amount=1,
            risk="low",
            can_realm_10=False,
            can_lightness_break=False,
            can_wz=False,
            ending_route="none",
            checkpoint="normal_after_wuju",
            notes="兵器试长枪基础奖励。",
        ),
        row_base(
            reward_plan_id="rw_wuju_weapon_02",
            slot=slots["wuju_weapon_02"],
            reward_profile="weapon_trial",
            martial_xp=5,
            weapon_xp=4,
            merit=1,
            clean_rep=0,
            old_case=0,
            lightness_type="practice",
            lightness_cap="cap_1",
            card_pool="weapon_basic",
            resource_type="supply",
            resource_amount=1,
            risk="low",
            can_realm_10=False,
            can_lightness_break=False,
            can_wz=False,
            ending_route="none",
            checkpoint="normal_after_wuju",
            notes="兵器试单刀基础奖励。",
        ),
        row_base(
            reward_plan_id="rw_wuju_exam_01",
            slot=slots["wuju_exam_01"],
            reward_profile="wuju_exam",
            martial_xp=5,
            weapon_xp=1,
            merit=1,
            clean_rep=0,
            old_case=0,
            lightness_type="level_up",
            lightness_cap="cap_1",
            card_pool="generic_common",
            resource_type="heal",
            resource_amount=1,
            risk="medium",
            can_realm_10=False,
            can_lightness_break=False,
            can_wz=False,
            ending_route="none",
            checkpoint="normal_after_wuju",
            notes="步法试允许轻功升到 1。",
        ),
        row_base(
            reward_plan_id="rw_wuju_exam_02",
            slot=slots["wuju_exam_02"],
            reward_profile="wuju_exam",
            martial_xp=6,
            weapon_xp=2,
            merit=1,
            clean_rep=0,
            old_case=0,
            lightness_type="practice",
            lightness_cap="cap_1",
            card_pool="weapon_common",
            resource_type="supply",
            resource_amount=1,
            risk="medium",
            can_realm_10=False,
            can_lightness_break=False,
            can_wz=False,
            ending_route="none",
            checkpoint="normal_after_wuju",
            notes="武举兵器考核奖励。",
        ),
        row_base(
            reward_plan_id="rw_wuju_exam_03",
            slot=slots["wuju_exam_03"],
            reward_profile="wuju_exam",
            martial_xp=8,
            weapon_xp=3,
            merit=2,
            clean_rep=0,
            old_case=0,
            lightness_type="practice",
            lightness_cap="cap_1",
            card_pool="weapon_uncommon",
            resource_type="upgrade_card",
            resource_amount=1,
            risk="medium",
            can_realm_10=False,
            can_lightness_break=False,
            can_wz=False,
            ending_route="none",
            checkpoint="normal_after_wuju",
            notes="武举对人战奖励，累计前置达到 32 xp。",
        ),
    ]


def normal_pool_rows(slot: SlotInfo, decks: list[DeckInfo]) -> list[dict[str, str]]:
    rows: list[dict[str, str]] = []
    sorted_decks = sorted(decks, key=lambda item: item.deck_id)
    high_ids = {deck.deck_id for deck in sorted_decks if deck.deck_variant_role in {"advanced", "aggressive"}}  # deterministic subset
    for deck in sorted_decks:
        is_high = deck.deck_id in high_ids and len([item for item in rows if item["reward_profile"] == "normal_high"]) < 5
        reward_profile = "normal_high" if is_high else ("normal_low" if deck.deck_variant_role == "basic" and "militia" in deck.deck_id else "normal_standard")
        weapon_xp = 2 if reward_profile != "normal_high" else 3
        merit = 1
        clean_rep = 0
        old_case = 1 if ("corrupt_patrolman" in deck.deck_id or "official" in deck.deck_id) else 0
        rows.append(
            row_base(
                reward_plan_id=f"rw_big_map_normal_{deck.deck_id}",
                slot=slot,
                reward_profile=reward_profile,
                martial_xp=5,
                weapon_xp=weapon_xp,
                merit=merit,
                clean_rep=clean_rep,
                old_case=old_case,
                lightness_type="practice",
                lightness_cap="cap_2" if reward_profile == "normal_high" else "none",
                card_pool="weapon_common" if reward_profile == "normal_high" else "generic_common",
                resource_type="silver",
                resource_amount=30 if reward_profile == "normal_high" else 20,
                risk="medium" if reward_profile == "normal_high" else "low",
                can_realm_10=False,
                can_lightness_break=False,
                can_wz=False,
                ending_route="none",
                checkpoint="normal_after_big_map",
                notes="普通池奖励，主用于 8-9 境成长。",
                deck=deck,
            )
        )
    return rows


def elite_pool_rows(slot: SlotInfo, decks: list[DeckInfo]) -> list[dict[str, str]]:
    rows: list[dict[str, str]] = []
    sorted_decks = sorted(decks, key=lambda item: item.deck_id)
    for index, deck in enumerate(sorted_decks):
        is_high = index >= len(sorted_decks) - 3
        profile = "elite_high" if is_high else "elite_standard"
        merit = 3 if is_high else 2
        old_case = 2 if "elite_military_officer" in deck.deck_id and is_high else (1 if "elite_military_officer" in deck.deck_id else 0)
        rows.append(
            row_base(
                reward_plan_id=f"rw_big_map_elite_{deck.deck_id}",
                slot=slot,
                reward_profile=profile,
                martial_xp=12,
                weapon_xp=4 if not is_high else 5,
                merit=merit,
                clean_rep=0,
                old_case=old_case,
                lightness_type="practice",
                lightness_cap="cap_2",
                card_pool="elite_rare" if is_high else "weapon_or_generic_uncommon",
                resource_type="upgrade_card" if is_high else "supply",
                resource_amount=1,
                risk="high",
                can_realm_10=is_high,
                can_lightness_break=False,
                can_wz=is_high,
                ending_route="none",
                checkpoint="elite_after_big_map",
                notes="精英池奖励，用于路线分流与武境 10 触发。",
                deck=deck,
            )
        )
    return rows


def boss_rows(slots: dict[str, SlotInfo], boss_decks: dict[str, DeckInfo]) -> list[dict[str, str]]:
    rows: list[dict[str, str]] = []
    normal = boss_decks.get("normal_boss")
    gate = boss_decks.get("true_gate")
    final_phase_1 = boss_decks.get("true_final_phase_1")
    final_phase_2 = boss_decks.get("true_final_phase_2")
    if normal is not None:
        rows.append(
            row_base(
                reward_plan_id=f"rw_boss_{normal.deck_id}",
                slot=slots["normal_boss_01"],
                reward_profile="boss_normal",
                martial_xp=12,
                weapon_xp=4,
                merit=3,
                clean_rep=0,
                old_case=1,
                lightness_type="practice",
                lightness_cap="cap_2",
                card_pool="boss_signature",
                resource_type="clue",
                resource_amount=1,
                risk="boss",
                can_realm_10=False,
                can_lightness_break=False,
                can_wz=False,
                ending_route="normal",
                checkpoint="normal_after_boss",
                notes="普通结局 Boss 奖励，保证 8-9 境可通。",
                deck=normal,
            )
        )
    if gate is not None:
        rows.append(
            row_base(
                reward_plan_id=f"rw_boss_{gate.deck_id}",
                slot=slots["true_boss_01"],
                reward_profile="boss_true_gate",
                martial_xp=12,
                weapon_xp=4,
                merit=4,
                clean_rep=1,
                old_case=2,
                lightness_type="level_up",
                lightness_cap="cap_3",
                card_pool="boss_signature",
                resource_type="clue",
                resource_amount=1,
                risk="boss",
                can_realm_10=True,
                can_lightness_break=True,
                can_wz=False,
                ending_route="true_route",
                checkpoint="true_after_boss_1",
                notes="真路线守门 Boss 奖励，稳定进入 10 境段。",
                deck=gate,
            )
        )
    if final_phase_1 is not None:
        rows.append(
            row_base(
                reward_plan_id=f"rw_boss_{final_phase_1.deck_id}",
                slot=slots["true_boss_02"],
                reward_profile="true_boss",
                martial_xp=16,
                weapon_xp=5,
                merit=5,
                clean_rep=1,
                old_case=3,
                lightness_type="practice",
                lightness_cap="cap_3",
                card_pool="boss_signature",
                resource_type="remove_card",
                resource_amount=1,
                risk="boss",
                can_realm_10=True,
                can_lightness_break=True,
                can_wz=False,
                ending_route="true_route",
                checkpoint="true_after_true_boss",
                notes="真 Boss 战阶段一奖励规划。",
                deck=final_phase_1,
            )
        )
    if final_phase_2 is not None:
        rows.append(
            row_base(
                reward_plan_id=f"rw_boss_{final_phase_2.deck_id}",
                slot=slots["true_boss_02"],
                reward_profile="true_boss",
                martial_xp=16,
                weapon_xp=5,
                merit=5,
                clean_rep=2,
                old_case=3,
                lightness_type="practice",
                lightness_cap="cap_3",
                card_pool="boss_signature",
                resource_type="title",
                resource_amount=1,
                risk="boss",
                can_realm_10=True,
                can_lightness_break=True,
                can_wz=False,
                ending_route="true_route",
                checkpoint="true_after_true_boss",
                notes="真 Boss 战阶段二奖励规划。",
                deck=final_phase_2,
            )
        )
    return rows


def exam_rows(slots: dict[str, SlotInfo], decks: list[DeckInfo]) -> list[dict[str, str]]:
    rows: list[dict[str, str]] = []
    slot_ids = ["wz_exam_01", "wz_exam_02", "wz_exam_03", "wz_exam_04", "wz_exam_05"]
    martial = [8, 8, 9, 10, 12]
    weapon = [3, 3, 4, 4, 5]
    merit = [2, 2, 3, 3, 4]
    lightness_type = ["practice", "practice", "level_up", "practice", "rare_breakthrough"]
    lightness_cap = ["cap_2", "cap_2", "cap_3", "cap_3", "cap_4"]
    pool = ["exam_official_reward", "exam_official_reward", "exam_official_reward", "exam_official_reward", "final_upgrade"]
    res_type = ["supply", "heal", "upgrade_card", "remove_card", "title"]
    profile = ["wuzhuangyuan_exam", "wuzhuangyuan_exam", "wuzhuangyuan_exam", "wuzhuangyuan_exam", "wuzhuangyuan_final"]
    for idx, slot_id in enumerate(slot_ids):
        deck = decks[idx] if idx < len(decks) else None
        rows.append(
            row_base(
                reward_plan_id=f"rw_exam_{'' if deck is None else deck.deck_id}",
                slot=slots[slot_id],
                reward_profile=profile[idx],
                martial_xp=martial[idx],
                weapon_xp=weapon[idx],
                merit=merit[idx],
                clean_rep=1,
                old_case=0,
                lightness_type=lightness_type[idx],
                lightness_cap=lightness_cap[idx],
                card_pool=pool[idx],
                resource_type=res_type[idx],
                resource_amount=1,
                risk="exam",
                can_realm_10=False,
                can_lightness_break=True if idx in {2, 4} else False,
                can_wz=False,
                ending_route="wuzhuangyuan" if idx == 4 else "none",
                checkpoint="wuzhuangyuan_after_exam" if idx == 4 else "wuzhuangyuan_before_exam",
                notes="武状元考试奖励规划；不抢真结局旧案主题。",
                deck=deck,
            )
        )
    return rows


def main() -> int:
    args = parse_args()
    design_dir = Path(args.design_dir)
    out_path = Path(args.out)
    must_exist(design_dir)

    slot_rows = read_tsv(design_dir / "generated_battle_slot_plan.tsv")
    deck_set_rows = read_tsv(design_dir / "generated_enemy_deck_sets.tsv")
    _ = read_tsv(design_dir / "generated_enemy_deck_skeleton.tsv")
    _ = read_tsv(design_dir / "generated_enemy_archetype_pool.tsv")
    _ = read_tsv(design_dir / "generated_route_progression_curve.tsv")
    _ = read_tsv(design_dir / "progression_numeric_config_v1_3.tsv")

    slots = parse_slots(slot_rows)
    decks = parse_decks(deck_set_rows)
    rows = reward_rows(slots, decks)
    write_tsv(out_path, rows)

    print(f"WROTE: {out_path}")
    print(f"REWARD_PLAN_ROWS: {len(rows)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
