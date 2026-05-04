extends "res://scripts/battle_controller_visual_story_return.gd"

# Use a local preload alias for parser-time constants to avoid relying on the
# global class registry while this parent script is being resolved.
const BattleIntentVisibilityForStoryReturn := preload("res://scripts/battle_intent_visibility.gd")

var _intent_visibility_policy := BattleIntentVisibilityForStoryReturn.POLICY_FULL


func _apply_selected_story_battle_to_current_battle() -> void:
	super._apply_selected_story_battle_to_current_battle()
	_setup_intent_visibility_policy_for_current_encounter()


func _apply_battle_loadout_once(loadout: Dictionary) -> void:
	super._apply_battle_loadout_once(loadout)
	_setup_intent_visibility_policy_for_current_encounter()


func _setup_intent_visibility_policy_for_current_encounter() -> void:
	_intent_visibility_policy = BattleIntentVisibilityForStoryReturn.POLICY_FULL
	var encounter: Dictionary = {}
	if not _pending_story_battle.is_empty():
		encounter = _pending_story_battle.get("encounter", {})
	elif not battle_loadout.is_empty():
		encounter = battle_loadout.get("encounter_config", {})
	if encounter.is_empty():
		return
	var policy := str(encounter.get("intent_visibility_policy", BattleIntentVisibilityForStoryReturn.POLICY_FULL))
	if not BattleIntentVisibilityForStoryReturn.is_valid_policy(policy):
		push_warning("Invalid intent_visibility_policy, fallback to full: %s" % policy)
		policy = BattleIntentVisibilityForStoryReturn.POLICY_FULL
	_intent_visibility_policy = policy


func _enemy_intent_visibility() -> String:
	var is_reactive := state_machine != null and state_machine.is_reactive_mode()
	var player_realm := player.realm if player != null else 0
	var enemy_realm := enemy.realm if enemy != null else 0
	return BattleIntentVisibilityForStoryReturn.resolve_enemy_visibility(_intent_visibility_policy, is_reactive, player_realm, enemy_realm)


func _mode_status_suffix() -> String:
	var text: String = super._mode_status_suffix()
	if state_machine != null and state_machine.is_reactive_mode():
		text += "\n意图可见：%s（%s）" % [
			BattleIntentVisibilityForStoryReturn.visibility_label(_enemy_intent_visibility()),
			_intent_visibility_policy
		]
	return text


func _intent_bubble_text(card: CardData, actor_slot: int, opponent_slot: int, target_slot: int) -> String:
	var full_text := super._intent_bubble_text(card, actor_slot, opponent_slot, target_slot)
	if enemy_intent != null and card == enemy_intent.actual_card:
		return BattleIntentVisibilityForStoryReturn.enemy_intent_bubble_text(card, _enemy_intent_visibility(), full_text)
	return full_text


func _enemy_preview_card() -> CardData:
	if not BattleIntentVisibilityForStoryReturn.should_show_enemy_range(_enemy_intent_visibility()):
		return null
	return super._enemy_preview_card()


func _compute_ordered_preview() -> Dictionary:
	var preview: Dictionary = super._compute_ordered_preview()
	if not bool(preview.get("has_preview", false)):
		return preview
	if enemy == null:
		return preview
	if not BattleIntentVisibilityForStoryReturn.should_show_enemy_final_preview(_enemy_intent_visibility()):
		preview["enemy_subjective"] = enemy.position
		preview["enemy_final"] = enemy.position
	return preview


func _effect_preview_text() -> String:
	if player == null or enemy == null or state_machine == null:
		return "[font_size=18][b]效果预览[/b][/font_size]\n等待战斗数据。"
	var visibility := _enemy_intent_visibility()
	if visibility == BattleIntentVisibilityForStoryReturn.VISIBILITY_FULL:
		return super._effect_preview_text()
	var p_intent: IntentData = draft_player_intent if draft_player_intent != null else player_intent
	var e_intent: IntentData = enemy_intent
	var p_card: CardData = p_intent.actual_card if p_intent != null else null
	var e_card: CardData = e_intent.actual_card if e_intent != null else null
	var sim: Dictionary = _ordered_preview_simulation(p_intent, e_intent)
	var lines: Array[String] = []
	lines.append("[font_size=18][b]效果预览[/b][/font_size]")
	lines.append("行动顺序：%s" % _order_text(sim.get("order", [])))
	lines.append("我方招式：%s" % (p_card.display_name if p_card != null else "待命"))
	if visibility == BattleIntentVisibilityForStoryReturn.VISIBILITY_TYPE:
		lines.append("敌方招式：敌方意图：%s" % BattleIntentVisibilityForStoryReturn.card_tactic_type_text(e_card))
	else:
		lines.append("敌方招式：敌方意图：不可辨")
	lines.append("")
	lines.append("[b]顺序结算预览[/b]")
	for step: Dictionary in sim.get("steps", []):
		if str(step.get("side", "")) == "enemy":
			lines.append(_redacted_enemy_step_text(step, visibility, e_card))
		else:
			lines.append(_step_text(step))
	lines.append("")
	lines.append("[b]最终汇总[/b]")
	lines.append("我方：伤%d / 势-%d / 主观 %s / 最终 %s" % [absi(int(sim.get("player_hp_delta", 0))) if int(sim.get("player_hp_delta", 0)) < 0 else 0, absi(int(sim.get("player_momentum_delta", 0))) if int(sim.get("player_momentum_delta", 0)) < 0 else 0, _slot_label(int(sim.get("player_subjective", player.position))), _slot_label(int(sim.get("player_final", player.position)))])
	if visibility == BattleIntentVisibilityForStoryReturn.VISIBILITY_TYPE:
		lines.append("敌方：只可辨类型 / 主观未知 / 最终未知")
	else:
		lines.append("敌方：意图不可辨 / 主观未知 / 最终未知")
	return "\n".join(lines)


func _reactive_threat_preview_text() -> String:
	if state_machine == null or not state_machine.is_reactive_mode():
		return ""
	if player == null or enemy == null or enemy_intent == null:
		return ""
	var visibility := _enemy_intent_visibility()
	if visibility == BattleIntentVisibilityForStoryReturn.VISIBILITY_FULL:
		return super._reactive_threat_preview_text()
	var result: Dictionary = _reactive_resolution_preview()
	var player_card: CardData = draft_player_intent.actual_card if draft_player_intent != null else null
	var lines: Array[String] = []
	lines.append("\n[font_size=18][b]反应式威胁摘要[/b][/font_size]")
	lines.append("敌方已落位：%s，当前距离 %d" % [_slot_label_safe(enemy.position), int(result.get("initial_distance", 0))])
	lines.append("我方响应：%s / %s / 伤%d / 势-%d" % [player_card.display_name if player_card != null else "未选招式", _range_text_safe(str(result.get("player_range", CombatResolver.RANGE_NONE))), int(result.get("player_damage", 0)), int(result.get("player_break", 0))])
	if visibility == BattleIntentVisibilityForStoryReturn.VISIBILITY_TYPE:
		lines.append("敌方威胁：敌方意图：%s" % BattleIntentVisibilityForStoryReturn.card_tactic_type_text(enemy_intent.actual_card))
		lines.append("结果重点：武境相当，只能辨认类型；具体伤害、削势与攻击范围未知。")
	else:
		lines.append("敌方威胁：不可辨")
		lines.append("结果重点：我方武境不足，无法预判敌方出招。")
	if bool(result.get("will_interrupt", false)):
		lines.append("我方预估：若成功打出崩势，敌方本回合攻击可能被中断。")
	return "\n".join(lines)


func _redacted_enemy_step_text(step: Dictionary, visibility: String, e_card: CardData) -> String:
	var phase := str(step.get("phase", ""))
	if visibility == BattleIntentVisibilityForStoryReturn.VISIBILITY_TYPE:
		if phase == "move":
			return "敌方目标：只可辨动作倾向，具体位移不明"
		if phase == "effect":
			return "敌方招式：%s，具体伤害与削势不明" % BattleIntentVisibilityForStoryReturn.card_tactic_type_text(e_card)
		if phase == "effect_move":
			return "敌方招式位移：不明"
		if phase == "interrupted":
			return "敌方招式：被打断"
		return "敌方：类型可辨，细节未知"
	if phase == "interrupted":
		return "敌方招式：被打断"
	return "敌方：意图不可辨"
