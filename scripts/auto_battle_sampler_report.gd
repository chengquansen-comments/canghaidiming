extends "res://scripts/auto_battle_sampler_optimization.gd"

# Report formatting layer.

static func format_report(result: Dictionary) -> String:
	if result.is_empty():
		return "未采样"
	var player_label := str(result.get("player_label", "玩家"))
	var enemy_label := str(result.get("enemy_label", "敌人"))
	return "样本:%d  模式:%s  压力:%s  平均回合:%.1f\n%s胜:%.1f%%  %s胜:%.1f%%  平:%.1f%%\n平均余血: %s %.1f / %s %.1f\n%s死亡回合: %s  %s死亡回合: %s\n崩势: 总%d  %s %.0f%%@%s  %s %.0f%%@%s\n压力触发: 边界%d  稳势%d\n击退:%d 拉近:%d 自移:%d\n命中: %s%d / %s%d\n结论: %s\n距离分布: %s" % [int(result.get("sample_count", 0)), str(result.get("settlement_mode", MODE_REACTIVE_ID)), str(result.get("pressure_profile", PRESSURE_NONE)), float(result.get("avg_turns", 0.0)), player_label, float(result.get("player_win_rate", 0.0)) * 100.0, enemy_label, float(result.get("enemy_win_rate", 0.0)) * 100.0, float(result.get("draw_rate", 0.0)) * 100.0, player_label, float(result.get("avg_player_hp", 0.0)), enemy_label, float(result.get("avg_enemy_hp", 0.0)), player_label, _format_optional_turn(float(result.get("avg_player_death_turn", 0.0))), enemy_label, _format_optional_turn(float(result.get("avg_enemy_death_turn", 0.0))), int(result.get("break_total", 0)), player_label, float(result.get("player_break_rate", 0.0)) * 100.0, _format_optional_turn(float(result.get("avg_player_first_break_turn", 0.0))), enemy_label, float(result.get("enemy_break_rate", 0.0)) * 100.0, _format_optional_turn(float(result.get("avg_enemy_first_break_turn", 0.0))), int(result.get("pressure_edge_total", 0)), int(result.get("break_resist_total", 0)), int(result.get("push_total", 0)), int(result.get("pull_total", 0)), int(result.get("self_move_total", 0)), player_label, int(result.get("player_hits", 0)), enemy_label, int(result.get("enemy_hits", 0)), format_balance_conclusion(result), _format_distance_ratio(result.get("distance_ratio", {}))]

static func format_balance_conclusion(result: Dictionary) -> String:
	if result.is_empty():
		return "未采样"
	var win := float(result.get("player_win_rate", 0.0))
	var turns := float(result.get("avg_turns", 0.0))
	var parts: Array[String] = []
	if win >= 0.72:
		parts.append("玩家偏强")
	elif win <= 0.42:
		parts.append("玩家偏弱")
	else:
		parts.append("胜率可用")
	if turns < 4.5:
		parts.append("节奏偏短")
	elif turns > 10.0:
		parts.append("节奏偏长")
	else:
		parts.append("节奏可用")
	if float(result.get("draw_rate", 0.0)) > 0.18:
		parts.append("平局/拖时偏高")
	if float(result.get("enemy_break_rate", 0.0)) < 0.18 and win < 0.55:
		parts.append("破敌压力不足")
	return "，".join(parts)

static func _format_optional_turn(value: float) -> String:
	return "%.1f" % value if value > 0.0 else "-"

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
