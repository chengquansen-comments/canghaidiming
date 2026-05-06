extends RefCounted

const StrategicMapState := preload("res://scripts/strategic_map_state.gd")
const StrategicRewardView := preload("res://scripts/narrative/strategic_reward_view.gd")

var c
var _reward_view

func _init(controller) -> void:
	c = controller

func _view():
	if _reward_view == null:
		_reward_view = StrategicRewardView.new(c)
	return _reward_view

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
	_view().render_reward_choice(
		node,
		card_ids,
		Callable(c, "_select_strategic_card_reward"),
		Callable(c, "_confirm_strategic_card_reward"),
		Callable(c, "_cancel_strategic_card_reward")
	)

func select_strategic_card_reward(card_id: String) -> void:
	c.selected_strategic_card_reward = card_id
	_view().refresh_selected_card(card_id, c.pending_strategic_card_choices, c.pending_strategic_card_node)

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
