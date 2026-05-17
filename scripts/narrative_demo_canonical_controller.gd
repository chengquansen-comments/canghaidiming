extends "res://scripts/narrative_demo_fragmented_controller.gd"

const CanonicalEffectsRuntime := preload("res://scripts/narrative/canonical_effects_runtime.gd")
const CanonicalNodeRegistry := preload("res://scripts/narrative/canonical_node_registry.gd")
const CanonicalStorySegmentRuntime := preload("res://scripts/narrative/canonical_story_segment_runtime.gd")
const CanonicalEndingRuntime := preload("res://scripts/narrative/canonical_ending_runtime.gd")
const CanonicalBattleRewardRuntime := preload("res://scripts/narrative/canonical_battle_reward_runtime.gd")
const CanonicalMapRuntime := preload("res://scripts/narrative/canonical_map_runtime.gd")
const CanonicalMapViewRuntime := preload("res://scripts/narrative/canonical_map_view_runtime.gd")

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
var wuke_story_state: Dictionary = CanonicalEffectsRuntime.strategic_story_state_defaults()

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
	for key in wuke_story_state.keys():
		base_state[str(key)] = wuke_story_state.get(key)
	return base_state

func _restore_narrative_state_from_context() -> void:
	super._restore_narrative_state_from_context()
	if not NarrativeBattleContext.has_narrative_state():
		return
	var state: Dictionary = NarrativeBattleContext.get_narrative_state()
	rival_gu_bond = int(state.get(VAR_RIVAL_GU_BOND, rival_gu_bond))
	rival_shen_bond = int(state.get(VAR_RIVAL_SHEN_BOND, rival_shen_bond))
	rival_qi_bond = int(state.get(VAR_RIVAL_QI_BOND, rival_qi_bond))
	_restore_wuke_story_state(state)

func _canonical_state() -> Dictionary:
	return CanonicalEffectsRuntime.canonical_state(
		jun_gong,
		qing_wang,
		clues,
		rival_gu_bond,
		rival_shen_bond,
		rival_qi_bond,
		wuke_story_state
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
	_apply_wuke_story_values(values)
	_save_narrative_state_to_context()

func _restore_wuke_story_state(state: Dictionary) -> void:
	for key in CanonicalEffectsRuntime.strategic_story_state_defaults().keys():
		var field := str(key)
		if field in CanonicalEffectsRuntime.story_boolean_fields():
			wuke_story_state[field] = bool(state.get(field, wuke_story_state.get(field, false)))
		else:
			wuke_story_state[field] = int(state.get(field, wuke_story_state.get(field, 0)))

func _apply_wuke_story_values(values: Dictionary) -> void:
	for key in wuke_story_state.keys():
		var field := str(key)
		if field in CanonicalEffectsRuntime.story_boolean_fields():
			wuke_story_state[field] = bool(values.get(field, wuke_story_state.get(field, false)))
		else:
			wuke_story_state[field] = int(values.get(field, wuke_story_state.get(field, 0)))

func _story_route_state() -> Dictionary:
	return wuke_story_state.duplicate(true)

func _record_choice_ending_flag(choice: Dictionary) -> void:
	var flag := CanonicalEndingRuntime.ending_flag_from_choice(choice)
	if not flag.is_empty():
		selected_ending_flag = flag

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
	var normalized_context_reward: Dictionary = {}
	if context_reward is Dictionary:
		normalized_context_reward = context_reward as Dictionary

	var node: Dictionary = {}
	var formal_reward: Dictionary = {}
	if source_index >= 0 and source_index < _active_node_count():
		node = _node_data_at(source_index)
		var encounter_id := str(node.get("combat", ""))
		if has_method("_formal_reward_for_encounter"):
			formal_reward = _formal_reward_for_encounter(encounter_id, str(node.get("type", "")))

	return CanonicalBattleRewardRuntime.reward_from_context_or_node(
		normalized_context_reward,
		source_index,
		_active_node_count(),
		node,
		formal_reward
	)

func _battle_growth_reward_for_source(source_index: int) -> Dictionary:
	var formal_reward: Dictionary = {}
	if source_index >= 0 and source_index < _active_node_count():
		var node: Dictionary = _node_data_at(source_index)
		var encounter_id := str(node.get("combat", ""))
		if has_method("_formal_reward_for_encounter"):
			formal_reward = _formal_reward_for_encounter(encounter_id, str(node.get("type", "")))

	return CanonicalBattleRewardRuntime.growth_reward(
		source_index,
		_active_node_count(),
		formal_reward
	)

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
	return CanonicalMapRuntime.current_world_map_title(_node_data_at(node_index))

func _vars_text() -> String:
	return CanonicalMapRuntime.vars_text(jun_gong, qing_wang, clues)

func _map_marker_for_index(index: int) -> String:
	return CanonicalMapRuntime.map_marker_for_index(index, node_index)

func _map_text() -> String:
	var nodes: Array = []
	for i in range(_active_node_count()):
		nodes.append(_node_data_at(i))
	return CanonicalMapRuntime.map_text(MAP_COLUMNS, nodes, node_index)

func _add_safe_map_buttons() -> void:
	var nodes: Array = []
	for i in range(_active_node_count()):
		nodes.append(_node_data_at(i))
	CanonicalMapViewRuntime.add_safe_map_buttons(
		map_buttons_box,
		MAP_COLUMNS,
		nodes,
		node_index,
		_on_map_node_pressed
	)

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
	return CanonicalMapViewRuntime.make_world_map_line(index, node_index)

func _make_world_map_node_button(index: int) -> Button:
	return CanonicalMapViewRuntime.make_world_map_node_button(
		index,
		_node_data_at(index),
		node_index,
		_on_map_node_pressed
	)

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
	_apply_canonical_effects(CanonicalMapRuntime.default_map_reward_for_node(_node_data_at(target_index)))

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
	return CanonicalEndingRuntime.ending_data(selected_ending_flag, jun_gong, qing_wang, clues)

func _ending_data_for_flag(flag: String) -> Dictionary:
	return CanonicalEndingRuntime.ending_data_for_flag(flag)

func _ending_catalog() -> Array[Dictionary]:
	return CanonicalEndingRuntime.ending_catalog(_node_config("military_coverup"))

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
	wuke_story_state = CanonicalEffectsRuntime.strategic_story_state_defaults()
	in_prologue = true
	career_selected = false
	last_hint = ""
	NarrativeBattleContext.clear()
	NarrativeBattleContext.clear_player_profile()
	_clear_narrative_state_context()
	_render()
