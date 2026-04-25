extends "res://scripts/battle_controller_visual_narrative_context.gd"

func _auto_start_narrative_battle_if_needed() -> void:
	if narrative_auto_start_attempted:
		return
	if not NarrativeBattleContext.has_request():
		return
	var encounter: String = str(NarrativeBattleContext.encounter_id)
	if encounter.is_empty():
		return
	narrative_auto_start_attempted = true
	var role_id: String = _formal_player_role_for_encounter(encounter)
	player_role_id = role_id
	var called: bool = _try_recommended_role_entry(role_id)
	if not called:
		called = _press_role_button_by_text(_formal_role_keywords(role_id))
	if called:
		_set_battle_result_debug_text("正式剧情战斗：已按 %s 自动进入 %s。" % [role_id, encounter])
	else:
		_set_battle_result_debug_text("正式剧情战斗：已写入 %s 配置；未命中自动入口，请点击对应角色入口。" % role_id)

func _formal_player_role_for_encounter(encounter: String) -> String:
	if encounter == "enc_prologue_master_rescue":
		return "blademaster"
	var profile: Dictionary = NarrativeBattleContext.get_player_profile()
	if not profile.is_empty():
		return str(profile.get("role", "spearman"))
	var mapping: Dictionary = NarrativeBattleContext.get_battle_mapping()
	return str(mapping.get("player_role", "spearman"))

func _formal_role_keywords(role_id: String) -> Array[String]:
	if role_id == "blademaster":
		return ["刀客", "腰刀", "blademaster", "刀"]
	return ["枪手", "长枪", "spearman", "枪"]

func _context_debug_text() -> String:
	var base_text: String = super._context_debug_text()
	var encounter: String = str(NarrativeBattleContext.encounter_id)
	if encounter.is_empty():
		return base_text
	return "%s\n正式接敌：encounter=%s｜auto_role=%s｜auto_start=%s" % [base_text, encounter, _formal_player_role_for_encounter(encounter), str(narrative_auto_start_attempted)]
