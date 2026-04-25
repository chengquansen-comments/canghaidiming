extends "res://scripts/battle_controller_visual_cached_ui.gd"

# Bottom layout policy:
# 1. Control bar and hand cards are fixed priority content.
# 2. Detail / preview panels must shrink and scroll instead of pushing cards out.
# 3. This layer does not touch Web shell, stretch mode, battle logic, or actor runtime.

const RESPONSIVE_BOTTOM_TOP := 560.0
const RESPONSIVE_BOTTOM_MARGIN := 12.0
const RESPONSIVE_BOTTOM_SEPARATION := 8
const RESPONSIVE_CONTROL_BAR_HEIGHT := 40.0
const RESPONSIVE_HAND_HEIGHT := 176.0
const RESPONSIVE_CARD_SIZE := Vector2(152, 168)
const RESPONSIVE_DETAIL_PANEL_HEIGHT := 132.0
const RESPONSIVE_DETAIL_LABEL_HEIGHT := 94.0
const BUBBLE_GAP_Y := 12.0
const BUBBLE_SAFE_MARGIN_X := 24.0

func _process(delta: float) -> void:
	super(delta)
	_bind_intent_bubbles_to_actor_sprites()

func _build_ui() -> void:
	super()
	_configure_responsive_bottom_layout()
	call_deferred("_configure_responsive_bottom_layout")
	call_deferred("_bind_intent_bubbles_to_actor_sprites")

func _refresh_visual_ui() -> void:
	super()
	_configure_responsive_bottom_layout()
	_stabilize_actor_runtime_textures()
	_bind_intent_bubbles_to_actor_sprites()

func _refresh_hand_buttons() -> void:
	super()
	_configure_responsive_bottom_layout()
	_configure_hand_button_sizes()
	_bind_intent_bubbles_to_actor_sprites()

func _refresh_stage_actor_positions(force: bool = false) -> void:
	super(force)
	_stabilize_actor_runtime_textures()
	_bind_intent_bubbles_to_actor_sprites()

func _refresh_intent_bubbles(force: bool = false) -> void:
	super(force)
	_bind_intent_bubbles_to_actor_sprites()

func _configure_responsive_bottom_layout() -> void:
	_configure_bottom_root_bounds()
	_configure_control_bar_priority()
	_configure_hand_area_priority()
	_configure_scrollable_detail_panels()
	_configure_hand_button_sizes()

func _configure_bottom_root_bounds() -> void:
	if bottom_backdrop != null:
		bottom_backdrop.anchor_left = 0.0
		bottom_backdrop.anchor_right = 1.0
		bottom_backdrop.anchor_top = 0.0
		bottom_backdrop.anchor_bottom = 1.0
		bottom_backdrop.offset_top = RESPONSIVE_BOTTOM_TOP - 10.0
		bottom_backdrop.offset_bottom = 0.0
	if bottom_root != null:
		bottom_root.anchor_left = 0.0
		bottom_root.anchor_right = 1.0
		bottom_root.anchor_top = 0.0
		bottom_root.anchor_bottom = 1.0
		bottom_root.offset_left = 20.0
		bottom_root.offset_right = -20.0
		bottom_root.offset_top = RESPONSIVE_BOTTOM_TOP
		bottom_root.offset_bottom = -RESPONSIVE_BOTTOM_MARGIN
		bottom_root.clip_contents = true
		bottom_root.add_theme_constant_override("separation", RESPONSIVE_BOTTOM_SEPARATION)
		bottom_root.size_flags_vertical = Control.SIZE_EXPAND_FILL

func _configure_control_bar_priority() -> void:
	var control_bar := _control_bar_node()
	if control_bar == null:
		return
	control_bar.custom_minimum_size = Vector2(0, RESPONSIVE_CONTROL_BAR_HEIGHT)
	control_bar.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	control_bar.clip_contents = true
	if control_bar is BoxContainer:
		(control_bar as BoxContainer).add_theme_constant_override("separation", 8)

func _configure_hand_area_priority() -> void:
	if hand_flow == null:
		return
	hand_flow.custom_minimum_size = Vector2(0, RESPONSIVE_HAND_HEIGHT)
	hand_flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hand_flow.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	hand_flow.clip_contents = true
	if hand_flow is BoxContainer:
		(hand_flow as BoxContainer).add_theme_constant_override("separation", 8)

func _configure_scrollable_detail_panels() -> void:
	_configure_detail_panel(card_detail_panel, card_detail_label)
	_configure_detail_panel(effect_preview_panel, effect_preview_label)
	_configure_detail_parent(card_detail_panel)
	_configure_detail_parent(effect_preview_panel)

func _configure_detail_panel(panel: PanelContainer, label: RichTextLabel) -> void:
	if panel != null:
		panel.custom_minimum_size = Vector2(0, RESPONSIVE_DETAIL_PANEL_HEIGHT)
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
		panel.clip_contents = true
	if label != null:
		label.fit_content = false
		label.scroll_active = true
		label.scroll_following = false
		label.clip_contents = true
		label.custom_minimum_size = Vector2(0, RESPONSIVE_DETAIL_LABEL_HEIGHT)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.size_flags_vertical = Control.SIZE_EXPAND_FILL

func _configure_detail_parent(panel: PanelContainer) -> void:
	if panel == null:
		return
	var parent := panel.get_parent()
	if parent == null or parent == bottom_root:
		return
	if parent is Control:
		var parent_control := parent as Control
		parent_control.custom_minimum_size = Vector2(0, RESPONSIVE_DETAIL_PANEL_HEIGHT)
		parent_control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		parent_control.size_flags_vertical = Control.SIZE_EXPAND_FILL
		parent_control.clip_contents = true
		if parent_control is BoxContainer:
			(parent_control as BoxContainer).add_theme_constant_override("separation", 8)

func _configure_hand_button_sizes() -> void:
	if hand_flow == null:
		return
	for child in hand_flow.get_children():
		if child is Button:
			var button := child as Button
			button.custom_minimum_size = RESPONSIVE_CARD_SIZE
			button.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
			button.clip_text = true
			button.clip_contents = true
			button.add_theme_font_size_override("font_size", 11)
		elif child is Control:
			var control := child as Control
			control.custom_minimum_size = Vector2(0, RESPONSIVE_HAND_HEIGHT)
			control.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
			control.clip_contents = true

func _stabilize_actor_runtime_textures() -> void:
	# Parent visual refreshes can still write the legacy three-frame sheet into the
	# TextureRect. Re-apply the active runtime frame after those refreshes so enemy
	# actors keep their enemy_* meta/sheet identity during and after attacks.
	_ensure_actor_animation_runtimes()
	_refresh_actor_runtime_visuals()

func _bind_intent_bubbles_to_actor_sprites() -> void:
	_bind_single_intent_bubble(player_intent_bubble, player_sprite)
	_bind_single_intent_bubble(enemy_intent_bubble, enemy_sprite)

func _bind_single_intent_bubble(bubble: PanelContainer, sprite: TextureRect) -> void:
	if bubble == null or sprite == null or not bubble.visible:
		return
	var bubble_size: Vector2 = bubble.size
	if bubble_size.x <= 1.0 or bubble_size.y <= 1.0:
		bubble_size = bubble.custom_minimum_size
	var sprite_rect: Rect2 = _sprite_visible_rect(sprite)
	var target_x: float = sprite_rect.position.x + sprite_rect.size.x * 0.5 - bubble_size.x * 0.5
	var target_y: float = sprite_rect.position.y - bubble_size.y - BUBBLE_GAP_Y
	bubble.position = Vector2(
		clampf(target_x, BUBBLE_SAFE_MARGIN_X, maxf(BUBBLE_SAFE_MARGIN_X, size.x - bubble_size.x - BUBBLE_SAFE_MARGIN_X)),
		maxf(STAGE_AREA_TOP + 8.0, target_y)
	)

func _sprite_visible_rect(sprite: TextureRect) -> Rect2:
	var rect := Rect2(sprite.position, sprite.size)
	if sprite.texture == null:
		return rect
	var texture_size: Vector2 = sprite.texture.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0 or sprite.size.x <= 0.0 or sprite.size.y <= 0.0:
		return rect
	var draw_scale: float = minf(sprite.size.x / texture_size.x, sprite.size.y / texture_size.y)
	var draw_size: Vector2 = texture_size * draw_scale
	var draw_offset: Vector2 = (sprite.size - draw_size) * 0.5
	return Rect2(sprite.position + draw_offset, draw_size)

func _control_bar_node() -> Control:
	if confirm_button != null and confirm_button.get_parent() is Control:
		return confirm_button.get_parent() as Control
	if reset_pick_button != null and reset_pick_button.get_parent() is Control:
		return reset_pick_button.get_parent() as Control
	if bottom_root != null and bottom_root.get_child_count() > 0 and bottom_root.get_child(0) is Control:
		return bottom_root.get_child(0) as Control
	return null
