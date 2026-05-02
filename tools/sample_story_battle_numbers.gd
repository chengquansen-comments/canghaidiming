extends SceneTree

const AutoBattleSampler = preload("res://scripts/auto_battle_sampler.gd")
const HotTuningController = preload("res://scripts/battle_controller_visual_hot_tuning.gd")
const StoryBattleLoader = preload("res://scripts/story_battle_loader.gd")
const StrategicMapState = preload("res://scripts/strategic_map_state.gd")

var samples := 120
var seed := 260430
var report_path := "res://reports/story_battle_number_report.json"
var profile_mode := "narrative_progression"
var player_role := "spearman"
var sequence := "all"


func _init() -> void:
	_parse_args()
	var controller: Node = HotTuningController.new()
	root.add_child(controller)
	await process_frame
	var card_catalog: Dictionary = StoryBattleLoader.build_card_catalog(controller.get("fighter_catalog"), controller.get("reward_pool"))
	var validation := StoryBattleLoader.validate_all(card_catalog)
	if not bool(validation.get("ok", false)):
		print(StoryBattleLoader.format_validation_report(validation))
		quit(1)
		return
	var report := _sample_story_encounters(card_catalog)
	_print_report(report)
	_save_json(report_path, report)
	root.remove_child(controller)
	controller.free()
	quit(0)


func _parse_args() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--samples="):
			samples = maxi(10, int(arg.get_slice("=", 1)))
		elif arg.begins_with("--seed="):
			seed = int(arg.get_slice("=", 1))
		elif arg.begins_with("--report="):
			report_path = arg.get_slice("=", 1)
		elif arg.begins_with("--profile-mode="):
			profile_mode = arg.get_slice("=", 1)
		elif arg.begins_with("--player-role="):
			player_role = arg.get_slice("=", 1)
		elif arg.begins_with("--sequence="):
			sequence = arg.get_slice("=", 1)


func _sample_story_encounters(card_catalog: Dictionary) -> Dictionary:
	var entries: Array[Dictionary] = []
	var encounters := _encounters_for_sequence()
	var profile := _initial_player_profile(player_role)
	for i in range(encounters.size()):
		var encounter: Dictionary = encounters[i]
		var encounter_id := str(encounter.get("encounter_id", ""))
		if encounter_id == "":
			continue
		var story_battle := StoryBattleLoader.build_story_battle(encounter_id, card_catalog)
		if story_battle.is_empty():
			continue
		var player_data = story_battle.get("player_data")
		var enemy_data = story_battle.get("opponent_data")
		var sample_player_data = player_data
		if _should_apply_narrative_profile(encounter_id):
			sample_player_data = _fighter_data_for_profile(profile, card_catalog)
		var result := AutoBattleSampler.run_batch(sample_player_data.starting_deck, enemy_data.starting_deck, {
			"sample_count": samples,
			"seed": seed + i * 997,
			"max_turns": 24,
			"settlement_mode": str(story_battle.get("settlement_mode", "reactive")),
			"pressure_profile": str(encounter.get("pressure_profile", "none")),
			"player_label": sample_player_data.display_name,
			"enemy_label": enemy_data.display_name,
			"player_state": _sampler_state(sample_player_data, true),
			"enemy_state": _sampler_state(enemy_data, false),
			"player_preferred": _preferred_array(sample_player_data.preferred_distances, _style_for_weapon(sample_player_data.weapon_name)),
			"enemy_preferred": _preferred_array(enemy_data.preferred_distances, _style_for_weapon(enemy_data.weapon_name))
		})
		entries.append({
			"encounter_id": encounter_id,
			"display_name": str(encounter.get("display_name", encounter_id)),
			"player_template_id": str(encounter.get("player_template_id", "")),
			"opponent_template_id": str(encounter.get("opponent_template_id", "")),
			"player_stat_set_id": str(encounter.get("player_stat_set_id", "")),
			"opponent_stat_set_id": str(encounter.get("opponent_stat_set_id", "")),
			"player_deck_id": str(encounter.get("player_deck_id", "")),
			"opponent_deck_id": str(encounter.get("opponent_deck_id", "")),
			"settlement_mode": str(story_battle.get("settlement_mode", "reactive")),
			"pressure_profile": str(encounter.get("pressure_profile", "none")),
			"profile_mode": profile_mode,
			"profile_before": profile.duplicate(true) if _should_apply_narrative_profile(encounter_id) else {},
			"sample": result,
			"conclusion": AutoBattleSampler.format_balance_conclusion(result)
		})
		if profile_mode == "narrative_progression" and _should_apply_narrative_profile(encounter_id):
			_apply_profile_growth(profile, encounter_id)
	return {
		"samples": samples,
		"seed": seed,
		"profile_mode": profile_mode,
		"player_role": player_role,
		"sequence": sequence,
		"entry_count": entries.size(),
		"entries": entries
	}


func _sampler_state(data, is_player: bool) -> Dictionary:
	return {
		"hp": data.max_hp,
		"max_momentum": data.max_momentum,
		"momentum": data.starting_momentum,
		"realm": data.starting_realm,
		"qinggong": maxi(1, data.qinggong),
		"position": data.starting_position if data.starting_position >= 0 else 2 if is_player else 6,
		"facing": data.starting_facing if data.starting_facing != "" else "right" if is_player else "left",
		"style": _style_for_weapon(data.weapon_name)
	}


func _should_apply_narrative_profile(encounter_id: String) -> bool:
	if profile_mode == "story_table":
		return false
	if encounter_id == "enc_prologue_master_rescue":
		return false
	if not encounter_id.begins_with("enc_"):
		return false
	if encounter_id == "fallback":
		return false
	return true


func _initial_player_profile(role_id: String) -> Dictionary:
	var numbers := StrategicMapState.player_numbers_for_martial(1)
	if role_id == "blademaster":
		return {"role": "blademaster", "career": "腰刀武官", "weapon": "腰刀", "max_hp": int(numbers.get("max_hp", 20)), "hp": int(numbers.get("hp", 20)), "max_posture": int(numbers.get("max_posture", 3)), "posture": int(numbers.get("posture", 3)), "qinggong": int(numbers.get("qinggong", 1)), "martial_level": 1, "battles_won": 0}
	return {"role": "spearman", "career": "长枪武官", "weapon": "长枪", "max_hp": int(numbers.get("max_hp", 20)), "hp": int(numbers.get("hp", 20)), "max_posture": int(numbers.get("max_posture", 3)), "posture": int(numbers.get("posture", 3)), "qinggong": int(numbers.get("qinggong", 1)), "martial_level": 1, "battles_won": 0}


func _fighter_data_for_profile(profile: Dictionary, card_catalog: Dictionary):
	var role_id := str(profile.get("role", "spearman"))
	var template_id := "player_blademaster" if role_id == "blademaster" else "player_spearman"
	var deck_id := _player_deck_id_for_profile(role_id, profile)
	var data = StoryBattleLoader.build_fighter_data(template_id, deck_id, "player_start", card_catalog, true)
	data.display_name = str(profile.get("career", data.display_name))
	data.weapon_name = str(profile.get("weapon", data.weapon_name))
	data.max_hp = int(profile.get("max_hp", data.max_hp))
	data.max_momentum = int(profile.get("max_posture", data.max_momentum))
	data.starting_momentum = clampi(int(profile.get("posture", data.starting_momentum)), 0, data.max_momentum)
	data.starting_realm = int(profile.get("martial_level", data.starting_realm))
	data.qinggong = int(profile.get("qinggong", data.qinggong))
	data.starting_deck = _default_loadout_deck_for_role(role_id, card_catalog)
	return data


func _apply_profile_growth(profile: Dictionary, encounter_id: String) -> void:
	var reward := _growth_for_encounter(encounter_id)
	profile["martial_level"] = int(profile.get("martial_level", 1)) + 1 + int(reward.get("martial_gain", 0))
	profile["battles_won"] = int(profile.get("battles_won", 0)) + 1
	var numbers := StrategicMapState.player_numbers_for_martial(int(profile.get("martial_level", 1)))
	profile["max_hp"] = int(numbers.get("max_hp", 1)) + int(reward.get("hp_gain", 0))
	profile["max_posture"] = int(numbers.get("max_posture", 1)) + int(reward.get("posture_gain", 0))
	profile["qinggong"] = int(numbers.get("qinggong", 1))
	if bool(reward.get("heal_full", true)):
		profile["hp"] = int(profile.get("max_hp", 1))
		profile["posture"] = int(profile.get("max_posture", 1))
	else:
		profile["hp"] = mini(int(profile.get("max_hp", 1)), int(profile.get("hp", 1)) + int(reward.get("hp_gain", 0)))
		profile["posture"] = mini(int(profile.get("max_posture", 1)), int(profile.get("posture", 1)) + int(reward.get("posture_gain", 0)))


func _growth_for_encounter(encounter_id: String) -> Dictionary:
	match encounter_id:
		"enc_beach_ambush":
			return {"hp_gain": 0, "posture_gain": 0, "martial_gain": 0, "heal_full": true}
		"enc_transport_officer":
			return {"hp_gain": 1, "posture_gain": 1, "martial_gain": 0, "heal_full": true}
		"enc_wakou_boss", "enc_boss_ext_wakou_leader":
			return {"hp_gain": 1, "posture_gain": 1, "martial_gain": 0, "heal_full": true}
		_:
			return {"hp_gain": 0, "posture_gain": 0, "martial_gain": 0, "heal_full": true}


func _player_deck_id_for_profile(role_id: String, profile: Dictionary) -> String:
	var wins := int(profile.get("battles_won", 0))
	if role_id == "spearman":
		return "player_spear_advanced" if wins >= 6 else "player_spear_start"
	return "player_blade_start"


func _default_loadout_deck_for_role(role_id: String, card_catalog: Dictionary) -> Array[CardData]:
	var ids := PackedStringArray()
	if role_id == "blademaster":
		ids = PackedStringArray(["blade_front_cut", "blade_front_cut", "blade_chase_cut", "blade_chase_cut", "blade_breathe", "blade_breathe", "blade_press_break", "blade_press_break"])
	else:
		ids = PackedStringArray(["spear_mid_thrust", "spear_mid_thrust", "spear_line_press", "spear_line_press", "spear_focus", "spear_focus", "spear_guard_horse", "spear_guard_horse"])
	var result: Array[CardData] = []
	for id in ids:
		var card = card_catalog.get(str(id), null)
		if card is CardData:
			result.append((card as CardData).duplicate_card())
	return result


func _encounters_for_sequence() -> Array[Dictionary]:
	var all := StoryBattleLoader.load_encounters()
	if sequence != "linear_intro":
		return all
	var ids := PackedStringArray([
		"enc_beach_ambush",
		"enc_fishing_village_embers",
		"enc_transport_officer",
		"enc_wakou_boss"
	])
	var by_id := {}
	for encounter: Dictionary in all:
		by_id[str(encounter.get("encounter_id", ""))] = encounter
	var out: Array[Dictionary] = []
	for id in ids:
		if by_id.has(id):
			out.append(by_id[id])
	return out


func _style_for_weapon(weapon_name: String) -> String:
	if weapon_name.findn("枪") >= 0 or weapon_name.findn("spear") >= 0:
		return "spear"
	return "blade"


func _preferred_array(values: PackedInt32Array, style: String) -> Array[int]:
	var out: Array[int] = []
	for value in values:
		out.append(int(value))
	if out.is_empty():
		return [3, 4, 5] if style == "spear" else [0, 1, 2]
	return out


func _print_report(report: Dictionary) -> void:
	print("story battle number report samples=%d seed=%d entries=%d profile=%s role=%s sequence=%s" % [samples, seed, int(report.get("entry_count", 0)), profile_mode, player_role, sequence])
	for entry: Dictionary in report.get("entries", []):
		var sample: Dictionary = entry.get("sample", {})
		print("%-30s %-12s win %.0f%% enemy %.0f%% turn %.1f hp %.1f/%.1f %s" % [
			str(entry.get("encounter_id", "")),
			str(entry.get("pressure_profile", "")),
			float(sample.get("player_win_rate", 0.0)) * 100.0,
			float(sample.get("enemy_win_rate", 0.0)) * 100.0,
			float(sample.get("avg_turns", 0.0)),
			float(sample.get("avg_player_hp", 0.0)),
			float(sample.get("avg_enemy_hp", 0.0)),
			str(entry.get("conclusion", ""))
		])


func _save_json(path: String, payload: Dictionary) -> void:
	var dir := path.get_base_dir()
	if dir != "" and not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(dir)):
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(payload, "\t"))
