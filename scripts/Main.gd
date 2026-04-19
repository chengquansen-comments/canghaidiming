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

func _ready() -> void:
	_load_game_data()
	_build_ui()
	if data_load_error != "":
		_show_data_error()
		return
	_show_class_select()


func _build_ui() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)

	var background := ColorRect.new()
	background.color = Color("0d1218")
	background.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(background)

	var sky_glow := ColorRect.new()
	sky_glow.color = Color(0.24, 0.18, 0.08, 0.22)
	sky_glow.anchor_right = 1.0
	sky_glow.anchor_bottom = 0.42
	add_child(sky_glow)

	var mist := ColorRect.new()
	mist.color = Color(0.65, 0.71, 0.78, 0.06)
	mist.anchor_top = 0.55
	mist.anchor_right = 1.0
	mist.anchor_bottom = 1.0
	add_child(mist)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	add_child(margin)

	root_container = VBoxContainer.new()
	root_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_container.add_theme_constant_override("separation", 14)
	margin.add_child(root_container)

	title_label = Label.new()
	title_label.text = "大明之沧海嘀鸣：单局战斗 Demo"
	title_label.add_theme_font_size_override("font_size", 28)
	title_label.modulate = Color("f5ebd0")
	root_container.add_child(title_label)

	subtitle_label = Label.new()
	subtitle_label.text = "围绕争机、势、距的单局原型。"
	subtitle_label.modulate = Color("b8c0cc")
	root_container.add_child(subtitle_label)

	battle_field_panel = _create_panel()
	battle_field_panel.custom_minimum_size = Vector2(0, 280)
	root_container.add_child(battle_field_panel)

	var battle_margin := MarginContainer.new()
	battle_margin.add_theme_constant_override("margin_left", 18)
	battle_margin.add_theme_constant_override("margin_right", 18)
	battle_margin.add_theme_constant_override("margin_top", 16)
	battle_margin.add_theme_constant_override("margin_bottom", 16)
	battle_field_panel.add_child(battle_margin)

	var battle_box := VBoxContainer.new()
	battle_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	battle_box.add_theme_constant_override("separation", 14)
	battle_margin.add_child(battle_box)

	var battle_header := HBoxContainer.new()
	battle_box.add_child(battle_header)

	battle_badge = Label.new()
	battle_badge.text = "演武未开"
	battle_badge.add_theme_font_size_override("font_size", 22)
	battle_badge.modulate = Color("f0d083")
	battle_header.add_child(battle_badge)

	var battle_hint := Label.new()
	battle_hint.text = "削势打断、稳架完格、抓崩塌处决"
	battle_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	battle_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	battle_hint.modulate = Color("9caab7")
	battle_header.add_child(battle_hint)

	var stage := HBoxContainer.new()
	stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stage.alignment = BoxContainer.ALIGNMENT_CENTER
	stage.add_theme_constant_override("separation", 18)
	battle_box.add_child(stage)

	player_avatar = _build_avatar(stage, "我方", Color("355d73"))
	var center_column := VBoxContainer.new()
	center_column.custom_minimum_size = Vector2(360, 0)
	center_column.alignment = BoxContainer.ALIGNMENT_CENTER
	center_column.add_theme_constant_override("separation", 8)
	stage.add_child(center_column)

	center_callout = Label.new()
	center_callout.text = "战场"
	center_callout.add_theme_font_size_override("font_size", 20)
	center_callout.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center_callout.modulate = Color("d4c6a3")
	center_column.add_child(center_callout)

	var distance_title := Label.new()
	distance_title.text = "距离刻度"
	distance_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	distance_title.modulate = Color("92a0ad")
	center_column.add_child(distance_title)

	distance_track = HBoxContainer.new()
	distance_track.alignment = BoxContainer.ALIGNMENT_CENTER
	distance_track.add_theme_constant_override("separation", 8)
	center_column.add_child(distance_track)
	_build_distance_track()

	enemy_avatar = _build_avatar(stage, "敌方", Color("73423b"))

	var top_split := HBoxContainer.new()
	top_split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	top_split.add_theme_constant_override("separation", 16)
	root_container.add_child(top_split)

	player_label = _build_panel_text(top_split, "玩家军情")
	enemy_label = _build_panel_text(top_split, "敌方军情")
	intent_label = _build_panel_text(top_split, "敌方招式意图")

	hand_label = Label.new()
	hand_label.text = "手牌"
	hand_label.add_theme_font_size_override("font_size", 22)
	hand_label.modulate = Color("f5ebd0")
	root_container.add_child(hand_label)

	var hand_panel := _create_panel()
	hand_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_container.add_child(hand_panel)

	hand_flow = HFlowContainer.new()
	hand_flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hand_flow.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hand_flow.add_theme_constant_override("h_separation", 10)
	hand_flow.add_theme_constant_override("v_separation", 10)
	hand_panel.add_child(hand_flow)

	var controls := HBoxContainer.new()
	controls.add_theme_constant_override("separation", 12)
	root_container.add_child(controls)

	action_button = Button.new()
	action_button.text = "结束回合"
	action_button.pressed.connect(_on_end_turn_pressed)
	_style_button(action_button, Color("8f5d2d"))
	controls.add_child(action_button)

	next_button = Button.new()
	next_button.text = "下一场"
	next_button.visible = false
	next_button.pressed.connect(_on_next_pressed)
	_style_button(next_button, Color("4c6d80"))
	controls.add_child(next_button)

	var log_title := Label.new()
	log_title.text = "战斗记录"
	log_title.add_theme_font_size_override("font_size", 22)
	log_title.modulate = Color("f5ebd0")
	root_container.add_child(log_title)

	log_panel = _create_panel()
	log_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_container.add_child(log_panel)

	log_label = RichTextLabel.new()
	log_label.fit_content = true
	log_label.bbcode_enabled = true
	log_label.scroll_following = true
	log_label.scroll_active = true
	log_panel.add_child(log_label)

	overlay_scrim = ColorRect.new()
	overlay_scrim.visible = false
	overlay_scrim.color = Color(0.01, 0.02, 0.03, 0.72)
	overlay_scrim.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(overlay_scrim)

	overlay_panel = PanelContainer.new()
	overlay_panel.visible = false
	overlay_panel.custom_minimum_size = Vector2(620, 0)
	overlay_panel.anchor_left = 0.5
	overlay_panel.anchor_top = 0.15
	overlay_panel.anchor_right = 0.5
	overlay_panel.anchor_bottom = 0.15
	overlay_panel.offset_left = -310
	overlay_panel.offset_right = 310
	overlay_panel.modulate = Color(1, 1, 1, 0)
	overlay_panel.add_theme_stylebox_override("panel", _make_panel_style(Color("2a2018"), Color("cfb889"), 2, 22))
	add_child(overlay_panel)

	var overlay_margin := MarginContainer.new()
	overlay_margin.add_theme_constant_override("margin_left", 20)
	overlay_margin.add_theme_constant_override("margin_right", 20)
	overlay_margin.add_theme_constant_override("margin_top", 18)
	overlay_margin.add_theme_constant_override("margin_bottom", 18)
	overlay_panel.add_child(overlay_margin)

	var overlay_box := VBoxContainer.new()
	overlay_box.add_theme_constant_override("separation", 10)
	overlay_margin.add_child(overlay_box)

	overlay_title = Label.new()
	overlay_title.add_theme_font_size_override("font_size", 24)
	overlay_box.add_child(overlay_title)

	overlay_body = RichTextLabel.new()
	overlay_body.fit_content = true
	overlay_body.bbcode_enabled = true
	overlay_box.add_child(overlay_body)

	overlay_actions = VBoxContainer.new()
	overlay_actions.add_theme_constant_override("separation", 8)
	overlay_box.add_child(overlay_actions)


func _build_panel_text(parent: Control, heading: String) -> RichTextLabel:
	var panel := _create_panel()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)

	var label := Label.new()
	label.text = heading
	label.add_theme_font_size_override("font_size", 20)
	label.modulate = Color("f2dfbd")
	box.add_child(label)

	var rich := RichTextLabel.new()
	rich.bbcode_enabled = true
	rich.fit_content = true
	rich.scroll_active = false
	rich.selection_enabled = false
	rich.modulate = Color("dbe4eb")
	box.add_child(rich)
	return rich


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


func _build_avatar(parent: Control, title: String, accent: Color) -> PanelContainer:
	var shell := PanelContainer.new()
	shell.custom_minimum_size = Vector2(260, 144)
	shell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shell.add_theme_stylebox_override("panel", _make_panel_style(accent.darkened(0.65), accent.lightened(0.1), 2, 24))
	parent.add_child(shell)

	var box := VBoxContainer.new()
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 8)
	shell.add_child(box)

	var title_label_local := Label.new()
	title_label_local.text = title
	title_label_local.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label_local.modulate = Color("d8dce3")
	box.add_child(title_label_local)

	var figure := Label.new()
	figure.text = "●"
	figure.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	figure.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	figure.add_theme_font_size_override("font_size", 56)
	figure.modulate = accent.lightened(0.3)
	box.add_child(figure)

	var fx := Label.new()
	fx.text = ""
	fx.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fx.add_theme_font_size_override("font_size", 18)
	fx.modulate = Color(1, 1, 1, 0)
	box.add_child(fx)

	if title == "我方":
		player_avatar_label = figure
		player_fx_label = fx
	else:
		enemy_avatar_label = figure
		enemy_fx_label = fx
	return shell


func _build_distance_track() -> void:
	distance_nodes.clear()
	distance_labels.clear()
	for child in distance_track.get_children():
		child.queue_free()
	for value in range(map_length):
		var node := PanelContainer.new()
		node.custom_minimum_size = Vector2(56, 54)
		node.add_theme_stylebox_override("panel", _make_panel_style(Color("151d24"), Color("4f5a65"), 1, 16))
		distance_track.add_child(node)
		distance_nodes.append(node)

		var marker := Label.new()
		marker.text = str(value)
		marker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		marker.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		marker.add_theme_font_size_override("font_size", 16)
		node.add_child(marker)
		distance_labels.append(marker)


func _load_game_data() -> void:
	data_load_error = ""
	class_defs = _load_json_file(DATA_PATHS["classes"], TYPE_DICTIONARY, "开局模板")
	card_defs = _load_json_file(DATA_PATHS["cards"], TYPE_DICTIONARY, "卡牌")
	effect_defs = _load_json_file(DATA_PATHS["effects"], TYPE_DICTIONARY, "效果类型")
	enemy_defs = _load_json_file(DATA_PATHS["enemies"], TYPE_ARRAY, "敌人")
	route_defs = _load_json_file(DATA_PATHS["routes"], TYPE_DICTIONARY, "路线节点")
	reward_pool = _load_json_file(DATA_PATHS["rewards"], TYPE_ARRAY, "奖励池")
	if data_load_error != "":
		return
	_build_enemy_lookup()
	_validate_game_data()


func _load_json_file(path: String, expected_type: int, label: String) -> Variant:
	if not FileAccess.file_exists(path):
		data_load_error = "%s 数据文件不存在：%s" % [label, path]
		push_error(data_load_error)
		return {} if expected_type == TYPE_DICTIONARY else []
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		data_load_error = "无法打开 %s 数据文件：%s" % [label, path]
		push_error(data_load_error)
		return {} if expected_type == TYPE_DICTIONARY else []
	var raw_text: String = file.get_as_text()
	var parsed: Variant = JSON.parse_string(raw_text)
	if parsed == null:
		data_load_error = "%s 数据文件 JSON 解析失败：%s" % [label, path]
		push_error(data_load_error)
		return {} if expected_type == TYPE_DICTIONARY else []
	if typeof(parsed) != expected_type:
		data_load_error = "%s 数据文件类型不正确：%s" % [label, path]
		push_error(data_load_error)
		return {} if expected_type == TYPE_DICTIONARY else []
	return parsed


func _validate_game_data() -> void:
	for effect_type in effect_defs.keys():
		var effect_def: Dictionary = effect_defs[effect_type]
		for required_key in ["handler", "required_fields"]:
			if not effect_def.has(required_key):
				_set_data_error("效果类型 %s 缺少字段 %s" % [effect_type, required_key])
				return
		var handler_name: String = effect_def["handler"]
		if not has_method(handler_name):
			_set_data_error("效果类型 %s 绑定了不存在的处理器 %s" % [effect_type, handler_name])
			return

	for class_id in class_defs.keys():
		var class_def: Dictionary = class_defs[class_id]
		for required_key in ["name", "weapon", "preferred_ranges", "passive", "deck"]:
			if not class_def.has(required_key):
				_set_data_error("开局模板 %s 缺少字段 %s" % [class_id, required_key])
				return
		for card_id in class_def["deck"]:
			if not card_defs.has(card_id):
				_set_data_error("开局模板 %s 使用了不存在的卡牌 %s" % [class_id, card_id])
				return

	for card_id in card_defs.keys():
		var card_def: Dictionary = card_defs[card_id]
		for required_key in ["name", "category", "cost", "text", "effects"]:
			if not card_def.has(required_key):
				_set_data_error("卡牌 %s 缺少字段 %s" % [card_id, required_key])
				return
		for effect_index in range(card_def["effects"].size()):
			var effect: Dictionary = card_def["effects"][effect_index]
			if not effect.has("type"):
				_set_data_error("卡牌 %s 的效果 #%d 缺少字段 type" % [card_id, effect_index])
				return
			var effect_type: String = effect["type"]
			if not effect_defs.has(effect_type):
				_set_data_error("卡牌 %s 使用了未注册的效果类型 %s" % [card_id, effect_type])
				return
			var spec: Dictionary = effect_defs[effect_type]
			for required_field in spec["required_fields"]:
				if not effect.has(required_field):
					_set_data_error("卡牌 %s 的效果类型 %s 缺少字段 %s" % [card_id, effect_type, required_field])
					return

	for reward_card_id in reward_pool:
		if not card_defs.has(reward_card_id):
			_set_data_error("奖励池引用了不存在的卡牌 %s" % reward_card_id)
			return

	for enemy_index in range(enemy_defs.size()):
		var enemy_def: Dictionary = enemy_defs[enemy_index]
		for required_key in ["id", "name", "title", "max_hp", "max_momentum", "start_distance", "preferred_ranges", "passive", "intents"]:
			if not enemy_def.has(required_key):
				_set_data_error("敌人配置 #%d 缺少字段 %s" % [enemy_index, required_key])
				return
		if enemy_def["intents"].is_empty():
			_set_data_error("敌人 %s 至少需要 1 条意图" % enemy_def["id"])
			return

	for route_id in route_defs.keys():
		var route_def: Dictionary = route_defs[route_id]
		for required_key in ["title", "kind", "next"]:
			if not route_def.has(required_key):
				_set_data_error("路线节点 %s 缺少字段 %s" % [route_id, required_key])
				return
		if route_def["kind"] == "battle":
			for required_key in ["enemy_id", "map_length", "initial_distance"]:
				if not route_def.has(required_key):
					_set_data_error("战斗路线节点 %s 缺少字段 %s" % [route_id, required_key])
					return
			if not enemy_def_by_id.has(route_def["enemy_id"]):
				_set_data_error("路线节点 %s 引用了不存在的敌人 %s" % [route_id, route_def["enemy_id"]])
				return
		for next_id in route_def["next"]:
			if not route_defs.has(next_id):
				_set_data_error("路线节点 %s 指向了不存在的下一节点 %s" % [route_id, next_id])
				return


func _build_enemy_lookup() -> void:
	enemy_def_by_id.clear()
	for enemy_def in enemy_defs:
		enemy_def_by_id[enemy_def["id"]] = enemy_def


func _set_data_error(message: String) -> void:
	data_load_error = message
	push_error(message)


func _show_data_error() -> void:
	_refresh_ui()
	_show_overlay(
		"数据加载失败",
		"[b]配表读取失败。[/b]\n\n%s\n\n请检查 `res://data` 下的 JSON 文件。" % data_load_error,
		[]
	)


func _show_class_select() -> void:
	player_class_id = ""
	battle_index = 0
	victory = false
	reward_pending = false
	battle_over = false
	current_node_id = ""
	current_enemy_node_id = ""
	available_next_nodes.clear()
	visited_nodes.clear()
	battle_log.clear()
	var class_actions := []
	var class_ids := class_defs.keys()
	class_ids.sort()
	for class_id in class_ids:
		var class_def: Dictionary = class_defs[class_id]
		class_actions.append({
			"text": "%s｜%s" % [class_def["name"], class_def["weapon"]],
			"callback": Callable(self, "_start_run").bind(class_id)
		})
	_show_overlay(
		"选择开局模板",
		"[b]按单局设计方案的 MVP 开局：[/b]\n选择一条武器流派，进入 6 场连续战斗。\n\n配表位置：`res://data/classes.json`",
		class_actions
	)
	_refresh_ui()


func _start_run(class_id: String) -> void:
	player_class_id = class_id
	_build_route_map()
	var class_def: Dictionary = class_defs[class_id]
	player = {
		"name": class_def["name"],
		"weapon": class_def["weapon"],
		"preferred_ranges": class_def["preferred_ranges"].duplicate(),
		"max_hp": 72,
		"hp": 72,
		"max_momentum": MAX_MOMENTUM,
		"momentum": 5,
		"guard": 0,
		"passive": class_def["passive"],
		"deck": class_def["deck"].duplicate(),
		"bonus_next_attack_damage": 0,
		"bonus_first_attack_momentum": 0,
		"first_attack_used": false,
		"took_damage_this_turn": false,
		"flags": {}
	}
	_hide_overlay()
	current_node_id = "start"
	visited_nodes = ["start"]
	_show_route_map("军旅路线", "选择第一站。不同节点会影响你的牌组、血量和接下来的敌人。", route_nodes["start"]["next"])


func _start_battle() -> void:
	battle_over = false
	reward_pending = false
	next_button.visible = false
	action_button.visible = true
	action_button.disabled = false
	hand.clear()
	discard_pile.clear()
	draw_pile = player["deck"].duplicate()
	draw_pile.shuffle()
	var current_battle_node: Dictionary = route_nodes[current_enemy_node_id]
	map_length = current_battle_node.get("map_length", 9)
	initial_distance = current_battle_node.get("initial_distance", 2)
	_setup_battle_positions()
	_build_distance_track()
	var enemy_def: Dictionary = enemy_def_by_id[current_battle_node["enemy_id"]]
	enemy = {
		"id": enemy_def["id"],
		"name": enemy_def["name"],
		"title": enemy_def["title"],
		"max_hp": enemy_def["max_hp"],
		"hp": enemy_def["max_hp"],
		"max_momentum": enemy_def["max_momentum"],
		"momentum": mini(6, enemy_def["max_momentum"]),
		"guard": 0,
		"passive": enemy_def["passive"],
		"preferred_ranges": enemy_def["preferred_ranges"].duplicate(),
		"intents": enemy_def["intents"],
		"intent_index": 0,
		"current_intent": {},
		"collapsed": false,
		"next_attack_critical": false,
		"flags": {}
	}
	_sync_distance_from_positions()
	if player["flags"].get("ambush_next_battle", false):
		enemy["momentum"] = maxi(enemy["momentum"] - 2, 0)
		player["flags"]["ambush_next_battle"] = false
		_log("你提前夜袭布置成功，敌方开局 -2 势。")
	battle_index += 1
	player["guard"] = 0
	player["momentum"] = clampi(player["momentum"] + 1, 0, MAX_MOMENTUM)
	player["first_attack_used"] = false
	player["took_damage_this_turn"] = false
	player["flags"] = {}
	_log("[b]%s[/b] 开始，抵达节点 [color=#95e1d3]%s[/color]，遭遇 [color=#f0d083]%s[/color]（%s）。" % [_battle_name(), route_nodes[current_enemy_node_id]["title"], enemy["name"], enemy["title"]])
	_show_fx(enemy_fx_label, enemy["title"], Color("f0d083"))
	_begin_player_turn(true)


func _battle_name() -> String:
	return "第 %d 战" % [battle_index]


func _begin_player_turn(is_new_battle := false) -> void:
	player["guard"] = 0
	player["first_attack_used"] = false
	player["took_damage_this_turn"] = false
	player["flags"] = {}
	player["bonus_next_attack_damage"] = 0
	player["bonus_first_attack_momentum"] = 0

	var gain := 3
	if player_class_id == "spear" and _is_preferred_distance(player["preferred_ranges"]):
		gain += 1
		player["bonus_first_attack_momentum"] = 1
		_log("你在优势距离起势，额外获得 1 势，且本回合首次攻击额外削敌 1 势。")
	if enemy["id"] == "dual_ronin":
		enemy["momentum"] = clampi(enemy["momentum"] + 1, 0, enemy["max_momentum"])
	if enemy["id"] == "captain_boss" and enemy["collapsed"]:
		enemy["momentum"] = clampi(enemy["momentum"] + 1, 0, enemy["max_momentum"])
	player["momentum"] = clampi(player["momentum"] + gain, 0, player["max_momentum"])

	if not is_new_battle:
		_log("[b]新回合[/b]：你恢复 %d 势。" % [gain])

	enemy["guard"] = 0
	_prepare_enemy_intent()
	_draw_to_hand(HAND_SIZE)
	_refresh_ui()


func _prepare_enemy_intent() -> void:
	var base_gain := 3
	if enemy["id"] == "raider":
		base_gain = 4
	elif enemy["id"] == "dual_ronin":
		base_gain = 4
	if _is_enemy_preferred_distance():
		base_gain += 1
	if enemy["id"] == "captain_boss" and _is_enemy_preferred_distance():
		base_gain += 1
	enemy["momentum"] = clampi(enemy["momentum"] + base_gain, 0, enemy["max_momentum"])

	var intents: Array = enemy["intents"]
	enemy["current_intent"] = intents[enemy["intent_index"] % intents.size()].duplicate()
	enemy["intent_index"] += 1


func _draw_to_hand(target_size: int) -> void:
	while hand.size() < target_size:
		if draw_pile.is_empty():
			if discard_pile.is_empty():
				break
			draw_pile = discard_pile.duplicate()
			discard_pile.clear()
			draw_pile.shuffle()
		hand.append(draw_pile.pop_back())


func _setup_battle_positions() -> void:
	initial_distance = clampi(initial_distance, 0, map_length - 1)
	var free_space: int = map_length - 1 - initial_distance
	player_position = free_space / 2
	enemy_position = player_position + initial_distance
	_sync_distance_from_positions()


func _sync_distance_from_positions() -> void:
	distance = maxi(enemy_position - player_position, 0)


func _apply_distance_delta(amount: int, actor: String) -> void:
	if amount == 0:
		return
	var before_distance := distance
	if actor == "player":
		if amount > 0:
			player_position = maxi(player_position - amount, 0)
		else:
			player_position = mini(player_position + abs(amount), enemy_position)
	else:
		if amount > 0:
			player_position = maxi(player_position - amount, 0)
		else:
			enemy_position = maxi(enemy_position - abs(amount), player_position)
	_sync_distance_from_positions()
	if before_distance == distance:
		_log("已抵地图边界，无法再退。")
		_show_fx(center_callout, "边界受限", Color("f0d083"))
		return
	var op := "+" if amount > 0 else ""
	_log("距离 %s%d，当前为 %d。" % [op, amount, distance])
	_animate_distance_shift()


func _build_route_map() -> void:
	route_nodes.clear()
	for node_id in route_defs.keys():
		route_nodes[node_id] = route_defs[node_id].duplicate(true)


func _show_route_map(title: String, body: String, node_ids: Array) -> void:
	available_next_nodes = node_ids.duplicate()
	var actions := []
	for node_id in node_ids:
		var node: Dictionary = route_nodes[node_id]
		actions.append({
			"text": "%s｜%s" % [_node_kind_label(node["kind"]), node["title"]],
			"callback": Callable(self, "_select_route_node").bind(node_id)
		})
	_show_overlay(title, "%s\n\n%s" % [body, _route_summary_text(node_ids)], actions)


func _select_route_node(node_id: String) -> void:
	current_node_id = node_id
	if not visited_nodes.has(node_id):
		visited_nodes.append(node_id)
	_hide_overlay()
	_resolve_current_node()


func _resolve_current_node() -> void:
	var node: Dictionary = route_nodes[current_node_id]
	match node["kind"]:
		"battle":
			current_enemy_node_id = current_node_id
			_start_battle()
		"camp":
			_resolve_camp_node(node)
		"school":
			_resolve_school_node(node)
		"order":
			_resolve_order_node(node)
		"start":
			_show_route_map("军旅路线", "从起点出发，选择下一处去向。", node["next"])


func _resolve_camp_node(node: Dictionary) -> void:
	var heal: int = node.get("heal", 10)
	var actual_heal := mini(heal, player["max_hp"] - player["hp"])
	player["hp"] += actual_heal
	_log("你在行营修整，回复了 %d 点生命。" % actual_heal)
	_show_route_map("行营修整", "你在军中短暂休整，补足气血后继续前行。", node["next"])
	_refresh_ui()


func _resolve_school_node(node: Dictionary) -> void:
	reward_pending = true
	reward_options.clear()
	var pool := reward_pool.duplicate()
	pool.shuffle()
	for i in range(3):
		reward_options.append(pool[i])
	var actions := []
	for card_id in reward_options:
		actions.append({"text": _reward_text(card_id), "callback": Callable(self, "_pick_reward_from_school").bind(card_id, node["next"])})
	_show_overlay("校场演武", "校场教习开放三门军技，择其一习得后继续赶路。", actions)
	_refresh_ui()


func _resolve_order_node(node: Dictionary) -> void:
	_show_overlay(
		"军令抉择",
		"夜里传令至营前。你可以稳妥整备，也可以冒险强袭，后续路线会保持不变。",
		[
			{"text": "谨慎潜伏｜回复 6 血", "callback": Callable(self, "_apply_order_choice").bind("heal", node["next"])},
			{"text": "接令强袭｜下战敌势 -2", "callback": Callable(self, "_apply_order_choice").bind("ambush", node["next"])},
			{"text": "教头点拨｜习得 1 张牌", "callback": Callable(self, "_apply_order_choice").bind("train", node["next"])}
		]
	)


func _apply_order_choice(choice: String, next_nodes: Array) -> void:
	match choice:
		"heal":
			var heal := mini(6, player["max_hp"] - player["hp"])
			player["hp"] += heal
			_log("你选择谨慎潜伏，回复了 %d 点生命。" % heal)
		"ambush":
			player["flags"]["ambush_next_battle"] = true
			_log("你接令强袭，下场战斗敌方开局 -2 势。")
		"train":
			var pool := reward_pool.duplicate()
			pool.shuffle()
			var learned_card: String = pool[0]
			player["deck"].append(learned_card)
			_log("教头点拨后，你习得了 [color=#95e1d3]%s[/color]。" % card_defs[learned_card]["name"])
	_show_route_map("继续行军", "处理完军令后，你继续沿路线推进。", next_nodes)
	_refresh_ui()


func _pick_reward_from_school(card_id: String, next_nodes: Array) -> void:
	player["deck"].append(card_id)
	reward_pending = false
	_log("你在校场习得了 [color=#95e1d3]%s[/color]。" % card_defs[card_id]["name"])
	_show_route_map("继续行军", "演武结束，选择下一处去向。", next_nodes)
	_refresh_ui()


func _node_kind_label(kind: String) -> String:
	match kind:
		"battle":
			return "战"
		"camp":
			return "营"
		"school":
			return "校"
		"order":
			return "令"
		_:
			return "起"


func _route_summary_text(node_ids: Array) -> String:
	var parts := []
	for node_id in node_ids:
		var node: Dictionary = route_nodes[node_id]
		var extra := ""
		match node["kind"]:
			"battle":
				var enemy_id: String = node["enemy_id"]
				var enemy_def: Dictionary = enemy_def_by_id[enemy_id]
				extra = "遭遇 %s" % enemy_def["name"]
			"camp":
				extra = "回复 %d 血" % node.get("heal", 10)
			"school":
				extra = "三选一卡"
			"order":
				extra = "事件抉择"
		parts.append("- %s：%s" % [node["title"], extra])
	return "\n".join(parts)


func _refresh_ui() -> void:
	player_label.text = _player_status_text()
	enemy_label.text = _enemy_status_text()
	intent_label.text = _intent_status_text()
	hand_label.text = "手牌（%d）" % hand.size()
	if player_class_id == "":
		battle_badge.text = "演武未开"
	elif current_node_id == "":
		battle_badge.text = "军旅待发"
	else:
		var node_title := ""
		if route_nodes.has(current_node_id):
			node_title = route_nodes[current_node_id]["title"]
		battle_badge.text = "%s｜%s" % [_battle_name() if not enemy.is_empty() else "路线推进", node_title]
	center_callout.text = "地图长度：%d｜当前距离：%d" % [map_length, distance]
	_refresh_battlefield_visuals()
	_refresh_distance_track()
	_refresh_hand_buttons()
	_refresh_log()


func _player_status_text() -> String:
	if player.is_empty():
		return "等待开局。"
	return "[b]%s[/b]｜%s\n生命：%d/%d\n势：%d/%d\n格挡：%d\n优势距离：%s\n当前位置：%d/%d\n当前距离：[color=#95e1d3]%d[/color]\n被动：%s" % [
		player["name"], player["weapon"], player["hp"], player["max_hp"], player["momentum"], player["max_momentum"],
		player["guard"], _ranges_text(player["preferred_ranges"]), player_position, map_length - 1, distance, player["passive"]
	]


func _enemy_status_text() -> String:
	if enemy.is_empty():
		return "尚未遭遇敌人。"
	var collapse_text := "\n[color=#ff8a7a]状态：崩塌，下次受击必暴击。[/color]" if enemy["collapsed"] else ""
	return "[b]%s[/b]｜%s\n生命：%d/%d\n势：%d/%d\n格挡：%d\n优势距离：%s\n当前位置：%d/%d\n被动：%s%s" % [
		enemy["name"], enemy["title"], enemy["hp"], enemy["max_hp"], enemy["momentum"], enemy["max_momentum"],
		enemy["guard"], _ranges_text(enemy["preferred_ranges"]), enemy_position, map_length - 1, enemy["passive"], collapse_text
	]


func _intent_status_text() -> String:
	if enemy.is_empty() or enemy["current_intent"].is_empty():
		return "暂无意图。"
	var intent: Dictionary = enemy["current_intent"]
	var move_text := "不改距"
	if intent.has("move_to"):
		move_text = "调整到距离 %d" % intent["move_to"]
	elif intent.has("move_delta"):
		move_text = "距离 %+d" % intent["move_delta"]
	var extras := []
	if intent.has("guard"):
		extras.append("获得 %d 格挡" % intent["guard"])
	if intent.has("tags"):
		extras.append("标签：" + " / ".join(intent["tags"]))
	return "[b]%s[/b]\n预计耗势：%d\n行动：%s\n预计伤害：%d\n预计削势：%d\n%s" % [
		intent["name"],
		intent["cost"],
		move_text,
		intent.get("damage", 0),
		intent.get("momentum_damage", 0),
		"｜".join(extras)
	]


func _refresh_hand_buttons() -> void:
	for child in hand_flow.get_children():
		child.queue_free()
	for i in range(hand.size()):
		var card_id: String = hand[i]
		var def: Dictionary = card_defs[card_id]
		var button := Button.new()
		button.custom_minimum_size = Vector2(250, 138)
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.text = "%s\n%s｜耗势 %d\n%s" % [def["name"], def["category"], _card_cost(card_id), def["text"]]
		button.disabled = battle_over or reward_pending or _card_cost(card_id) > player["momentum"]
		_style_card_button(button, def["category"])
		button.pressed.connect(_on_card_pressed.bind(i))
		hand_flow.add_child(button)


func _refresh_log() -> void:
	log_label.text = "\n".join(battle_log.slice(maxi(battle_log.size() - 18, 0), battle_log.size()))


func _refresh_battlefield_visuals() -> void:
	if player.is_empty():
		player_avatar_label.text = "●"
		enemy_avatar_label.text = "●"
		return
	player_avatar_label.text = "枪" if player_class_id == "spear" else "刀"
	enemy_avatar_label.text = _enemy_glyph()
	player_avatar.modulate = Color("ffffff")
	enemy_avatar.modulate = Color("ffffff") if not enemy.get("collapsed", false) else Color("ffb1a8")


func _refresh_distance_track() -> void:
	for i in range(distance_nodes.size()):
		var node := distance_nodes[i]
		var label := distance_labels[i]
		var marker_text := str(i)
		var occupied := false
		if i == player_position and i == enemy_position:
			marker_text += "\n我·敌"
			occupied = true
		elif i == player_position:
			marker_text += "\n我"
			occupied = true
		elif i == enemy_position:
			marker_text += "\n敌"
			occupied = true
		label.text = marker_text
		if occupied:
			node.add_theme_stylebox_override("panel", _make_panel_style(Color("324b5d"), Color("9ad5ff"), 2, 16))
			label.modulate = Color("f6f9fb")
		else:
			node.add_theme_stylebox_override("panel", _make_panel_style(Color("151d24"), Color("4f5a65"), 1, 16))
			label.modulate = Color("95a5b1")


func _style_card_button(button: Button, category: String) -> void:
	var accent: Color = CATEGORY_COLORS.get(category, Color("718093"))
	button.add_theme_font_size_override("font_size", 17)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	button.add_theme_color_override("font_color", Color("f7f2e8"))
	button.add_theme_color_override("font_disabled_color", Color("8c9096"))
	button.add_theme_stylebox_override("normal", _make_panel_style(accent.darkened(0.72), accent, 2, 16))
	button.add_theme_stylebox_override("hover", _make_panel_style(accent.darkened(0.58), accent.lightened(0.25), 2, 16))
	button.add_theme_stylebox_override("pressed", _make_panel_style(accent.darkened(0.82), accent.lightened(0.1), 2, 16))
	button.add_theme_stylebox_override("disabled", _make_panel_style(Color("1a2128"), Color("3c454f"), 1, 16))


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


func _card_cost(card_id: String) -> int:
	var cost: int = card_defs[card_id]["cost"]
	if card_id == "dragonslash" and enemy.get("collapsed", false):
		return 0
	if card_id == "dragon_break" and enemy.get("collapsed", false):
		return maxi(cost - 2, 0)
	return cost


func _on_card_pressed(index: int) -> void:
	if battle_over or reward_pending:
		return
	var card_id: String = hand[index]
	var cost: int = _card_cost(card_id)
	if cost > player["momentum"]:
		return
	player["momentum"] -= cost
	var card: Dictionary = card_defs[card_id]
	_log("你使出 [color=#95e1d3]%s[/color]。" % card["name"])
	_flash_avatar(player_avatar, Color("95e1d3"))
	_show_fx(player_fx_label, card["name"], CATEGORY_COLORS.get(card["category"], Color.WHITE))
	_apply_card(card_id)
	discard_pile.append(card_id)
	hand.remove_at(index)
	if enemy["hp"] <= 0:
		_handle_enemy_defeated()
		return
	_refresh_ui()


func _apply_card(card_id: String) -> void:
	var card: Dictionary = card_defs[card_id]
	for effect in card["effects"]:
		_apply_effect(effect, card_id)


func _apply_effect(effect: Dictionary, card_id: String) -> void:
	if effect.get("if_preferred", false) and not _is_preferred_distance(player["preferred_ranges"]):
		return
	var effect_type: String = effect["type"]
	var effect_spec: Dictionary = effect_defs[effect_type]
	var handler_name: String = effect_spec["handler"]
	call(handler_name, effect, card_id)


func _effect_distance(effect: Dictionary, _card_id: String) -> void:
	_apply_distance_delta(effect["amount"], "player")


func _effect_set_distance_toward(effect: Dictionary, _card_id: String) -> void:
	var target: int = effect["target"]
	if distance < target:
		_apply_distance_delta(+1, "player")
	elif distance > target:
		_apply_distance_delta(-1, "player")


func _effect_set_distance_step_toward_preferred(_effect: Dictionary, _card_id: String) -> void:
	var target: int = player["preferred_ranges"][0]
	if not player["preferred_ranges"].has(distance):
		if distance < target:
			_apply_distance_delta(+1, "player")
		else:
			_apply_distance_delta(-1, "player")


func _effect_toggle_distance(_effect: Dictionary, _card_id: String) -> void:
	_apply_distance_delta(selected_distance_toggle, "player")
	selected_distance_toggle *= -1


func _effect_guard(effect: Dictionary, _card_id: String) -> void:
	var amount: int = effect["amount"]
	if effect.get("if_preferred", false) and not _is_preferred_distance(player["preferred_ranges"]):
		amount = 0
	player["guard"] += amount
	if amount > 0:
		_log("你获得 %d 格挡。" % amount)
		_show_fx(player_fx_label, "+%d 格挡" % amount, Color("7dd3a7"))


func _effect_momentum(effect: Dictionary, _card_id: String) -> void:
	player["momentum"] = clampi(player["momentum"] + effect["amount"], 0, player["max_momentum"])
	_log("你恢复 %d 势。" % effect["amount"])
	_show_fx(player_fx_label, "+%d 势" % effect["amount"], Color("8ec5ff"))


func _effect_enemy_momentum(effect: Dictionary, _card_id: String) -> void:
	var before: int = enemy["momentum"]
	enemy["momentum"] = clampi(enemy["momentum"] + effect["amount"], 0, enemy["max_momentum"])
	if effect["amount"] < 0:
		_log("敌方失去 %d 势。" % (before - enemy["momentum"]))
		_show_fx(enemy_fx_label, "-%d 势" % (before - enemy["momentum"]), Color("ffb05c"))
		if enemy["momentum"] <= 0:
			_collapse_enemy()


func _effect_draw(effect: Dictionary, _card_id: String) -> void:
	_draw_to_hand(mini(hand.size() + effect["amount"], HAND_SIZE + effect["amount"]))
	_log("你调整呼吸，补到 %d 张手牌。" % hand.size())


func _effect_buff_next_attack_damage(effect: Dictionary, _card_id: String) -> void:
	if _is_preferred_distance(player["preferred_ranges"]):
		player["bonus_next_attack_damage"] += effect["amount"]
		_log("你蓄起刀势，下一次攻击额外 +%d 伤害。" % effect["amount"])


func _effect_flag(effect: Dictionary, _card_id: String) -> void:
	player["flags"][effect["flag"]] = true


func _effect_attack(effect: Dictionary, card_id: String) -> void:
	_resolve_attack(effect, card_id)


func _resolve_attack(effect: Dictionary, card_id: String) -> void:
	var damage: int = effect["damage"]
	var momentum_damage: int = effect.get("momentum_damage", 0)

	if effect.has("range_bonus") and not effect["range_bonus"].has(distance):
		damage = maxi(damage - effect.get("range_penalty", 0), 0)
	if effect.has("bonus_damage_if_momentum_missing") and enemy["max_momentum"] - enemy["momentum"] >= 4:
		damage += effect["bonus_damage_if_momentum_missing"]
	if effect.get("override_damage_if_collapsed", 0) > 0 and enemy["collapsed"]:
		damage = effect["override_damage_if_collapsed"]
	if effect.get("bonus_damage_if_collapsed", 0) > 0 and enemy["collapsed"]:
		damage += effect["bonus_damage_if_collapsed"]
	if player_class_id == "saber" and not player["first_attack_used"]:
		damage += 2
	if player["bonus_next_attack_damage"] > 0:
		damage += player["bonus_next_attack_damage"]
		player["bonus_next_attack_damage"] = 0
	if player_class_id == "spear" and not player["first_attack_used"]:
		momentum_damage += player["bonus_first_attack_momentum"]

	var critical := false
	if effect.get("force_crit_if_collapsed", false) and enemy["collapsed"]:
		critical = true
	elif enemy["next_attack_critical"]:
		critical = true
	if critical:
		damage *= CRITICAL_MULTIPLIER
		enemy["next_attack_critical"] = false
		_log("[color=#ff8a7a]崩塌处决！[/color] 伤害翻倍。")
		_show_fx(center_callout, "处决", Color("ff8a7a"))

	player["first_attack_used"] = true

	var guard_block := mini(enemy["guard"], damage)
	enemy["guard"] -= guard_block
	damage -= guard_block
	if guard_block > 0:
		_log("敌方格挡了 %d 点伤害。" % guard_block)
		_show_fx(enemy_fx_label, "格挡 %d" % guard_block, Color("8fd1b4"))
	if damage > 0:
		enemy["hp"] = maxi(enemy["hp"] - damage, 0)
		_log("命中造成 %d 伤害。" % damage)
		_flash_avatar(enemy_avatar, Color("d86959"))
		_show_fx(enemy_fx_label, "-%d 血" % damage, Color("ff8a7a"))

	var before: int = enemy["momentum"]
	enemy["momentum"] = clampi(enemy["momentum"] - momentum_damage, 0, enemy["max_momentum"])
	if momentum_damage > 0:
		_log("同时削去敌方 %d 势。" % (before - enemy["momentum"]))
	if enemy["momentum"] <= 0 and before > 0:
		_collapse_enemy()


func _collapse_enemy() -> void:
	enemy["collapsed"] = true
	enemy["next_attack_critical"] = true
	_log("[color=#ff8a7a]%s 架势崩塌！本回合动作取消，下次受到攻击必暴击。[/color]" % enemy["name"])
	_flash_avatar(enemy_avatar, Color("ff8a7a"), 0.12)
	_show_fx(enemy_fx_label, "崩塌", Color("ff8a7a"))


func _on_end_turn_pressed() -> void:
	if battle_over or reward_pending:
		return
	_enemy_phase()


func _enemy_phase() -> void:
	var intent: Dictionary = enemy["current_intent"]
	for card_id in hand:
		discard_pile.append(card_id)
	hand.clear()

	if player["flags"].get("guard_frame", false) and not player["took_damage_this_turn"]:
		player["momentum"] = clampi(player["momentum"] + 1, 0, player["max_momentum"])
		_log("你守得沉稳，回合结束再回 1 势。")

	if enemy["collapsed"]:
		_log("%s 尚在崩塌中，本回合招式中断。" % enemy["name"])
		enemy["collapsed"] = false
		_show_fx(center_callout, "敌招中断", Color("f0d083"))
		_begin_player_turn()
		return

	if enemy["momentum"] < intent["cost"]:
		_log("%s 想施展 [color=#f0d083]%s[/color]，但势不足，被你打断。%s 露出破绽。" % [enemy["name"], intent["name"], enemy["name"]])
		enemy["collapsed"] = true
		enemy["next_attack_critical"] = true
		_show_fx(center_callout, "打断成功", Color("f0d083"))
		_flash_avatar(enemy_avatar, Color("ff8a7a"), 0.1)
		_begin_player_turn()
		return

	enemy["momentum"] -= intent["cost"]
	if intent.has("move_to"):
		var target_distance: int = intent["move_to"]
		if distance < target_distance:
			_apply_distance_delta(+1, "enemy")
		elif distance > target_distance:
			_apply_distance_delta(-1, "enemy")
	elif intent.has("move_delta"):
		_apply_distance_delta(intent["move_delta"], "enemy")

	if intent.has("guard"):
		enemy["guard"] += intent["guard"]
		_log("%s 先稳住架势，获得 %d 格挡。" % [enemy["name"], intent["guard"]])
		_show_fx(enemy_fx_label, "+%d 格挡" % intent["guard"], Color("7dd3a7"))

	var damage: int = intent.get("damage", 0)
	if intent.has("range_bonus") and intent["range_bonus"].has(distance):
		damage += 2
	if enemy["id"] == "firearms_officer" and distance == 3:
		damage += 2

	var incoming: int = damage
	var guard_before: int = player["guard"]
	var blocked := mini(player["guard"], incoming)
	player["guard"] -= blocked
	incoming -= blocked
	if blocked > 0:
		_log("你格挡了 %d 点伤害。" % blocked)
		_show_fx(player_fx_label, "格挡 %d" % blocked, Color("7dd3a7"))
		var surplus: int = guard_before - damage
		if incoming == 0 and surplus <= 3:
			var stolen := mini(1, enemy["momentum"])
			enemy["momentum"] -= stolen
			player["momentum"] = clampi(player["momentum"] + 1, 0, player["max_momentum"])
			_log("[color=#95e1d3]完美格挡！[/color] 你吸走敌方 %d 势，并回 1 势。" % stolen)
			_flash_avatar(player_avatar, Color("95e1d3"), 0.1)
			_show_fx(center_callout, "完美格挡", Color("95e1d3"))

	var player_before_hp: int = player["hp"]
	if incoming > 0:
		player["hp"] = maxi(player["hp"] - incoming, 0)
		player["took_damage_this_turn"] = true
		_log("%s 的 [color=#f0d083]%s[/color] 命中，你受到 %d 伤害。" % [enemy["name"], intent["name"], incoming])
		_flash_avatar(enemy_avatar, Color("f0d083"))
		_flash_avatar(player_avatar, Color("d86959"))
		_show_fx(player_fx_label, "-%d 血" % incoming, Color("ff8a7a"))

	var momentum_loss: int = intent.get("momentum_damage", 0)
	if momentum_loss > 0:
		player["momentum"] = maxi(player["momentum"] - momentum_loss, 0)
		_log("你的势再被压掉 %d 点。" % momentum_loss)

	if player_before_hp - player["hp"] >= 10:
		player["momentum"] = maxi(player["momentum"] - 1, 0)
		_log("你吃到重击，额外失去 1 势。")

	if player["hp"] <= 0:
		_handle_player_defeated()
		return

	_begin_player_turn()


func _handle_enemy_defeated() -> void:
	battle_over = true
	action_button.disabled = true
	action_button.visible = false
	hand.clear()
	_log("[b]%s[/b] 击败了 [color=#f0d083]%s[/color]。" % [player["name"], enemy["name"]])
	var node: Dictionary = route_nodes[current_enemy_node_id]
	if node["next"].is_empty():
		victory = true
		_show_overlay(
			"单局完成",
			"[b]你击破了路线终点的头目。[/b]\n\n这版单局现在已经具备分支路线：你会在行营、校场、军令与遭遇战之间做选择，再把构筑和血线带进终局。",
			[
				{"text": "重新开局", "callback": Callable(self, "_show_class_select")}
			]
		)
		_refresh_ui()
		return
	enemy = {}
	_show_route_map("战后推进", "此战已胜，选择下一处节点继续单局。", node["next"])
	_refresh_ui()


func _reward_text(card_id: String) -> String:
	var def: Dictionary = card_defs[card_id]
	return "%s｜%s｜耗势 %d" % [def["name"], def["category"], def["cost"]]


func _handle_player_defeated() -> void:
	battle_over = true
	action_button.disabled = true
	action_button.visible = false
	hand.clear()
	var reason := "败于势竭"
	if not player["preferred_ranges"].has(distance):
		reason = "败于失距"
	elif player["momentum"] == 0:
		reason = "败于势竭"
	elif enemy["current_intent"].get("damage", 0) >= 12:
		reason = "败于贪刀未收"
	_show_overlay(
		"此局战败",
		"[b]%s[/b]\n\n你倒在了 %s 手下。可以直接重新开一局继续验证手感。" % [reason, enemy["name"]],
		[
			{"text": "重新开局", "callback": Callable(self, "_show_class_select")}
		]
	)
	_refresh_ui()


func _on_next_pressed() -> void:
	if reward_pending:
		return
	battle_index += 1
	_start_battle()


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
