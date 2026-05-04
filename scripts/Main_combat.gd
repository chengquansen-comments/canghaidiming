extends "res://scripts/Main_data.gd"

func _start_battle() -> void:
	battle_over = false
	reward_pending = false
	next_button.visible = false
	action_button.visible = true
	action_button.disabled = false
	hand.clear()
	discard_pile.clear()
	draw_pile = player["deck"].duplicate()
	draw_pile.shuffle()
	var current_battle_node: Dictionary = route_nodes[current_enemy_node_id]
	map_length = current_battle_node.get("map_length", 9)
	initial_distance = current_battle_node.get("initial_distance", 2)
	_setup_battle_positions()
	_build_distance_track()
	var enemy_def: Dictionary = enemy_def_by_id[current_battle_node["enemy_id"]]
	enemy = {
		"id": enemy_def["id"],
		"name": enemy_def["name"],
		"title": enemy_def["title"],
		"max_hp": enemy_def["max_hp"],
		"hp": enemy_def["max_hp"],
		"max_momentum": enemy_def["max_momentum"],
		"momentum": mini(6, enemy_def["max_momentum"]),
		"guard": 0,
		"passive": enemy_def["passive"],
		"preferred_ranges": enemy_def["preferred_ranges"].duplicate(),
		"intents": enemy_def["intents"],
		"intent_index": 0,
		"current_intent": {},
		"collapsed": false,
		"next_attack_critical": false,
		"flags": {}
	}
	_sync_distance_from_positions()
	if player["flags"].get("ambush_next_battle", false):
		enemy["momentum"] = maxi(enemy["momentum"] - 2, 0)
		player["flags"]["ambush_next_battle"] = false
		_log("你提前夜袭布置成功，敌方开局 -2 势。")
	battle_index += 1
	player["guard"] = 0
	player["momentum"] = clampi(player["momentum"] + 1, 0, MAX_MOMENTUM)
	player["first_attack_used"] = false
	player["took_damage_this_turn"] = false
	player["flags"] = {}
	_log("[b]%s[/b] 开始，抵达节点 [color=#95e1d3]%s[/color]，遭遇 [color=#f0d083]%s[/color]（%s）。" % [_battle_name(), route_nodes[current_enemy_node_id]["title"], enemy["name"], enemy["title"]])
	_show_fx(enemy_fx_label, enemy["title"], Color("f0d083"))
	_begin_player_turn(true)

func _battle_name() -> String:
	return "第 %d 战" % [battle_index]

func _begin_player_turn(is_new_battle := false) -> void:
	player["guard"] = 0
	player["first_attack_used"] = false
	player["took_damage_this_turn"] = false
	player["flags"] = {}
	player["bonus_next_attack_damage"] = 0
	player["bonus_first_attack_momentum"] = 0

	var gain := 3
	if player_class_id == "spear" and _is_preferred_distance(player["preferred_ranges"]):
		gain += 1
		player["bonus_first_attack_momentum"] = 1
		_log("你在优势距离起势，额外获得 1 势，且本回合首次攻击额外削敌 1 势。")
	if enemy["id"] == "dual_ronin":
		enemy["momentum"] = clampi(enemy["momentum"] + 1, 0, enemy["max_momentum"])
	if enemy["id"] == "captain_boss" and enemy["collapsed"]:
		enemy["momentum"] = clampi(enemy["momentum"] + 1, 0, enemy["max_momentum"])
	player["momentum"] = clampi(player["momentum"] + gain, 0, player["max_momentum"])

	if not is_new_battle:
		_log("[b]新回合[/b]：你恢复 %d 势。" % [gain])

	enemy["guard"] = 0
	_prepare_enemy_intent()
	_draw_to_hand(HAND_SIZE)
	_refresh_ui()

func _prepare_enemy_intent() -> void:
	var base_gain := 3
	if enemy["id"] == "raider":
		base_gain = 4
	elif enemy["id"] == "dual_ronin":
		base_gain = 4
	if _is_enemy_preferred_distance():
		base_gain += 1
	if enemy["id"] == "captain_boss" and _is_enemy_preferred_distance():
		base_gain += 1
	enemy["momentum"] = clampi(enemy["momentum"] + base_gain, 0, enemy["max_momentum"])

	var intents: Array = enemy["intents"]
	enemy["current_intent"] = intents[enemy["intent_index"] % intents.size()].duplicate()
	enemy["intent_index"] += 1

func _draw_to_hand(target_size: int) -> void:
	while hand.size() < target_size:
		if draw_pile.is_empty():
			if discard_pile.is_empty():
				break
			draw_pile = discard_pile.duplicate()
			discard_pile.clear()
			draw_pile.shuffle()
		hand.append(draw_pile.pop_back())

func _setup_battle_positions() -> void:
	initial_distance = clampi(initial_distance, 0, map_length - 1)
	var free_space: int = map_length - 1 - initial_distance
	player_position = free_space / 2
	enemy_position = player_position + initial_distance
	_sync_distance_from_positions()

func _sync_distance_from_positions() -> void:
	distance = maxi(enemy_position - player_position, 0)

func _apply_distance_delta(amount: int, actor: String) -> void:
	if amount == 0:
		return
	var before_distance := distance
	if actor == "player":
		if amount > 0:
			player_position = maxi(player_position - amount, 0)
		else:
			player_position = mini(player_position + abs(amount), enemy_position)
	else:
		if amount > 0:
			player_position = maxi(player_position - amount, 0)
		else:
			enemy_position = maxi(enemy_position - abs(amount), player_position)
	_sync_distance_from_positions()
	if before_distance == distance:
		_log("已抵地图边界，无法再退。")
		_show_fx(center_callout, "边界受限", Color("f0d083"))
		return
	var op := "+" if amount > 0 else ""
	_log("距离 %s%d，当前为 %d。" % [op, amount, distance])
	_animate_distance_shift()

func _on_card_pressed(index: int) -> void:
	if battle_over or reward_pending:
		return
	var card_id: String = hand[index]
	var cost: int = _card_cost(card_id)
	if cost > player["momentum"]:
		return
	player["momentum"] -= cost
	var card: Dictionary = card_defs[card_id]
	_log("你使出 [color=#95e1d3]%s[/color]。" % card["name"])
	_flash_avatar(player_avatar, Color("95e1d3"))
	_show_fx(player_fx_label, card["name"], CATEGORY_COLORS.get(card["category"], Color.WHITE))
	_apply_card(card_id)
	discard_pile.append(card_id)
	hand.remove_at(index)
	if enemy["hp"] <= 0:
		_handle_enemy_defeated()
		return
	_refresh_ui()

func _apply_card(card_id: String) -> void:
	var card: Dictionary = card_defs[card_id]
	for effect in card["effects"]:
		_apply_effect(effect, card_id)

func _apply_effect(effect: Dictionary, card_id: String) -> void:
	if effect.get("if_preferred", false) and not _is_preferred_distance(player["preferred_ranges"]):
		return
	var effect_type: String = effect["type"]
	var effect_spec: Dictionary = effect_defs[effect_type]
	var handler_name: String = effect_spec["handler"]
	call(handler_name, effect, card_id)

func _effect_distance(effect: Dictionary, _card_id: String) -> void:
	_apply_distance_delta(effect["amount"], "player")

func _effect_set_distance_toward(effect: Dictionary, _card_id: String) -> void:
	var target: int = effect["target"]
	if distance < target:
		_apply_distance_delta(+1, "player")
	elif distance > target:
		_apply_distance_delta(-1, "player")

func _effect_set_distance_step_toward_preferred(_effect: Dictionary, _card_id: String) -> void:
	var target: int = player["preferred_ranges"][0]
	if not player["preferred_ranges"].has(distance):
		if distance < target:
			_apply_distance_delta(+1, "player")
		else:
			_apply_distance_delta(-1, "player")

func _effect_toggle_distance(_effect: Dictionary, _card_id: String) -> void:
	_apply_distance_delta(selected_distance_toggle, "player")
	selected_distance_toggle *= -1

func _effect_guard(effect: Dictionary, _card_id: String) -> void:
	var amount: int = effect["amount"]
	if effect.get("if_preferred", false) and not _is_preferred_distance(player["preferred_ranges"]):
		amount = 0
	player["guard"] += amount
	if amount > 0:
		_log("你获得 %d 格挡。" % amount)
		_show_fx(player_fx_label, "+%d 格挡" % amount, Color("7dd3a7"))

func _effect_momentum(effect: Dictionary, _card_id: String) -> void:
	player["momentum"] = clampi(player["momentum"] + effect["amount"], 0, player["max_momentum"])
	_log("你恢复 %d 势。" % effect["amount"])
	_show_fx(player_fx_label, "+%d 势" % effect["amount"], Color("8ec5ff"))

func _effect_enemy_momentum(effect: Dictionary, _card_id: String) -> void:
	var before: int = enemy["momentum"]
	enemy["momentum"] = clampi(enemy["momentum"] + effect["amount"], 0, enemy["max_momentum"])
	if effect["amount"] < 0:
		_log("敌方失去 %d 势。" % (before - enemy["momentum"]))
		_show_fx(enemy_fx_label, "-%d 势" % (before - enemy["momentum"]), Color("ffb05c"))
		if enemy["momentum"] <= 0:
			_collapse_enemy()

func _effect_draw(effect: Dictionary, _card_id: String) -> void:
	_draw_to_hand(mini(hand.size() + effect["amount"], HAND_SIZE + effect["amount"]))
	_log("你调整呼吸，补到 %d 张手牌。" % hand.size())

func _effect_buff_next_attack_damage(effect: Dictionary, _card_id: String) -> void:
	if _is_preferred_distance(player["preferred_ranges"]):
		player["bonus_next_attack_damage"] += effect["amount"]
		_log("你蓄起刀势，下一次攻击额外 +%d 伤害。" % effect["amount"])

func _effect_flag(effect: Dictionary, _card_id: String) -> void:
	player["flags"][effect["flag"]] = true

func _effect_attack(effect: Dictionary, card_id: String) -> void:
	_resolve_attack(effect, card_id)

func _resolve_attack(effect: Dictionary, card_id: String) -> void:
	var damage: int = effect["damage"]
	var momentum_damage: int = effect.get("momentum_damage", 0)

	if effect.has("range_bonus") and not effect["range_bonus"].has(distance):
		damage = maxi(damage - effect.get("range_penalty", 0), 0)
	if effect.has("bonus_damage_if_momentum_missing") and enemy["max_momentum"] - enemy["momentum"] >= 4:
		damage += effect["bonus_damage_if_momentum_missing"]
	if effect.get("override_damage_if_collapsed", 0) > 0 and enemy["collapsed"]:
		damage = effect["override_damage_if_collapsed"]
	if effect.get("bonus_damage_if_collapsed", 0) > 0 and enemy["collapsed"]:
		damage += effect["bonus_damage_if_collapsed"]
	if player_class_id == "saber" and not player["first_attack_used"]:
		damage += 2
	if player["bonus_next_attack_damage"] > 0:
		damage += player["bonus_next_attack_damage"]
		player["bonus_next_attack_damage"] = 0
	if player_class_id == "spear" and not player["first_attack_used"]:
		momentum_damage += player["bonus_first_attack_momentum"]

	var critical := false
	if effect.get("force_crit_if_collapsed", false) and enemy["collapsed"]:
		critical = true
	elif enemy["next_attack_critical"]:
		critical = true
	if critical:
		damage *= CRITICAL_MULTIPLIER
		enemy["next_attack_critical"] = false
		_log("[color=#ff8a7a]崩塌处决！[/color] 伤害翻倍。")
		_show_fx(center_callout, "处决", Color("ff8a7a"))

	player["first_attack_used"] = true

	var guard_block := mini(enemy["guard"], damage)
	enemy["guard"] -= guard_block
	damage -= guard_block
	if guard_block > 0:
		_log("敌方格挡了 %d 点伤害。" % guard_block)
		_show_fx(enemy_fx_label, "格挡 %d" % guard_block, Color("8fd1b4"))
	if damage > 0:
		enemy["hp"] = maxi(enemy["hp"] - damage, 0)
		_log("命中造成 %d 伤害。" % damage)
		_flash_avatar(enemy_avatar, Color("d86959"))
		_show_fx(enemy_fx_label, "-%d 血" % damage, Color("ff8a7a"))

	var before: int = enemy["momentum"]
	enemy["momentum"] = clampi(enemy["momentum"] - momentum_damage, 0, enemy["max_momentum"])
	if momentum_damage > 0:
		_log("同时削去敌方 %d 势。" % (before - enemy["momentum"]))
	if enemy["momentum"] <= 0 and before > 0:
		_collapse_enemy()

func _collapse_enemy() -> void:
	enemy["collapsed"] = true
	enemy["next_attack_critical"] = true
	_log("[color=#ff8a7a]%s 架势崩塌！本回合动作取消，下次受到攻击必暴击。[/color]" % enemy["name"])
	_flash_avatar(enemy_avatar, Color("ff8a7a"), 0.12)
	_show_fx(enemy_fx_label, "崩塌", Color("ff8a7a"))

func _on_end_turn_pressed() -> void:
	if battle_over or reward_pending:
		return
	_enemy_phase()

func _enemy_phase() -> void:
	var intent: Dictionary = enemy["current_intent"]
	for card_id in hand:
		discard_pile.append(card_id)
	hand.clear()

	if player["flags"].get("guard_frame", false) and not player["took_damage_this_turn"]:
		player["momentum"] = clampi(player["momentum"] + 1, 0, player["max_momentum"])
		_log("你守得沉稳，回合结束再回 1 势。")

	if enemy["collapsed"]:
		_log("%s 尚在崩塌中，本回合招式中断。" % enemy["name"])
		enemy["collapsed"] = false
		_show_fx(center_callout, "敌招中断", Color("f0d083"))
		_begin_player_turn()
		return

	if enemy["momentum"] < intent["cost"]:
		_log("%s 想施展 [color=#f0d083]%s[/color]，但势不足，被你打断。%s 露出破绽。" % [enemy["name"], intent["name"], enemy["name"]])
		enemy["collapsed"] = true
		enemy["next_attack_critical"] = true
		_show_fx(center_callout, "打断成功", Color("f0d083"))
		_flash_avatar(enemy_avatar, Color("ff8a7a"), 0.1)
		_begin_player_turn()
		return

	enemy["momentum"] -= intent["cost"]
	if intent.has("move_to"):
		var target_distance: int = intent["move_to"]
		if distance < target_distance:
			_apply_distance_delta(+1, "enemy")
		elif distance > target_distance:
			_apply_distance_delta(-1, "enemy")
	elif intent.has("move_delta"):
		_apply_distance_delta(intent["move_delta"], "enemy")

	if intent.has("guard"):
		enemy["guard"] += intent["guard"]
		_log("%s 先稳住架势，获得 %d 格挡。" % [enemy["name"], intent["guard"]])
		_show_fx(enemy_fx_label, "+%d 格挡" % intent["guard"], Color("7dd3a7"))

	var damage: int = intent.get("damage", 0)
	if intent.has("range_bonus") and intent["range_bonus"].has(distance):
		damage += 2
	if enemy["id"] == "firearms_officer" and distance == 3:
		damage += 2

	var incoming: int = damage
	var guard_before: int = player["guard"]
	var blocked := mini(player["guard"], incoming)
	player["guard"] -= blocked
	incoming -= blocked
	if blocked > 0:
		_log("你格挡了 %d 点伤害。" % blocked)
		_show_fx(player_fx_label, "格挡 %d" % blocked, Color("7dd3a7"))
		var surplus: int = guard_before - damage
		if incoming == 0 and surplus <= 3:
			var stolen := mini(1, enemy["momentum"])
			enemy["momentum"] -= stolen
			player["momentum"] = clampi(player["momentum"] + 1, 0, player["max_momentum"])
			_log("[color=#95e1d3]完美格挡！[/color] 你吸走敌方 %d 势，并回 1 势。" % stolen)
			_flash_avatar(player_avatar, Color("95e1d3"), 0.1)
			_show_fx(center_callout, "完美格挡", Color("95e1d3"))

	var player_before_hp: int = player["hp"]
	if incoming > 0:
		player["hp"] = maxi(player["hp"] - incoming, 0)
		player["took_damage_this_turn"] = true
		_log("%s 的 [color=#f0d083]%s[/color] 命中，你受到 %d 伤害。" % [enemy["name"], intent["name"], incoming])
		_flash_avatar(enemy_avatar, Color("f0d083"))
		_flash_avatar(player_avatar, Color("d86959"))
		_show_fx(player_fx_label, "-%d 血" % incoming, Color("ff8a7a"))

	var momentum_loss: int = intent.get("momentum_damage", 0)
	if momentum_loss > 0:
		player["momentum"] = maxi(player["momentum"] - momentum_loss, 0)
		_log("你的势再被压掉 %d 点。" % momentum_loss)

	if player_before_hp - player["hp"] >= 10:
		player["momentum"] = maxi(player["momentum"] - 1, 0)
		_log("你吃到重击，额外失去 1 势。")

	if player["hp"] <= 0:
		_handle_player_defeated()
		return

	_begin_player_turn()

func _handle_enemy_defeated() -> void:
	battle_over = true
	action_button.disabled = true
	action_button.visible = false
	hand.clear()
	_log("[b]%s[/b] 击败了 [color=#f0d083]%s[/color]。" % [player["name"], enemy["name"]])
	var node: Dictionary = route_nodes[current_enemy_node_id]
	if node["next"].is_empty():
		victory = true
		_show_overlay(
			"单局完成",
			"[b]你击破了路线终点的头目。[/b]\n\n这版单局现在已经具备分支路线：你会在行营、校场、军令与遭遇战之间做选择，再把构筑和血线带进终局。",
			[
				{"text": "重新开局", "callback": Callable(self, "_show_class_select")}
			]
		)
		_refresh_ui()
		return
	enemy = {}
	_show_route_map("战后推进", "此战已胜，选择下一处节点继续单局。", node["next"])
	_refresh_ui()

func _reward_text(card_id: String) -> String:
	var def: Dictionary = card_defs[card_id]
	return "%s｜%s｜耗势 %d" % [def["name"], def["category"], def["cost"]]

func _handle_player_defeated() -> void:
	battle_over = true
	action_button.disabled = true
	action_button.visible = false
	hand.clear()
	var reason := "败于势竭"
	if not player["preferred_ranges"].has(distance):
		reason = "败于失距"
	elif player["momentum"] == 0:
		reason = "败于势竭"
	elif enemy["current_intent"].get("damage", 0) >= 12:
		reason = "败于贪刀未收"
	_show_overlay(
		"此局战败",
		"[b]%s[/b]\n\n你倒在了 %s 手下。可以直接重新开一局继续验证手感。" % [reason, enemy["name"]],
		[
			{"text": "重新开局", "callback": Callable(self, "_show_class_select")}
		]
	)
	_refresh_ui()

