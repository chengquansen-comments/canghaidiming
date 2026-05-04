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
	panel.add_theme_stylebox_override("panel", _make_panel_style(Color("18212a"), Color("52606d"), 1, 18))
	return panel

func _make_panel_style(fill: Color, border: Color, border_width: int, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	style.shadow_color = Color(0, 0, 0, 0.25)
	style.shadow_size = 6
	return style

func _style_button(button: Button, fill: Color) -> void:
	button.custom_minimum_size = Vector2(150, 48)
	button.add_theme_font_size_override("font_size", 18)
	var normal := _make_panel_style(fill, fill.lightened(0.15), 1, 14)
	var hover := _make_panel_style(fill.lightened(0.1), fill.lightened(0.3), 1, 14)
	var pressed := _make_panel_style(fill.darkened(0.15), fill.lightened(0.15), 1, 14)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("disabled", _make_panel_style(Color(fill.r, fill.g, fill.b, 0.4), Color("5d646b"), 1, 14))

func _show_overlay(title: String, body: String, actions: Array) -> void:
	overlay_title.text = title
	overlay_body.text = body
	for child in overlay_actions.get_children():
		child.queue_free()
	for action in actions:
		var button := Button.new()
		button.text = action["text"]
		_style_button(button, Color("6a4b2a"))
		button.pressed.connect(action["callback"])
		overlay_actions.add_child(button)
	overlay_scrim.visible = true
	overlay_panel.visible = true
	overlay_panel.scale = Vector2(0.96, 0.96)
	overlay_panel.modulate = Color(1, 1, 1, 0)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(overlay_panel, "modulate", Color(1, 1, 1, 1), 0.18)
	tween.tween_property(overlay_panel, "scale", Vector2.ONE, 0.2)

func _hide_overlay() -> void:
	overlay_panel.visible = false
	overlay_scrim.visible = false

func _log(message: String) -> void:
	battle_log.append(message)
	_refresh_log()

func _flash_avatar(target: PanelContainer, color: Color, scale_boost := 0.05) -> void:
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(target, "modulate", color, 0.08)
	tween.tween_property(target, "scale", Vector2.ONE * (1.0 + scale_boost), 0.08)
	tween.chain().set_parallel(true)
	tween.tween_property(target, "modulate", Color.WHITE, 0.18)
	tween.tween_property(target, "scale", Vector2.ONE, 0.18)

func _show_fx(label: Label, text: String, color: Color) -> void:
	label.text = text
	label.modulate = Color(color.r, color.g, color.b, 1.0)
	label.scale = Vector2.ONE
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "scale", Vector2(1.06, 1.06), 0.15)
	tween.chain()
	tween.tween_property(label, "scale", Vector2.ONE, 0.22)
	tween.tween_property(label, "modulate", Color(color.r, color.g, color.b, 0.0), 0.45)

func _animate_distance_shift() -> void:
	var tween := create_tween()
	tween.set_parallel(true)
	var player_bump := Vector2(1.04, 0.96) if distance >= 2 else Vector2(0.96, 1.04)
	var enemy_bump := Vector2(0.96, 1.04) if distance >= 2 else Vector2(1.04, 0.96)
	tween.tween_property(player_avatar, "scale", player_bump, 0.08)
	tween.tween_property(enemy_avatar, "scale", enemy_bump, 0.08)
	tween.tween_property(center_callout, "scale", Vector2(1.05, 1.05), 0.08)
	tween.chain().set_parallel(true)
	tween.tween_property(player_avatar, "scale", Vector2.ONE, 0.18)
	tween.tween_property(enemy_avatar, "scale", Vector2.ONE, 0.18)
	tween.tween_property(center_callout, "scale", Vector2.ONE, 0.18)

func _is_preferred_distance(ranges: Array) -> bool:
	return ranges.has(distance)

func _is_enemy_preferred_distance() -> bool:
	return enemy["preferred_ranges"].has(distance)

func _ranges_text(ranges: Array) -> String:
	var parts := []
	for value in ranges:
		parts.append(str(value))
	return " / ".join(parts)

func _enemy_glyph() -> String:
	if enemy.is_empty():
		return "●"
	match enemy.get("id", ""):
		"militia_spear", "captain_boss":
			return "枪"
		"shield_blade":
			return "盾"
		"firearms_officer":
			return "铳"
		_:
			return "刀"
