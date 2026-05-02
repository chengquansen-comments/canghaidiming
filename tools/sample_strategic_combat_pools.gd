extends SceneTree

const AutoBattleSampler := preload("res://scripts/auto_battle_sampler.gd")
const HotTuningController := preload("res://scripts/battle_controller_visual_hot_tuning.gd")
const StoryBattleLoader := preload("res://scripts/story_battle_loader.gd")
const StrategicMapState := preload("res://scripts/strategic_map_state.gd")

const STRATEGIC_MAP_PATH := "res://data/strategic_map.json"

var samples := 40
var seed := 260501
var report_path := "res://reports/strategic_combat_pool_report.json"
var player_role := "spearman"
var pool_filter := ""
var print_all := false


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
	var strategic_config := _read_json_dict(STRATEGIC_MAP_PATH)
	if strategic_config.is_empty():
		push_error("strategic_map.json missing or empty")
		quit(1)
		return
	var report := _sample_pools(strategic_config, card_catalog)
	_print_report(report)
	_save_json(report_path, report)
	root.remove_child(controller)
	controller.free()
	quit(0)


func _parse_args() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--samples="):
			samples = maxi(5, int(arg.get_slice("=", 1)))
		elif arg.begins_with("--seed="):
			seed = int(arg.get_slice("=", 1))
		elif arg.begins_with("--report="):
			report_path = arg.get_slice("=", 1)
		elif arg.begins_with("--player-role="):
			player_role = arg.get_slice("=", 1)
		elif arg.begins_with("--pool="):
			pool_filter = arg.get_slice("=", 1)
		elif arg == "--print-all":
			print_all = true


func _sample_pools(config: Dictionary, card_catalog: Dictionary) -> Dictionary:
	var pools: Dictionary = config.get("combat_enemy_pools", {})
	var targets: Dictionary = config.get("combat_balance_targets", {})
	var stats_by_level: Dictionary = config.get("enemy_martial_stats", {})
	var rows: Array[Dictionary] = []
	var summary: Dictionary = {}
	var row_index := 0
	for pool_id in pools.keys():
		var combat_pool_id := str(pool_id)
		if not pool_filter.is_empty() and combat_pool_id != pool_filter:
			continue
		var entries: Array = pools.get(combat_pool_id, [])
		for entry_variant in entries:
			if not (entry_variant is Dictionary):
				continue
			var entry: Dictionary = entry_variant
			for player_martial in range(1, 11):
				for enemy_martial in range(1, 11):
					if enemy_martial < int(entry.get("martial_min", 1)) or enemy_martial > int(entry.get("martial_max", 10)):
						continue
					var enemy_stats := _enemy_stats_for_entry(stats_by_level, entry, enemy_martial)
					if enemy_stats.is_empty():
						continue
					var result := _sample_entry(card_catalog, entry, player_martial, enemy_martial, enemy_stats, row_index)
					row_index += 1
					var player_numbers := StrategicMapState.player_numbers_for_martial(player_martial)
					var target := _target_for_delta(targets, combat_pool_id, player_martial - enemy_martial)
					var judgment := _judge_result(result, target, player_numbers)
					var row := {
						"combat_pool_id": combat_pool_id,
						"enemy_pool_entry": str(entry.get("pool_entry_id", "")),
						"player_role": player_role,
						"player_martial_level": player_martial,
						"enemy_martial_level": enemy_martial,
						"player_hp": int(player_numbers.get("max_hp", 20)),
						"player_qinggong": int(player_numbers.get("qinggong", 1)),
						"player_max_posture": int(player_numbers.get("max_posture", 3)),
						"enemy_hp": int(enemy_stats.get("max_hp", 1)),
						"enemy_qinggong": int(enemy_stats.get("qinggong", 1)),
						"enemy_max_posture": int(enemy_stats.get("max_momentum", 1)),
						"enemy_start_posture": int(enemy_stats.get("starting_momentum", 0)),
						"enemy_template_id": str(entry.get("opponent_template_id", "")),
						"enemy_deck_id": str(entry.get("opponent_deck_id", "")),
						"difficulty_role": str(target.get("difficulty_role", "未定义")),
						"target": target,
						"sample": result,
						"recommendation": judgment,
					}
					rows.append(row)
					_record_summary(summary, combat_pool_id, judgment, result)
	_finalize_summary(summary)
	return {
		"samples": samples,
		"seed": seed,
		"player_role": player_role,
		"pool_filter": pool_filter,
		"row_count": rows.size(),
		"summary": summary,
		"rows": rows,
	}


func _sample_entry(card_catalog: Dictionary, entry: Dictionary, player_martial: int, enemy_martial: int, enemy_stats: Dictionary, row_index: int) -> Dictionary:
	var player_data = _player_fighter_for_martial(card_catalog, player_martial)
	var enemy_data = StoryBattleLoader.build_fighter_data(
		str(entry.get("opponent_template_id", "")),
		str(entry.get("opponent_deck_id", "")),
		"normal",
		card_catalog,
		false
	)
	if enemy_data == null or player_data == null:
		return {}
	enemy_data.display_name = str(entry.get("display_name", enemy_data.display_name))
	enemy_data.max_hp = int(enemy_stats.get("max_hp", enemy_data.max_hp))
	enemy_data.max_momentum = int(enemy_stats.get("max_momentum", enemy_data.max_momentum))
	enemy_data.starting_momentum = int(enemy_stats.get("starting_momentum", enemy_data.starting_momentum))
	enemy_data.qinggong = int(enemy_stats.get("qinggong", enemy_data.qinggong))
	enemy_data.starting_realm = enemy_martial
	return AutoBattleSampler.run_batch(player_data.starting_deck, enemy_data.starting_deck, {
		"sample_count": samples,
		"seed": seed + row_index * 977,
		"max_turns": 24,
		"settlement_mode": AutoBattleSampler.MODE_REACTIVE_ID,
		"pressure_profile": AutoBattleSampler.PRESSURE_NONE,
		"player_label": player_data.display_name,
		"enemy_label": enemy_data.display_name,
		"player_state": _sampler_state(player_data, true),
		"enemy_state": _sampler_state(enemy_data, false),
		"player_preferred": _preferred_array(player_data.preferred_distances, _style_for_weapon(player_data.weapon_name)),
		"enemy_preferred": _preferred_array(enemy_data.preferred_distances, _style_for_weapon(enemy_data.weapon_name)),
	})


func _player_fighter_for_martial(card_catalog: Dictionary, martial_level: int):
	var template_id := "player_blademaster" if player_role == "blademaster" else "player_spearman"
	var deck_id := "player_blade_start" if player_role == "blademaster" else "player_spear_start"
	var data = StoryBattleLoader.build_fighter_data(template_id, deck_id, "player_start", card_catalog, true)
	if data == null:
		return null
	var numbers := StrategicMapState.player_numbers_for_martial(martial_level)
	data.max_hp = int(numbers.get("max_hp", data.max_hp))
	data.max_momentum = int(numbers.get("max_posture", data.max_momentum))
	data.starting_momentum = int(numbers.get("posture", data.starting_momentum))
	data.qinggong = int(numbers.get("qinggong", data.qinggong))
	data.starting_realm = martial_level
	data.starting_deck = _default_loadout_deck_for_role(player_role, card_catalog)
	return data


func _enemy_stats_for_entry(stats_by_level: Dictionary, entry: Dictionary, martial_level: int) -> Dictionary:
	var base: Dictionary = stats_by_level.get(str(martial_level), {})
	if base.is_empty():
		return {}
	var max_momentum := maxi(1, int(base.get("max_momentum", 1)) + int(entry.get("max_momentum_bonus", 0)))
	return {
		"max_hp": maxi(1, int(base.get("max_hp", 1)) + int(entry.get("hp_bonus", 0))),
		"max_momentum": max_momentum,
		"starting_momentum": clampi(int(base.get("starting_momentum", 0)) + int(entry.get("starting_momentum_bonus", 0)), 0, max_momentum),
		"qinggong": maxi(1, int(base.get("qinggong", 1)) + int(entry.get("qinggong_bonus", 0))),
	}


func _target_for_delta(targets: Dictionary, combat_pool_id: String, delta: int) -> Dictionary:
	var rows: Array = targets.get(combat_pool_id, [])
	for item in rows:
		if not (item is Dictionary):
			continue
		var target: Dictionary = item
		if delta >= int(target.get("player_martial_delta_min", 0)) and delta <= int(target.get("player_martial_delta_max", 0)):
			return target
	return {}


func _judge_result(result: Dictionary, target: Dictionary, player_numbers: Dictionary) -> String:
	if result.is_empty():
		return "无样本"
	if target.is_empty():
		return "未定义"
	var win_rate := float(result.get("player_win_rate", 0.0))
	var hp_fraction := 0.0
	var player_hp := float(player_numbers.get("max_hp", 1))
	if player_hp > 0.0:
		hp_fraction = float(result.get("avg_player_hp", 0.0)) / player_hp
	var turns := float(result.get("avg_turns", 0.0))
	if win_rate < float(target.get("target_win_rate_min", 0.0)) or hp_fraction < float(target.get("target_avg_player_hp_remaining_min", 0.0)):
		return "过难"
	if win_rate > float(target.get("target_win_rate_max", 1.0)) or hp_fraction > float(target.get("target_avg_player_hp_remaining_max", 1.0)):
		return "过易"
	if turns < float(target.get("target_turns_min", 0.0)):
		return "过易"
	if turns > float(target.get("target_turns_max", 99.0)):
		return "过难"
	return "合理"


func _record_summary(summary: Dictionary, combat_pool_id: String, judgment: String, result: Dictionary) -> void:
	if not summary.has(combat_pool_id):
		summary[combat_pool_id] = {"rows": 0, "过易": 0, "合理": 0, "过难": 0, "未定义": 0, "无样本": 0, "win_total": 0.0, "turn_total": 0.0}
	var item: Dictionary = summary[combat_pool_id]
	item["rows"] = int(item.get("rows", 0)) + 1
	item[judgment] = int(item.get(judgment, 0)) + 1
	item["win_total"] = float(item.get("win_total", 0.0)) + float(result.get("player_win_rate", 0.0))
	item["turn_total"] = float(item.get("turn_total", 0.0)) + float(result.get("avg_turns", 0.0))


func _finalize_summary(summary: Dictionary) -> void:
	for key in summary.keys():
		var item: Dictionary = summary[key]
		var rows := maxi(1, int(item.get("rows", 0)))
		item["avg_win_rate"] = float(item.get("win_total", 0.0)) / float(rows)
		item["avg_turns"] = float(item.get("turn_total", 0.0)) / float(rows)


func _sampler_state(data, is_player: bool) -> Dictionary:
	return {
		"hp": data.max_hp,
		"max_momentum": data.max_momentum,
		"momentum": data.starting_momentum,
		"realm": data.starting_realm,
		"qinggong": maxi(1, data.qinggong),
		"position": data.starting_position if data.starting_position >= 0 else 2 if is_player else 6,
		"facing": data.starting_facing if data.starting_facing != "" else "right" if is_player else "left",
		"style": _style_for_weapon(data.weapon_name),
	}


func _style_for_weapon(weapon_name: String) -> String:
	if weapon_name.findn("枪") >= 0 or weapon_name.findn("spear") >= 0:
		return "spear"
	return "blade"


func _preferred_array(values: PackedInt32Array, style: String) -> Array:
	var out: Array = []
	for value in values:
		out.append(int(value))
	if out.is_empty():
		return [3, 4, 5] if style == "spear" else [0, 1, 2]
	return out


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


func _print_report(report: Dictionary) -> void:
	print("strategic combat pool sample samples=%d seed=%d role=%s rows=%d report=%s" % [samples, seed, player_role, int(report.get("row_count", 0)), report_path])
	var summary: Dictionary = report.get("summary", {})
	for pool_id in summary.keys():
		var item: Dictionary = summary[pool_id]
		print("%-18s rows %3d  合理 %3d  过易 %3d  过难 %3d  未定义 %3d  avg_win %.0f%%  avg_turn %.1f" % [
			str(pool_id),
			int(item.get("rows", 0)),
			int(item.get("合理", 0)),
			int(item.get("过易", 0)),
			int(item.get("过难", 0)),
			int(item.get("未定义", 0)),
			float(item.get("avg_win_rate", 0.0)) * 100.0,
			float(item.get("avg_turns", 0.0)),
		])
	var printed := 0
	for row: Dictionary in report.get("rows", []):
		if not print_all and printed >= 24:
			break
		print("%s/%s P%d vs E%d  P[%dHP Q%d M%d] E[%dHP Q%d M%d/%d] %s/%s win %.0f%% hp %.1f turn %.1f => %s" % [
			str(row.get("combat_pool_id", "")),
			str(row.get("enemy_pool_entry", "")),
			int(row.get("player_martial_level", 0)),
			int(row.get("enemy_martial_level", 0)),
			int(row.get("player_hp", 0)),
			int(row.get("player_qinggong", 0)),
			int(row.get("player_max_posture", 0)),
			int(row.get("enemy_hp", 0)),
			int(row.get("enemy_qinggong", 0)),
			int(row.get("enemy_start_posture", 0)),
			int(row.get("enemy_max_posture", 0)),
			str(row.get("enemy_template_id", "")),
			str(row.get("enemy_deck_id", "")),
			float(row.get("sample", {}).get("player_win_rate", 0.0)) * 100.0,
			float(row.get("sample", {}).get("avg_player_hp", 0.0)),
			float(row.get("sample", {}).get("avg_turns", 0.0)),
			str(row.get("recommendation", "")),
		])
		printed += 1
	if not print_all and int(report.get("row_count", 0)) > printed:
		print("... remaining rows saved to %s; pass --print-all to print every row" % report_path)


func _read_json_dict(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	return parsed if parsed is Dictionary else {}


func _save_json(path: String, payload: Dictionary) -> void:
	var dir := path.get_base_dir()
	if dir != "" and not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(dir)):
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(payload, "\t"))
