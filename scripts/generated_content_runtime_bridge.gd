extends RefCounted
class_name GeneratedContentRuntimeBridge

const MANIFEST_PATH := "res://data/runtime/content_engine_whitelist/full_content_bridge_manifest.json"
const BUNDLE_PATH_PATTERN := "res://data/runtime/content_engine_whitelist/%s.full_content_bridge.json"
const FALLBACK_POLICY := "legacy"


func load_manifest() -> Dictionary:
	if not FileAccess.file_exists(MANIFEST_PATH):
		return {}
	var f := FileAccess.open(MANIFEST_PATH, FileAccess.READ)
	if f == null:
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return parsed


func load_bundle(battle_slot_id: String) -> Dictionary:
	if battle_slot_id == "":
		return {}
	var path := BUNDLE_PATH_PATTERN % battle_slot_id
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return parsed


func get_domain(bundle: Dictionary, domain: String) -> Dictionary:
	if bundle.is_empty() or not bundle.has("domains"):
		return {}
	var domains: Variant = bundle.get("domains", {})
	if typeof(domains) != TYPE_DICTIONARY:
		return {}
	var map: Dictionary = domains
	var d: Variant = map.get(domain, {})
	return d if typeof(d) == TYPE_DICTIONARY else {}


func get_domain_count(bundle: Dictionary, domain: String) -> int:
	var d := get_domain(bundle, domain)
	if d.is_empty():
		return 0
	return int(d.get("candidate_count", 0))


func get_reward_candidate(bundle: Dictionary) -> Dictionary:
	return get_domain(bundle, "reward")


func get_battle_slot_candidate(bundle: Dictionary) -> Dictionary:
	return get_domain(bundle, "battle_slot")


func get_enemy_deck_candidate(bundle: Dictionary) -> Dictionary:
	return get_domain(bundle, "enemy_deck")


func get_card_pool_candidates(bundle: Dictionary) -> Dictionary:
	return get_domain(bundle, "card_pool")


func get_operation_node_candidates(bundle: Dictionary) -> Dictionary:
	return get_domain(bundle, "operation_node")


func get_narrative_candidates(bundle: Dictionary) -> Dictionary:
	return get_domain(bundle, "narrative")


func get_route_gate_candidates(bundle: Dictionary) -> Dictionary:
	return get_domain(bundle, "route_gate")


func validate_bridge_bundle(bundle: Dictionary) -> Dictionary:
	if bundle.is_empty():
		return {"ok": false, "error": "bundle_empty", "fallback_policy": FALLBACK_POLICY}
	if str(bundle.get("rollback_policy", "")) != FALLBACK_POLICY:
		return {"ok": false, "error": "rollback_policy_invalid", "fallback_policy": FALLBACK_POLICY}
	if bool(bundle.get("global_content_engine_enabled", true)):
		return {"ok": false, "error": "global_content_engine_enabled_true", "fallback_policy": FALLBACK_POLICY}
	if bool(bundle.get("formal_runtime_enabled", true)):
		return {"ok": false, "error": "formal_runtime_enabled_true", "fallback_policy": FALLBACK_POLICY}
	if bool(bundle.get("runtime_ready", true)):
		return {"ok": false, "error": "runtime_ready_true", "fallback_policy": FALLBACK_POLICY}
	if not bool(bundle.get("bridge_only", false)):
		return {"ok": false, "error": "bridge_only_false", "fallback_policy": FALLBACK_POLICY}
	return {"ok": true, "error": "", "fallback_policy": FALLBACK_POLICY}
