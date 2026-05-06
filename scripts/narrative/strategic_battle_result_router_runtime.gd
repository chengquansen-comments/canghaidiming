extends RefCounted

const NarrativeBattleContext := preload("res://scripts/narrative_battle_context.gd")

static func consume_if_handled(c) -> bool:
	if not NarrativeBattleContext.has_result():
		return false
	var source_id := NarrativeBattleContext.source_node_id
	var result := NarrativeBattleContext.last_result
	if source_id == c.STRATEGIC_FINAL_BOSS_SOURCE_ID:
		if result == "win":
			var boss: Dictionary = c.strategic_state.get("final_boss", {}) as Dictionary
			c.selected_ending_flag = str(boss.get("ending_flag", "surface_pirate"))
			c.strategic_state["active"] = false
			c.strategic_state["completed"] = true
			c.strategic_state["final_gate_active"] = false
			c.last_hint = "终局战胜利：%s" % str(boss.get("title", "海门收束"))
			NarrativeBattleContext.clear()
			c._save_narrative_state_to_context()
			if c._base_ui_ready():
				c._advance_to_node(c._flow_count(), c.last_hint)
			else:
				c.pending_strategic_ending_render = true
			return true
		c.last_hint = "终局战未胜：海门仍未收束，可再次挑战。"
		c.strategic_state["final_gate_active"] = true
		NarrativeBattleContext.clear()
		c._save_narrative_state_to_context()
		if c._base_ui_ready():
			c._render()
		return true
	if source_id.begins_with("map_"):
		var graph: Dictionary = c.strategic_state.get("network_map", {}) as Dictionary
		if not graph.is_empty() and not str(graph.get("pending_map_node_id", "")).is_empty():
			c._consume_network_node_battle(source_id, result)
			NarrativeBattleContext.clear()
			c._save_narrative_state_to_context()
			return true
		c._consume_strategic_node_battle(source_id, result)
		NarrativeBattleContext.clear()
		c._save_narrative_state_to_context()
		return true
	return false
