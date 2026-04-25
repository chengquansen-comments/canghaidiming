extends RefCounted
class_name PreviewConsistencyChecker

const RANGE_HIT := "hit"
const RANGE_GRAZE := "graze"
const RANGE_MISS_RANGE := "miss_range"
const RANGE_MISS_FACING := "miss_facing"

static func build_preview_signature(snapshot: Dictionary) -> Dictionary:
	var sim := simulate(snapshot)
	return {
		"order": sim.get("order", []),
		"player_final": sim.get("player_final", -1),
		"enemy_final": sim.get("enemy_final", -1),
		"player_hp_delta": sim.get("player_hp_delta", 0),
		"enemy_hp_delta": sim.get("enemy_hp_delta", 0),
		"player_momentum_delta": sim.get("player_momentum_delta", 0),
		"enemy_momentum_delta": sim.get("enemy_momentum_delta", 0),
		"player_range_result": sim.get("player_range_result", "none"),
		"enemy_range_result": sim.get("enemy_range_result", "none"),
		"player_will_break": sim.get("player_will_break", false),
		"enemy_will_break": sim.get("enemy_will_break", false)
	}

static func compare(snapshot: Dictionary, preview_signature: Dictionary) -> Dictionary:
	var expected := build_preview_signature(snapshot)
	var mismatches: Array[String] = []
	for key in expected.keys():
		if not preview_signature.has(key):
			mismatches.append("missing:%s" % key)
			continue
		if str(preview_signature[key]) != str(expected[key]):
			mismatches.append("%s expected=%s actual=%s" % [key, str(expected[key]), str(preview_signature[key])])
	return {
		"ok": mismatches.is_empty(),
		"expected": expected,
		"actual": preview_signature,
		"mismatches": mismatches
	}

static func simulate(snapshot: Dictionary) -> Dictionary:
	var p_pos: int = int(snapshot.get("player_position", 0))
	var e_pos: int = int(snapshot.get("enemy_position", 0))
	var p_facing: String = str(snapshot.get("player_facing", "right"))
	var e_facing: String = str(snapshot.get("enemy_facing", "left"))
	var p_card: Dictionary = snapshot.get("player_card", {})
	var e_card: Dictionary = snapshot.get("enemy_card", {})
	var order: Array = snapshot.get("order", ["player", "enemy"])
	var p_hp_delta := 0
	var e_hp_delta := 0
	var p_momentum_delta := 0
	var e_momentum_delta := 0
	var p_result := "none"
	var e_result := "none"
	var p_will_break := false
	var e_will_break := false
	var p_momentum: int = int(snapshot.get("player_momentum", 0))
	var e_momentum: int = int(snapshot.get("enemy_momentum", 0))
	var p_broken: bool = bool(snapshot.get("player_broken", false))
	var e_broken: bool = bool(snapshot.get("enemy_broken", false))

	for side in order:
		if side == "player" and not p_card.is_empty():
			p_result = evaluate_range(p_card, p_pos, p_facing, e_pos)
			var outcome := resolve_card_preview(p_card, p_result, p_broken, e_broken, int(snapshot.get("enemy_guard", 0)))
			e_hp_delta -= int(outcome.get("damage", 0))
			e_momentum_delta -= int(outcome.get("break", 0))
			p_momentum_delta += int(outcome.get("gain", 0))
			if e_momentum > 0 and e_momentum + e_momentum_delta <= 0:
				e_will_break = true
			var moved := apply_card_movement(p_card, true, p_pos, e_pos, p_facing, p_result)
			p_pos = int(moved.get("player", p_pos))
			e_pos = int(moved.get("enemy", e_pos))
		elif side == "enemy" and not e_card.is_empty():
			e_result = evaluate_range(e_card, e_pos, e_facing, p_pos)
			var outcome2 := resolve_card_preview(e_card, e_result, e_broken, p_broken, int(snapshot.get("player_guard", 0)))
			p_hp_delta -= int(outcome2.get("damage", 0))
			p_momentum_delta -= int(outcome2.get("break", 0))
			e_momentum_delta += int(outcome2.get("gain", 0))
			if p_momentum > 0 and p_momentum + p_momentum_delta <= 0:
				p_will_break = true
			var moved2 := apply_card_movement(e_card, false, p_pos, e_pos, e_facing, e_result)
			p_pos = int(moved2.get("player", p_pos))
			e_pos = int(moved2.get("enemy", e_pos))

	return {
		"order": order,
		"player_final": clampi(p_pos, 0, 8),
		"enemy_final": clampi(e_pos, 0, 8),
		"player_hp_delta": p_hp_delta,
		"enemy_hp_delta": e_hp_delta,
		"player_momentum_delta": p_momentum_delta,
		"enemy_momentum_delta": e_momentum_delta,
		"player_range_result": p_result,
		"enemy_range_result": e_result,
		"player_will_break": p_will_break,
		"enemy_will_break": e_will_break
	}

static func resolve_card_preview(card: Dictionary, range_result: String, actor_broken: bool, target_broken: bool, target_guard: int) -> Dictionary:
	if actor_broken:
		return {"damage": 0, "break": 0, "gain": 0}
	if range_result != RANGE_HIT and range_result != RANGE_GRAZE:
		return {"damage": 0, "break": 0, "gain": 0}
	var damage: int = int(card.get("damage", 0))
	if range_result == RANGE_GRAZE:
		damage = maxi(ceili(float(damage) * 0.5), 1) if damage > 0 else 0
	if target_broken and damage > 0:
		damage *= 2
	damage = maxi(damage - target_guard, 0)
	var break_value: int = int(card.get("break_momentum", 0))
	if range_result == RANGE_GRAZE:
		break_value = maxi(break_value - 1, 0)
	return {
		"damage": damage,
		"break": break_value,
		"gain": int(card.get("gain_momentum", 0))
	}

static func evaluate_range(card: Dictionary, actor_pos: int, actor_facing: String, target_pos: int) -> String:
	if not bool(card.get("requires_hit_check", true)):
		return RANGE_HIT
	if bool(card.get("requires_facing", true)) and not has_tag(card, "回身") and not faces_target(actor_pos, actor_facing, target_pos):
		return RANGE_MISS_FACING
	var distance := absi(target_pos - actor_pos)
	var min_distance := int(card.get("min_distance", 0))
	var max_distance := int(card.get("max_distance", 8))
	if distance >= min_distance and distance <= max_distance:
		return RANGE_HIT
	var gap := min_distance - distance if distance < min_distance else distance - max_distance
	return RANGE_GRAZE if gap == 1 else RANGE_MISS_RANGE

static func has_tag(card: Dictionary, tag: String) -> bool:
	var tags: Array = card.get("tags", [])
	return tags.has(tag)

static func faces_target(actor_pos: int, actor_facing: String, target_pos: int) -> bool:
	if actor_pos == target_pos:
		return true
	if target_pos > actor_pos:
		return actor_facing == "right"
	return actor_facing == "left"

static func apply_card_movement(card: Dictionary, is_player_actor: bool, p_pos: int, e_pos: int, actor_facing: String, range_result: String) -> Dictionary:
	var can_move := false
	var condition := str(card.get("move_condition", "none"))
	if condition == "always":
		can_move = true
	elif condition == "on_hit":
		can_move = range_result == RANGE_HIT
	elif condition == "on_graze":
		can_move = range_result == RANGE_GRAZE
	if not can_move:
		return {"player": p_pos, "enemy": e_pos}
	var actor_pos := p_pos if is_player_actor else e_pos
	var target_pos := e_pos if is_player_actor else p_pos
	var push := int(card.get("target_push_after", 0))
	var pull := int(card.get("target_pull_after", 0))
	var self_move := int(card.get("self_move_after", 0))
	if push > 0:
		target_pos = preview_push(actor_pos, target_pos, actor_facing, push)
	elif pull > 0:
		target_pos = preview_pull(actor_pos, target_pos, actor_facing, pull)
	elif self_move != 0:
		actor_pos = preview_self(actor_pos, target_pos, actor_facing, self_move)
	return {"player": actor_pos if is_player_actor else target_pos, "enemy": target_pos if is_player_actor else actor_pos}

static func preview_dir(actor_pos: int, target_pos: int, facing: String) -> int:
	if target_pos > actor_pos:
		return 1
	if target_pos < actor_pos:
		return -1
	return 1 if facing == "right" else -1

static func preview_self(actor_pos: int, target_pos: int, facing: String, amount: int) -> int:
	var dir := preview_dir(actor_pos, target_pos, facing)
	return clampi(actor_pos + dir if amount > 0 else actor_pos - dir, 0, 8)

static func preview_push(actor_pos: int, target_pos: int, facing: String, amount: int) -> int:
	return clampi(target_pos + preview_dir(actor_pos, target_pos, facing) * amount, 0, 8)

static func preview_pull(actor_pos: int, target_pos: int, facing: String, amount: int) -> int:
	var dir := preview_dir(actor_pos, target_pos, facing)
	var result := clampi(target_pos - dir * amount, 0, 8)
	if dir > 0 and result < actor_pos:
		result = actor_pos
	if dir < 0 and result > actor_pos:
		result = actor_pos
	return result
