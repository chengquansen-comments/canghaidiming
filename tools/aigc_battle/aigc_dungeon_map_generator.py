#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import random
from dataclasses import dataclass
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[2]
PROGRESSION_DIR = ROOT / "data" / "aigc_battle" / "progression_templates"
PACK_ROOT = ROOT / "data" / "aigc_battle" / "generated" / "dungeon_progression_v1_3" / "packs"
CONTRACT_PATH = ROOT / "data" / "aigc_battle" / "generated" / "dungeon_big_map_integration" / "existing_big_map_contract.json"
OUT_DIR = ROOT / "data" / "aigc_battle" / "generated" / "dungeon_maps"


@dataclass
class CandidateSpec:
    category: str
    ref_id: str
    node_type: str
    title: str
    subtitle: str
    preview_text: str
    route_tags: list[str]
    old_case_tags: list[str]


def _slug(text: str) -> str:
    return str(text).strip().lower().replace(" ", "_").replace("-", "_")


def _read_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def _write_json(path: Path, payload: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def _write_text(path: Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8")


def _battle_effects(slot: dict[str, Any]) -> dict[str, Any]:
    return {
        "military_merit": int(slot.get("military_merit_reward", 0)),
        "clean_reputation": 1 if "public" in slot.get("narrative_tags", []) else 0,
        "case_clues": 1 if slot.get("old_case_tags", []) else 0,
    }


def _operation_effects(op: dict[str, Any]) -> dict[str, Any]:
    effects = op.get("effects", {})
    result = {}
    if isinstance(effects, dict):
        for key in ["military_merit", "clean_reputation", "old_case_clue_delta", "martial_xp", "weapon_xp"]:
            if key in effects:
                result[key] = effects[key]
    if "old_case_clue_delta" in result:
        result["case_clues"] = result.pop("old_case_clue_delta")
    return result


def _compatible_primary_secondary(route_tags: list[str], old_case_tags: list[str], fallback_type: str) -> tuple[str, str]:
    if "old_case" in route_tags or old_case_tags:
        return ("old_case", "military")
    if "lightness" in route_tags:
        return ("reputation", "military")
    if fallback_type in {"combat_common", "combat_elite"}:
        return ("military", "old_case" if old_case_tags else "")
    if fallback_type == "case":
        return ("old_case", "")
    if fallback_type == "reputation":
        return ("reputation", "")
    if fallback_type == "risk":
        return ("reputation", "old_case")
    return ("military", "")


def _node_title_from_operation(op: dict[str, Any]) -> tuple[str, str]:
    operation_type = str(op.get("operation_type", "operation"))
    mapping = {
        "camp_rest": ("行营修整", "回气整备"),
        "training_ground": ("校场磨招", "稳练兵器"),
        "military_office": ("军府批令", "积累军功"),
        "weapon_shop": ("军器补给", "换新兵刃"),
        "old_case_clue": ("旧案线索", "拾取残页"),
        "lightness_encounter": ("轻身奇遇", "寻步法机缘"),
        "master_teaching": ("前辈点拨", "临阵开窍"),
        "prepare_before_boss": ("战前整备", "压阵收束"),
        "capital_prepare": ("回京备考", "整冠候试"),
    }
    return mapping.get(operation_type, ("行路杂事", operation_type))


def _subtitle_for_slot(slot: dict[str, Any]) -> str:
    battle_type = str(slot.get("battle_type", "battle"))
    mapping = {
        "prologue": "序章教学战",
        "weapon_trial": "武举兵器试",
        "formal_exam": "武举正式考核",
        "normal": "大地图普通战",
        "elite": "大地图精英战",
        "rare_event": "稀有事件战",
        "boss": "结局 Boss",
        "capital_exam": "回京考试战",
    }
    return mapping.get(battle_type, battle_type)


def _preview_for_slot(slot: dict[str, Any]) -> str:
    tags = slot.get("narrative_tags", [])
    if "tutorial" in tags:
        return "伤痕未止，潮线上已经有人逼来。"
    if "wuju" in tags:
        return "考场不大，但看台上的目光很重。"
    if slot.get("battle_type") == "elite":
        return "前路有人等你犯错，这一战不是照表出牌。"
    if slot.get("battle_type") == "rare_event":
        return "风向忽然不对，这不是寻常路上会遇见的人。"
    if slot.get("battle_type") == "boss":
        return "再往前，路就不会自己退开。"
    if slot.get("battle_type") == "capital_exam":
        return "京师试场只认强弱，不认侥幸。"
    return "路口有兵火气，也有你想要的东西。"


def _result_for_slot(slot: dict[str, Any]) -> str:
    battle_type = str(slot.get("battle_type", "battle"))
    route_type = str(slot.get("route_type", ""))
    if battle_type == "prologue":
        return "你扛过了第一波杀意，海风里终于有了自己的立脚点。"
    if "wuju" in slot.get("narrative_tags", []):
        return "这一场不是白打，台下的人已经重新估量你。"
    if battle_type == "elite":
        return "硬仗拿下之后，前路不再只是寻常军情。"
    if battle_type == "capital_exam":
        return "试场记住了你的出手，下一场会更难也更近。"
    if battle_type == "boss" and route_type == "normal":
        return "普通结局：奉命收束海门事件。"
    if battle_type == "boss" and route_type == "true":
        return "真结局：旧案与火器暗线完成收束。"
    if battle_type == "rare_event":
        return "这一战留下的不是热血，而是后面会发作的余波。"
    return "这一战有了定数，路也跟着往前推了一格。"


def _story_arc_for_slot(slot: dict[str, Any], segment: str, node_type: str) -> str:
    route_type = str(slot.get("route_type", ""))
    tags = set(str(tag) for tag in slot.get("narrative_tags", []))
    old_case_tags = set(str(tag) for tag in slot.get("old_case_tags", []))
    if node_type == "true_boss" or route_type == "true" or old_case_tags:
        return "old_case"
    if node_type == "wuzhuangyuan_exam" or route_type == "wuzhuangyuan":
        return "capital_exam"
    if segment == "prologue":
        return "prologue"
    if segment == "wuju":
        return "wuju"
    if "frontline" in tags or "coast" in tags:
        return "coastal_front"
    if "public" in tags:
        return "public_order"
    return "military_pressure"


def _story_stage_for_slot(slot: dict[str, Any], segment: str) -> str:
    if segment in {"prologue", "wuju"}:
        return segment
    battle_type = str(slot.get("battle_type", "battle"))
    if battle_type == "normal":
        return "big_map"
    if battle_type == "elite":
        return "big_map_elite"
    if battle_type == "rare_event":
        return "big_map_rare"
    if battle_type == "boss":
        return "ending"
    if battle_type == "capital_exam":
        return "capital_exam"
    return battle_type


def _story_variant_for_slot(slot: dict[str, Any], lane: int) -> str:
    archetype = _slug(str(slot.get("enemy_archetype", "unknown")))
    battle_index = int(slot.get("battle_index", 0))
    return f"{archetype}_b{battle_index:02d}_l{lane:02d}"


def _story_title(node_id: str, slot: dict[str, Any], segment: str, node_type: str) -> str:
    route_type = str(slot.get("route_type", ""))
    if node_type == "normal_boss":
        return "海门收束战"
    if node_type == "true_boss":
        if node_id.endswith("001"):
            return "旧案守门人"
        return "火器暗影"
    if node_type == "wuzhuangyuan_exam":
        fixed = {
            "slot_wz01_capital_weapon_review": "入京校阅",
            "slot_wz02_footwork_trial": "步战较艺",
            "slot_wz03_mixed_weapon_exam": "马步兵械",
            "slot_wz04_duel_chain": "擂台连胜",
            "slot_wz05_imperial_final_examiner": "殿前终试",
        }
        return fixed.get(str(slot.get("battle_slot_id", "")), str(slot.get("enemy_archetype", "京师试战")).replace("_", " ").title())
    if segment == "prologue":
        return "海潮首战"
    if segment == "wuju":
        return str(slot.get("enemy_archetype", "武举试手")).replace("_", " ").title()
    if route_type == "true":
        return "旧案线追击"
    if route_type == "wuzhuangyuan":
        return "京师试战"
    tags = set(str(tag) for tag in slot.get("narrative_tags", []))
    if "coast" in tags:
        return "海线接敌"
    if "frontline" in tags:
        return "前压军情"
    return str(slot.get("enemy_archetype", "遭遇战")).replace("_", " ").title()


def _story_preview(node_id: str, slot: dict[str, Any], segment: str, node_type: str) -> str:
    if node_type == "normal_boss":
        return "奉命收束海门之前，最后一层兵火气已经压到脸上。"
    if node_type == "true_boss":
        if node_id.endswith("001"):
            return "旧案走到门口，不会自己开。"
        return "暗线已经不剩遮掩，这一战之后要么见真相，要么全埋住。"
    if node_type == "wuzhuangyuan_exam":
        previews = {
            "slot_wz01_capital_weapon_review": "京师先看你的兵器，不先看你的志气。",
            "slot_wz02_footwork_trial": "步法一乱，后面的武艺都白讲。",
            "slot_wz03_mixed_weapon_exam": "台上换手极快，不会只让你打一种兵器。",
            "slot_wz04_duel_chain": "擂台不让你喘匀气，连胜本身就是试题。",
            "slot_wz05_imperial_final_examiner": "殿前不认侥幸，最后一手就是你的名分。",
        }
        return previews.get(str(slot.get("battle_slot_id", "")), _preview_for_slot(slot))
    if segment == "prologue":
        return "伤口还没冷，潮线上已经有人来试你的命。"
    if segment == "wuju":
        return "武举场上，先被记住的是失手，不是侥幸。"
    tags = set(str(tag) for tag in slot.get("narrative_tags", []))
    if "coast" in tags:
        return "海风里有埋伏味，这一格不是平推过去的。"
    if "frontline" in tags:
        return "前线压得很近，这一战打完才知道路还能不能往前。"
    if "old_case" in tags or slot.get("old_case_tags"):
        return "线索还没成形，但这场接敌已经带着旧案的影子。"
    return _preview_for_slot(slot)


def _story_result(node_id: str, slot: dict[str, Any], segment: str, node_type: str) -> str:
    if node_type in {"normal_boss", "true_boss", "wuzhuangyuan_exam"}:
        return _result_for_slot(slot)
    if segment == "prologue":
        return "你活过了潮边第一战，这张图才真正对你展开。"
    if segment == "wuju":
        return "这一手被记下，后面的路会按这个分量看你。"
    if slot.get("old_case_tags"):
        return "兵刃落下之后，线索没有消失，反而更清楚了一层。"
    return _result_for_slot(slot)


def _story_beat_for_battle(node_id: str, slot: dict[str, Any], segment: str, node_type: str, lane: int) -> dict[str, Any]:
    story_arc = _story_arc_for_slot(slot, segment, node_type)
    story_stage = _story_stage_for_slot(slot, segment)
    story_variant = _story_variant_for_slot(slot, lane)
    return {
        "story_beat_id": f"beat_{_slug(node_id)}_{story_arc}_{story_variant}",
        "story_arc": story_arc,
        "story_role": str(slot.get("enemy_archetype", "unknown")),
        "story_stage": story_stage,
        "story_variant": story_variant,
        "title": _story_title(node_id, slot, segment, node_type),
        "preview_text": _story_preview(node_id, slot, segment, node_type),
        "result_text": _story_result(node_id, slot, segment, node_type),
        "entry_hint": _story_preview(node_id, slot, segment, node_type),
        "exit_hint": _story_result(node_id, slot, segment, node_type),
    }


def _node_type_to_compatible(node_type: str) -> str:
    mapping = {
        "prologue_battle": "combat_common",
        "wuju_battle": "combat_common",
        "battle_normal": "combat_common",
        "battle_elite": "combat_elite",
        "operation": "military",
        "old_case": "case",
        "training": "military",
        "lightness_event": "risk",
        "prepare": "rest",
        "boss_gate": "rest",
        "route_branch": "military",
        "normal_boss": "combat_elite",
        "true_boss": "combat_elite",
        "wuzhuangyuan_exam": "combat_elite",
        "start": "military",
    }
    return mapping[node_type]


def _node_type_to_state(node_type: str, node_id: str, available_ids: list[str], completed_ids: list[str]) -> str:
    if node_id in completed_ids:
        return "completed"
    if node_id in available_ids:
        return "available"
    if node_type == "start":
        return "start"
    return "locked"


def _load_sources(progression_id: str, pack_id: str) -> dict[str, Any]:
    progression = _read_json(PROGRESSION_DIR / f"{progression_id}.json")
    pack_dir = PACK_ROOT / pack_id
    return {
        "progression": progression,
        "manifest": _read_json(pack_dir / "content_pool_manifest.json"),
        "battle_slot_pool": _read_json(pack_dir / "battle_slot_pool.json"),
        "operation_node_pool": _read_json(pack_dir / "operation_node_pool.json"),
        "route_rules": _read_json(pack_dir / "route_rules.json"),
        "growth_rules": _read_json(pack_dir / "growth_rules.json"),
        "contract": _read_json(CONTRACT_PATH),
        "pack_dir": pack_dir,
    }


def _slot_index(slots: list[dict[str, Any]]) -> dict[str, dict[str, Any]]:
    return {str(slot["battle_slot_id"]): slot for slot in slots}


def _op_index(items: list[dict[str, Any]]) -> dict[str, dict[str, Any]]:
    return {str(item["operation_node_id"]): item for item in items}


def _collect_slots(slots: list[dict[str, Any]], stage: str, battle_type: str | None = None, route_type: str | None = None) -> list[dict[str, Any]]:
    result = []
    for slot in slots:
        if str(slot.get("stage", "")) != stage:
            continue
        if battle_type is not None and str(slot.get("battle_type", "")) != battle_type:
            continue
        if route_type is not None and str(slot.get("route_type", "")) != route_type:
            continue
        result.append(slot)
    return result


def _layer_plan() -> list[dict[str, Any]]:
    return [
        {"kind": "battle", "mode": "normal"},
        {"kind": "operation", "ops": ["op_training_ground", "op_camp_rest"]},
        {"kind": "battle", "mode": "forced_elite"},
        {"kind": "battle", "mode": "normal"},
        {"kind": "operation", "ops": ["op_old_case_clue", "op_military_office"]},
        {"kind": "battle", "mode": "mixed_elite_middle"},
        {"kind": "operation", "ops": ["op_weapon_shop", "op_lightness_encounter"]},
        {"kind": "battle", "mode": "normal"},
        {"kind": "battle", "mode": "forced_elite"},
        {"kind": "operation", "ops": ["op_training_ground", "op_old_case_clue"]},
        {"kind": "battle", "mode": "normal"},
        {"kind": "battle", "mode": "normal"},
        {"kind": "operation", "ops": ["op_military_office", "op_master_teaching"]},
        {"kind": "battle", "mode": "normal"},
        {"kind": "operation", "ops": ["op_camp_rest", "op_old_case_clue"]},
        {"kind": "battle", "mode": "normal"},
        {"kind": "battle", "mode": "mixed_elite_heavy"},
        {"kind": "operation", "ops": ["op_lightness_encounter", "op_training_ground"]},
        {"kind": "battle", "mode": "normal"},
        {"kind": "battle", "mode": "forced_elite"},
        {"kind": "operation", "ops": ["op_master_teaching", "op_military_office"]},
        {"kind": "battle", "mode": "normal"},
        {"kind": "operation", "ops": ["op_prepare_before_boss", "op_capital_prepare"]},
        {"kind": "battle", "mode": "rare_or_normal"},
    ]


def _candidate_specs_for_battle(mode: str, pools: dict[str, list[dict[str, Any]]], counters: dict[str, int]) -> list[CandidateSpec]:
    def take(name: str) -> dict[str, Any]:
        collection = pools[name]
        index = counters.get(name, 0) % len(collection)
        counters[name] = counters.get(name, 0) + 1
        return collection[index]

    specs: list[CandidateSpec] = []
    if mode == "forced_elite":
        chosen = [take("elite"), take("elite")]
    elif mode == "mixed_elite_middle":
        chosen = [take("normal"), take("elite"), take("normal")]
    elif mode == "mixed_elite_heavy":
        chosen = [take("normal"), take("normal"), take("elite")]
    elif mode == "rare_or_normal":
        chosen = [take("normal"), take("normal"), take("rare")]
    else:
        chosen = [take("normal"), take("normal")]

    for slot in chosen:
        is_elite = str(slot.get("battle_type")) == "elite"
        node_type = "battle_elite" if is_elite else "battle_normal"
        specs.append(
            CandidateSpec(
                category="battle",
                ref_id=str(slot["battle_slot_id"]),
                node_type=node_type,
                title=str(slot.get("enemy_archetype", "遭遇")).replace("_", " ").title(),
                subtitle=_subtitle_for_slot(slot),
                preview_text=_preview_for_slot(slot),
                route_tags=list(slot.get("narrative_tags", [])),
                old_case_tags=list(slot.get("old_case_tags", [])),
            )
        )
    return specs


def _candidate_specs_for_operation(op_ids: list[str], op_by_id: dict[str, dict[str, Any]]) -> list[CandidateSpec]:
    specs = []
    for op_id in op_ids:
        op = op_by_id[op_id]
        title, subtitle = _node_title_from_operation(op)
        operation_type = str(op.get("operation_type", "operation"))
        node_type = "operation"
        if operation_type == "old_case_clue":
            node_type = "old_case"
        elif operation_type == "training_ground":
            node_type = "training"
        elif operation_type == "lightness_encounter":
            node_type = "lightness_event"
        elif operation_type in {"prepare_before_boss", "capital_prepare"}:
            node_type = "prepare"
        specs.append(
            CandidateSpec(
                category="operation",
                ref_id=op_id,
                node_type=node_type,
                title=title,
                subtitle=subtitle,
                preview_text="此处不见血，但会决定你后面怎么打。",
                route_tags=list(op.get("route_tags", [])),
                old_case_tags=list(op.get("old_case_tags", [])),
            )
        )
    return specs


def _build_node(node_id: str, layer_index: int, lane: int, spec: CandidateSpec, slot_by_id: dict[str, dict[str, Any]], op_by_id: dict[str, dict[str, Any]]) -> dict[str, Any]:
    battle_slot_id = ""
    operation_node_id = ""
    compatible_encounter_id = ""
    compatible_battle_id = ""
    compatible_combat_pool_id = ""
    effects: dict[str, Any] = {}
    tags = [spec.node_type]
    story_beat_id = ""
    story_arc = ""
    story_role = ""
    story_stage = ""
    story_variant = ""
    entry_hint = ""
    exit_hint = ""
    result_text = ""
    if spec.category == "battle":
        slot = slot_by_id[spec.ref_id]
        story = _story_beat_for_battle(node_id, slot, "big_map", spec.node_type, lane)
        battle_slot_id = spec.ref_id
        compatible_encounter_id = str(slot.get("compatible_encounter_id", ""))
        compatible_battle_id = str(slot.get("compatible_battle_id", ""))
        compatible_combat_pool_id = str(slot.get("compatible_combat_pool_id", ""))
        effects = _battle_effects(slot)
        story_beat_id = str(story["story_beat_id"])
        story_arc = str(story["story_arc"])
        story_role = str(story["story_role"])
        story_stage = str(story["story_stage"])
        story_variant = str(story["story_variant"])
        spec.title = str(story["title"])
        spec.preview_text = str(story["preview_text"])
        result_text = str(story["result_text"])
        entry_hint = str(story["entry_hint"])
        exit_hint = str(story["exit_hint"])
        tags.extend(list(slot.get("narrative_tags", [])))
        tags.extend(list(slot.get("old_case_tags", [])))
    else:
        op = op_by_id[spec.ref_id]
        operation_node_id = spec.ref_id
        effects = _operation_effects(op)
        result_text = "%s 已定。" % spec.title
        tags.extend(list(op.get("route_tags", [])))
        tags.extend(list(op.get("old_case_tags", [])))
    compatible_network_node_type = _node_type_to_compatible(spec.node_type)
    primary_line, secondary_line = _compatible_primary_secondary(spec.route_tags, spec.old_case_tags, compatible_network_node_type)
    return {
        "node_id": node_id,
        "segment": "big_map",
        "node_type": spec.node_type,
        "layer_index": layer_index,
        "lane": lane,
        "title": spec.title,
        "subtitle": spec.subtitle,
        "preview_text": spec.preview_text,
        "result_text": result_text,
        "tags": sorted({tag for tag in tags if tag}),
        "route_tags": spec.route_tags,
        "old_case_tags": spec.old_case_tags,
        "battle_slot_id": battle_slot_id,
        "operation_node_id": operation_node_id,
        "story_beat_id": story_beat_id,
        "story_arc": story_arc,
        "story_role": story_role,
        "story_stage": story_stage,
        "story_variant": story_variant,
        "entry_hint": entry_hint,
        "exit_hint": exit_hint,
        "materialized": True,
        "map_node_type_hint": compatible_network_node_type,
        "compatible_network_node_type": compatible_network_node_type,
        "compatible_encounter_id": compatible_encounter_id,
        "compatible_battle_id": compatible_battle_id,
        "compatible_combat_pool_id": compatible_combat_pool_id,
        "enemy_martial_level": int(slot.get("enemy_martial_level", 0)) if spec.category == "battle" else 0,
        "recommended_martial_min": int(slot.get("recommended_martial_min", 0)) if spec.category == "battle" else 0,
        "recommended_martial_max": int(slot.get("recommended_martial_max", 0)) if spec.category == "battle" else 0,
        "primary_line": primary_line,
        "secondary_line": secondary_line,
        "effects": effects,
        "outgoing_node_ids": [],
        "incoming_node_ids": [],
    }


def _add_edge(nodes_by_id: dict[str, dict[str, Any]], edges: list[dict[str, str]], from_id: str, to_id: str) -> None:
    if to_id not in nodes_by_id[from_id]["outgoing_node_ids"]:
        nodes_by_id[from_id]["outgoing_node_ids"].append(to_id)
    if from_id not in nodes_by_id[to_id]["incoming_node_ids"]:
        nodes_by_id[to_id]["incoming_node_ids"].append(from_id)
    edges.append({"from_node_id": from_id, "to_node_id": to_id})


def _build_fixed_battle_node(
    *,
    node_id: str,
    segment: str,
    node_type: str,
    layer_index: int,
    lane: int,
    slot: dict[str, Any],
    primary_line: str,
    secondary_line: str,
    tags: list[str],
    route_tags: list[str],
    old_case_tags: list[str],
) -> dict[str, Any]:
    story = _story_beat_for_battle(node_id, slot, segment, node_type, lane)
    return {
        "node_id": node_id,
        "segment": segment,
        "node_type": node_type,
        "layer_index": layer_index,
        "lane": lane,
        "title": str(story["title"]),
        "subtitle": _subtitle_for_slot(slot),
        "preview_text": str(story["preview_text"]),
        "result_text": str(story["result_text"]),
        "tags": sorted({*tags, *slot.get("narrative_tags", []), *slot.get("old_case_tags", [])}),
        "route_tags": route_tags,
        "old_case_tags": old_case_tags,
        "battle_slot_id": str(slot["battle_slot_id"]),
        "operation_node_id": "",
        "story_beat_id": str(story["story_beat_id"]),
        "story_arc": str(story["story_arc"]),
        "story_role": str(story["story_role"]),
        "story_stage": str(story["story_stage"]),
        "story_variant": str(story["story_variant"]),
        "entry_hint": str(story["entry_hint"]),
        "exit_hint": str(story["exit_hint"]),
        "materialized": True,
        "map_node_type_hint": str(slot.get("map_node_type_hint", "combat_common")),
        "compatible_network_node_type": str(slot.get("compatible_network_node_type", "combat_common")),
        "compatible_encounter_id": str(slot.get("compatible_encounter_id", "")),
        "compatible_battle_id": str(slot.get("compatible_battle_id", "")),
        "compatible_combat_pool_id": str(slot.get("compatible_combat_pool_id", "")),
        "enemy_martial_level": int(slot.get("enemy_martial_level", 0)),
        "recommended_martial_min": int(slot.get("recommended_martial_min", 0)),
        "recommended_martial_max": int(slot.get("recommended_martial_max", 0)),
        "primary_line": primary_line,
        "secondary_line": secondary_line,
        "effects": _battle_effects(slot),
        "outgoing_node_ids": [],
        "incoming_node_ids": [],
    }


def _build_ending_result(route: str, node: dict[str, Any]) -> dict[str, Any]:
    return {
        "final_node": True,
        "route": route,
        "title": str(node.get("title", "")),
        "result_text": str(node.get("result_text", "路线已收束。")),
    }


def generate_map(progression_id: str, pack_id: str, seed: int) -> dict[str, Any]:
    sources = _load_sources(progression_id, pack_id)
    slots = sources["battle_slot_pool"]["battle_slots"]
    ops = sources["operation_node_pool"]["operation_nodes"]
    slot_by_id = _slot_index(slots)
    op_by_id = _op_index(ops)

    normal_slots = _collect_slots(slots, "big_map", "normal")
    elite_slots = _collect_slots(slots, "big_map", "elite")
    rare_slots = _collect_slots(slots, "big_map", "rare_event")
    rng = random.Random(seed)
    counters: dict[str, int] = {
        "normal": rng.randrange(len(normal_slots)),
        "elite": rng.randrange(len(elite_slots)),
        "rare": rng.randrange(len(rare_slots)),
    }
    pools = {
        "normal": normal_slots,
        "elite": elite_slots,
        "rare": rare_slots,
    }

    nodes: list[dict[str, Any]] = []
    nodes_by_id: dict[str, dict[str, Any]] = {}
    edges: list[dict[str, str]] = []
    layers: list[dict[str, Any]] = []

    def push(node: dict[str, Any]) -> None:
        nodes.append(node)
        nodes_by_id[node["node_id"]] = node

    start_node = {
        "node_id": "node_start",
        "segment": "start",
        "node_type": "start",
        "layer_index": 0,
        "lane": 0,
        "title": "海疆起点",
        "subtitle": "整装待发",
        "preview_text": "从这里往前，路不会只给你一条。",
        "tags": ["start"],
        "route_tags": [],
        "old_case_tags": [],
        "battle_slot_id": "",
        "operation_node_id": "",
        "materialized": True,
        "map_node_type_hint": "military",
        "compatible_network_node_type": "military",
        "compatible_encounter_id": "",
        "compatible_battle_id": "",
        "compatible_combat_pool_id": "",
        "primary_line": "military",
        "secondary_line": "",
        "effects": {},
        "outgoing_node_ids": [],
        "incoming_node_ids": [],
    }
    push(start_node)
    layers.append({"layer_index": 0, "segment": "start", "node_ids": ["node_start"]})

    shared_chain = [
        ("node_prologue_001", "prologue", "prologue_battle", "slot_prologue_001"),
        ("node_wuju_001", "wuju", "wuju_battle", "slot_wuju_001"),
        ("node_wuju_002", "wuju", "wuju_battle", "slot_wuju_002"),
        ("node_wuju_003", "wuju", "wuju_battle", "slot_wuju_003"),
        ("node_wuju_004", "wuju", "wuju_battle", "slot_wuju_004"),
        ("node_wuju_005", "wuju", "wuju_battle", "slot_wuju_005"),
    ]
    previous_id = "node_start"
    layer_cursor = 1
    for node_id, segment, node_type, slot_id in shared_chain:
        slot = slot_by_id[slot_id]
        node = _build_fixed_battle_node(
            node_id=node_id,
            segment=segment,
            node_type=node_type,
            layer_index=layer_cursor,
            lane=0,
            slot=slot,
            primary_line="military",
            secondary_line="old_case" if slot.get("old_case_tags") else "",
            tags=[node_type],
            route_tags=list(slot.get("narrative_tags", [])),
            old_case_tags=list(slot.get("old_case_tags", [])),
        )
        push(node)
        _add_edge(nodes_by_id, edges, previous_id, node_id)
        layers.append({"layer_index": layer_cursor, "segment": segment, "node_ids": [node_id]})
        previous_id = node_id
        layer_cursor += 1

    for offset, plan in enumerate(_layer_plan()):
        node_ids: list[str] = []
        if plan["kind"] == "battle":
            specs = _candidate_specs_for_battle(plan["mode"], pools, counters)
        else:
            specs = _candidate_specs_for_operation(plan["ops"], op_by_id)
        for lane, spec in enumerate(specs):
            node_id = f"node_bigmap_{layer_cursor:02d}_{lane:02d}"
            node = _build_node(node_id, layer_cursor, lane, spec, slot_by_id, op_by_id)
            push(node)
            node_ids.append(node_id)
        prev_ids = layers[-1]["node_ids"]
        for from_id in prev_ids:
            for to_id in node_ids:
                _add_edge(nodes_by_id, edges, from_id, to_id)
        layers.append({"layer_index": layer_cursor, "segment": "big_map", "node_ids": node_ids})
        layer_cursor += 1

    boss_gate_id = "node_boss_gate"
    boss_gate = {
        "node_id": boss_gate_id,
        "segment": "ending_gate",
        "node_type": "boss_gate",
        "layer_index": layer_cursor,
        "lane": 0,
        "title": "海门前压阵",
        "subtitle": "收束前线",
        "preview_text": "你要带着自己的路，走到最后那道门前。",
        "tags": ["boss_gate", "prepare"],
        "route_tags": ["boss_prepare"],
        "old_case_tags": [],
        "battle_slot_id": "",
        "operation_node_id": "op_prepare_before_boss",
        "materialized": True,
        "map_node_type_hint": "rest",
        "compatible_network_node_type": "rest",
        "compatible_encounter_id": "",
        "compatible_battle_id": "",
        "compatible_combat_pool_id": "",
        "primary_line": "military",
        "secondary_line": "",
        "effects": {"prepare_bonus": "boss_ready"},
        "outgoing_node_ids": [],
        "incoming_node_ids": [],
    }
    push(boss_gate)
    for from_id in layers[-1]["node_ids"]:
        _add_edge(nodes_by_id, edges, from_id, boss_gate_id)
    layers.append({"layer_index": layer_cursor, "segment": "ending_gate", "node_ids": [boss_gate_id]})
    layer_cursor += 1

    route_branch_nodes = [
        {
            "node_id": "node_route_normal",
            "node_type": "route_branch",
            "title": "收束海门",
            "subtitle": "普通结局路线",
            "route_tags": ["normal"],
        },
        {
            "node_id": "node_route_true",
            "node_type": "route_branch",
            "title": "追查真相",
            "subtitle": "真结局路线",
            "route_tags": ["true"],
        },
        {
            "node_id": "node_route_wuzhuangyuan",
            "node_type": "route_branch",
            "title": "回京赴试",
            "subtitle": "武状元路线",
            "route_tags": ["wuzhuangyuan"],
        },
    ]
    branch_ids = []
    for lane, item in enumerate(route_branch_nodes):
        node = {
            "node_id": item["node_id"],
            "segment": "route_branch",
            "node_type": item["node_type"],
            "layer_index": layer_cursor,
            "lane": lane,
            "title": item["title"],
            "subtitle": item["subtitle"],
            "preview_text": "条件满足时，最后的路由你自己选。",
            "tags": ["route_branch", *item["route_tags"]],
            "route_tags": item["route_tags"],
            "old_case_tags": [],
            "battle_slot_id": "",
            "operation_node_id": "",
            "materialized": True,
            "map_node_type_hint": "military",
            "compatible_network_node_type": "military",
            "compatible_encounter_id": "",
            "compatible_battle_id": "",
            "compatible_combat_pool_id": "",
            "primary_line": "military",
            "secondary_line": "old_case" if "true" in item["route_tags"] else "",
            "effects": {},
            "outgoing_node_ids": [],
            "incoming_node_ids": [],
        }
        push(node)
        branch_ids.append(node["node_id"])
        _add_edge(nodes_by_id, edges, boss_gate_id, node["node_id"])
    layers.append({"layer_index": layer_cursor, "segment": "route_branch", "node_ids": branch_ids})
    layer_cursor += 1

    normal_boss_slot = slot_by_id["slot_normal_boss_coastal_closure"]
    true_boss_slots = [
        slot_by_id["slot_true_boss_old_case_gatekeeper"],
        slot_by_id["slot_true_boss_firearm_shadow"],
    ]
    exam_slots = [
        slot_by_id["slot_wz01_capital_weapon_review"],
        slot_by_id["slot_wz02_footwork_trial"],
        slot_by_id["slot_wz03_mixed_weapon_exam"],
        slot_by_id["slot_wz04_duel_chain"],
        slot_by_id["slot_wz05_imperial_final_examiner"],
    ]

    ending_nodes = [
        ("node_normal_boss", "normal_boss", normal_boss_slot["battle_slot_id"], "node_route_normal"),
        ("node_true_boss_001", "true_boss", true_boss_slots[0]["battle_slot_id"], "node_route_true"),
        ("node_wuzhuangyuan_exam_001", "wuzhuangyuan_exam", exam_slots[0]["battle_slot_id"], "node_route_wuzhuangyuan"),
    ]
    ending_ids = []
    for lane, (node_id, node_type, slot_id, parent_id) in enumerate(ending_nodes):
        slot = slot_by_id[slot_id]
        node = _build_fixed_battle_node(
            node_id=node_id,
            segment="ending",
            node_type=node_type,
            layer_index=layer_cursor,
            lane=lane,
            slot=slot,
            primary_line="old_case" if node_type == "true_boss" else "military",
            secondary_line="military" if node_type == "true_boss" else ("old_case" if slot.get("old_case_tags") else ""),
            tags=[node_type],
            route_tags=[str(slot.get("route_type", ""))],
            old_case_tags=list(slot.get("old_case_tags", [])),
        )
        if node_id == "node_normal_boss":
            node["ending_result"] = _build_ending_result("normal", node)
        push(node)
        ending_ids.append(node_id)
        _add_edge(nodes_by_id, edges, parent_id, node_id)
    layers.append({"layer_index": layer_cursor, "segment": "ending", "node_ids": ending_ids})
    layer_cursor += 1

    node_true_boss_002 = _build_fixed_battle_node(
        node_id="node_true_boss_002",
        segment="ending",
        node_type="true_boss",
        layer_index=layer_cursor,
        lane=0,
        slot=true_boss_slots[1],
        primary_line="old_case",
        secondary_line="military",
        tags=["true_boss", "true_final"],
        route_tags=["true"],
        old_case_tags=list(true_boss_slots[1].get("old_case_tags", [])),
    )
    node_true_boss_002["ending_result"] = _build_ending_result("true", node_true_boss_002)
    push(node_true_boss_002)
    _add_edge(nodes_by_id, edges, "node_true_boss_001", "node_true_boss_002")

    exam_layer_ids = ["node_wuzhuangyuan_exam_002"]
    layers.append({"layer_index": layer_cursor, "segment": "ending", "node_ids": ["node_true_boss_002", "node_wuzhuangyuan_exam_002"]})
    exam_2 = slot_by_id[str(exam_slots[1]["battle_slot_id"])]
    node_exam_2 = _build_fixed_battle_node(
        node_id="node_wuzhuangyuan_exam_002",
        segment="ending",
        node_type="wuzhuangyuan_exam",
        layer_index=layer_cursor,
        lane=1,
        slot=exam_2,
        primary_line="military",
        secondary_line="",
        tags=["wuzhuangyuan_exam", "capital"],
        route_tags=["wuzhuangyuan"],
        old_case_tags=[],
    )
    push(node_exam_2)
    _add_edge(nodes_by_id, edges, "node_wuzhuangyuan_exam_001", "node_wuzhuangyuan_exam_002")
    layer_cursor += 1

    previous_exam_node = "node_wuzhuangyuan_exam_002"
    for index, slot in enumerate(exam_slots[2:], start=3):
        node_id = f"node_wuzhuangyuan_exam_{index:03d}"
        node = _build_fixed_battle_node(
            node_id=node_id,
            segment="ending",
            node_type="wuzhuangyuan_exam",
            layer_index=layer_cursor,
            lane=0,
            slot=slot,
            primary_line="military",
            secondary_line="",
            tags=["wuzhuangyuan_exam", "capital"],
            route_tags=["wuzhuangyuan"],
            old_case_tags=[],
        )
        if index == 5:
            node["ending_result"] = _build_ending_result("wuzhuangyuan", node)
        push(node)
        _add_edge(nodes_by_id, edges, previous_exam_node, node_id)
        layers.append({"layer_index": layer_cursor, "segment": "ending", "node_ids": [node_id]})
        previous_exam_node = node_id
        layer_cursor += 1

    route_state = {
        "run_id": "dungeon_run_seed_1001",
        "map_instance_id": "dungeon_map_seed_1001",
        "current_node_id": "node_start",
        "selected_node_id": "node_prologue_001",
        "visited_node_ids": ["node_start"],
        "visited_path_order": ["node_start"],
        "completed_node_ids": ["node_start"],
        "available_next_node_ids": ["node_prologue_001"],
        "battle_count_so_far": 0,
        "elite_count_so_far": 0,
        "operation_count_so_far": 0,
        "route_flags": {
            "true_route_unlocked": False,
            "wuzhuangyuan_route_unlocked": False
        },
        "martial_realm": 1,
        "lightness_level": 0,
        "military_merit": 0,
        "clean_reputation": 0,
        "old_case_progress": 0,
        "case_clues": 0,
    }

    for node in nodes:
        node["outgoing_node_ids"].sort()
        node["incoming_node_ids"].sort()

    map_instance = {
        "map_instance_id": "dungeon_map_seed_1001",
        "progression_template_id": progression_id,
        "content_pool_pack_id": pack_id,
        "seed": seed,
        "supports_fixed_sequence": False,
        "no_fixed_linear_sequence": True,
        "route_choice_available": True,
        "layers": layers,
        "nodes": nodes,
        "edges": edges,
    }

    compatible_nodes = []
    for node in nodes:
        compatible_node_type = str(node["compatible_network_node_type"])
        state = _node_type_to_state(str(node["node_type"]), str(node["node_id"]), route_state["available_next_node_ids"], route_state["completed_node_ids"])
        x = 60.0 + float(node["layer_index"]) * 46.0
        y = 90.0 + float(node["lane"] + 1) * 78.0
        title = str(node["title"])
        compatible_nodes.append({
            "map_graph_id": node["node_id"],
            "pool_node_id": node["battle_slot_id"] or node["operation_node_id"] or node["node_id"],
            "layer": int(node["layer_index"]),
            "lane": int(node["lane"]),
            "x": x,
            "y": y,
            "title": title,
            "node_type": compatible_node_type,
            "primary_line": str(node.get("primary_line", "military")),
            "secondary_line": str(node.get("secondary_line", "")),
            "preview_text": str(node["preview_text"]),
            "result_text": str(node.get("result_text", "%s 已定。" % title)),
            "effects": dict(node.get("effects", {})),
            "tags": list(node.get("tags", [])),
            "story_beat_id": str(node.get("story_beat_id", "")),
            "story_arc": str(node.get("story_arc", "")),
            "story_role": str(node.get("story_role", "")),
            "story_stage": str(node.get("story_stage", "")),
            "story_variant": str(node.get("story_variant", "")),
            "entry_hint": str(node.get("entry_hint", "")),
            "exit_hint": str(node.get("exit_hint", "")),
            "ending_result": dict(node.get("ending_result", {})),
            "combat": {},
            "combat_pool_id": str(node.get("compatible_combat_pool_id", "")),
            "encounter_id": str(node.get("compatible_encounter_id", "")),
            "battle_id": str(node.get("compatible_battle_id", "")),
            "enemy_martial_level": int(node.get("enemy_martial_level", 0)),
            "recommended_martial_min": int(node.get("recommended_martial_min", 0)),
            "recommended_martial_max": int(node.get("recommended_martial_max", 0)),
            "source_battle_slot_id": str(node.get("battle_slot_id", "")),
            "debug_fallback": False,
            "outgoing": list(node.get("outgoing_node_ids", [])),
            "incoming": list(node.get("incoming_node_ids", [])),
            "state": state,
        })

    compatible = {
        "run_id": route_state["run_id"],
        "seed": seed,
        "layer_count": len(layers),
        "current_layer": 1,
        "current_node_id": route_state["current_node_id"],
        "selected_node_id": route_state["selected_node_id"],
        "completed_node_ids": list(route_state["completed_node_ids"]),
        "available_node_ids": list(route_state["available_next_node_ids"]),
        "pending_map_node_id": "",
        "pending_result_text": "",
        "pending_effects": {},
        "nodes": compatible_nodes,
    }

    report = {
        "generator": "aigc_dungeon_map_generator",
        "map_instance_id": map_instance["map_instance_id"],
        "progression_template_id": progression_id,
        "content_pool_pack_id": pack_id,
        "seed": seed,
        "summary": {
            "layer_count": len(layers),
            "node_count": len(nodes),
            "edge_count": len(edges),
            "route_choice_available": True,
            "available_next_node_ids": list(route_state["available_next_node_ids"]),
            "story_beat_count": len([node for node in nodes if str(node.get("story_beat_id", ""))]),
        },
        "artifacts": {
            "map_instance_path": "data/aigc_battle/generated/dungeon_maps/map_seed_1001.json",
            "route_state_path": "data/aigc_battle/generated/dungeon_maps/route_state_seed_1001_initial.json",
            "big_map_compatible_path": "data/aigc_battle/generated/dungeon_maps/big_map_compatible_seed_1001.json",
        },
    }
    return {
        "map_instance": map_instance,
        "route_state": route_state,
        "compatible": compatible,
        "report": report,
    }


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--progression", required=True)
    parser.add_argument("--pack", required=True)
    parser.add_argument("--seed", required=True, type=int)
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    result = generate_map(args.progression, args.pack, args.seed)
    map_path = OUT_DIR / f"map_seed_{args.seed}.json"
    route_path = OUT_DIR / f"route_state_seed_{args.seed}_initial.json"
    compatible_path = OUT_DIR / f"big_map_compatible_seed_{args.seed}.json"
    report_json_path = OUT_DIR / "map_generation_report.json"
    report_md_path = OUT_DIR / "map_generation_report.md"

    _write_json(map_path, result["map_instance"])
    _write_json(route_path, result["route_state"])
    _write_json(compatible_path, result["compatible"])
    _write_json(report_json_path, result["report"])
    _write_text(
        report_md_path,
        "\n".join([
            "# Dungeon Map Generation Report",
            "",
            "- map_instance_id: `%s`" % result["map_instance"]["map_instance_id"],
            "- progression_template_id: `%s`" % args.progression,
            "- content_pool_pack_id: `%s`" % args.pack,
            "- seed: `%s`" % args.seed,
            "- route_choice_available: `true`",
            "- layer_count: `%s`" % len(result["map_instance"]["layers"]),
            "- node_count: `%s`" % len(result["map_instance"]["nodes"]),
            "- edge_count: `%s`" % len(result["map_instance"]["edges"]),
        ]) + "\n"
    )
    print("wrote %s" % map_path.relative_to(ROOT))
    print("wrote %s" % route_path.relative_to(ROOT))
    print("wrote %s" % compatible_path.relative_to(ROOT))
    print("wrote %s" % report_json_path.relative_to(ROOT))
    print("route_choice_available=true")


if __name__ == "__main__":
    main()
