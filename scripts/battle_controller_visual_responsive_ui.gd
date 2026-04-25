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

var _last_resolved_position_signature := ""

func _process(delta: float) -> void:
	super(delta)
	_refresh_positions_immediately_after_movement()
	_bind_intent_bubbles_to_actor_sprites()

func _resolved_position_signature() -> String:
	if player == null or enemy == null:
		return "no-session"
	return "%d|%s|%d|%s|%d" % [
		player.position,
		player.facing,
		enemy.position,
		enemy.facing,
		state_machine.current_distance if state_machine != null else -1
	]

func _refresh_positions_immediately_after_movement() -> void:
	if player == null or enemy == null or not battle_active:
		_last_resolved_position_signature = _resolved_position_signature()
		return
	var signature := _resolved_position_signature()
	if signature == _last_resolved_position_signature:
		return
	_last_resolved_position_signature = signature
	# Movement can happen inside BattleStateMachine.resolve_intent, outside the normal
	# card-selection refresh path. Clear visual caches and force the stage to redraw
	# on the same frame so push/pull/self-move effects are visible immediately.
	_stage_grid_signature = ""
	_stage_actor_signature = ""
	_player_intent_bubble_signature = ""
	_enemy_intent_bubble_signature = ""
	_refresh_stage_grid(true)
	_refresh_stage_actor_positions(true)
	_refresh_intent_bubbles(true)
	_refresh_effect_preview_panel()

func _build_catalog() -> void:
	# v0.3.2: override the parent prototype catalog with movement-aware spear/blade cards.
	fighter_catalog.clear()
	reward_pool.clear()
	combo_registry.clear()

	var spear_mid_thrust := _ready_v032_card("spear_mid_thrust", "中平直刺", "枪手标准二三格刺击，稳定伤害与削势。", 2, 3, 2, CardData.ROLE_DAMAGE, 0, 2, 5, 0, PackedStringArray(["长兵", "正面", "基础"]), "枪")
	var spear_line_press := _ready_v032_card("spear_line_press", "拦枪压线", "枪杆压住来路，命中后将敌人击退一格。", 2, 3, 2, CardData.ROLE_MOMENTUM, 0, 4, 2, 0, PackedStringArray(["长兵", "破势", "控线"]), "枪", true, 0, 1, 0, CardData.MOVE_ON_HIT)
	var spear_retreat_sting := _ready_v032_card("spear_retreat_sting", "退枪留锋", "近身脱身刺，命中后自身后撤一格。", 1, 2, 2, CardData.ROLE_DAMAGE, 0, 1, 4, 0, PackedStringArray(["长兵", "后撤", "脱身"]), "枪", true, -1, 0, 0, CardData.MOVE_ON_HIT)
	var spear_guard_horse := _ready_v032_card("spear_guard_horse", "架枪拒马", "架枪成拒马，稳守并推开敌人。", 0, 8, 2, CardData.ROLE_GUARD, 0, 0, 0, 7, PackedStringArray(["架势", "拒止"]), "枪", false, 0, 1, 0, CardData.MOVE_ALWAYS)
	var spear_step_thrust := _ready_v032_card("spear_step_thrust", "顺步送枪", "三格追击刺，命中后自身进身一格。", 3, 3, 2, CardData.ROLE_DAMAGE, 0, 1, 6, 0, PackedStringArray(["长兵", "进身"]), "枪", true, 1, 0, 0, CardData.MOVE_ON_HIT)
	var spear_focus := _ready_v032_card("spear_focus", "稳架蓄枪", "聚势整架并后撤，重建二三格控线。", 0, 8, 0, CardData.ROLE_MOMENTUM, 3, 0, 0, 2, PackedStringArray(["聚势", "架势"]), "枪", false, -1, 0, 0, CardData.MOVE_ALWAYS)

	var blade_front_cut := _ready_v032_card("blade_front_cut", "迎门斩", "刀客一二格标准斩击。", 1, 2, 2, CardData.ROLE_DAMAGE, 0, 1, 6, 0, PackedStringArray(["短兵", "基础"]), "刀")
	var blade_press_break := _ready_v032_card("blade_press_break", "压刀破架", "贴身压架，命中后拉近敌人一格。", 1, 1, 2, CardData.ROLE_MOMENTUM, 0, 4, 2, 0, PackedStringArray(["短兵", "破势", "贴身"]), "刀", true, 0, 0, 1, CardData.MOVE_ON_HIT)
	var blade_chase_cut := _ready_v032_card("blade_chase_cut", "赶步追斩", "二三格追身斩，命中后自身进身一格。", 2, 3, 2, CardData.ROLE_DAMAGE, 0, 1, 5, 0, PackedStringArray(["短兵", "追身"]), "刀", true, 1, 0, 0, CardData.MOVE_ON_HIT)
	var blade_hook_pull := _ready_v032_card("blade_hook_pull", "挂刀带步", "刀锋挂带，命中后将敌人拉近一格。", 1, 2, 2, CardData.ROLE_DAMAGE, 0, 2, 4, 0, PackedStringArray(["短兵", "拉扯"]), "刀", true, 0, 0, 1, CardData.MOVE_ON_HIT)
	var blade_body_press := _ready_v032_card("blade_body_press", "贴身撞刀", "极近顶撞破势，命中后自身进身贴住。", 0, 1, 2, CardData.ROLE_DAMAGE, 0, 3, 4, 0, PackedStringArray(["短兵", "贴身", "破势"]), "刀", true, 1, 0, 0, CardData.MOVE_ON_HIT)
	var blade_breathe := _ready_v032_card("blade_breathe", "收刀换气", "收刀换气并进身，持续保持近身压力。", 0, 8, 0, CardData.ROLE_MOMENTUM, 3, 0, 0, 2, PackedStringArray(["聚势", "短兵"]), "刀", false, 1, 0, 0, CardData.MOVE_ALWAYS)

	var spear_deck: Array[CardData] = [spear_mid_thrust, spear_line_press, spear_retreat_sting, spear_guard_horse, spear_step_thrust, spear_focus]
	var blade_deck: Array[CardData] = [blade_front_cut, blade_press_break, blade_chase_cut, blade_hook_pull, blade_body_press, blade_breathe]

	fighter_catalog["spearman"] = FighterData.new("spearman", "枪手", "长枪", 24, 6, 5, 1, PackedInt32Array([2, 3]), spear_deck, 1, 2, "right")
	fighter_catalog["blademaster"] = FighterData.new("blademaster", "刀客", "单刀", 22, 6, 5, 2, PackedInt32Array([1, 2]), blade_deck, 1, 6, "left")

	reward_pool = [
		_ready_v032_card("reward_push", "压线", "命中后击退敌人一格。", 2, 3, 2, CardData.ROLE_MOMENTUM, 0, 2, 2, 0, PackedStringArray(["控线"]), "通用", true, 0, 1, 0, CardData.MOVE_ON_HIT),
		_ready_v032_card("reward_pull", "挂带", "命中后拉近敌人一格。", 1, 2, 2, CardData.ROLE_DAMAGE, 0, 1, 4, 0, PackedStringArray(["拉扯"]), "通用", true, 0, 0, 1, CardData.MOVE_ON_HIT),
		_ready_v032_card("reward_guard", "铁壁", "纯粹追求稳固格挡。", 0, 8, 2, CardData.ROLE_GUARD, 0, 0, 0, 8, PackedStringArray(["架势"]), "通用", false)
	]

	combo_registry["spearman"] = [
		{
			"id": "spear_combo_001",
			"display_name": "控线连刺",
			"starter_card_id": "spear_mid_thrust",
			"required_card_ids": PackedStringArray(["spear_mid_thrust", "spear_step_thrust"]),
			"followups": [
				{"name": "追喉刺", "base_damage": 2, "segment_type": "追击"},
				{"name": "顺势送枪", "base_damage": 4, "segment_type": "终结", "is_finisher": true}
			]
		}
	]
	combo_registry["blademaster"] = [
		{
			"id": "blade_combo_001",
			"display_name": "贴身三斩",
			"starter_card_id": "blade_front_cut",
			"required_card_ids": PackedStringArray(["blade_front_cut", "blade_body_press"]),
			"followups": [
				{"name": "追身快斩", "base_damage": 2, "segment_type": "追击"},
				{"name": "贴身断流", "base_damage": 5, "segment_type": "终结", "is_finisher": true}
			]
		}
	]

func _ready_v032_card(
	p_id: String,
	p_name: String,
	p_desc: String,
	p_min_distance: int,
	p_max_distance: int,
	p_cost: int,
	p_role: String,
	p_gain_momentum: int,
	p_break_momentum: int,
	p_damage: int,
	p_guard: int,
	p_tags: PackedStringArray = PackedStringArray(),
	p_weapon_style: String = "",
	p_requires_facing: bool = true,
	p_self_move_after: int = 0,
	p_target_push_after: int = 0,
	p_target_pull_after: int = 0,
	p_move_condition: String = CardData.MOVE_NONE
) -> CardData:
	return CardData.new(
		p_id,
		p_name,
		p_desc,
		p_min_distance,
		p_max_distance,
		p_cost,
		p_role,
		p_gain_momentum,
		p_break_momentum,
		p_damage,
		p_guard,
		p_tags,
		p_weapon_style,
		p_requires_facing,
		p_self_move_after,
		p_target_push_after,
		p_target_pull_after,
		p_move_condition
	)

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
