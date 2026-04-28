extends RefCounted
class_name AutoBattleSampler

# CardData-only auto battle sampler. Runtime inputs and tuned candidates are
# CardData instances; combat exchange is delegated to CombatResolver.

const CombatResolver = preload("res://scripts/combat_resolver.gd")

static func run_batch(player_cards: Array[CardData], enemy_cards: Array[CardData], options: Dictionary = {}) -> Dictionary:
	var sample_count: int = int(options.get("sample_count", 100))
	var max_turns: int = int(options.get("max_turns", 30))
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = int(options.get("seed", Time.get_unix_time_from_system()))
	var aggregate: Dictionary = _empty_aggregate(sample_count, max_turns)
	aggregate["player_label"] = str(options.get("player_label", "玩家"))
	aggregate["enemy_label"] = str(options.get("enemy_label", "敌人"))
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

static func run_single(player_cards: Array[CardData], enemy_cards: Array[CardData], max_turns: int, rng: RandomNumberGenerator, options: Dictionary = {}) -> Dictionary:
	var player_state: Dictionary = options.get("player_state", {})
	var enemy_state: Dictionary = options.get("enemy_state", {})
	var p: Dictionary = _runtime_state(player_state, {"hp": 24, "max_momentum": 10, "momentum": 6, "guard": 0, "position": 2, "facing": "right", "broken": false, "style": "spear"})
	var e: Dictionary = _runtime_state(enemy_state, {"hp": 22, "max_momentum": 10, "momentum": 6, "guard": 0, "position": 6, "facing": "left", "broken": false, "style": "blade"})
	var player_preferred: Array = options.get("player_preferred", _preferred_for_style(str(p.get("style", "spear"))))
	var enemy_preferred: Array = options.get("enemy_preferred", _preferred_for_style(str(e.get("style", "blade"))))
	_bind_preferred_to_state(p, player_preferred)
	_bind_preferred_to_state(e, enemy_preferred)
	var momentum_regen: int = int(options.get("momentum_regen", 3))
	var distance_hist: Dictionary = {}
	var push_count: int = 0
	var pull_count: int = 0
	var self_move_count: int = 0
	var break_count: int = 0
	var player_hit_count: int = 0
	var enemy_hit_count: int = 0
	var turns: int = 0
	for turn: int in range(max_turns):
		turns += 1
		p["guard"] = 0
		e["guard"] = 0
		p["momentum"] = mini(int(p.get("max_momentum", 10)), int(p.get("momentum", 0)) + momentum_regen)
		e["momentum"] = mini(int(e.get("max_momentum", 10)), int(e.get("momentum", 0)) + momentum_regen)
		p["broken"] = false
		e["broken"] = false
		_move_toward_preferred_range(p, e, player_preferred)
		_move_toward_preferred_range(e, p, enemy_preferred)
		var p_card: CardData = _choose_card(player_cards, p, e, rng)
		var e_card: CardData = _choose_card(enemy_cards, e, p, rng)
		var order: Array[String] = _resolution_order(p, e, p_card, e_card, rng)
		var sim: Dictionary = CombatResolver.resolve_exchange(p, e, p_card, e_card, order)
		p["hp"] = int(p.get("hp", 0)) + int(sim.get("player_hp_delta", 0))
		e["hp"] = int(e.get("hp", 0)) + int(sim.get("enemy_hp_delta", 0))
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
		if bool(sim.get("enemy_will_break", false)):
			break_count += 1
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
	return {"winner": winner, "turns": turns, "player_hp": int(p.get("hp", 0)), "enemy_hp": int(e.get("hp", 0)), "distance_hist": distance_hist, "push_count": push_count, "pull_count": pull_count, "self_move_count": self_move_count, "break_count": break_count, "player_hit_count": player_hit_count, "enemy_hit_count": enemy_hit_count}

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

static func _resolution_order(player_state: Dictionary, enemy_state: Dictionary, player_card: CardData, enemy_card: CardData, rng: RandomNumberGenerator) -> Array[String]:
	var result: Array[String] = []
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

static func balance_score(result: Dictionary) -> float:
	var win_gap: float = abs(float(result.get("player_win_rate", 0.0)) - float(result.get("enemy_win_rate", 0.0)))
	var turn_penalty: float = abs(float(result.get("avg_turns", 0.0)) - 7.0) / 10.0
	var distance_ratio: Dictionary = result.get("distance_ratio", {})
	var core_distance_ratio: float = _ratio_get(distance_ratio, 1) + _ratio_get(distance_ratio, 2) + _ratio_get(distance_ratio, 3)
	var distance_penalty: float = abs(core_distance_ratio - 0.72)
	var draw_penalty: float = float(result.get("draw_rate", 0.0)) * 0.5
	return win_gap * 2.0 + turn_penalty + distance_penalty + draw_penalty

static func _ratio_get(r: Dictionary, key: int) -> float:
	if r.has(key):
		return float(r[key])
	if r.has(str(key)):
		return float(r[str(key)])
	return 0.0

static func _empty_aggregate(sample_count: int, max_turns: int) -> Dictionary:
	return {"sample_count": sample_count, "max_turns": max_turns, "player_wins": 0, "enemy_wins": 0, "draws": 0, "turns_total": 0, "distance_hist": {}, "push_total": 0, "pull_total": 0, "self_move_total": 0, "break_total": 0, "player_hits": 0, "enemy_hits": 0}

static func _record_result(aggregate: Dictionary, result: Dictionary) -> void:
	var winner: String = str(result.get("winner", "draw"))
	if winner.begins_with("player"):
		aggregate["player_wins"] += 1
	elif winner.begins_with("enemy"):
		aggregate["enemy_wins"] += 1
	else:
		aggregate["draws"] += 1
	aggregate["turns_total"] += int(result.get("turns", 0))
	aggregate["push_total"] += int(result.get("push_count", 0))
	aggregate["pull_total"] += int(result.get("pull_count", 0))
	aggregate["self_move_total"] += int(result.get("self_move_count", 0))
	aggregate["break_total"] += int(result.get("break_count", 0))
	aggregate["player_hits"] += int(result.get("player_hit_count", 0))
	aggregate["enemy_hits"] += int(result.get("enemy_hit_count", 0))
	var hist: Dictionary = result.get("distance_hist", {})
	for key in hist.keys():
		aggregate["distance_hist"][key] = int(aggregate["distance_hist"].get(key, 0)) + int(hist[key])

static func _finalize_aggregate(aggregate: Dictionary) -> void:
	var n: int = maxi(int(aggregate.get("sample_count", 1)), 1)
	aggregate["player_win_rate"] = float(aggregate.get("player_wins", 0)) / float(n)
	aggregate["enemy_win_rate"] = float(aggregate.get("enemy_wins", 0)) / float(n)
	aggregate["draw_rate"] = float(aggregate.get("draws", 0)) / float(n)
	aggregate["avg_turns"] = float(aggregate.get("turns_total", 0)) / float(n)
	var total_distance_ticks: int = 0
	for key in aggregate["distance_hist"].keys():
		total_distance_ticks += int(aggregate["distance_hist"][key])
	var distance_ratio: Dictionary = {}
	for key in aggregate["distance_hist"].keys():
		distance_ratio[key] = float(aggregate["distance_hist"][key]) / float(maxi(total_distance_ticks, 1))
	aggregate["distance_ratio"] = distance_ratio

static func format_report(result: Dictionary) -> String:
	if result.is_empty():
		return "未采样"
	var player_label := str(result.get("player_label", "玩家"))
	var enemy_label := str(result.get("enemy_label", "敌人"))
	return "样本:%d  平均回合:%.1f\n%s胜:%.1f%%  %s胜:%.1f%%  平:%.1f%%\n击退:%d 拉近:%d 自移:%d 崩势:%d\n命中: %s%d / %s%d\n距离分布: %s" % [int(result.get("sample_count", 0)), float(result.get("avg_turns", 0.0)), player_label, float(result.get("player_win_rate", 0.0)) * 100.0, enemy_label, float(result.get("enemy_win_rate", 0.0)) * 100.0, float(result.get("draw_rate", 0.0)) * 100.0, int(result.get("push_total", 0)), int(result.get("pull_total", 0)), int(result.get("self_move_total", 0)), int(result.get("break_total", 0)), player_label, int(result.get("player_hits", 0)), enemy_label, int(result.get("enemy_hits", 0)), _format_distance_ratio(result.get("distance_ratio", {}))]

static func format_sweep_report(sweep: Dictionary, top_n: int = 5) -> String:
	if sweep.is_empty():
		return "未扫描"
	var results: Array = sweep.get("results", [])
	var text: String = "扫描:%d组 x %d局\n" % [int(sweep.get("config_count", 0)), int(sweep.get("samples_per_config", 0))]
	for i: int in range(mini(top_n, results.size())):
		text += _format_rank_line(i + 1, results[i]) + "\n"
	return text

static func format_optimize_report(opt: Dictionary, top_n: int = 5) -> String:
	if opt.is_empty():
		return "未优化"
	var text: String = "优化:%d轮 / 评估%d组 x %d局\n" % [int(opt.get("iterations", 0)), int(opt.get("evaluated", 0)), int(opt.get("samples_per_config", 0))]
	text += "推荐: " + _format_rank_line(1, opt.get("best", {})) + "\n"
	var results: Array = opt.get("results", [])
	for i: int in range(1, mini(top_n, results.size())):
		text += _format_rank_line(i + 1, results[i]) + "\n"
	return text

static func _format_rank_line(rank: int, r: Dictionary) -> String:
	var c: Dictionary = r.get("config", {})
	var player_label := str(r.get("player_label", "玩家"))
	var enemy_label := str(r.get("enemy_label", "敌人"))
	return "%d) score %.3f D%.2f B%.2f C%+d M%s %s%.0f%% %s%.0f%% 回合%.1f" % [rank, float(r.get("balance_score", 0.0)), float(c.get("damage", 1.0)), float(c.get("break", 1.0)), int(c.get("cost", 0)), "开" if bool(c.get("movement", true)) else "关", player_label, float(r.get("player_win_rate", 0.0)) * 100.0, enemy_label, float(r.get("enemy_win_rate", 0.0)) * 100.0, float(r.get("avg_turns", 0.0))]

static func _format_distance_ratio(distance_ratio: Dictionary) -> String:
	var parts: Array[String] = []
	for d: int in range(0, 9):
		if distance_ratio.has(d):
			parts.append("%d:%.0f%%" % [d, float(distance_ratio[d]) * 100.0])
		elif distance_ratio.has(str(d)):
			parts.append("%d:%.0f%%" % [d, float(distance_ratio[str(d)]) * 100.0])
	return " ".join(parts)
