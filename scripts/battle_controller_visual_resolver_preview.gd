extends "res://scripts/battle_controller_visual_hot_tuning.gd"

# Preview routing layer: keep all UI/debug/hot tuning behavior, but make the
# ghost preview use the shared CombatResolver instead of local preview rules.

const CombatResolver = preload("res://scripts/combat_resolver.gd")


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
		return "预期：待命"
	var range_result: String = str(sim.get("player_range_result", CombatResolver.RANGE_NONE)) if is_player_side else str(sim.get("enemy_range_result", CombatResolver.RANGE_NONE))
	var hp_delta: int = int(sim.get("enemy_hp_delta", 0)) if is_player_side else int(sim.get("player_hp_delta", 0))
	var momentum_delta: int = int(sim.get("enemy_momentum_delta", 0)) if is_player_side else int(sim.get("player_momentum_delta", 0))
	var will_break: bool = bool(sim.get("enemy_will_break", false)) if is_player_side else bool(sim.get("player_will_break", false))
	var damage: int = absi(hp_delta) if hp_delta < 0 else 0
	var break_value: int = absi(momentum_delta) if momentum_delta < 0 else 0
	var parts: Array[String] = []
	parts.append(_resolver_range_text(range_result))
	parts.append("伤%d" % damage)
	if break_value > 0:
		parts.append("势-%d" % break_value)
	if will_break:
		parts.append("预期崩势")
	if card.gain_momentum > 0 and range_result == CombatResolver.RANGE_HIT:
		parts.append("势+%d" % card.gain_momentum)
	return "预期：%s" % " / ".join(parts)


func _resolver_range_text(range_result: String) -> String:
	match range_result:
		CombatResolver.RANGE_HIT:
			return "命中"
		CombatResolver.RANGE_GRAZE:
			return "擦中"
		CombatResolver.RANGE_MISS_FACING:
			return "朝向未中"
		CombatResolver.RANGE_MISS_RANGE:
			return "距离未中"
		_:
			return "无判定"
