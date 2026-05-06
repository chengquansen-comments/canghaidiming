extends Control
class_name NarrativeDemoController

const NarrativeStateScript := preload("res://scripts/narrative/narrative_state.gd")
const NarrativeFontHelper := preload("res://scripts/narrative/narrative_font_helper.gd")
const NarrativeCombatBridgeScript := preload("res://scripts/narrative/narrative_combat_bridge.gd")
const NarrativeStaticMapLayoutScript := preload("res://scripts/narrative/narrative_static_map_layout.gd")
const NarrativeRouteRuntime := preload("res://scripts/narrative/narrative_route_runtime.gd")
const NarrativeChoiceRuntime := preload("res://scripts/narrative/narrative_choice_runtime.gd")
const PROLOGUE_BACKGROUND_HINTS := {
	"p01_tide": "res://assets/pixel_battle/backgrounds/prologue_burning_village.png",
	"p04_blade": "res://assets/pixel_battle/backgrounds/prologue_burning_village.png",
	"p07_master_enter": "res://assets/pixel_battle/backgrounds/prologue_master_blocks_blade.png",
	"p08_master_cards": "res://assets/pixel_battle/backgrounds/prologue_master_blocks_blade.png",
	"p12_ten_years": "res://assets/pixel_battle/backgrounds/prologue_ten_years_later.png"
}
const PROLOGUE_PORTRAIT_HINTS := {
	"p02_father": {"name": "父亲", "path": ""},
	"p03_enemy": {"name": "敌人", "path": ""},
	"p05_child_card": {"name": "幼年主角", "path": "res://assets/pixel_battle/portraits/protagonist_child.png"},
	"p06_child_down": {"name": "敌人", "path": ""},
	"p07_master_enter": {"name": "师父", "path": "res://assets/pixel_battle/portraits/mentor_veteran.png"},
	"p08_master_cards": {"name": "师父", "path": "res://assets/pixel_battle/portraits/mentor_veteran.png"},
	"p11_dont_look": {"name": "师父", "path": "res://assets/pixel_battle/portraits/mentor_veteran.png"},
	"p12_ten_years": {"name": "主角 / 师父", "path": "res://assets/pixel_battle/portraits/protagonist_young.png"}
}
const SPEAKER_PORTRAIT_HINTS := {
	"主角": {"name": "主角：年轻武官", "path": "res://assets/pixel_battle/portraits/protagonist_young.png"},
	"师父": {"name": "师父：沉默老兵", "path": "res://assets/pixel_battle/portraits/mentor_veteran.png"},
	"上官": {"name": "军门上官", "path": "res://assets/pixel_battle/portraits/military_superior.png"},
	"Boss": {"name": "小股倭寇首领", "path": "res://assets/pixel_battle/portraits/wakou_leader.png"},
	"海商": {"name": "海商豪强", "path": "res://assets/pixel_battle/portraits/merchant_magnate.png"},
	"押运官": {"name": "失械案押运官", "path": "res://assets/pixel_battle/portraits/transport_officer.png"},
	"兵变营头": {"name": "兵变营头", "path": "res://assets/pixel_battle/portraits/mutiny_captain.png"},
	"敌方枪手": {"name": "敌方枪手", "path": "res://assets/pixel_battle/portraits/enemy_spearman_story.png"},
	"敌方刀客": {"name": "敌方刀客", "path": "res://assets/pixel_battle/portraits/enemy_blademaster_story.png"},
	"旧物": {"name": "旧物：官造火铳", "path": "res://assets/pixel_battle/relics/relic_ming_firearm.png"}
}

var narrative: NarrativeState
var combat_bridge: NarrativeCombatBridge
var map_layout: NarrativeStaticMapLayout
var root_panel: PanelContainer
var title_label: Label
var type_label: Label
var route_label: Label
var map_box: HBoxContainer
var visual_row: HBoxContainer
var art_frame: PanelContainer
var art_texture: TextureRect
var art_label: Label
var portrait_frame: PanelContainer
var portrait_texture: TextureRect
var portrait_label: Label
var body_label: RichTextLabel
var result_label: Label
var vars_label: Label
var combat_panel: PanelContainer
var combat_payload_label: Label
var request_battle_button: Button
var mock_win_button: Button
var choices_box: VBoxContainer
var continue_button: Button
var restart_button: Button
var showing_prologue := true
var waiting_result := false
var _route_runtime
var _choice_runtime

func _route_runtime_helper():
	if _route_runtime == null:
		_route_runtime = NarrativeRouteRuntime.new(self)
	return _route_runtime

func _choice_runtime_helper():
	if _choice_runtime == null:
		_choice_runtime = NarrativeChoiceRuntime.new(self)
	return _choice_runtime

func _ready() -> void:
	_build_ui()
	_force_cjk_font()
	_start_narrative()

func _force_cjk_font() -> void:
	NarrativeFontHelper.enforce(self)

func _build_ui() -> void:
	root_panel = PanelContainer.new()
	root_panel.anchor_left = 0.04
	root_panel.anchor_top = 0.04
	root_panel.anchor_right = 0.96
	root_panel.anchor_bottom = 0.96
	root_panel.offset_left = 0
	root_panel.offset_top = 0
	root_panel.offset_right = 0
	root_panel.offset_bottom = 0
	add_child(root_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_bottom", 24)
	root_panel.add_child(margin)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 10)
	margin.add_child(layout)

	title_label = Label.new()
	title_label.add_theme_font_size_override("font_size", 30)
	title_label.text = "《大明之沧海嘀鸣》"
	layout.add_child(title_label)

	type_label = Label.new()
	type_label.add_theme_font_size_override("font_size", 16)
	type_label.modulate = Color(0.82, 0.78, 0.68, 1.0)
	layout.add_child(type_label)

	route_label = Label.new()
	route_label.add_theme_font_size_override("font_size", 15)
	route_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	route_label.custom_minimum_size = Vector2(0, 42)
	route_label.modulate = Color(0.66, 0.78, 0.84, 1.0)
	layout.add_child(route_label)

	var map_scroll := HScrollContainer.new()
	map_scroll.custom_minimum_size = Vector2(0, 142)
	map_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	map_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	layout.add_child(map_scroll)

	map_box = HBoxContainer.new()
	map_box.add_theme_constant_override("separation", 10)
	map_scroll.add_child(map_box)

	visual_row = HBoxContainer.new()
	visual_row.add_theme_constant_override("separation", 10)
	visual_row.custom_minimum_size = Vector2(0, 170)
	layout.add_child(visual_row)

	art_frame = PanelContainer.new()
	art_frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	art_frame.custom_minimum_size = Vector2(0, 170)
	visual_row.add_child(art_frame)

	var art_stack := CenterContainer.new()
	art_frame.add_child(art_stack)

	art_texture = TextureRect.new()
	art_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art_texture.custom_minimum_size = Vector2(760, 160)
	art_stack.add_child(art_texture)

	art_label = Label.new()
	art_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	art_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	art_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	art_label.custom_minimum_size = Vector2(720, 0)
	art_label.modulate = Color(0.86, 0.82, 0.7, 1.0)
	art_stack.add_child(art_label)

	portrait_frame = PanelContainer.new()
	portrait_frame.custom_minimum_size = Vector2(190, 170)
	visual_row.add_child(portrait_frame)

	var portrait_stack := CenterContainer.new()
	portrait_frame.add_child(portrait_stack)

	portrait_texture = TextureRect.new()
	portrait_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait_texture.custom_minimum_size = Vector2(180, 160)
	portrait_stack.add_child(portrait_texture)

	portrait_label = Label.new()
	portrait_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	portrait_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	portrait_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	portrait_label.custom_minimum_size = Vector2(170, 0)
	portrait_label.modulate = Color(0.86, 0.82, 0.7, 1.0)
	portrait_stack.add_child(portrait_label)

	body_label = RichTextLabel.new()
	body_label.fit_content = false
	body_label.scroll_active = true
	body_label.bbcode_enabled = true
	body_label.custom_minimum_size = Vector2(0, 118)
	body_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_label.add_theme_font_size_override("normal_font_size", 22)
	layout.add_child(body_label)

	combat_panel = PanelContainer.new()
	combat_panel.visible = false
	layout.add_child(combat_panel)

	var combat_margin := MarginContainer.new()
	combat_margin.add_theme_constant_override("margin_left", 10)
	combat_margin.add_theme_constant_override("margin_top", 8)
	combat_margin.add_theme_constant_override("margin_right", 10)
	combat_margin.add_theme_constant_override("margin_bottom", 8)
	combat_panel.add_child(combat_margin)

	var combat_layout := VBoxContainer.new()
	combat_layout.add_theme_constant_override("separation", 6)
	combat_margin.add_child(combat_layout)

	combat_payload_label = Label.new()
	combat_payload_label.add_theme_font_size_override("font_size", 15)
	combat_payload_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	combat_payload_label.modulate = Color(0.82, 0.88, 0.9, 1.0)
	combat_layout.add_child(combat_payload_label)

	var combat_buttons := HBoxContainer.new()
	combat_buttons.add_theme_constant_override("separation", 8)
	combat_layout.add_child(combat_buttons)

	request_battle_button = Button.new()
	request_battle_button.text = "请求战斗"
	request_battle_button.custom_minimum_size = Vector2(140, 38)
	request_battle_button.pressed.connect(_on_request_battle_pressed)
	combat_buttons.add_child(request_battle_button)

	mock_win_button = Button.new()
	mock_win_button.text = "视为胜利继续"
	mock_win_button.custom_minimum_size = Vector2(170, 38)
	mock_win_button.pressed.connect(_on_mock_battle_win_pressed)
	combat_buttons.add_child(mock_win_button)

	result_label = Label.new()
	result_label.add_theme_font_size_override("font_size", 18)
	result_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result_label.modulate = Color(0.9, 0.84, 0.68, 1.0)
	layout.add_child(result_label)

	vars_label = Label.new()
	vars_label.add_theme_font_size_override("font_size", 18)
	vars_label.modulate = Color(0.72, 0.86, 0.9, 1.0)
	layout.add_child(vars_label)

	choices_box = VBoxContainer.new()
	choices_box.add_theme_constant_override("separation", 8)
	layout.add_child(choices_box)

	var button_row := HBoxContainer.new()
	button_row.add_theme_constant_override("separation", 10)
	layout.add_child(button_row)

	continue_button = Button.new()
	continue_button.text = "继续"
	continue_button.custom_minimum_size = Vector2(160, 44)
	continue_button.pressed.connect(_on_continue_pressed)
	button_row.add_child(continue_button)

	restart_button = Button.new()
	restart_button.text = "重开叙事"
	restart_button.custom_minimum_size = Vector2(160, 44)
	restart_button.pressed.connect(_start_narrative)
	button_row.add_child(restart_button)

func _start_narrative() -> void:
	narrative = NarrativeStateScript.new()
	combat_bridge = NarrativeCombatBridgeScript.new()
	map_layout = NarrativeStaticMapLayoutScript.new()
	map_layout.load_from_path()
	var ok := narrative.load_from_path()
	showing_prologue = true
	waiting_result = false
	result_label.text = ""
	if not ok:
		title_label.text = "叙事数据加载失败"
		body_label.text = "请检查 data/narrative/mvp_compressed_narrative.json"
		_set_art_placeholder("叙事数据加载失败。")
		_set_portrait_placeholder("无角色")
		_render_combat_bridge({})
		_render_map_strip()
		_force_cjk_font()
		return
	_render_next_prologue_step()
	_force_cjk_font()

func _clear_choices() -> void:
	for child in choices_box.get_children():
		child.queue_free()

func _clear_map() -> void:
	if map_box == null:
		return
	for child in map_box.get_children():
		child.queue_free()

func _on_continue_pressed() -> void:
	_choice_runtime_helper().on_continue_pressed()

func _render_next_prologue_step() -> void:
	_route_runtime_helper().render_next_prologue_step()

func _render_step_art(step: Dictionary) -> void:
	_route_runtime_helper().render_step_art(step)

func _render_step_portrait(step: Dictionary) -> void:
	_route_runtime_helper().render_step_portrait(step)

func _format_step(step: Dictionary) -> String:
	return _route_runtime_helper().format_step(step)

func _render_node() -> void:
	_route_runtime_helper().render_node()

func _render_combat_bridge(node: Dictionary) -> void:
	_route_runtime_helper().render_combat_bridge(node)

func _combat_payload_text(payload: Dictionary) -> String:
	return _route_runtime_helper().combat_payload_text(payload)

func _on_request_battle_pressed() -> void:
	_choice_runtime_helper().on_request_battle_pressed()

func _on_mock_battle_win_pressed() -> void:
	_choice_runtime_helper().on_mock_battle_win_pressed()

func _render_node_art(node: Dictionary) -> void:
	_route_runtime_helper().render_node_art(node)

func _render_node_portrait(node: Dictionary) -> void:
	_route_runtime_helper().render_node_portrait(node)

func _portrait_hint_for_speaker(speaker: String) -> Dictionary:
	return _route_runtime_helper().portrait_hint_for_speaker(speaker)

func _apply_portrait_hint(hint: Dictionary, fallback_name: String) -> void:
	_route_runtime_helper().apply_portrait_hint(hint, fallback_name)

func _set_art_from_path(path: String, fallback_text: String) -> void:
	_route_runtime_helper().set_art_from_path(path, fallback_text)

func _set_art_placeholder(text: String) -> void:
	_route_runtime_helper().set_art_placeholder(text)

func _set_portrait_from_path(path: String, fallback_text: String) -> void:
	_route_runtime_helper().set_portrait_from_path(path, fallback_text)

func _set_portrait_placeholder(text: String) -> void:
	_route_runtime_helper().set_portrait_placeholder(text)

func _render_map_strip() -> void:
	_route_runtime_helper().render_map_strip()

func _render_static_branch_map() -> void:
	_route_runtime_helper()._render_static_branch_map()

func _build_map_column(column: Dictionary) -> Control:
	return _route_runtime_helper()._build_map_column(column)

func _build_static_map_node_card(node_entry: Dictionary) -> Control:
	return _route_runtime_helper()._build_static_map_node_card(node_entry)

func _is_static_map_node_available(node_id: String) -> bool:
	return _route_runtime_helper()._is_static_map_node_available(node_id)

func _static_map_marker(is_current: bool, is_visited: bool, is_available: bool) -> String:
	return _route_runtime_helper()._static_map_marker(is_current, is_visited, is_available)

func _render_fallback_route_strip() -> void:
	_route_runtime_helper()._render_fallback_route_strip()

func _build_map_node_card(node_id: String) -> Control:
	return _route_runtime_helper()._build_map_node_card(node_id)

func _node_marker(node_id: String, is_current: bool, is_visited: bool) -> String:
	return _route_runtime_helper()._node_marker(node_id, is_current, is_visited)

func _node_type_icon(node_type: String) -> String:
	return _route_runtime_helper()._node_type_icon(node_type)

func _format_node(node: Dictionary) -> String:
	return _route_runtime_helper().format_node(node)

func _enemy_list_text(value: Variant) -> String:
	return _route_runtime_helper()._enemy_list_text(value)

func _choice_button_text(choice: Dictionary) -> String:
	return _choice_runtime_helper().choice_button_text(choice)

func _on_choice_pressed(index: int) -> void:
	_choice_runtime_helper().on_choice_pressed(index)

func _render_ending() -> void:
	_choice_runtime_helper().render_ending()
