extends "res://scripts/battle_controller_visual_narrative_context_result.gd"

# Narrative context runtime layer.

func _ready() -> void:
	super._ready()
	_resolve_pending_battle_loadout()
	_add_narrative_debug_layer()
	call_deferred("_auto_start_narrative_battle_if_needed")

func _process(_delta: float) -> void:
	super._process(_delta)
	_update_battle_result_debug()

func _auto_start_narrative_battle_if_needed() -> void:
	if narrative_auto_start_attempted:
		return
	if str(NarrativeBattleContext.encounter_id) != "enc_prologue_master_rescue":
		return
	narrative_auto_start_attempted = true
	player_role_id = "master_veteran"
	var called: bool = _try_recommended_role_entry("master_veteran")
	if not called:
		called = _press_role_button_by_text(["师父", "师傅", "老兵", "master_veteran"])
	if called:
		_set_battle_result_debug_text("序章师父战：已自动以师父刀法进入教学战。")
	else:
		_set_battle_result_debug_text("序章师父战：已写入师父刀法配置；未命中自动开战入口。")

func _select_role_and_start(role_id: String) -> void:
	_mark_battle_loadout_needs_apply()
	super._select_role_and_start(role_id)
	_mark_battle_loadout_needs_apply()
	_load_narrative_battle_once()

func _start_session(role_id: String) -> void:
	_mark_battle_loadout_needs_apply()
	super._start_session(role_id)
	_load_narrative_battle_once()

func _start_battle() -> void:
	_mark_battle_loadout_needs_apply()
	super._start_battle()
	_mark_battle_loadout_needs_apply()
	_load_narrative_battle_once()

func _mark_battle_loadout_needs_apply() -> void:
	if NarrativeBattleContext.has_request():
		battle_loadout_applied = false
		narrative_numbers_applied = false

func _press_role_button_by_text(keywords: Array[String]) -> bool:
	var buttons: Array[Button] = []
	_collect_buttons(self, buttons)
	for button: Button in buttons:
		var text: String = button.text
		for keyword: String in keywords:
			if text.findn(keyword) >= 0:
				button.emit_signal("pressed")
				return true
	return false

func _collect_buttons(node: Node, out_buttons: Array[Button]) -> void:
	for child: Node in node.get_children():
		if child is Button:
			out_buttons.append(child)
		_collect_buttons(child, out_buttons)

func _add_narrative_debug_layer() -> void:
	narrative_debug_layer = CanvasLayer.new()
	narrative_debug_layer.name = "NarrativeDebugCanvasLayer"
	narrative_debug_layer.layer = 100
	add_child(narrative_debug_layer)

	enemy_config_strip = Label.new()
	enemy_config_strip.name = "EnemyConfigTopStrip"
	enemy_config_strip.text = _enemy_full_config_text()
	enemy_config_strip.anchor_left = 0.02
	enemy_config_strip.anchor_right = 0.98
	enemy_config_strip.anchor_top = 0.0
	enemy_config_strip.anchor_bottom = 0.0
	enemy_config_strip.offset_top = 6
	enemy_config_strip.offset_bottom = 62
	enemy_config_strip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	enemy_config_strip.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	enemy_config_strip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	enemy_config_strip.add_theme_font_size_override("font_size", 13)
	narrative_debug_layer.add_child(enemy_config_strip)

	var panel: PanelContainer = PanelContainer.new()
	panel.name = "NarrativeDebugPanel"
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.anchor_top = 0.0
	panel.anchor_bottom = 0.0
	panel.offset_left = -540
	panel.offset_right = -18
	panel.offset_top = 68
	panel.offset_bottom = 500
	narrative_debug_layer.add_child(panel)

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)

	narrative_debug_box = VBoxContainer.new()
	narrative_debug_box.add_theme_constant_override("separation", 8)
	margin.add_child(narrative_debug_box)

	narrative_context_label = Label.new()
	narrative_context_label.name = "NarrativeContextDebugLabel"
	narrative_context_label.text = _context_debug_text()
	narrative_context_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	narrative_context_label.add_theme_font_size_override("font_size", 14)
	narrative_debug_box.add_child(narrative_context_label)

	battle_mapping_label = Label.new()
	battle_mapping_label.name = "BattleMappingDebugLabel"
	battle_mapping_label.text = _mapping_debug_text()
	battle_mapping_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	battle_mapping_label.add_theme_font_size_override("font_size", 14)
	narrative_debug_box.add_child(battle_mapping_label)

	enemy_config_label = Label.new()
	enemy_config_label.name = "EnemyConfigDebugLabel"
	enemy_config_label.text = _enemy_config_debug_text()
	enemy_config_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	enemy_config_label.add_theme_font_size_override("font_size", 14)
	narrative_debug_box.add_child(enemy_config_label)

	battle_result_label = Label.new()
	battle_result_label.name = "BattleResultDebugLabel"
	battle_result_label.text = "战斗结果：可随时返回剧情；debug 返回按胜利处理"
	battle_result_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	battle_result_label.add_theme_font_size_override("font_size", 13)
	narrative_debug_box.add_child(battle_result_label)

	recommended_start_button = Button.new()
	recommended_start_button.name = "RecommendedBattleButton"
	recommended_start_button.text = "按推荐接敌"
	recommended_start_button.custom_minimum_size = Vector2(0, 40)
	recommended_start_button.pressed.connect(_on_recommended_battle_pressed)
	narrative_debug_box.add_child(recommended_start_button)

	continue_narrative_button = Button.new()
	continue_narrative_button.name = "ContinueNarrativeButton"
	continue_narrative_button.text = "返回剧情"
	continue_narrative_button.custom_minimum_size = Vector2(0, 42)
	continue_narrative_button.pressed.connect(_on_continue_narrative_pressed)
	narrative_debug_box.add_child(continue_narrative_button)

func _on_recommended_battle_pressed() -> void:
	var mapping: Dictionary = NarrativeBattleContext.get_battle_mapping()
	var role_id: String = str(mapping.get("player_role", "spearman"))
	player_role_id = role_id
	var called: bool = _try_recommended_role_entry(role_id)
	if called:
		_set_battle_result_debug_text("接战操作：已按推荐玩家=%s 尝试进入战斗。" % role_id)
	else:
		_set_battle_result_debug_text("接战操作：已写入推荐玩家=%s；未匹配自动入口，请继续使用原角色选择按钮。" % role_id)

func _try_recommended_role_entry(role_id: String) -> bool:
	var called: bool = false
	var one_arg_methods: Array[String] = ["_select_role_and_start", "_on_role_selected", "_select_role", "_choose_role", "_pick_role", "_start_battle", "_begin_battle", "_start_session", "_begin_session", "_start_run"]
	for method_name: String in one_arg_methods:
		if _method_accepts_arg_count(method_name, 1):
			callv(method_name, [role_id])
			called = true
			break
	var no_arg_methods: Array[String] = ["_confirm_role_selection", "_confirm_role_pick", "_start_battle", "_begin_battle", "_start_session", "_begin_session", "_start_run"]
	if not called:
		for method_name: String in no_arg_methods:
			if _method_accepts_arg_count(method_name, 0):
				callv(method_name, [])
				called = true
				break
	if called:
		_mark_battle_loadout_needs_apply()
		_load_narrative_battle_once()
	return called

