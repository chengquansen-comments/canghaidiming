extends RefCounted
class_name CombatResolver

const ENABLE_GRAZE := false
const RANGE_HIT := "hit"
const RANGE_GRAZE := "graze"
const RANGE_MISS_RANGE := "miss_range"
const RANGE_MISS_FACING := "miss_facing"
const RANGE_NONE := "none"

static func resolve_exchange(player_state: Dictionary, enemy_state: Dictionary, player_card: CardData, enemy_card: CardData, order: Array[String]) -> Dictionary:
	var p_pos: int = int(player_state.get("position", 0))
	var e_pos: int = int(enemy_state.get("position", 0))
	var p_facing: String = str(player_state.get("facing", "right"))
	var e_facing: String = str(enemy_state.get("facing", "left"))
	var p_hp_delta: int = 0
	var e_hp_delta: int = 0
	var p_momentum_delta: int = 0
	var e_momentum_delta: int = 0
	var p_guard_delta: int = 0
	var e_guard_delta: int = 0
	var p_result: String = RANGE_NONE
	var e_result: String = RANGE_NONE
	var p_will_break: bool = false
	var e_will_break: bool = false

	for side: String in order:
		if side == "player" and player_card != null:
			p_result = evaluate_range(player_card, p_pos, p_facing, e_pos)
			var out_p: Dictionary = resolve_card_effect(player_card, p_result, bool(player_state.get("broken", false)), bool(enemy_state.get("broken", false)), int(enemy_state.get("guard", 0)) + e_guard_delta)
			e_hp_delta -= int(out_p.get("damage", 0))
			e_momentum_delta -= int(out_p.get("break", 0))
			p_momentum_delta += int(out_p.get("gain", 0))
			p_guard_delta += int(out_p.get("guard", 0))
			if int(enemy_state.get("momentum", 0)) > 0 and int(enemy_state.get("momentum", 0)) + e_momentum_delta <= 0:
				e_will_break = true
			var moved: Dictionary = apply_card_movement(player_card, true, p_pos, e_pos, p_facing, p_result, e_will_break)
			p_pos = int(moved.get("player", p_pos))
			e_pos = int(moved.get("enemy", e_pos))
		elif side == "enemy" and enemy_card != null:
			e_result = evaluate_range(enemy_card, e_pos, e_facing, p_pos)
			var out_e: Dictionary = resolve_card_effect(enemy_card, e_result, bool(enemy_state.get("broken", false)), bool(player_state.get("broken", false)), int(player_state.get("guard", 0)) + p_guard_delta)
			p_hp_delta -= int(out_e.get("damage", 0))
			p_momentum_delta -= int(out_e.get("break", 0))
			e_momentum_delta += int(out_e.get("gain", 0))
			e_guard_delta += int(out_e.get("guard", 0))
			if int(player_state.get("momentum", 0)) > 0 and int(player_state.get("momentum", 0)) + p_momentum_delta <= 0:
				p_will_break = true
			var moved2: Dictionary = apply_card_movement(enemy_card, false, p_pos, e_pos, e_facing, e_result, p_will_break)
			p_pos = int(moved2.get("player", p_pos))
			e_pos = int(moved2.get("enemy", e_pos))

	return {
		"player_final": clampi(p_pos, 0, 8),
		"enemy_final": clampi(e_pos, 0, 8),
		"player_hp_delta": p_hp_delta,
		"enemy_hp_delta": e_hp_delta,
		"player_momentum_delta": p_momentum_delta,
		"enemy_momentum_delta": e_momentum_delta,
		"player_guard_delta": p_guard_delta,
		"enemy_guard_delta": e_guard_delta,
		"player_range_result": p_result,
		"enemy_range_result": e_result,
		"player_will_break": p_will_break,
		"enemy_will_break": e_will_break,
		"order": order
	}

static func resolve_card_effect(card: CardData, range_result: String, actor_broken: bool, target_broken: bool, target_guard: int) -> Dictionary:
	if card == null:
		return {"damage": 0, "break": 0, "gain": 0, "guard": 0}
	var guard_value: int = card.guard
	var is_effective_hit := range_result == RANGE_HIT or (ENABLE_GRAZE and range_result == RANGE_GRAZE)
	if actor_broken or not is_effective_hit:
		return {"damage": 0, "break": 0, "gain": 0, "guard": guard_value}
	var damage_value: int = card.damage
	if ENABLE_GRAZE and range_result == RANGE_GRAZE:
		damage_value = maxi(ceili(float(damage_value) * 0.5), 1) if damage_value > 0 else 0
	if target_broken and damage_value > 0:
		damage_value *= 2
	damage_value = maxi(damage_value - target_guard, 0)
	var break_value: int = card.break_momentum
	if ENABLE_GRAZE and range_result == RANGE_GRAZE:
		break_value = maxi(break_value - 1, 0)
	return {"damage": damage_value, "break": break_value, "gain": card.gain_momentum, "guard": guard_value}

static func evaluate_range(card: CardData, actor_pos: int, actor_facing: String, target_pos: int) -> String:
	if card == null or not card.requires_hit_check():
		return RANGE_HIT
	if card.requires_facing and not card.has_tag("回身") and not faces_target(actor_pos, actor_facing, target_pos):
		return RANGE_MISS_FACING
	var distance: int = absi(target_pos - actor_pos)
	if distance >= card.min_distance and distance <= card.max_distance:
		return RANGE_HIT
	var gap: int = card.min_distance - distance if distance < card.min_distance else distance - card.max_distance
	if ENABLE_GRAZE and gap == 1:
		return RANGE_GRAZE
	return RANGE_MISS_RANGE

static func apply_card_movement(card: CardData, is_player_actor: bool, p_pos: int, e_pos: int, actor_facing: String, range_result: String, target_will_break: bool = false) -> Dictionary:
	if card == null:
		return {"player": p_pos, "enemy": e_pos}
	var can_move: bool = false
	if card.move_condition == CardData.MOVE_ALWAYS:
		can_move = true
	elif card.move_condition == CardData.MOVE_ON_HIT:
		can_move = range_result == RANGE_HIT
	elif card.move_condition == CardData.MOVE_ON_GRAZE:
		can_move = ENABLE_GRAZE and range_result == RANGE_GRAZE
	elif card.move_condition == CardData.MOVE_ON_BREAK:
		can_move = target_will_break
	if not can_move:
		return {"player": p_pos, "enemy": e_pos}
	var actor_pos: int = p_pos if is_player_actor else e_pos
	var target_pos: int = e_pos if is_player_actor else p_pos
	if card.target_push_after > 0:
		target_pos = preview_push(actor_pos, target_pos, actor_facing, card.target_push_after)
	elif card.target_pull_after > 0:
		target_pos = preview_pull(actor_pos, target_pos, actor_facing, card.target_pull_after)
	elif card.self_move_after != 0:
		actor_pos = preview_self(actor_pos, target_pos, actor_facing, card.self_move_after)
	return {"player": actor_pos if is_player_actor else target_pos, "enemy": target_pos if is_player_actor else actor_pos}

static func faces_target(actor_pos: int, actor_facing: String, target_pos: int) -> bool:
	if actor_pos == target_pos:
		return true
	if target_pos > actor_pos:
		return actor_facing == "right"
	return actor_facing == "left"

static func preview_dir(actor_pos: int, target_pos: int, facing: String) -> int:
	if target_pos > actor_pos:
		return 1
	if target_pos < actor_pos:
		return -1
	return 1 if facing == "right" else -1

static func preview_self(actor_pos: int, target_pos: int, facing: String, amount: int) -> int:
	var dir: int = preview_dir(actor_pos, target_pos, facing)
	return clampi(actor_pos + dir if amount > 0 else actor_pos - dir, 0, 8)

static func preview_push(actor_pos: int, target_pos: int, facing: String, amount: int) -> int:
	return clampi(target_pos + preview_dir(actor_pos, target_pos, facing) * amount, 0, 8)

static func preview_pull(actor_pos: int, target_pos: int, facing: String, amount: int) -> int:
	var dir: int = preview_dir(actor_pos, target_pos, facing)
	var result: int = clampi(target_pos - dir * amount, 0, 8)
	if dir > 0 and result < actor_pos:
		result = actor_pos
	if dir < 0 and result > actor_pos:
		result = actor_pos
	return result
