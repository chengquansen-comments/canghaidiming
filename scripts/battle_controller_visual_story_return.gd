extends "res://scripts/battle_controller_visual_settlement_mode.gd"

# Auto-return + pressure-profile layer for story battles.
#
# v0.4.4 routes pressure_profile writes through BattleEffectApplier so this
# visual layer decides timing and displays feedback, but no longer directly
# mutates combat values for pressure rules.
#
# Use a local preload alias for parser-time constants to avoid relying on the
# global class registry while this parent script is being resolved.

const BattleEffectApplierForStoryReturn := preload("res://scripts/battle_effect_applier.gd")
const PRESSURE_NONE := BattleEffectApplierForStoryReturn.PRESSURE_NONE
const PRESSURE_EDGE := BattleEffectApplierForStoryReturn.PRESSURE_EDGE
const PRESSURE_BREAK_RESIST := BattleEffectApplierForStoryReturn.PRESSURE_BREAK_RESIST

var _returning_to_story_selection := false
var _pressure_profile := PRESSURE_NONE
var _break_resist_available := false
var _last_edge_positions: Dictionary = {}
var _battle_reward_choices: Array[CardData] = []
var _selected_battle_reward_card_id := ""
var _battle_result_confirm_button: Button
var _intent_visibility_policy := BattleIntentVisibility.POLICY_FULL
const AIGC_TELEMETRY_PATH := "res://data/aigc_battle/telemetry/aigc_sequence_telemetry.jsonl"


func _apply_selected_story_battle_to_current_battle() -> void:
	super._apply_selected_story_battle_to_current_battle()
	_setup_pressure_profile_for_current_encounter()
	_setup_intent_visibility_policy_for_current_encounter()


func _apply_battle_loadout_once(loadout: Dictionary) -> void:
	super._apply_battle_loadout_once(loadout)
	_setup_pressure_profile_for_current_encounter()
	_setup_intent_visibility_policy_for_current_encounter()


func _refresh_ui() -> void:
	_apply_pressure_profile_runtime_rules()
	super()
	_try_auto_return_after_battle_result()
	_append_pressure_profile_to_status()


func _on_continue_narrative_pressed() -> void:
	if NarrativeBattleContext.has_request():
		super._on_continue_narrative_pressed()
		return
	if log_label != null:
		log_label.append_text("\n[color=#8fd3ff]返回战斗测试。[/color]")
	_show_combat_banner("返回战斗测试", Color("1c2a36"), Color("8fd3ff"))
	_reset_story_battle_runtime_state()
	_show_story_encounter_selection()
	_returning_to_story_selection = false


func _setup_pressure_profile_for_current_encounter() -> void:
	_pressure_profile = PRESSURE_NONE
	_break_resist_available = false
	_last_edge_positions = {}
	var encounter: Dictionary = {}
	if not _pending_story_battle.is_empty():
		encounter = _pending_story_battle.get("encounter", {}) as Dictionary
	elif not battle_loadout.is_empty():
		encounter = battle_loadout.get("encounter_config", {}) as Dictionary
	if encounter.is_empty():
		return
	_pressure_profile = str(encounter.get("pressure_profile", PRESSURE_NONE))
	if not BattleEffectApplierForStoryReturn.is_valid_pressure_profile(_pressure_profile):
		push_warning("Invalid pressure_profile, fallback to none: %s" % _pressure_profile)
		_pressure_profile = PRESSURE_NONE
	_break_resist_available = _pressure_profile == PRESSURE_BREAK_RESIST
	if log_label != null and _pressure_profile != PRESSURE_NONE:
		log_label.append_text("\n[color=#ffd479]压力规则：%s[/color]" % _pressure_profile)


func _setup_intent_visibility_policy_for_current_encounter() -> void:
	_intent_visibility_policy = BattleIntentVisibility.POLICY_FULL
	var encounter: Dictionary = {}
	if not _pending_story_battle.is_empty():
		encounter = _pending_story_battle.get("encounter", {})
	elif not battle_loadout.is_empty():
		encounter = battle_loadout.get("encounter_config", {})
	if encounter.is_empty():
		return
	var policy := str(encounter.get("intent_visibility_policy", BattleIntentVisibility.POLICY_FULL))
	if not BattleIntentVisibility.is_valid_policy(policy):
		push_warning("Invalid intent_visibility_policy, fallback to full: %s" % policy)
		policy = BattleIntentVisibility.POLICY_FULL
	_intent_visibility_policy = policy


func _enemy_intent_visibility() -> String:
	var is_reactive := state_machine != null and state_machine.is_reactive_mode()
	var player_realm := player.realm if player != null else 0
	var enemy_realm := enemy.realm if enemy != null else 0
	return BattleIntentVisibility.resolve_enemy_visibility(_intent_visibility_policy, is_reactive, player_realm, enemy_realm)


func _mode_status_suffix() -> String:
	var text: String = super._mode_status_suffix()
	if state_machine != null and state_machine.is_reactive_mode():
		text += "\n意图可见：%s（%s）" % [
			BattleIntentVisibility.visibility_label(_enemy_intent_visibility()),
			_intent_visibility_policy
		]
	return text


func _intent_bubble_text(card: CardData, actor_slot: int, opponent_slot: int, target_slot: int) -> String:
	var full_text := super._intent_bubble_text(card, actor_slot, opponent_slot, target_slot)
	if enemy_intent != null and card == enemy_intent.actual_card:
		return BattleIntentVisibility.enemy_intent_bubble_text(card, _enemy_intent_visibility(), full_text)
	return full_text


func _enemy_preview_card() -> CardData:
	if not BattleIntentVisibility.should_show_enemy_range(_enemy_intent_visibility()):
		return null
	return super._enemy_preview_card()


func _compute_ordered_preview() -> Dictionary:
	var preview: Dictionary = super._compute_ordered_preview()
	if not bool(preview.get("has_preview", false)):
		return preview
	if enemy == null:
		return preview
	if not BattleIntentVisibility.should_show_enemy_final_preview(_enemy_intent_visibility()):
		preview["enemy_subjective"] = enemy.position
		preview["enemy_final"] = enemy.position
	return preview


func _effect_preview_text() -> String:
	if player == null or enemy == null or state_machine == null:
		return "[font_size=18][b]效果预览[/b][/font_size]\n等待战斗数据。"
	var visibility := _enemy_intent_visibility()
	if visibility == BattleIntentVisibility.VISIBILITY_FULL:
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
	if visibility == BattleIntentVisibility.VISIBILITY_TYPE:
		lines.append("敌方招式：敌方意图：%s" % BattleIntentVisibility.card_tactic_type_text(e_card))
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
	if visibility == BattleIntentVisibility.VISIBILITY_TYPE:
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
	if visibility == BattleIntentVisibility.VISIBILITY_FULL:
		return super._reactive_threat_preview_text()
	var result: Dictionary = _reactive_resolution_preview()
	var player_card: CardData = draft_player_intent.actual_card if draft_player_intent != null else null
	var lines: Array[String] = []
	lines.append("\n[font_size=18][b]反应式威胁摘要[/b][/font_size]")
	lines.append("敌方已落位：%s，当前距离 %d" % [_slot_label_safe(enemy.position), int(result.get("initial_distance", 0))])
	lines.append("我方响应：%s / %s / 伤%d / 势-%d" % [player_card.display_name if player_card != null else "未选招式", _range_text_safe(str(result.get("player_range", CombatResolver.RANGE_NONE))), int(result.get("player_damage", 0)), int(result.get("player_break", 0))])
	if visibility == BattleIntentVisibility.VISIBILITY_TYPE:
		lines.append("敌方威胁：敌方意图：%s" % BattleIntentVisibility.card_tactic_type_text(enemy_intent.actual_card))
		lines.append("结果重点：武境相当，只能辨认类型；具体伤害、削势与攻击范围未知。")
	else:
		lines.append("敌方威胁：不可辨")
		lines.append("结果重点：我方武境不足，无法预判敌方出招。")
	if bool(result.get("will_interrupt", false)):
		lines.append("我方预估：若成功打出崩势，敌方本回合攻击可能被中断。")
	return "\n".join(lines)


func _redacted_enemy_step_text(step: Dictionary, visibility: String, e_card: CardData) -> String:
	var phase := str(step.get("phase", ""))
	if visibility == BattleIntentVisibility.VISIBILITY_TYPE:
		if phase == "move":
			return "敌方目标：只可辨动作倾向，具体位移不明"
		if phase == "effect":
			return "敌方招式：%s，具体伤害与削势不明" % BattleIntentVisibility.card_tactic_type_text(e_card)
		if phase == "effect_move":
			return "敌方招式位移：不明"
		if phase == "interrupted":
			return "敌方招式：被打断"
		return "敌方：类型可辨，细节未知"
	if phase == "interrupted":
		return "敌方招式：被打断"
	return "敌方：意图不可辨"


func _apply_pressure_profile_runtime_rules() -> void:
	if not battle_active:
		return
	if player == null or enemy == null or state_machine == null:
		return
	var context: Dictionary = {
		"break_resist_available": _break_resist_available,
		"last_edge_positions": _last_edge_positions
	}
	var result: Dictionary = BattleEffectApplierForStoryReturn.apply_pressure_profile(_pressure_profile, player, enemy, state_machine, context)
	_break_resist_available = bool(context.get("break_resist_available", _break_resist_available))
	var edge_positions_value: Variant = context.get("last_edge_positions", _last_edge_positions)
	if edge_positions_value is Dictionary:
		_last_edge_positions = edge_positions_value as Dictionary
	if not bool(result.get("applied", false)):
		return
	var events_value: Variant = result.get("events", [])
	if not (events_value is Array):
		return
	var events: Array = events_value as Array
	for i in range(events.size()):
		var event_value: Variant = events[i]
		if event_value is Dictionary:
			_log_pressure_event(event_value as Dictionary)


func _log_pressure_event(event: Dictionary) -> void:
	var event_type: String = str(event.get("type", ""))
	if event_type == PRESSURE_EDGE:
		if log_label != null:
			log_label.append_text("\n[color=#ffd479]边界压迫：%s被逼至%s，额外失1势。[/color]" % [str(event.get("label", "角色")), _slot_label_safe(int(event.get("position", 0)))])
	elif event_type == PRESSURE_BREAK_RESIST:
		if log_label != null:
			log_label.append_text("\n[color=#ffd479]稳势：对手强行稳住身形，本次崩势中断被抵消，势保留为1。[/color]")
		_show_combat_banner("稳势：崩势被抵消", Color("2a2018"), Color("ffd479"))


func _append_pressure_profile_to_status() -> void:
	if status_label == null:
		return
	if _pressure_profile == PRESSURE_NONE:
		return
	status_label.append_text("\n压力规则：%s" % _pressure_profile)


func _try_auto_return_after_battle_result() -> void:
	pass


func _show_battle_result_overlay(victory: bool) -> void:
	if battle_result_title == null or battle_result_body == null or battle_result_actions == null:
		return
	_battle_reward_choices.clear()
	_selected_battle_reward_card_id = ""
	_battle_result_confirm_button = null
	_mark_generated_reward_visible(victory)
	var title: String = "战斗胜利" if victory else "战斗失败"
	battle_result_title.text = title
	_set_battle_result_body_text(_battle_result_body_text(victory, ""))
	for child: Node in battle_result_actions.get_children():
		child.queue_free()
	if victory and _battle_result_should_offer_player_reward():
		_battle_reward_choices = _sample_battle_reward_choices(3)
		for card: CardData in _battle_reward_choices:
			var card_button: Button = Button.new()
			card_button.text = card.short_summary()
			card_button.custom_minimum_size = Vector2(360, 46)
			card_button.pressed.connect(_select_battle_reward_card.bind(card.id))
			battle_result_actions.add_child(card_button)
	var button: Button = Button.new()
	button.text = "确认"
	button.custom_minimum_size = Vector2(160, 42)
	button.pressed.connect(Callable(self, "_on_battle_result_confirm_pressed") if victory else Callable(self, "_on_battle_retry_confirm_pressed"))
	if victory and _battle_result_should_offer_player_reward() and not _battle_reward_choices.is_empty():
		button.disabled = true
	_battle_result_confirm_button = button
	battle_result_actions.add_child(button)
	if battle_result_scrim != null:
		battle_result_scrim.visible = true
		battle_result_scrim.move_to_front()
	if battle_result_panel != null:
		if victory and _battle_result_should_use_story_size():
			battle_result_panel.offset_left = -390
			battle_result_panel.offset_right = 390
			battle_result_panel.offset_top = -230
			battle_result_panel.offset_bottom = 260
		else:
			battle_result_panel.offset_left = -240
			battle_result_panel.offset_right = 240
			battle_result_panel.offset_top = -120
			battle_result_panel.offset_bottom = 120
		battle_result_panel.visible = true
		battle_result_panel.move_to_front()
	if has_method("_apply_button_styles"):
		call("_apply_button_styles")


func _battle_result_body_text(victory: bool, selected_card_id: String) -> String:
	if not victory:
		return "重新再来"
	if _battle_result_is_proxy_player():
		return ""
	var lines: Array[String] = []
	lines.append(_projected_player_growth_text())
	if _has_generated_manifest_reward():
		lines.append("本场奖励：%s" % _generated_reward_summary_text())
		lines.append("确认后领取并返回正式流程。")
		return "\n".join(lines)
	if _battle_result_should_offer_player_reward():
		if selected_card_id.is_empty():
			lines.append("选择 1 张新招式加入长期牌库。")
		else:
			lines.append("已选择：%s" % _card_display_name(selected_card_id))
	return "\n".join(lines)


func _battle_result_is_proxy_player() -> bool:
	return NarrativeBattleContext.has_request() and not NarrativeBattleContext.should_override_player_profile()


func _battle_result_should_offer_player_reward() -> bool:
	return NarrativeBattleContext.has_request() and not _battle_result_is_proxy_player() and not _has_generated_manifest_reward()


func _battle_result_should_use_story_size() -> bool:
	return NarrativeBattleContext.has_request() and not _battle_result_is_proxy_player()


func _projected_player_growth_text() -> String:
	if not NarrativeBattleContext.has_player_profile():
		if player == null or player.data == null:
			return "胜利结算：玩家数值将在返回剧情后更新。"
		var fallback_level: int = int(player.realm)
		var fallback_next_level: int = fallback_level + 1
		var fallback_new_hp: int = NarrativeBattleContext.PLAYER_INITIAL_HP + maxi(0, fallback_next_level - NarrativeBattleContext.PLAYER_INITIAL_MARTIAL_LEVEL) * 2
		var fallback_new_posture: int = clampi(NarrativeBattleContext.PLAYER_INITIAL_MAX_POSTURE + maxi(0, fallback_next_level - NarrativeBattleContext.PLAYER_INITIAL_MARTIAL_LEVEL), NarrativeBattleContext.PLAYER_INITIAL_MAX_POSTURE, NarrativeBattleContext.PLAYER_MAX_POSTURE)
		var fallback_new_qinggong: int = clampi(NarrativeBattleContext.PLAYER_INITIAL_QINGGONG + int(maxi(0, fallback_next_level - NarrativeBattleContext.PLAYER_INITIAL_MARTIAL_LEVEL) / 3), NarrativeBattleContext.PLAYER_INITIAL_QINGGONG, NarrativeBattleContext.PLAYER_MAX_QINGGONG)
		return "数值变化：武境 %d -> %d｜HP上限 %d -> %d｜势上限 %d -> %d｜轻功 %d -> %d｜胜场 +1" % [fallback_level, fallback_next_level, player.data.max_hp, fallback_new_hp, player.data.max_momentum, fallback_new_posture, player.qinggong, fallback_new_qinggong]
	var profile: Dictionary = NarrativeBattleContext.get_player_profile() as Dictionary
	var old_level: int = int(profile.get("martial_level", 1))
	var new_level: int = old_level + 1
	var old_hp: int = int(profile.get("max_hp", NarrativeBattleContext.PLAYER_INITIAL_HP))
	var old_current_hp: int = int(profile.get("hp", old_hp))
	var old_posture: int = int(profile.get("max_posture", NarrativeBattleContext.PLAYER_INITIAL_MAX_POSTURE))
	var old_current_posture: int = int(profile.get("posture", old_posture))
	var old_qinggong: int = int(profile.get("qinggong", NarrativeBattleContext.PLAYER_INITIAL_QINGGONG))
	var old_wins: int = int(profile.get("battles_won", 0))
	var new_hp: int = NarrativeBattleContext.PLAYER_INITIAL_HP + maxi(0, new_level - NarrativeBattleContext.PLAYER_INITIAL_MARTIAL_LEVEL) * 2
	var new_posture: int = clampi(NarrativeBattleContext.PLAYER_INITIAL_MAX_POSTURE + maxi(0, new_level - NarrativeBattleContext.PLAYER_INITIAL_MARTIAL_LEVEL), NarrativeBattleContext.PLAYER_INITIAL_MAX_POSTURE, NarrativeBattleContext.PLAYER_MAX_POSTURE)
	var new_qinggong: int = clampi(NarrativeBattleContext.PLAYER_INITIAL_QINGGONG + int(maxi(0, new_level - NarrativeBattleContext.PLAYER_INITIAL_MARTIAL_LEVEL) / 3), NarrativeBattleContext.PLAYER_INITIAL_QINGGONG, NarrativeBattleContext.PLAYER_MAX_QINGGONG)
	return "数值变化：武境 %d -> %d｜HP %d/%d -> %d/%d｜势 %d/%d -> %d/%d｜轻功 %d -> %d｜胜场 %d -> %d" % [old_level, new_level, old_current_hp, old_hp, new_hp, new_hp, old_current_posture, old_posture, new_posture, new_posture, old_qinggong, new_qinggong, old_wins, old_wins + 1]


func _sample_battle_reward_choices(count: int) -> Array[CardData]:
	var owned: Array[String] = []
	if NarrativeBattleContext.has_player_profile():
		var card_state: Dictionary = NarrativeBattleContext.get_player_card_state() as Dictionary
		var owned_values: Array = card_state.get("owned_card_ids", []) as Array
		for i in range(owned_values.size()):
			owned.append(str(owned_values[i]))
	var pool: Array[CardData] = []
	var fallback_pool: Array[CardData] = []
	var max_rank := 10
	var player_weapon := ""
	if player != null and player.data != null:
		max_rank = ShoushiComboRules.max_rank_for_realm(player.session_realm)
		player_weapon = player.data.weapon_name
	for template: CardData in reward_pool:
		var card: CardData = template.duplicate_card()
		fallback_pool.append(card)
		var style_ok := player_weapon.is_empty() or card.weapon_style.is_empty() or card.weapon_style == "通用" or player_weapon.find(card.weapon_style) >= 0
		if card.shoushi_rank <= max_rank and style_ok and not card.has_tag("兼容") and not (card.id in owned):
			pool.append(card)
	if pool.is_empty():
		for card in fallback_pool:
			if not card.has_tag("兼容"):
				pool.append(card)
	if pool.is_empty():
		pool = fallback_pool
	pool.shuffle()
	var selected: Array[CardData] = []
	var selected_count: int = mini(count, pool.size())
	for i in range(selected_count):
		selected.append(pool[i])
	return selected


func _select_battle_reward_card(card_id: String) -> void:
	_selected_battle_reward_card_id = card_id
	_set_battle_result_body_text(_battle_result_body_text(true, card_id))
	if _battle_result_confirm_button != null:
		_battle_result_confirm_button.disabled = false
	for child: Node in battle_result_actions.get_children():
		if child is Button and child != _battle_result_confirm_button:
			var button: Button = child as Button
			button.disabled = false
			button.text = _battle_reward_button_text(button.text, card_id)
	if has_method("_apply_button_styles"):
		call("_apply_button_styles")


func _set_battle_result_body_text(text: String) -> void:
	if battle_result_body == null:
		return
	battle_result_body.text = text
	battle_result_body.visible = not text.is_empty()


func _battle_reward_button_text(current_text: String, selected_card_id: String) -> String:
	var clean: String = current_text.trim_prefix("✓ ")
	for card: CardData in _battle_reward_choices:
		if clean == card.short_summary():
			return "✓ %s" % clean if card.id == selected_card_id else clean
	return current_text


func _card_display_name(card_id: String) -> String:
	for card: CardData in _battle_reward_choices:
		if card.id == card_id:
			return card.display_name
	return card_id


func _has_generated_manifest_reward() -> bool:
	if battle_loadout.is_empty():
		return false
	if str(battle_loadout.get("loadout_source", "")) != "generated_manifest":
		return false
	if str(battle_loadout.get("reward_plan_id", "")).is_empty():
		return false
	var reward: Dictionary = battle_loadout.get("generated_reward", battle_loadout.get("reward_plan", {}))
	return not reward.is_empty()


func _active_generated_reward() -> Dictionary:
	if not _has_generated_manifest_reward():
		return {}
	return _dict(battle_loadout.get("generated_reward", battle_loadout.get("reward_plan", {})))


func _generated_reward_summary_text() -> String:
	var reward := _active_generated_reward()
	if reward.is_empty():
		return "无"
	var reward_type := str(reward.get("reward_type", "reward"))
	var item_texts: Array[String] = []
	for item_variant in reward.get("reward_items", []):
		if not (item_variant is Dictionary):
			continue
		var item: Dictionary = item_variant
		item_texts.append("%s x%s" % [str(item.get("item_id", "")), str(item.get("quantity", 1))])
	if item_texts.is_empty():
		return reward_type
	return "%s｜%s" % [reward_type, "，".join(item_texts)]


func _mark_generated_reward_visible(victory: bool) -> void:
	if not victory:
		return
	if not _has_generated_manifest_reward():
		return
	last_reward_source = "generated_manifest"
	last_reward_plan_id = str(battle_loadout.get("reward_plan_id", ""))
	last_generated_reward_visible = true


func _claim_generated_manifest_reward(result_key: String) -> void:
	if result_key != "win":
		return
	if not _has_generated_manifest_reward():
		return
	last_reward_source = "generated_manifest"
	last_reward_plan_id = str(battle_loadout.get("reward_plan_id", ""))
	last_generated_reward_claimed = true
	last_formal_progression_continues = true


func _append_generated_telemetry_event(result_key: String) -> void:
	last_telemetry_written = false
	last_telemetry_error = ""
	if battle_loadout.is_empty():
		return
	if str(battle_loadout.get("loadout_source", "")) != "generated_manifest":
		return
	var telemetry_path := ProjectSettings.globalize_path(AIGC_TELEMETRY_PATH)
	var telemetry_dir := telemetry_path.get_base_dir()
	var dir_result := DirAccess.make_dir_recursive_absolute(telemetry_dir)
	if dir_result != OK and not DirAccess.dir_exists_absolute(telemetry_dir):
		last_telemetry_error = "telemetry_dir_create_failed:%s" % telemetry_dir
		return
	var file := FileAccess.open(telemetry_path, FileAccess.READ_WRITE)
	if file == null:
		file = FileAccess.open(telemetry_path, FileAccess.WRITE_READ)
	if file == null:
		last_telemetry_error = "telemetry_open_failed:%s" % telemetry_path
		return
	file.seek_end()
	var event := {
		"timestamp": Time.get_datetime_string_from_system(true, true),
		"mechanic_profile_id": str(battle_loadout.get("mechanic_profile_id", "")),
		"content_pack_id": str(battle_loadout.get("content_pack_id", "")),
		"target_sequence_id": str(battle_loadout.get("target_sequence_id", "")),
		"formal_encounter_id": str(battle_loadout.get("encounter_id", "")),
		"formal_battle_id": str(battle_loadout.get("battle_id", "")),
		"generated_battle_slot_id": str(battle_loadout.get("generated_battle_slot_id", "")),
		"generated_deck_id": str(battle_loadout.get("generated_deck_id", "")),
		"reward_plan_id": str(battle_loadout.get("reward_plan_id", "")),
		"loadout_source": str(battle_loadout.get("loadout_source", "")),
		"encounter_tier": str(battle_loadout.get("encounter_tier", "")),
		"encounter_kind": str(battle_loadout.get("encounter_kind", "")),
		"sequence_position": int(battle_loadout.get("sequence_position", 0)),
		"deck_power_score": float(battle_loadout.get("deck_power_score", 0.0)),
		"target_power_min": int(battle_loadout.get("target_power_min", 0)),
		"target_power_max": int(battle_loadout.get("target_power_max", 0)),
		"runtime_primitives": (battle_loadout.get("runtime_primitives", []) as Array).duplicate(),
		"opening_pressure": _dict(battle_loadout.get("opening_pressure", {})),
		"clue_pressure": _dict(battle_loadout.get("clue_pressure", {})),
		"battle_result": result_key,
		"win": result_key == "win",
		"turn_count": _runtime_turn_count,
		"round_count": maxi(0, state_machine.round_index - 1) if state_machine != null else _runtime_turn_count,
		"cards_played_count": _runtime_cards_played_count,
		"enemy_cards_played_count": _runtime_enemy_cards_played_count,
		"player_cards_played": _runtime_player_card_ids_played.duplicate(),
		"enemy_cards_played": _runtime_enemy_card_ids_played.duplicate(),
		"damage_dealt": _runtime_damage_dealt,
		"damage_taken": _runtime_damage_taken,
		"block_gained": _runtime_block_gained,
		"momentum_gained": _runtime_momentum_gained,
		"momentum_broken": _runtime_momentum_broken,
		"player_hp_start": _runtime_player_hp_start,
		"player_hp_end": player.hp if player != null else -1,
		"enemy_hp_start": _runtime_enemy_hp_start,
		"enemy_hp_end": enemy.hp if enemy != null else -1,
		"reward_claimed": last_generated_reward_claimed,
		"return_flow_completed": last_formal_progression_continues,
		"weapon_followup_enabled": last_weapon_followup_enabled,
		"weapon_followup_triggered": last_weapon_followup_triggered,
		"weapon_followup_trigger_count": last_weapon_followup_trigger_count,
		"weapon_followup_bonus_total": last_weapon_followup_bonus_applied,
		"clue_pressure_enabled": last_clue_pressure_enabled,
		"clue_pressure_applied": last_clue_pressure_applied,
		"clue_pressure_trigger_count": last_clue_pressure_trigger_count,
		"clue_pressure_tags": last_clue_pressure_tags.duplicate(),
		"clue_pressure_effect": last_clue_pressure_effect,
		"clue_pressure_value": last_clue_pressure_value,
		"clue_pressure_converted_effect": last_clue_pressure_converted_effect,
		"player_wujing_cap": last_player_wujing_cap,
		"max_required_wujing": last_max_required_wujing,
		"max_closing_form_tier": last_max_closing_form_tier,
		"dual_weapon_enabled": last_dual_weapon_enabled,
		"weapon_loadout": last_weapon_loadout.duplicate(),
		"primary_weapon_style": last_primary_weapon_style,
		"secondary_weapon_style": last_secondary_weapon_style,
		"dual_weapon_synergy_count": last_dual_weapon_synergy_count,
		"telemetry_detail_level": "partial" if _runtime_turn_count > 0 else "minimal",
		"telemetry_source": "battle_controller_visual_story_return",
	}
	file.store_line(JSON.stringify(event))
	last_telemetry_written = true
	last_telemetry_path = telemetry_path
	last_telemetry_event_profile_id = str(event.get("mechanic_profile_id", ""))
	last_telemetry_event_battle_slot_id = str(event.get("generated_battle_slot_id", ""))
	last_telemetry_event_deck_id = str(event.get("generated_deck_id", ""))


func _on_intent_resolved(actor: Fighter, target: Fighter, intent: IntentData, feedback: Dictionary) -> void:
	super._on_intent_resolved(actor, target, intent, feedback)
	if actor == null or target == null or intent == null or intent.actual_card == null:
		return
	_runtime_turn_count += 1
	var is_player_actor := actor == player
	if is_player_actor:
		_runtime_cards_played_count += 1
		_runtime_player_card_ids_played.append(str(intent.actual_card.id))
		_runtime_damage_dealt += int(feedback.get("hp_damage", 0))
		_runtime_block_gained += maxi(intent.actual_card.guard, 0)
		_runtime_momentum_gained += maxi(intent.actual_card.gain_momentum, 0)
		_runtime_momentum_broken += maxi(intent.actual_card.break_momentum, 0)
	else:
		_runtime_enemy_cards_played_count += 1
		_runtime_enemy_card_ids_played.append(str(intent.actual_card.id))
		_runtime_damage_taken += int(feedback.get("hp_damage", 0))
	var side := "player" if is_player_actor else "enemy"
	_apply_pending_clue_pressure_runtime(side)
	_apply_weapon_followup_runtime(actor, target, intent.actual_card, side, feedback)


func _apply_pending_clue_pressure_runtime(side: String) -> void:
	if not last_clue_pressure_enabled or last_clue_pressure_applied:
		return
	if side == "player" and last_clue_pressure_trigger_timing == "first_player_action":
		_apply_clue_pressure_runtime_effect()
	elif side == "enemy" and last_clue_pressure_trigger_timing == "enemy_pressure_phase":
		_apply_clue_pressure_runtime_effect()
	if last_clue_pressure_applied and log_label != null:
		log_label.append_text("\n[color=#c8f7a6]线索破防触发：%s｜值=%d[/color]" % [last_clue_pressure_effect, last_clue_pressure_value])


func _apply_weapon_followup_runtime(actor: Fighter, target: Fighter, card: CardData, side: String, feedback: Dictionary) -> void:
	if not last_weapon_followup_enabled:
		var loadout_followup: Dictionary = _dict(battle_loadout.get("weapon_followup", {}))
		if bool(loadout_followup.get("enabled", false)):
			last_weapon_followup_enabled = true
			last_weapon_followup_expected_chain_count = int(loadout_followup.get("expected_chain_count", 0))
			last_weapon_followup_primary_weapon_style = str(loadout_followup.get("primary_weapon_style", ""))
			last_weapon_followup_pressure_level = str(loadout_followup.get("pressure_level", ""))
			for card_variant in battle_loadout.get("cards", []):
				if not (card_variant is Dictionary):
					continue
				var card_meta: Dictionary = card_variant
				var card_meta_id := str(card_meta.get("card_id", card_meta.get("id", "")))
				if card_meta_id.is_empty():
					continue
				_runtime_generated_card_meta[card_meta_id] = card_meta.duplicate(true)
	if not last_weapon_followup_enabled:
		return
	if card == null:
		return
	var card_id := str(card.id)
	var meta: Dictionary = _dict(_runtime_generated_card_meta.get(card_id, {}))
	if meta.is_empty():
		_runtime_last_card_by_side[side] = {
			"card_id": card_id,
			"weapon_style": str(card.weapon_style),
			"tags": card.tags.duplicate(),
		}
		return
	var trigger := str(meta.get("followup_trigger", ""))
	var previous_meta: Dictionary = _dict(_runtime_last_card_by_side.get(side, {}))
	var triggered := false
	if trigger == "same_weapon_previous_card":
		triggered = str(previous_meta.get("weapon_style", "")) == str(meta.get("weapon_style", ""))
	elif trigger == "":
		triggered = false
	if triggered:
		var bonus: Dictionary = _dict(meta.get("followup_bonus", {}))
		var applied_fields: Array = []
		var applied_bonus := {}
		var bonus_damage := int(bonus.get("bonus_damage", 0))
		var bonus_momentum := int(bonus.get("bonus_momentum", 0))
		var bonus_block := int(bonus.get("bonus_block", 0))
		if bonus_damage > 0 and bool(feedback.get("connected", true)):
			target.hp = maxi(target.hp - bonus_damage, 0)
			applied_fields.append("bonus_damage")
			applied_bonus["bonus_damage"] = bonus_damage
			if actor == player:
				_runtime_damage_dealt += bonus_damage
			else:
				_runtime_damage_taken += bonus_damage
		if bonus_momentum > 0:
			actor.recover_momentum(bonus_momentum)
			applied_fields.append("bonus_momentum")
			applied_bonus["bonus_momentum"] = bonus_momentum
			_runtime_momentum_gained += bonus_momentum
		if bonus_block > 0:
			actor.add_guard(bonus_block)
			applied_fields.append("bonus_block")
			applied_bonus["bonus_block"] = bonus_block
			_runtime_block_gained += bonus_block
		if not applied_fields.is_empty():
			last_weapon_followup_triggered = true
			last_weapon_followup_trigger_count += 1
			last_weapon_followup_bonus_applied = applied_bonus
			last_weapon_followup_applied_fields = applied_fields
			last_weapon_followup_card_id = card_id
			last_weapon_followup_group = str(meta.get("followup_group", ""))
			last_weapon_followup_trigger = trigger
			if log_label != null:
				log_label.append_text("\n[color=#8fd3ff]武器追击触发：%s｜%s[/color]" % [card.display_name, ",".join(applied_fields)])
			_refresh_ui()
	_runtime_last_card_by_side[side] = {
		"card_id": card_id,
		"weapon_style": str(meta.get("weapon_style", card.weapon_style)),
		"tags": (meta.get("tags", []) as Array).duplicate(),
	}


func _on_battle_result_confirm_pressed() -> void:
	_hide_battle_result_overlay()
	var result_text: String = "战斗胜利"
	var result_key: String = "win"
	if player != null and enemy != null and player.hp <= 0 and enemy.hp <= 0:
		result_text = "两败俱伤"
		result_key = "draw"
	if _story_encounter_selected:
		if log_label != null:
			log_label.append_text("\n[color=#8fd3ff]%s，返回战斗测试。[/color]" % result_text)
		_show_combat_banner("%s，返回战斗测试" % result_text, Color("1c2a36"), Color("8fd3ff"))
		_reset_story_battle_runtime_state()
		_show_story_encounter_selection()
		_returning_to_story_selection = false
		return
	if NarrativeBattleContext.has_request():
		if log_label != null:
			log_label.append_text("\n[color=#8fd3ff]%s，返回剧情流程。[/color]" % result_text)
		_show_combat_banner("%s，返回剧情" % result_text, Color("1c2a36"), Color("8fd3ff"))
		await get_tree().create_timer(0.35).timeout
		var source_scene: String = NarrativeBattleContext.source_scene
		if source_scene.is_empty():
			source_scene = "res://scenes/NarrativeDemo.tscn"
		_claim_generated_manifest_reward(result_key)
		_append_generated_telemetry_event(result_key)
		if result_key == "win" and not _selected_battle_reward_card_id.is_empty():
			NarrativeBattleContext.grant_player_cards([_selected_battle_reward_card_id])
		NarrativeBattleContext.set_result(result_key)
		get_tree().change_scene_to_file(source_scene)
		return
	if log_label != null:
		log_label.append_text("\n[color=#8fd3ff]%s，返回战斗测试。[/color]" % result_text)
	_show_combat_banner("%s，返回地图" % result_text, Color("1c2a36"), Color("8fd3ff"))
	_reset_story_battle_runtime_state()
	_show_story_encounter_selection()
	_returning_to_story_selection = false


func _on_battle_retry_confirm_pressed() -> void:
	_hide_battle_result_overlay()
	_returning_to_story_selection = false
	_reactive_pre_move_round = -1
	_reactive_pre_move_animation_round = -1
	_reactive_pre_move_animating = false
	_last_edge_positions = {}
	_break_resist_available = _pressure_profile == PRESSURE_BREAK_RESIST
	_start_battle()


func _return_to_story_encounter_selection_after_battle() -> void:
	var result_text: String = "战斗结束"
	var result_key: String = "draw"
	if player != null and enemy != null:
		if enemy.hp <= 0 and player.hp > 0:
			result_text = "战斗胜利"
			result_key = "win"
		elif player.hp <= 0 and enemy.hp > 0:
			result_text = "战斗失败"
			result_key = "lose"
		else:
			result_text = "两败俱伤"
			result_key = "draw"
	while _presentation_busy():
		await get_tree().create_timer(0.05).timeout
	await get_tree().create_timer(0.15).timeout
	if _story_encounter_selected:
		if log_label != null:
			log_label.append_text("\n[color=#8fd3ff]%s，返回战斗测试。[/color]" % result_text)
		_show_combat_banner("%s，返回战斗测试" % result_text, Color("1c2a36"), Color("8fd3ff"))
		_reset_story_battle_runtime_state()
		_show_story_encounter_selection()
		_returning_to_story_selection = false
		return
	if NarrativeBattleContext.has_request():
		if log_label != null:
			log_label.append_text("\n[color=#8fd3ff]%s，返回剧情流程。[/color]" % result_text)
		_show_combat_banner("%s，返回剧情" % result_text, Color("1c2a36"), Color("8fd3ff"))
		await get_tree().create_timer(0.45).timeout
		var source_scene: String = NarrativeBattleContext.source_scene
		if source_scene.is_empty():
			source_scene = "res://scenes/NarrativeDemo.tscn"
		NarrativeBattleContext.set_result(result_key)
		get_tree().change_scene_to_file(source_scene)
		return
	if log_label != null:
		log_label.append_text("\n[color=#8fd3ff]%s，返回剧情遭遇选择。[/color]" % result_text)
	_show_combat_banner("%s，返回地图" % result_text, Color("1c2a36"), Color("8fd3ff"))
	_reset_story_battle_runtime_state()
	_show_story_encounter_selection()
	_returning_to_story_selection = false


func _reset_story_battle_runtime_state() -> void:
	battle_active = false
	awaiting_player_input = false
	player_role_id = ""
	_story_encounter_selected = false
	_reactive_pre_move_round = -1
	_pending_story_battle = {}
	_pressure_profile = PRESSURE_NONE
	_break_resist_available = false
	_last_edge_positions = {}
	player_intent = null
	enemy_intent = null
	draft_player_intent = null
	draft_player_position = -1
	draft_player_facing = ""
	draft_player_has_position = false
	declaration_order = PackedStringArray()
	declaration_index = 0
	fusion_first_index = -1
	state_machine.reset_for_session()
