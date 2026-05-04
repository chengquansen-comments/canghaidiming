extends "res://scripts/battle_controller_visual_hot_tuning_profile_snapshot.gd"

# Extracted hot tuning profile formatting layer.

func _refresh_tuning_panel() -> void:
	super()
	if tuning_label == null:
		return
	tuning_label.text += "\n[b]实时调参[/b]\n"
	tuning_label.text += "当前目标: %s\n" % str(_selected_generation_target().get("label", "均衡"))
	tuning_label.text += "\n[b]战斗采样[/b]\n"
	tuning_label.text += _format_sampler_binding()
	tuning_label.text += _last_sample_report
	tuning_label.text += "\n\n[b]数值方案[/b]\n"
	tuning_label.text += _number_config_status + "\n"
	tuning_label.text += _format_active_number_config()

func _format_active_number_config() -> String:
	if _active_number_config_index < 0 or _active_number_config_index >= _number_configs.size():
		return "当前未选中方案\n"
	var config: Dictionary = _number_configs[_active_number_config_index]
	var sample: Dictionary = config.get("sample", {})
	var lines: Array[String] = []
	lines.append("选中：%s" % str(config.get("name", "方案")))
	lines.append("来源：%s｜%s" % [str(config.get("encounter_id", "current")), _profile_store_label()])
	var target: Dictionary = config.get("target", {})
	if not target.is_empty():
		lines.append("目标：%s  胜率%.0f%%  回合%.1f" % [str(target.get("label", "目标")), float(target.get("player_win_rate", 0.0)) * 100.0, float(target.get("turn_target", 0.0))])
	if not sample.is_empty():
		lines.append("采样：%s胜 %.1f%% / %s胜 %.1f%% / 平 %.1f%% / %.1f回合" % [
			_fighter_label(player, "玩家"),
			float(sample.get("player_win_rate", 0.0)) * 100.0,
			_fighter_label(enemy, "敌人"),
			float(sample.get("enemy_win_rate", 0.0)) * 100.0,
			float(sample.get("draw_rate", 0.0)) * 100.0,
			float(sample.get("avg_turns", 0.0))
		])
	var diff: Array = config.get("diff", [])
	if diff.is_empty():
		lines.append("改动：无")
	else:
		lines.append("改动：%s" % "；".join(diff.slice(0, 5)))
	lines.append("我方卡组：%s" % _format_deck_summary(config.get("player_deck", [])))
	lines.append("敌方卡组：%s" % _format_deck_summary(config.get("enemy_deck", [])))
	return "\n".join(lines) + "\n"

func _format_sampler_binding() -> String:
	if player == null or enemy == null or player.data == null or enemy.data == null:
		return "采样绑定：未进入当前战斗\n"
	var source := "选中方案" if _active_number_config_index >= 0 and _active_number_config_index < _number_configs.size() else "当前战斗"
	return "采样绑定[%s]：%s HP%d 势%d/%d 武境%d 轻功%d 牌%d  vs  %s HP%d 势%d/%d 武境%d 轻功%d 牌%d\n" % [
		source,
		_fighter_label(player, "玩家"),
		player.data.max_hp,
		player.momentum,
		player.data.max_momentum,
		player.realm,
		maxi(1, player.qinggong),
		_export_cards(player).size(),
		_fighter_label(enemy, "敌人"),
		enemy.data.max_hp,
		enemy.momentum,
		enemy.data.max_momentum,
		enemy.realm,
		maxi(1, enemy.qinggong),
		_export_cards(enemy).size()
	]

func _format_deck_summary(deck_entries: Array) -> String:
	if deck_entries.is_empty():
		return "未记录"
	var counts := _deck_counts(deck_entries)
	var parts: Array[String] = []
	for id in counts.keys():
		parts.append("%s x%d" % [str(id), int(counts[id])])
	parts.sort()
	return ", ".join(parts)
