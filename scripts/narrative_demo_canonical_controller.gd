extends "res://scripts/narrative_demo_fragmented_controller.gd"

const CanonicalEffectsRuntime := preload("res://scripts/narrative/canonical_effects_runtime.gd")
const CanonicalNodeRegistry := preload("res://scripts/narrative/canonical_node_registry.gd")
const CanonicalStorySegmentRuntime := preload("res://scripts/narrative/canonical_story_segment_runtime.gd")

# Canonical narrative variable names for the MVP runtime.
# Internal legacy counters are kept as storage for compatibility with older controllers:
#   jun_gong  -> military_merit
#   qing_wang -> clean_reputation
#   clues     -> case_clues
const VAR_MILITARY_MERIT := "military_merit"
const VAR_CLEAN_REPUTATION := "clean_reputation"
const VAR_CASE_CLUES := "case_clues"
const VAR_SOLDIER_TRUST := "soldier_trust"
const VAR_RIVAL_GU_BOND := "rival_gu_bond"
const VAR_RIVAL_SHEN_BOND := "rival_shen_bond"
const VAR_RIVAL_QI_BOND := "rival_qi_bond"

const LEGACY_VAR_ALIASES := {
	"jun_gong": VAR_MILITARY_MERIT,
	"qing_wang": VAR_CLEAN_REPUTATION,
	"clues": VAR_CASE_CLUES,
	"public_repute": VAR_CLEAN_REPUTATION,
	"case_clues": VAR_CASE_CLUES,
	"soldier_trust": VAR_SOLDIER_TRUST,
	"rival_gu_bond": VAR_RIVAL_GU_BOND,
	"rival_shen_bond": VAR_RIVAL_SHEN_BOND,
	"rival_qi_bond": VAR_RIVAL_QI_BOND
}

const MVP_NODE_IDS := [
	"military_order",
	"beach_ambush",
	"beach_ambush_aftermath",
	"fishing_village_embers",
	"fishing_village_embers_aftermath",
	"ming_firearm",
	"altered_military_report",
	"transport_officer",
	"transport_officer_aftermath",
	"night_knife_camp",
	"wakou_boss",
	"military_coverup"
]

const MVP_NODE_META := {
	"military_order": {"column":"军令", "type":"事件", "visual_path":"res://assets/pixel_battle/backgrounds/narrative_military_order.png"},
	"beach_ambush": {"column":"初遇", "type":"普通战斗", "visual_path":"res://assets/pixel_battle/backgrounds/narrative_beach_ambush.png"},
	"beach_ambush_aftermath": {"column":"初遇", "type":"战后处理", "visual_path":"res://assets/pixel_battle/backgrounds/narrative_beach_ambush.png"},
	"fishing_village_embers": {"column":"初遇", "type":"普通战斗", "visual_path":"res://assets/pixel_battle/backgrounds/narrative_fishing_village_embers.png"},
	"fishing_village_embers_aftermath": {"column":"初遇", "type":"战后处理", "visual_path":"res://assets/pixel_battle/backgrounds/narrative_fishing_village_embers.png"},
	"ming_firearm": {"column":"疑点", "type":"旧物", "visual_path":"res://assets/pixel_battle/relics/relic_ming_firearm.png"},
	"altered_military_report": {"column":"疑点", "type":"旧物", "visual_path":"res://assets/pixel_battle/relics/relic_altered_military_report.png"},
	"transport_officer": {"column":"压迫", "type":"精英战斗", "visual_path":"res://assets/pixel_battle/portraits/transport_officer.png"},
	"transport_officer_aftermath": {"column":"压迫", "type":"战后处理", "visual_path":"res://assets/pixel_battle/portraits/transport_officer.png"},
	"night_knife_camp": {"column":"压迫", "type":"事件", "visual_path":"res://assets/pixel_battle/backgrounds/narrative_night_knife_camp.png"},
	"wakou_boss": {"column":"破船", "type":"Boss", "visual_path":"res://assets/pixel_battle/portraits/wakou_leader.png"},
	"military_coverup": {"column":"军门", "type":"结尾", "visual_path":"res://assets/pixel_battle/backgrounds/narrative_military_coverup.png"}
}

var node_sentence_index: int = 0
var selected_ending_flag: String = ""
var rival_gu_bond: int = 0
var rival_shen_bond: int = 0
var rival_qi_bond: int = 0

func _active_node_ids() -> Array:
	if has_method("_flow_node_ids"):
		var value = call("_flow_node_ids")
		if value is Array and not (value as Array).is_empty():
			return CanonicalNodeRegistry.active_node_ids(value as Array)
	return CanonicalNodeRegistry.active_node_ids()

func _active_node_count() -> int:
	return _active_node_ids().size()

func _narrative_state_snapshot() -> Dictionary:
	var base_state := super._narrative_state_snapshot()
	base_state[VAR_RIVAL_GU_BOND] = rival_gu_bond
	base_state[VAR_RIVAL_SHEN_BOND] = rival_shen_bond
	base_state[VAR_RIVAL_QI_BOND] = rival_qi_bond
	return base_state

func _restore_narrative_state_from_context() -> void:
	super._restore_narrative_state_from_context()
	if not NarrativeBattleContext.has_narrative_state():
		return
	var state: Dictionary = NarrativeBattleContext.get_narrative_state()
	rival_gu_bond = int(state.get(VAR_RIVAL_GU_BOND, rival_gu_bond))
	rival_shen_bond = int(state.get(VAR_RIVAL_SHEN_BOND, rival_shen_bond))
	rival_qi_bond = int(state.get(VAR_RIVAL_QI_BOND, rival_qi_bond))

func _canonical_state() -> Dictionary:
	return CanonicalEffectsRuntime.canonical_state(
		jun_gong,
		qing_wang,
		clues,
		rival_gu_bond,
		rival_shen_bond,
		rival_qi_bond
	)

func _normalize_effects(raw_effects: Dictionary) -> Dictionary:
	return CanonicalEffectsRuntime.normalize_effects(raw_effects)

func _apply_canonical_effects(effects: Dictionary) -> void:
	var values := CanonicalEffectsRuntime.apply_effects_to_values(_canonical_state(), effects)
	jun_gong = int(values[CanonicalEffectsRuntime.VAR_MILITARY_MERIT])
	qing_wang = int(values[CanonicalEffectsRuntime.VAR_CLEAN_REPUTATION])
	clues = int(values[CanonicalEffectsRuntime.VAR_CASE_CLUES])
	rival_gu_bond = int(values[CanonicalEffectsRuntime.VAR_RIVAL_GU_BOND])
	rival_shen_bond = int(values[CanonicalEffectsRuntime.VAR_RIVAL_SHEN_BOND])
	rival_qi_bond = int(values[CanonicalEffectsRuntime.VAR_RIVAL_QI_BOND])
	_save_narrative_state_to_context()

func _record_choice_ending_flag(choice: Dictionary) -> void:
	var ending_flag := str(choice.get("ending_flag", "")).strip_edges()
	var effects = choice.get("effects", {})
	if ending_flag.is_empty() and effects is Dictionary:
		ending_flag = str((effects as Dictionary).get("ending_flag", "")).strip_edges()
	if not ending_flag.is_empty():
		selected_ending_flag = ending_flag

func _node_id_at(index: int) -> String:
	return CanonicalNodeRegistry.node_id_at(_active_node_ids(), index)

func _node_meta(node_id: String) -> Dictionary:
	return CanonicalNodeRegistry.node_meta(node_id)

func _node_data_at(index: int) -> Dictionary:
	var node_id := _node_id_at(index)
	return CanonicalNodeRegistry.merge_node_data(node_id, _node_config(node_id))

func _configured_choices_for_node(node_id: String) -> Array:
	return CanonicalNodeRegistry.configured_choices(_node_config(node_id))

func _node_story_segments(node: Dictionary) -> Array[String]:
	return CanonicalStorySegmentRuntime.node_story_segments(node)

func _append_text_segments(segments: Array[String], raw_text: String) -> void:
	CanonicalStorySegmentRuntime.append_text_segments(segments, raw_text)

func _is_node_story_complete(node: Dictionary) -> bool:
	return CanonicalStorySegmentRuntime.is_node_story_complete(node, node_sentence_index)

func _current_node_story_text(node: Dictionary) -> String:
	return CanonicalStorySegmentRuntime.current_node_story_text(node, node_sentence_index)

func _on_continue_node_sentence() -> void:
	node_sentence_index += 1
	_render()

func _choice_effects_for_index(index: int) -> Dictionary:
	var node_id := _node_id_at(node_index)
	var configured_choices := _configured_choices_for_node(node_id)
	if index >= 0 and index < configured_choices.size() and configured_choices[index] is Dictionary:
		var configured: Dictionary = configured_choices[index]
		var effects = configured.get("effects", {})
		if effects is Dictionary:
			return _normalize_effects(effects)
	return {
		VAR_MILITARY_MERIT: 0,
		VAR_CLEAN_REPUTATION: 0,
		VAR_CASE_CLUES: 0,
		VAR_SOLDIER_TRUST: 0,
		VAR_RIVAL_GU_BOND: 0,
		VAR_RIVAL_SHEN_BOND: 0,
		VAR_RIVAL_QI_BOND: 0
	}

func _add_choice_button(choice: Dictionary, index: int) -> void:
	var node_id := _node_id_at(node_index)
	var effects := _choice_effects_for_index(index)
	var btn := Button.new()
	btn.text = "%s（军功 %+d / 清望 %+d / 旧案 %+d）" % [
		_choice_label(node_id, choice, index),
		int(effects[VAR_MILITARY_MERIT]),
		int(effects[VAR_CLEAN_REPUTATION]),
		int(effects[VAR_CASE_CLUES])
	]
	btn.custom_minimum_size = Vector2(0, 42)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.pressed.connect(_on_choice.bind(index))
	choices_box.add_child(btn)

func _on_choice(index: int) -> void:
	var node_id := _node_id_at(node_index)
	var choices := _configured_choices_for_node(node_id)
	if index < 0 or index >= choices.size():
		return
	if choices[index] is Dictionary:
		_record_choice_ending_flag(choices[index] as Dictionary)
	_apply_canonical_effects(_choice_effects_for_index(index))
	NarrativeBattleContext.apply_player_growth("choice", 0, 0, 0, false)
	if node_index < _active_node_count() - 1:
		_advance_to_node(node_index + 1, "")
	else:
		_render_ending()

func _apply_choice_delta(choice: Dictionary) -> void:
	_apply_canonical_effects(CanonicalEffectsRuntime.choice_delta(choice))
	NarrativeBattleContext.apply_player_growth("choice", 0, 0, 0, false)

func _battle_reward_for_source(source_index: int) -> Dictionary:
	var context_reward = NarrativeBattleContext.get_enemy_config().get("reward", {})
	if context_reward is Dictionary and not (context_reward as Dictionary).is_empty():
		return _normalize_effects(context_reward)
	if source_index < 0 or source_index >= _active_node_count():
		return {
			VAR_MILITARY_MERIT: 0,
			VAR_CLEAN_REPUTATION: 0,
			VAR_CASE_CLUES: 0,
			VAR_SOLDIER_TRUST: 0,
			VAR_RIVAL_GU_BOND: 0,
			VAR_RIVAL_SHEN_BOND: 0,
			VAR_RIVAL_QI_BOND: 0
		}
	var node: Dictionary = _node_data_at(source_index)
	var encounter_id := str(node.get("combat", ""))
	if has_method("_formal_reward_for_encounter"):
		var formal_reward: Dictionary = _formal_reward_for_encounter(encounter_id, str(node.get("type", "")))
		return _normalize_effects(formal_reward)
	match str(node.get("type", "")):
		"普通战斗", "精英战斗":
			return {VAR_MILITARY_MERIT: 1, VAR_CLEAN_REPUTATION: 0, VAR_CASE_CLUES: 1, VAR_SOLDIER_TRUST: 0, VAR_RIVAL_GU_BOND: 0, VAR_RIVAL_SHEN_BOND: 0, VAR_RIVAL_QI_BOND: 0}
		"Boss":
			return {VAR_MILITARY_MERIT: 2, VAR_CLEAN_REPUTATION: 0, VAR_CASE_CLUES: 2, VAR_SOLDIER_TRUST: 0, VAR_RIVAL_GU_BOND: 0, VAR_RIVAL_SHEN_BOND: 0, VAR_RIVAL_QI_BOND: 0}
		_:
			return {VAR_MILITARY_MERIT: 1, VAR_CLEAN_REPUTATION: 0, VAR_CASE_CLUES: 0, VAR_SOLDIER_TRUST: 0, VAR_RIVAL_GU_BOND: 0, VAR_RIVAL_SHEN_BOND: 0, VAR_RIVAL_QI_BOND: 0}

func _battle_growth_reward_for_source(source_index: int) -> Dictionary:
	if source_index < 0 or source_index >= _active_node_count():
		return {"hp_gain": 0, "posture_gain": 0, "martial_gain": 0, "heal_full": false}
	var node: Dictionary = _node_data_at(source_index)
	var encounter_id := str(node.get("combat", ""))
	if has_method("_formal_reward_for_encounter"):
		return _formal_reward_for_encounter(encounter_id, str(node.get("type", "")))
	return {"hp_gain": 0, "posture_gain": 0, "martial_gain": 0, "heal_full": true}

func _apply_battle_result_reward(source_index: int) -> void:
	_apply_canonical_effects(_battle_reward_for_source(source_index))
	var growth := _battle_growth_reward_for_source(source_index)
	NarrativeBattleContext.apply_player_growth(
		"battle_win",
		int(growth.get("hp_gain", 0)),
		int(growth.get("posture_gain", 0)),
		int(growth.get("martial_gain", 0)),
		bool(growth.get("heal_full", true))
	)

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
		_save_narrative_state_to_context()
		return
	for i in range(_active_node_count()):
		if _node_id_at(i) == source_id:
			node_index = i
			in_prologue = false
			break
	if result == "win":
		var growth := _battle_growth_reward_for_source(node_index)
		_apply_battle_result_reward(node_index)
		if node_index < _active_node_count() - 1:
			node_index += 1
			node_sentence_index = 0
		last_hint = str(growth.get("reward_text", "战斗胜利：已返回剧情，并自动推进到下一节点。"))
	elif result == "lose":
		last_hint = "战斗失败：已返回剧情。当前暂不扣除资源，可重试或视为胜利继续。"
	elif result == "draw":
		last_hint = "战斗同归于尽：已返回剧情。线索保留，暂不推进。"
	else:
		last_hint = "战斗结果未知：已返回剧情。"
	NarrativeBattleContext.clear()
	_save_narrative_state_to_context()

func _render_node() -> void:
	var node: Dictionary = _node_data_at(node_index)
	title_label.text = str(node.get("title", ""))
	status_label.text = "%s / %s" % [str(node.get("column", "")), str(node.get("type", ""))]
	map_label.text = ""
	scene_label.text = _format_scene_text(str(node.get("scene", "")))
	_render_visual(str(node.get("visual_path", "")), str(node.get("scene", "")))
	body_label.text = _current_node_story_text(node)
	if not last_hint.is_empty() and _is_node_story_complete(node):
		body_label.text += "\n\n[i]%s[/i]" % _fragmented_hint(last_hint)
	vars_label.text = _vars_text()
	_add_safe_map_buttons()
	if not _is_node_story_complete(node):
		_add_placeholder(combat_buttons_box, "")
		_add_button(choices_box, "继续", _on_continue_node_sentence)
		return
	if _node_has_combat_data(node):
		_add_button(combat_buttons_box, _combat_button_text(node), _on_request_battle)
		_add_button(combat_buttons_box, _combat_mock_button_text(node), _on_mock_battle_win)
	else:
		_add_placeholder(combat_buttons_box, "")
	var choices := _configured_choices_for_node(str(node.get("id", "")))
	for i in range(choices.size()):
		var choice: Dictionary = choices[i] if choices[i] is Dictionary else {}
		_add_choice_button(choice, i)

func _on_request_battle() -> void:
	var node: Dictionary = _node_data_at(node_index)
	var node_id: String = str(node.get("id", ""))
	var combat = node.get("combat", {})
	if combat is Dictionary and bool((combat as Dictionary).get("enabled", false)):
		NarrativeBattleContext.set_request_from_combat(combat as Dictionary, node_id)
		get_tree().change_scene_to_file("res://scenes/MainVisual.tscn")
		return
	super._on_request_battle()

func _on_mock_battle_win() -> void:
	var node: Dictionary = _node_data_at(node_index)
	node_sentence_index = _node_story_segments(node).size() - 1
	body_label.text = _current_node_story_text(node) + "\n\n[b]战斗占位胜利[/b]\n现在可选择战后处理。"
	BattleFontHelper.enforce(self)

func _current_node_id() -> String:
	if in_prologue:
		return "prologue"
	return _node_id_at(node_index)

func _current_world_map_title() -> String:
	var node: Dictionary = _node_data_at(node_index)
	return str(node.get("title", ""))

func _vars_text() -> String:
	return "军功 %d / 清望 %d / 旧案线索 %d" % [jun_gong, qing_wang, clues]

func _map_text() -> String:
	var lines: Array[String] = []
	for col in MAP_COLUMNS:
		var items: Array[String] = []
		for i in range(_active_node_count()):
			var n: Dictionary = _node_data_at(i)
			if str(n.get("column", "")) == col:
				items.append("%s %s" % [_map_marker_for_index(i), str(n.get("title", ""))])
		lines.append("【%s】%s" % [col, " / ".join(items)])
	return "\n".join(lines)

func _add_safe_map_buttons() -> void:
	var column_row := HBoxContainer.new()
	column_row.add_theme_constant_override("separation", 8)
	map_buttons_box.add_child(column_row)
	for column_name in MAP_COLUMNS:
		var column_box := VBoxContainer.new()
		column_box.custom_minimum_size = Vector2(142, 0)
		column_box.add_theme_constant_override("separation", 4)
		column_row.add_child(column_box)
		var title := Label.new()
		title.text = column_name
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.add_theme_font_size_override("font_size", 13)
		column_box.add_child(title)
		for i in range(_active_node_count()):
			var node: Dictionary = _node_data_at(i)
			if str(node.get("column", "")) == column_name:
				var btn := Button.new()
				btn.text = "%s %s" % [_map_marker_for_index(i), str(node.get("title", ""))]
				btn.custom_minimum_size = Vector2(136, 38)
				btn.pressed.connect(_on_map_node_pressed.bind(i))
				column_box.add_child(btn)

func _refresh_world_map() -> void:
	if world_map_layer == null or world_map_panel == null or world_map_nodes_row == null:
		return
	world_map_panel.visible = not in_prologue
	if in_prologue:
		return
	if world_map_status_label != null:
		world_map_status_label.text = "海疆行军图｜当前：%s｜军功 %d｜清望 %d｜旧案 %d" % [_current_world_map_title(), jun_gong, qing_wang, clues]
	for child: Node in world_map_nodes_row.get_children():
		child.queue_free()
	for i in range(_active_node_count()):
		if i > 0:
			world_map_nodes_row.add_child(_make_world_map_line(i))
		world_map_nodes_row.add_child(_make_world_map_node_button(i))

func _make_world_map_line(index: int) -> Label:
	var line := Label.new()
	line.text = "━━"
	line.custom_minimum_size = Vector2(24, 34)
	line.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	line.add_theme_font_size_override("font_size", 13)
	line.add_theme_color_override("font_color", Color("c9a35b") if index <= node_index else Color(0.60, 0.55, 0.46, 0.45))
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return line

func _make_world_map_node_button(index: int) -> Button:
	var node: Dictionary = _node_data_at(index)
	var btn := Button.new()
	btn.text = "%s\n%s" % [_world_map_marker_for_index(index), str(node.get("title", ""))]
	btn.custom_minimum_size = Vector2(116, 48)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.focus_mode = Control.FOCUS_NONE
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	btn.disabled = index > node_index + 1
	btn.pressed.connect(_on_map_node_pressed.bind(index))
	return btn

func _on_map_node_pressed(target_index: int) -> void:
	if target_index == node_index:
		last_hint = "地图节点：当前节点。"
	elif target_index < node_index:
		last_hint = "地图节点：已走过。"
	elif target_index != node_index + 1:
		last_hint = "地图节点：未开放。"
	else:
		_apply_default_map_reward(target_index)
		_advance_to_node(target_index, "地图节点：可前往，已通过地图选路推进，并获得默认行军收益。")
		return
	_render()

func _apply_default_map_reward(target_index: int) -> void:
	if target_index < 0 or target_index >= _active_node_count():
		return
	var node: Dictionary = _node_data_at(target_index)
	match str(node.get("type", "")):
		"普通战斗", "精英战斗":
			jun_gong += 1
			clues += 1
		"Boss":
			jun_gong += 2
			clues += 1
		"旧物":
			clues += 2
		_:
			qing_wang += 1

func _advance_to_node(target_index: int, hint: String = "") -> void:
	last_hint = hint
	node_sentence_index = 0
	if target_index >= _active_node_count():
		_render_ending()
		return
	node_index = target_index
	_save_narrative_state_to_context()
	_render()

func _ending_data() -> Dictionary:
	var flagged_ending := _ending_data_for_flag(selected_ending_flag)
	if not flagged_ending.is_empty():
		return flagged_ending
	if clues >= 4:
		return {
			"id": "private_investigation",
			"title": "结局：旧案浮起",
			"status": "旧案浮起",
			"text": "你藏下一份证据。\n\n纸很薄。\n\n却压得甲很沉。\n\n师父说：不要再问。\n\n你第一次没有听。",
			"feedback": "你接近了真相，但军门与师父都开始变得沉默。"
		}
	if jun_gong >= 4 and clues < 4:
		return {
			"id": "merit_cover",
			"title": "结局：军功入册",
			"status": "军功入册",
			"text": "捷报写得很好。\n\n首级数得很准。\n\n案卷少了一页。\n\n你升了一级。",
			"feedback": "你立下了功名，但旧案从案卷里退后了一步。"
		}
	if qing_wang >= 4 and clues < 4:
		return {
			"id": "truth_report",
			"title": "结局：清名在外",
			"status": "清名在外",
			"text": "百姓记得你救过人。\n\n军门记得你误过令。\n\n师父说：好名声也会杀人。\n\n潮声没有回答。",
			"feedback": "你保住了道义，却还没有把真相从潮声里拉出来。"
		}
	return {
		"id": "silence",
		"title": "结局：沉默退下",
		"status": "沉默退下",
		"text": "门关上。\n\n灯还亮着。\n\n案卷少了一页。\n\n你什么都没有说。\n\n潮声替你说了一夜。",
		"feedback": "你没有站上任何一边，悬念被保留下来。"
	}

func _ending_data_for_flag(flag: String) -> Dictionary:
	match flag:
		"truth_report":
			return {
				"id": "truth_report",
				"title": "结局：据实上报",
				"status": "据实上报",
				"text": "你把话说完。\n\n屋里安静了很久。\n\n案卷没有立刻合上。\n\n潮声从门外涌进来。",
				"feedback": "你选择把真相放到军门案上，清望与旧案线索会成为你的支撑。"
			}
		"private_investigation":
			return {
				"id": "private_investigation",
				"title": "结局：藏证私查",
				"status": "藏证私查",
				"text": "袖中有纸。\n\n心里有潮。\n\n你退下时没有回头。\n\n旧案从此不只在案卷里。",
				"feedback": "你留下了继续追查的火种，但军门与师父都会更沉默。"
			}
		"merit_cover":
			return {
				"id": "merit_cover",
				"title": "结局：借功压案",
				"status": "借功压案",
				"text": "你把首级摆出来。\n\n没人再问箱子。\n\n捷报写得顺。\n\n顺得不像真的。",
				"feedback": "你用军功换来当下的通行，但旧案被压回潮声下面。"
			}
		"silence":
			return {
				"id": "silence",
				"title": "结局：沉默退下",
				"status": "沉默退下",
				"text": "门关上。\n\n灯还亮着。\n\n师父还站在外面。\n\n你什么都没有说。",
				"feedback": "你没有站上任何一边，悬念被保留下来。"
			}
	return {}

func _ending_catalog() -> Array[Dictionary]:
	var catalog: Array[Dictionary] = []
	var final_node := _node_config("military_coverup")
	var choices = final_node.get("choices", [])
	if choices is Array:
		for choice_variant in choices:
			if not (choice_variant is Dictionary):
				continue
			var choice := choice_variant as Dictionary
			var flag := str(choice.get("ending_flag", "")).strip_edges()
			var effects = choice.get("effects", {})
			if flag.is_empty() and effects is Dictionary:
				flag = str((effects as Dictionary).get("ending_flag", "")).strip_edges()
			if flag.is_empty():
				continue
			var ending := _ending_data_for_flag(flag)
			if ending.is_empty():
				ending = {
					"id": flag,
					"title": "结局：%s" % str(choice.get("label", flag)),
					"status": str(choice.get("label", flag)),
					"text": str(choice.get("result", "")),
					"feedback": ""
				}
			catalog.append(ending)
	if catalog.is_empty():
		for flag in ["truth_report", "private_investigation", "merit_cover", "silence"]:
			catalog.append(_ending_data_for_flag(flag))
	return catalog

func _render_ending() -> void:
	var ending := _ending_data()
	title_label.text = str(ending.get("title", "结局"))
	status_label.text = str(ending.get("status", "单局结算"))
	map_label.text = _map_text()
	scene_label.text = _format_scene_text("第一幕结局：变量评价已生效。")
	_render_visual("", "第一幕结局：变量评价已生效。")
	body_label.text = "%s\n\n[b]评价[/b]\n%s\n\n军功 %d / 清望 %d / 旧案线索 %d" % [
		str(ending.get("text", "")),
		str(ending.get("feedback", "")),
		jun_gong,
		qing_wang,
		clues
	]
	vars_label.text = _vars_text()
	_clear_dynamic_boxes()
	_add_placeholder(map_buttons_box, "单局已结束。")
	_add_placeholder(combat_buttons_box, "结局阶段无战斗。")
	_add_button(choices_box, "重开叙事", _restart)
	BattleFontHelper.enforce(self)

func _restart() -> void:
	step_index = 0
	node_index = 0
	node_sentence_index = 0
	selected_ending_flag = ""
	jun_gong = 0
	qing_wang = 0
	clues = 0
	rival_gu_bond = 0
	rival_shen_bond = 0
	rival_qi_bond = 0
	in_prologue = true
	career_selected = false
	last_hint = ""
	NarrativeBattleContext.clear()
	NarrativeBattleContext.clear_player_profile()
	_clear_narrative_state_context()
	_render()
