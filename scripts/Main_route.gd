extends "res://scripts/Main_combat.gd"

func _show_class_select() -> void:
	player_class_id = ""
	battle_index = 0
	victory = false
	reward_pending = false
	battle_over = false
	current_node_id = ""
	current_enemy_node_id = ""
	available_next_nodes.clear()
	visited_nodes.clear()
	battle_log.clear()
	_show_main_menu()
	_refresh_ui()

func _show_main_menu() -> void:
	_show_overlay(
		"单局原型入口",
		"[b]选择要进入的页面：[/b]\n战斗测试用于进入 6 场连续战斗；设置用于调整当前测试规则开关。",
		[
			{"text": "战斗测试", "callback": Callable(self, "_show_battle_test_page")},
			{"text": "设置", "callback": Callable(self, "_show_settings_page")}
		]
	)

func _show_battle_test_page() -> void:
	var class_actions := []
	var class_ids := class_defs.keys()
	class_ids.sort()
	for class_id in class_ids:
		var class_def: Dictionary = class_defs[class_id]
		class_actions.append({
			"text": "%s｜%s" % [class_def["name"], class_def["weapon"]],
			"callback": Callable(self, "_start_run").bind(class_id)
		})
	class_actions.append({"text": "返回", "callback": Callable(self, "_show_main_menu")})
	_show_overlay(
		"战斗测试",
		"[b]按单局设计方案的 MVP 开局：[/b]\n选择一条武器流派，进入 6 场连续战斗。\n\n配表位置：`res://data/classes.json`",
		class_actions
	)

func _show_settings_page() -> void:
	var graze_state := "开" if CombatResolver.ENABLE_GRAZE else "关"
	_show_overlay(
		"设置",
		"[b]战斗测试设置[/b]\n\n擦中规则：%s\n开启后，距离只差 1 格的攻击会判定为擦中，并按当前收束规则造成半伤、削势 -1。关闭后，擦中视为距离未命中。" % graze_state,
		[
			{"text": "擦中规则：%s" % graze_state, "callback": Callable(self, "_toggle_graze_setting")},
			{"text": "返回", "callback": Callable(self, "_show_main_menu")}
		]
	)

func _toggle_graze_setting() -> void:
	CombatResolver.ENABLE_GRAZE = not CombatResolver.ENABLE_GRAZE
	_show_settings_page()
	_refresh_ui()

func _start_run(class_id: String) -> void:
	player_class_id = class_id
	_build_route_map()
	var class_def: Dictionary = class_defs[class_id]
	player = {
		"name": class_def["name"],
		"weapon": class_def["weapon"],
		"preferred_ranges": class_def["preferred_ranges"].duplicate(),
		"max_hp": 72,
		"hp": 72,
		"max_momentum": MAX_MOMENTUM,
		"momentum": 5,
		"guard": 0,
		"passive": class_def["passive"],
		"deck": class_def["deck"].duplicate(),
		"bonus_next_attack_damage": 0,
		"bonus_first_attack_momentum": 0,
		"first_attack_used": false,
		"took_damage_this_turn": false,
		"flags": {}
	}
	_hide_overlay()
	current_node_id = "start"
	visited_nodes = ["start"]
	_show_route_map("军旅路线", "选择第一站。不同节点会影响你的牌组、血量和接下来的敌人。", route_nodes["start"]["next"])

func _build_route_map() -> void:
	route_nodes.clear()
	for node_id in route_defs.keys():
		route_nodes[node_id] = route_defs[node_id].duplicate(true)

func _show_route_map(title: String, body: String, node_ids: Array) -> void:
	available_next_nodes = node_ids.duplicate()
	var actions := []
	for node_id in node_ids:
		var node: Dictionary = route_nodes[node_id]
		actions.append({
			"text": "%s｜%s" % [_node_kind_label(node["kind"]), node["title"]],
			"callback": Callable(self, "_select_route_node").bind(node_id)
		})
	_show_overlay(title, "%s\n\n%s" % [body, _route_summary_text(node_ids)], actions)

func _select_route_node(node_id: String) -> void:
	current_node_id = node_id
	if not visited_nodes.has(node_id):
		visited_nodes.append(node_id)
	_hide_overlay()
	_resolve_current_node()

func _resolve_current_node() -> void:
	var node: Dictionary = route_nodes[current_node_id]
	match node["kind"]:
		"battle":
			current_enemy_node_id = current_node_id
			_start_battle()
		"camp":
			_resolve_camp_node(node)
		"school":
			_resolve_school_node(node)
		"order":
			_resolve_order_node(node)
		"start":
			_show_route_map("军旅路线", "从起点出发，选择下一处去向。", node["next"])

func _resolve_camp_node(node: Dictionary) -> void:
	var heal: int = node.get("heal", 10)
	var actual_heal := mini(heal, player["max_hp"] - player["hp"])
	player["hp"] += actual_heal
	_log("你在行营修整，回复了 %d 点生命。" % actual_heal)
	_show_route_map("行营修整", "你在军中短暂休整，补足气血后继续前行。", node["next"])
	_refresh_ui()

func _resolve_school_node(node: Dictionary) -> void:
	reward_pending = true
	reward_options.clear()
	var pool := reward_pool.duplicate()
	pool.shuffle()
	for i in range(3):
		reward_options.append(pool[i])
	var actions := []
	for card_id in reward_options:
		actions.append({"text": _reward_text(card_id), "callback": Callable(self, "_pick_reward_from_school").bind(card_id, node["next"])})
	_show_overlay("校场演武", "校场教习开放三门军技，择其一习得后继续赶路。", actions)
	_refresh_ui()

func _resolve_order_node(node: Dictionary) -> void:
	_show_overlay(
		"军令抉择",
		"夜里传令至营前。你可以稳妥整备，也可以冒险强袭，后续路线会保持不变。",
		[
			{"text": "谨慎潜伏｜回复 6 血", "callback": Callable(self, "_apply_order_choice").bind("heal", node["next"])},
			{"text": "接令强袭｜下战敌势 -2", "callback": Callable(self, "_apply_order_choice").bind("ambush", node["next"])},
			{"text": "教头点拨｜习得 1 张牌", "callback": Callable(self, "_apply_order_choice").bind("train", node["next"])}
		]
	)

func _apply_order_choice(choice: String, next_nodes: Array) -> void:
	match choice:
		"heal":
			var heal := mini(6, player["max_hp"] - player["hp"])
			player["hp"] += heal
			_log("你选择谨慎潜伏，回复了 %d 点生命。" % heal)
		"ambush":
			player["flags"]["ambush_next_battle"] = true
			_log("你接令强袭，下场战斗敌方开局 -2 势。")
		"train":
			var pool := reward_pool.duplicate()
			pool.shuffle()
			var learned_card: String = pool[0]
			player["deck"].append(learned_card)
			_log("教头点拨后，你习得了 [color=#95e1d3]%s[/color]。" % card_defs[learned_card]["name"])
	_show_route_map("继续行军", "处理完军令后，你继续沿路线推进。", next_nodes)
	_refresh_ui()

func _pick_reward_from_school(card_id: String, next_nodes: Array) -> void:
	player["deck"].append(card_id)
	reward_pending = false
	_log("你在校场习得了 [color=#95e1d3]%s[/color]。" % card_defs[card_id]["name"])
	_show_route_map("继续行军", "演武结束，选择下一处去向。", next_nodes)
	_refresh_ui()

func _node_kind_label(kind: String) -> String:
	match kind:
		"battle":
			return "战"
		"camp":
			return "营"
		"school":
			return "校"
		"order":
			return "令"
		_:
			return "起"

func _route_summary_text(node_ids: Array) -> String:
	var parts := []
	for node_id in node_ids:
		var node: Dictionary = route_nodes[node_id]
		var extra := ""
		match node["kind"]:
			"battle":
				var enemy_id: String = node["enemy_id"]
				var enemy_def: Dictionary = enemy_def_by_id[enemy_id]
				extra = "遭遇 %s" % enemy_def["name"]
			"camp":
				extra = "回复 %d 血" % node.get("heal", 10)
			"school":
				extra = "三选一卡"
			"order":
				extra = "事件抉择"
		parts.append("- %s：%s" % [node["title"], extra])
	return "\n".join(parts)

