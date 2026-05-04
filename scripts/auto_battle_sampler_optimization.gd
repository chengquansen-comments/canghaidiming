extends "res://scripts/auto_battle_sampler_aggregate.gd"

# Parameter sweep and auto optimization layer.

static func run_batch(player_cards: Array[CardData], enemy_cards: Array[CardData], options: Dictionary = {}) -> Dictionary:
	var sample_count: int = int(options.get("sample_count", 100))
	var max_turns: int = int(options.get("max_turns", 30))
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = int(options.get("seed", Time.get_unix_time_from_system()))
	var aggregate: Dictionary = _empty_aggregate(sample_count, max_turns)
	aggregate["player_label"] = str(options.get("player_label", "玩家"))
	aggregate["enemy_label"] = str(options.get("enemy_label", "敌人"))
	aggregate["settlement_mode"] = str(options.get("settlement_mode", MODE_REACTIVE_ID))
	aggregate["pressure_profile"] = str(options.get("pressure_profile", PRESSURE_NONE))
	for i: int in range(sample_count):
		_record_result(aggregate, run_single(player_cards, enemy_cards, max_turns, rng, options))
	_finalize_aggregate(aggregate)
	return aggregate

static func run_parameter_sweep(player_cards: Array[CardData], enemy_cards: Array[CardData], options: Dictionary = {}) -> Dictionary:
	var samples_per_config: int = int(options.get("samples_per_config", 60))
	var max_turns: int = int(options.get("max_turns", 30))
	var damage_values: Array = options.get("damage_values", [0.85, 1.0, 1.15])
	var break_values: Array = options.get("break_values", [0.85, 1.0, 1.15])
	var cost_values: Array = options.get("cost_values", [0])
	var movement_values: Array = options.get("movement_values", [true, false])
	var results: Array[Dictionary] = []
	for damage_value in damage_values:
		for break_value in break_values:
			for cost_value in cost_values:
				for move_enabled in movement_values:
					var config: Dictionary = {"damage": float(damage_value), "break": float(break_value), "cost": int(cost_value), "movement": bool(move_enabled)}
					results.append(evaluate_config(player_cards, enemy_cards, config, samples_per_config, max_turns, options))
	results.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("balance_score", 999.0)) < float(b.get("balance_score", 999.0))
	)
	return {"results": results, "best": results[0] if not results.is_empty() else {}, "config_count": results.size(), "samples_per_config": samples_per_config}

static func run_auto_optimize(player_cards: Array[CardData], enemy_cards: Array[CardData], options: Dictionary = {}) -> Dictionary:
	var iterations: int = int(options.get("iterations", 4))
	var candidates_per_iter: int = int(options.get("candidates_per_iter", 10))
	var samples_per_config: int = int(options.get("samples_per_config", 50))
	var max_turns: int = int(options.get("max_turns", 30))
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = int(options.get("seed", Time.get_unix_time_from_system()))
	var center: Dictionary = {"damage": 1.0, "break": 1.0, "cost": 0, "movement": true}
	var radius_damage: float = 0.25
	var radius_break: float = 0.25
	var all_results: Array[Dictionary] = []
	var best: Dictionary = evaluate_config(player_cards, enemy_cards, center, samples_per_config, max_turns, options)
	all_results.append(best)
	for iter: int in range(iterations):
		var local_results: Array[Dictionary] = []
		for i: int in range(candidates_per_iter):
			var cfg: Dictionary = {
				"damage": clampf(float(center.get("damage", 1.0)) + rng.randf_range(-radius_damage, radius_damage), 0.65, 1.6),
				"break": clampf(float(center.get("break", 1.0)) + rng.randf_range(-radius_break, radius_break), 0.65, 1.6),
				"cost": int(center.get("cost", 0)),
				"movement": bool(center.get("movement", true))
			}
			if rng.randf() < 0.18:
				cfg["cost"] = rng.randi_range(-1, 1)
			if rng.randf() < 0.12:
				cfg["movement"] = not bool(cfg.get("movement", true))
			var result: Dictionary = evaluate_config(player_cards, enemy_cards, cfg, samples_per_config, max_turns, options)
			result["iteration"] = iter + 1
			local_results.append(result)
			all_results.append(result)
		local_results.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return float(a.get("balance_score", 999.0)) < float(b.get("balance_score", 999.0))
		)
		if not local_results.is_empty() and float(local_results[0].get("balance_score", 999.0)) < float(best.get("balance_score", 999.0)):
			best = local_results[0]
			center = best.get("config", center)
		radius_damage *= 0.58
		radius_break *= 0.58
	all_results.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("balance_score", 999.0)) < float(b.get("balance_score", 999.0))
	)
	return {"best": best, "results": all_results, "evaluated": all_results.size(), "iterations": iterations, "samples_per_config": samples_per_config}

static func evaluate_config(player_cards: Array[CardData], enemy_cards: Array[CardData], config: Dictionary, samples_per_config: int, max_turns: int, options: Dictionary = {}) -> Dictionary:
	var tuned_player: Array[CardData] = tune_cards(player_cards, float(config.get("damage", 1.0)), float(config.get("break", 1.0)), int(config.get("cost", 0)), bool(config.get("movement", true)))
	var tuned_enemy: Array[CardData] = tune_cards(enemy_cards, float(config.get("damage", 1.0)), float(config.get("break", 1.0)), int(config.get("cost", 0)), bool(config.get("movement", true)))
	var run_options: Dictionary = options.duplicate(true)
	run_options["sample_count"] = samples_per_config
	run_options["max_turns"] = max_turns
	var result: Dictionary = run_batch(tuned_player, tuned_enemy, run_options)
	result["config"] = config.duplicate(true)
	result["balance_score"] = balance_score(result)
	return result

static func tune_cards(cards: Array[CardData], damage_mul: float, break_mul: float, cost_delta: int, movement_enabled: bool) -> Array[CardData]:
	var out: Array[CardData] = []
	for source_card: CardData in cards:
		if source_card == null:
			continue
		var tuned: CardData = source_card.duplicate_card()
		tuned.damage = maxi(0, int(round(float(source_card.damage) * damage_mul)))
		tuned.break_momentum = maxi(0, int(round(float(source_card.break_momentum) * break_mul)))
		tuned.momentum_cost = maxi(0, source_card.momentum_cost + cost_delta)
		if not movement_enabled:
			tuned.self_move_after = 0
			tuned.target_push_after = 0
			tuned.target_pull_after = 0
			tuned.move_condition = CardData.MOVE_NONE
		out.append(tuned)
	return out
