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

# === 新增：预览虚影 ===
var player_preview_ghost: TextureRect
var enemy_preview_ghost: TextureRect
var player_preview_label: Label
var enemy_preview_label: Label

func _process(delta: float) -> void:
	super(delta)
	_refresh_positions_immediately_after_movement()
	_refresh_preview_ghosts()
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
	_stage_grid_signature = ""
	_stage_actor_signature = ""
	_player_intent_bubble_signature = ""
	_enemy_intent_bubble_signature = ""
	_refresh_stage_grid(true)
	_refresh_stage_actor_positions(true)
	_refresh_intent_bubbles(true)
	_refresh_effect_preview_panel()

# ==============================
#  核心新增：虚影系统
# ==============================

func _ensure_preview_ghosts() -> void:
	if stage_layer == null:
		return
	if player_preview_ghost == null:
		player_preview_ghost = _build_preview_ghost(true)
		stage_layer.add_child(player_preview_ghost)
	if enemy_preview_ghost == null:
		enemy_preview_ghost = _build_preview_ghost(false)
		stage_layer.add_child(enemy_preview_ghost)
	if player_preview_label == null:
		player_preview_label = _build_preview_label(true)
		stage_layer.add_child(player_preview_label)
	if enemy_preview_label == null:
		enemy_preview_label = _build_preview_label(false)
		stage_layer.add_child(enemy_preview_label)

func _build_preview_ghost(is_player: bool) -> TextureRect:
	var ghost := TextureRect.new()
	ghost.visible = false
	ghost.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	ghost.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ghost.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ghost.custom_minimum_size = ACTOR_DISPLAY_SIZE
	ghost.size = ACTOR_DISPLAY_SIZE
	ghost.z_index = 15
	ghost.modulate = Color(0.5, 0.8, 1.0, 0.35) if is_player else Color(1.0, 0.6, 0.4, 0.35)
	return ghost

func _build_preview_label(is_player: bool) -> Label:
	var label := Label.new()
	label.visible = false
	label.z_index = 20
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color("dff1ff") if is_player else Color("ffe0d0"))
	label.add_theme_color_override("font_shadow_color", Color(0,0,0,0.9))
	return label

func _refresh_preview_ghosts() -> void:
	_ensure_preview_ghosts()
	if player == null or enemy == null or not battle_active:
		_set_preview_visible(false)
		return

	var preview := _compute_preview()
	if not preview.has_preview:
		_set_preview_visible(false)
		return

	player_preview_ghost.texture = player_sprite.texture
	enemy_preview_ghost.texture = enemy_sprite.texture

	player_preview_ghost.position = _slot_top_left(preview.player_pos, true)
	enemy_preview_ghost.position = _slot_top_left(preview.enemy_pos, false)

	player_preview_label.text = preview.player_text
	enemy_preview_label.text = preview.enemy_text

	player_preview_label.position = player_preview_ghost.position + Vector2(0, -40)
	enemy_preview_label.position = enemy_preview_ghost.position + Vector2(0, -40)

	_set_preview_visible(true)

func _set_preview_visible(v: bool) -> void:
	player_preview_ghost.visible = v
	enemy_preview_ghost.visible = v
	player_preview_label.visible = v
	enemy_preview_label.visible = v

# ==============================
#  预期结算（核心逻辑）
# ==============================

func _compute_preview() -> Dictionary:
	var player_pos = _player_preview_position()
	var enemy_pos = enemy.position

	var player_card = _player_preview_card()
	var enemy_card = _enemy_preview_card()

	var player_text = "预期"
	var enemy_text = "预期"

	var has_preview = player_card != null or enemy_card != null

	# === 玩家先结算（简化版） ===
	if player_card != null:
		var result = _preview_range_result(player_card, player_pos, _player_preview_facing(), enemy_pos)
		if result == BattleStateMachine.RANGE_HIT:
			var dmg = _preview_damage_for_result(player_card, enemy, result)
			player_text = "命中 伤%d" % dmg
			if player_card.target_push_after > 0:
				enemy_pos += player_card.target_push_after
			elif player_card.target_pull_after > 0:
				enemy_pos -= player_card.target_pull_after
		elif result == BattleStateMachine.RANGE_MISS_RANGE:
			player_text = "未命中"

	# === 敌人 ===
	if enemy_card != null:
		var result2 = _preview_range_result(enemy_card, enemy_pos, _enemy_preview_facing(), player_pos)
		if result2 == BattleStateMachine.RANGE_HIT:
			var dmg2 = _preview_damage_for_result(enemy_card, player, result2)
			enemy_text = "命中 伤%d" % dmg2
			if enemy_card.target_push_after > 0:
				player_pos += enemy_card.target_push_after
			elif enemy_card.target_pull_after > 0:
				player_pos -= enemy_card.target_pull_after
		elif result2 == BattleStateMachine.RANGE_MISS_RANGE:
			enemy_text = "未命中"

	player_pos = clampi(player_pos, 0, GRID_SLOT_COUNT-1)
	enemy_pos = clampi(enemy_pos, 0, GRID_SLOT_COUNT-1)

	return {
		"has_preview": has_preview,
		"player_pos": player_pos,
		"enemy_pos": enemy_pos,
		"player_text": player_text,
		"enemy_text": enemy_text
	}

# ==============================
# 原逻辑不动
# ==============================

func _build_catalog() -> void:
	# 保持原逻辑
	fighter_catalog.clear()
