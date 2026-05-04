extends "res://scripts/auto_battle_sampler_foundation.gd"

# Single-run simulation layer.

static func run_single(player_cards: Array[CardData], enemy_cards: Array[CardData], max_turns: int, rng: RandomNumberGenerator, options: Dictionary = {}) -> Dictionary:
	var player_state: Dictionary = options.get("player_state", {})
	var enemy_state: Dictionary = options.get("enemy_state", {})
	var p: Dictionary = _runtime_state(player_state, {"hp": 24, "max_momentum": 10, "momentum": 6, "guard": 0, "position": 2, "facing": "right", "broken": false, "style": "spear"})
	var e: Dictionary = _runtime_state(enemy_state, {"hp": 22, "max_momentum": 10, "momentum": 6, "guard": 0, "position": 6, "facing": "left", "broken": false, "style": "blade"})
	var player_preferred: Array = options.get("player_preferred", _preferred_for_style(str(p.get("style", "spear"))))
	var enemy_preferred: Array = options.get("enemy_preferred", _preferred_for_style(str(e.get("style", "blade"))))
	_bind_preferred_to_state(p, player_preferred)
	_bind_preferred_to_state(e, enemy_preferred)
	var settlement_mode := str(options.get("settlement_mode", MODE_REACTIVE_ID))
	var pressure_profile := str(options.get("pressure_profile", PRESSURE_NONE))
	var momentum_regen: int = int(options.get("momentum_regen", 2))
	var break_resist_available := pressure_profile == PRESSURE_BREAK_RESIST
	var distance_hist: Dictionary = {}
	var push_count: int = 0
	var pull_count: int = 0
	var self_move_count: int = 0
	var break_count: int = 0
	var player_break_count: int = 0
	var enemy_break_count: int = 0
	var player_first_break_turn: int = 0
	var enemy_first_break_turn: int = 0
	var player_hit_count: int = 0
	var enemy_hit_count: int = 0
	var pressure_edge_count: int = 0
	var break_resist_count: int = 0
	var turns: int = 0
	for turn: int in range(max_turns):
		turns += 1
		p["guard"] = 0
		e["guard"] = 0
		p["momentum"] = mini(int(p.get("max_momentum", 10)), int(p.get("momentum", 0)) + momentum_regen)
		e["momentum"] = mini(int(e.get("max_momentum", 10)), int(e.get("momentum", 0)) + momentum_regen)
		p["broken"] = bool(p.get("next_broken", false))
		e["broken"] = bool(e.get("next_broken", false))
		p["next_broken"] = false
		e["next_broken"] = false
		_move_toward_preferred_range(p, e, player_preferred)
		_move_toward_preferred_range(e, p, enemy_preferred)
		if pressure_profile == PRESSURE_EDGE:
			pressure_edge_count += _apply_edge_pressure_to_sampler_state(p)
			pressure_edge_count += _apply_edge_pressure_to_sampler_state(e)
		var p_card: CardData = _choose_card(player_cards, p, e, rng)
		var e_card: CardData = _choose_card(enemy_cards, e, p, rng)
		var order: Array[String] = _resolution_order(p, e, p_card, e_card, rng, settlement_mode)
		var sim: Dictionary = _resolve_sampler_exchange(p, e, p_card, e_card, order, settlement_mode)
		if bool(sim.get("enemy_will_break", false)) and break_resist_available:
			break_resist_available = false
			break_resist_count += 1
			sim["enemy_will_break"] = false
			sim["enemy_momentum_delta"] = mini(0, int(sim.get("enemy_momentum_delta", 0)) + 1)
		p["hp"] = maxi(int(p.get("hp", 0)) + int(sim.get("player_hp_delta", 0)), 0)
		e["hp"] = maxi(int(e.get("hp", 0)) + int(sim.get("enemy_hp_delta", 0)), 0)
		p["momentum"] = clampi(int(p.get("momentum", 0)) + int(sim.get("player_momentum_delta", 0)), 0, int(p.get("max_momentum", 10)))
		e["momentum"] = clampi(int(e.get("momentum", 0)) + int(sim.get("enemy_momentum_delta", 0)), 0, int(e.get("max_momentum", 10)))
		p["guard"] = max(0, int(p.get("guard", 0)) + int(sim.get("player_guard_delta", 0)))
		e["guard"] = max(0, int(e.get("guard", 0)) + int(sim.get("enemy_guard_delta", 0)))
		p["position"] = int(sim.get("player_final", p.get("position", 0)))
		e["position"] = int(sim.get("enemy_final", e.get("position", 0)))
		_face_each_other(p, e)
		if str(sim.get("player_range_result", "none")) == CombatResolver.RANGE_HIT:
			player_hit_count += 1
		if str(sim.get("enemy_range_result", "none")) == CombatResolver.RANGE_HIT:
			enemy_hit_count += 1
		if bool(sim.get("player_will_break", false)):
			break_count += 1
			player_break_count += 1
			p["next_broken"] = true
			if player_first_break_turn <= 0:
				player_first_break_turn = turns
		if bool(sim.get("enemy_will_break", false)):
			break_count += 1
			enemy_break_count += 1
			e["next_broken"] = true
			if enemy_first_break_turn <= 0:
				enemy_first_break_turn = turns
		push_count += _movement_count(p_card, "target_push_after") + _movement_count(e_card, "target_push_after")
		pull_count += _movement_count(p_card, "target_pull_after") + _movement_count(e_card, "target_pull_after")
		if p_card != null:
			self_move_count += absi(p_card.self_move_after)
		if e_card != null:
			self_move_count += absi(e_card.self_move_after)
		var d: int = absi(int(e.get("position", 0)) - int(p.get("position", 0)))
		distance_hist[d] = int(distance_hist.get(d, 0)) + 1
		if int(p.get("hp", 0)) <= 0 or int(e.get("hp", 0)) <= 0:
			break
	var winner: String = "draw"
	if int(p.get("hp", 0)) > 0 and int(e.get("hp", 0)) <= 0:
		winner = "player"
	elif int(e.get("hp", 0)) > 0 and int(p.get("hp", 0)) <= 0:
		winner = "enemy"
	elif int(p.get("hp", 0)) > int(e.get("hp", 0)):
		winner = "player_timeout"
	elif int(e.get("hp", 0)) > int(p.get("hp", 0)):
		winner = "enemy_timeout"
	var player_death_turn: int = turns if int(p.get("hp", 0)) <= 0 else 0
	var enemy_death_turn: int = turns if int(e.get("hp", 0)) <= 0 else 0
	return {"winner": winner, "turns": turns, "player_hp": int(p.get("hp", 0)), "enemy_hp": int(e.get("hp", 0)), "distance_hist": distance_hist, "push_count": push_count, "pull_count": pull_count, "self_move_count": self_move_count, "break_count": break_count, "player_break_count": player_break_count, "enemy_break_count": enemy_break_count, "player_first_break_turn": player_first_break_turn, "enemy_first_break_turn": enemy_first_break_turn, "player_death_turn": player_death_turn, "enemy_death_turn": enemy_death_turn, "player_hit_count": player_hit_count, "enemy_hit_count": enemy_hit_count, "pressure_edge_count": pressure_edge_count, "break_resist_count": break_resist_count}
