extends RefCounted
const NarrativeBattleContext := preload("res://scripts/narrative_battle_context.gd")

var c

func _init(controller) -> void:
	c = controller

func _get(property: StringName):
	if c == null:
		return null
	return c.get(property)

func _set(property: StringName, value) -> bool:
	if c == null:
		return false
	c.set(property, value)
	return true

func _is_debug_toggle_event(event: InputEvent) -> bool:
	if not (event is InputEventKey):
		return false
	var key_event := event as InputEventKey
	return key_event.pressed and not key_event.echo and key_event.keycode == c.DEBUG_TOGGLE_KEY

func _toggle_focus_debug_panel() -> void:
	NarrativeBattleContext.toggle_ui_debug_visible()
	c._apply_focus_debug_visibility()

func _flow_node_ids() -> Array:
	if c.focus_flow_loaded:
		return c.focus_flow_node_ids
	c.focus_flow_loaded = true
	c.focus_flow_node_ids.clear()
	c.focus_flow_source = "fallback"
	_load_flow_from_compiled_data()
	if c.focus_flow_node_ids.is_empty():
		for node_id in c.MVP_NODE_IDS:
			c.focus_flow_node_ids.append(str(node_id))
	return c.focus_flow_node_ids

func _load_flow_from_compiled_data() -> void:
	if not c.narrative_mvp_data_loaded:
		return
	var ids = c.narrative_mvp_data.get("flow_node_ids", [])
	if not (ids is Array):
		return
	for node_id in ids:
		var clean_id := str(node_id).strip_edges()
		if not clean_id.is_empty():
			c.focus_flow_node_ids.append(clean_id)
	if not c.focus_flow_node_ids.is_empty():
		c.focus_flow_source = c.NARRATIVE_MVP_DATA_PATH

func _flow_count() -> int:
	return _flow_node_ids().size()

func _node_id_at(index: int) -> String:
	var ids := _flow_node_ids()
	if index >= 0 and index < ids.size():
		return str(ids[index])
	return ""

func _current_node_id() -> String:
	if c.in_prologue:
		return "prologue"
	var node_id := _node_id_at(c.node_index)
	if not node_id.is_empty():
		return node_id
	return "node"

func _world_map_total_count() -> int:
	return _flow_count() + 1

func _world_map_current_index() -> int:
	return 0 if c.in_prologue else c.node_index + 1

func _on_world_map_node_pressed(map_index: int) -> void:
	if map_index == 0:
		c.last_hint = "地图节点：序章。"
		c._render()
		return
	c._on_map_node_pressed(map_index - 1)

func _battle_growth_reward_for_source(source_index: int) -> Dictionary:
	if source_index < 0 or source_index >= _flow_count():
		return {"hp_gain": 0, "posture_gain": 0, "martial_gain": 0, "heal_full": false}
	var node: Dictionary = c._node_data_at(source_index)
	var combat: Dictionary = c._node_level_combat(node)
	var encounter_id := str(combat.get("encounter_id", ""))
	if encounter_id.is_empty() and str(node.get("id", "")) == c.BOSS_NODE_ID:
		encounter_id = c.BOSS_ENCOUNTER_ID
	if c.has_method("_formal_reward_for_encounter"):
		return c._formal_reward_for_encounter(encounter_id, str(node.get("type", "")))
	return {"hp_gain": 2, "posture_gain": 0, "martial_gain": 1, "heal_full": true}

func _consume_battle_result_if_needed() -> void:
	if not NarrativeBattleContext.has_result():
		return
	var source_id: String = NarrativeBattleContext.source_node_id
	var result: String = NarrativeBattleContext.last_result
	if source_id == "prologue_master_rescue":
		c.in_prologue = true
		if result == "win":
			var pending_choice: Dictionary = c._load_pending_choice()
			var effects: Dictionary = c._choice_effects(pending_choice)
			c._apply_canonical_effects(effects)
			c.step_index = c.PROLOGUE_AFTER_MASTER_BATTLE_STEP
			c.prologue_sentence_index = 0
			c.prologue_result_sentence_index = 0
			c.showing_prologue_choice_result = false
			c.prologue_choice_result_text = ""
			c.prologue_choice_result_delta_text = ""
			c.last_hint = ""
		else:
			c.step_index = c.PROLOGUE_MASTER_RESCUE_STEP
			c.prologue_sentence_index = c._prologue_story_segments().size() - 1
			c.last_hint = "序章战斗返回：当前 Demo 按师父救场继续推进。"
		NarrativeBattleContext.clear()
		c._clear_pending_choice()
		c._save_narrative_state_to_context()
		return
	for i in range(_flow_count()):
		if _node_id_at(i) == source_id:
			c.node_index = i
			c.in_prologue = false
			break
	if result == "win":
		c._apply_battle_growth(c.node_index)
		if source_id == c.BOSS_NODE_ID:
			c.boss_battle_completed = true
			c.showing_choice_result = false
			c.choice_result_text = ""
			c.choice_result_delta_text = ""
			c.choice_result_sentence_index = 0
			c.last_hint = "首领倒下。现在决定这场战斗留下什么。"
		else:
			var pending_choice: Dictionary = c._load_pending_choice()
			if pending_choice.is_empty():
				c.last_hint = "战斗胜利：未找到待结算选择，暂不推进。"
			else:
				var effects: Dictionary = c._choice_effects(pending_choice)
				c._apply_canonical_effects(effects)
				c.choice_result_text = str(pending_choice.get("result", "战斗胜利。"))
				c.choice_result_delta_text = ""
				c.choice_result_sentence_index = 0
				c.showing_choice_result = true
				c.last_hint = ""
	elif result == "lose":
		c.last_hint = "战斗失败：已返回剧情。当前暂不扣除资源，可重新选择。"
		c.showing_choice_result = false
	elif result == "draw":
		c.last_hint = "战斗同归于尽：已返回剧情。线索保留，可重新选择。"
		c.showing_choice_result = false
	else:
		c.last_hint = "战斗结果未知：已返回剧情。"
	NarrativeBattleContext.clear()
	c._clear_pending_choice()
	c._clear_pending_boss_node()
	c.node_sentence_index = c._node_story_segments(c._node_data_at(c.node_index)).size() - 1
	c._save_narrative_state_to_context()

func _on_continue_after_choice_result() -> void:
	if not c._is_choice_result_complete():
		c.choice_result_sentence_index += 1
		c._render()
		return
	c.showing_choice_result = false
	c.choice_result_text = ""
	c.choice_result_delta_text = ""
	c.choice_result_sentence_index = 0
	if _node_id_at(c.node_index) == c.BOSS_NODE_ID:
		c.boss_battle_completed = false
	if c.node_index < _flow_count() - 1:
		c._advance_to_node(c.node_index + 1, "")
	else:
		c._render_ending()

func _advance_to_node(target_index: int, hint: String = "") -> void:
	c.last_hint = hint
	c.node_sentence_index = 0
	if target_index >= _flow_count():
		c._render_ending()
		return
	c.node_index = target_index
	c._save_narrative_state_to_context()
	c._render()

func _on_focus_foot_alignment_debug_pressed() -> void:
	var current: bool = bool(Engine.get_meta(c.FOOT_ALIGNMENT_DEBUG_META, false))
	Engine.set_meta(c.FOOT_ALIGNMENT_DEBUG_META, not current)
	c._update_focus_debug_panel()

func _foot_alignment_debug_enabled() -> bool:
	return bool(Engine.get_meta(c.FOOT_ALIGNMENT_DEBUG_META, false))

func _focus_current_node_data() -> Dictionary:
	if c.has_method("_node_data_at"):
		var variant = c.call("_node_data_at", c.node_index)
		if variant is Dictionary:
			return variant
	if c.node_index >= 0 and c.node_index < c.NODES.size():
		return c.NODES[c.node_index]
	return {}

func _safe_label_text(label: Label, fallback: String) -> String:
	if label == null:
		return fallback
	var text := label.text.strip_edges()
	return fallback if text.is_empty() else text
