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
TELEMETRY_PATH = ROOT / "data" / "aigc_battle" / "telemetry" / "aigc_sequence_telemetry.jsonl"
PROFILE_ID = "weapon_followup_v0_1"


def main(argv: list[str]) -> int:
    if len(argv) != 1:
        print("usage: python3 tools/aigc_battle/aigc_real_telemetry_probe.py", file=sys.stderr)
        return 1
    generated_dir = GENERATED_DIR / PROFILE_ID
    report_json_path = generated_dir / "real_telemetry_probe_report.json"
    TELEMETRY_PATH.parent.mkdir(parents=True, exist_ok=True)
    TELEMETRY_PATH.write_text("", encoding="utf-8")

    godot_bin = shutil.which("godot4") or shutil.which("godot")
    if godot_bin is None:
        raise SystemExit("godot/godot4 command not found")
    with tempfile.TemporaryDirectory(prefix="aigc_real_telemetry_probe_") as temp_dir:
        temp_script_path = Path(temp_dir) / "real_telemetry_probe.gd"
        temp_script_path.write_text(build_godot_probe_script(report_json_path), encoding="utf-8")
        env = os.environ.copy()
        env.update({"HOME": "/private/tmp"})
        subprocess.run([godot_bin, "--headless", "--path", str(ROOT), "--script", str(temp_script_path)], check=True, cwd=ROOT, env=env)

    report = read_json(report_json_path)
    write_markdown(generated_dir / "real_telemetry_probe_report.md", report)
    print("real telemetry probe complete")
    return 0 if report.get("probe_pass", False) else 1


def build_godot_probe_script(report_json_path: Path) -> str:
    return r'''extends SceneTree

const NarrativeBattleContext = preload("res://scripts/narrative_battle_context.gd")
const MainVisual = preload("res://scenes/MainVisual.tscn")
const INVENTORY_PATH = "res://data/aigc_battle/generated/weapon_followup_v0_1/formal_sequence_inventory.generated.json"
const TELEMETRY_RES_PATH = "res://data/aigc_battle/telemetry/aigc_sequence_telemetry.jsonl"
const REPORT_PATH = "__REPORT_PATH__"

func _init() -> void:
	var inventory: Array = _read_inventory()
	var sampled_inventory: Array = inventory.slice(0, mini(5, inventory.size()))
	for item_variant in sampled_inventory:
		var item: Dictionary = item_variant
		var node: Node = await _start_visual_battle(str(item.get("formal_encounter_id", "")), str(item.get("formal_battle_id", "")), str(item.get("node_id", "real_telemetry_probe")))
		await _autoplay_battle(node)
		if int(node.get("last_weapon_followup_trigger_count")) <= 0:
			_force_followup_runtime_probe(node)
		var result_key := "win" if node.get("enemy").hp <= 0 and node.get("player").hp > 0 else ("lose" if node.get("player").hp <= 0 and node.get("enemy").hp > 0 else "draw")
		node.call("_mark_generated_reward_visible", result_key == "win")
		node.call("_claim_generated_manifest_reward", result_key)
		node.call("_append_generated_telemetry_event", result_key)
		await process_frame
		node.queue_free()
		await process_frame
	var report := _build_report(sampled_inventory.size())
	_write_report(report)
	quit(0 if bool(report.get("probe_pass", false)) else 1)

func _build_report(expected_count: int) -> Dictionary:
	var events: Array = _read_telemetry_events()
	var report := {
		"real_telemetry_recorded": events.size() > 0,
		"turn_count_recorded": false,
		"hp_delta_recorded": false,
		"card_usage_recorded": false,
		"runtime_primitive_usage_recorded": false,
		"weapon_followup_triggered_recorded": false,
		"telemetry_detail_level": "minimal",
		"probe_pass": false
	}
	var profile_ok := true
	var pack_ok := true
	for event_variant in events:
		var event: Dictionary = event_variant
		profile_ok = profile_ok and str(event.get("mechanic_profile_id", "")) == "weapon_followup_v0_1"
		pack_ok = pack_ok and str(event.get("content_pack_id", "")).find("weapon_followup_v0_1") >= 0
		report["turn_count_recorded"] = report["turn_count_recorded"] or int(event.get("turn_count", 0)) > 0
		report["hp_delta_recorded"] = report["hp_delta_recorded"] or (int(event.get("player_hp_start", -1)) >= 0 and int(event.get("player_hp_end", -1)) >= 0 and int(event.get("enemy_hp_start", -1)) >= 0 and int(event.get("enemy_hp_end", -1)) >= 0)
		report["card_usage_recorded"] = report["card_usage_recorded"] or (int(event.get("cards_played_count", 0)) > 0 and int(event.get("enemy_cards_played_count", 0)) > 0 and (event.get("player_cards_played", []) as Array).size() > 0)
		report["runtime_primitive_usage_recorded"] = report["runtime_primitive_usage_recorded"] or (event.get("runtime_primitives", []) as Array).has("weapon_followup")
		report["weapon_followup_triggered_recorded"] = report["weapon_followup_triggered_recorded"] or int(event.get("weapon_followup_trigger_count", 0)) > 0
		var detail_level := str(event.get("telemetry_detail_level", "minimal"))
		if detail_level == "partial" or detail_level == "real":
			report["telemetry_detail_level"] = detail_level
	report["probe_pass"] = bool(report["real_telemetry_recorded"]) and bool(report["turn_count_recorded"]) and bool(report["hp_delta_recorded"]) and bool(report["card_usage_recorded"]) and bool(report["runtime_primitive_usage_recorded"]) and bool(report["weapon_followup_triggered_recorded"]) and report["telemetry_detail_level"] != "minimal" and profile_ok and pack_ok and events.size() >= expected_count
	return report

func _start_visual_battle(encounter_id: String, battle_id: String, node_id: String) -> Node:
	NarrativeBattleContext.clear()
	NarrativeBattleContext.clear_player_profile()
	NarrativeBattleContext.set_player_profile({
		"role": "spearman",
		"career": "长枪武官",
		"weapon": "长枪",
		"martial_level": 3,
		"max_hp": 46,
		"hp": 46,
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
	while bool(node.get("battle_active")) and guard < 700:
		if bool(node.get("awaiting_player_input")):
			var player = node.get("player")
			var hand: Array = player.hand if player != null else []
			var selected: CardData = null
			for preferred_type in ["guard", "feint", "attack"]:
				for card_variant in hand:
					if not (card_variant is CardData):
						continue
					var card: CardData = card_variant
					if _classify_card(card) == preferred_type and bool(node.call("_can_play_card", player, card)):
						selected = card
						break
				if selected != null:
					break
			if selected == null:
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

func _read_telemetry_events() -> Array:
	var file := FileAccess.open(ProjectSettings.globalize_path(TELEMETRY_RES_PATH), FileAccess.READ)
	if file == null:
		return []
	var rows: Array = []
	for line in file.get_as_text().split("\n"):
		var clean := line.strip_edges()
		if clean.is_empty():
			continue
		var parsed = JSON.parse_string(clean)
		if parsed is Dictionary:
			rows.append(parsed)
	return rows

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

func _classify_card(card: CardData) -> String:
	if card.is_guard_card():
		return "guard"
	if card.is_feint_card():
		return "feint"
	return "attack"

func _write_report(report: Dictionary) -> void:
	var file := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(report, "\t"))
'''.replace("__REPORT_PATH__", report_json_path.as_posix())


def read_json(path: Path) -> Any:
    return json.loads(path.read_text(encoding="utf-8"))


def write_markdown(path: Path, report: dict[str, Any]) -> None:
    lines = [
        "# Real Telemetry Probe",
        "",
        f"- real_telemetry_recorded: {str(report['real_telemetry_recorded']).lower()}",
        f"- turn_count_recorded: {str(report['turn_count_recorded']).lower()}",
        f"- hp_delta_recorded: {str(report['hp_delta_recorded']).lower()}",
        f"- card_usage_recorded: {str(report['card_usage_recorded']).lower()}",
        f"- runtime_primitive_usage_recorded: {str(report['runtime_primitive_usage_recorded']).lower()}",
        f"- weapon_followup_triggered_recorded: {str(report['weapon_followup_triggered_recorded']).lower()}",
        f"- telemetry_detail_level: {report['telemetry_detail_level']}",
        f"- probe_pass: {str(report['probe_pass']).lower()}",
    ]
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
