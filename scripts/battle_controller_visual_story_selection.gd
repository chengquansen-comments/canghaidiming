extends "res://scripts/battle_controller_visual_preview_position_guard.gd"

# Story-battle selection and settlement-mode base layer.
#
# This parent controller owns story encounter selection, story battle loading,
# player/opponent template assignment, and base settlement-mode switching.
# Reactive round timing and pre-move presentation stay in
# battle_controller_visual_settlement_mode.gd.

const StoryBattleLoader = preload("res://scripts/story_battle_loader.gd")
const SettlementNarrativeBattleContext = preload("res://scripts/narrative_battle_context.gd")

const STORY_ENCOUNTER_TAB_IMPLEMENTED := "implemented"
const STORY_ENCOUNTER_TAB_UNIMPLEMENTED := "unimplemented"
const STORY_ENCOUNTER_IMPLEMENTED_LABEL := "实装"
const STORY_ENCOUNTER_UNIMPLEMENTED_LABEL := "未实装"

@export var story_encounter_id: String = "prologue_beach_teach"
@export_enum("symmetric", "reactive") var settlement_mode_id: String = "reactive"

var _story_encounter_selected := false
var _story_encounters: Array[Dictionary] = []
var _pending_story_battle: Dictionary = {}
var _story_validation_report: Dictionary = {}
var _story_encounter_tab_id := STORY_ENCOUNTER_TAB_IMPLEMENTED


func _ready() -> void:
	super()
	var card_catalog: Dictionary = _build_story_card_catalog()
	_story_validation_report = StoryBattleLoader.validate_all(card_catalog)
	print(StoryBattleLoader.format_validation_report(_story_validation_report))
	_story_encounters = StoryBattleLoader.load_encounters()
	_apply_visual_settlement_mode()


func _show_role_selection() -> void:
	if not _story_encounter_selected:
		_show_story_encounter_selection()
		return
	_start_selected_story_encounter()


func _show_story_encounter_selection() -> void:
	battle_active = false
	awaiting_player_input = false
	player_role_id = ""
	_pending_story_battle = {}
	if _story_encounters.is_empty():
		_story_encounters = StoryBattleLoader.load_encounters()
	if overlay_scrim != null:
		overlay_scrim.visible = true
	if overlay_panel != null:
		overlay_panel.visible = true
	if overlay_title != null:
		overlay_title.text = "战斗测试"
	if overlay_body != null:
		var validation_text: String = ""
		if not _story_validation_report.is_empty():
			validation_text = " 配置校验：%s。" % ("通过" if bool(_story_validation_report.get("ok", false)) else "存在错误，请看控制台")
		var counts: Dictionary = _story_encounter_tab_counts()
		overlay_body.text = "选择一场 story_battles.json 中的战斗配置。每场会自动加载敌我模板、数值、卡组、结算模式和压力规则；剧情入口也复用同一套配置。\n\n当前页签：%s（%d 场）。实装页用于正式剧情/可交付战斗；未实装页保留教学、压力、演示和兜底测试。%s" % [_story_encounter_tab_label(_story_encounter_tab_id), int(counts.get(_story_encounter_tab_id, 0)), validation_text]
	_clear_overlay_actions()
	_add_story_selection_back_button()
	_add_story_encounter_tab_buttons()
	for row: Dictionary in _story_encounters:
		if _story_encounter_tab_for_row(row) != _story_encounter_tab_id:
			continue
		_add_story_encounter_button(row)
	if has_method("_apply_button_styles"):
		call("_apply_button_styles")


func _clear_overlay_actions() -> void:
	if overlay_actions == null:
		return
	for child: Node in overlay_actions.get_children():
		child.queue_free()


func _add_story_selection_back_button() -> void:
	if overlay_actions == null:
		return
	var button: Button = Button.new()
	button.text = "返回主菜单"
	button.custom_minimum_size = Vector2(0, 42)
	button.pressed.connect(_on_story_selection_back_pressed)
	overlay_actions.add_child(button)


func _add_story_encounter_tab_buttons() -> void:
	if overlay_actions == null:
		return
	var counts: Dictionary = _story_encounter_tab_counts()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	overlay_actions.add_child(row)
	_add_story_encounter_tab_button(row, STORY_ENCOUNTER_TAB_IMPLEMENTED, int(counts.get(STORY_ENCOUNTER_TAB_IMPLEMENTED, 0)))
	_add_story_encounter_tab_button(row, STORY_ENCOUNTER_TAB_UNIMPLEMENTED, int(counts.get(STORY_ENCOUNTER_TAB_UNIMPLEMENTED, 0)))


func _add_story_encounter_tab_button(parent: Control, tab_id: String, count: int) -> void:
	var button: Button = Button.new()
	var selected_prefix := "● " if _story_encounter_tab_id == tab_id else "○ "
	button.text = "%s%s（%d）" % [selected_prefix, _story_encounter_tab_label(tab_id), count]
	button.custom_minimum_size = Vector2(0, 40)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.disabled = _story_encounter_tab_id == tab_id
	button.pressed.connect(func() -> void:
		_set_story_encounter_tab(tab_id)
	)
	parent.add_child(button)


func _set_story_encounter_tab(tab_id: String) -> void:
	_story_encounter_tab_id = tab_id
	_show_story_encounter_selection()


func _story_encounter_tab_counts() -> Dictionary:
	var counts := {
		STORY_ENCOUNTER_TAB_IMPLEMENTED: 0,
		STORY_ENCOUNTER_TAB_UNIMPLEMENTED: 0,
	}
	for row: Dictionary in _story_encounters:
		var tab_id: String = _story_encounter_tab_for_row(row)
		counts[tab_id] = int(counts.get(tab_id, 0)) + 1
	return counts


func _story_encounter_tab_label(tab_id: String) -> String:
	return STORY_ENCOUNTER_IMPLEMENTED_LABEL if tab_id == STORY_ENCOUNTER_TAB_IMPLEMENTED else STORY_ENCOUNTER_UNIMPLEMENTED_LABEL


func _story_encounter_tab_for_row(row: Dictionary) -> String:
	if _story_encounter_row_has_explicit_implemented_flag(row):
		return STORY_ENCOUNTER_TAB_IMPLEMENTED if _story_encounter_row_is_explicitly_implemented(row) else STORY_ENCOUNTER_TAB_UNIMPLEMENTED
	return STORY_ENCOUNTER_TAB_UNIMPLEMENTED if _story_encounter_row_looks_unimplemented(row) else STORY_ENCOUNTER_TAB_IMPLEMENTED


func _story_encounter_row_has_explicit_implemented_flag(row: Dictionary) -> bool:
	return row.has("implemented") or row.has("is_implemented") or row.has("implementation_status") or row.has("test_status")


func _story_encounter_row_is_explicitly_implemented(row: Dictionary) -> bool:
	if row.has("implemented"):
		return _to_bool_like(row.get("implemented", false))
	if row.has("is_implemented"):
		return _to_bool_like(row.get("is_implemented", false))
	var status := str(row.get("implementation_status", row.get("test_status", ""))).strip_edges().to_lower()
	return status in ["implemented", "live", "formal", "production", "ready", "done", "实装", "正式", "已实装", "可用"]


func _to_bool_like(value) -> bool:
	if value is bool:
		return bool(value)
	var text := str(value).strip_edges().to_lower()
	return text in ["1", "true", "yes", "y", "on", "implemented", "实装", "已实装"]


func _story_encounter_row_looks_unimplemented(row: Dictionary) -> bool:
	var encounter_id := str(row.get("encounter_id", "")).to_lower()
	var display_name := str(row.get("display_name", ""))
	var notes := str(row.get("notes", ""))
	var combined := "%s %s %s" % [encounter_id, display_name, notes]
	var lower_combined := combined.to_lower()
	if encounter_id.begins_with("symmetric_"):
		return true
	if encounter_id.begins_with("fallback_"):
		return true
	if encounter_id.find("debug") >= 0 or encounter_id.find("test") >= 0:
		return true
	var unimplemented_markers := [
		"测试", "教学", "演示", "兜底", "缺省", "默认", "对称式", "压力", "控距", "破势",
		"test", "debug", "demo", "fallback", "teach", "teaching", "probe", "duel", "pressure"
	]
	for marker in unimplemented_markers:
		if lower_combined.find(str(marker).to_lower()) >= 0:
			return true
	return false


func _on_story_selection_back_pressed() -> void:
	SettlementNarrativeBattleContext.clear()
	get_tree().change_scene_to_file("res://scenes/Main.tscn")


func _add_story_encounter_button(row: Dictionary) -> void:
	if overlay_actions == null:
		return
	var selected_id: String = str(row.get("encounter_id", ""))
	if selected_id == "":
		return
	var display_name: String = str(row.get("display_name", selected_id))
	var mode: String = str(row.get("settlement_mode", "symmetric"))
	var player_template: String = str(row.get("player_template_id", ""))
	var opponent_template: String = str(row.get("opponent_template_id", ""))
	var notes: String = str(row.get("notes", ""))
	var button: Button = Button.new()
	button.text = "%s｜%s vs %s｜%s" % [display_name, player_template, opponent_template, mode]
	button.custom_minimum_size = Vector2(0, 42)
	if notes != "":
		button.tooltip_text = notes
	button.pressed.connect(func() -> void:
		_select_story_encounter_and_start(selected_id)
	)
	overlay_actions.add_child(button)


func _select_story_encounter_and_start(encounter_id: String) -> void:
	story_encounter_id = encounter_id
	_story_encounter_selected = true
	_clear_story_battle_reactive_state()
	var card_catalog: Dictionary = _build_story_card_catalog()
	_pending_story_battle = StoryBattleLoader.build_story_battle(story_encounter_id, card_catalog)
	if _pending_story_battle.is_empty():
		push_warning("Story encounter failed to load: %s" % encounter_id)
		_story_encounter_selected = false
		_show_story_encounter_selection()
		return
	settlement_mode_id = str(_pending_story_battle.get("settlement_mode", BattleStateMachine.MODE_REACTIVE_ID))
	_apply_visual_settlement_mode()
	var encounter: Dictionary = _pending_story_battle.get("encounter", {}) as Dictionary
	_show_combat_banner("剧情遭遇：%s" % str(encounter.get("display_name", story_encounter_id)), Color("1c2a36"), Color("8fd3ff"))
	_start_selected_story_encounter()


func _start_selected_story_encounter() -> void:
	if _pending_story_battle.is_empty():
		var card_catalog: Dictionary = _build_story_card_catalog()
		_pending_story_battle = StoryBattleLoader.build_story_battle(story_encounter_id, card_catalog)
		if _pending_story_battle.is_empty():
			_show_story_encounter_selection()
			return
	var encounter: Dictionary = _pending_story_battle.get("encounter", {}) as Dictionary
	var role_id: String = _core_role_id_for_template(str(encounter.get("player_template_id", "player_blademaster")))
	super._select_role_and_start(role_id)
	_apply_selected_story_battle_to_current_battle()


func _apply_selected_story_battle_to_current_battle() -> void:
	if _pending_story_battle.is_empty():
		return
	var player_data: FighterData = _pending_story_battle.get("player_data", null) as FighterData
	var opponent_data: FighterData = _pending_story_battle.get("opponent_data", null) as FighterData
	var encounter: Dictionary = _pending_story_battle.get("encounter", {}) as Dictionary
	if player_data == null or opponent_data == null:
		push_warning("Story encounter has null fighter data: %s" % story_encounter_id)
		return
	player = Fighter.new(player_data)
	player.set_session_realm(player_data.starting_realm)
	_prepare_player_battle_deck()
	player.reset_for_battle(HAND_SIZE)
	enemy = Fighter.new(opponent_data)
	enemy.set_session_realm(opponent_data.starting_realm)
	enemy.reset_for_battle(HAND_SIZE)
	settlement_mode_id = str(_pending_story_battle.get("settlement_mode", settlement_mode_id))
	_apply_visual_settlement_mode()
	state_machine.update_distance_from_positions(player, enemy)
	if log_label != null:
		log_label.append_text("\n[color=#8fd3ff]已加载剧情遭遇：%s → 我方 %s / 对手 %s / 模式 %s[/color]" % [str(encounter.get("display_name", story_encounter_id)), player_data.display_name, opponent_data.display_name, settlement_mode_id])
	_refresh_ui()


func _build_story_card_catalog() -> Dictionary:
	return StoryBattleLoader.build_card_catalog(fighter_catalog, reward_pool)


func _core_role_id_for_template(template_id: String) -> String:
	if template_id == "master_veteran":
		return "master_veteran"
	if template_id.find("spear") >= 0:
		return "spearman"
	return "blademaster"


func set_visual_settlement_mode(value: String) -> void:
	settlement_mode_id = value
	_clear_story_battle_reactive_state()
	_apply_visual_settlement_mode()
	_show_combat_banner("结算模式：%s" % ("反应式" if settlement_mode_id == BattleStateMachine.MODE_REACTIVE_ID else "对称式"), Color("1c2a36") if settlement_mode_id == BattleStateMachine.MODE_REACTIVE_ID else Color("2a2018"), Color("8fd3ff") if settlement_mode_id == BattleStateMachine.MODE_REACTIVE_ID else Color("ffd479"))
	_refresh_ui()


func toggle_visual_settlement_mode() -> void:
	if settlement_mode_id == BattleStateMachine.MODE_REACTIVE_ID:
		set_visual_settlement_mode(BattleStateMachine.MODE_SYMMETRIC_ID)
	else:
		set_visual_settlement_mode(BattleStateMachine.MODE_REACTIVE_ID)


func _apply_visual_settlement_mode() -> void:
	if state_machine == null:
		return
	state_machine.set_settlement_mode_id(settlement_mode_id)
	print("[settlement-mode] ", state_machine.settlement_mode_id())


func _clear_story_battle_reactive_state() -> void:
	# Overridden by reactive settlement-mode child controller.
	pass
