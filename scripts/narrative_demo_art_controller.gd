extends "res://scripts/narrative_demo_formal_controller.gd"

const ART_TEXTURE_SIZE := Vector2(640, 132)
const ART_LABEL_SIZE := Vector2(640, 112)
const ART_FRAME_SIZE := Vector2(0, 142)
const ACTION_AREA_SIZE := Vector2(0, 300)
const BODY_AREA_SIZE := Vector2(0, 82)
const MAP_AREA_SIZE := Vector2(0, 54)
const SCENE_AREA_SIZE := Vector2(0, 42)

func _render_visual(path: String, fallback_text: String) -> void:
	_apply_art_layout_size()
	super._render_visual(path, fallback_text)

func _render() -> void:
	super._render()
	_apply_art_layout_size()

func _apply_art_layout_size() -> void:
	# 上一版把视觉图拉到 220 高，会挤掉下方选项。
	# 这里改成“中等画幅 + 下方操作区优先”，保证美术可见但不影响玩法验收。
	if map_label != null:
		map_label.custom_minimum_size = MAP_AREA_SIZE
	if scene_label != null:
		scene_label.custom_minimum_size = SCENE_AREA_SIZE
	if body_label != null:
		body_label.custom_minimum_size = BODY_AREA_SIZE
		body_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if action_scroll != null:
		action_scroll.custom_minimum_size = ACTION_AREA_SIZE
		action_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if visual_texture != null:
		visual_texture.custom_minimum_size = ART_TEXTURE_SIZE
		visual_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		visual_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if visual_label != null:
		visual_label.custom_minimum_size = ART_LABEL_SIZE
	if visual_texture != null and visual_texture.get_parent() != null and visual_texture.get_parent().get_parent() != null:
		var frame: Node = visual_texture.get_parent().get_parent()
		if frame is Control:
			(frame as Control).custom_minimum_size = ART_FRAME_SIZE

func _prologue_visual_hint() -> String:
	if step_index <= 3:
		return "主视觉占位：黑屏潮声 / 宣纸暗海 / 村火朱砂 / 远岸烟云"
	if step_index <= 8:
		return "主视觉占位：师父旧腰刀 / 童年主角 / 火光剪影 / 家国旧案"
	if step_index == PROLOGUE_CAREER_STEP:
		return "主视觉占位：青年明代武官 / 深绛红战袍 / 海疆出山 / 风起沧海"
	return "主视觉占位：暗箭 / 师父背影 / 海雾山路"

func _prologue_scene_hint() -> String:
	if step_index <= 3:
		return "序章美术：宣纸底色、黑墨海岸、远处村火、低垂烟云。"
	if step_index <= 8:
		return "序章美术：旧腰刀挡刀、童年主角倒地、火光剪影、悲壮克制。"
	if step_index == PROLOGUE_CAREER_STEP:
		return "出山美术：青年明代武官、深色札甲、深绛红战袍、海雾、远崖、家国情怀。"
	return "序章美术：暗箭灭口、师父沉默、海雾山路、旧案未尽。"
