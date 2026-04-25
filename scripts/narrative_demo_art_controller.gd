extends "res://scripts/narrative_demo_formal_controller.gd"

func _render_visual(path: String, fallback_text: String) -> void:
	_apply_art_frame_size()
	super._render_visual(path, fallback_text)

func _apply_art_frame_size() -> void:
	if visual_texture != null:
		visual_texture.custom_minimum_size = Vector2(720, 210)
		visual_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		visual_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if visual_label != null:
		visual_label.custom_minimum_size = Vector2(720, 160)
	if visual_texture != null and visual_texture.get_parent() != null and visual_texture.get_parent().get_parent() != null:
		var frame = visual_texture.get_parent().get_parent()
		if frame is Control:
			frame.custom_minimum_size = Vector2(0, 220)

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
