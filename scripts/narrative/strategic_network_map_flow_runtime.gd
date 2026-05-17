extends RefCounted

const StrategicNetworkMapRuntime := preload("res://scripts/strategic_network_map_runtime.gd")
const StrategicNetworkBattleBridge := preload("res://scripts/strategic_network_battle_bridge.gd")
const StrategicNetworkMapConfirm := preload("res://scripts/strategic_network_map_confirm.gd")
const StrategicNetworkMapBattleResult := preload("res://scripts/strategic_network_map_battle_result.gd")
const NetworkMapGenerator := preload("res://scripts/strategic_network_map_generator.gd")
const AigcDungeonBigMapLoader := preload("res://scripts/aigc_dungeon_big_map_loader.gd")
const AigcDungeonRouteBranchEvaluator := preload("res://scripts/aigc_dungeon_route_branch_evaluator.gd")
const AigcDungeonFormalSaveSlotStore := preload("res://scripts/aigc_dungeon_formal_save_slot_store.gd")
const NarrativeBattleContext := preload("res://scripts/narrative_battle_context.gd")
const StrategicMapWukeGuard := preload("res://scripts/strategic_map_wuke_guard.gd")

static func on_network_node_clicked(c, map_graph_id: String) -> void:
	var graph_variant = c.strategic_state.get("network_map", {})
	if not (graph_variant is Dictionary):
		return
	var graph := graph_variant as Dictionary
	if graph.is_empty():
		return
	graph["selected_node_id"] = map_graph_id
	c._sync_network_state_from_graph(graph)
	c._save_narrative_state_to_context()
	c._render()

static func confirm_network_node(c) -> void:
	var graph: Dictionary = c.strategic_state.get("network_map", {}) as Dictionary
	if graph.is_empty():
		return
	var selected_id := str(graph.get("selected_node_id", ""))
	var node := StrategicNetworkMapRuntime.find_node(graph, selected_id)
	if node.is_empty():
		c.last_hint = "未选中有效的大势图节点。"
		c._render()
		return
	if not StrategicNetworkMapConfirm.selected_can_confirm(graph):
		c.last_hint = StrategicNetworkMapConfirm.block_reason(node)
		c._render()
		return
	if StrategicNetworkBattleBridge.is_combat_node(node):
		c._enter_network_combat_node(node)
		return
	c._execute_network_non_combat_node(node)

static func execute_network_non_combat_node(c, node: Dictionary) -> void:
	var graph: Dictionary = c.strategic_state.get("network_map", {}) as Dictionary
	if graph.is_empty():
		return
	c._apply_strategic_node(StrategicNetworkMapRuntime.runtime_node_for_effects(node))
	StrategicNetworkMapRuntime.complete_node(graph, node)
	if AigcDungeonRouteBranchEvaluator.is_branch_gate_node(node):
		var branch_result: Dictionary = AigcDungeonRouteBranchEvaluator.evaluate_route_branch(c.strategic_state, c.strategic_state.get("dungeon_route_rules", {}), node, graph)
		AigcDungeonRouteBranchEvaluator.apply_branch_result(graph, c.strategic_state, branch_result, node)
	elif AigcDungeonRouteBranchEvaluator.is_route_branch_node(node):
		AigcDungeonRouteBranchEvaluator.apply_selected_route_choice(graph, c.strategic_state, node)
	StrategicNetworkMapRuntime.refresh_node_states(graph)
	c._sync_network_state_from_graph(graph)
	var result_text := str(node.get("result_text", ""))
	if result_text.is_empty():
		result_text = "你记下了这一处海疆线索。"
	if AigcDungeonRouteBranchEvaluator.is_branch_gate_node(node):
		var available_routes: Array = c.strategic_state.get("available_ending_routes", [])
		var route_flags: Dictionary = c.strategic_state.get("route_flags", {})
		result_text = "终路已显：%s｜player_choice_required=%s" % [
			",".join(available_routes),
			str(route_flags.get("player_choice_required", false)),
		]
	elif AigcDungeonRouteBranchEvaluator.is_route_branch_node(node):
		result_text = "路线已定：%s" % str(c.strategic_state.get("selected_ending_route", ""))
	c.last_hint = result_text
	c._save_narrative_state_to_context()
	c._render()

static func enter_network_combat_node(c, node: Dictionary) -> void:
	var graph: Dictionary = c.strategic_state.get("network_map", {}) as Dictionary
	if graph.is_empty():
		return
	var request := StrategicNetworkBattleBridge.combat_request_for_node(node)
	if not bool(request.get("enabled", false)):
		c.last_hint = str(request.get("blocked_reason", "该战斗节点暂未接入。"))
		c._save_narrative_state_to_context()
		c._render()
		return
	var node_id := str(node.get("map_graph_id", ""))
	graph["pending_map_node_id"] = node_id
	graph["pending_result_text"] = str(node.get("result_text", ""))
	graph["pending_effects"] = (node.get("effects", {}) as Dictionary).duplicate(true)
	c._sync_network_state_from_graph(graph)
	c._sync_strategic_cards_to_context()
	c._save_narrative_state_to_context()
	NarrativeBattleContext.set_request_from_combat(request, "map_" + node_id)
	c.get_tree().change_scene_to_file("res://scenes/MainVisual.tscn")

static func consume_network_node_battle(c, source_id: String, result: String) -> void:
	var graph: Dictionary = c.strategic_state.get("network_map", {}) as Dictionary
	var outcome := StrategicNetworkMapBattleResult.consume_battle_result(graph, source_id, result)
	if bool(outcome.get("source_mismatch", false)):
		push_warning("Network map battle source mismatch: expected %s, got %s" % [str(outcome.get("expected_source_id", "")), source_id])
	c.last_hint = str(outcome.get("last_hint", ""))
	var node: Dictionary = outcome.get("node", {}) as Dictionary
	if bool(outcome.get("completed", false)) and not node.is_empty():
		c._apply_strategic_node(StrategicNetworkMapRuntime.runtime_node_for_effects(node))
		NarrativeBattleContext.apply_player_growth("battle_win", 0, 0, 0, true)
		_apply_route_ending_if_needed(c, graph, node)
	if bool(outcome.get("mutated", false)):
		c._sync_network_state_from_graph(graph)

static func on_network_final_boss_pressed(c) -> void:
	var graph: Dictionary = c.strategic_state.get("network_map", {}) as Dictionary
	if graph.is_empty():
		c.last_hint = "终局门未开启：未找到海疆大势图。"
		c._render()
		return
	c.strategic_state["final_gate_active"] = true
	c.strategic_state["final_boss"] = {
		"title": "海门收束",
		"encounter_id": c.NETWORK_FINAL_BOSS_ENCOUNTER_ID,
		"battle_id": c.NETWORK_FINAL_BOSS_BATTLE_ID,
		"ending_flag": "surface_pirate",
	}
	var request := StrategicNetworkBattleBridge.final_boss_request(c.NETWORK_FINAL_BOSS_ENCOUNTER_ID, c.NETWORK_FINAL_BOSS_BATTLE_ID)
	if not bool(request.get("enabled", false)):
		c.last_hint = str(request.get("blocked_reason", "终局战暂未接入。"))
		c._save_narrative_state_to_context()
		c._render()
		return
	c._sync_strategic_cards_to_context()
	c._save_narrative_state_to_context()
	NarrativeBattleContext.set_request_from_combat(request, c.STRATEGIC_FINAL_BOSS_SOURCE_ID)
	c.get_tree().change_scene_to_file("res://scenes/MainVisual.tscn")

static func ensure_network_map_for_state(c, warn_if_regenerated: bool = false) -> void:
	var map_variant = c.strategic_state.get("network_map", {})
	if map_variant is Dictionary and not (map_variant as Dictionary).is_empty():
		var graph := map_variant as Dictionary
		var removed_count := StrategicMapWukeGuard.sanitize_network_graph(graph)
		if removed_count > 0:
			StrategicNetworkMapRuntime.ensure_selected_node(graph)
			StrategicNetworkMapRuntime.refresh_node_states(graph)
			if c.has_method("_sync_network_state_from_graph"):
				c._sync_network_state_from_graph(graph)
			else:
				StrategicNetworkMapRuntime.sync_mirror_fields(c.strategic_state, graph)
			if c.has_method("_save_narrative_state_to_context"):
				c._save_narrative_state_to_context()
			push_warning("network_map restored with Wuke nodes; removed %d before render." % removed_count)
		return
	if AigcDungeonBigMapLoader.has_compatible_map_file():
		var bundle := AigcDungeonBigMapLoader.load_runtime_bundle()
		if not bool(bundle.get("ok", false)):
			var error_text := "AIGC dungeon map load failed: %s" % str(bundle.get("error", "unknown"))
			if bundle.has("details"):
				error_text += "｜%s" % ",".join(bundle.get("details", []))
			c.last_hint = error_text
			push_error(error_text)
			return
		AigcDungeonBigMapLoader.apply_bundle_to_state(c.strategic_state, bundle)
		return
	var seed_value := int(c.strategic_state.get("seed", 1701))
	if warn_if_regenerated:
		push_warning("strategic_state.network_map missing during restore, regenerating from seed=%d" % seed_value)
	var network_map: Dictionary = NetworkMapGenerator.generate_network_map(c.strategic_config, c.strategic_state, seed_value)
	c._sync_network_state_from_graph(network_map)
	print(NetworkMapGenerator.summarize_network_map(network_map))

static func save_dungeon_route_slot(c, slot_id: String = "slot_001") -> Dictionary:
	ensure_network_map_for_state(c)
	var graph: Dictionary = c.strategic_state.get("network_map", {}) as Dictionary
	if graph.is_empty():
		return {
			"ok": false,
			"error": "network_map_missing",
		}
	if not AigcDungeonBigMapLoader.is_dungeon_profile_active():
		return {
			"ok": false,
			"error": "dungeon_profile_not_active",
		}
	var metadata := {
		"map_instance_id": str(graph.get("map_instance_id", "")),
		"content_pool_pack_id": "dungeon_pool_pack_001",
		"progression_template_id": "dungeon_progression_v1_3",
		"seed": int(graph.get("seed", 0)),
	}
	var result := AigcDungeonFormalSaveSlotStore.save_slot(slot_id, c.strategic_state, graph, metadata)
	if bool(result.get("ok", false)):
		c.last_hint = "已保存副本路线：%s" % str(result.get("slot_id", slot_id))
	else:
		c.last_hint = "副本路线保存失败：%s" % str(result.get("error", result.get("errors", [])))
	c._save_narrative_state_to_context()
	c._render()
	return result

static func restore_dungeon_route_slot(c, slot_id: String = "slot_001") -> Dictionary:
	ensure_network_map_for_state(c)
	var graph: Dictionary = c.strategic_state.get("network_map", {}) as Dictionary
	if graph.is_empty():
		return {
			"ok": false,
			"error": "network_map_missing",
		}
	if not AigcDungeonBigMapLoader.is_dungeon_profile_active():
		return {
			"ok": false,
			"error": "dungeon_profile_not_active",
		}
	var restore_result := AigcDungeonFormalSaveSlotStore.restore_slot(slot_id, graph)
	if not bool(restore_result.get("ok", false)):
		c.last_hint = "副本路线读取失败：%s" % str(restore_result.get("errors", []))
		c._render()
		return restore_result
	var route_state := restore_result.get("route_state", {}) as Dictionary
	AigcDungeonBigMapLoader.apply_route_state_to_graph(graph, route_state)
	var valid_available := StrategicNetworkMapRuntime.valid_available_ids(graph, graph.get("available_node_ids", []))
	if valid_available.is_empty() or str(graph.get("selected_node_id", "")) == str(graph.get("current_node_id", "")):
		var current_node := StrategicNetworkMapRuntime.find_node(graph, str(graph.get("current_node_id", "")))
		var by_id := StrategicNetworkMapRuntime.node_by_id(graph)
		var completed: Array = graph.get("completed_node_ids", [])
		var outgoing: Array = []
		for item in current_node.get("outgoing", []):
			var node_id := str(item)
			if not node_id.is_empty() and by_id.has(node_id) and not completed.has(node_id):
				outgoing.append(node_id)
		graph["available_node_ids"] = outgoing
		StrategicNetworkMapRuntime.refresh_node_states(graph)
	else:
		graph["available_node_ids"] = valid_available
	StrategicNetworkMapRuntime.ensure_selected_node(graph)
	c._sync_network_state_from_graph(graph)
	c.last_hint = "已恢复副本路线：%s" % slot_id
	c._save_narrative_state_to_context()
	c._render()
	return {
		"ok": true,
		"slot_id": slot_id,
		"route_state": route_state,
	}

static func _apply_route_ending_if_needed(c, graph: Dictionary, node: Dictionary) -> bool:
	var ending_variant = node.get("ending_result", {})
	if not (ending_variant is Dictionary):
		return false
	var ending_result: Dictionary = (ending_variant as Dictionary).duplicate(true)
	if ending_result.is_empty() or not bool(ending_result.get("final_node", false)):
		return false
	var node_id := str(node.get("map_graph_id", ""))
	var route := str(ending_result.get("route", graph.get("selected_ending_route", c.strategic_state.get("selected_ending_route", ""))))
	if route.is_empty():
		route = "normal"
	ending_result["route"] = route
	ending_result["source_node_id"] = node_id
	graph["ending_result"] = ending_result.duplicate(true)
	graph["selected_ending_route"] = route
	graph["route_choice_locked"] = true
	graph["route_complete"] = true
	graph["map_complete"] = true
	graph["available_node_ids"] = []
	graph["selected_node_id"] = node_id
	c.strategic_state["ending_result"] = ending_result.duplicate(true)
	c.strategic_state["selected_ending_route"] = route
	c.strategic_state["route_choice_locked"] = true
	c.strategic_state["route_complete"] = true
	c.strategic_state["active"] = false
	c.strategic_state["completed"] = true
	c.last_hint = str(ending_result.get("result_text", node.get("result_text", "路线已收束。")))
	return true
