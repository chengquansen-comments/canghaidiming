extends RefCounted
class_name AutoBattleSampler

const PreviewConsistencyChecker = preload("res://scripts/preview_consistency_checker.gd")

static func run_batch(player_cards: Array, enemy_cards: Array, options: Dictionary = {}) -> Dictionary:
	var sample_count := int(options.get("sample_count", 100))
	var max_turns := int(options.get("max_turns", 30))
	var rng := RandomNumberGenerator.new()
	rng.seed = int(options.get("seed", Time.get_unix_time_from_system()))
	var aggregate := _empty_aggregate(sample_count, max_turns)
	for i in range(sample_count):
		_record_result(aggregate, run_single(player_cards, enemy_cards, max_turns, rng))
	_finalize_aggregate(aggregate)
	return aggregate

static func run_parameter_sweep(player_cards: Array, enemy_cards: Array, options: Dictionary = {}) -> Dictionary:
	var samples_per_config := int(options.get("samples_per_config", 60))
	var max_turns := int(options.get("max_turns", 30))
	var damage_values: Array = options.get("damage_values", [0.85, 1.0, 1.15])
	var break_values: Array = options.get("break_values", [0.85, 1.0, 1.15])
	var cost_values: Array = options.get("cost_values", [0])
	var movement_values: Array = options.get("movement_values", [true, false])
	var results: Array[Dictionary] = []
	for dmg in damage_values:
		for brk in break_values:
			for cost in cost_values:
				for move_enabled in movement_values:
					var tuned_player := tune_cards(player_cards, float(dmg), float(brk), int(cost), bool(move_enabled))
					var tuned_enemy := tune_cards(enemy_cards, float(dmg), float(brk), int(cost), bool(move_enabled))
					var result := run_batch(tuned_player, tuned_enemy, {"sample_count": samples_per_config, "max_turns": max_turns})
					result.config = {"damage": float(dmg), "break": float(brk), "cost": int(cost), "movement": bool(move_enabled)}
					result.balance_score = balance_score(result)
					results.append(result)
	results.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("balance_score", 999.0)) < float(b.get("balance_score", 999.0))
	)
	return {"results": results, "best": results[0] if not results.is_empty() else {}, "config_count": results.size(), "samples_per_config": samples_per_config}

static func tune_cards(cards: Array, damage_mul: float, break_mul: float, cost_delta: int, movement_enabled: bool) -> Array:
	var out := []
	for c in cards:
		if typeof(c) != TYPE_DICTIONARY:
			continue
		var card := c.duplicate(true)
		card.damage = maxi(0, int(round(float(card.get("damage", 0)) * damage_mul)))
		card.break_momentum = maxi(0, int(round(float(card.get("break_momentum", 0)) * break_mul)))
		card.momentum_cost = maxi(0, int(card.get("momentum_cost", 0)) + cost_delta)
		if not movement_enabled:
			card.self_move_after = 0
			card.target_push_after = 0
			card.target_pull_after = 0
			card.move_condition = "none"
		out.append(card)
	return out

static func balance_score(result: Dictionary) -> float:
	var win_gap := abs(float(result.get("player_win_rate", 0.0)) - float(result.get("enemy_win_rate", 0.0)))
	var avg_turns := float(result.get("avg_turns", 0.0))
	var turn_penalty := abs(avg_turns - 7.0) / 10.0
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

static func run_single(player_cards: Array, enemy_cards: Array, max_turns: int, rng: RandomNumberGenerator) -> Dictionary:
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
		p.guard = 0
		e.guard = 0
		p.momentum = mini(10, int(p.momentum) + 3)
		e.momentum = mini(10, int(e.momentum) + 3)
		p.broken = false
		e.broken = false
		_move_toward_preferred_range(p, e, [2, 3])
		_move_toward_preferred_range(e, p, [1, 2])
		var p_card := _choose_card(player_cards, p, e, rng)
		var e_card := _choose_card(enemy_cards, e, p, rng)
		var order := ["player", "enemy"] if rng.randi_range(0, 1) == 0 else ["enemy", "player"]
		var sim := PreviewConsistencyChecker.simulate({"player_position": int(p.position), "enemy_position": int(e.position), "player_facing": str(p.facing), "enemy_facing": str(e.facing), "player_card": p_card, "enemy_card": e_card, "order": order, "player_momentum": int(p.momentum), "enemy_momentum": int(e.momentum), "player_guard": int(p.guard), "enemy_guard": int(e.guard), "player_broken": bool(p.broken), "enemy_broken": bool(e.broken)})
		p.hp += int(sim.get("player_hp_delta", 0))
		e.hp += int(sim.get("enemy_hp_delta", 0))
		p.momentum = clampi(int(p.momentum) + int(sim.get("player_momentum_delta", 0)), 0, 10)
		e.momentum = clampi(int(e.momentum) + int(sim.get("enemy_momentum_delta", 0)), 0, 10)
		p.position = int(sim.get("player_final", p.position))
		e.position = int(sim.get("enemy_final", e.position))
		_face_each_other(p, e)
		if str(sim.get("player_range_result", "none")) == "hit": player_hit_count += 1
		if str(sim.get("enemy_range_result", "none")) == "hit": enemy_hit_count += 1
		if bool(sim.get("player_will_break", false)): break_count += 1
		if bool(sim.get("enemy_will_break", false)): break_count += 1
		push_count += _movement_count(p_card, "target_push_after") + _movement_count(e_card, "target_push_after")
		pull_count += _movement_count(p_card, "target_pull_after") + _movement_count(e_card, "target_pull_after")
		self_move_count += abs(int(p_card.get("self_move_after", 0))) + abs(int(e_card.get("self_move_after", 0)))
		var d := absi(int(e.position) - int(p.position))
		distance_hist[d] = int(distance_hist.get(d, 0)) + 1
		if int(p.hp) <= 0 or int(e.hp) <= 0: break
	var winner := "draw"
	if int(p.hp) > 0 and int(e.hp) <= 0: winner = "player"
	elif int(e.hp) > 0 and int(p.hp) <= 0: winner = "enemy"
	elif int(p.hp) > int(e.hp): winner = "player_timeout"
	elif int(e.hp) > int(p.hp): winner = "enemy_timeout"
	return {"winner": winner, "turns": turns, "player_hp": int(p.hp), "enemy_hp": int(e.hp), "distance_hist": distance_hist, "push_count": push_count, "pull_count": pull_count, "self_move_count": self_move_count, "break_count": break_count, "player_hit_count": player_hit_count, "enemy_hit_count": enemy_hit_count}

static func _choose_card(cards: Array, actor: Dictionary, target: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	if cards.is_empty(): return {}
	var best: Dictionary = {}
	var best_score := -999999.0
	for card in cards:
		if typeof(card) != TYPE_DICTIONARY: continue
		var score := _score_card(card, actor, target) + rng.randf_range(-0.75, 0.75)
		if score > best_score:
			best_score = score
			best = card
	return best if not best.is_empty() else cards[rng.randi_range(0, cards.size() - 1)]

static func _score_card(card: Dictionary, actor: Dictionary, target: Dictionary) -> float:
	var distance := absi(int(target.position) - int(actor.position))
	var score := 0.0
	if distance >= int(card.get("min_distance", 0)) and distance <= int(card.get("max_distance", 8)): score += 8.0
	else: score -= 3.0
	if int(actor.momentum) < int(card.get("momentum_cost", 0)): score -= 8.0
	score += float(card.get("damage", 0)) * 0.8 + float(card.get("break_momentum", 0)) * 0.7 + float(card.get("gain_momentum", 0)) * 0.5 + float(card.get("guard", 0)) * 0.35
	if str(actor.get("style", "")) == "spear":
		if int(card.get("target_push_after", 0)) > 0: score += 2.5
		if distance == 2 or distance == 3: score += 2.0
	else:
		if int(card.get("target_pull_after", 0)) > 0 or int(card.get("self_move_after", 0)) > 0: score += 2.5
		if distance == 1 or distance == 2: score += 2.0
	return score

static func _move_toward_preferred_range(actor: Dictionary, target: Dictionary, preferred: Array) -> void:
	var distance := absi(int(target.position) - int(actor.position))
	var min_pref := int(preferred[0]); var max_pref := int(preferred[1])
	if distance >= min_pref and distance <= max_pref:
		_face_each_other(actor, target); return
	var dir := 1 if int(target.position) > int(actor.position) else -1
	if distance > max_pref: actor.position = clampi(int(actor.position) + dir, 0, 8)
	elif distance < min_pref: actor.position = clampi(int(actor.position) - dir, 0, 8)
	_face_each_other(actor, target)

static func _face_each_other(a: Dictionary, b: Dictionary) -> void:
	if int(b.position) > int(a.position): a.facing = "right"; b.facing = "left"
	elif int(b.position) < int(a.position): a.facing = "left"; b.facing = "right"

static func _movement_count(card: Dictionary, field: String) -> int:
	if str(card.get("move_condition", "none")) == "none": return 0
	return abs(int(card.get(field, 0)))

static func _empty_aggregate(sample_count: int, max_turns: int) -> Dictionary:
	return {"sample_count": sample_count, "max_turns": max_turns, "player_wins": 0, "enemy_wins": 0, "draws": 0, "turns_total": 0, "distance_hist": {}, "push_total": 0, "pull_total": 0, "self_move_total": 0, "break_total": 0, "player_hits": 0, "enemy_hits": 0}

static func _record_result(aggregate: Dictionary, result: Dictionary) -> void:
	var winner := str(result.get("winner", "draw"))
	if winner.begins_with("player"): aggregate.player_wins += 1
	elif winner.begins_with("enemy"): aggregate.enemy_wins += 1
	else: aggregate.draws += 1
	aggregate.turns_total += int(result.get("turns", 0)); aggregate.push_total += int(result.get("push_count", 0)); aggregate.pull_total += int(result.get("pull_count", 0)); aggregate.self_move_total += int(result.get("self_move_count", 0)); aggregate.break_total += int(result.get("break_count", 0)); aggregate.player_hits += int(result.get("player_hit_count", 0)); aggregate.enemy_hits += int(result.get("enemy_hit_count", 0))
	var hist: Dictionary = result.get("distance_hist", {})
	for key in hist.keys(): aggregate.distance_hist[key] = int(aggregate.distance_hist.get(key, 0)) + int(hist[key])

static func _finalize_aggregate(aggregate: Dictionary) -> void:
	var n := maxi(int(aggregate.sample_count), 1)
	aggregate.player_win_rate = float(aggregate.player_wins) / float(n); aggregate.enemy_win_rate = float(aggregate.enemy_wins) / float(n); aggregate.draw_rate = float(aggregate.draws) / float(n); aggregate.avg_turns = float(aggregate.turns_total) / float(n)
	var total_distance_ticks := 0
	for key in aggregate.distance_hist.keys(): total_distance_ticks += int(aggregate.distance_hist[key])
	var distance_ratio := {}
	for key in aggregate.distance_hist.keys(): distance_ratio[key] = float(aggregate.distance_hist[key]) / float(maxi(total_distance_ticks, 1))
	aggregate.distance_ratio = distance_ratio

static func format_report(result: Dictionary) -> String:
	if result.is_empty(): return "未采样"
	return "样本:%d  平均回合:%.1f\n枪胜:%.1f%%  刀胜:%.1f%%  平:%.1f%%\n击退:%d 拉近:%d 自移:%d 崩势:%d\n命中: 枪%d / 刀%d\n距离分布: %s" % [int(result.get("sample_count", 0)), float(result.get("avg_turns", 0.0)), float(result.get("player_win_rate", 0.0)) * 100.0, float(result.get("enemy_win_rate", 0.0)) * 100.0, float(result.get("draw_rate", 0.0)) * 100.0, int(result.get("push_total", 0)), int(result.get("pull_total", 0)), int(result.get("self_move_total", 0)), int(result.get("break_total", 0)), int(result.get("player_hits", 0)), int(result.get("enemy_hits", 0)), _format_distance_ratio(result.get("distance_ratio", {}))]

static func format_sweep_report(sweep: Dictionary, top_n: int = 5) -> String:
	if sweep.is_empty(): return "未扫描"
	var results: Array = sweep.get("results", [])
	var text := "扫描:%d组 x %d局\n" % [int(sweep.get("config_count", 0)), int(sweep.get("samples_per_config", 0))]
	for i in range(mini(top_n, results.size())):
		var r: Dictionary = results[i]
		var c: Dictionary = r.get("config", {})
		text += "%d) score %.3f D%.2f B%.2f C%+d M%s 枪%.0f%% 刀%.0f%% 回合%.1f\n" % [i + 1, float(r.get("balance_score", 0.0)), float(c.get("damage", 1.0)), float(c.get("break", 1.0)), int(c.get("cost", 0)), "开" if bool(c.get("movement", true)) else "关", float(r.get("player_win_rate", 0.0)) * 100.0, float(r.get("enemy_win_rate", 0.0)) * 100.0, float(r.get("avg_turns", 0.0))]
	return text

static func _format_distance_ratio(distance_ratio: Dictionary) -> String:
	var parts: Array[String] = []
	for d in range(0, 9):
		if distance_ratio.has(d): parts.append("%d:%.0f%%" % [d, float(distance_ratio[d]) * 100.0])
		elif distance_ratio.has(str(d)): parts.append("%d:%.0f%%" % [d, float(distance_ratio[str(d)]) * 100.0])
	return " ".join(parts)
