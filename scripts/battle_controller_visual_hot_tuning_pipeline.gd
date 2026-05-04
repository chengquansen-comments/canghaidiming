extends "res://scripts/battle_controller_visual_hot_tuning_config.gd"

# Extracted from battle_controller_visual_hot_tuning.gd.
# Layer responsibility: battle_controller_visual_hot_tuning_pipeline.gd.

func _sync_number_pipeline_fields_from_fighters() -> void:
	if _number_pipeline_fields.is_empty():
		return
	if player == null or enemy == null or player.data == null or enemy.data == null:
		_number_config_status = "数值管线：尚未进入战斗"
		return
	var current := {
		"player": _fighter_number_snapshot(player),
		"enemy": _fighter_number_snapshot(enemy)
	}
	_set_pipeline_side_values("player", current.get("player", {}))
	_set_pipeline_side_values("enemy", current.get("enemy", {}))
	if _number_pipeline_baseline.is_empty():
		_number_pipeline_baseline = current.duplicate(true)
	_number_config_status = "数值管线：已读取当前敌我数值"
	_refresh_tuning_panel()

func _apply_number_pipeline_fields() -> void:
	if player == null or enemy == null:
		_number_config_status = "应用失败：尚未进入战斗"
		_refresh_tuning_panel()
		return
	if _number_pipeline_baseline.is_empty():
		_number_pipeline_baseline = {
			"player": _fighter_number_snapshot(player),
			"enemy": _fighter_number_snapshot(enemy)
		}
	_apply_fighter_numbers(player, _pipeline_side_values("player"))
	_apply_fighter_numbers(enemy, _pipeline_side_values("enemy"))
	if state_machine != null:
		state_machine.update_distance_from_positions(player, enemy)
	if has_method("_safe_refresh_runtime_ui"):
		call("_safe_refresh_runtime_ui")
	_number_config_status = "数值管线：已应用到当前战斗"
	_refresh_tuning_panel()

func _reset_number_pipeline_fields() -> void:
	if _number_pipeline_baseline.is_empty():
		if player != null and enemy != null:
			_number_pipeline_baseline = {
				"player": _fighter_number_snapshot(player),
				"enemy": _fighter_number_snapshot(enemy)
			}
		else:
			_number_config_status = "重置失败：尚未进入战斗"
			_refresh_tuning_panel()
			return
	_set_pipeline_side_values("player", _number_pipeline_baseline.get("player", {}))
	_set_pipeline_side_values("enemy", _number_pipeline_baseline.get("enemy", {}))
	_apply_number_pipeline_fields()
	_number_config_status = "数值管线：已重置到读取时基线"
	_refresh_tuning_panel()

func _save_number_pipeline_config() -> void:
	if player == null or enemy == null:
		_number_config_status = "保存失败：尚未进入战斗"
		_refresh_tuning_panel()
		return
	var config := _snapshot_number_config("管线方案 %02d" % _number_config_serial)
	config["player"] = _pipeline_side_values("player")
	config["enemy"] = _pipeline_side_values("enemy")
	config["diff"] = _number_config_diff(_snapshot_number_config("当前"), config)
	_number_config_serial += 1
	_number_configs.append(config)
	_active_number_config_index = _number_configs.size() - 1
	_number_config_status = "数值管线：已保存配置"
	_save_number_configs()
	_refresh_number_config_select()
	_refresh_tuning_panel()

func _sample_number_pipeline_fields() -> void:
	if player == null or enemy == null:
		_number_config_status = "采样失败：尚未进入战斗"
		_refresh_tuning_panel()
		return
	var config := _snapshot_number_config("管线临时采样")
	config["player"] = _pipeline_side_values("player")
	config["enemy"] = _pipeline_side_values("enemy")
	var count := int(_number_pipeline_sample_count.value) if _number_pipeline_sample_count != null else 120
	var seed := int(_number_pipeline_seed.value) if _number_pipeline_seed != null else int(Time.get_ticks_usec() % 1000000)
	var result := _sample_number_config(config, count, seed)
	_last_sample_report = AutoBattleSampler.format_report(result)
	_number_config_status = "数值管线：已按面板参数采样，%s" % AutoBattleSampler.format_balance_conclusion(result)
	_refresh_tuning_panel()

func _set_pipeline_side_values(side: String, values: Dictionary) -> void:
	for field in ["max_hp", "max_momentum", "momentum", "realm", "qinggong"]:
		var key := "%s_%s" % [side, field]
		var spin: SpinBox = _number_pipeline_fields.get(key, null)
		if spin != null:
			spin.value = float(values.get(field, spin.value))

func _pipeline_side_values(side: String) -> Dictionary:
	var values := {}
	for field in ["max_hp", "max_momentum", "momentum", "realm", "qinggong"]:
		var key := "%s_%s" % [side, field]
		var spin: SpinBox = _number_pipeline_fields.get(key, null)
		if spin != null:
			values[field] = int(spin.value)
	values["momentum"] = clampi(int(values.get("momentum", 0)), 0, int(values.get("max_momentum", 1)))
	var fighter := player if side == "player" else enemy
	var fallback_style := "spear" if side == "player" else "blade"
	values["style"] = _style_for_fighter(fighter, fallback_style)
	values["preferred"] = _preferred_for_fighter(fighter, str(values.get("style", fallback_style)))
	return values
