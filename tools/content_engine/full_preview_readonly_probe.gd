extends SceneTree

const MANIFEST_PATH := "res://data/runtime_preview/content_engine/full_content_package.preview_manifest.json"
const OUT_PATH := "res://data/design/generated_full_preview_godot_readonly_report.tsv"

const DOMAINS := [
	{"name": "battle_rewards", "list_key": "rewards", "expected": 45},
	{"name": "battle_slots", "list_key": "battle_slots", "expected": 16},
	{"name": "enemy_decks", "list_key": "enemy_decks", "expected": 39},
	{"name": "card_pool", "list_key": "cards", "expected": 72},
	{"name": "operation_nodes", "list_key": "operation_nodes", "expected": 10},
	{"name": "narrative_nodes", "list_key": "narrative_nodes", "expected": 28},
	{"name": "route_gates", "list_key": "route_gates", "expected": 9},
]


func _initialize() -> void:
	var rows: Array = _run_probe()
	_write_tsv(rows)
	print("FULL_PREVIEW_GODOT_READONLY_PROBE_DONE")
	quit()


func _run_probe() -> Array:
	var rows: Array = []
	var manifest: Dictionary = _read_json(MANIFEST_PATH)
	if manifest.is_empty():
		rows.append(_row("manifest_load", "FAIL", "readable", "empty", "manifest 读取失败"))
		return rows

	rows.append(_row("manifest_runtime_ready", "PASS" if manifest.get("runtime_ready", true) == false else "FAIL", "false", str(manifest.get("runtime_ready", "unknown")).to_lower(), "manifest runtime_ready 必须 false"))
	rows.append(_row("manifest_preview_only", "PASS" if manifest.get("preview_only", false) == true else "FAIL", "true", str(manifest.get("preview_only", "unknown")).to_lower(), "manifest preview_only 必须 true"))
	rows.append(_row("selected_reward_policy", "PASS" if str(manifest.get("selected_reward_policy", "")) == "legacy" else "FAIL", "legacy", str(manifest.get("selected_reward_policy", "")), "selected_reward_policy 必须 legacy"))
	rows.append(_row("content_engine_enabled", "PASS" if bool(manifest.get("content_engine_enabled", false)) == false else "FAIL", "false", str(manifest.get("content_engine_enabled", "unknown")).to_lower(), "content_engine_enabled 必须 false"))

	var domain_map: Dictionary = {}
	for item_variant in manifest.get("domains", []):
		if typeof(item_variant) != TYPE_DICTIONARY:
			continue
		var item: Dictionary = item_variant
		domain_map[str(item.get("domain", ""))] = item

	for domain in DOMAINS:
		var name := str(domain["name"])
		var list_key := str(domain["list_key"])
		var expected := int(domain["expected"])
		if not domain_map.has(name):
			rows.append(_row("count::%s" % name, "FAIL", str(expected), "missing", "manifest 缺少 domain"))
			continue
		var rel_path := str(domain_map[name].get("path", ""))
		var json_path := "res://%s" % rel_path if not rel_path.begins_with("res://") else rel_path
		var obj: Dictionary = _read_json(json_path)
		if obj.is_empty():
			rows.append(_row("count::%s" % name, "FAIL", str(expected), "0", "domain json 读取失败"))
			continue
		var arr: Array = obj.get(list_key, []) if typeof(obj.get(list_key, [])) == TYPE_ARRAY else []
		rows.append(_row("count::%s" % name, "PASS" if arr.size() == expected else "FAIL", str(expected), str(arr.size()), "domain 条目数校验"))
		rows.append(_row("runtime_ready::%s" % name, "PASS" if bool(obj.get("runtime_ready", true)) == false else "FAIL", "false", str(obj.get("runtime_ready", "unknown")).to_lower(), "domain runtime_ready 必须 false"))
		rows.append(_row("preview_only::%s" % name, "PASS" if bool(obj.get("preview_only", false)) == true else "FAIL", "true", str(obj.get("preview_only", "unknown")).to_lower(), "domain preview_only 必须 true"))

	return rows


func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return parsed


func _row(check_id: String, status: String, expected: String, actual: String, notes: String) -> Dictionary:
	return {
		"check_id": check_id,
		"status": status,
		"expected": expected,
		"actual": actual,
		"notes": notes,
	}


func _write_tsv(rows: Array) -> void:
	var f := FileAccess.open(OUT_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_line("check_id\tstatus\texpected\tactual\tnotes")
	for row_variant in rows:
		if typeof(row_variant) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = row_variant
		f.store_line("%s\t%s\t%s\t%s\t%s" % [
			str(row.get("check_id", "")),
			str(row.get("status", "")),
			str(row.get("expected", "")),
			str(row.get("actual", "")),
			str(row.get("notes", "")).replace("\n", " "),
		])
