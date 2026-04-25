extends "res://scripts/battle_controller_visual_hot_tuning.gd"

# Preview routing layer: keep all UI/debug/hot tuning behavior, but make the
# ghost preview use the shared CombatResolver instead of local preview rules.
# v0.3.4: ghost labels show next-resolution effects, not intent summaries.

const CombatResolver = preload("res://scripts/combat_resolver.gd")
const PREVIEW_GHOST_ALPHA := 0.30
const PREVIEW_GHOST_OVERLAP_ALPHA := 1.00


func _refresh_preview_ghosts() -> void:
	_ensure_preview_ghosts()
	if player_preview_ghost == null or enemy_preview_ghost == null or player_preview_label == null or enemy_preview_label == null:
		return
	if player == null or enemy == null or not battle_active:
		_set_preview_ghosts_visible(false)
		return
	var preview: Dictionary = _compute_ordered_preview()
	if not bool(preview.get("has_preview", false)):
		_set_preview_ghosts_visible(false)
		return
	var player_final: int = int(preview.get("player_final", player.position))
	var enemy_final: int = int(preview.get("enemy_final", enemy.position))
	player_preview_ghost.texture = player_sprite.texture if player_sprite != null else null
	enemy_preview_ghost.texture = enemy_sprite.texture if enemy_sprite != null else null
	player_preview_ghost.position = _slot_top_left(player_final, true)
	enemy_preview_ghost.position = _slot_top_left(enemy_final, false)
	player_preview_ghost.modulate = _preview_ghost_modulate(true, player_final == player.position)
	enemy_preview_ghost.modulate = _preview_ghost_modulate(false, enemy_final == enemy.position)
	player_preview_label.text = str(preview.get("player_text", ""))
	enemy_preview_label.text = str(preview.get("enemy_text", ""))
	player_preview_label.position = player_preview_ghost.position + Vector2(-16, -62)
	enemy_preview_label.position = enemy_preview_ghost.position + Vector2(-16, -62)
	_set_preview_ghosts_visible(true)


func _preview_ghost_modulate(is_player: bool, overlaps_real_actor: bool) -> Color:
	var alpha: float = PREVIEW_GHOST_OVERLAP_ALPHA if overlaps_real_actor else PREVIEW_GHOST_ALPHA
	if overlaps_real_actor:
		return Color(1.0, 1.0, 1.0, alpha)
	return Color(0.55, 0.78, 1.0, alpha) if is_player else Color(1.0, 0.64, 0.48, alpha)


func _compute_ordered_preview() -> Dictionary:
	var p_intent: IntentData = draft_player_intent if draft_player_intent != null else player_intent
	var e_intent: IntentData = enemy_intent
	var p_card: CardData = p_intent.actual_card if p_intent != null else null
	var e_card: CardData = e_intent.actual_card if e_intent != null else null
	var has_preview: bool = draft_player_has_position or p_card != null or e_card != null
	if not has_preview:
		return {"has_preview": false}

	var p_state: Dictionary = _resolver_preview_state(true, p_intent)
	var e_state: Dictionary = _resolver_preview_state(false, e_intent)
	var order: Array[String] = _preview_resolution_order(p_intent, e_intent)
	var sim: Dictionary = CombatResolver.resolve_exchange(p_state, e_state, p_card, e_card, order)
	var p_text: String = _resolver_preview_text(true, p_card, sim)
	var e_text: String = _resolver_preview_text(false, e_card, sim)
	return {
		"has_preview": true,
		"player_final": clampi(int(sim.get("player_final", p_state.get("position", 0))), 0, GRID_SLOT_COUNT - 1),
		"enemy_final": clampi(int(sim.get("enemy_final", e_state.get("position", 0))), 0, GRID_SLOT_COUNT - 1),
		"player_text": p_text,
		"enemy_text": e_text,
		"source": "CombatResolver"
	}


func _resolver_preview_state(is_player: bool, intent: IntentData) -> Dictionary:
	var fighter: Fighter = player if is_player else enemy
	if fighter == null:
		return {"hp": 0, "momentum": 0, "guard": 0, "position": 0, "facing": "right", "broken": false}
	var pos: int = fighter.position
	var facing: String = fighter.facing
	if is_player:
		pos = _player_preview_position()
		facing = _player_preview_facing()
	else:
		if intent != null and intent.target_position >= 0:
			pos = intent.target_position
		facing = _enemy_preview_facing()
	return {
		"hp": fighter.hp,
		"momentum": fighter.momentum,
		"guard": fighter.guard_points,
		"position": pos,
		"facing": facing,
		"broken": fighter.is_broken()
	}


func _resolver_preview_text(is_player_side: bool, card: CardData, sim: Dictionary) -> String:
	if card == null:
		return "待命\n无效果"
	var range_result: String = str(sim.get("player_range_result", CombatResolver.RANGE_NONE)) if is_player_side else str(sim.get("enemy_range_result", CombatResolver.RANGE_NONE))
	var hp_delta: int = int(sim.get("enemy_hp_delta", 0)) if is_player_side else int(sim.get("player_hp_delta", 0))
	var momentum_delta: int = int(sim.get("enemy_momentum_delta", 0)) if is_player_side else int(sim.get("player_momentum_delta", 0))
	var actor_momentum_delta: int = int(sim.get("player_momentum_delta", 0)) if is_player_side else int(sim.get("enemy_momentum_delta", 0))
	var target_guard_delta: int = int(sim.get("enemy_guard_delta", 0)) if is_player_side else int(sim.get("player_guard_delta", 0))
	var actor_guard_delta: int = int(sim.get("player_guard_delta", 0)) if is_player_side else int(sim.get("enemy_guard_delta", 0))
	var will_break: bool = bool(sim.get("enemy_will_break", false)) if is_player_side else bool(sim.get("player_will_break", false))
	var damage: int = absi(hp_delta) if hp_delta < 0 else 0
	var break_value: int = absi(momentum_delta) if momentum_delta < 0 else 0
	var gain_value: int = actor_momentum_delta if actor_momentum_delta > 0 else 0
	var guard_value: int = actor_guard_delta if actor_guard_delta > 0 else 0
	var parts: Array[String] = []
	if range_result == CombatResolver.RANGE_MISS_FACING or range_result == CombatResolver.RANGE_MISS_RANGE:
		parts.append("未命中")
	elif range_result == CombatResolver.RANGE_GRAZE:
		parts.append("擦中")
		parts.append("伤%d" % damage)
	else:
		parts.append("命中") if card.requires_hit_check() else parts.append("生效")
		if damage > 0:
			parts.append("伤%d" % damage)
	if break_value > 0:
		parts.append("势-%d" % break_value)
	if will_break:
		parts.append("崩势")
	if gain_value > 0:
		parts.append("势+%d" % gain_value)
	if guard_value > 0:
		parts.append("护+%d" % guard_value)
	if target_guard_delta > 0:
		parts.append("敌护+%d" % target_guard_delta)
	if parts.is_empty():
		parts.append("无效果")
	return "%s\n%s" % [card.display_name, " / ".join(parts)]


func _resolver_range_text(range_result: String) -> String:
	match range_result:
		CombatResolver.RANGE_HIT:
			return "命中"
		CombatResolver.RANGE_GRAZE:
			return "擦中"
		CombatResolver.RANGE_MISS_FACING:
			return "未命中"
		CombatResolver.RANGE_MISS_RANGE:
			return "未命中"
		_:
			return "无判定"
