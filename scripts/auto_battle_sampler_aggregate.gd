extends "res://scripts/auto_battle_sampler_simulation.gd"

# Batch aggregation and scoring layer.

static func balance_score(result: Dictionary) -> float:
	var win_gap: float = abs(float(result.get("player_win_rate", 0.0)) - float(result.get("enemy_win_rate", 0.0)))
	var turn_penalty: float = abs(float(result.get("avg_turns", 0.0)) - 7.0) / 10.0
	var distance_ratio: Dictionary = result.get("distance_ratio", {})
	var core_distance_ratio: float = _ratio_get(distance_ratio, 1) + _ratio_get(distance_ratio, 2) + _ratio_get(distance_ratio, 3)
	var distance_penalty: float = abs(core_distance_ratio - 0.72)
	var draw_penalty: float = float(result.get("draw_rate", 0.0)) * 0.5
	return win_gap * 2.0 + turn_penalty + distance_penalty + draw_penalty

static func _empty_aggregate(sample_count: int, max_turns: int) -> Dictionary:
	return {"sample_count": sample_count, "max_turns": max_turns, "player_wins": 0, "enemy_wins": 0, "draws": 0, "turns_total": 0, "player_hp_total": 0, "enemy_hp_total": 0, "distance_hist": {}, "push_total": 0, "pull_total": 0, "self_move_total": 0, "break_total": 0, "player_break_total": 0, "enemy_break_total": 0, "player_first_break_turn_total": 0, "player_first_break_count": 0, "enemy_first_break_turn_total": 0, "enemy_first_break_count": 0, "player_death_turn_total": 0, "player_death_count": 0, "enemy_death_turn_total": 0, "enemy_death_count": 0, "pressure_edge_total": 0, "break_resist_total": 0, "player_hits": 0, "enemy_hits": 0}

static func _record_result(aggregate: Dictionary, result: Dictionary) -> void:
	var winner: String = str(result.get("winner", "draw"))
	if winner.begins_with("player"):
		aggregate["player_wins"] += 1
	elif winner.begins_with("enemy"):
		aggregate["enemy_wins"] += 1
	else:
		aggregate["draws"] += 1
	aggregate["turns_total"] += int(result.get("turns", 0))
	aggregate["player_hp_total"] += int(result.get("player_hp", 0))
	aggregate["enemy_hp_total"] += int(result.get("enemy_hp", 0))
	aggregate["push_total"] += int(result.get("push_count", 0))
	aggregate["pull_total"] += int(result.get("pull_count", 0))
	aggregate["self_move_total"] += int(result.get("self_move_count", 0))
	aggregate["break_total"] += int(result.get("break_count", 0))
	aggregate["player_break_total"] += int(result.get("player_break_count", 0))
	aggregate["enemy_break_total"] += int(result.get("enemy_break_count", 0))
	aggregate["pressure_edge_total"] += int(result.get("pressure_edge_count", 0))
	aggregate["break_resist_total"] += int(result.get("break_resist_count", 0))
	aggregate["player_hits"] += int(result.get("player_hit_count", 0))
	aggregate["enemy_hits"] += int(result.get("enemy_hit_count", 0))
	_record_positive_turn(aggregate, "player_first_break", int(result.get("player_first_break_turn", 0)))
	_record_positive_turn(aggregate, "enemy_first_break", int(result.get("enemy_first_break_turn", 0)))
	_record_positive_turn(aggregate, "player_death", int(result.get("player_death_turn", 0)))
	_record_positive_turn(aggregate, "enemy_death", int(result.get("enemy_death_turn", 0)))
	var hist: Dictionary = result.get("distance_hist", {})
	for key in hist.keys():
		aggregate["distance_hist"][key] = int(aggregate["distance_hist"].get(key, 0)) + int(hist[key])

static func _finalize_aggregate(aggregate: Dictionary) -> void:
	var n: int = maxi(int(aggregate.get("sample_count", 1)), 1)
	aggregate["player_win_rate"] = float(aggregate.get("player_wins", 0)) / float(n)
	aggregate["enemy_win_rate"] = float(aggregate.get("enemy_wins", 0)) / float(n)
	aggregate["draw_rate"] = float(aggregate.get("draws", 0)) / float(n)
	aggregate["avg_turns"] = float(aggregate.get("turns_total", 0)) / float(n)
	aggregate["avg_player_hp"] = float(aggregate.get("player_hp_total", 0)) / float(n)
	aggregate["avg_enemy_hp"] = float(aggregate.get("enemy_hp_total", 0)) / float(n)
	aggregate["player_break_rate"] = float(aggregate.get("player_first_break_count", 0)) / float(n)
	aggregate["enemy_break_rate"] = float(aggregate.get("enemy_first_break_count", 0)) / float(n)
	aggregate["avg_player_first_break_turn"] = _average_positive_turn(aggregate, "player_first_break")
	aggregate["avg_enemy_first_break_turn"] = _average_positive_turn(aggregate, "enemy_first_break")
	aggregate["avg_player_death_turn"] = _average_positive_turn(aggregate, "player_death")
	aggregate["avg_enemy_death_turn"] = _average_positive_turn(aggregate, "enemy_death")
	var total_distance_ticks: int = 0
	for key in aggregate["distance_hist"].keys():
		total_distance_ticks += int(aggregate["distance_hist"][key])
	var distance_ratio: Dictionary = {}
	for key in aggregate["distance_hist"].keys():
		distance_ratio[key] = float(aggregate["distance_hist"][key]) / float(maxi(total_distance_ticks, 1))
	aggregate["distance_ratio"] = distance_ratio

static func _record_positive_turn(aggregate: Dictionary, key: String, value: int) -> void:
	if value <= 0:
		return
	aggregate["%s_turn_total" % key] = int(aggregate.get("%s_turn_total" % key, 0)) + value
	aggregate["%s_count" % key] = int(aggregate.get("%s_count" % key, 0)) + 1

static func _average_positive_turn(aggregate: Dictionary, key: String) -> float:
	var count: int = int(aggregate.get("%s_count" % key, 0))
	if count <= 0:
		return 0.0
	return float(aggregate.get("%s_turn_total" % key, 0)) / float(count)
