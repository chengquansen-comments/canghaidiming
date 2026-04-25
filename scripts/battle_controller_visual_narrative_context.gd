extends "res://scripts/battle_controller_visual_break_preview.gd"

const NarrativeBattleContext := preload("res://scripts/narrative_battle_context.gd")
const BattleStateMachineScript := preload("res://scripts/battle_state_machine.gd")
const DEFAULT_NARRATIVE_SCENE := "res://scenes/NarrativeDemo.tscn"

var narrative_debug_layer: CanvasLayer
var narrative_debug_box: VBoxContainer
var narrative_context_label: Label
var battle_mapping_label: Label
var battle_result_label: Label
var continue_narrative_button: Button
var last_result_debug_text := ""
var result_recorded := false

func _ready() -> void:
	super._ready()
	_add_narrative_debug_layer()

func _process(_delta: float) -> void:
	_update_battle_result_debug()

func _add_narrative_debug_layer() -> void:
	narrative_debug_layer = CanvasLayer.new()
	narrative_debug_layer.name = "NarrativeDebugCanvasLayer"
	narrative_debug_layer.layer = 100
	add_child(narrative_debug_layer)

	var panel := PanelContainer.new()
	panel.name = "NarrativeDebugPanel"
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.anchor_top = 0.0
	panel.anchor_bottom = 0.0
	panel.offset_left = -520
	panel.offset_right = -18
	panel.offset_top = 54
	panel.offset_bottom = 330
	narrative_debug_layer.add_child(panel)

	var margin := MarginContainer.new()
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
	battle_mapping_label.add_theme_font_size_override("font_size", 15)
	narrative_debug_box.add_child(battle_mapping_label)

	battle_result_label = Label.new()
	battle_result_label.name = "BattleResultDebugLabel"
	battle_result_label.text = "战斗结果：可随时返回剧情；胜负会按当前 HP 推断"
	battle_result_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	battle_result_label.add_theme_font_size_override("font_size", 13)
	narrative_debug_box.add_child(battle_result_label)

	continue_narrative_button = Button.new()
	continue_narrative_button.name = "ContinueNarrativeButton"
	continue_narrative_button.text = "返回剧情"
	continue_narrative_button.custom_minimum_size = Vector2(0, 42)
	continue_narrative_button.pressed.connect(_on_continue_narrative_pressed)
	narrative_debug_box.add_child(continue_narrative_button)

func _context_debug_text() -> String:
	var mapping := NarrativeBattleContext.get_battle_mapping()
	var mapping_summary := "关卡信息：%s｜推荐玩家=%s｜推荐敌人=%s｜难度=%s" % [
		str(mapping.get("label", "")),
		str(mapping.get("player_role", "")),
		str(mapping.get("enemy_role", "")),
		str(mapping.get("difficulty", ""))
	]
	if NarrativeBattleContext.has_request():
		return "%s\n叙事上下文：%s" % [mapping_summary, NarrativeBattleContext.debug_text()]
	return "%s\n叙事上下文：无请求｜返回将按 win 保底" % mapping_summary

func _mapping_debug_text() -> String:
	return "接战映射：%s" % NarrativeBattleContext.battle_mapping_debug_text()

func _update_battle_result_debug() -> void:
	if battle_result_label == null:
		return
	if narrative_context_label != null:
		narrative_context_label.text = _context_debug_text()
	if battle_mapping_label != null:
		battle_mapping_label.text = _mapping_debug_text()
	if state_machine == null:
		_set_battle_result_debug_text("战斗结果：state_machine=null｜可点击返回剧情")
		return
	if player == null or enemy == null:
		_set_battle_result_debug_text("战斗结果：等待角色创建｜可点击返回剧情")
		return
	var hp_result_ready := player.hp <= 0 or enemy.hp <= 0
	var phase_result_ready := state_machine.phase == BattleStateMachineScript.BattlePhase.RESULT
	if not hp_result_ready and not phase_result_ready:
		_set_battle_result_debug_text("战斗结果：phase=%s｜player_hp=%d｜enemy_hp=%d｜未结算，可点击返回剧情" % [str(state_machine.phase), player.hp, enemy.hp])
		return
	var narrative_result := _get_narrative_result()
	_record_result_once(narrative_result)
	var result_state := "RESULT" if phase_result_ready else "HP_ZERO"
	_set_battle_result_debug_text("战斗结果：state=%s｜phase=%s｜player_hp=%d｜enemy_hp=%d｜narrative_result=%s" % [result_state, str(state_machine.phase), player.hp, enemy.hp, narrative_result])

func _record_result_once(narrative_result: String) -> void:
	if result_recorded:
		return
	NarrativeBattleContext.set_result(narrative_result)
	result_recorded = true
	if narrative_context_label != null:
		narrative_context_label.text = _context_debug_text()

func _set_battle_result_debug_text(text: String) -> void:
	if text == last_result_debug_text:
		return
	last_result_debug_text = text
	battle_result_label.text = text

func _get_narrative_result() -> String:
	if player == null or enemy == null:
		return "win"
	if player.hp > 0 and enemy.hp <= 0:
		return "win"
	if player.hp <= 0 and enemy.hp > 0:
		return "lose"
	if player.hp <= 0 and enemy.hp <= 0:
		return "draw"
	return "win"

func _on_continue_narrative_pressed() -> void:
	if not NarrativeBattleContext.has_result():
		NarrativeBattleContext.set_result(_get_narrative_result())
	var target_scene := NarrativeBattleContext.source_scene
	if target_scene.is_empty():
		target_scene = DEFAULT_NARRATIVE_SCENE
	get_tree().change_scene_to_file(target_scene)
