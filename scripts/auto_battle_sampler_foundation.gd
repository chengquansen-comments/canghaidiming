extends RefCounted

# Auto battle sampler foundation. Shared constants and low-level combat helpers.

const CombatResolver = preload("res://scripts/combat_resolver.gd")

const MODE_REACTIVE_ID := "reactive"
const MODE_SYMMETRIC_ID := "symmetric"
const PRESSURE_NONE := "none"
const PRESSURE_EDGE := "edge_pressure"
const PRESSURE_BREAK_RESIST := "break_resist"

static func _runtime_state(source: Dictionary, defaults: Dictionary) -> Dictionary:
	var out: Dictionary = defaults.duplicate(true)
	for key in source.keys():
		out[key] = source[key]
	if not out.has("max_momentum"):
		out["max_momentum"] = int(out.get("momentum", 10))
	return out

static func _preferred_for_style(style: String) -> Array:
	if style == "spear":
		return [3, 4, 5]
	return [0, 1, 2]

static func _bind_preferred_to_state(state: Dictionary, preferred: Array) -> void:
	if preferred.is_empty():
		return
	state["preferred_min"] = int(preferred[0])
	state["preferred_max"] = int(preferred[preferred.size() - 1])

static func _resolution_order(player_state: Dictionary, enemy_state: Dictionary, player_card: CardData, enemy_card: CardData, rng: RandomNumberGenerator, settlement_mode: String = MODE_REACTIVE_ID) -> Array[String]:
	var result: Array[String] = []
	if settlement_mode == MODE_REACTIVE_ID:
		result.assign(["enemy", "player"] if bool(player_state.get("broken", false)) and not bool(enemy_state.get("broken", false)) else ["player", "enemy"])
		return result
	var player_senki := player_card != null and player_card.has_tag("先机")
	var enemy_senki := enemy_card != null and enemy_card.has_tag("先机")
	if player_senki and not enemy_senki:
		result.assign(["player", "enemy"])
		return result
	if enemy_senki and not player_senki:
		result.assign(["enemy", "player"])
		return result
	var player_realm := int(player_state.get("realm", 1))
	var enemy_realm := int(enemy_state.get("realm", 1))
	if player_realm > enemy_realm:
		result.assign(["player", "enemy"])
		return result
	if enemy_realm > player_realm:
		result.assign(["enemy", "player"])
		return result
	result.assign(["player", "enemy"] if rng.randi_range(0, 1) == 0 else ["enemy", "player"])
	return result

static func _resolve_sampler_exchange(player_state: Dictionary, enemy_state: Dictionary, player_card: CardData, enemy_card: CardData, order: Array[String], settlement_mode: String) -> Dictionary:
	if settlement_mode != MODE_REACTIVE_ID:
		return CombatResolver.resolve_exchange(player_state, enemy_state, player_card, enemy_card, order)
	var aggregate := _empty_exchange(order)
	var p_state := player_state.duplicate(true)
	var e_state := enemy_state.duplicate(true)
	for side: String in order:
		if side == "player":
			var sim_p := CombatResolver.resolve_exchange(p_state, e_state, player_card, null, ["player"])
			_merge_exchange(aggregate, sim_p)
			_apply_exchange_to_states(p_state, e_state, sim_p)
			if bool(sim_p.get("enemy_will_break", false)):
				aggregate["enemy_will_break"] = true
				break
		elif side == "enemy":
			var sim_e := CombatResolver.resolve_exchange(p_state, e_state, null, enemy_card, ["enemy"])
			_merge_exchange(aggregate, sim_e)
			_apply_exchange_to_states(p_state, e_state, sim_e)
			if bool(sim_e.get("player_will_break", false)):
				aggregate["player_will_break"] = true
	aggregate["player_final"] = int(p_state.get("position", int(player_state.get("position", 0))))
	aggregate["enemy_final"] = int(e_state.get("position", int(enemy_state.get("position", 0))))
	return aggregate

static func _empty_exchange(order: Array[String]) -> Dictionary:
	return {"player_final": 0, "enemy_final": 0, "player_hp_delta": 0, "enemy_hp_delta": 0, "player_momentum_delta": 0, "enemy_momentum_delta": 0, "player_guard_delta": 0, "enemy_guard_delta": 0, "player_range_result": CombatResolver.RANGE_NONE, "enemy_range_result": CombatResolver.RANGE_NONE, "player_will_break": false, "enemy_will_break": false, "order": order}

static func _merge_exchange(target: Dictionary, source: Dictionary) -> void:
	for key in ["player_hp_delta", "enemy_hp_delta", "player_momentum_delta", "enemy_momentum_delta", "player_guard_delta", "enemy_guard_delta"]:
		target[key] = int(target.get(key, 0)) + int(source.get(key, 0))
	if str(source.get("player_range_result", CombatResolver.RANGE_NONE)) != CombatResolver.RANGE_NONE:
		target["player_range_result"] = str(source.get("player_range_result", CombatResolver.RANGE_NONE))
	if str(source.get("enemy_range_result", CombatResolver.RANGE_NONE)) != CombatResolver.RANGE_NONE:
		target["enemy_range_result"] = str(source.get("enemy_range_result", CombatResolver.RANGE_NONE))
	target["player_will_break"] = bool(target.get("player_will_break", false)) or bool(source.get("player_will_break", false))
	target["enemy_will_break"] = bool(target.get("enemy_will_break", false)) or bool(source.get("enemy_will_break", false))

static func _apply_exchange_to_states(p_state: Dictionary, e_state: Dictionary, sim: Dictionary) -> void:
	p_state["hp"] = maxi(int(p_state.get("hp", 0)) + int(sim.get("player_hp_delta", 0)), 0)
	e_state["hp"] = maxi(int(e_state.get("hp", 0)) + int(sim.get("enemy_hp_delta", 0)), 0)
	p_state["momentum"] = clampi(int(p_state.get("momentum", 0)) + int(sim.get("player_momentum_delta", 0)), 0, int(p_state.get("max_momentum", 10)))
	e_state["momentum"] = clampi(int(e_state.get("momentum", 0)) + int(sim.get("enemy_momentum_delta", 0)), 0, int(e_state.get("max_momentum", 10)))
	p_state["guard"] = maxi(0, int(p_state.get("guard", 0)) + int(sim.get("player_guard_delta", 0)))
	e_state["guard"] = maxi(0, int(e_state.get("guard", 0)) + int(sim.get("enemy_guard_delta", 0)))
	p_state["position"] = int(sim.get("player_final", p_state.get("position", 0)))
	e_state["position"] = int(sim.get("enemy_final", e_state.get("position", 0)))

static func _apply_edge_pressure_to_sampler_state(state: Dictionary) -> int:
	var pos := int(state.get("position", 0))
	if pos != 0 and pos != 8:
		return 0
	var before := int(state.get("momentum", 0))
	if before <= 0:
		return 0
	state["momentum"] = maxi(before - 1, 0)
	if int(state.get("momentum", 0)) == 0:
		state["next_broken"] = true
	return 1

static func _choose_card(cards: Array[CardData], actor: Dictionary, target: Dictionary, rng: RandomNumberGenerator) -> CardData:
	if cards.is_empty():
		return null
	var best: CardData = null
	var best_score: float = -999999.0
	for card: CardData in cards:
		if card == null:
			continue
		var score: float = _score_card(card, actor, target) + rng.randf_range(-0.75, 0.75)
		if score > best_score:
			best_score = score
			best = card
	return best if best != null else cards[rng.randi_range(0, cards.size() - 1)]

static func _score_card(card: CardData, actor: Dictionary, target: Dictionary) -> float:
	var distance: int = absi(int(target.get("position", 0)) - int(actor.get("position", 0)))
	var score: float = 0.0
	if distance >= card.min_distance and distance <= card.max_distance:
		score += 8.0
	else:
		score -= 3.0
	if int(actor.get("momentum", 0)) < card.momentum_cost:
		score -= 8.0
	score += float(card.damage) * 0.8 + float(card.break_momentum) * 0.7 + float(card.gain_momentum) * 0.5 + float(card.guard) * 0.35
	var preferred_min := int(actor.get("preferred_min", 2 if str(actor.get("style", "")) == "spear" else 1))
	var preferred_max := int(actor.get("preferred_max", 3 if str(actor.get("style", "")) == "spear" else 2))
	if str(actor.get("style", "")) == "spear":
		if card.target_push_after > 0:
			score += 2.5
		if distance >= preferred_min and distance <= preferred_max:
			score += 2.0
	else:
		if card.target_pull_after > 0 or card.self_move_after > 0:
			score += 2.5
		if distance >= preferred_min and distance <= preferred_max:
			score += 2.0
	return score

static func _move_toward_preferred_range(actor: Dictionary, target: Dictionary, preferred: Array) -> void:
	var distance: int = absi(int(target.get("position", 0)) - int(actor.get("position", 0)))
	var min_pref: int = int(preferred[0])
	var max_pref: int = int(preferred[1])
	if distance >= min_pref and distance <= max_pref:
		_face_each_other(actor, target)
		return
	var dir: int = 1 if int(target.get("position", 0)) > int(actor.get("position", 0)) else -1
	var steps: int = maxi(1, int(actor.get("qinggong", 1)))
	if distance > max_pref:
		actor["position"] = clampi(int(actor.get("position", 0)) + dir * mini(steps, distance - max_pref), 0, 8)
	elif distance < min_pref:
		actor["position"] = clampi(int(actor.get("position", 0)) - dir * mini(steps, min_pref - distance), 0, 8)
	_face_each_other(actor, target)

static func _face_each_other(a: Dictionary, b: Dictionary) -> void:
	if int(b.get("position", 0)) > int(a.get("position", 0)):
		a["facing"] = "right"
		b["facing"] = "left"
	elif int(b.get("position", 0)) < int(a.get("position", 0)):
		a["facing"] = "left"
		b["facing"] = "right"

static func _movement_count(card: CardData, field: String) -> int:
	if card == null or card.move_condition == CardData.MOVE_NONE:
		return 0
	if field == "target_push_after":
		return abs(card.target_push_after)
	if field == "target_pull_after":
		return abs(card.target_pull_after)
	return 0

static func _ratio_get(r: Dictionary, key: int) -> float:
	if r.has(key):
		return float(r[key])
	if r.has(str(key)):
		return float(r[str(key)])
	return 0.0
