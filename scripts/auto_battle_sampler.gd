extends RefCounted
class_name AutoBattleSampler

# CardData-only auto battle sampler. Runtime inputs and tuned candidates are
# CardData instances; dictionaries are used only for aggregate reports/configs.

static func run_batch(player_cards: Array[CardData], enemy_cards: Array[CardData], options: Dictionary = {}) -> Dictionary:
	var sample_count: int = int(options.get("sample_count", 100))
	var max_turns: int = int(options.get("max_turns", 30))
	var rng := RandomNumberGenerator.new()
	rng.seed = int(options.get("seed", Time.get_unix_time_from_system()))
	var aggregate: Dictionary = _empty_aggregate(sample_count, max_turns)
	for i in range(sample_count):
		_record_result(aggregate, run_single(player_cards, enemy_cards, max_turns, rng))
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
					var config := {"damage": float(damage_value), "break": float(break_value), "cost": int(cost_value), "movement": bool(move_enabled)}
					results.append(evaluate_config(player_cards, enemy_cards, config, samples_per_config, max_turns))
	results.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("balance_score", 999.0)) < float(b.get("balance_score", 999.0))
	)
	return {"results": results, "best": results[0] if not results.is_empty() else {}, "config_count": results.size(), "samples_per_config": samples_per_config}

static func run_auto_optimize(player_cards: Array[CardData], enemy_cards: Array[CardData], options: Dictionary = {}) -> Dictionary:
	var iterations: int = int(options.get("iterations", 4))
	var candidates_per_iter: int = int(options.get("candidates_per_iter", 10))
	var samples_per_config: int = int(options.get("samples_per_config", 50))
	var max_turns: int = int(options.get("max_turns", 30))
	var rng := RandomNumberGenerator.new()
	rng.seed = int(options.get("seed", Time.get_unix_time_from_system()))
	var center := {"damage": 1.0, "break": 1.0, "cost": 0, "movement": true}
	var radius_damage := 0.25
	var radius_break := 0.25
	var all_results: Array[Dictionary] = []
	var best: Dictionary = evaluate_config(player_cards, enemy_cards, center, samples_per_config, max_turns)
	all_results.append(best)
	for iter in range(iterations):
		var local_results: Array[Dictionary] = []
		for i in range(candidates_per_iter):
			var cfg := {
				"damage": clampf(float(center.get("damage", 1.0)) + rng.randf_range(-radius_damage, radius_damage), 0.65, 1.6),
				"break": clampf(float(center.get("break", 1.0)) + rng.randf_range(-radius_break, radius_break), 0.65, 1.6),
				"cost": int(center.get("cost", 0)),
				"movement": bool(center.get("movement", true))
			}
			if rng.randf() < 0.18:
				cfg["cost"] = rng.randi_range(-1, 1)
			if rng.randf() < 0.12:
				cfg["movement"] = not bool(cfg.get("movement", true))
			var result := evaluate_config(player_cards, enemy_cards, cfg, samples_per_config, max_turns)
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

static func evaluate_config(player_cards: Array[CardData], enemy_cards: Array[CardData], config: Dictionary, samples_per_config: int, max_turns: int) -> Dictionary:
	var tuned_player: Array[CardData] = tune_cards(player_cards, float(config.get("damage", 1.0)), float(config.get("break", 1.0)), int(config.get("cost", 0)), bool(config.get("movement", true)))
	var tuned_enemy: Array[CardData] = tune_cards(enemy_cards, float(config.get("damage", 1.0)), float(config.get("break", 1.0)), int(config.get("cost", 0)), bool(config.get("movement", true)))
	var result: Dictionary = run_batch(tuned_player, tuned_enemy, {"sample_count": samples_per_config, "max_turns": max_turns})
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

static func run_single(player_cards: Array[CardData], enemy_cards: Array[CardData], max_turns: int, rng: RandomNumberGenerator) -> Dictionary:
	var p := {"hp": 24, "momentum": 6, "guard": 0, "position": 2, "facing": "right", "broken": false, "style": "spear"}
	var e := {"hp": 22, "momentum": 6, "guard": 0, "position": 6, "facing": "left", "broken": false, "style": "blade"}
	var distance_hist := {}
	var push_count := 0
	var pull_count := 0
	var self_move_count := 0
	var break_count := 0
	var player_hit_count := 0
	var enemy_hit_count := 0
	var turns := 0
	for turn in range(max_turns):
		turns += 1
		p["guard"] = 0
		e["guard"] = 0
		p["momentum"] = mini(10, int(p.get("momentum", 0)) + 3)
		e["momentum"] = mini(10, int(e.get("momentum", 0)) + 3)
		p["broken"] = false
		e["broken"] = false
		_move_toward_preferred_range(p, e, [2, 3])
		_move_toward_preferred_range(e, p, [1, 2])
		var p_card: CardData = _choose_card(player_cards, p, e, rng)
		var e_card: CardData = _choose_card(enemy_cards, e, p, rng)
		var order: Array[String] = ["player", "enemy"] if rng.randi_range(0, 1) == 0 else ["enemy", "player"]
		var sim := _simulate_exchange(p, e, p_card, e_card, order)
		p["hp"] = int(p.get("hp", 0)) + int(sim.get("player_hp_delta", 0))
		e["hp"] = int(e.get("hp", 0)) + int(sim.get("enemy_hp_delta", 0))
		p["momentum"] = clampi(int(p.get("momentum", 0)) + int(sim.get("player_momentum_delta", 0)), 0, 10)
		e["momentum"] = clampi(int(e.get("momentum", 0)) + int(sim.get("enemy_momentum_delta", 0)), 0, 10)
		p["position"] = int(sim.get("player_final", p.get("position", 0)))
		e["position"] = int(sim.get("enemy_final", e.get("position", 0)))
		_face_each_other(p, e)
		if str(sim.get("player_range_result", "none")) == "hit":
			player_hit_count += 1
		if str(sim.get("enemy_range_result", "none")) == "hit":
			enemy_hit_count += 1
		if bool(sim.get("player_will_break", false)):
			break_count += 1
		if bool(sim.get("enemy_will_break", false)):
			break_count += 1
		push_count += _movement_count(p_card, "target_push_after") + _movement_count(e_card, "target_push_after")
		pull_count += _movement_count(p_card, "target_pull_after") + _movement_count(e_card, "target_pull_after")
		self_move_count += absi(p_card.self_move_after) + absi(e_card.self_move_after)
		var d := absi(int(e.get("position", 0)) - int(p.get("position", 0)))
		distance_hist[d] = int(distance_hist.get(d, 0)) + 1
		if int(p.get("hp", 0)) <= 0 or int(e.get("hp", 0)) <= 0:
			break
	var winner := "draw"
	if int(p.get("hp", 0)) > 0 and int(e.get("hp", 0)) <= 0:
		winner = "player"
	elif int(e.get("hp", 0)) > 0 and int(p.get("hp", 0)) <= 0:
		winner = "enemy"
	elif int(p.get("hp", 0)) > int(e.get("hp", 0)):
		winner = "player_timeout"
	elif int(e.get("hp", 0)) > int(p.get("hp", 0)):
		winner = "enemy_timeout"
	return {"winner": winner, "turns": turns, "player_hp": int(p.get("hp", 0)), "enemy_hp": int(e.get("hp", 0)), "distance_hist": distance_hist, "push_count": push_count, "pull_count": pull_count, "self_move_count": self_move_count, "break_count": break_count, "player_hit_count": player_hit_count, "enemy_hit_count": enemy_hit_count}

static func _simulate_exchange(p: Dictionary, e: Dictionary, p_card: CardData, e_card: CardData, order: Array[String]) -> Dictionary:
	var p_pos := int(p.get("position", 0))
	var e_pos := int(e.get("position", 0))
	var p_facing := str(p.get("facing", "right"))
	var e_facing := str(e.get("facing", "left"))
	var p_hp_delta := 0
	var e_hp_delta := 0
	var p_momentum_delta := 0
	var e_momentum_delta := 0
	var p_result := "none"
	var e_result := "none"
	var p_will_break := false
	var e_will_break := false
	for side in order:
		if side == "player" and p_card != null:
			p_result = _evaluate_range(p_card, p_pos, p_facing, e_pos)
			var out_p := _resolve_card_preview(p_card, p_result, bool(p.get("broken", false)), bool(e.get("broken", false)), int(e.get("guard", 0)))
			e_hp_delta -= int(out_p.get("damage", 0))
			e_momentum_delta -= int(out_p.get("break", 0))
			p_momentum_delta += int(out_p.get("gain", 0))
			if int(e.get("momentum", 0)) > 0 and int(e.get("momentum", 0)) + e_momentum_delta <= 0:
				e_will_break = true
			var moved := _apply_card_movement(p_card, true, p_pos, e_pos, p_facing, p_result)
			p_pos = int(moved.get("player", p_pos))
			e_pos = int(moved.get("enemy", e_pos))
		elif side == "enemy" and e_card != null:
			e_result = _evaluate_range(e_card, e_pos, e_facing, p_pos)
			var out_e := _resolve_card_preview(e_card, e_result, bool(e.get("broken", false)), bool(p.get("broken", false)), int(p.get("guard", 0)))
			p_hp_delta -= int(out_e.get("damage", 0))
			p_momentum_delta -= int(out_e.get("break", 0))
			e_momentum_delta += int(out_e.get("gain", 0))
			if int(p.get("momentum", 0)) > 0 and int(p.get("momentum", 0)) + p_momentum_delta <= 0:
				p_will_break = true
			var moved2 := _apply_card_movement(e_card, false, p_pos, e_pos, e_facing, e_result)
			p_pos = int(moved2.get("player", p_pos))
			e_pos = int(moved2.get("enemy", e_pos))
	return {"player_final": clampi(p_pos, 0, 8), "enemy_final": clampi(e_pos, 0, 8), "player_hp_delta": p_hp_delta, "enemy_hp_delta": e_hp_delta, "player_momentum_delta": p_momentum_delta, "enemy_momentum_delta": e_momentum_delta, "player_range_result": p_result, "enemy_range_result": e_result, "player_will_break": p_will_break, "enemy_will_break": e_will_break}

static func _resolve_card_preview(card: CardData, range_result: String, actor_broken: bool, target_broken: bool, target_guard: int) -> Dictionary:
	if actor_broken or (range_result != "hit" and range_result != "graze"):
		return {"damage": 0, "break": 0, "gain": 0}
	var damage := card.damage
	if range_result == "graze":
		damage = maxi(ceili(float(damage) * 0.5), 1) if damage > 0 else 0
	if target_broken and damage > 0:
		damage *= 2
	damage = maxi(damage - target_guard, 0)
	var break_value := card.break_momentum
	if range_result == "graze":
		break_value = maxi(break_value - 1, 0)
	return {"damage": damage, "break": break_value, "gain": card.gain_momentum}

static func _evaluate_range(card: CardData, actor_pos: int, actor_facing: String, target_pos: int) -> String:
	if not card.requires_hit_check():
		return "hit"
	if card.requires_facing and not card.has_tag("回身") and not _faces_target(actor_pos, actor_facing, target_pos):
		return "miss_facing"
	var distance := absi(target_pos - actor_pos)
	if distance >= card.min_distance and distance <= card.max_distance:
		return "hit"
	var gap := card.min_distance - distance if distance < card.min_distance else distance - card.max_distance
	return "graze" if gap == 1 else "miss_range"

static func _apply_card_movement(card: CardData, is_player_actor: bool, p_pos: int, e_pos: int, actor_facing: String, range_result: String) -> Dictionary:
	var can_move := false
	if card.move_condition == CardData.MOVE_ALWAYS:
		can_move = true
	elif card.move_condition == CardData.MOVE_ON_HIT:
		can_move = range_result == "hit"
	elif card.move_condition == CardData.MOVE_ON_GRAZE:
		can_move = range_result == "graze"
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

static func _choose_card(cards: Array[CardData], actor: Dictionary, target: Dictionary, rng: RandomNumberGenerator) -> CardData:
	if cards.is_empty():
		return null
	var best: CardData = null
	var best_score := -999999.0
	for card: CardData in cards:
		if card == null:
			continue
		var score := _score_card(card, actor, target) + rng.randf_range(-0.75, 0.75)
		if score > best_score:
			best_score = score
			best = card
	return best if best != null else cards[rng.randi_range(0, cards.size() - 1)]

static func _score_card(card: CardData, actor: Dictionary, target: Dictionary) -> float:
	var distance := absi(int(target.get("position", 0)) - int(actor.get("position", 0)))
	var score := 0.0
	if distance >= card.min_distance and distance <= card.max_distance:
		score += 8.0
	else:
		score -= 3.0
	if int(actor.get("momentum", 0)) < card.momentum_cost:
		score -= 8.0
	score += float(card.damage) * 0.8 + float(card.break_momentum) * 0.7 + float(card.gain_momentum) * 0.5 + float(card.guard) * 0.35
	if str(actor.get("style", "")) == "spear":
		if card.target_push_after > 0:
			score += 2.5
		if distance == 2 or distance == 3:
			score += 2.0
	else:
		if card.target_pull_after > 0 or card.self_move_after > 0:
			score += 2.5
		if distance == 1 or distance == 2:
			score += 2.0
	return score

static func _move_toward_preferred_range(actor: Dictionary, target: Dictionary, preferred: Array) -> void:
	var distance := absi(int(target.get("position", 0)) - int(actor.get("position", 0)))
	var min_pref := int(preferred[0])
	var max_pref := int(preferred[1])
	if distance >= min_pref and distance <= max_pref:
		_face_each_other(actor, target)
		return
	var dir := 1 if int(target.get("position", 0)) > int(actor.get("position", 0)) else -1
	if distance > max_pref:
		actor["position"] = clampi(int(actor.get("position", 0)) + dir, 0, 8)
	elif distance < min_pref:
		actor["position"] = clampi(int(actor.get("position", 0)) - dir, 0, 8)
	_face_each_other(actor, target)

static func _face_each_other(a: Dictionary, b: Dictionary) -> void:
	if int(b.get("position", 0)) > int(a.get("position", 0)):
		a["facing"] = "right"
		b["facing"] = "left"
	elif int(b.get("position", 0)) < int(a.get("position", 0)):
		a["facing"] = "left"
		b["facing"] = "right"

static func _faces_target(actor_pos: int, actor_facing: String, target_pos: int) -> bool:
	if actor_pos == target_pos:
		return true
	if target_pos > actor_pos:
		return actor_facing == "right"
	return actor_facing == "left"

static func _movement_count(card: CardData, field: String) -> int:
	if card == null or card.move_condition == CardData.MOVE_NONE:
		return 0
	if field == "target_push_after":
		return abs(card.target_push_after)
	if field == "target_pull_after":
		return abs(card.target_pull_after)
	return 0

static func _preview_dir(actor_pos: int, target_pos: int, facing: String) -> int:
	if target_pos > actor_pos:
		return 1
	if target_pos < actor_pos:
		return -1
	return 1 if facing == "right" else -1

static func _preview_self(actor_pos: int, target_pos: int, facing: String, amount: int) -> int:
	var dir := _preview_dir(actor_pos, target_pos, facing)
	return clampi(actor_pos + dir if amount > 0 else actor_pos - dir, 0, 8)

static func _preview_push(actor_pos: int, target_pos: int, facing: String, amount: int) -> int:
	return clampi(target_pos + _preview_dir(actor_pos, target_pos, facing) * amount, 0, 8)

static func _preview_pull(actor_pos: int, target_pos: int, facing: String, amount: int) -> int:
	var dir := _preview_dir(actor_pos, target_pos, facing)
	var result := clampi(target_pos - dir * amount, 0, 8)
	if dir > 0 and result < actor_pos:
		result = actor_pos
	if dir < 0 and result > actor_pos:
		result = actor_pos
	return result

static func balance_score(result: Dictionary) -> float:
	var win_gap := abs(float(result.get("player_win_rate", 0.0)) - float(result.get("enemy_win_rate", 0.0)))
	var turn_penalty := abs(float(result.get("avg_turns", 0.0)) - 7.0) / 10.0
	var distance_ratio: Dictionary = result.get("distance_ratio", {})
	var core_distance_ratio := _ratio_get(distance_ratio, 1) + _ratio_get(distance_ratio, 2) + _ratio_get(distance_ratio, 3)
	var distance_penalty := abs(core_distance_ratio - 0.72)
	var draw_penalty := float(result.get("draw_rate", 0.0)) * 0.5
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
	var winner := str(result.get("winner", "draw"))
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
	var n := maxi(int(aggregate.get("sample_count", 1)), 1)
	aggregate["player_win_rate"] = float(aggregate.get("player_wins", 0)) / float(n)
	aggregate["enemy_win_rate"] = float(aggregate.get("enemy_wins", 0)) / float(n)
	aggregate["draw_rate"] = float(aggregate.get("draws", 0)) / float(n)
	aggregate["avg_turns"] = float(aggregate.get("turns_total", 0)) / float(n)
	var total_distance_ticks := 0
	for key in aggregate["distance_hist"].keys():
		total_distance_ticks += int(aggregate["distance_hist"][key])
	var distance_ratio := {}
	for key in aggregate["distance_hist"].keys():
		distance_ratio[key] = float(aggregate["distance_hist"][key]) / float(maxi(total_distance_ticks, 1))
	aggregate["distance_ratio"] = distance_ratio

static func format_report(result: Dictionary) -> String:
	if result.is_empty():
		return "未采样"
	return "样本:%d  平均回合:%.1f\n枪胜:%.1f%%  刀胜:%.1f%%  平:%.1f%%\n击退:%d 拉近:%d 自移:%d 崩势:%d\n命中: 枪%d / 刀%d\n距离分布: %s" % [int(result.get("sample_count", 0)), float(result.get("avg_turns", 0.0)), float(result.get("player_win_rate", 0.0)) * 100.0, float(result.get("enemy_win_rate", 0.0)) * 100.0, float(result.get("draw_rate", 0.0)) * 100.0, int(result.get("push_total", 0)), int(result.get("pull_total", 0)), int(result.get("self_move_total", 0)), int(result.get("break_total", 0)), int(result.get("player_hits", 0)), int(result.get("enemy_hits", 0)), _format_distance_ratio(result.get("distance_ratio", {}))]

static func format_sweep_report(sweep: Dictionary, top_n: int = 5) -> String:
	if sweep.is_empty():
		return "未扫描"
	var results: Array = sweep.get("results", [])
	var text := "扫描:%d组 x %d局\n" % [int(sweep.get("config_count", 0)), int(sweep.get("samples_per_config", 0))]
	for i in range(mini(top_n, results.size())):
		text += _format_rank_line(i + 1, results[i]) + "\n"
	return text

static func format_optimize_report(opt: Dictionary, top_n: int = 5) -> String:
	if opt.is_empty():
		return "未优化"
	var text := "优化:%d轮 / 评估%d组 x %d局\n" % [int(opt.get("iterations", 0)), int(opt.get("evaluated", 0)), int(opt.get("samples_per_config", 0))]
	text += "推荐: " + _format_rank_line(1, opt.get("best", {})) + "\n"
	var results: Array = opt.get("results", [])
	for i in range(1, mini(top_n, results.size())):
		text += _format_rank_line(i + 1, results[i]) + "\n"
	return text

static func _format_rank_line(rank: int, r: Dictionary) -> String:
	var c: Dictionary = r.get("config", {})
	return "%d) score %.3f D%.2f B%.2f C%+d M%s 枪%.0f%% 刀%.0f%% 回合%.1f" % [rank, float(r.get("balance_score", 0.0)), float(c.get("damage", 1.0)), float(c.get("break", 1.0)), int(c.get("cost", 0)), "开" if bool(c.get("movement", true)) else "关", float(r.get("player_win_rate", 0.0)) * 100.0, float(r.get("enemy_win_rate", 0.0)) * 100.0, float(r.get("avg_turns", 0.0))]

static func _format_distance_ratio(distance_ratio: Dictionary) -> String:
	var parts: Array[String] = []
	for d in range(0, 9):
		if distance_ratio.has(d):
			parts.append("%d:%.0f%%" % [d, float(distance_ratio[d]) * 100.0])
		elif distance_ratio.has(str(d)):
			parts.append("%d:%.0f%%" % [d, float(distance_ratio[str(d)]) * 100.0])
	return " ".join(parts)
