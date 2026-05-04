extends "res://scripts/battle_controller_visual_hot_tuning_pipeline.gd"

# Extracted from battle_controller_visual_hot_tuning.gd.
# Layer responsibility: battle_controller_visual_hot_tuning_ui.gd.

func _build_ui() -> void:
	super()
	_isolate_tuning_panel_input()
	_build_hot_tuning_controls()
	_load_number_configs()
	_refresh_tuning_panel()

func _unhandled_input(event: InputEvent) -> void:
	# F9 is handled in parent _input so it works even when panel controls have focus.
	# Keep this empty to avoid duplicate toggles.
	pass

func _start_session(role_id: String) -> void:
	_number_pipeline_baseline.clear()
	super._start_session(role_id)
	_sync_number_pipeline_fields_from_fighters()

func _isolate_tuning_panel_input() -> void:
	if tuning_panel == null:
		return
	tuning_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	if tuning_content_root != null:
		tuning_content_root.mouse_filter = Control.MOUSE_FILTER_STOP
	if tuning_label != null:
		tuning_label.mouse_filter = Control.MOUSE_FILTER_STOP
	if not tuning_panel.gui_input.is_connected(_on_tuning_panel_gui_input):
		tuning_panel.gui_input.connect(_on_tuning_panel_gui_input)

func _on_tuning_panel_gui_input(event: InputEvent) -> void:
	if event is InputEventMouse:
		get_viewport().set_input_as_handled()

func _build_hot_tuning_controls() -> void:
	if tuning_panel == null or tuning_label == null or _hot_controls_root != null:
		return
	var parent_container: VBoxContainer = tuning_content_root if tuning_content_root != null else null
	if parent_container == null:
		return
	tuning_label.custom_minimum_size = Vector2(392, 300)
	tuning_panel.offset_right = 452
	tuning_panel.offset_bottom = 640
	parent_container.custom_minimum_size = Vector2(412, 596)
	_hot_controls_root = VBoxContainer.new()
	_hot_controls_root.name = "HotTuningControls"
	_hot_controls_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_hot_controls_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hot_controls_root.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_hot_controls_root.add_theme_constant_override("separation", 4)
	parent_container.add_child(_hot_controls_root)
	_add_sample_buttons()
	_add_number_pipeline_controls()
	_add_number_config_controls()

func _add_sample_buttons() -> void:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var btn100 := Button.new()
	btn100.text = "采样当前100局"
	btn100.mouse_filter = Control.MOUSE_FILTER_STOP
	btn100.pressed.connect(func(): _run_sampling(100))
	row.add_child(btn100)
	_hot_controls_root.add_child(row)

func _add_number_pipeline_controls() -> void:
	var title := Label.new()
	title.text = "数值管线"
	title.mouse_filter = Control.MOUSE_FILTER_STOP
	_hot_controls_root.add_child(title)

	var grid := GridContainer.new()
	grid.columns = 3
	grid.mouse_filter = Control.MOUSE_FILTER_STOP
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hot_controls_root.add_child(grid)

	_add_pipeline_header(grid, "项目")
	_add_pipeline_header(grid, "玩家")
	_add_pipeline_header(grid, "敌人")
	for spec in [
		{"key": "max_hp", "label": "HP", "min": 1.0, "max": 120.0, "step": 1.0},
		{"key": "max_momentum", "label": "势上限", "min": 1.0, "max": 20.0, "step": 1.0},
		{"key": "momentum", "label": "起势", "min": 0.0, "max": 20.0, "step": 1.0},
		{"key": "realm", "label": "武境", "min": 1.0, "max": 6.0, "step": 1.0},
		{"key": "qinggong", "label": "轻功", "min": 1.0, "max": 5.0, "step": 1.0}
	]:
		var label := Label.new()
		label.text = str(spec.get("label", ""))
		label.custom_minimum_size = Vector2(72, 24)
		label.mouse_filter = Control.MOUSE_FILTER_STOP
		grid.add_child(label)
		var p_spin := _make_pipeline_spin(float(spec.get("min", 0.0)), float(spec.get("max", 99.0)), float(spec.get("step", 1.0)))
		var e_spin := _make_pipeline_spin(float(spec.get("min", 0.0)), float(spec.get("max", 99.0)), float(spec.get("step", 1.0)))
		_number_pipeline_fields["player_%s" % str(spec.get("key", ""))] = p_spin
		_number_pipeline_fields["enemy_%s" % str(spec.get("key", ""))] = e_spin
		grid.add_child(p_spin)
		grid.add_child(e_spin)

	var sample_row := HBoxContainer.new()
	sample_row.mouse_filter = Control.MOUSE_FILTER_STOP
	sample_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hot_controls_root.add_child(sample_row)
	var sample_label := Label.new()
	sample_label.text = "采样"
	sample_label.custom_minimum_size = Vector2(44, 24)
	sample_label.mouse_filter = Control.MOUSE_FILTER_STOP
	sample_row.add_child(sample_label)
	_number_pipeline_sample_count = _make_pipeline_spin(10.0, 2000.0, 10.0)
	_number_pipeline_sample_count.value = 120.0
	_number_pipeline_seed = _make_pipeline_spin(0.0, 999999.0, 1.0)
	_number_pipeline_seed.value = 260430.0
	sample_row.add_child(_number_pipeline_sample_count)
	sample_row.add_child(_number_pipeline_seed)

	var action_row := HBoxContainer.new()
	action_row.mouse_filter = Control.MOUSE_FILTER_STOP
	action_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hot_controls_root.add_child(action_row)
	for spec in [
		{"label": "读取当前", "callback": Callable(self, "_sync_number_pipeline_fields_from_fighters")},
		{"label": "应用", "callback": Callable(self, "_apply_number_pipeline_fields")},
		{"label": "重置", "callback": Callable(self, "_reset_number_pipeline_fields")},
		{"label": "保存配置", "callback": Callable(self, "_save_number_pipeline_config")},
		{"label": "重采样", "callback": Callable(self, "_sample_number_pipeline_fields")}
	]:
		var button := Button.new()
		button.text = str(spec.get("label", ""))
		button.mouse_filter = Control.MOUSE_FILTER_STOP
		button.pressed.connect(spec.get("callback", Callable()))
		action_row.add_child(button)
	_sync_number_pipeline_fields_from_fighters()

func _add_pipeline_header(parent: Container, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_STOP
	label.add_theme_color_override("font_color", Color("9cc7ff"))
	parent.add_child(label)

func _make_pipeline_spin(min_value: float, max_value: float, step: float) -> SpinBox:
	var spin := SpinBox.new()
	spin.min_value = min_value
	spin.max_value = max_value
	spin.step = step
	spin.custom_minimum_size = Vector2(92, 24)
	spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spin.mouse_filter = Control.MOUSE_FILTER_STOP
	return spin

func _add_number_config_controls() -> void:
	var title := Label.new()
	title.text = "数值方案"
	title.mouse_filter = Control.MOUSE_FILTER_STOP
	_hot_controls_root.add_child(title)

	var target_row := HBoxContainer.new()
	target_row.mouse_filter = Control.MOUSE_FILTER_STOP
	target_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var target_label := Label.new()
	target_label.text = "目标"
	target_label.custom_minimum_size = Vector2(44, 24)
	target_label.mouse_filter = Control.MOUSE_FILTER_STOP
	_target_select = OptionButton.new()
	_target_select.custom_minimum_size = Vector2(292, 24)
	_target_select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_target_select.mouse_filter = Control.MOUSE_FILTER_STOP
	_target_select.add_item("均衡：接近五五开", 0)
	_target_select.add_item("偏易：玩家优势", 1)
	_target_select.add_item("偏难：敌人压迫", 2)
	_target_select.add_item("持久：更多回合", 3)
	_target_select.add_item("速战：更短回合", 4)
	target_row.add_child(target_label)
	target_row.add_child(_target_select)
	_hot_controls_root.add_child(target_row)

	var select_row := HBoxContainer.new()
	select_row.mouse_filter = Control.MOUSE_FILTER_STOP
	select_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_number_config_select = OptionButton.new()
	_number_config_select.custom_minimum_size = Vector2(236, 24)
	_number_config_select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_number_config_select.mouse_filter = Control.MOUSE_FILTER_STOP
	_number_config_select.item_selected.connect(_on_number_config_selected)
	var apply_button := Button.new()
	apply_button.text = "切换"
	apply_button.mouse_filter = Control.MOUSE_FILTER_STOP
	apply_button.pressed.connect(_apply_selected_number_config)
	var duplicate_button := Button.new()
	duplicate_button.text = "复制"
	duplicate_button.mouse_filter = Control.MOUSE_FILTER_STOP
	duplicate_button.pressed.connect(_duplicate_selected_number_config)
	var delete_button := Button.new()
	delete_button.text = "删除"
	delete_button.mouse_filter = Control.MOUSE_FILTER_STOP
	delete_button.pressed.connect(_delete_selected_number_config)
	select_row.add_child(_number_config_select)
	select_row.add_child(apply_button)
	select_row.add_child(duplicate_button)
	select_row.add_child(delete_button)
	_hot_controls_root.add_child(select_row)

	var action_row := HBoxContainer.new()
	action_row.mouse_filter = Control.MOUSE_FILTER_STOP
	action_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var capture_button := Button.new()
	capture_button.text = "保存当前"
	capture_button.mouse_filter = Control.MOUSE_FILTER_STOP
	capture_button.pressed.connect(_save_current_number_config)
	var sample_button := Button.new()
	sample_button.text = "采样当前"
	sample_button.mouse_filter = Control.MOUSE_FILTER_STOP
	sample_button.pressed.connect(func(): _sample_current_number_config(120))
	var generate_button := Button.new()
	generate_button.text = "按目标生成"
	generate_button.mouse_filter = Control.MOUSE_FILTER_STOP
	generate_button.pressed.connect(_generate_number_configs)
	action_row.add_child(capture_button)
	action_row.add_child(sample_button)
	action_row.add_child(generate_button)
	_hot_controls_root.add_child(action_row)
	_refresh_number_config_select()
