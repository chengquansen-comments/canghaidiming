extends RefCounted

const StrategicNetworkMapRuntime := preload("res://scripts/strategic_network_map_runtime.gd")
const StrategicNetworkBattleBridge := preload("res://scripts/strategic_network_battle_bridge.gd")
const StrategicNetworkMapConfirm := preload("res://scripts/strategic_network_map_confirm.gd")
const StrategicNetworkMapBattleResult := preload("res://scripts/strategic_network_map_battle_result.gd")
const NetworkMapGenerator := preload("res://scripts/strategic_network_map_generator.gd")
const AigcDungeonBigMapLoader := preload("res://scripts/aigc_dungeon_big_map_loader.gd")
const NarrativeBattleContext := preload("res://scripts/narrative_battle_context.gd")

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
	StrategicNetworkMapRuntime.refresh_node_states(graph)
	c._sync_network_state_from_graph(graph)
	var result_text := str(node.get("result_text", ""))
	if result_text.is_empty():
		result_text = "你记下了这一处海疆线索。"
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
