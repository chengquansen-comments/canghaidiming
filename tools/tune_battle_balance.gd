extends SceneTree

const AutoBattleSampler = preload("res://scripts/auto_battle_sampler.gd")
const CardData = preload("res://scripts/card_data.gd")

const ENCOUNTER_ORDER := [
	"enc_prologue_master_rescue",
	"enc_beach_ambush",
	"enc_fishing_village_embers",
	"enc_transport_officer",
	"enc_mutiny_camp",
	"enc_wakou_boss"
]

const ENEMY_MANIFEST_PATH := "res://data/enemy_manifest.json"
const ENEMY_TABLE_PATH := "res://tables/enemy_manifest_enemies.tsv"
const ENEMY_DECK_TABLE_PATH := "res://tables/enemy_manifest_deck.tsv"

var samples := 80
var seed := 260427
var write_tables := false
var report_path := "res://reports/battle_balance_report.json"

func _init() -> void:
	_parse_args()
	var manifest := _read_json(ENEMY_MANIFEST_PATH)
	if manifest.is_empty():
		_fail("无法读取 %s" % ENEMY_MANIFEST_PATH)
		return
	var report := _run_campaign_tuning(manifest)
	_print_report(report)
	if write_tables:
		_write_recommendations(report)
	_save_json(report_path, report)
	quit(0)

func _parse_args() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg == "--write":
			write_tables = true
		elif arg.begins_with("--samples="):
			samples = maxi(20, int(arg.get_slice("=", 1)))
		elif arg.begins_with("--seed="):
			seed = int(arg.get_slice("=", 1))
		elif arg.begins_with("--report="):
			report_path = arg.get_slice("=", 1)

func _run_campaign_tuning(manifest: Dictionary) -> Dictionary:
	var encounters: Dictionary = manifest.get("encounters", {})
	var enemies: Dictionary = manifest.get("enemies", {})
	var role_profiles := {
		"spearman": {"hp": 38, "max_momentum": 10, "momentum": 6, "style": "spear", "level": 1},
		"blademaster": {"hp": 34, "max_momentum": 10, "momentum": 7, "style": "blade", "level": 1}
	}
	var entries: Array[Dictionary] = []
	var recommendations := {}
	for encounter_id in ENCOUNTER_ORDER:
		var encounter: Dictionary = encounters.get(encounter_id, {})
		if encounter.is_empty():
			continue
		var enemy_id := str(encounter.get("enemy_id", ""))
		var enemy: Dictionary = enemies.get(enemy_id, {})
		if enemy.is_empty():
			continue
		var role_id := str(encounter.get("player_role", "spearman"))
		var player_config := _player_config(encounter_id, role_id, role_profiles.get(role_id, {}))
		var enemy_config := _enemy_config(enemy, encounter)
		var target := _target_for_difficulty(str(encounter.get("difficulty", "normal")))
		var baseline := _evaluate_config(player_config, enemy_config, enemy_config, samples, seed + entries.size() * 1000)
		var best := _search_best(player_config, enemy_config, target, seed + entries.size() * 1000)
		var recommended_enemy: Dictionary = best.get("candidate", enemy_config)
		entries.append({
			"encounter_id": encounter_id,
			"enemy_id": enemy_id,
			"difficulty": str(encounter.get("difficulty", "")),
			"player_role": role_id,
			"target": target,
			"baseline": baseline,
			"best": best,
			"recommended_enemy": recommended_enemy
		})
		recommendations[enemy_id] = recommended_enemy
		if encounter_id != "enc_prologue_master_rescue":
			var growth := _growth_for_difficulty(str(encounter.get("difficulty", "normal")))
			var profile: Dictionary = role_profiles.get(role_id, {})
			profile["hp"] = int(profile.get("hp", 34)) + int(growth.get("hp", 0))
			profile["max_momentum"] = int(profile.get("max_momentum", 10)) + int(growth.get("posture", 0))
			profile["momentum"] = int(profile.get("max_momentum", 10))
			profile["level"] = int(profile.get("level", 1)) + int(growth.get("martial", 0))
			role_profiles[role_id] = profile
	return {
		"samples_per_config": samples,
		"seed": seed,
		"write_tables": write_tables,
		"entries": entries,
		"recommendations": recommendations
	}

func _search_best(player_config: Dictionary, enemy_config: Dictionary, target: Dictionary, base_seed: int) -> Dictionary:
	var hp_delta_values := [-12, -8, -4, 0, 4]
	var start_posture_delta_values := [-2, -1, 0]
	var realm_delta_values := [0]
	var qinggong_delta_values := [-1, 0]
	var damage_delta_values := [-3, -2, -1, 0, 1]
	var break_delta_values := [-2, -1, 0]
	var guard_delta_values := [-3, -1, 0, 1]
	var best := {}
	var count := 0
	for hp_delta in hp_delta_values:
		for start_delta in start_posture_delta_values:
			for realm_delta in realm_delta_values:
				for qinggong_delta in qinggong_delta_values:
					for damage_delta in damage_delta_values:
						for break_delta in break_delta_values:
							for guard_delta in guard_delta_values:
								var adjustment := {"hp_delta": hp_delta, "start_posture_delta": start_delta, "realm_delta": realm_delta, "qinggong_delta": qinggong_delta, "damage_delta": damage_delta, "break_delta": break_delta, "guard_delta": guard_delta}
								var candidate := _adjusted_enemy_config(enemy_config, adjustment)
								var result := _evaluate_config(player_config, enemy_config, candidate, samples, base_seed + count)
								result["candidate"] = candidate
								result["changes"] = _describe_changes(enemy_config, candidate)
								result["score"] = _score_against_target(result, target) + _change_penalty(enemy_config, candidate, result["changes"])
								count += 1
								if best.is_empty() or float(result.get("score", 999.0)) < float(best.get("score", 999.0)):
									best = result
	best["evaluated_configs"] = count
	return best

func _evaluate_config(player_config: Dictionary, enemy_config: Dictionary, tuned_enemy: Dictionary, sample_count: int, run_seed: int) -> Dictionary:
	var player_cards := _cards_from_configs(player_config.get("deck", []))
	var enemy_cards := _cards_from_configs(tuned_enemy.get("deck", []))
	var result := AutoBattleSampler.run_batch(player_cards, enemy_cards, {
		"sample_count": sample_count,
		"seed": run_seed,
		"max_turns": 24,
		"player_state": {
			"hp": int(player_config.get("hp", 34)),
			"max_momentum": int(player_config.get("max_momentum", 10)),
			"momentum": int(player_config.get("momentum", 6)),
			"position": 2,
			"facing": "right",
			"style": str(player_config.get("style", "spear")),
			"realm": int(player_config.get("realm", 1)),
			"qinggong": maxi(1, int(player_config.get("qinggong", 1)))
		},
		"enemy_state": {
			"hp": int(tuned_enemy.get("max_hp", 26)),
			"max_momentum": int(tuned_enemy.get("max_momentum", 10)),
			"momentum": int(tuned_enemy.get("momentum", 4)),
			"position": 6,
			"facing": "left",
			"style": str(tuned_enemy.get("style", "blade")),
			"realm": int(tuned_enemy.get("realm", 1)),
			"qinggong": maxi(1, int(tuned_enemy.get("qinggong", 1)))
		},
		"player_preferred": player_config.get("preferred", [3, 4, 5]),
		"enemy_preferred": tuned_enemy.get("preferred", [0, 1, 2])
	})
	return result

func _score_against_target(result: Dictionary, target: Dictionary) -> float:
	var win := float(result.get("player_win_rate", 0.0))
	var turns := float(result.get("avg_turns", 0.0))
	var min_turns := float(target.get("min_turns", 5.0))
	var max_turns := float(target.get("max_turns", 10.0))
	var turn_penalty := 0.0
	if turns < min_turns:
		turn_penalty = (min_turns - turns) / 6.0
	elif turns > max_turns:
		turn_penalty = (turns - max_turns) / 6.0
	return abs(win - float(target.get("player_win_rate", 0.65))) * 2.6 + turn_penalty + float(result.get("draw_rate", 0.0)) * 0.5

func _change_penalty(base: Dictionary, candidate: Dictionary, changes: Array) -> float:
	var penalty := float(changes.size()) * 0.01
	penalty += abs(float(candidate.get("max_hp", 0)) - float(base.get("max_hp", 0))) * 0.003
	penalty += abs(float(candidate.get("momentum", 0)) - float(base.get("momentum", 0))) * 0.015
	penalty += abs(float(candidate.get("qinggong", 1)) - float(base.get("qinggong", 1))) * 0.025
	return penalty

func _target_for_difficulty(difficulty: String) -> Dictionary:
	match difficulty:
		"tutorial_elite":
			return {"player_win_rate": 0.9, "min_turns": 3.0, "max_turns": 6.0}
		"elite":
			return {"player_win_rate": 0.6, "min_turns": 6.0, "max_turns": 10.0}
		"boss":
			return {"player_win_rate": 0.52, "min_turns": 7.0, "max_turns": 12.0}
		_:
			return {"player_win_rate": 0.7, "min_turns": 5.0, "max_turns": 9.0}

func _growth_for_difficulty(difficulty: String) -> Dictionary:
	match difficulty:
		"elite":
			return {"hp": 2, "posture": 1, "martial": 1}
		"boss":
			return {"hp": 3, "posture": 1, "martial": 2}
		_:
			return {"hp": 1, "posture": 0, "martial": 1}

func _player_config(encounter_id: String, role_id: String, profile: Dictionary) -> Dictionary:
	if encounter_id == "enc_prologue_master_rescue":
		return {"hp": 48, "max_momentum": 12, "momentum": 9, "realm": 4, "qinggong": 3, "style": "blade", "preferred": [0, 1, 2], "deck": _master_cards()}
	var level := int(profile.get("level", 1))
	if role_id == "blademaster":
		return {"hp": int(profile.get("hp", 34)), "max_momentum": int(profile.get("max_momentum", 10)), "momentum": int(profile.get("momentum", 7)), "realm": level, "qinggong": 2, "style": "blade", "preferred": [0, 1, 2], "deck": _blade_cards(level)}
	return {"hp": int(profile.get("hp", 38)), "max_momentum": int(profile.get("max_momentum", 10)), "momentum": int(profile.get("momentum", 6)), "realm": level, "qinggong": 1, "style": "spear", "preferred": [3, 4, 5], "deck": _spear_cards(level)}

func _enemy_config(enemy: Dictionary, encounter: Dictionary) -> Dictionary:
	var role_sheet := str(enemy.get("role_sheet", ""))
	var family := str(encounter.get("enemy_family", "spearman"))
	var style := "blade" if role_sheet.findn("blade") >= 0 or family == "blademaster" else "spear"
	return {
		"max_hp": int(enemy.get("max_hp", 26)),
		"max_momentum": int(enemy.get("max_posture", 10)),
		"momentum": int(enemy.get("start_posture", 4)),
		"realm": int(enemy.get("realm", _default_enemy_realm(str(encounter.get("difficulty", "normal"))))),
		"qinggong": maxi(1, int(enemy.get("qinggong", 2 if style == "blade" else 1))),
		"style": style,
		"preferred": [0, 1, 2] if style == "blade" else [3, 4, 5],
		"deck": enemy.get("deck", [])
	}

func _default_enemy_realm(difficulty: String) -> int:
	match difficulty:
		"elite":
			return 2
		"boss":
			return 3
		_:
			return 1

func _adjusted_enemy_config(enemy_config: Dictionary, adjustment: Dictionary) -> Dictionary:
	var out := enemy_config.duplicate(true)
	out["max_hp"] = maxi(1, int(enemy_config.get("max_hp", 1)) + int(adjustment.get("hp_delta", 0)))
	out["max_momentum"] = clampi(int(enemy_config.get("max_momentum", 10)) + int(adjustment.get("max_posture_delta", 0)), 6, 14)
	out["momentum"] = clampi(int(enemy_config.get("momentum", 4)) + int(adjustment.get("start_posture_delta", 0)), 0, int(out.get("max_momentum", 10)))
	out["realm"] = clampi(int(enemy_config.get("realm", 1)) + int(adjustment.get("realm_delta", 0)), 1, 4)
	out["qinggong"] = clampi(int(enemy_config.get("qinggong", 1)) + int(adjustment.get("qinggong_delta", 0)), 1, 4)
	var deck: Array = []
	for card_variant in enemy_config.get("deck", []):
		var card: Dictionary = card_variant.duplicate(true)
		card["damage"] = maxi(0, int(card.get("damage", 0)) + (int(adjustment.get("damage_delta", 0)) if int(card.get("damage", 0)) > 0 else 0))
		card["break"] = maxi(0, int(card.get("break", 0)) + (int(adjustment.get("break_delta", 0)) if int(card.get("break", 0)) > 0 else 0))
		card["guard"] = maxi(0, int(card.get("guard", 0)) + (int(adjustment.get("guard_delta", 0)) if int(card.get("guard", 0)) > 0 else 0))
		deck.append(card)
	out["deck"] = deck
	return out

func _describe_changes(base: Dictionary, candidate: Dictionary) -> Array[String]:
	var changes: Array[String] = []
	for field in ["max_hp", "max_momentum", "momentum", "realm", "qinggong"]:
		if int(base.get(field, 0)) != int(candidate.get(field, 0)):
			changes.append("%s %d->%d" % [field, int(base.get(field, 0)), int(candidate.get(field, 0))])
	var base_deck: Array = base.get("deck", [])
	var candidate_deck: Array = candidate.get("deck", [])
	for i in range(mini(base_deck.size(), candidate_deck.size())):
		var b: Dictionary = base_deck[i]
		var c: Dictionary = candidate_deck[i]
		var card_changes: Array[String] = []
		for field in ["cost", "gain", "break", "damage", "guard", "min", "max"]:
			if int(b.get(field, 0)) != int(c.get(field, 0)):
				card_changes.append("%s %d->%d" % [field, int(b.get(field, 0)), int(c.get(field, 0))])
		if not card_changes.is_empty():
			changes.append("%s: %s" % [str(b.get("name", b.get("id", ""))), ", ".join(card_changes)])
	return changes

func _cards_from_configs(configs: Array) -> Array[CardData]:
	var cards: Array[CardData] = []
	for item in configs:
		var config: Dictionary = item
		cards.append(CardData.new(str(config.get("id", "card")), str(config.get("name", "招式")), str(config.get("name", "")), int(config.get("min", 0)), int(config.get("max", 5)), int(config.get("cost", 1)), str(config.get("role", "damage")), int(config.get("gain", 0)), int(config.get("break", 0)), int(config.get("damage", 0)), int(config.get("guard", 0)), PackedStringArray(config.get("tags", [])), str(config.get("style", "")), bool(config.get("facing", true))))
	return cards

func _c(id: String, name: String, min_d: int, max_d: int, cost: int, role: String, gain: int, brk: int, dmg: int, guard: int, tags: Array, style: String, facing: bool = true) -> Dictionary:
	return {"id": id, "name": name, "min": min_d, "max": max_d, "cost": cost, "role": role, "gain": gain, "break": brk, "damage": dmg, "guard": guard, "tags": tags, "style": style, "facing": facing}

func _master_cards() -> Array:
	return [_c("m_1","老兵压刀",0,2,0,"momentum",3,2,0,0,["教学","强力"],"刀"), _c("m_2","旧刀横封",0,3,0,"guard",0,0,0,9,["教学","守"],"刀",false), _c("m_3","沉默斩",0,2,1,"damage",0,2,12,0,["教学","斩杀"],"刀"), _c("m_4","断声一刀",0,1,1,"damage",0,3,16,0,["终结"],"刀")]

func _spear_cards(level: int) -> Array:
	var cards := [_c("p_s1","枪式一",3,5,1,"momentum",2,0,0,0,["试探"],"枪"), _c("p_s2","枪式二",3,5,1,"momentum",0,2,0,0,["破势"],"枪"), _c("p_s3","枪式三",3,5,1,"damage",0,0,5,0,["起手"],"枪"), _c("p_s4","枪守式",0,5,1,"guard",0,0,0,5,["守"],"枪",false), _c("p_s5","枪进式",2,4,1,"damage",1,0,4,0,["进身"],"枪"), _c("p_s6","枪终式",4,5,2,"damage",0,1,8,0,["终结"],"枪")]
	if level >= 2: cards.append(_c("p_s7","枪先式",2,4,2,"momentum",2,2,0,0,["先机"],"枪"))
	if level >= 3: cards.append(_c("p_s8","枪固式",0,5,2,"guard",0,0,0,9,["重守"],"枪",false))
	return cards

func _blade_cards(level: int) -> Array:
	var cards := [_c("p_b1","刀式一",0,2,1,"momentum",2,0,0,0,["试探"],"刀"), _c("p_b2","刀式二",0,2,1,"momentum",0,2,0,0,["破势"],"刀"), _c("p_b3","刀式三",0,2,1,"damage",0,0,5,0,["起手"],"刀"), _c("p_b4","刀守式",0,3,1,"guard",0,0,0,5,["守"],"刀",false), _c("p_b5","刀追式",0,1,1,"damage",1,0,4,0,["追击"],"刀"), _c("p_b6","刀终式",0,1,2,"damage",0,1,8,0,["终结"],"刀")]
	if level >= 2: cards.append(_c("p_b7","刀先式",0,2,2,"momentum",2,2,0,0,["先机"],"刀"))
	if level >= 3: cards.append(_c("p_b8","刀固式",0,3,2,"guard",0,0,0,9,["重守"],"刀",false))
	return cards

func _print_report(report: Dictionary) -> void:
	print("battle balance tuning samples=%d seed=%d write=%s" % [samples, seed, str(write_tables)])
	for entry in report.get("entries", []):
		var baseline: Dictionary = entry.get("baseline", {})
		var best: Dictionary = entry.get("best", {})
		var candidate: Dictionary = best.get("candidate", {})
		var changes: Array = best.get("changes", [])
		print("%s %-13s base %.0f%%/%.1ft -> best %.0f%%/%.1ft score %.3f HP %d 轻功 %d 武境 %d 改动 %d项" % [
			str(entry.get("encounter_id", "")),
			str(entry.get("difficulty", "")),
			float(baseline.get("player_win_rate", 0.0)) * 100.0,
			float(baseline.get("avg_turns", 0.0)),
			float(best.get("player_win_rate", 0.0)) * 100.0,
			float(best.get("avg_turns", 0.0)),
			float(best.get("score", 0.0)),
			int(candidate.get("max_hp", 0)),
			int(candidate.get("qinggong", 1)),
			int(candidate.get("realm", 0)),
			int(changes.size())
		])
		if not changes.is_empty():
			print("  " + "；".join(changes.slice(0, 6)))

func _write_recommendations(report: Dictionary) -> void:
	_update_enemy_table(report.get("recommendations", {}))
	_update_deck_table(report.get("recommendations", {}))

func _update_enemy_table(recommendations: Dictionary) -> void:
	var rows := _read_tsv(ENEMY_TABLE_PATH)
	for row in rows:
		var enemy_id := str(row.get("enemy_id", ""))
		if recommendations.has(enemy_id):
			var recommendation: Dictionary = recommendations[enemy_id]
			row["max_hp"] = str(int(recommendation.get("max_hp", row.get("max_hp", 1))))
			row["max_posture"] = str(int(recommendation.get("max_momentum", row.get("max_posture", 10))))
			row["start_posture"] = str(int(recommendation.get("momentum", row.get("start_posture", 4))))
			row["realm"] = str(int(recommendation.get("realm", row.get("realm", 1))))
			row["qinggong"] = str(maxi(1, int(recommendation.get("qinggong", row.get("qinggong", 1)))))
	_write_tsv(ENEMY_TABLE_PATH, rows)

func _update_deck_table(recommendations: Dictionary) -> void:
	var rows := _read_tsv(ENEMY_DECK_TABLE_PATH)
	var by_card := {}
	for enemy_id in recommendations.keys():
		for card in recommendations[enemy_id].get("deck", []):
			by_card["%s/%s" % [enemy_id, str(card.get("id", ""))]] = card
	for row in rows:
		var key := "%s/%s" % [str(row.get("enemy_id", "")), str(row.get("id", ""))]
		if by_card.has(key):
			var card: Dictionary = by_card[key]
			row["damage"] = str(int(card.get("damage", row.get("damage", 0))))
			row["break"] = str(int(card.get("break", row.get("break", 0))))
			row["guard"] = str(int(card.get("guard", row.get("guard", 0))))
	_write_tsv(ENEMY_DECK_TABLE_PATH, rows)

func _read_tsv(path: String) -> Array[Dictionary]:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return []
	var lines := file.get_as_text().split("\n", false)
	if lines.is_empty():
		return []
	var headers := lines[0].split("\t")
	var rows: Array[Dictionary] = []
	for i in range(1, lines.size()):
		var values := lines[i].split("\t", true)
		var row := {}
		for h in range(headers.size()):
			row[headers[h]] = values[h] if h < values.size() else ""
		rows.append(row)
	return rows

func _write_tsv(path: String, rows: Array[Dictionary]) -> void:
	if rows.is_empty():
		return
	var headers: Array = rows[0].keys()
	var lines: Array[String] = ["\t".join(headers)]
	for row in rows:
		var values: Array[String] = []
		for header in headers:
			values.append(str(row.get(header, "")))
		lines.append("\t".join(values))
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string("\n".join(lines) + "\n")

func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	return parsed if parsed is Dictionary else {}

func _save_json(path: String, payload: Dictionary) -> void:
	var dir := path.get_base_dir()
	if dir != "" and not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(dir)):
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(payload, "\t"))

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
