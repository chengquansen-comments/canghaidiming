extends "res://scripts/battle_controller_visual_cached_ui.gd"

const ResponsiveLayoutHelper = preload("res://scripts/visual/responsive_layout_helper.gd")
const ResponsiveUiBindings = preload("res://scripts/visual/responsive_ui_bindings.gd")
const ResponsiveCatalogHelper = preload("res://scripts/visual/responsive_catalog_helper.gd")

# v0.3.3 top-level controller patch:
# - Restores this file as a complete, compile-safe override layer.
# - Keeps committed actor sprites on their real battle positions.
# - Uses translucent ghosts to preview final positions after ordered resolution.
# - Preview order follows BattleStateMachine.get_resolution_order when both intents exist.

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
var player_preview_ghost: TextureRect
var enemy_preview_ghost: TextureRect
var player_preview_label: Label
var enemy_preview_label: Label
var _responsive_layout_helper
var _responsive_ui_bindings
var _responsive_catalog_helper

func _layout_helper():
	if _responsive_layout_helper == null:
		_responsive_layout_helper = ResponsiveLayoutHelper.new(self)
	return _responsive_layout_helper

func _bindings_helper():
	if _responsive_ui_bindings == null:
		_responsive_ui_bindings = ResponsiveUiBindings.new(self)
	return _responsive_ui_bindings

func _catalog_helper():
	if _responsive_catalog_helper == null:
		_responsive_catalog_helper = ResponsiveCatalogHelper.new(self)
	return _responsive_catalog_helper


func _process(delta: float) -> void:
	super(delta)
	_refresh_positions_immediately_after_movement()
	_refresh_preview_ghosts()
	_bind_intent_bubbles_to_actor_sprites()


func _build_catalog() -> void:
	_catalog_helper().build_catalog()


func _build_ui() -> void:
	super()
	_ensure_preview_ghosts()
	_configure_responsive_bottom_layout()
	call_deferred("_configure_responsive_bottom_layout")
	call_deferred("_bind_intent_bubbles_to_actor_sprites")


func _refresh_visual_ui() -> void:
	super()
	_force_real_actor_positions()
	_refresh_preview_ghosts()
	_configure_responsive_bottom_layout()
	_stabilize_actor_runtime_textures()
	_bind_intent_bubbles_to_actor_sprites()


func _refresh_stage_actor_positions(force: bool = false) -> void:
	super(force)
	_force_real_actor_positions()
	_refresh_preview_ghosts()
	_stabilize_actor_runtime_textures()
	_bind_intent_bubbles_to_actor_sprites()


func _current_grid_positions() -> Dictionary:
	# Real stage markers should represent committed state only. Future results are
	# represented by ghosts.
	return {
		"player": player.position if player != null else 0,
		"enemy": enemy.position if enemy != null else GRID_RIGHT_ANCHOR_SLOT
	}


func _refresh_hand_buttons() -> void:
	super()
	_configure_responsive_bottom_layout()
	_configure_hand_button_sizes()
	_bind_intent_bubbles_to_actor_sprites()


func _refresh_intent_bubbles(force: bool = false) -> void:
	super(force)
	_bind_intent_bubbles_to_actor_sprites()


func _resolved_position_signature() -> String:
	if player == null or enemy == null:
		return "no-session"
	return "%d|%s|%d|%s|%d" % [player.position, player.facing, enemy.position, enemy.facing, state_machine.current_distance if state_machine != null else -1]


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
	_refresh_stage_actor_positions(true)
	_refresh_stage_grid(true)
	_refresh_intent_bubbles(true)
	_refresh_effect_preview_panel()


func _ensure_preview_ghosts() -> void:
	_bindings_helper().ensure_preview_ghosts()


func _build_preview_ghost(is_player: bool) -> TextureRect:
	return _bindings_helper().build_preview_ghost(is_player)


func _build_preview_label(is_player: bool) -> Label:
	return _bindings_helper().build_preview_label(is_player)


func _force_real_actor_positions() -> void:
	_bindings_helper().force_real_actor_positions()


func _refresh_preview_ghosts() -> void:
	_bindings_helper().refresh_preview_ghosts()


func _set_preview_ghosts_visible(value: bool) -> void:
	_bindings_helper().set_preview_ghosts_visible(value)


func _compute_ordered_preview() -> Dictionary:
	var p_intent: IntentData = draft_player_intent if draft_player_intent != null else player_intent
	var e_intent: IntentData = enemy_intent
	var p_card: CardData = p_intent.actual_card if p_intent != null else null
	var e_card: CardData = e_intent.actual_card if e_intent != null else null
	var has_preview := draft_player_has_position or p_card != null or e_card != null
	if not has_preview:
		return {"has_preview": false}

	var p_pos := _player_preview_position()
	var e_pos := enemy.position
	if e_intent != null and e_intent.target_position >= 0:
		e_pos = e_intent.target_position
	var p_facing := _player_preview_facing()
	var e_facing := _enemy_preview_facing()
	var p_text := "预期：待命"
	var e_text := "预期：待命"

	var order := _preview_resolution_order(p_intent, e_intent)
	for side in order:
		if side == "player" and p_card != null:
			var result := _preview_range_result_at(p_card, p_pos, p_facing, e_pos)
			var outcome := _preview_outcome_text(p_card, player, enemy, result)
			p_text = str(outcome.get("actor", "预期"))
			e_text = str(outcome.get("target", e_text))
			var moved := _apply_preview_movement(p_card, true, p_pos, e_pos, p_facing, result)
			p_pos = moved.get("player", p_pos)
			e_pos = moved.get("enemy", e_pos)
		elif side == "enemy" and e_card != null:
			var result2 := _preview_range_result_at(e_card, e_pos, e_facing, p_pos)
			var outcome2 := _preview_outcome_text(e_card, enemy, player, result2)
			e_text = str(outcome2.get("actor", "预期"))
			p_text = str(outcome2.get("target", p_text))
			var moved2 := _apply_preview_movement(e_card, false, p_pos, e_pos, e_facing, result2)
			p_pos = moved2.get("player", p_pos)
			e_pos = moved2.get("enemy", e_pos)

	return {
		"has_preview": true,
		"player_final": clampi(p_pos, 0, GRID_SLOT_COUNT - 1),
		"enemy_final": clampi(e_pos, 0, GRID_SLOT_COUNT - 1),
		"player_text": p_text,
		"enemy_text": e_text
	}


func _preview_resolution_order(p_intent: IntentData, e_intent: IntentData) -> Array[String]:
	if p_intent != null and e_intent != null and state_machine != null:
		var ordered := state_machine.get_resolution_order(player, enemy, p_intent, e_intent)
		var result: Array[String] = []
		for intent in ordered:
			if intent == p_intent:
				result.append("player")
			elif intent == e_intent:
				result.append("enemy")
		if not result.is_empty():
			return result
	if p_intent != null and e_intent == null:
		return ["player"]
	if p_intent == null and e_intent != null:
		return ["enemy"]
	return ["player", "enemy"]


func _preview_range_result_at(card: CardData, actor_pos: int, actor_facing: String, target_pos: int) -> String:
	return CombatResolver.evaluate_range(card, actor_pos, actor_facing, target_pos)


func _preview_outcome_text(card: CardData, actor: Fighter, target: Fighter, range_result: String) -> Dictionary:
	if card == null:
		return {"actor": "预期：待命", "target": "预期：待命"}
	if actor != null and actor.is_broken():
		return {"actor": "预期：崩势无效 / 伤0", "target": "预期：无伤害"}
	var damage := _preview_damage_for_result(card, target, range_result)
	var break_value := _preview_break_for_result(card, range_result)
	var actor_parts: Array[String] = []
	actor_parts.append(_range_result_text(range_result))
	actor_parts.append("伤%d" % damage)
	if break_value > 0:
		actor_parts.append("势-%d" % break_value)
	var is_effective_hit := range_result == CombatResolver.RANGE_HIT or (CombatResolver.ENABLE_GRAZE and range_result == CombatResolver.RANGE_GRAZE)
	if card.gain_momentum > 0 and is_effective_hit:
		actor_parts.append("势+%d" % card.gain_momentum)
	var target_parts: Array[String] = []
	if damage == 0 and break_value == 0:
		target_parts.append("无伤害")
	else:
		if damage > 0:
			target_parts.append("受伤%d" % damage)
		if break_value > 0:
			target_parts.append("失势%d" % break_value)
		if target != null and target.momentum > 0 and target.momentum - break_value <= 0:
			target_parts.append("预期崩势")
	return {"actor": "预期：%s" % " / ".join(actor_parts), "target": "预期：%s" % " / ".join(target_parts)}


func _apply_preview_movement(card: CardData, is_player_actor: bool, p_pos: int, e_pos: int, actor_facing: String, range_result: String) -> Dictionary:
	var can_move := false
	match card.move_condition:
		CardData.MOVE_ALWAYS:
			can_move = true
		CardData.MOVE_ON_HIT:
			can_move = range_result == CombatResolver.RANGE_HIT
		CardData.MOVE_ON_GRAZE:
			can_move = CombatResolver.ENABLE_GRAZE and range_result == CombatResolver.RANGE_GRAZE
		_:
			can_move = false
	if not can_move:
		return {"player": p_pos, "enemy": e_pos}
	var actor_pos := p_pos if is_player_actor else e_pos
	var target_pos := e_pos if is_player_actor else p_pos
	if card.target_push_after > 0:
		target_pos = _preview_push(actor_pos, target_pos, actor_facing, card.target_push_after)
	elif card.target_pull_after > 0:
		target_pos = _preview_pull(actor_pos, target_pos, actor_facing, card.target_pull_after)
	elif card.self_move_after != 0:
		actor_pos = _preview_self(actor_pos, target_pos, actor_facing, card.self_move_after)
	return {"player": actor_pos if is_player_actor else target_pos, "enemy": target_pos if is_player_actor else actor_pos}


func _preview_dir(actor_pos: int, target_pos: int, facing: String) -> int:
	if target_pos > actor_pos:
		return 1
	if target_pos < actor_pos:
		return -1
	return 1 if facing == "right" else -1


func _preview_self(actor_pos: int, target_pos: int, facing: String, amount: int) -> int:
	var dir := _preview_dir(actor_pos, target_pos, facing)
	return clampi(actor_pos + dir if amount > 0 else actor_pos - dir, 0, GRID_SLOT_COUNT - 1)


func _preview_push(actor_pos: int, target_pos: int, facing: String, amount: int) -> int:
	return clampi(target_pos + _preview_dir(actor_pos, target_pos, facing) * amount, 0, GRID_SLOT_COUNT - 1)


func _preview_pull(actor_pos: int, target_pos: int, facing: String, amount: int) -> int:
	var dir := _preview_dir(actor_pos, target_pos, facing)
	var result := clampi(target_pos - dir * amount, 0, GRID_SLOT_COUNT - 1)
	if dir > 0 and result < actor_pos:
		result = actor_pos
	if dir < 0 and result > actor_pos:
		result = actor_pos
	return result


func _preview_faces_target(actor_position: int, actor_facing: String, target_position: int) -> bool:
	if actor_position == target_position:
		return true
	if target_position > actor_position:
		return actor_facing == "right"
	return actor_facing == "left"


func _preview_break_for_result(card: CardData, range_result: String) -> int:
	if card == null:
		return 0
	if range_result == CombatResolver.RANGE_HIT:
		return card.break_momentum
	if CombatResolver.ENABLE_GRAZE and range_result == CombatResolver.RANGE_GRAZE:
		return maxi(card.break_momentum - 1, 0)
	return 0


func _configure_responsive_bottom_layout() -> void:
	_layout_helper().configure_responsive_bottom_layout()


func _configure_bottom_root_bounds() -> void:
	_layout_helper().configure_bottom_root_bounds()


func _configure_control_bar_priority() -> void:
	_layout_helper().configure_control_bar_priority()


func _configure_hand_area_priority() -> void:
	_layout_helper().configure_hand_area_priority()


func _configure_scrollable_detail_panels() -> void:
	_layout_helper().configure_scrollable_detail_panels()


func _configure_detail_panel(panel: PanelContainer, label: RichTextLabel) -> void:
	_layout_helper().configure_detail_panel(panel, label)


func _configure_detail_parent(panel: PanelContainer) -> void:
	_layout_helper().configure_detail_parent(panel)


func _configure_hand_button_sizes() -> void:
	_layout_helper().configure_hand_button_sizes()


func _stabilize_actor_runtime_textures() -> void:
	_bindings_helper().stabilize_actor_runtime_textures()


func _bind_intent_bubbles_to_actor_sprites() -> void:
	_bindings_helper().bind_intent_bubbles_to_actor_sprites()


func _bind_single_intent_bubble(bubble: PanelContainer, sprite: TextureRect, is_player_actor: bool) -> void:
	_bindings_helper().bind_single_intent_bubble(bubble, sprite, is_player_actor)


func _sprite_visible_rect(sprite: TextureRect) -> Rect2:
	return _bindings_helper().sprite_visible_rect(sprite)


func _control_bar_node() -> Control:
	return _layout_helper().control_bar_node()
