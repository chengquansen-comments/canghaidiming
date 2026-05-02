extends "res://scripts/narrative_demo_safe_controller.gd"

func _apply_battle_result_reward(source_index: int) -> void:
	if source_index < 0 or source_index >= NODES.size():
		return
	var node: Dictionary = NODES[source_index]
	var encounter_id: String = str(node.get("combat", ""))
	var reward: Dictionary = _formal_reward_for_encounter(encounter_id, str(node.get("type", "")))
	jun_gong += int(reward.get("jun_gong", 0))
	qing_wang += int(reward.get("qing_wang", 0))
	clues += int(reward.get("clues", 0))
	NarrativeBattleContext.apply_player_growth(
		"battle_win",
		int(reward.get("hp_gain", 0)),
		int(reward.get("posture_gain", 0)),
		int(reward.get("martial_gain", 0)),
		bool(reward.get("heal_full", true))
	)

func _formal_reward_for_encounter(encounter_id: String, node_type: String) -> Dictionary:
	match encounter_id:
		"enc_beach_ambush":
			return {"jun_gong":1, "qing_wang":0, "clues":1, "hp_gain":0, "posture_gain":0, "martial_gain":0, "heal_full":true, "reward_text":"海边伏击胜利：军功+1，旧案线索+1。"}
		"enc_transport_officer":
			return {"jun_gong":1, "qing_wang":1, "clues":2, "hp_gain":0, "posture_gain":0, "martial_gain":0, "heal_full":true, "reward_text":"押运官战胜利：军功+1，清望+1，旧案线索+2，武境+1。"}
		"enc_wakou_boss":
			return {"jun_gong":2, "qing_wang":0, "clues":2, "hp_gain":0, "posture_gain":0, "martial_gain":0, "heal_full":true, "reward_text":"破船首领战胜利：军功+2，旧案线索+2，武境+1。"}
		_:
			if node_type == "Boss":
				return {"jun_gong":2, "qing_wang":0, "clues":2, "hp_gain":0, "posture_gain":0, "martial_gain":0, "heal_full":true, "reward_text":"Boss战胜利：武境+1。"}
			return {"jun_gong":1, "qing_wang":0, "clues":1, "hp_gain":0, "posture_gain":0, "martial_gain":0, "heal_full":true, "reward_text":"战斗胜利：获得基础成长。"}

func _consume_battle_result_if_needed() -> void:
	if not NarrativeBattleContext.has_result():
		return
	var source_id: String = NarrativeBattleContext.source_node_id
	var result: String = NarrativeBattleContext.last_result
	if source_id == PROLOGUE_MASTER_SOURCE_ID:
		in_prologue = true
		step_index = PROLOGUE_AFTER_MASTER_BATTLE_STEP
		if result == "win":
			clues += 1
			last_hint = "序章战斗胜利：师父斩敌，敌人临死吐出旧案线索。"
		else:
			last_hint = "序章战斗返回：当前 Demo 按师父救场继续推进。"
		NarrativeBattleContext.clear()
		return
	for i in range(NODES.size()):
		var node: Dictionary = NODES[i]
		if str(node.get("id", "")) == source_id:
			node_index = i
			in_prologue = false
			break
	if result == "win":
		var current_node: Dictionary = NODES[node_index]
		var encounter_id: String = str(current_node.get("combat", ""))
		var reward: Dictionary = _formal_reward_for_encounter(encounter_id, str(current_node.get("type", "")))
		_apply_battle_result_reward(node_index)
		if node_index < NODES.size() - 1:
			node_index += 1
		last_hint = str(reward.get("reward_text", "战斗胜利：已返回剧情，并自动推进到下一节点。"))
	elif result == "lose":
		last_hint = "战斗失败：已返回剧情。当前暂不扣除资源，可重试或视为胜利继续。"
	elif result == "draw":
		last_hint = "战斗同归于尽：已返回剧情。线索保留，暂不推进。"
	else:
		last_hint = "战斗结果未知：已返回剧情。"
	NarrativeBattleContext.clear()
