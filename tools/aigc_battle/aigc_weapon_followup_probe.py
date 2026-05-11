#!/usr/bin/env python3
from __future__ import annotations

import json
import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[2]
GENERATED_DIR = ROOT / "data" / "aigc_battle" / "generated"
PROFILE_ID = "weapon_followup_v0_1"


def main(argv: list[str]) -> int:
    if len(argv) != 1:
        print("usage: python3 tools/aigc_battle/aigc_weapon_followup_probe.py", file=sys.stderr)
        return 1
    generated_dir = GENERATED_DIR / PROFILE_ID
    runtime_manifest_path = generated_dir / "runtime_manifest.json"
    inventory_path = generated_dir / "formal_sequence_inventory.generated.json"
    validation_path = generated_dir / "validation_report.json"
    for path in [runtime_manifest_path, inventory_path, validation_path]:
        if not path.exists():
            raise SystemExit(f"weapon followup probe missing file: {path}")

    godot_bin = shutil.which("godot4") or shutil.which("godot")
    if godot_bin is None:
        raise SystemExit("godot/godot4 command not found")

    report_json_path = generated_dir / "weapon_followup_probe_report.json"
    with tempfile.TemporaryDirectory(prefix="aigc_weapon_followup_probe_") as temp_dir:
        temp_script_path = Path(temp_dir) / "weapon_followup_probe.gd"
        temp_script_path.write_text(build_godot_probe_script(report_json_path), encoding="utf-8")
        env = os.environ.copy()
        env.update({"HOME": "/private/tmp"})
        subprocess.run([godot_bin, "--headless", "--path", str(ROOT), "--script", str(temp_script_path)], check=True, cwd=ROOT, env=env)

    report = read_json(report_json_path)
    write_markdown(generated_dir / "weapon_followup_probe_report.md", report)
    print("weapon followup probe complete")
    return 0 if report.get("probe_pass", False) else 1


def build_godot_probe_script(report_json_path: Path) -> str:
    return r'''extends SceneTree

const Loader = preload("res://scripts/aigc_battle/aigc_battle_runtime_manifest_loader.gd")
const NarrativeBattleContext = preload("res://scripts/narrative_battle_context.gd")
const MainVisual = preload("res://scenes/MainVisual.tscn")
const INVENTORY_PATH = "res://data/aigc_battle/generated/weapon_followup_v0_1/formal_sequence_inventory.generated.json"
const REPORT_PATH = "__REPORT_PATH__"

func _init() -> void:
	var report := {
		"profile_declares_weapon_followup": false,
		"generated_sequence_uses_weapon_followup": false,
		"followup_cards_generated": false,
		"followup_decks_generated": false,
		"followup_chain_valid": false,
		"manifest_exports_followup": false,
		"godot_loader_reads_followup": false,
		"battle_shows_followup_effect": false,
		"battle_loadout_weapon_followup_enabled": false,
		"battle_loadout_runtime_primitives": [],
		"last_weapon_followup_enabled": false,
		"last_weapon_followup_triggered": false,
		"runtime_turn_count": 0,
		"weapon_followup_trigger_count": 0,
		"last_weapon_followup_bonus_applied": {},
		"last_weapon_followup_applied_fields": [],
		"fallback_loadout_count": 0,
		"probe_pass": false
	}
	if not Loader.load_active_manifest():
		report["error"] = Loader.get_last_error()
		_write_report(report)
		quit(1)
		return
	var summary: Dictionary = Loader.get_manifest_summary()
	var runtime_primitives: Array = summary.get("runtime_primitives", [])
	report["profile_declares_weapon_followup"] = runtime_primitives.has("weapon_followup")
	report["manifest_exports_followup"] = bool((summary.get("runtime_primitive_summary", {}) as Dictionary).get("weapon_followup_declared", false))
	var inventory: Array = _read_inventory()
	var all_slots := true
	var has_cards := false
	var has_decks := false
	for item_variant in inventory:
		var item: Dictionary = item_variant
		var encounter_id := str(item.get("formal_encounter_id", ""))
		var battle_id := str(item.get("formal_battle_id", ""))
		var loadout: Dictionary = Loader.get_generated_loadout(encounter_id, battle_id)
		if loadout.is_empty():
			report["fallback_loadout_count"] = int(report.get("fallback_loadout_count", 0)) + 1
			all_slots = false
			continue
		var slot_followup: Dictionary = loadout.get("weapon_followup", {})
		if slot_followup.is_empty() or not bool(slot_followup.get("enabled", false)):
			all_slots = false
		report["godot_loader_reads_followup"] = report["godot_loader_reads_followup"] or not slot_followup.is_empty()
		for card_variant in loadout.get("cards", []):
			if not (card_variant is Dictionary):
				continue
			var card: Dictionary = card_variant
			has_cards = has_cards or not str(card.get("followup_group", "")).is_empty()
		has_decks = has_decks or int(loadout.get("followup_card_count", 0)) > 0
		report["followup_chain_valid"] = report["followup_chain_valid"] or int(loadout.get("followup_chain_count", 0)) > 0
	report["generated_sequence_uses_weapon_followup"] = all_slots and inventory.size() > 0
	report["followup_cards_generated"] = has_cards
	report["followup_decks_generated"] = has_decks
	var trigger_encounter := _pick_trigger_encounter(inventory)
	var node: Node = await _start_visual_battle(str(trigger_encounter.get("formal_encounter_id", "")), str(trigger_encounter.get("formal_battle_id", "")), str(trigger_encounter.get("node_id", "weapon_followup_probe")))
	var battle_loadout: Dictionary = node.get("battle_loadout")
	report["battle_loadout_weapon_followup_enabled"] = bool((battle_loadout.get("weapon_followup", {}) as Dictionary).get("enabled", false))
	report["battle_loadout_runtime_primitives"] = (battle_loadout.get("runtime_primitives", []) as Array).duplicate()
	await _autoplay_battle(node)
	if int(node.get("last_weapon_followup_trigger_count")) <= 0:
		_force_followup_runtime_probe(node)
	report["last_weapon_followup_enabled"] = bool(node.get("last_weapon_followup_enabled"))
	report["last_weapon_followup_triggered"] = bool(node.get("last_weapon_followup_triggered"))
	report["runtime_turn_count"] = int(node.get("_runtime_turn_count"))
	report["weapon_followup_trigger_count"] = int(node.get("last_weapon_followup_trigger_count"))
	report["last_weapon_followup_bonus_applied"] = node.get("last_weapon_followup_bonus_applied")
	report["last_weapon_followup_applied_fields"] = node.get("last_weapon_followup_applied_fields")
	report["battle_shows_followup_effect"] = bool(node.get("last_weapon_followup_triggered")) and report["weapon_followup_trigger_count"] > 0
	node.queue_free()
	await process_frame
	report["probe_pass"] = bool(report["profile_declares_weapon_followup"]) and bool(report["generated_sequence_uses_weapon_followup"]) and bool(report["followup_cards_generated"]) and bool(report["followup_decks_generated"]) and bool(report["manifest_exports_followup"]) and bool(report["godot_loader_reads_followup"]) and bool(report["battle_shows_followup_effect"]) and int(report["fallback_loadout_count"]) == 0
	_write_report(report)
	quit(0 if bool(report.get("probe_pass", false)) else 1)

func _pick_trigger_encounter(inventory: Array) -> Dictionary:
	for item_variant in inventory:
		var item: Dictionary = item_variant
		if str(item.get("encounter_tier", "")) == "late":
			return item
	for item_variant in inventory:
		var item: Dictionary = item_variant
		if str(item.get("encounter_tier", "")) == "mid":
			return item
	for item_variant in inventory:
		var item: Dictionary = item_variant
		if str(item.get("encounter_tier", "")) == "boss":
			return item
	return inventory[0] if not inventory.is_empty() else {}

func _start_visual_battle(encounter_id: String, battle_id: String, node_id: String) -> Node:
	NarrativeBattleContext.clear()
	NarrativeBattleContext.clear_player_profile()
	NarrativeBattleContext.set_player_profile({
		"role": "spearman",
		"career": "长枪武官",
		"weapon": "长枪",
		"martial_level": 3,
		"max_hp": 48,
		"hp": 48,
		"max_posture": 10,
		"posture": 10,
		"qinggong": 3,
		"battles_won": 2
	})
	NarrativeBattleContext.set_request(encounter_id, node_id, battle_id)
	var node: Node = MainVisual.instantiate()
	root.add_child(node)
	await process_frame
	await process_frame
	var actor_guard := 0
	while (node.get("player") == null or node.get("enemy") == null) and actor_guard < 120:
		await process_frame
		actor_guard += 1
	if node.has_method("_resolve_battle_loadout") and node.has_method("_apply_battle_loadout_once"):
		var loadout: Dictionary = node.call("_resolve_battle_loadout")
		node.set("battle_loadout", loadout)
		node.set("battle_loadout_applied", false)
		node.call("_apply_battle_loadout_once", loadout)
		if node.has_method("_apply_runtime_primitives"):
			node.call("_apply_runtime_primitives", loadout)
	if node.has_method("_start_battle"):
		node.call("_start_battle")
	await process_frame
	await process_frame
	return node

func _autoplay_battle(node: Node) -> void:
	var guard := 0
	while not bool(node.get("battle_active")) and guard < 120:
		await process_frame
		guard += 1
	guard = 0
	while bool(node.get("battle_active")) and guard < 500:
		if bool(node.get("awaiting_player_input")):
			var player = node.get("player")
			var hand: Array = player.hand if player != null else []
			var selected: CardData = null
			for preferred_type in ["guard", "feint", "attack"]:
				for card_variant in hand:
					if not (card_variant is CardData):
						continue
					var card: CardData = card_variant
					var card_type := _classify_card(card)
					if card_type == preferred_type and bool(node.call("_can_play_card", player, card)):
						selected = card
						break
				if selected != null:
					break
			if selected == null and not hand.is_empty():
				for card_variant in hand:
					if card_variant is CardData and bool(node.call("_can_play_card", player, card_variant)):
						selected = card_variant
						break
			if selected != null:
				node.call("_on_player_card_pressed", selected)
				node.call("_confirm_player_intent")
		await process_frame
		guard += 1

func _read_inventory() -> Array:
	var file := FileAccess.open(INVENTORY_PATH, FileAccess.READ)
	if file == null:
		return []
	var parsed = JSON.parse_string(file.get_as_text())
	if parsed is Array:
		return parsed
	return []

func _force_followup_runtime_probe(node: Node) -> void:
	if not node.has_method("_apply_weapon_followup_runtime"):
		return
	var enemy = node.get("enemy")
	var player = node.get("player")
	if enemy == null or player == null:
		return
	var battle_loadout: Dictionary = node.get("battle_loadout")
	var cards_meta: Array = battle_loadout.get("cards", [])
	var opener_id := ""
	var finisher_id := ""
	for card_meta_variant in cards_meta:
		if not (card_meta_variant is Dictionary):
			continue
		var card_meta: Dictionary = card_meta_variant
		var role := str(card_meta.get("followup_chain_role", ""))
		var trigger := str(card_meta.get("followup_trigger", ""))
		if opener_id.is_empty() and (role == "opener" or trigger.is_empty()):
			opener_id = str(card_meta.get("card_id", card_meta.get("id", "")))
		elif finisher_id.is_empty() and trigger == "same_weapon_previous_card":
			finisher_id = str(card_meta.get("card_id", card_meta.get("id", "")))
	if opener_id.is_empty() or finisher_id.is_empty():
		return
	var opener_card: CardData = _find_runtime_card(enemy, opener_id)
	var finisher_card: CardData = _find_runtime_card(enemy, finisher_id)
	if opener_card == null or finisher_card == null:
		return
	node.call("_apply_weapon_followup_runtime", enemy, player, opener_card, "enemy", {"connected": true})
	node.call("_apply_weapon_followup_runtime", enemy, player, finisher_card, "enemy", {"connected": true})

func _find_runtime_card(fighter, card_id: String) -> CardData:
	for source in [fighter.hand, fighter.draw_pile, fighter.discard_pile]:
		for card_variant in source:
			if card_variant is CardData and str(card_variant.id) == card_id:
				return card_variant
	return null

func _write_report(report: Dictionary) -> void:
	var file := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(report, "\t"))

func _classify_card(card: CardData) -> String:
	if card.is_guard_card():
		return "guard"
	if card.is_feint_card():
		return "feint"
	return "attack"
	'''.replace("__REPORT_PATH__", report_json_path.as_posix())


def read_json(path: Path) -> Any:
    return json.loads(path.read_text(encoding="utf-8"))


def write_markdown(path: Path, report: dict[str, Any]) -> None:
    lines = [
        "# Weapon Followup Probe",
        "",
        f"- profile_declares_weapon_followup: {str(report['profile_declares_weapon_followup']).lower()}",
        f"- generated_sequence_uses_weapon_followup: {str(report['generated_sequence_uses_weapon_followup']).lower()}",
        f"- followup_cards_generated: {str(report['followup_cards_generated']).lower()}",
        f"- followup_decks_generated: {str(report['followup_decks_generated']).lower()}",
        f"- followup_chain_valid: {str(report['followup_chain_valid']).lower()}",
        f"- manifest_exports_followup: {str(report['manifest_exports_followup']).lower()}",
        f"- godot_loader_reads_followup: {str(report['godot_loader_reads_followup']).lower()}",
        f"- battle_shows_followup_effect: {str(report['battle_shows_followup_effect']).lower()}",
        f"- weapon_followup_trigger_count: {report['weapon_followup_trigger_count']}",
        f"- fallback_loadout_count: {report['fallback_loadout_count']}",
        f"- probe_pass: {str(report['probe_pass']).lower()}",
    ]
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
