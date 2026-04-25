extends "res://scripts/battle_controller_visual_break_preview.gd"

const NarrativeBattleContext := preload("res://scripts/narrative_battle_context.gd")

var narrative_context_label: Label

func _ready() -> void:
	super._ready()
	_add_narrative_context_debug()

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
