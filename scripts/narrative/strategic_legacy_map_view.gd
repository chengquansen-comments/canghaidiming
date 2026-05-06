extends RefCounted

# View helper for the legacy three-choice strategic map.
#
# This file only writes UI nodes and creates choice buttons. It does not mutate
# strategic_state, advance the map cursor, apply rewards, save context, or switch scenes.

const StrategicMapState := preload("res://scripts/strategic_map_state.gd")
const BACKGROUND_PATH := "res://assets/pixel_battle/backgrounds/map_march_coast.png"
const TITLE_TEXT := "海疆大势图"
const SCENE_TEXT := "军情、海防与旧案线索被摊在同一张图上。"
const BODY_TEXT := "你不再只沿着一条案线走。\n\n每一步只看四件事：军功、清望、旧案、武境。"
const MAP_PLACEHOLDER := "每层三选一。选中后应用收益；战斗节点会跳转 MainVisual。"
const COMBAT_PLACEHOLDER := "当前层候选节点"
const CHOICE_MINIMUM_SIZE := Vector2(0, 76)

var owner = null


func _init(owner_node) -> void:
	owner = owner_node


func render(region: Dictionary, layer: Dictionary, map_data: Dictionary, strategic_state: Dictionary, layer_index: int, last_hint: String, progress_text: String, choice_callback: Callable) -> void:
	if owner == null:
		return
	owner.title_label.text = TITLE_TEXT
	owner.status_label.text = "%s｜第 %d 层" % [str(region.get("region_title", "海疆")), layer_index + 1]
	owner.map_label.text = progress_text
	owner.scene_label.text = owner._format_scene_text(SCENE_TEXT)
	owner._render_visual(BACKGROUND_PATH, TITLE_TEXT)
	owner.body_label.text = BODY_TEXT
	if not last_hint.is_empty():
		owner.body_label.text += "\n\n[i]%s[/i]" % last_hint
	owner.vars_label.text = StrategicMapState.summary_text(strategic_state)
	owner._add_placeholder(owner.map_buttons_box, MAP_PLACEHOLDER)
	owner._add_placeholder(owner.combat_buttons_box, COMBAT_PLACEHOLDER)
	var choices: Array = layer.get("choices", [])
	for i in range(choices.size()):
		if choices[i] is Dictionary:
			_add_choice_button(choices[i] as Dictionary, i, choice_callback)


func _add_choice_button(node: Dictionary, index: int, choice_callback: Callable) -> void:
	if owner == null:
		return
	var effects: Dictionary = node.get("effects", {}) as Dictionary
	var btn := Button.new()
	var scope_text := StrategicMapState.event_scope_text(node)
	var combat_text := owner._strategic_combat_pool_text(node)
	btn.text = "%s｜%s%s%s\n%s\n%s" % [
		str(node.get("title", "")),
		owner._strategic_type_label(str(node.get("node_type", ""))),
		"｜%s" % scope_text if not scope_text.is_empty() else "",
		"｜%s" % combat_text if not combat_text.is_empty() else "",
		str(node.get("preview_text", "")),
		owner._strategic_effects_text(effects),
	]
	btn.custom_minimum_size = CHOICE_MINIMUM_SIZE
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.pressed.connect(choice_callback.bind(index))
	owner.choices_box.add_child(btn)
