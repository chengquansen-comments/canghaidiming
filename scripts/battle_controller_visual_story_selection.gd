extends "res://scripts/battle_controller_visual_preview_position_guard.gd"

# Story-battle selection and settlement-mode base layer.
#
# This parent controller owns story encounter selection, story battle loading,
# player/opponent template assignment, and base settlement-mode switching.
# Reactive round timing and pre-move presentation stay in
# battle_controller_visual_settlement_mode.gd.

const StoryBattleLoader = preload("res://scripts/story_battle_loader.gd")
const SettlementNarrativeBattleContext = preload("res://scripts/narrative_battle_context.gd")

@export var story_encounter_id: String = "prologue_beach_teach"
@export_enum("symmetric", "reactive") var settlement_mode_id: String = "reactive"

var _story_encounter_selected := false
var _story_encounters: Array[Dictionary] = []
var _pending_story_battle: Dictionary = {}
var _story_validation_report: Dictionary = {}


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
		overlay_body.text = "选择一场 story_battles.json 中的战斗配置。每场会自动加载敌我模板、数值、卡组、结算模式和压力规则；剧情入口也复用同一套配置。" + validation_text
	_clear_overlay_actions()
	_add_story_selection_back_button()
	for row: Dictionary in _story_encounters:
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
		push_warning("Story encounter failed to load: %s" % story_encounter_id)
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
