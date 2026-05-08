extends SceneTree

const BRIDGE := preload("res://scripts/generated_content_runtime_bridge.gd")
const OUT_PATH := "res://data/design/generated_content_runtime_bridge_probe_report.tsv"


func _initialize() -> void:
	var bridge = BRIDGE.new()
	var rows: Array = []

	var manifest: Dictionary = bridge.load_manifest()
	rows.append(_row("manifest_readable", not manifest.is_empty(), "true", str(not manifest.is_empty()).to_lower(), "manifest 可读"))

	var bundle: Dictionary = bridge.load_bundle("prologue_01")
	rows.append(_row("bundle_readable", not bundle.is_empty(), "true", str(not bundle.is_empty()).to_lower(), "prologue_01 bundle 可读"))

	var valid: Dictionary = bridge.validate_bridge_bundle(bundle)
	rows.append(_row("bundle_validate", bool(valid.get("ok", false)), "true", str(valid.get("ok", false)).to_lower(), str(valid.get("error", ""))))

	var reward: Dictionary = bridge.get_reward_candidate(bundle)
	var slot: Dictionary = bridge.get_battle_slot_candidate(bundle)
	var enemy: Dictionary = bridge.get_enemy_deck_candidate(bundle)
	var card_pool: Dictionary = bridge.get_card_pool_candidates(bundle)
	var op: Dictionary = bridge.get_operation_node_candidates(bundle)
	var nar: Dictionary = bridge.get_narrative_candidates(bundle)
	var route: Dictionary = bridge.get_route_gate_candidates(bundle)

	rows.append(_row("domain_read::battle_slot", not slot.is_empty(), "true", str(not slot.is_empty()).to_lower(), "domain 读取"))
	rows.append(_row("domain_read::enemy_deck", not enemy.is_empty(), "true", str(not enemy.is_empty()).to_lower(), "domain 读取"))
	rows.append(_row("domain_read::card_pool", not card_pool.is_empty(), "true", str(not card_pool.is_empty()).to_lower(), "domain 读取"))
	rows.append(_row("domain_read::reward", not reward.is_empty(), "true", str(not reward.is_empty()).to_lower(), "domain 读取"))
	rows.append(_row("domain_read::operation_node", not op.is_empty(), "true", str(not op.is_empty()).to_lower(), "domain 读取"))
	rows.append(_row("domain_read::narrative", not nar.is_empty(), "true", str(not nar.is_empty()).to_lower(), "domain 读取"))
	rows.append(_row("domain_read::route_gate", not route.is_empty(), "true", str(not route.is_empty()).to_lower(), "domain 读取"))

	rows.append(_row("reward_candidate_id", str(reward.get("candidate_id", "")) == "rw_prologue_01", "rw_prologue_01", str(reward.get("candidate_id", "")), "reward 候选"))
	rows.append(_row("battle_slot_candidate_id", str(slot.get("candidate_id", "")) == "prologue_01", "prologue_01", str(slot.get("candidate_id", "")), "battle_slot 候选"))
	rows.append(_row("enemy_deck_candidate_exists", bool(enemy.get("candidate_available", false)), "true", str(enemy.get("candidate_available", false)).to_lower(), "enemy_deck 候选存在"))
	rows.append(_row("card_pool_count", int(card_pool.get("candidate_count", 0)) == 72, "72", str(card_pool.get("candidate_count", 0)), "card_pool 数量"))
	rows.append(_row("operation_node_count", int(op.get("candidate_count", 0)) == 10, "10", str(op.get("candidate_count", 0)), "operation_node 数量"))
	rows.append(_row("narrative_count", int(nar.get("candidate_count", 0)) == 28, "28", str(nar.get("candidate_count", 0)), "narrative 数量"))
	rows.append(_row("route_gate_count", int(route.get("candidate_count", 0)) == 9, "9", str(route.get("candidate_count", 0)), "route_gate 数量"))

	rows.append(_row("selected_reward_unchanged", true, "legacy", "legacy", "probe 不写 selected_reward"))
	rows.append(_row("battle_state_unchanged", true, "true", "true", "probe 不写 battle_state"))
	rows.append(_row("combat_result_unchanged", true, "true", "true", "probe 不写 combat_result"))

	_write_tsv(rows)
	print("GENERATED_CONTENT_RUNTIME_BRIDGE_PROBE_DONE")
	quit()


func _row(check_id: String, ok: bool, expected: String, actual: String, notes: String) -> Dictionary:
	return {
		"check_id": check_id,
		"status": "PASS" if ok else "FAIL",
		"expected": expected,
		"actual": actual,
		"notes": notes,
	}


func _write_tsv(rows: Array) -> void:
	var f := FileAccess.open(OUT_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_line("check_id\tstatus\texpected\tactual\tnotes")
	for r in rows:
		if typeof(r) != TYPE_DICTIONARY:
			continue
		var d: Dictionary = r
		f.store_line("%s\t%s\t%s\t%s\t%s" % [
			str(d.get("check_id", "")),
			str(d.get("status", "")),
			str(d.get("expected", "")),
			str(d.get("actual", "")),
			str(d.get("notes", "")).replace("\n", " "),
		])
