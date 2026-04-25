extends "res://scripts/battle_controller_visual_break_preview.gd"

const NarrativeBattleContext := preload("res://scripts/narrative_battle_context.gd")
const BattleStateMachineScript := preload("res://scripts/battle_state_machine.gd")

var narrative_context_label: Label
var battle_result_label: Label
var continue_narrative_button: Button
var last_result_debug_text := ""
var result_recorded := false

func _ready() -> void:
	super._ready()
	_add_narrative_context_debug()
	_add_battle_result_debug()

func _process(_delta: float) -> void:
	_update_battle_result_debug()

func _add_narrative_context_debug() -> void:
	if not NarrativeBattleContext.has_request():
		return
	narrative_context_label = Label.new()
	narrative_context_label.name = "NarrativeContextDebugLabel"
	narrative_context_label.text = "叙事战斗上下文：%s" % NarrativeBattleContext.debug_text()
	narrative_context_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	narrative_context_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	narrative_context_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	narrative_context_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	narrative_context_label.anchor_left = 0.5
	narrative_context_label.anchor_right = 0.5
	narrative_context_label.anchor_top = 0.0
	narrative_context_label.anchor_bottom = 0.0
	narrative_context_label.offset_left = -420
	narrative_context_label.offset_right = 420
	narrative_context_label.offset_top = 78
	narrative_context_label.offset_bottom = 112
	narrative_context_label.add_theme_font_size_override("font_size", 16)
	add_child(narrative_context_label)

func _add_battle_result_debug() -> void:
	if not NarrativeBattleContext.has_request():
		return
	battle_result_label = Label.new()
	battle_result_label.name = "BattleResultDebugLabel"
	battle_result_label.text = "战斗结果诊断：等待战斗结算"
	battle_result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	battle_result_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	battle_result_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	battle_result_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	battle_result_label.anchor_left = 0.5
	battle_result_label.anchor_right = 0.5
	battle_result_label.anchor_top = 0.0
	battle_result_label.anchor_bottom = 0.0
	battle_result_label.offset_left = -420
	battle_result_label.offset_right = 420
	battle_result_label.offset_top = 112
	battle_result_label.offset_bottom = 146
	battle_result_label.add_theme_font_size_override("font_size", 16)
	add_child(battle_result_label)

	continue_narrative_button = Button.new()
	continue_narrative_button.name = "ContinueNarrativeButton"
	continue_narrative_button.text = "继续剧情"
	continue_narrative_button.visible = false
	continue_narrative_button.anchor_left = 0.5
	continue_narrative_button.anchor_right = 0.5
	continue_narrative_button.anchor_top = 0.0
	continue_narrative_button.anchor_bottom = 0.0
	continue_narrative_button.offset_left = -110
	continue_narrative_button.offset_right = 110
	continue_narrative_button.offset_top = 150
	continue_narrative_button.offset_bottom = 194
	continue_narrative_button.pressed.connect(_on_continue_narrative_pressed)
	add_child(continue_narrative_button)

func _update_battle_result_debug() -> void:
	if battle_result_label == null:
		return
	if not NarrativeBattleContext.has_request():
		battle_result_label.visible = false
		if continue_narrative_button != null:
			continue_narrative_button.visible = false
		return
	if state_machine == null:
		_set_battle_result_debug_text("战斗结果诊断：state_machine=null")
		return
	if player == null or enemy == null:
		_set_battle_result_debug_text("战斗结果诊断：等待角色创建")
		return
	if state_machine.phase != BattleStateMachineScript.BattlePhase.RESULT:
		_set_battle_result_debug_text("战斗结果诊断：phase=%s｜player_hp=%d｜enemy_hp=%d｜状态=未结算" % [str(state_machine.phase), player.hp, enemy.hp])
		return
	var narrative_result := _get_narrative_result()
	if not result_recorded:
		NarrativeBattleContext.set_result(narrative_result)
		result_recorded = true
		if narrative_context_label != null:
			narrative_context_label.text = "叙事战斗上下文：%s" % NarrativeBattleContext.debug_text()
	_set_battle_result_debug_text("战斗结果诊断：phase=RESULT｜player_hp=%d｜enemy_hp=%d｜narrative_result=%s" % [player.hp, enemy.hp, narrative_result])
	if continue_narrative_button != null:
		continue_narrative_button.visible = true

func _set_battle_result_debug_text(text: String) -> void:
	if text == last_result_debug_text:
		return
	last_result_debug_text = text
	battle_result_label.text = text

func _get_narrative_result() -> String:
	if player == null or enemy == null:
		return "unknown"
	if player.hp > 0 and enemy.hp <= 0:
		return "win"
	if player.hp <= 0 and enemy.hp > 0:
		return "lose"
	if player.hp <= 0 and enemy.hp <= 0:
		return "draw"
	return "unknown"

func _on_continue_narrative_pressed() -> void:
	get_tree().change_scene_to_file(NarrativeBattleContext.source_scene)
