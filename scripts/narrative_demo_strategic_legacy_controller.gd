extends "res://scripts/narrative_demo_ui_focus_controller.gd"

const StrategicMapGenerator := preload("res://scripts/strategic_map_generator.gd")
const StrategicMapState := preload("res://scripts/strategic_map_state.gd")
const StrategicNetworkMapGenerator := preload("res://scripts/strategic_network_map_generator.gd")
const StrategicNetworkBattleBridge := preload("res://scripts/strategic_network_battle_bridge.gd")
const StrategicEndingFormatter := preload("res://scripts/narrative/strategic_ending_formatter.gd")
const StrategicRewardRuntime := preload("res://scripts/narrative/strategic_reward_runtime.gd")
const STRATEGIC_ENTRY_NODE_ID := "world_map_entry"
const STRATEGIC_FINAL_BOSS_SOURCE_ID := "strategic_final_boss"

var strategic_config: Dictionary = {}
var strategic_state: Dictionary = StrategicMapState.default_state()
var pending_strategic_ending_render := false
var pending_strategic_card_node: Dictionary = {}
var pending_strategic_card_choices: Array[String] = []
var selected_strategic_card_reward := ""
var _strategic_reward_runtime
var _strategic_ending_formatter

# Legacy strategic-map layer.
# Keeps the old current_map / three-choice fallback and shared strategic state.

func _load_strategic_map_config() -> void:
	strategic_config = StrategicMapGenerator.load_config()

func _reward_runtime():
	if _strategic_reward_runtime == null:
		_strategic_reward_runtime = StrategicRewardRuntime.new(self)
	return _strategic_reward_runtime

func _ending_formatter():
	if _strategic_ending_formatter == null:
		_strategic_ending_formatter = StrategicEndingFormatter.new()
	return _strategic_ending_formatter
func _try_consume_debug_world_map_entry() -> void:
	if not NarrativeBattleContext.has_debug_entry():
		return
	var entry := NarrativeBattleContext.consume_debug_entry()
	if str(entry.get("mode", "")) != "world_map":
		return
	var role := str(entry.get("player_role", "spearman"))
	var martial_level: int = max(1, int(entry.get("martial_level", 1)))
	_ensure_debug_world_map_player_profile(role, martial_level)
	jun_gong = 1
	qing_wang = 1
	clues = 1
	_start_strategic_map("Debug：直接进入海疆大势图。")
func _ensure_debug_world_map_player_profile(role: String = "spearman", martial_level: int = 1) -> void:
	if NarrativeBattleContext.has_player_profile():
		return
	var owned_card_ids: Array[String] = []
	if role == "blademaster":
		owned_card_ids = [
			"blade_press_break",
			"blade_press_break",
			"blade_hook_pull",
			"blade_hook_pull",
			"blade_body_press",
			"blade_body_press",
			"reward_guard",
			"reward_guard",
		]
	else:
		owned_card_ids = [
			"spear_step_thrust",
			"spear_step_thrust",
			"spear_retreat_sting",
			"spear_retreat_sting",
			"reward_push",
			"reward_push",
			"reward_guard",
			"reward_guard",
		]
	var selected_loadout_ids := owned_card_ids.duplicate()
	NarrativeBattleContext.set_player_profile({
		"role": role,
		"career": "调试武生",
		"weapon": "长枪" if role == "spearman" else "腰刀",
		"martial_level": martial_level,
		"max_hp": 32,
		"hp": 32,
		"max_posture": 10,
		"posture": 5,
		"qinggong": 1,
		"owned_card_ids": owned_card_ids,
		"selected_loadout_ids": selected_loadout_ids,
		"deck_slots": [],
		"active_deck_index": 0,
		"debug_profile": true,
	})
func _start_strategic_map(hint: String = "") -> void:
	if strategic_config.is_empty():
		last_hint = "大势图配置缺失，暂按线性节点继续。"
		super._advance_to_node(node_index + 1, last_hint)
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
	base["network_map"] = StrategicNetworkMapGenerator.generate_network_map(strategic_config, base, int(base["seed"]))
	var network_map: Dictionary = base.get("network_map", {}) as Dictionary
	base["selected_node_id"] = str(network_map.get("selected_node_id", ""))
	base["available_node_ids"] = (network_map.get("available_node_ids", []) as Array).duplicate(true)
	base["completed_node_ids"] = (network_map.get("completed_node_ids", []) as Array).duplicate(true)
	base["current_node_id"] = str(network_map.get("current_node_id", ""))
	base["pending_map_node_id"] = str(network_map.get("pending_map_node_id", ""))
	base["pending_result_text"] = str(network_map.get("pending_result_text", ""))
	base["pending_effects"] = (network_map.get("pending_effects", {}) as Dictionary).duplicate(true)
	print(StrategicNetworkMapGenerator.summarize_network_map(network_map))
	strategic_state = base
	_sync_world_map_runtime_state()
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
func _render_legacy_strategic_map() -> void:
	_refresh_current_strategic_layer()
	var map_data: Dictionary = strategic_state.get("current_map", {}) as Dictionary
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
	var map_data: Dictionary = strategic_state.get("current_map", {}) as Dictionary
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
	_sync_world_map_runtime_state()
func _strategic_progress_text(map_data: Dictionary) -> String:
	return _reward_runtime().strategic_progress_text(map_data)
func _add_strategic_choice_button(node: Dictionary, index: int) -> void:
	var effects: Dictionary = node.get("effects", {}) as Dictionary
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
		var request := StrategicNetworkBattleBridge.combat_request_for_node(node)
		if not bool(request.get("enabled", false)):
			last_hint = str(request.get("blocked_reason", "该战斗节点暂未接入。"))
			_render()
			return
		strategic_state["current_world_map_node_id"] = str(node.get("node_id", ""))
		strategic_state["current_world_map_node_effects"] = (node.get("effects", {}) as Dictionary).duplicate(true)
		_store_pending_choice(str(node.get("node_id", "")), {
			"label": str(node.get("title", "")),
			"result": str(node.get("result_text", "")),
			"effects": node.get("effects", {}),
		})
		_sync_world_map_runtime_state()
		_sync_strategic_cards_to_context()
		_save_narrative_state_to_context()
		NarrativeBattleContext.set_request_from_combat(request, str(node.get("node_id", "")))
		get_tree().change_scene_to_file("res://scenes/MainVisual.tscn")
		return
	var reward_choices := _strategic_card_reward_choices(node)
	if not reward_choices.is_empty():
		_show_strategic_card_reward_choice(node, reward_choices)
		return
	_apply_strategic_node(node)
	_advance_strategic_cursor()
	_sync_world_map_runtime_state()
	_save_narrative_state_to_context()
	_render()
func _consume_strategic_node_battle(source_id: String, result: String) -> void:
	var pending := _load_pending_choice()
	if result != "win":
		last_hint = "大势图战斗未胜：当前层暂不推进。"
		_clear_pending_choice()
		_sync_world_map_runtime_state()
		return
	var node := _find_strategic_node(source_id)
	if node.is_empty():
		last_hint = "大势图战斗胜利：未找到节点配置，暂不结算。"
		_clear_pending_choice()
		_sync_world_map_runtime_state()
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
	_sync_world_map_runtime_state()
func _apply_strategic_node(node: Dictionary) -> void:
	_sync_context_cards_to_strategic_state()
	var effects: Dictionary = node.get("effects", {}) as Dictionary
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
	strategic_state["current_world_map_node_id"] = str(node.get("node_id", ""))
	strategic_state["current_world_map_node_effects"] = effects.duplicate(true)
	_sync_world_map_runtime_state()
	last_hint = result_text
func _strategic_card_reward_choices(node: Dictionary) -> Array[String]:
	return _reward_runtime().strategic_card_reward_choices(node)
func _show_strategic_card_reward_choice(node: Dictionary, card_ids: Array[String]) -> void:
	_reward_runtime().show_strategic_card_reward_choice(node, card_ids)
func _select_strategic_card_reward(card_id: String) -> void:
	_reward_runtime().select_strategic_card_reward(card_id)
func _confirm_strategic_card_reward() -> void:
	_reward_runtime().confirm_strategic_card_reward()
func _cancel_strategic_card_reward() -> void:
	_reward_runtime().cancel_strategic_card_reward()
func _strategic_card_choice_text(card_id: String, selected: bool) -> String:
	return _reward_runtime().strategic_card_choice_text(card_id, selected)
func _strategic_card_label(card_id: String) -> String:
	return _reward_runtime().strategic_card_label(card_id)
func _strategic_card_hint(card_id: String) -> String:
	return _reward_runtime().strategic_card_hint(card_id)
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
	_sync_world_map_runtime_state()
	if StrategicMapGenerator.is_map_complete(strategic_state.get("current_map", {}), int(strategic_state.get("region_index", 0)), int(strategic_state.get("layer_index", 0))):
		if _base_ui_ready():
			_prepare_strategic_final_gate()
		else:
			strategic_state["final_boss"] = StrategicMapGenerator.select_final_boss(strategic_config, strategic_state)
func _prepare_strategic_final_gate() -> void:
	var boss := StrategicMapGenerator.select_final_boss(strategic_config, strategic_state)
	strategic_state["final_boss"] = boss
	strategic_state["is_world_map_active"] = false
	_sync_world_map_runtime_state()
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
	var boss: Dictionary = strategic_state.get("final_boss", {}) as Dictionary
	if boss.is_empty():
		boss = StrategicMapGenerator.select_final_boss(strategic_config, strategic_state)
		strategic_state["final_boss"] = boss
	var request := StrategicNetworkBattleBridge.final_boss_request(str(boss.get("encounter_id", "enc_boss_ext_wakou_leader")), str(boss.get("battle_id", "boss_ext_wakou_leader")))
	if not bool(request.get("enabled", false)):
		last_hint = str(request.get("blocked_reason", "终局战暂未接入。"))
		_render()
		return
	_sync_strategic_cards_to_context()
	_save_narrative_state_to_context()
	NarrativeBattleContext.set_request_from_combat(request, STRATEGIC_FINAL_BOSS_SOURCE_ID)
	get_tree().change_scene_to_file("res://scenes/MainVisual.tscn")
func _sync_world_map_runtime_state() -> void:
	var map_data: Dictionary = strategic_state.get("current_map", {}) as Dictionary
	var region_index := int(strategic_state.get("region_index", 0))
	var layer_index := int(strategic_state.get("layer_index", 0))
	var region := StrategicMapGenerator.current_region(map_data, region_index)
	var layer := StrategicMapGenerator.current_layer(map_data, region_index, layer_index)
	var generated_nodes: Array[String] = []
	var choices: Array = layer.get("choices", [])
	for choice_variant in choices:
		if choice_variant is Dictionary:
			generated_nodes.append(str((choice_variant as Dictionary).get("node_id", "")))
	strategic_state["current_region_id"] = str(region.get("region_id", ""))
	strategic_state["current_region_layer"] = layer_index + 1
	strategic_state["world_map_generated_nodes"] = generated_nodes
	strategic_state["world_map_completed_nodes"] = (strategic_state.get("selected_nodes", []) as Array).duplicate(true)
	strategic_state["is_world_map_active"] = bool(strategic_state.get("active", false))
func _find_strategic_node(node_id: String) -> Dictionary:
	var node_pool: Array = strategic_config.get("node_pool", [])
	for item in node_pool:
		if item is Dictionary and str((item as Dictionary).get("node_id", "")) == node_id:
			return (item as Dictionary).duplicate(true)
	return {}
func _strategic_node_triggers_combat(node: Dictionary) -> bool:
	return str(node.get("node_type", "")).begins_with("combat_") and not str(node.get("encounter_id", "")).is_empty()
func _strategic_type_label(node_type: String) -> String:
	return _reward_runtime().strategic_type_label(node_type)
func _strategic_effects_text(effects: Dictionary) -> String:
	return _reward_runtime().strategic_effects_text(effects)
func _card_reward_ids_from_effects(value) -> Array[String]:
	return _reward_runtime().card_reward_ids_from_effects(value)
func _strategic_combat_pool_text(node: Dictionary) -> String:
	return _reward_runtime().strategic_combat_pool_text(node)
func _ending_data_for_flag(flag: String) -> Dictionary:
	var ending: Dictionary = _ending_formatter().ending_data_for_flag(flag)
	if ending.is_empty():
		return super._ending_data_for_flag(flag)
	return ending
func _ending_catalog() -> Array[Dictionary]:
	return _ending_formatter().ending_catalog()
