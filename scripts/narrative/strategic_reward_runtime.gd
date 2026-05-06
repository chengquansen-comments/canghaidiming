extends RefCounted

const BattleFontHelper := preload("res://scripts/visual/battle_font_view.gd")
const StrategicMapState := preload("res://scripts/strategic_map_state.gd")

var c

func _init(controller) -> void:
	c = controller

func strategic_card_reward_choices(node: Dictionary) -> Array[String]:
	var effects: Dictionary = node.get("effects", {}) as Dictionary
	var ids := card_reward_ids_from_effects(effects.get("card_rewards", []))
	if ids.is_empty():
		return []
	var owned := card_reward_ids_from_effects(c.strategic_state.get("owned_card_ids", []))
	var fresh: Array[String] = []
	for card_id: String in ids:
		if not (card_id in owned):
			fresh.append(card_id)
	var candidates := fresh if not fresh.is_empty() else ids
	candidates.shuffle()
	return candidates.slice(0, mini(3, candidates.size()))

func show_strategic_card_reward_choice(node: Dictionary, card_ids: Array[String]) -> void:
	c.pending_strategic_card_node = node.duplicate(true)
	c.pending_strategic_card_choices = card_ids.duplicate()
	c.selected_strategic_card_reward = ""
	c._clear_dynamic_boxes()
	c.title_label.text = str(node.get("title", "得招"))
	c.status_label.text = "%s / 招式抉择" % c._strategic_type_label(str(node.get("node_type", "")))
	c.map_label.text = c._strategic_progress_text(c.strategic_state.get("current_map", {}))
	c.scene_label.text = c._format_scene_text(str(node.get("preview_text", "")))
	c._render_visual(str(node.get("visual_path", "")), str(node.get("title", "得招")))
	c.body_label.text = "%s\n\n选择 1 张新招式加入长期牌库，然后确认。" % str(node.get("result_text", "你得了一次整理招式的机会。"))
	c.vars_label.text = StrategicMapState.summary_text(c.strategic_state)
	c._add_placeholder(c.map_buttons_box, "卡牌奖励不会自动发放，需先三选一。")
	c._add_placeholder(c.combat_buttons_box, "非战斗节点")
	for card_id: String in c.pending_strategic_card_choices:
		var btn := Button.new()
		btn.text = strategic_card_choice_text(card_id, false)
		btn.custom_minimum_size = Vector2(0, 76)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.pressed.connect(c._select_strategic_card_reward.bind(card_id))
		c.choices_box.add_child(btn)
	var confirm := Button.new()
	confirm.name = "StrategicCardRewardConfirm"
	confirm.text = "确认"
	confirm.disabled = true
	confirm.custom_minimum_size = Vector2(0, 64)
	confirm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	confirm.pressed.connect(c._confirm_strategic_card_reward)
	c.choices_box.add_child(confirm)
	var cancel := Button.new()
	cancel.text = "返回本层选择"
	cancel.custom_minimum_size = Vector2(0, 54)
	cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cancel.pressed.connect(c._cancel_strategic_card_reward)
	c.choices_box.add_child(cancel)
	BattleFontHelper.enforce(c)
	c._apply_focus_ui()
	c._hide_scene_art_overlay_nodes()

func select_strategic_card_reward(card_id: String) -> void:
	c.selected_strategic_card_reward = card_id
	for child in c.choices_box.get_children():
		if child is Button:
			var btn := child as Button
			if btn.name == "StrategicCardRewardConfirm":
				btn.disabled = c.selected_strategic_card_reward.is_empty()
				continue
			if card_id in c.pending_strategic_card_choices:
				for choice_id: String in c.pending_strategic_card_choices:
					if btn.text.find(strategic_card_label(choice_id)) >= 0:
						btn.text = strategic_card_choice_text(choice_id, choice_id == card_id)
	c.body_label.text = "%s\n\n已选择：%s" % [str(c.pending_strategic_card_node.get("result_text", "")), strategic_card_label(card_id)]

func confirm_strategic_card_reward() -> void:
	if c.pending_strategic_card_node.is_empty() or c.selected_strategic_card_reward.is_empty():
		return
	var node: Dictionary = c.pending_strategic_card_node.duplicate(true)
	var effects: Dictionary = node.get("effects", {}) as Dictionary
	effects["card_rewards"] = [c.selected_strategic_card_reward]
	node["effects"] = effects
	c.pending_strategic_card_node.clear()
	c.pending_strategic_card_choices.clear()
	c.selected_strategic_card_reward = ""
	c._apply_strategic_node(node)
	c._advance_strategic_cursor()
	c._save_narrative_state_to_context()
	c._render()

func cancel_strategic_card_reward() -> void:
	c.pending_strategic_card_node.clear()
	c.pending_strategic_card_choices.clear()
	c.selected_strategic_card_reward = ""
	c._render()

func strategic_card_choice_text(card_id: String, selected: bool) -> String:
	var prefix := "✓ " if selected else ""
	return "%s%s\n%s" % [prefix, strategic_card_label(card_id), strategic_card_hint(card_id)]

func strategic_card_label(card_id: String) -> String:
	match card_id:
		"reward_push": return "压线"
		"reward_pull": return "挂带"
		"reward_guard": return "铁壁"
		"blade_press_break": return "压刀破架"
		"blade_hook_pull": return "挂刀带步"
		"blade_body_press": return "贴身撞刀"
		"spear_retreat_sting": return "退枪留锋"
		"spear_step_thrust": return "顺步送枪"
	return card_id

func strategic_card_hint(card_id: String) -> String:
	match card_id:
		"reward_push": return "控线，命中后击退敌人。"
		"reward_pull": return "拉扯，命中后拉近敌人。"
		"reward_guard": return "架势，获得高额格挡。"
		"blade_press_break": return "短兵破势，贴身压架。"
		"blade_hook_pull": return "短兵拉扯，调整距离。"
		"blade_body_press": return "极近破势，压短兵节奏。"
		"spear_retreat_sting": return "近身脱身刺，命中后后撤。"
		"spear_step_thrust": return "三格追击刺，命中后进身。"
	return "加入长期牌库。"

func card_reward_ids_from_effects(value) -> Array[String]:
	var ids: Array[String] = []
	if value is Array or value is PackedStringArray:
		for item in value:
			var card_id := str(item)
			if not card_id.is_empty():
				ids.append(card_id)
	elif value is String:
		var card_id := str(value)
		if not card_id.is_empty():
			ids.append(card_id)
	return ids

func strategic_progress_text(map_data: Dictionary) -> String:
	var regions: Array = map_data.get("regions", [])
	var parts: Array[String] = []
	for i in range(regions.size()):
		if not (regions[i] is Dictionary):
			continue
		var region: Dictionary = regions[i] as Dictionary
		var marker := "●" if i < int(c.strategic_state.get("region_index", 0)) else ("◆" if i == int(c.strategic_state.get("region_index", 0)) else "○")
		parts.append("%s %s" % [marker, str(region.get("region_title", ""))])
	return " / ".join(parts)

func strategic_type_label(node_type: String) -> String:
	match node_type:
		"combat_common": return "普通战斗"
		"combat_elite": return "强敌"
		"military": return "军功"
		"case": return "旧案"
		"reputation": return "清望"
		"rest": return "休整"
		"risk": return "风险"
	return node_type

func strategic_effects_text(effects: Dictionary) -> String:
	var parts: Array[String] = []
	var labels := {
		"military_merit": "军功",
		"clean_reputation": "清望",
		"case_clues": "旧案",
	}
	for key in labels.keys():
		var value := int(effects.get(key, 0))
		if value != 0:
			parts.append("%s %+d" % [str(labels[key]), value])
	var card_rewards := card_reward_ids_from_effects(effects.get("card_rewards", []))
	if not card_rewards.is_empty():
		parts.append("招式 +%d" % card_rewards.size())
	return "收益：%s" % (" / ".join(parts) if not parts.is_empty() else "无")

func strategic_combat_pool_text(node: Dictionary) -> String:
	if not str(node.get("node_type", "")).begins_with("combat_"):
		return ""
	var pool_id := str(node.get("combat_pool_id", ""))
	var recommended_min := int(node.get("recommended_martial_min", 0))
	var recommended_max := int(node.get("recommended_martial_max", 0))
	var enemy_martial := int(node.get("enemy_martial_level", 0))
	if pool_id.is_empty():
		return ""
	return "敌类%s 武境%d-%d 敌%d" % [pool_id, recommended_min, recommended_max, enemy_martial]
