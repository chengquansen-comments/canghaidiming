extends "res://scripts/battle_controller_visual_presentation_stepwise.gd"

# Thin runtime wrapper for story-battle selection and settlement-mode switching.
#
# Opening flow: story encounter -> battle.
# The encounter decides player template/deck/stat, opponent template/deck/stat,
# and settlement mode. Templates/decks/stats do not encode enemy/player identity;
# only encounter assigns sides.
# F8 still toggles settlement mode during local testing.

const StoryBattleLoader = preload("res://scripts/story_battle_loader.gd")

@export var story_encounter_id: String = "prologue_beach_teach"
@export_enum("symmetric", "reactive") var settlement_mode_id: String = "symmetric"

var _story_encounter_selected := false
var _reactive_pre_move_round := -1
var _story_encounters: Array[Dictionary] = []
var _pending_story_battle: Dictionary = {}
var _story_validation_report: Dictionary = {}


func _ready() -> void:
	super()
	var card_catalog: Dictionary = _build_story_card_catalog()
	_story_validation_report = StoryBattleLoader.validate_all(card_catalog)
	print(StoryBattleLoader.format_validation_report(_story_validation_report))
	_story_encounters = StoryBattleLoader.load_encounters()
	_apply_visual_settlement_mode()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F8:
			toggle_visual_settlement_mode()
			get_viewport().set_input_as_handled()
			return


func _show_role_selection() -> void:
	if not _story_encounter_selected:
		_show_story_encounter_selection()
		return
	_start_selected_story_encounter()


func _show_story_encounter_selection() -> void:
	battle_active = false
	awaiting_player_input = false
	player_role_id = ""
	_pending_story_battle = {}
	if _story_encounters.is_empty():
		_story_encounters = StoryBattleLoader.load_encounters()
	if overlay_scrim != null:
		overlay_scrim.visible = true
	if overlay_panel != null:
		overlay_panel.visible = true
	if overlay_title != null:
		overlay_title.text = "选择剧情遭遇"
	if overlay_body != null:
		var validation_text := ""
		if not _story_validation_report.is_empty():
			validation_text = "\n\n配置校验：%s" % ("通过" if bool(_story_validation_report.get("ok", false)) else "存在错误，请看控制台")
		overlay_body.text = "剧情遭遇会自动决定：\n- 玩家模板 / 玩家剧情卡组 / 玩家数值\n- 对手模板 / 对手剧情卡组 / 对手数值\n- 结算模式\n\n模板、卡组、数值本身不区分敌我，只有遭遇配置分配双方。" + validation_text
	_clear_overlay_actions()
	for row: Dictionary in _story_encounters:
		_add_story_encounter_button(row)


func _clear_overlay_actions() -> void:
	if overlay_actions == null:
		return
	for child in overlay_actions.get_children():
		child.queue_free()


func _add_story_encounter_button(row: Dictionary) -> void:
	if overlay_actions == null:
		return
	var selected_id: String = str(row.get("encounter_id", ""))
	if selected_id == "":
		return
	var display_name: String = str(row.get("display_name", selected_id))
	var mode: String = str(row.get("settlement_mode", "symmetric"))
	var notes: String = str(row.get("notes", ""))
	var button := Button.new()
	button.text = "%s（%s）" % [display_name, mode]
	if notes != "":
		button.tooltip_text = notes
	button.pressed.connect(func() -> void:
		_select_story_encounter_and_start(selected_id)
	)
	overlay_actions.add_child(button)


func _select_story_encounter_and_start(encounter_id: String) -> void:
	story_encounter_id = encounter_id
	_story_encounter_selected = true
	_reactive_pre_move_round = -1
	var card_catalog: Dictionary = _build_story_card_catalog()
	_pending_story_battle = StoryBattleLoader.build_story_battle(story_encounter_id, card_catalog)
	if _pending_story_battle.is_empty():
		push_warning("Story encounter failed to load: %s" % story_encounter_id)
		_story_encounter_selected = false
		_show_story_encounter_selection()
		return
	settlement_mode_id = str(_pending_story_battle.get("settlement_mode", "symmetric"))
	_apply_visual_settlement_mode()
	var encounter: Dictionary = _pending_story_battle.get("encounter", {})
	_show_combat_banner("剧情遭遇：%s" % str(encounter.get("display_name", story_encounter_id)), Color("1c2a36"), Color("8fd3ff"))
	_start_selected_story_encounter()


func _start_selected_story_encounter() -> void:
	if _pending_story_battle.is_empty():
		var card_catalog: Dictionary = _build_story_card_catalog()
		_pending_story_battle = StoryBattleLoader.build_story_battle(story_encounter_id, card_catalog)
		if _pending_story_battle.is_empty():
			_show_story_encounter_selection()
			return
	var encounter: Dictionary = _pending_story_battle.get("encounter", {})
	var role_id: String = _core_role_id_for_template(str(encounter.get("player_template_id", "player_blademaster")))
	super._select_role_and_start(role_id)
	_apply_selected_story_battle_to_current_battle()


func _apply_selected_story_battle_to_current_battle() -> void:
	if _pending_story_battle.is_empty():
		return
	var player_data: FighterData = _pending_story_battle.get("player_data", null)
	var opponent_data: FighterData = _pending_story_battle.get("opponent_data", null)
	var encounter: Dictionary = _pending_story_battle.get("encounter", {})
	if player_data == null or opponent_data == null:
		push_warning("Story encounter has null fighter data: %s" % story_encounter_id)
		return
	if player_data.starting_deck.is_empty() and player != null and player.data != null:
		player_data.starting_deck = player.data.clone_deck()
	if opponent_data.starting_deck.is_empty() and enemy != null and enemy.data != null:
		opponent_data.starting_deck = enemy.data.clone_deck()
	player = Fighter.new(player_data)
	player.set_session_realm(player_data.starting_realm)
	player.reset_for_battle(HAND_SIZE)
	enemy = Fighter.new(opponent_data)
	enemy.set_session_realm(opponent_data.starting_realm)
	enemy.reset_for_battle(HAND_SIZE)
	settlement_mode_id = str(_pending_story_battle.get("settlement_mode", settlement_mode_id))
	_apply_visual_settlement_mode()
	state_machine.update_distance_from_positions(player, enemy)
	if log_label != null:
		log_label.append_text("\n[color=#8fd3ff]已加载剧情遭遇：%s → 我方 %s / 对手 %s / 模式 %s[/color]" % [str(encounter.get("display_name", story_encounter_id)), player_data.display_name, opponent_data.display_name, settlement_mode_id])
	_refresh_ui()


func _build_story_card_catalog() -> Dictionary:
	var catalog: Dictionary = {}
	for fighter_id in fighter_catalog.keys():
		var data: FighterData = fighter_catalog[fighter_id]
		for card: CardData in data.starting_deck:
			catalog[card.id] = card
	for card: CardData in reward_pool:
		catalog[card.id] = card
	return catalog


func _core_role_id_for_template(template_id: String) -> String:
	if template_id.find("spear") >= 0 or template_id == "master_veteran":
		return "spearman"
	return "blademaster"


func set_visual_settlement_mode(value: String) -> void:
	settlement_mode_id = value
	_reactive_pre_move_round = -1
	_apply_visual_settlement_mode()
	_show_combat_banner("结算模式：%s" % ("反应式" if settlement_mode_id == BattleStateMachine.MODE_REACTIVE_ID else "对称式"), Color("1c2a36") if settlement_mode_id == BattleStateMachine.MODE_REACTIVE_ID else Color("2a2018"), Color("8fd3ff") if settlement_mode_id == BattleStateMachine.MODE_REACTIVE_ID else Color("ffd479"))
	_refresh_ui()


func toggle_visual_settlement_mode() -> void:
	if settlement_mode_id == BattleStateMachine.MODE_REACTIVE_ID:
		set_visual_settlement_mode(BattleStateMachine.MODE_SYMMETRIC_ID)
	else:
		set_visual_settlement_mode(BattleStateMachine.MODE_REACTIVE_ID)


func _apply_visual_settlement_mode() -> void:
	if state_machine == null:
		return
	state_machine.set_settlement_mode_id(settlement_mode_id)
	print("[settlement-mode] ", state_machine.settlement_mode_id())


func _try_apply_reactive_enemy_pre_move() -> void:
	if state_machine == null or not state_machine.is_reactive_mode():
		return
	if not battle_active or not awaiting_player_input:
		return
	if enemy == null or enemy_intent == null:
		return
	if _reactive_pre_move_round == state_machine.round_index:
		return
	if enemy_intent.target_position < 0:
		return
	var from_position: int = enemy.position
	var from_facing: String = enemy.facing
	var to_position: int = clampi(enemy_intent.target_position, 0, BATTLE_SLOT_COUNT - 1)
	var to_facing: String = enemy_intent.target_facing if enemy_intent.target_facing != "" else enemy.facing
	enemy.position = to_position
	enemy.facing = "left" if to_facing == "left" else "right"
	enemy_intent.set_stance(enemy.position, enemy.facing)
	state_machine.update_distance_from_positions(player, enemy)
	_reactive_pre_move_round = state_machine.round_index
	if log_label != null and (from_position != enemy.position or from_facing != enemy.facing):
		log_label.append_text("\n[color=#8fd3ff]反应式：敌方先移动 %s → %s，并亮出攻击意图。[/color]" % [_slot_label_safe(from_position), _slot_label_safe(enemy.position)])
	_show_combat_banner("敌方先移动，亮出威胁", Color("1c2a36"), Color("8fd3ff"))


func _slot_label_safe(slot: int) -> String:
	var labels := ["零位", "一位", "二位", "三位", "四位", "五位", "六位", "七位", "八位"]
	if slot >= 0 and slot < labels.size():
		return labels[slot]
	return "%d位" % slot


func _mode_status_suffix() -> String:
	if state_machine == null:
		return ""
	var text := "\n剧情遭遇：%s" % story_encounter_id
	text += "\n结算模式：%s（%s）" % [state_machine.settlement_mode_label(), state_machine.settlement_mode_id()]
	text += "\n快捷键：F8 切换结算模式"
	if state_machine.is_reactive_mode():
		text += "\n反应式规则：敌方先移动并亮意图；玩家响应后先结算；若打出崩势，敌方本回合攻击中断。"
	return text


func _reactive_threat_preview_text() -> String:
	if state_machine == null or not state_machine.is_reactive_mode():
		return ""
	if player == null or enemy == null or enemy_intent == null:
		return ""
	var result: Dictionary = _reactive_resolution_preview()
	var enemy_card: CardData = enemy_intent.actual_card
	var player_card: CardData = draft_player_intent.actual_card if draft_player_intent != null else null
	var lines: Array[String] = []
	lines.append("\n[font_size=18][b]反应式威胁摘要[/b][/font_size]")
	lines.append("敌方已落位：%s，当前距离 %d" % [_slot_label_safe(enemy.position), int(result.get("initial_distance", 0))])
	lines.append("我方响应：%s / %s / 伤%d / 势-%d" % [player_card.display_name if player_card != null else "未选招式", _range_text_safe(str(result.get("player_range", CombatResolver.RANGE_NONE))), int(result.get("player_damage", 0)), int(result.get("player_break", 0))])
	if bool(result.get("will_interrupt", false)):
		lines.append("敌方威胁：%s / 已被崩势打断" % (enemy_card.display_name if enemy_card != null else "无"))
		lines.append("结果重点：预计打出崩势，敌方本回合攻击中断。")
	else:
		lines.append("敌方威胁：%s / %s / 伤%d / 势-%d / 结算距离 %d" % [enemy_card.display_name if enemy_card != null else "无", _range_text_safe(str(result.get("enemy_range_after_player", CombatResolver.RANGE_NONE))), int(result.get("enemy_damage", 0)), int(result.get("enemy_break", 0)), int(result.get("final_distance_before_enemy", 0))])
		lines.append("结果重点：敌方将基于我方响应后的最终站位重新判定命中。")
	lines.append("最终预估：我方 %s；敌方 %s" % [_slot_label_safe(int(result.get("player_after_player_action", player.position))), _slot_label_safe(int(result.get("enemy_after_player_action", enemy.position)))])
	return "\n".join(lines)


func _reactive_resolution_preview() -> Dictionary:
	var enemy_card: CardData = enemy_intent.actual_card if enemy_intent != null else null
	var player_card: CardData = draft_player_intent.actual_card if draft_player_intent != null else null
	var player_pos: int = _reactive_player_preview_position()
	var player_facing: String = _reactive_player_preview_facing(player_pos)
	var player_after: int = player_pos
	var enemy_after: int = enemy.position
	var player_range: String = CombatResolver.RANGE_NONE
	var enemy_range_after_player: String = CombatResolver.RANGE_NONE
	var will_interrupt := false
	var player_damage := 0
	var player_break := 0
	var enemy_damage := 0
	var enemy_break := 0
	if player_card != null:
		var player_state := {"hp": player.hp, "momentum": player.momentum, "guard": player.guard_points, "position": player_pos, "facing": player_facing, "broken": player.is_broken()}
		var enemy_state := {"hp": enemy.hp, "momentum": enemy.momentum, "guard": enemy.guard_points, "position": enemy.position, "facing": enemy.facing, "broken": enemy.is_broken()}
		var sim: Dictionary = CombatResolver.resolve_exchange(player_state, enemy_state, player_card, null, ["player"])
		var enemy_hp_delta: int = int(sim.get("enemy_hp_delta", 0))
		var enemy_momentum_delta: int = int(sim.get("enemy_momentum_delta", 0))
		player_damage = absi(enemy_hp_delta) if enemy_hp_delta < 0 else 0
		player_break = absi(enemy_momentum_delta) if enemy_momentum_delta < 0 else 0
		player_range = str(sim.get("player_range_result", CombatResolver.RANGE_NONE))
		player_after = int(sim.get("player_final", player_pos))
		enemy_after = int(sim.get("enemy_final", enemy.position))
		will_interrupt = enemy.momentum > 0 and enemy.momentum + enemy_momentum_delta <= 0
	if enemy_card != null and not will_interrupt:
		var enemy_state_after := {"hp": enemy.hp, "momentum": enemy.momentum, "guard": enemy.guard_points, "position": enemy_after, "facing": enemy.facing, "broken": enemy.is_broken()}
		var player_state_after := {"hp": player.hp, "momentum": player.momentum, "guard": player.guard_points, "position": player_after, "facing": player_facing, "broken": player.is_broken()}
		var enemy_sim: Dictionary = CombatResolver.resolve_exchange(enemy_state_after, player_state_after, enemy_card, null, ["player"])
		var player_hp_delta: int = int(enemy_sim.get("enemy_hp_delta", 0))
		var player_momentum_delta: int = int(enemy_sim.get("enemy_momentum_delta", 0))
		enemy_damage = absi(player_hp_delta) if player_hp_delta < 0 else 0
		enemy_break = absi(player_momentum_delta) if player_momentum_delta < 0 else 0
		enemy_range_after_player = str(enemy_sim.get("player_range_result", CombatResolver.RANGE_NONE))
	return {
		"initial_distance": absi(enemy.position - player.position),
		"player_range": player_range,
		"player_damage": player_damage,
		"player_break": player_break,
		"will_interrupt": will_interrupt,
		"player_after_player_action": player_after,
		"enemy_after_player_action": enemy_after,
		"enemy_range_after_player": enemy_range_after_player,
		"enemy_damage": enemy_damage,
		"enemy_break": enemy_break,
		"final_distance_before_enemy": absi(enemy_after - player_after)
	}


func _reactive_player_preview_position() -> int:
	if draft_player_has_position:
		return clampi(draft_player_position, 0, BATTLE_SLOT_COUNT - 1)
	return player.position


func _reactive_player_preview_facing(_player_pos: int) -> String:
	if draft_player_facing != "":
		return draft_player_facing
	return player.facing


func _range_text_safe(range_result: String) -> String:
	match range_result:
		CombatResolver.RANGE_HIT:
			return "命中"
		CombatResolver.RANGE_GRAZE:
			return "擦中"
		CombatResolver.RANGE_MISS_FACING:
			return "朝向未中"
		CombatResolver.RANGE_MISS_RANGE:
			return "距离未中"
		_:
			return "无"


func _refresh_ui() -> void:
	_try_apply_reactive_enemy_pre_move()
	super()
	if status_label != null and state_machine != null:
		status_label.append_text(_mode_status_suffix())
	if preview_label != null:
		preview_label.append_text(_reactive_threat_preview_text())
