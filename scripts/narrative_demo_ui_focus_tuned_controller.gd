extends "res://scripts/narrative_demo_ui_focus_controller.gd"

const StrategicMapGenerator := preload("res://scripts/strategic_map_generator.gd")
const StrategicMapState := preload("res://scripts/strategic_map_state.gd")
const STRATEGIC_ENTRY_NODE_ID := "military_coverup"
const STRATEGIC_FINAL_BOSS_SOURCE_ID := "strategic_final_boss"

# Final UI tuning layer.
# Keeps narrative presentation simple: static scene art + caption + bottom floating choices.
# Motion/effects are disabled at the cinematic controller source; this layer only
# applies layout polish and hides optional debug/map UI.

const TUNED_STORY_FONT_SIZE := 72
const TUNED_OPTION_FONT_SIZE := 25
const TUNED_CAPTION_OFFSET_Y := 30

var strategic_config: Dictionary = {}
var strategic_state: Dictionary = StrategicMapState.default_state()
var pending_strategic_ending_render := false
var pending_strategic_card_node: Dictionary = {}
var pending_strategic_card_choices: Array[String] = []
var selected_strategic_card_reward := ""

func _ready() -> void:
	_load_strategic_map_config()
	super._ready()
	_apply_tuned_scene_art_view()

func _process(delta: float) -> void:
	super._process(delta)
	_apply_tuned_scene_art_view()

func _render() -> void:
	if pending_strategic_ending_render and _base_ui_ready():
		pending_strategic_ending_render = false
		super._advance_to_node(_flow_count(), last_hint)
		return
	if bool(strategic_state.get("active", false)):
		if not _base_ui_ready():
			return
		_clear_dynamic_boxes()
		_render_strategic_map()
		BattleFontHelper.enforce(self)
		_apply_focus_ui()
		_hide_scene_art_overlay_nodes()
		return
	super._render()
	_apply_tuned_scene_art_view()

func _narrative_state_snapshot() -> Dictionary:
	var snapshot := super._narrative_state_snapshot()
	snapshot["strategic_state"] = strategic_state.duplicate(true)
	return snapshot

func _restore_narrative_state_from_context() -> void:
	super._restore_narrative_state_from_context()
	var state := NarrativeBattleContext.get_narrative_state()
	var strategic_variant = state.get("strategic_state", {})
	if strategic_variant is Dictionary:
		strategic_state = (strategic_variant as Dictionary).duplicate(true)
		_sync_context_cards_to_strategic_state()

func _restart() -> void:
	strategic_state = StrategicMapState.default_state()
	super._restart()

func _consume_battle_result_if_needed() -> void:
	if not NarrativeBattleContext.has_result():
		return
	var source_id := NarrativeBattleContext.source_node_id
	var result := NarrativeBattleContext.last_result
	if source_id == STRATEGIC_FINAL_BOSS_SOURCE_ID:
		if result == "win":
			var boss: Dictionary = strategic_state.get("final_boss", {})
			selected_ending_flag = str(boss.get("ending_flag", "surface_pirate"))
			strategic_state["active"] = false
			strategic_state["completed"] = true
			last_hint = "终局战胜利：%s" % str(boss.get("title", "海门收束"))
			NarrativeBattleContext.clear()
			_save_narrative_state_to_context()
			if _base_ui_ready():
				super._advance_to_node(_flow_count(), last_hint)
			else:
				pending_strategic_ending_render = true
			return
		last_hint = "终局战返回：当前暂不推进，可再次挑战。"
		NarrativeBattleContext.clear()
		_save_narrative_state_to_context()
		return
	if source_id.begins_with("map_"):
		_consume_strategic_node_battle(source_id, result)
		NarrativeBattleContext.clear()
		_save_narrative_state_to_context()
		return
	super._consume_battle_result_if_needed()

func _advance_to_node(target_index: int, hint: String = "") -> void:
	if target_index < _flow_count() and _node_id_at(target_index) == STRATEGIC_ENTRY_NODE_ID and not bool(strategic_state.get("completed", false)):
		_start_strategic_map("破船之后，海疆大势图展开。")
		return
	super._advance_to_node(target_index, hint)

func _load_strategic_map_config() -> void:
	strategic_config = StrategicMapGenerator.load_config()

func _start_strategic_map(hint: String = "") -> void:
	if strategic_config.is_empty():
		last_hint = "大势图配置缺失，暂回到军门压案。"
		super._advance_to_node(_flow_count() - 1, last_hint)
		return
	var base := StrategicMapState.default_state()
	base["active"] = true
	base["seed"] = 1701 + jun_gong * 17 + qing_wang * 31 + clues * 43
	base["military_merit"] = jun_gong
	base["clean_reputation"] = qing_wang
	base["case_clues"] = clues
	var profile := NarrativeBattleContext.get_player_profile()
	base["martial_level"] = int(profile.get("martial_level", 1))
	base = StrategicMapState.sync_card_state_from_profile(base, profile)
	base["current_map"] = StrategicMapGenerator.generate_map(strategic_config, base, int(base["seed"]))
	strategic_state = base
	last_hint = hint
	_save_narrative_state_to_context()
	if _base_ui_ready():
		_render()

func _base_ui_ready() -> bool:
	return title_label != null \
		and status_label != null \
		and map_label != null \
		and scene_label != null \
		and body_label != null \
		and vars_label != null \
		and map_buttons_box != null \
		and combat_buttons_box != null \
		and choices_box != null

func _render_strategic_map() -> void:
	_refresh_current_strategic_layer()
	var map_data: Dictionary = strategic_state.get("current_map", {})
	var region_index := int(strategic_state.get("region_index", 0))
	var layer_index := int(strategic_state.get("layer_index", 0))
	var region := StrategicMapGenerator.current_region(map_data, region_index)
	var layer := StrategicMapGenerator.current_layer(map_data, region_index, layer_index)
	if region.is_empty() or layer.is_empty():
		_prepare_strategic_final_gate()
		return
	title_label.text = "海疆大势图"
	status_label.text = "%s｜第 %d 层" % [str(region.get("region_title", "海疆")), layer_index + 1]
	map_label.text = _strategic_progress_text(map_data)
	scene_label.text = _format_scene_text("军情、海防与旧案线索被摊在同一张图上。")
	_render_visual("res://assets/pixel_battle/backgrounds/map_march_coast.png", "海疆大势图")
	body_label.text = "你不再只沿着一条案线走。\n\n每一步只看四件事：军功、清望、旧案、武境。"
	if not last_hint.is_empty():
		body_label.text += "\n\n[i]%s[/i]" % last_hint
	vars_label.text = StrategicMapState.summary_text(strategic_state)
	_add_placeholder(map_buttons_box, "每层三选一。选中后应用收益；战斗节点会跳转 MainVisual。")
	_add_placeholder(combat_buttons_box, "当前层候选节点")
	var choices: Array = layer.get("choices", [])
	for i in range(choices.size()):
		if choices[i] is Dictionary:
			_add_strategic_choice_button(choices[i] as Dictionary, i)

func _refresh_current_strategic_layer() -> void:
	var map_data: Dictionary = strategic_state.get("current_map", {})
	var region_index := int(strategic_state.get("region_index", 0))
	var layer_index := int(strategic_state.get("layer_index", 0))
	var layer := StrategicMapGenerator.current_layer(map_data, region_index, layer_index)
	var martial_level := int(strategic_state.get("martial_level", 1))
	if int(layer.get("generated_for_martial_level", -1)) == martial_level:
		return
	var seed_value := int(strategic_state.get("seed", 1701)) + region_index * 101 + layer_index * 17 + martial_level * 1009
	var refreshed := StrategicMapGenerator.refresh_layer(strategic_config, map_data, strategic_state, region_index, layer_index, seed_value)
	if refreshed.is_empty():
		return
	var regions: Array = map_data.get("regions", [])
	if region_index < 0 or region_index >= regions.size() or not (regions[region_index] is Dictionary):
		return
	var region := regions[region_index] as Dictionary
	var layers: Array = region.get("layers", [])
	if layer_index < 0 or layer_index >= layers.size():
		return
	layers[layer_index] = refreshed
	region["layers"] = layers
	regions[region_index] = region
	map_data["regions"] = regions
	strategic_state["current_map"] = map_data

func _strategic_progress_text(map_data: Dictionary) -> String:
	var regions: Array = map_data.get("regions", [])
	var parts: Array[String] = []
	for i in range(regions.size()):
		if not (regions[i] is Dictionary):
			continue
		var region: Dictionary = regions[i]
		var marker := "●" if i < int(strategic_state.get("region_index", 0)) else ("◆" if i == int(strategic_state.get("region_index", 0)) else "○")
		parts.append("%s %s" % [marker, str(region.get("region_title", ""))])
	return " / ".join(parts)

func _add_strategic_choice_button(node: Dictionary, index: int) -> void:
	var effects: Dictionary = node.get("effects", {})
	var btn := Button.new()
	var scope_text := StrategicMapState.event_scope_text(node)
	var combat_text := _strategic_combat_pool_text(node)
	btn.text = "%s｜%s%s%s\n%s\n%s" % [
		str(node.get("title", "")),
		_strategic_type_label(str(node.get("node_type", ""))),
		"｜%s" % scope_text if not scope_text.is_empty() else "",
		"｜%s" % combat_text if not combat_text.is_empty() else "",
		str(node.get("preview_text", "")),
		_strategic_effects_text(effects),
	]
	btn.custom_minimum_size = Vector2(0, 76)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.pressed.connect(_on_strategic_choice.bind(index))
	choices_box.add_child(btn)

func _on_strategic_choice(index: int) -> void:
	var layer := StrategicMapGenerator.current_layer(strategic_state.get("current_map", {}), int(strategic_state.get("region_index", 0)), int(strategic_state.get("layer_index", 0)))
	var choices: Array = layer.get("choices", [])
	if index < 0 or index >= choices.size() or not (choices[index] is Dictionary):
		return
	var node := choices[index] as Dictionary
	if _strategic_node_triggers_combat(node):
		_store_pending_choice(str(node.get("node_id", "")), {
			"label": str(node.get("title", "")),
			"result": str(node.get("result_text", "")),
			"effects": node.get("effects", {}),
		})
		_sync_strategic_cards_to_context()
		_save_narrative_state_to_context()
		NarrativeBattleContext.set_request_from_combat({
			"enabled": true,
			"encounter_id": str(node.get("encounter_id", "")),
			"battle_id": str(node.get("battle_id", "")),
			"override_player_profile": true,
			"combat_pool_id": str(node.get("combat_pool_id", "")),
			"recommended_martial_min": int(node.get("recommended_martial_min", 0)),
			"recommended_martial_max": int(node.get("recommended_martial_max", 0)),
			"enemy_martial_level": int(node.get("enemy_martial_level", 0)),
		}, str(node.get("node_id", "")))
		get_tree().change_scene_to_file("res://scenes/MainVisual.tscn")
		return
	var reward_choices := _strategic_card_reward_choices(node)
	if not reward_choices.is_empty():
		_show_strategic_card_reward_choice(node, reward_choices)
		return
	_apply_strategic_node(node)
	_advance_strategic_cursor()
	_save_narrative_state_to_context()
	_render()

func _consume_strategic_node_battle(source_id: String, result: String) -> void:
	var pending := _load_pending_choice()
	if result != "win":
		last_hint = "大势图战斗未胜：当前层暂不推进。"
		_clear_pending_choice()
		return
	var node := _find_strategic_node(source_id)
	if node.is_empty():
		last_hint = "大势图战斗胜利：未找到节点配置，暂不结算。"
		_clear_pending_choice()
		return
	_apply_strategic_node(node)
	NarrativeBattleContext.apply_player_growth("battle_win", 0, 0, 0, true)
	var profile := NarrativeBattleContext.get_player_profile()
	strategic_state = StrategicMapState.apply_battle_win(strategic_state, profile)
	strategic_state["martial_level"] = int(profile.get("martial_level", strategic_state.get("martial_level", 1)))
	if not pending.is_empty():
		strategic_state["last_node_result"] = str(pending.get("result", strategic_state.get("last_node_result", "")))
	_advance_strategic_cursor()
	_clear_pending_choice()

func _apply_strategic_node(node: Dictionary) -> void:
	_sync_context_cards_to_strategic_state()
	var effects: Dictionary = node.get("effects", {})
	strategic_state = StrategicMapState.apply_effects(strategic_state, effects)
	_sync_strategic_cards_to_context()
	_sync_context_cards_to_strategic_state()
	jun_gong = int(strategic_state.get("military_merit", jun_gong))
	qing_wang = int(strategic_state.get("clean_reputation", qing_wang))
	clues = int(strategic_state.get("case_clues", clues))
	var selected: Array = strategic_state.get("selected_nodes", [])
	selected.append(str(node.get("node_id", "")))
	strategic_state["selected_nodes"] = selected
	var result_text := str(node.get("result_text", ""))
	strategic_state["last_node_result"] = result_text
	last_hint = result_text


func _strategic_card_reward_choices(node: Dictionary) -> Array[String]:
	var effects: Dictionary = node.get("effects", {})
	var ids := _card_reward_ids_from_effects(effects.get("card_rewards", []))
	if ids.is_empty():
		return []
	var owned := _card_reward_ids_from_effects(strategic_state.get("owned_card_ids", []))
	var fresh: Array[String] = []
	for card_id: String in ids:
		if not (card_id in owned):
			fresh.append(card_id)
	var candidates := fresh if not fresh.is_empty() else ids
	candidates.shuffle()
	return candidates.slice(0, mini(3, candidates.size()))


func _show_strategic_card_reward_choice(node: Dictionary, card_ids: Array[String]) -> void:
	pending_strategic_card_node = node.duplicate(true)
	pending_strategic_card_choices = card_ids.duplicate()
	selected_strategic_card_reward = ""
	_clear_dynamic_boxes()
	title_label.text = str(node.get("title", "得招"))
	status_label.text = "%s / 招式抉择" % _strategic_type_label(str(node.get("node_type", "")))
	map_label.text = _strategic_progress_text(strategic_state.get("current_map", {}))
	scene_label.text = _format_scene_text(str(node.get("preview_text", "")))
	_render_visual(str(node.get("visual_path", "")), str(node.get("title", "得招")))
	body_label.text = "%s\n\n选择 1 张新招式加入长期牌库，然后确认。" % str(node.get("result_text", "你得了一次整理招式的机会。"))
	vars_label.text = StrategicMapState.summary_text(strategic_state)
	_add_placeholder(map_buttons_box, "卡牌奖励不会自动发放，需先三选一。")
	_add_placeholder(combat_buttons_box, "非战斗节点")
	for card_id: String in pending_strategic_card_choices:
		var btn := Button.new()
		btn.text = _strategic_card_choice_text(card_id, false)
		btn.custom_minimum_size = Vector2(0, 76)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.pressed.connect(_select_strategic_card_reward.bind(card_id))
		choices_box.add_child(btn)
	var confirm := Button.new()
	confirm.name = "StrategicCardRewardConfirm"
	confirm.text = "确认"
	confirm.disabled = true
	confirm.custom_minimum_size = Vector2(0, 64)
	confirm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	confirm.pressed.connect(_confirm_strategic_card_reward)
	choices_box.add_child(confirm)
	var cancel := Button.new()
	cancel.text = "返回本层选择"
	cancel.custom_minimum_size = Vector2(0, 54)
	cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cancel.pressed.connect(_cancel_strategic_card_reward)
	choices_box.add_child(cancel)
	BattleFontHelper.enforce(self)
	_apply_focus_ui()
	_hide_scene_art_overlay_nodes()


func _select_strategic_card_reward(card_id: String) -> void:
	selected_strategic_card_reward = card_id
	for child in choices_box.get_children():
		if child is Button:
			var btn := child as Button
			if btn.name == "StrategicCardRewardConfirm":
				btn.disabled = selected_strategic_card_reward.is_empty()
				continue
			if card_id in pending_strategic_card_choices:
				for choice_id: String in pending_strategic_card_choices:
					if btn.text.find(_strategic_card_label(choice_id)) >= 0:
						btn.text = _strategic_card_choice_text(choice_id, choice_id == card_id)
	body_label.text = "%s\n\n已选择：%s" % [str(pending_strategic_card_node.get("result_text", "")), _strategic_card_label(card_id)]


func _confirm_strategic_card_reward() -> void:
	if pending_strategic_card_node.is_empty() or selected_strategic_card_reward.is_empty():
		return
	var node := pending_strategic_card_node.duplicate(true)
	var effects: Dictionary = node.get("effects", {})
	effects["card_rewards"] = [selected_strategic_card_reward]
	node["effects"] = effects
	pending_strategic_card_node.clear()
	pending_strategic_card_choices.clear()
	selected_strategic_card_reward = ""
	_apply_strategic_node(node)
	_advance_strategic_cursor()
	_save_narrative_state_to_context()
	_render()


func _cancel_strategic_card_reward() -> void:
	pending_strategic_card_node.clear()
	pending_strategic_card_choices.clear()
	selected_strategic_card_reward = ""
	_render()


func _strategic_card_choice_text(card_id: String, selected: bool) -> String:
	var prefix := "✓ " if selected else ""
	return "%s%s\n%s" % [prefix, _strategic_card_label(card_id), _strategic_card_hint(card_id)]


func _strategic_card_label(card_id: String) -> String:
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


func _strategic_card_hint(card_id: String) -> String:
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

func _sync_context_cards_to_strategic_state() -> void:
	var profile := NarrativeBattleContext.get_player_profile()
	if profile.is_empty():
		return
	strategic_state = StrategicMapState.sync_card_state_from_profile(strategic_state, profile)

func _sync_strategic_cards_to_context() -> void:
	if not NarrativeBattleContext.has_player_profile():
		return
	NarrativeBattleContext.set_player_card_state(strategic_state.get("owned_card_ids", []), strategic_state.get("selected_loadout_ids", []), strategic_state.get("deck_slots", []), int(strategic_state.get("active_deck_index", 0)))

func _advance_strategic_cursor() -> void:
	var cursor := StrategicMapGenerator.advance_cursor(strategic_state.get("current_map", {}), int(strategic_state.get("region_index", 0)), int(strategic_state.get("layer_index", 0)))
	strategic_state["region_index"] = int(cursor.get("region_index", 0))
	strategic_state["layer_index"] = int(cursor.get("layer_index", 0))
	if StrategicMapGenerator.is_map_complete(strategic_state.get("current_map", {}), int(strategic_state.get("region_index", 0)), int(strategic_state.get("layer_index", 0))):
		if _base_ui_ready():
			_prepare_strategic_final_gate()
		else:
			strategic_state["final_boss"] = StrategicMapGenerator.select_final_boss(strategic_config, strategic_state)

func _prepare_strategic_final_gate() -> void:
	var boss := StrategicMapGenerator.select_final_boss(strategic_config, strategic_state)
	strategic_state["final_boss"] = boss
	if not _base_ui_ready():
		return
	title_label.text = "海门收束"
	status_label.text = str(boss.get("title", "终局门槛"))
	map_label.text = "大势图已走完：%d 个节点" % [(strategic_state.get("selected_nodes", []) as Array).size()]
	scene_label.text = _format_scene_text("海门风紧，所有线索都被推到最后一战前。")
	_render_visual("res://assets/pixel_battle/backgrounds/battle_bg_broken_ship.png", "海门收束")
	body_label.text = str(boss.get("intro_text", "倭患仍在海上。案卷仍少一页。"))
	if not last_hint.is_empty():
		body_label.text += "\n\n[i]%s[/i]" % last_hint
	vars_label.text = StrategicMapState.summary_text(strategic_state)
	_add_placeholder(map_buttons_box, "终局版本由军功、清望、旧案、武境共同决定。")
	_add_button(combat_buttons_box, "进入终局战：%s" % str(boss.get("title", "海门收束")), _on_strategic_final_boss)
	_add_placeholder(choices_box, "终局战胜利后进入对应结局。")

func _on_strategic_final_boss() -> void:
	var boss: Dictionary = strategic_state.get("final_boss", {})
	if boss.is_empty():
		boss = StrategicMapGenerator.select_final_boss(strategic_config, strategic_state)
		strategic_state["final_boss"] = boss
	_sync_strategic_cards_to_context()
	_save_narrative_state_to_context()
	NarrativeBattleContext.set_request_from_combat({
		"enabled": true,
		"encounter_id": str(boss.get("encounter_id", "enc_boss_ext_wakou_leader")),
		"battle_id": str(boss.get("battle_id", "boss_ext_wakou_leader")),
		"override_player_profile": true,
	}, STRATEGIC_FINAL_BOSS_SOURCE_ID)
	get_tree().change_scene_to_file("res://scenes/MainVisual.tscn")

func _find_strategic_node(node_id: String) -> Dictionary:
	var node_pool: Array = strategic_config.get("node_pool", [])
	for item in node_pool:
		if item is Dictionary and str((item as Dictionary).get("node_id", "")) == node_id:
			return (item as Dictionary).duplicate(true)
	return {}

func _strategic_node_triggers_combat(node: Dictionary) -> bool:
	return str(node.get("node_type", "")).begins_with("combat_") and not str(node.get("encounter_id", "")).is_empty()

func _strategic_type_label(node_type: String) -> String:
	match node_type:
		"combat_common": return "普通战斗"
		"combat_elite": return "强敌"
		"military": return "军功"
		"case": return "旧案"
		"reputation": return "清望"
		"rest": return "休整"
		"risk": return "风险"
	return node_type

func _strategic_effects_text(effects: Dictionary) -> String:
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
	var card_rewards := _card_reward_ids_from_effects(effects.get("card_rewards", []))
	if not card_rewards.is_empty():
		parts.append("招式 +%d" % card_rewards.size())
	return "收益：%s" % (" / ".join(parts) if not parts.is_empty() else "无")

func _card_reward_ids_from_effects(value) -> Array[String]:
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

func _strategic_combat_pool_text(node: Dictionary) -> String:
	if not str(node.get("node_type", "")).begins_with("combat_"):
		return ""
	var pool_id := str(node.get("combat_pool_id", ""))
	var recommended_min := int(node.get("recommended_martial_min", 0))
	var recommended_max := int(node.get("recommended_martial_max", 0))
	var enemy_martial := int(node.get("enemy_martial_level", 0))
	if pool_id.is_empty():
		return ""
	return "敌类%s 武境%d-%d 敌%d" % [pool_id, recommended_min, recommended_max, enemy_martial]

func _ending_data_for_flag(flag: String) -> Dictionary:
	match flag:
		"true_resolution":
			return {
				"id": "true_resolution",
				"title": "结局：海门真收束",
				"status": "海门真收束",
				"text": "堂上开卷。\n\n海门起风。\n\n这一次，军令、人声、旧案都没有退。",
				"feedback": "军功让你进堂，旧案让你说话，清望让别人敢信。"
			}
		"court_exposure":
			return {
				"id": "court_exposure",
				"title": "结局：堂审翻案",
				"status": "堂审翻案",
				"text": "案卷被迫摊开。\n\n堂外很静。\n\n你赢了一场堂审，却还要等人敢抬头。\n\n然而这就是事情的真相吗？",
				"feedback": "军功和旧案足以开卷，但清望不足时，真相仍显得孤。"
			}
		"reputation_redress":
			return {
				"id": "reputation_redress",
				"title": "结局：清望昭雪",
				"status": "清望昭雪",
				"text": "堂上无人开口。\n\n堂外，有人替你跪了一地。\n\n案卷终于不能只在灯下合上。\n\n然而这就是事情的真相吗？",
				"feedback": "清望让别人敢信你，旧案因此有了见光的缝。"
			}
		"military_reputation":
			return {
				"id": "military_reputation",
				"title": "结局：封海得众",
				"status": "封海得众",
				"text": "海口封住了。\n\n百姓没有散。\n\n你第一次觉得军令也能护住活人。\n\n然而这就是你想要的吗？",
				"feedback": "军功给你权力，清望让权力没有只剩冷铁。"
			}
		"private_truth":
			return {
				"id": "private_truth",
				"title": "结局：私查真相",
				"status": "私查真相",
				"text": "箭从岸上来。\n\n这一次，没有人替他灭口。\n\n师父站得很远。\n\n然而这就是事情的真相吗？",
				"feedback": "旧案让你说得出话，但没有足够军功时，真相仍难进堂。"
			}
		"military_promotion":
			return {
				"id": "military_promotion",
				"title": "结局：军功升迁",
				"status": "军功升迁",
				"text": "你升入卫中。\n\n旧案也封在卫中。\n\n潮声隔着官印，仍然很近。\n\n然而这就是你想要的吗？",
				"feedback": "军功让你进得了堂，也让堂门在你身后落锁。"
			}
		"isolated_evidence":
			return {
				"id": "isolated_evidence",
				"title": "结局：孤证难鸣",
				"status": "孤证难鸣",
				"text": "你知道箭从哪里来。\n\n纸也知道。\n\n可是堂上没有人接这句话。\n\n然而这就是事情的真相吗？",
				"feedback": "旧案足够深，但军功和清望都不足时，真相只能先活在你手里。"
			}
		"martial_survival":
			return {
				"id": "martial_survival",
				"title": "结局：武境破围",
				"status": "武境破围",
				"text": "你杀出海门。\n\n身后火起，堂上灯灭。\n\n旧案没有开卷，但没人再敢轻易灭你的口。\n\n然而这就是你想要的吗？",
				"feedback": "武境能让你活下来，却不能替你赢得堂口和人心。"
			}
		"surface_pirate":
			return {
				"id": "surface_pirate",
				"title": "结局：表层平倭",
				"status": "表层平倭",
				"text": "倭患平了。\n\n案卷仍少一页。\n\n师父没有看你。\n\n然而这就是你想要的吗？",
				"feedback": "表面的海寇被清掉了，旧案还在潮下。"
			}
	return super._ending_data_for_flag(flag)

func _ending_catalog() -> Array[Dictionary]:
	var catalog: Array[Dictionary] = []
	for flag in [
		"true_resolution",
		"court_exposure",
		"reputation_redress",
		"military_reputation",
		"military_promotion",
		"private_truth",
		"isolated_evidence",
		"martial_survival",
		"surface_pirate",
	]:
		var ending := _ending_data_for_flag(flag)
		if not ending.is_empty():
			catalog.append(ending)
	return catalog

func _ensure_focus_story_caption() -> void:
	if focus_story_layer != null:
		return
	focus_story_layer = Control.new()
	focus_story_layer.name = "NarrativePerformanceCaptionLayer"
	focus_story_layer.anchor_left = 0.0
	focus_story_layer.anchor_top = 0.0
	focus_story_layer.anchor_right = 1.0
	focus_story_layer.anchor_bottom = 1.0
	focus_story_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_story_layer.z_index = 90
	focus_story_layer.z_as_relative = false
	add_child(focus_story_layer)

	focus_story_panel = PanelContainer.new()
	focus_story_panel.name = "NarrativePerformanceCaptionPanel"
	focus_story_panel.anchor_left = 0.06
	focus_story_panel.anchor_top = PERFORMANCE_CAPTION_TOP
	focus_story_panel.anchor_right = 0.94
	focus_story_panel.anchor_bottom = PERFORMANCE_CAPTION_BOTTOM
	focus_story_panel.offset_top = TUNED_CAPTION_OFFSET_Y
	focus_story_panel.offset_bottom = TUNED_CAPTION_OFFSET_Y
	focus_story_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_story_panel.z_index = 91
	focus_story_panel.add_theme_stylebox_override("panel", _transparent_panel_style())
	focus_story_layer.add_child(focus_story_panel)

	focus_story_label = RichTextLabel.new()
	focus_story_label.name = "NarrativePerformanceCaptionText"
	focus_story_label.bbcode_enabled = true
	focus_story_label.fit_content = false
	focus_story_label.scroll_active = false
	focus_story_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_story_label.add_theme_font_size_override("normal_font_size", TUNED_STORY_FONT_SIZE)
	focus_story_label.add_theme_font_size_override("bold_font_size", TUNED_STORY_FONT_SIZE)
	focus_story_label.add_theme_font_size_override("italics_font_size", TUNED_STORY_FONT_SIZE)
	focus_story_label.add_theme_color_override("default_color", Color("f6ead2"))
	focus_story_panel.add_child(focus_story_label)

func _style_button_box(box: VBoxContainer) -> void:
	if box == null:
		return
	box.visible = true
	box.add_theme_constant_override("separation", 16)
	for child in box.get_children():
		if child is Button:
			var btn := child as Button
			btn.visible = true
			btn.custom_minimum_size = Vector2(0, 92)
			btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			btn.add_theme_font_size_override("font_size", TUNED_OPTION_FONT_SIZE)
		elif child is Label:
			_hide_control(child as Control)

func _apply_tuned_scene_art_view() -> void:
	_pin_cinematic_background()
	_make_operation_panel_floating()
	_hide_scene_art_overlay_ui()

func _pin_cinematic_background() -> void:
	if cinematic_bg == null:
		return
	cinematic_bg.visible = true
	cinematic_bg.scale = Vector2.ONE
	cinematic_bg.position = Vector2.ZERO
	cinematic_bg.rotation = 0.0
	cinematic_bg.pivot_offset = Vector2.ZERO
	cinematic_bg.modulate = Color.WHITE
	cinematic_bg.self_modulate = Color.WHITE
	cinematic_bg.material = null
	cinematic_bg.offset_left = 0.0
	cinematic_bg.offset_top = 0.0
	cinematic_bg.offset_right = 0.0
	cinematic_bg.offset_bottom = 0.0

func _make_operation_panel_floating() -> void:
	var operation_panel := _find_operation_panel()
	if operation_panel == null:
		return
	operation_panel.add_theme_stylebox_override("panel", _transparent_panel_style())
	operation_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var margin := operation_panel.get_child(0) if operation_panel.get_child_count() > 0 else null
	if margin is MarginContainer:
		var margin_container := margin as MarginContainer
		margin_container.add_theme_constant_override("margin_left", 0)
		margin_container.add_theme_constant_override("margin_right", 0)
		margin_container.add_theme_constant_override("margin_top", 0)
		margin_container.add_theme_constant_override("margin_bottom", 0)

func _hide_scene_art_overlay_ui() -> void:
	_hide_canvas_item(cinematic_mist)
	_hide_canvas_item(cinematic_fire)
	_hide_canvas_item(cinematic_dim)
	_hide_canvas_item(cinematic_focus)
	_hide_canvas_item(cinematic_master)
	_hide_canvas_item(cinematic_hero)
	_hide_canvas_item(world_map_layer)
	_hide_canvas_item(world_map_panel)
	_hide_canvas_item(focus_world_map_layer)
	_hide_canvas_item(focus_world_map_panel)
	_hide_canvas_item(focus_debug_layer)
	_hide_canvas_item(focus_debug_panel)
	if visual_debug_label != null:
		visual_debug_label.visible = false
		visual_debug_label.custom_minimum_size = Vector2.ZERO

func _hide_canvas_item(node: CanvasItem) -> void:
	if node == null:
		return
	node.visible = false
	node.modulate = Color(1.0, 1.0, 1.0, 0.0)
	node.self_modulate = Color(1.0, 1.0, 1.0, 0.0)
	node.material = null
	if node is Control:
		var control := node as Control
		control.mouse_filter = Control.MOUSE_FILTER_IGNORE
		control.custom_minimum_size = Vector2.ZERO

func _transparent_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	style.border_color = Color(0.0, 0.0, 0.0, 0.0)
	style.set_border_width_all(0)
	style.set_corner_radius_all(0)
	style.content_margin_left = 0
	style.content_margin_right = 0
	style.content_margin_top = 0
	style.content_margin_bottom = 0
	return style
