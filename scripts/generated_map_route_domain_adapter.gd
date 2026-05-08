extends RefCounted
class_name GeneratedMapRouteDomainAdapter

const BRIDGE := preload("res://scripts/generated_content_runtime_bridge.gd")
const BATTLE_SLOTS_PATH := "res://data/runtime_preview/content_engine/battle_slots.preview.json"
const OPERATION_NODES_PATH := "res://data/runtime_preview/content_engine/operation_nodes.preview.json"
const NARRATIVE_NODES_PATH := "res://data/runtime_preview/content_engine/narrative_nodes.preview.json"
const ROUTE_GATES_PATH := "res://data/runtime_preview/content_engine/route_gates.preview.json"
const FALLBACK_POLICY := "legacy"


func build_generated_map_route_candidate(battle_slot_id: String) -> Dictionary:
	if battle_slot_id == "" or not BRIDGE.new().is_enabled_for_battle_slot(battle_slot_id):
		return {
			"battle_slot_id": battle_slot_id,
			"enabled": false,
			"fallback_policy": FALLBACK_POLICY,
			"battle_slot": {},
			"operation_node": {},
			"narrative": {},
			"route_gate": {},
		}
	var bundle: Dictionary = BRIDGE.new().get_full_content_bundle_for_battle_slot(battle_slot_id)
	return {
		"battle_slot_id": battle_slot_id,
		"enabled": true,
		"fallback_policy": FALLBACK_POLICY,
		"battle_slot": get_battle_slot_for_battle_slot(battle_slot_id, bundle),
		"operation_node": get_operation_nodes_for_battle_slot(battle_slot_id, bundle),
		"narrative": get_narrative_keys_for_battle_slot(battle_slot_id, bundle),
		"route_gate": get_route_gates_for_battle_slot(battle_slot_id, bundle),
		"map_route_runtime_candidate": build_generated_map_route_runtime_candidate(battle_slot_id),
	}


func build_generated_map_route_runtime_candidate(battle_slot_id: String) -> Dictionary:
	if battle_slot_id == "" or not BRIDGE.new().is_enabled_for_battle_slot(battle_slot_id):
		return {
			"battle_slot_id": battle_slot_id,
			"map_route_candidate_available": false,
			"battle_slot_candidate_id": "",
			"operation_node_count": 0,
			"narrative_key_count": 0,
			"route_gate_count": 0,
			"narrative_keys_only": true,
			"route_gate_writes_formal_flow": false,
			"fallback_policy": FALLBACK_POLICY,
			"candidate_source": "legacy",
			"legacy_fallback_available": true,
		}
	var bundle: Dictionary = BRIDGE.new().get_full_content_bundle_for_battle_slot(battle_slot_id)
	var battle_slot := get_battle_slot_candidate(battle_slot_id, bundle)
	var operation_nodes := get_operation_node_candidates(battle_slot_id, bundle)
	var narrative := get_narrative_key_candidates(battle_slot_id, bundle)
	var route_gates := get_route_gate_candidates(battle_slot_id, bundle)
	var nv := validate_narrative_keys(narrative)
	var rv := validate_route_gate_candidates(route_gates)
	return {
		"battle_slot_id": battle_slot_id,
		"map_route_candidate_available": bool(battle_slot.get("candidate_available", false)) and bool(operation_nodes.get("candidate_available", false)) and bool(narrative.get("candidate_available", false)) and bool(route_gates.get("candidate_available", false)),
		"battle_slot_candidate_id": str(battle_slot.get("candidate_id", "")),
		"operation_node_count": int(operation_nodes.get("candidate_count", 0)),
		"narrative_key_count": int(narrative.get("candidate_count", 0)),
		"route_gate_count": int(route_gates.get("candidate_count", 0)),
		"narrative_keys_only": bool(nv.get("narrative_keys_only", false)),
		"route_gate_writes_formal_flow": bool(rv.get("route_gate_writes_formal_flow", true)),
		"fallback_policy": FALLBACK_POLICY,
		"candidate_source": "content_engine_candidate",
		"legacy_fallback_available": true,
	}


func get_battle_slot_candidate(battle_slot_id: String, bridge_bundle: Dictionary = {}) -> Dictionary:
	return get_battle_slot_for_battle_slot(battle_slot_id, bridge_bundle)


func get_operation_node_candidates(battle_slot_id: String, bridge_bundle: Dictionary = {}) -> Dictionary:
	return get_operation_nodes_for_battle_slot(battle_slot_id, bridge_bundle)


func get_narrative_key_candidates(battle_slot_id: String, bridge_bundle: Dictionary = {}) -> Dictionary:
	return get_narrative_keys_for_battle_slot(battle_slot_id, bridge_bundle)


func validate_narrative_keys(candidates: Dictionary) -> Dictionary:
	var keys := _arr(candidates.get("narrative_keys", []))
	var keys_only := true
	for item in keys:
		if typeof(item) != TYPE_DICTIONARY:
			keys_only = false
			break
		var row: Dictionary = item
		var hook_tags := str(row.get("hook_tags", ""))
		if hook_tags.length() > 120:
			keys_only = false
			break
	return {
		"narrative_keys_only": keys_only and bool(candidates.get("hook_only", false)),
	}


func get_route_gate_candidates(battle_slot_id: String, bridge_bundle: Dictionary = {}) -> Dictionary:
	return get_route_gates_for_battle_slot(battle_slot_id, bridge_bundle)


func validate_route_gate_candidates(candidates: Dictionary) -> Dictionary:
	return {
		"route_gate_writes_formal_flow": bool(candidates.get("writes_formal_flow", false)),
	}


func get_battle_slot_for_battle_slot(battle_slot_id: String, bridge_bundle: Dictionary = {}) -> Dictionary:
	if battle_slot_id == "" or not BRIDGE.new().is_enabled_for_battle_slot(battle_slot_id):
		return _legacy_row("battle_slot")
	var domains := _domains_from_bundle(battle_slot_id, bridge_bundle)
	var candidate: Dictionary = _dict(domains.get("battle_slot", {}))
	if not bool(candidate.get("candidate_available", false)):
		return _legacy_row("battle_slot_unavailable")
	var preview := _read_json_dict(BATTLE_SLOTS_PATH)
	for item in _arr(preview.get("battle_slots", [])):
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = item
		if str(row.get("battle_slot_id", "")) != battle_slot_id:
			continue
		return {
			"candidate_available": true,
			"candidate_id": battle_slot_id,
			"candidate_count": 1,
			"formal_source": "content_engine",
			"fallback_policy": FALLBACK_POLICY,
			"slot_meta": {
				"stage": str(row.get("stage", "")),
				"route_type": str(row.get("route_type", "")),
				"battle_type": str(row.get("battle_type", "")),
			},
			"writes_formal_flow": false,
			"notes": "battle_slot_candidate_readonly",
		}
	return _legacy_row("battle_slot_not_found")


func get_operation_nodes_for_battle_slot(battle_slot_id: String, bridge_bundle: Dictionary = {}) -> Dictionary:
	if battle_slot_id == "" or not BRIDGE.new().is_enabled_for_battle_slot(battle_slot_id):
		return _legacy_row("operation_node")
	var domains := _domains_from_bundle(battle_slot_id, bridge_bundle)
	var candidate: Dictionary = _dict(domains.get("operation_node", {}))
	if not bool(candidate.get("candidate_available", false)):
		return _legacy_row("operation_node_unavailable")
	var preview := _read_json_dict(OPERATION_NODES_PATH)
	var nodes := _arr(preview.get("operation_nodes", []))
	return {
		"candidate_available": true,
		"candidate_id": str(candidate.get("candidate_id", "operation_nodes_preview")),
		"candidate_count": nodes.size(),
		"formal_source": "content_engine_candidate",
		"fallback_policy": FALLBACK_POLICY,
		"writes_formal_flow": false,
		"notes": "operation_node_candidate_readonly",
	}


func get_narrative_keys_for_battle_slot(battle_slot_id: String, bridge_bundle: Dictionary = {}) -> Dictionary:
	if battle_slot_id == "" or not BRIDGE.new().is_enabled_for_battle_slot(battle_slot_id):
		return _legacy_row("narrative")
	var domains := _domains_from_bundle(battle_slot_id, bridge_bundle)
	var candidate: Dictionary = _dict(domains.get("narrative", {}))
	if not bool(candidate.get("candidate_available", false)):
		return _legacy_row("narrative_unavailable")
	var preview := _read_json_dict(NARRATIVE_NODES_PATH)
	var nodes := _arr(preview.get("narrative_nodes", []))
	var keys: Array = []
	for item in nodes:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = item
		keys.append({
			"narrative_node_id": str(row.get("narrative_node_id", "")),
			"source_id": str(row.get("source_id", "")),
			"hook_tags": str(row.get("hook_tags", "")),
			"trigger_stage": str(row.get("trigger_stage", "")),
		})
	return {
		"candidate_available": true,
		"candidate_id": str(candidate.get("candidate_id", "narrative_key_hook_preview")),
		"candidate_count": keys.size(),
		"formal_source": "content_engine_candidate",
		"fallback_policy": FALLBACK_POLICY,
		"hook_only": true,
		"narrative_keys": keys,
		"writes_formal_flow": false,
		"notes": "narrative_key_hook_only_no_body_text",
	}


func get_route_gates_for_battle_slot(battle_slot_id: String, bridge_bundle: Dictionary = {}) -> Dictionary:
	if battle_slot_id == "" or not BRIDGE.new().is_enabled_for_battle_slot(battle_slot_id):
		return _legacy_row("route_gate")
	var domains := _domains_from_bundle(battle_slot_id, bridge_bundle)
	var candidate: Dictionary = _dict(domains.get("route_gate", {}))
	if not bool(candidate.get("candidate_available", false)):
		return _legacy_row("route_gate_unavailable")
	var preview := _read_json_dict(ROUTE_GATES_PATH)
	var gates := _arr(preview.get("route_gates", []))
	return {
		"candidate_available": true,
		"candidate_id": str(candidate.get("candidate_id", "route_gates_preview")),
		"candidate_count": gates.size(),
		"formal_source": "content_engine_candidate",
		"fallback_policy": FALLBACK_POLICY,
		"writes_formal_flow": false,
		"notes": "route_gate_candidate_only_no_formal_routing_change",
	}


func _domains_from_bundle(battle_slot_id: String, bridge_bundle: Dictionary) -> Dictionary:
	var bundle := bridge_bundle
	if bundle.is_empty():
		bundle = BRIDGE.new().get_full_content_bundle_for_battle_slot(battle_slot_id)
	if bundle.is_empty():
		return {}
	return _dict(bundle.get("domains", {}))


func _legacy_row(reason: String) -> Dictionary:
	return {
		"candidate_available": false,
		"candidate_id": "",
		"candidate_count": 0,
		"formal_source": "legacy",
		"fallback_policy": FALLBACK_POLICY,
		"writes_formal_flow": false,
		"notes": "legacy_fallback_%s" % reason,
	}


func _read_json_dict(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


func _dict(v: Variant) -> Dictionary:
	return v if typeof(v) == TYPE_DICTIONARY else {}


func _arr(v: Variant) -> Array:
	return v if typeof(v) == TYPE_ARRAY else []
