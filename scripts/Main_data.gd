extends "res://scripts/Main_ui.gd"

func _load_game_data() -> void:
	data_load_error = ""
	class_defs = _load_json_file(DATA_PATHS["classes"], TYPE_DICTIONARY, "开局模板")
	card_defs = _load_json_file(DATA_PATHS["cards"], TYPE_DICTIONARY, "卡牌")
	effect_defs = _load_json_file(DATA_PATHS["effects"], TYPE_DICTIONARY, "效果类型")
	enemy_defs = _load_json_file(DATA_PATHS["enemies"], TYPE_ARRAY, "敌人")
	route_defs = _load_json_file(DATA_PATHS["routes"], TYPE_DICTIONARY, "路线节点")
	reward_pool = _load_json_file(DATA_PATHS["rewards"], TYPE_ARRAY, "奖励池")
	if data_load_error != "":
		return
	_build_enemy_lookup()
	_validate_game_data()

func _load_json_file(path: String, expected_type: int, label: String) -> Variant:
	if not FileAccess.file_exists(path):
		data_load_error = "%s 数据文件不存在：%s" % [label, path]
		push_error(data_load_error)
		return {} if expected_type == TYPE_DICTIONARY else []
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		data_load_error = "无法打开 %s 数据文件：%s" % [label, path]
		push_error(data_load_error)
		return {} if expected_type == TYPE_DICTIONARY else []
	var raw_text: String = file.get_as_text()
	var parsed: Variant = JSON.parse_string(raw_text)
	if parsed == null:
		data_load_error = "%s 数据文件 JSON 解析失败：%s" % [label, path]
		push_error(data_load_error)
		return {} if expected_type == TYPE_DICTIONARY else []
	if typeof(parsed) != expected_type:
		data_load_error = "%s 数据文件类型不正确：%s" % [label, path]
		push_error(data_load_error)
		return {} if expected_type == TYPE_DICTIONARY else []
	return parsed

func _validate_game_data() -> void:
	for effect_type in effect_defs.keys():
		var effect_def: Dictionary = effect_defs[effect_type]
		for required_key in ["handler", "required_fields"]:
			if not effect_def.has(required_key):
				_set_data_error("效果类型 %s 缺少字段 %s" % [effect_type, required_key])
				return
		var handler_name: String = effect_def["handler"]
		if not has_method(handler_name):
			_set_data_error("效果类型 %s 绑定了不存在的处理器 %s" % [effect_type, handler_name])
			return

	for class_id in class_defs.keys():
		var class_def: Dictionary = class_defs[class_id]
		for required_key in ["name", "weapon", "preferred_ranges", "passive", "deck"]:
			if not class_def.has(required_key):
				_set_data_error("开局模板 %s 缺少字段 %s" % [class_id, required_key])
				return
		for card_id in class_def["deck"]:
			if not card_defs.has(card_id):
				_set_data_error("开局模板 %s 使用了不存在的卡牌 %s" % [class_id, card_id])
				return

	for card_id in card_defs.keys():
		var card_def: Dictionary = card_defs[card_id]
		for required_key in ["name", "category", "cost", "text", "effects"]:
			if not card_def.has(required_key):
				_set_data_error("卡牌 %s 缺少字段 %s" % [card_id, required_key])
				return
		for effect_index in range(card_def["effects"].size()):
			var effect: Dictionary = card_def["effects"][effect_index]
			if not effect.has("type"):
				_set_data_error("卡牌 %s 的效果 #%d 缺少字段 type" % [card_id, effect_index])
				return
			var effect_type: String = effect["type"]
			if not effect_defs.has(effect_type):
				_set_data_error("卡牌 %s 使用了未注册的效果类型 %s" % [card_id, effect_type])
				return
			var spec: Dictionary = effect_defs[effect_type]
			for required_field in spec["required_fields"]:
				if not effect.has(required_field):
					_set_data_error("卡牌 %s 的效果类型 %s 缺少字段 %s" % [card_id, effect_type, required_field])
					return

	for reward_card_id in reward_pool:
		if not card_defs.has(reward_card_id):
			_set_data_error("奖励池引用了不存在的卡牌 %s" % reward_card_id)
			return

	for enemy_index in range(enemy_defs.size()):
		var enemy_def: Dictionary = enemy_defs[enemy_index]
		for required_key in ["id", "name", "title", "max_hp", "max_momentum", "start_distance", "preferred_ranges", "passive", "intents"]:
			if not enemy_def.has(required_key):
				_set_data_error("敌人配置 #%d 缺少字段 %s" % [enemy_index, required_key])
				return
		if enemy_def["intents"].is_empty():
			_set_data_error("敌人 %s 至少需要 1 条意图" % enemy_def["id"])
			return

	for route_id in route_defs.keys():
		var route_def: Dictionary = route_defs[route_id]
		for required_key in ["title", "kind", "next"]:
			if not route_def.has(required_key):
				_set_data_error("路线节点 %s 缺少字段 %s" % [route_id, required_key])
				return
		if route_def["kind"] == "battle":
			for required_key in ["enemy_id", "map_length", "initial_distance"]:
				if not route_def.has(required_key):
					_set_data_error("战斗路线节点 %s 缺少字段 %s" % [route_id, required_key])
					return
			if not enemy_def_by_id.has(route_def["enemy_id"]):
				_set_data_error("路线节点 %s 引用了不存在的敌人 %s" % [route_id, route_def["enemy_id"]])
				return
		for next_id in route_def["next"]:
			if not route_defs.has(next_id):
				_set_data_error("路线节点 %s 指向了不存在的下一节点 %s" % [route_id, next_id])
				return

func _build_enemy_lookup() -> void:
	enemy_def_by_id.clear()
	for enemy_def in enemy_defs:
		enemy_def_by_id[enemy_def["id"]] = enemy_def

func _set_data_error(message: String) -> void:
	data_load_error = message
	push_error(message)

func _show_data_error() -> void:
	_refresh_ui()
	_show_overlay(
		"数据加载失败",
		"[b]配表读取失败。[/b]\n\n%s\n\n请检查 `res://data` 下的 JSON 文件。" % data_load_error,
		[]
	)

func _card_cost(card_id: String) -> int:
	var cost: int = card_defs[card_id]["cost"]
	if card_id == "dragonslash" and enemy.get("collapsed", false):
		return 0
	if card_id == "dragon_break" and enemy.get("collapsed", false):
		return maxi(cost - 2, 0)
	return cost

