extends RefCounted

const SaveBridge := preload("res://scripts/aigc_dungeon_save_bridge.gd")

const STORE_SCHEMA_VERSION := "aigc_dungeon_formal_save_slot_store_v0_1"
const DEFAULT_SLOT_ID := "slot_001"
const DEFAULT_SLOT_DIR := "user://aigc_dungeon/save_slots"


static func save_slot(slot_id: String, route_state: Dictionary, network_map: Dictionary, metadata: Dictionary = {}) -> Dictionary:
	var clean_slot_id := _clean_slot_id(slot_id)
	var save_payload := SaveBridge.build_save_payload(route_state, network_map, metadata)
	var slot_payload := {
		"save_slot_schema_version": STORE_SCHEMA_VERSION,
		"slot_id": clean_slot_id,
		"slot_source": "aigc_dungeon_formal_save_slot_store",
		"saved_at_unix": Time.get_unix_time_from_system(),
		"aigc_save_payload": save_payload,
	}
	var validation := validate_slot_payload(slot_payload, network_map)
	if not bool(validation.get("ok", false)):
		return {
			"ok": false,
			"errors": validation.get("errors", []),
			"path": slot_path(clean_slot_id),
		}
	var write_result := SaveBridge.write_save_payload(slot_payload, slot_path(clean_slot_id))
	return {
		"ok": bool(write_result.get("ok", false)),
		"path": slot_path(clean_slot_id),
		"slot_id": clean_slot_id,
		"validation": validation,
		"error": str(write_result.get("error", "")),
	}


static func read_slot(slot_id: String) -> Dictionary:
	var clean_slot_id := _clean_slot_id(slot_id)
	var read_result := SaveBridge.read_save_payload(slot_path(clean_slot_id))
	if not bool(read_result.get("ok", false)):
		return read_result
	return {
		"ok": true,
		"path": slot_path(clean_slot_id),
		"slot_id": clean_slot_id,
		"slot_payload": (read_result.get("payload", {}) as Dictionary).duplicate(true),
	}


static func restore_slot(slot_id: String, network_map: Dictionary) -> Dictionary:
	var read_result := read_slot(slot_id)
	if not bool(read_result.get("ok", false)):
		return {
			"ok": false,
			"errors": [str(read_result.get("error", "read_failed"))],
			"route_state": {},
		}
	var slot_payload := read_result.get("slot_payload", {}) as Dictionary
	var validation := validate_slot_payload(slot_payload, network_map)
	if not bool(validation.get("ok", false)):
		return {
			"ok": false,
			"errors": validation.get("errors", []),
			"route_state": {},
		}
	var save_payload := slot_payload.get("aigc_save_payload", {}) as Dictionary
	return SaveBridge.restore_route_state_from_save(save_payload, network_map)


static func validate_slot_payload(slot_payload: Dictionary, network_map: Dictionary) -> Dictionary:
	var errors: Array[String] = []
	if str(slot_payload.get("save_slot_schema_version", "")) != STORE_SCHEMA_VERSION:
		errors.append("save_slot_schema_version_invalid")
	if str(slot_payload.get("slot_id", "")).is_empty():
		errors.append("slot_id_missing")
	var save_payload: Variant = slot_payload.get("aigc_save_payload", {})
	if not (save_payload is Dictionary):
		errors.append("aigc_save_payload_missing")
	else:
		var save_validation := SaveBridge.validate_save_payload(save_payload as Dictionary, network_map)
		if not bool(save_validation.get("ok", false)):
			for item in save_validation.get("errors", []):
				errors.append("aigc_save_payload:%s" % str(item))
	return {
		"ok": errors.is_empty(),
		"errors": errors,
	}


static func clear_slot(slot_id: String) -> Dictionary:
	var clean_slot_id := _clean_slot_id(slot_id)
	var path := ProjectSettings.globalize_path(slot_path(clean_slot_id))
	if FileAccess.file_exists(path):
		var result := DirAccess.remove_absolute(path)
		return {
			"ok": result == OK,
			"path": slot_path(clean_slot_id),
			"slot_id": clean_slot_id,
		}
	return {
		"ok": true,
		"path": slot_path(clean_slot_id),
		"slot_id": clean_slot_id,
	}


static func slot_path(slot_id: String = DEFAULT_SLOT_ID) -> String:
	return "%s/%s.json" % [DEFAULT_SLOT_DIR, _clean_slot_id(slot_id)]


static func _clean_slot_id(slot_id: String) -> String:
	var clean := slot_id.strip_edges()
	if clean.is_empty():
		return DEFAULT_SLOT_ID
	clean = clean.replace("/", "_").replace("\\", "_").replace("..", "_")
	return clean
