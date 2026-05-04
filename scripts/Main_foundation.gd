extends Control

const MAX_MOMENTUM := 10
const HAND_SIZE := 5
const CRITICAL_MULTIPLIER := 2
const DATA_PATHS := {
	"classes": "res://data/classes.json",
	"cards": "res://data/cards.json",
	"effects": "res://data/effects.json",
	"enemies": "res://data/enemies.json",
	"routes": "res://data/routes.json",
	"rewards": "res://data/rewards.json"
}

var player_class_id := ""
var battle_index := 0
var distance := 2
var map_length := 9
var initial_distance := 2
var player_position := 0
var enemy_position := 2
var class_defs: Dictionary = {}
var card_defs: Dictionary = {}
var effect_defs: Dictionary = {}
var reward_pool: Array = []
var enemy_defs: Array = []
var route_defs: Dictionary = {}
var enemy_def_by_id: Dictionary = {}
var route_nodes: Dictionary = {}
var current_node_id := ""
var current_enemy_node_id := ""
var available_next_nodes: Array = []
var visited_nodes: Array = []
var data_load_error := ""

var player := {}
var enemy := {}

var draw_pile: Array = []
var discard_pile: Array = []
var hand: Array = []
var reward_options: Array = []

var selected_distance_toggle := 1
var battle_log := []
var battle_over := false
var reward_pending := false
var victory := false

var title_label: Label
var subtitle_label: Label
var battle_badge: Label
var distance_track: HBoxContainer
var distance_nodes: Array[PanelContainer] = []
var distance_labels: Array[Label] = []
var player_avatar: PanelContainer
var enemy_avatar: PanelContainer
var player_avatar_label: Label
var enemy_avatar_label: Label
var player_fx_label: Label
var enemy_fx_label: Label
var center_callout: Label
var player_label: RichTextLabel
var enemy_label: RichTextLabel
var intent_label: RichTextLabel
var hand_label: Label
var hand_flow: HFlowContainer
var action_button: Button
var next_button: Button
var log_label: RichTextLabel
var overlay_panel: PanelContainer
var overlay_scrim: ColorRect
var overlay_title: Label
var overlay_body: RichTextLabel
var overlay_actions: VBoxContainer
var root_container: VBoxContainer
var battle_field_panel: PanelContainer
var log_panel: PanelContainer
var current_tween: Tween

const CATEGORY_COLORS := {
	"步法": Color("6db8ff"),
	"架势": Color("7dd3a7"),
	"攻击": Color("f0b35f"),
	"杀招": Color("df6d5d"),
	"战术": Color("9b8cff")
}

func _create_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _make_panel_style(Color("16202a"), Color("344657"), 1, 8))
	return panel

func _make_panel_style(fill: Color, border: Color, border_width: int, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(border_width)
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	return style

func _style_button(button: Button, fill: Color) -> void:
	button.add_theme_stylebox_override("normal", _make_panel_style(fill, fill.lightened(0.25), 1, 6))
	button.add_theme_stylebox_override("hover", _make_panel_style(fill.lightened(0.12), fill.lightened(0.35), 1, 6))
	button.add_theme_stylebox_override("pressed", _make_panel_style(fill.darkened(0.12), fill.lightened(0.15), 1, 6))
	button.add_theme_color_override("font_color", Color("f4e6c8"))
	button.add_theme_font_size_override("font_size", 16)

func _show_overlay(title: String, body: String, actions: Array) -> void:
	overlay_title.text = title
	overlay_body.text = body
	for child in overlay_actions.get_children():
		child.queue_free()
	for action in actions:
		var button := Button.new()
		button.text = action.get("text", "继续")
		button.custom_minimum_size = Vector2(0, 42)
		_style_button(button, Color("4a3a25"))
		var callback: Callable = action.get("callback", Callable())
		if callback.is_valid():
			button.pressed.connect(callback)
		overlay_actions.add_child(button)
	overlay_scrim.visible = true
	overlay_panel.visible = true

func _hide_overlay() -> void:
	overlay_scrim.visible = false
	overlay_panel.visible = false

func _log(message: String) -> void:
	battle_log.append(message)
	if battle_log.size() > 8:
		battle_log.pop_front()
	_refresh_log()

func _flash_avatar(target: PanelContainer, color: Color, scale_boost := 0.05) -> void:
	if target == null:
		return
	var original_color := target.modulate
	var original_scale := target.scale
	var tween := create_tween()
	tween.tween_property(target, "modulate", color, 0.08)
	tween.parallel().tween_property(target, "scale", original_scale + Vector2(scale_boost, scale_boost), 0.08)
	tween.tween_property(target, "modulate", original_color, 0.18)
	tween.parallel().tween_property(target, "scale", original_scale, 0.18)

func _show_fx(label: Label, text: String, color: Color) -> void:
	label.text = text
	label.modulate = color
	label.position.y = -16
	var tween := create_tween()
	tween.tween_property(label, "position:y", -42, 0.32)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.32)
	tween.tween_callback(func():
		label.text = ""
		label.position.y = -16
		label.modulate = Color(1, 1, 1, 1)
	)

func _animate_distance_shift() -> void:
	if current_tween:
		current_tween.kill()
	current_tween = create_tween()
	center_callout.scale = Vector2(1.08, 1.08)
	current_tween.tween_property(center_callout, "scale", Vector2.ONE, 0.22)

func _is_preferred_distance(ranges: Array) -> bool:
	return ranges.has(distance)

func _is_enemy_preferred_distance() -> bool:
	return enemy.get("preferred", []).has(distance)

func _ranges_text(ranges: Array) -> String:
	var values := []
	for value in ranges:
		values.append(str(value))
	return ",".join(values)

func _enemy_glyph() -> String:
	var category: String = enemy.get("intent_category", "")
	match category:
		"攻击":
			return "⚔"
		"杀招":
			return "✦"
		"步法":
			return "⇄"
		"架势":
			return "◆"
		_:
			return "?"
