extends "res://scripts/battle_controller_demo_visual.gd"

# Dedicated visual battle controller entry.
# This keeps the current demo presentation path explicit and separate
# from the pure text debugging entry, while delegating reusable concerns
# to helper scripts under scripts/visual/.

const BattleSkinHelper = preload("res://scripts/visual/battle_skin.gd")
const BattleStageHelper = preload("res://scripts/visual/battle_stage_view.gd")
const BattleHudHelper = preload("res://scripts/visual/battle_hud_view.gd")
const BattleFxPool = preload("res://scripts/visual/battle_fx_pool.gd")
const WebRuntimeFlags = preload("res://scripts/web_runtime_flags.gd")
const WEB_SMOKE_BATTLE_FLAG := "smoke_battle"
const VISUAL_POLL_REFRESH_INTERVAL := 0.12
const BUTTON_STYLE_META := &"visual_button_style_applied"

var _visual_poll_refresh_elapsed := 0.0
var _fx_pool := BattleFxPool.new()
var _stage_grid_signature := ""
var _stage_actor_signature := ""
var _hud_signature := ""
var _player_intent_bubble_signature := ""
var _enemy_intent_bubble_signature := ""
var _range_trapezoid_pool: Array[Dictionary] = []
var _hand_buttons_signature := ""
var _node_buttons_signature := ""
var _overlay_action_buttons: Array[Button] = []

func _ready() -> void:
	super()
	_fx_pool.set_parent(center_fx_layer if center_fx_layer != null else self)
	_mark_web_smoke_battle_state("visual-ready")
	if WebRuntimeFlags.has_query_flag(WEB_SMOKE_BATTLE_FLAG):
		call_deferred("_bootstrap_web_smoke_battle")

func _safe_load_texture(path: String) -> Texture2D:
	return BattleSkinHelper.load_texture_or_svg(path)

func _make_demo_panel_style(fill: Color, border: Color) -> StyleBox:
	return BattleSkinHelper.make_visual_panel_style(fill, border, PANEL_FRAME_PATH)

func _make_button_style(tint: Color) -> StyleBox:
	return BattleSkinHelper.make_button_style(tint, BUTTON_FRAME_PATH, PANEL_FRAME_PATH)

func _bootstrap_web_smoke_battle() -> void:
	if player == null:
		_mark_web_smoke_battle_state("session-starting")
		_start_session("spearman")
	if not battle_active:
		_mark_web_smoke_battle_state("battle-starting")
		_start_battle()
	_mark_web_smoke_battle_state("battle-ready")

func _mark_web_smoke_battle_state(state: String) -> void:
	WebRuntimeFlags.set_body_dataset("webSmokeBattle", state)

func _build_catalog() -> void:
	BattleHudHelper.clear_text_cache()
	super()

func _refresh_ui() -> void:
	super()
	_refresh_visual_ui()

func _show_node_buttons() -> void:
	var signature := _node_buttons_state_signature()
	if signature == _node_buttons_signature:
		return
	_node_buttons_signature = signature
	super()

func _show_overlay(title: String, body: String, actions: Array) -> void:
	if overlay_title == null or overlay_body == null or overlay_actions == null:
		return
	overlay_title.text = title
	overlay_body.text = body
	for i in range(actions.size()):
		var action: Dictionary = actions[i]
		var button := _overlay_action_button(i)
		_disconnect_button_pressed(button)
		button.text = str(action["text"]) if action.has("text") else ""
		var callback: Callable = action["callback"] if action.has("callback") else Callable()
		if callback.is_valid():
			button.pressed.connect(callback)
		button.disabled = false
		button.visible = true
	for i in range(actions.size(), _overlay_action_buttons.size()):
		var button := _overlay_action_buttons[i]
		_disconnect_button_pressed(button)
		button.visible = false
	if overlay_scrim != null:
		overlay_scrim.visible = true
		overlay_scrim.move_to_front()
	if overlay_panel != null:
		overlay_panel.visible = true
		overlay_panel.move_to_front()
	_apply_button_styles()

func _overlay_action_button(index: int) -> Button:
	while _overlay_action_buttons.size() <= index:
		var button := Button.new()
		button.visible = false
		overlay_actions.add_child(button)
		_overlay_action_buttons.append(button)
	return _overlay_action_buttons[index]

func _disconnect_button_pressed(button: Button) -> void:
	for connection in button.pressed.get_connections():
		var connection_data: Dictionary = connection
		if not connection_data.has("callable"):
			continue
		var callable: Callable = connection_data["callable"]
		if callable.is_valid() and button.pressed.is_connected(callable):
			button.pressed.disconnect(callable)

func _apply_button_styles() -> void:
	var groups: Array = [
		[deck_button, reset_pick_button, confirm_button],
		node_buttons_box.get_children() if node_buttons_box != null else [],
		overlay_actions.get_children() if overlay_actions != null else []
	]
	for group in groups:
		for child in group:
			if child is Button:
				_style_plain_button_once(child)

func _style_plain_button_once(button: Button) -> void:
	if button.has_meta(BUTTON_STYLE_META):
		return
	_style_button(button)
	button.set_meta(BUTTON_STYLE_META, true)

func _start_session(role_id: String) -> void:
	BattleHudHelper.clear_text_cache()
	super(role_id)

func _finish_battle() -> void:
	BattleHudHelper.clear_text_cache()
	super()

func _refresh_visual_ui() -> void:
	var has_session := player != null and enemy != null
	_set_battle_chrome_visible(has_session)
	if not has_session:
		BattleHudHelper.clear_text_cache()
		_stage_grid_signature = ""
		_stage_actor_signature = ""
		_hud_signature = ""
		_player_intent_bubble_signature = ""
		_enemy_intent_bubble_signature = ""
		_hand_buttons_signature = ""
		_node_buttons_signature = ""
		_clear_range_trapezoids()
		_apply_button_styles()
		return
	_refresh_character_visuals()
	_refresh_hud_bars(true)
	_refresh_center_labels()
	_refresh_stage_grid(true)
	_refresh_stage_actor_positions(true)
	_refresh_intent_bubbles(true)
	_refresh_card_detail_panel()
	_refresh_effect_preview_panel()
	_refresh_log_strip()
	_refresh_hand_buttons()
	_apply_button_styles()

func _set_battle_chrome_visible(visible: bool) -> void:
	if top_hud != null:
		top_hud.visible = visible
	if center_hud != null:
		center_hud.visible = visible
	if bottom_backdrop != null:
		bottom_backdrop.visible = visible
	if bottom_root != null:
		bottom_root.visible = visible
	if stage_area_frame != null:
		stage_area_frame.visible = visible
	if stage_grid_box != null:
		stage_grid_box.visible = visible
	if stage_slot_label_box != null:
		stage_slot_label_box.visible = visible
	if player_sprite != null:
		player_sprite.visible = visible
	if enemy_sprite != null:
		enemy_sprite.visible = visible
	if player_fallback_actor != null:
		player_fallback_actor.visible = visible and player_fallback_actor.visible
	if enemy_fallback_actor != null:
		enemy_fallback_actor.visible = visible and enemy_fallback_actor.visible

func _clear_range_trapezoids() -> void:
	_stage_grid_signature = ""
	if range_overlay_layer == null:
		return
	for entry in _range_trapezoid_pool:
		var polygon: Polygon2D = entry.get("polygon", null)
		var outline: Line2D = entry.get("outline", null)
		if polygon != null:
			polygon.visible = false
		if outline != null:
			outline.visible = false

func _refresh_center_labels() -> void:
	if round_label != null:
		round_label.text = "师门决斗"
	if phase_label != null:
		if battle_active:
			phase_label.text = "第 %d 回合" % state_machine.round_index
		else:
			phase_label.text = "月下试剑"

func _refresh_log_strip() -> void:
	if battle_log_strip == null:
		return
	var logs := _recent_logs()
	if logs.is_empty():
		battle_log_strip.text = "日志待命"
	else:
		battle_log_strip.text = logs[logs.size() - 1].replace("[b]", "").replace("[/b]", "")

func _refresh_character_visuals() -> void:
	player_sheet_source = _sheet_source_for(player, false)
	enemy_sheet_source = _sheet_source_for(enemy, true)
	var player_sheet := _sheet_frame_texture(player_sheet_source, 0)
	var enemy_sheet := _sheet_frame_texture(enemy_sheet_source, 0)
	if player_sprite != null:
		player_sprite.texture = player_sheet
		player_sprite.modulate = Color(0.92, 0.95, 1.0, 0.96)
	if enemy_sprite != null:
		enemy_sprite.texture = enemy_sheet
		enemy_sprite.modulate = Color(0.78, 0.82, 0.92, 0.94)
	if player_fallback_actor != null:
		player_fallback_actor.visible = player_sheet == null
		player_fallback_actor.modulate = Color(0.88, 0.92, 1.0, 0.94)
	if enemy_fallback_actor != null:
		enemy_fallback_actor.visible = enemy_sheet == null
		enemy_fallback_actor.modulate = Color(0.7, 0.75, 0.88, 0.92)
	var player_portrait := _portrait_texture_for(player)
	var enemy_portrait := _portrait_texture_for(enemy)
	if player_avatar != null:
		player_avatar.texture = player_portrait
	if enemy_avatar != null:
		enemy_avatar.texture = enemy_portrait
	if player_avatar_fallback != null:
		player_avatar_fallback.visible = player_portrait == null
	if enemy_avatar_fallback != null:
		enemy_avatar_fallback.visible = enemy_portrait == null
	if player_name_label != null:
		player_name_label.text = player.data.display_name if player != null else "玩家"
	if enemy_name_label != null:
		enemy_name_label.text = enemy.data.display_name if enemy != null else "敌方"
	if player_school_label != null:
		player_school_label.text = SCHOOL_NAME if player != null else ""
	if enemy_school_label != null:
		enemy_school_label.text = SCHOOL_NAME if enemy != null else ""

func _refresh_hud_bars(force: bool = false) -> void:
	var signature := _hud_state_signature()
	if not force and signature == _hud_signature:
		return
	_hud_signature = signature
	if player != null and player_hp_fill != null and player_hp_bg != null:
		var player_hp_width := player_hp_bg.size.x if player_hp_bg.size.x > 1.0 else HUD_BAR_WIDTH
		player_hp_fill.size = Vector2(player_hp_width * clamp(float(player.hp) / max(1.0, float(player.data.max_hp)), 0.0, 1.0), player_hp_bg.size.y if player_hp_bg.size.y > 0.0 else 14.0)
		if player_hp_value_label != null:
			player_hp_value_label.text = "%d / %d" % [player.hp, player.data.max_hp]
		_refresh_momentum_dots(player_momentum_dots, player.momentum, player.data.max_momentum)
	if enemy != null and enemy_hp_fill != null and enemy_hp_bg != null:
		var enemy_hp_width := enemy_hp_bg.size.x if enemy_hp_bg.size.x > 1.0 else HUD_BAR_WIDTH
		enemy_hp_fill.size = Vector2(enemy_hp_width * clamp(float(enemy.hp) / max(1.0, float(enemy.data.max_hp)), 0.0, 1.0), enemy_hp_bg.size.y if enemy_hp_bg.size.y > 0.0 else 14.0)
		if enemy_hp_value_label != null:
			enemy_hp_value_label.text = "%d / %d" % [enemy.hp, enemy.data.max_hp]
		_refresh_momentum_dots(enemy_momentum_dots, enemy.momentum, enemy.data.max_momentum)

func _hud_state_signature() -> String:
	if player == null or enemy == null:
		return "no-session"
	var player_hp_width := int(round(player_hp_bg.size.x)) if player_hp_bg != null else 0
	var enemy_hp_width := int(round(enemy_hp_bg.size.x)) if enemy_hp_bg != null else 0
	return "%d|%d|%d|%d|%d|%d|%d|%d|%d|%d" % [
		player.hp,
		player.data.max_hp,
		player.momentum,
		player.data.max_momentum,
		player_hp_width,
		enemy.hp,
		enemy.data.max_hp,
		enemy.momentum,
		enemy.data.max_momentum,
		enemy_hp_width
	]

func _refresh_momentum_dots(container: HBoxContainer, current: int, maximum: int) -> void:
	if container == null:
		return
	var safe_max := clampi(maximum, 1, 12)
	if container.get_child_count() != safe_max:
		for child in container.get_children():
			child.free()
		for i in range(safe_max):
			var dot := PanelContainer.new()
			dot.custom_minimum_size = Vector2(19, 19)
			dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
			container.add_child(dot)
	for i in range(container.get_child_count()):
		var dot := container.get_child(i)
		if dot is PanelContainer:
			dot.add_theme_stylebox_override("panel", _make_momentum_dot_style(i < current))

func _grid_total_width() -> float:
	return BattleStageHelper.grid_total_width(GRID_SLOT_COUNT, GRID_SLOT_WIDTH, GRID_SLOT_GAP)

func _slot_center_x(slot: int) -> float:
	return BattleStageHelper.slot_center_x(size.x, slot, GRID_SLOT_COUNT, GRID_SLOT_WIDTH, GRID_SLOT_GAP)

func _slot_top_left(slot: int, is_player: bool) -> Vector2:
	return BattleStageHelper.slot_top_left(size.x, slot, is_player, GRID_SLOT_COUNT, GRID_SLOT_WIDTH, GRID_SLOT_GAP, STAGE_GROUND_Y, player_sprite.size.y, PLAYER_FOOT_OFFSET_X, ENEMY_FOOT_OFFSET_X)

func _current_grid_positions() -> Dictionary:
	var distance := state_machine.current_distance if state_machine != null else 2
	return BattleStageHelper.current_grid_positions(distance, GRID_RIGHT_ANCHOR_SLOT, GRID_SLOT_COUNT)

func _target_slot_for_preview(is_player: bool, player_slot: int, enemy_slot: int, card: CardData) -> int:
	return BattleStageHelper.target_slot_for_preview(is_player, player_slot, enemy_slot, card, GRID_SLOT_COUNT)

func _attack_range_slots(is_player: bool, origin_slot: int, card: CardData) -> Array[int]:
	return BattleStageHelper.attack_range_slots(is_player, origin_slot, card, GRID_SLOT_COUNT)

func _preview_cycle_phase() -> float:
	return BattleStageHelper.preview_cycle_phase(preview_anim_time, PREVIEW_CYCLE_DURATION)

func _preview_frame_for_card(card: CardData, active: bool) -> int:
	return BattleStageHelper.preview_frame_for_card(card, active, _preview_cycle_phase())

func _animated_actor_top_left(is_player: bool, start_slot: int, target_slot: int, active: bool) -> Vector2:
	return BattleStageHelper.animated_actor_top_left(size.x, is_player, start_slot, target_slot, active, _preview_cycle_phase(), GRID_SLOT_COUNT, GRID_SLOT_WIDTH, GRID_SLOT_GAP, STAGE_GROUND_Y, player_sprite.size.y, PLAYER_FOOT_OFFSET_X, ENEMY_FOOT_OFFSET_X)

func _ease_preview(value: float) -> float:
	return BattleStageHelper.ease_preview(value)

func _compact_effect_summary(card: CardData) -> String:
	return BattleHudHelper.compact_effect_summary(card)

func _compact_button_text(card: CardData, marker: String, reason: String) -> String:
	var text := BattleHudHelper.compact_button_text(card, _card_role_prefix(card), marker, _draft_uses_card(card))
	if reason != "":
		text += "\n限制：%s" % reason
	return text

func _card_detail_text(card: CardData) -> String:
	return BattleHudHelper.card_detail_text(card)

func _focused_card_for_detail() -> CardData:
	return BattleHudHelper.focused_card(draft_player_intent, player_intent)

func _refresh_card_detail_panel() -> void:
	if card_detail_label == null:
		return
	card_detail_label.add_theme_color_override("default_color", Color("2f2821"))
	var focused_card := _focused_card_for_detail()
	if focused_card == null:
		card_detail_label.text = BattleHudHelper.empty_detail_text()
		return
	card_detail_label.text = _card_detail_text(focused_card)

func _refresh_effect_preview_panel() -> void:
	if effect_preview_label == null:
		return
	effect_preview_label.text = _effect_preview_text()

func _effect_preview_text() -> String:
	if player == null or enemy == null or state_machine == null:
		return "[font_size=18][b]效果预览[/b][/font_size]\n等待战斗数据。"
	var positions := _current_grid_positions()
	var player_slot: int = positions.get("player", 0)
	var enemy_slot: int = positions.get("enemy", 0)
	var player_card := _player_preview_card()
	var enemy_card := _enemy_preview_card()
	var preview_card := player_card
	var uses_wait := false
	if preview_card == null:
		preview_card = _preview_wait_card()
		uses_wait = true
	var player_target := _target_slot_for_preview(true, player_slot, enemy_slot, preview_card)
	var enemy_target_for_preview := _target_slot_for_preview(false, player_slot, enemy_slot, enemy_card)
	var player_range := _attack_range_slots(true, player_target, preview_card)
	var hits_enemy := player_range.has(enemy_target_for_preview)
	var damage := _preview_damage(preview_card, enemy, hits_enemy)
	var hp_after := maxi(enemy.hp - damage, 0)
	var self_momentum_after := clampi(player.momentum - preview_card.momentum_cost + (preview_card.gain_momentum if hits_enemy else 0), 0, player.data.max_momentum)
	var enemy_momentum_after := clampi(enemy.momentum - (preview_card.break_momentum if hits_enemy else 0), 0, enemy.data.max_momentum)
	var lines: Array[String] = []
	lines.append("[font_size=18][b]效果预览[/b][/font_size]")
	lines.append("当前：%s，距离 %d" % ["未选招，按不动预览" if uses_wait else preview_card.display_name, state_machine.current_distance])
	lines.append("我方位置：%s → %s" % [_slot_label(player_slot), _slot_label(player_target)])
	lines.append("影响格位：%s" % _slot_list_text(player_range))
	lines.append("预计命中：%s" % ("敌方" if hits_enemy and preview_card.requires_hit_check() else "无"))
	lines.append("预计伤害：%d" % damage)
	if preview_card.gain_momentum > 0 or preview_card.break_momentum > 0 or preview_card.momentum_cost > 0:
		lines.append("我方势：%d → %d" % [player.momentum, self_momentum_after])
		lines.append("敌方势：%d → %d" % [enemy.momentum, enemy_momentum_after])
	lines.append("敌方气血：%d/%d → %d/%d" % [enemy.hp, enemy.data.max_hp, hp_after, enemy.data.max_hp])
	if enemy_card != null:
		var enemy_target := enemy_target_for_preview
		var enemy_range := _attack_range_slots(false, enemy_target, enemy_card)
		var enemy_hits_player := enemy_range.has(player_target)
		var enemy_damage := _preview_damage(enemy_card, player, enemy_hits_player)
		var enemy_self_momentum_after := clampi(enemy.momentum - enemy_card.momentum_cost + (enemy_card.gain_momentum if enemy_hits_player else 0), 0, enemy.data.max_momentum)
		var player_momentum_after := clampi(player.momentum - (enemy_card.break_momentum if enemy_hits_player else 0), 0, player.data.max_momentum)
		var player_hp_after := maxi(player.hp - enemy_damage, 0)
		lines.append("")
		lines.append("[b]敌方可见意图[/b]：%s" % enemy_card.display_name)
		lines.append("敌方位置：%s → %s" % [_slot_label(enemy_slot), _slot_label(enemy_target)])
		lines.append("敌方影响格位：%s" % _slot_list_text(enemy_range))
		lines.append("敌方预计命中：%s" % ("我方" if enemy_hits_player and enemy_card.requires_hit_check() else "无"))
		lines.append("敌方预计伤害：%d" % enemy_damage)
		if enemy_card.gain_momentum > 0 or enemy_card.break_momentum > 0 or enemy_card.momentum_cost > 0:
			lines.append("敌方势：%d → %d" % [enemy.momentum, enemy_self_momentum_after])
			lines.append("我方势：%d → %d" % [player.momentum, player_momentum_after])
		lines.append("我方气血：%d/%d → %d/%d" % [player.hp, player.data.max_hp, player_hp_after, player.data.max_hp])
	return "\n".join(lines)

func _preview_damage(card: CardData, target: Fighter, hits_target: bool) -> int:
	if card == null or not hits_target or card.damage <= 0:
		return 0
	var amount := card.damage
	if target != null and target.is_broken():
		amount *= 2
	if target != null:
		amount = maxi(amount - target.guard_points, 0)
	return amount

func _slot_label(slot: int) -> String:
	if slot >= 0 and slot < SLOT_LABELS.size():
		return SLOT_LABELS[slot]
	return "未知"

func _slot_list_text(slots: Array[int]) -> String:
	if slots.is_empty():
		return "无"
	var parts: Array[String] = []
	for slot in slots:
		parts.append(_slot_label(slot))
	return " / ".join(parts)

func _refresh_intent_bubbles(force: bool = false) -> void:
	_refresh_single_intent_bubble(true, force)
	_refresh_single_intent_bubble(false, force)

func _refresh_single_intent_bubble(is_player: bool, force: bool = false) -> void:
	var bubble := player_intent_bubble if is_player else enemy_intent_bubble
	var label := player_intent_bubble_label if is_player else enemy_intent_bubble_label
	if bubble == null or label == null:
		return
	if not battle_active:
		bubble.visible = false
		_set_intent_bubble_signature(is_player, "")
		return
	var card := _player_preview_card() if is_player else _enemy_preview_card()
	var positions := _current_grid_positions()
	var player_slot: int = positions.get("player", 0)
	var enemy_slot: int = positions.get("enemy", 0)
	var actor_slot := player_slot if is_player else enemy_slot
	var opponent_slot := enemy_slot if is_player else player_slot
	var target_slot := _target_slot_for_preview(is_player, player_slot, enemy_slot, card)
	var bubble_text := _intent_bubble_text(card, actor_slot, opponent_slot, target_slot)
	var signature := _intent_bubble_state_signature(is_player, card, actor_slot, opponent_slot, target_slot, bubble_text)
	if not force and signature == _intent_bubble_signature(is_player):
		return
	_set_intent_bubble_signature(is_player, signature)
	label.text = bubble_text
	bubble.size = bubble.custom_minimum_size
	bubble.visible = true
	var sprite := player_sprite if is_player else enemy_sprite
	if sprite == null:
		return
	var bubble_x := sprite.position.x + sprite.size.x * 0.5 - bubble.size.x * 0.5
	var bubble_y := sprite.position.y - bubble.size.y - 12.0
	bubble.position = Vector2(
		clamp(bubble_x, 24.0, maxf(24.0, size.x - bubble.size.x - 24.0)),
		maxf(STAGE_AREA_TOP + 8.0, bubble_y)
	)

func _intent_bubble_state_signature(is_player: bool, card: CardData, actor_slot: int, opponent_slot: int, target_slot: int, bubble_text: String) -> String:
	var card_id := card.id if card != null else "-"
	var bubble := player_intent_bubble if is_player else enemy_intent_bubble
	var bubble_width := int(round(bubble.custom_minimum_size.x)) if bubble != null else 0
	return "%s|%d|%d|%d|%s|%d|%d" % [
		card_id,
		actor_slot,
		opponent_slot,
		target_slot,
		bubble_text,
		bubble_width,
		int(round(size.x))
	]

func _intent_bubble_signature(is_player: bool) -> String:
	return _player_intent_bubble_signature if is_player else _enemy_intent_bubble_signature

func _set_intent_bubble_signature(is_player: bool, signature: String) -> void:
	if is_player:
		_player_intent_bubble_signature = signature
	else:
		_enemy_intent_bubble_signature = signature

func _intent_bubble_text(card: CardData, actor_slot: int, opponent_slot: int, target_slot: int) -> String:
	if card == null:
		return "观察中"
	var parts: Array[String] = []
	parts.append(_intent_move_text(actor_slot, opponent_slot, target_slot))
	parts.append(card.display_name)
	parts.append_array(_intent_effect_parts(card))
	return "｜".join(parts)

func _intent_move_text(actor_slot: int, opponent_slot: int, target_slot: int) -> String:
	var delta := target_slot - actor_slot
	if delta == 0:
		return "原地"
	var facing_dir := signi(opponent_slot - actor_slot)
	if facing_dir == 0:
		return "原地"
	var steps := absi(delta)
	return "进%d" % steps if signi(delta) == facing_dir else "退%d" % steps

func _intent_effect_parts(card: CardData) -> Array[String]:
	var parts: Array[String] = []
	if card.guard > 0:
		parts.append("格挡%d" % card.guard)
	if card.gain_momentum > 0:
		parts.append("势+%d" % card.gain_momentum)
	if card.break_momentum > 0:
		parts.append("势-%d" % card.break_momentum)
	if card.damage > 0:
		parts.append("伤害%d" % card.damage)
	if parts.is_empty():
		parts.append("无效果")
	return parts

func _refresh_hand_buttons() -> void:
	if hand_flow == null:
		return
	var signature := _hand_buttons_state_signature()
	if signature == _hand_buttons_signature:
		return
	_hand_buttons_signature = signature
	for child in hand_flow.get_children():
		child.queue_free()
	if player == null:
		return
	if player.hand.is_empty():
		var empty_label := Label.new()
		empty_label.custom_minimum_size = Vector2(420, 180)
		empty_label.text = "暂无招式牌\n进入演武后会在这里显示本回合招式。"
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty_label.add_theme_font_size_override("font_size", 18)
		empty_label.add_theme_color_override("font_color", Color("9f9277"))
		hand_flow.add_child(empty_label)
		return
	for i in range(player.hand.size()):
		var card: CardData = player.hand[i]
		var reason := _card_restriction_reason(player, card)
		var marker := _combo_marker_text(player, card)
		var button := Button.new()
		button.custom_minimum_size = Vector2(176, 204)
		button.text = ""
		button.tooltip_text = _compact_button_text(card, marker, reason)
		button.autowrap_mode = TextServer.AUTOWRAP_OFF
		button.clip_text = true
		button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		button.add_theme_font_size_override("font_size", 12)
		button.disabled = not awaiting_player_input or not _can_play_card(player, card)
		_apply_card_button_style(button, card, _draft_uses_card(card), button.disabled)
		_build_card_button_face(button, card, marker, reason)
		button.pressed.connect(_on_player_card_pressed.bind(card))
		hand_flow.add_child(button)

func _hand_buttons_state_signature() -> String:
	if player == null:
		return "no-player"
	if player.hand.is_empty():
		return "empty|%s|%d|%d" % [str(awaiting_player_input), int(round(hand_flow.size.x)) if hand_flow != null else 0, int(round(hand_flow.size.y)) if hand_flow != null else 0]
	var parts: Array[String] = []
	parts.append(str(awaiting_player_input))
	parts.append(str(player.momentum))
	parts.append(str(player.guard_points))
	parts.append(str(state_machine.current_distance if state_machine != null else 0))
	parts.append(str(state_machine.phase if state_machine != null else -1))
	parts.append(_intent_card_id(draft_player_intent))
	parts.append(_intent_card_id(player_intent))
	parts.append(str(player.combo_window_active))
	parts.append(str(player.control_state))
	parts.append(str(int(round(hand_flow.size.x)) if hand_flow != null else 0))
	for card in player.hand:
		if card == null:
			parts.append("<null>")
			continue
		var reason := _card_restriction_reason(player, card)
		var marker := _combo_marker_text(player, card)
		var disabled := not awaiting_player_input or not _can_play_card(player, card)
		var selected := _draft_uses_card(card)
		parts.append("%s:%d:%s:%s:%s:%s" % [card.id, card.momentum_cost, str(disabled), str(selected), reason, marker])
	return "|".join(parts)

func _node_buttons_state_signature() -> String:
	if player == null:
		return "no-player"
	var parts: Array[String] = []
	parts.append(player.data.id)
	parts.append(str(battle_active))
	parts.append(str(node_pick_count))
	parts.append(str(awaiting_player_input))
	parts.append(str(fusion_first_index))
	parts.append(str(state_machine.phase if state_machine != null else -1))
	return "|".join(parts)

func _intent_card_id(intent: IntentData) -> String:
	if intent == null or intent.actual_card == null:
		return "-"
	return intent.actual_card.id

func _apply_card_button_style(button: Button, card: CardData, selected: bool, disabled: bool) -> void:
	var base := Color("141a20")
	var border := Color("8a7856")
	if card.is_guard_card():
		border = Color("637d91")
	elif card.is_momentum_card():
		border = Color("6f8d76")
	if selected:
		border = Color("e2c066")
	var normal := _make_flat_card_style(base, border, 2 if not selected else 3)
	var hover := _make_flat_card_style(base.lightened(0.08), border.lightened(0.15), 3)
	var pressed := _make_flat_card_style(base.lightened(0.14), Color("e6c36a"), 3)
	var disabled_style := _make_flat_card_style(Color("111418"), Color("4d4a42"), 1)
	button.add_theme_stylebox_override("normal", disabled_style if disabled else normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", _make_flat_card_style(base.lightened(0.04), Color("efd382"), 3))
	button.add_theme_stylebox_override("disabled", disabled_style)
	button.add_theme_color_override("font_color", Color(1, 1, 1, 0))
	button.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0))

func _make_flat_card_style(fill: Color, border: Color, border_width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(8)
	style.content_margin_left = 0
	style.content_margin_right = 0
	style.content_margin_top = 0
	style.content_margin_bottom = 0
	return style

func _build_card_button_face(button: Button, card: CardData, marker: String, reason: String) -> void:
	var face := MarginContainer.new()
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	face.add_theme_constant_override("margin_left", 10)
	face.add_theme_constant_override("margin_right", 10)
	face.add_theme_constant_override("margin_top", 10)
	face.add_theme_constant_override("margin_bottom", 10)
	button.add_child(face)

	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 7)
	face.add_child(box)

	var title_row := HBoxContainer.new()
	title_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_row.add_theme_constant_override("separation", 8)
	box.add_child(title_row)

	var cost_badge := PanelContainer.new()
	cost_badge.custom_minimum_size = Vector2(34, 34)
	cost_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cost_badge.add_theme_stylebox_override("panel", _make_badge_style(true))
	title_row.add_child(cost_badge)
	var cost_label := Label.new()
	cost_label.text = str(card.momentum_cost)
	cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cost_label.add_theme_font_size_override("font_size", 18)
	cost_label.add_theme_color_override("font_color", Color("f5efe1"))
	cost_badge.add_child(cost_label)

	var title_label := Label.new()
	title_label.text = card.display_name
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.add_theme_font_size_override("font_size", 18)
	title_label.add_theme_color_override("font_color", Color("f0e4c4"))
	title_label.clip_text = true
	title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title_row.add_child(title_label)

	var tag := Label.new()
	tag.text = _short_card_type_tag(card)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.custom_minimum_size = Vector2(28, 28)
	tag.add_theme_font_size_override("font_size", 14)
	tag.add_theme_color_override("font_color", Color("f7ead0"))
	tag.add_theme_stylebox_override("normal", _make_type_tag_style(card))
	title_row.add_child(tag)

	var art_box := PanelContainer.new()
	art_box.custom_minimum_size = Vector2(0, 54)
	art_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	art_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art_box.add_theme_stylebox_override("panel", _make_card_art_style(card))
	box.add_child(art_box)
	var art_label := Label.new()
	art_label.text = _card_art_glyph(card)
	art_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	art_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	art_label.add_theme_font_size_override("font_size", 22)
	art_label.add_theme_color_override("font_color", Color("ced8dd"))
	art_box.add_child(art_label)

	var summary := Label.new()
	summary.text = _compact_effect_summary(card)
	if marker != "":
		summary.text += "\n%s" % marker
	if reason != "":
		summary.text += "\n限制：%s" % reason
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary.clip_text = true
	summary.max_lines_visible = 3
	summary.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	summary.add_theme_font_size_override("font_size", 13)
	summary.add_theme_color_override("font_color", Color("d9d2bf") if reason == "" else Color("a79881"))
	box.add_child(summary)

func _short_card_type_tag(card: CardData) -> String:
	if card.is_guard_card():
		return "防"
	if card.is_momentum_card():
		return "身"
	return "攻"

func _make_type_tag_style(card: CardData) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("6f2824")
	if card.is_guard_card():
		style.bg_color = Color("29495f")
	elif card.is_momentum_card():
		style.bg_color = Color("355d46")
	style.border_color = Color("c7b181")
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	return style

func _make_card_art_style(card: CardData) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("202934")
	if card.is_guard_card():
		style.bg_color = Color("243443")
	elif card.is_momentum_card():
		style.bg_color = Color("24382e")
	style.border_color = Color("403b31")
	style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	return style

func _card_art_glyph(card: CardData) -> String:
	if card.is_guard_card():
		return "守"
	if card.is_momentum_card():
		return "行"
	if card.max_distance >= 3:
		return "气"
	return "斩"

func _refresh_stage_grid(force: bool = false) -> void:
	if stage_grid_cells.is_empty():
		return
	var positions := _current_grid_positions()
	var player_slot: int = positions.get("player", 0)
	var enemy_slot: int = positions.get("enemy", 0)
	var player_preview_card := _player_preview_card()
	var enemy_preview_card := _enemy_preview_card()
	var player_target_slot := _target_slot_for_preview(true, player_slot, enemy_slot, player_preview_card)
	var enemy_target_slot := _target_slot_for_preview(false, player_slot, enemy_slot, enemy_preview_card)
	var player_range := _attack_range_slots(true, player_target_slot, player_preview_card)
	var enemy_range := _attack_range_slots(false, enemy_target_slot, enemy_preview_card)
	var signature := _stage_grid_state_signature(player_target_slot, enemy_target_slot, player_range, enemy_range, player_preview_card, enemy_preview_card)
	if not force and signature == _stage_grid_signature:
		return
	_stage_grid_signature = signature
	_refresh_range_trapezoids(player_range, player_target_slot, enemy_range, enemy_target_slot)
	for i in range(GRID_SLOT_COUNT):
		var in_player_range := player_range.has(i)
		var in_enemy_range := enemy_range.has(i)
		var has_player := i == player_target_slot
		var has_enemy := i == enemy_target_slot
		var fill := GRID_BASE_COLOR
		if has_player:
			fill = PLAYER_POS_COLOR
		if has_enemy:
			fill = ENEMY_POS_COLOR
		stage_grid_cells[i].add_theme_stylebox_override("panel", _make_grid_cell_style(fill, i, has_player, has_enemy, false, false))
		if (has_enemy and in_player_range) or (has_player and in_enemy_range):
			stage_grid_labels[i].text = "×"
		elif in_player_range or in_enemy_range:
			stage_grid_labels[i].text = "·"
		else:
			stage_grid_labels[i].text = ""

func _stage_grid_state_signature(
	player_target_slot: int,
	enemy_target_slot: int,
	player_range: Array[int],
	enemy_range: Array[int],
	player_preview_card: CardData,
	enemy_preview_card: CardData
) -> String:
	var player_card_id := player_preview_card.id if player_preview_card != null else "-"
	var enemy_card_id := enemy_preview_card.id if enemy_preview_card != null else "-"
	return "%d|%d|%s|%s|%s|%s|%d" % [
		player_target_slot,
		enemy_target_slot,
		_slot_array_key(player_range),
		_slot_array_key(enemy_range),
		player_card_id,
		enemy_card_id,
		int(round(size.x))
	]

func _slot_array_key(slots: Array[int]) -> String:
	var parts: Array[String] = []
	for slot in slots:
		parts.append(str(slot))
	return ",".join(parts)

func _refresh_range_trapezoids(player_range: Array[int], player_origin_slot: int, enemy_range: Array[int], enemy_origin_slot: int) -> void:
	if range_overlay_layer == null:
		return
	var used_count := 0
	for slot in player_range:
		_draw_range_trapezoid(used_count, slot, player_origin_slot, Color(0.25, 0.62, 1.0, 0.24), Color(0.62, 0.86, 1.0, 0.78))
		used_count += 1
	for slot in enemy_range:
		_draw_range_trapezoid(used_count, slot, enemy_origin_slot, Color(1.0, 0.32, 0.22, 0.23), Color(1.0, 0.67, 0.52, 0.78))
		used_count += 1
	for i in range(used_count, _range_trapezoid_pool.size()):
		var entry := _range_trapezoid_pool[i]
		var polygon: Polygon2D = entry.get("polygon", null)
		var outline: Line2D = entry.get("outline", null)
		if polygon != null:
			polygon.visible = false
		if outline != null:
			outline.visible = false

func _draw_range_trapezoid(pool_index: int, slot: int, origin_slot: int, fill_color: Color, outline_color: Color) -> void:
	if range_overlay_layer == null:
		return
	var entry := _range_trapezoid_entry(pool_index)
	var polygon: Polygon2D = entry.get("polygon", null)
	var outline: Line2D = entry.get("outline", null)
	if polygon == null or outline == null:
		return
	polygon.polygon = _range_trapezoid_points(slot, origin_slot)
	polygon.color = fill_color
	polygon.z_index = 2
	polygon.visible = true
	outline.points = polygon.polygon
	outline.closed = true
	outline.width = 3.0
	outline.default_color = outline_color
	outline.joint_mode = Line2D.LINE_JOINT_ROUND
	outline.z_index = 3
	outline.visible = true

func _range_trapezoid_entry(pool_index: int) -> Dictionary:
	while _range_trapezoid_pool.size() <= pool_index:
		var polygon := Polygon2D.new()
		polygon.visible = false
		polygon.z_index = 2
		range_overlay_layer.add_child(polygon)
		var outline := Line2D.new()
		outline.visible = false
		outline.closed = true
		outline.width = 3.0
		outline.joint_mode = Line2D.LINE_JOINT_ROUND
		outline.z_index = 3
		range_overlay_layer.add_child(outline)
		_range_trapezoid_pool.append({"polygon": polygon, "outline": outline})
	return _range_trapezoid_pool[pool_index]

func _range_trapezoid_points(slot: int, origin_slot: int) -> PackedVector2Array:
	var left := _slot_center_x(slot) - GRID_SLOT_WIDTH * 0.5
	var right := _slot_center_x(slot) + GRID_SLOT_WIDTH * 0.5
	var top_y := GRID_STAGE_Y - 18.0
	var bottom_y := GRID_STAGE_Y + GRID_SLOT_HEIGHT + 8.0
	var short_side_y_inset := 15.0
	var long_outset := 10.0
	if origin_slot <= slot:
		return PackedVector2Array([
			Vector2(left, top_y + short_side_y_inset),
			Vector2(right + long_outset, top_y),
			Vector2(right + long_outset, bottom_y),
			Vector2(left, bottom_y - short_side_y_inset)
		])
	return PackedVector2Array([
		Vector2(left - long_outset, top_y),
		Vector2(right, top_y + short_side_y_inset),
		Vector2(right, bottom_y - short_side_y_inset),
		Vector2(left - long_outset, bottom_y)
	])

func _refresh_stage_actor_positions(force: bool = false) -> void:
	if player_sprite == null or enemy_sprite == null:
		return
	var positions := _current_grid_positions()
	var player_slot: int = positions.get("player", 0)
	var enemy_slot: int = positions.get("enemy", 0)
	var player_card := _player_preview_card()
	var enemy_card := _enemy_preview_card()
	var player_target_slot := _target_slot_for_preview(true, player_slot, enemy_slot, player_card)
	var enemy_target_slot := _target_slot_for_preview(false, player_slot, enemy_slot, enemy_card)
	var signature := _stage_actor_state_signature(player_target_slot, enemy_target_slot, player_card, enemy_card)
	if not force and signature == _stage_actor_signature:
		return
	_stage_actor_signature = signature
	var player_top_left := _slot_top_left(player_target_slot, true)
	var enemy_top_left := _slot_top_left(enemy_target_slot, false)
	player_sprite.position = player_top_left
	enemy_sprite.position = enemy_top_left
	player_fallback_actor.position = player_top_left
	enemy_fallback_actor.position = enemy_top_left
	_set_actor_sheet_frame(player, 0)
	_set_actor_sheet_frame(enemy, 0)
	_apply_actor_facing(player_target_slot, enemy_target_slot, player_top_left, enemy_top_left)

func _stage_actor_state_signature(player_target_slot: int, enemy_target_slot: int, player_card: CardData, enemy_card: CardData) -> String:
	var player_card_id := player_card.id if player_card != null else "-"
	var enemy_card_id := enemy_card.id if enemy_card != null else "-"
	var player_role := player.data.id if player != null else "-"
	var enemy_role := enemy.data.id if enemy != null else "-"
	return "%d|%d|%s|%s|%s|%s|%d|%d|%d" % [
		player_target_slot,
		enemy_target_slot,
		player_card_id,
		enemy_card_id,
		player_role,
		enemy_role,
		int(round(size.x)),
		int(round(player_sprite.size.y)),
		int(round(enemy_sprite.size.y))
	]

func _apply_actor_facing(player_slot: int, enemy_slot: int, player_top_left: Vector2, enemy_top_left: Vector2) -> void:
	# 当前素材默认朝右；根据预期站位动态翻转，让回合开始与预览阶段都面向对手。
	var player_faces_left := player_slot > enemy_slot
	var enemy_faces_left := enemy_slot > player_slot
	_set_texture_actor_facing(player_sprite, player_faces_left)
	_set_texture_actor_facing(enemy_sprite, enemy_faces_left)
	_set_fallback_actor_facing(player_fallback_actor, player_faces_left, player_top_left)
	_set_fallback_actor_facing(enemy_fallback_actor, enemy_faces_left, enemy_top_left)

func _set_texture_actor_facing(sprite: TextureRect, faces_left: bool) -> void:
	if sprite == null:
		return
	sprite.flip_h = faces_left

func _set_fallback_actor_facing(actor: Control, faces_left: bool, top_left: Vector2) -> void:
	if actor == null:
		return
	var fallback_scale := ACTOR_DISPLAY_SIZE.x / ACTOR_FALLBACK_BASE_SIZE
	actor.scale = Vector2(-fallback_scale if faces_left else fallback_scale, fallback_scale)
	actor.position = top_left + (Vector2(ACTOR_DISPLAY_SIZE.x, 0.0) if faces_left else Vector2.ZERO)

func _process(delta: float) -> void:
	preview_anim_time += delta
	if not battle_active:
		return
	_visual_poll_refresh_elapsed += delta
	if _visual_poll_refresh_elapsed < VISUAL_POLL_REFRESH_INTERVAL:
		return
	_visual_poll_refresh_elapsed = 0.0
	_refresh_hud_bars()
	_refresh_stage_grid()
	_refresh_stage_actor_positions()
	_refresh_intent_bubbles()

func _player_preview_card() -> CardData:
	if draft_player_intent != null and draft_player_intent.actual_card != null:
		return draft_player_intent.actual_card
	if player_intent != null and player_intent.actual_card != null and state_machine != null and state_machine.phase == BattleStateMachine.BattlePhase.DECLARE:
		return player_intent.actual_card
	return null

func _enemy_preview_card() -> CardData:
	return _visible_card_for_intent(_enemy_preview_intent(), player)

func _enemy_preview_intent() -> IntentData:
	if enemy_intent != null:
		return enemy_intent
	if not battle_active or state_machine == null or state_machine.phase != BattleStateMachine.BattlePhase.DECLARE:
		return null
	if enemy_ai == null or enemy == null or player == null:
		return null
	var seen_intent := draft_player_intent if draft_player_intent != null else player_intent
	return enemy_ai.choose_intent(enemy, player, state_machine.current_distance, seen_intent)

func _visible_card_for_intent(intent: IntentData, viewer: Fighter) -> CardData:
	if intent == null:
		return null
	if intent.is_hidden() and viewer != null and not intent.can_hidden_be_read(viewer):
		return intent.visible_card
	return intent.actual_card

func _should_preview_card(card: CardData) -> bool:
	return battle_active and card != null and state_machine != null and state_machine.phase == BattleStateMachine.BattlePhase.DECLARE

func _sheet_source_for(fighter: Fighter, is_enemy: bool) -> Texture2D:
	if fighter == null:
		return null
	var prefix := "enemy_" if is_enemy else ""
	var role := fighter.data.id
	return _safe_load_texture("res://assets/pixel_battle/sheets/%s%s_sheet.png" % [prefix, role])

func _sheet_frame_texture(source: Texture2D, frame_index: int) -> Texture2D:
	if source == null:
		return null
	var frame_width := maxi(source.get_width() / SHEET_FRAME_COUNT, 1)
	var atlas := AtlasTexture.new()
	atlas.atlas = source
	atlas.region = Rect2(frame_width * clampi(frame_index, 0, SHEET_FRAME_COUNT - 1), 0, frame_width, source.get_height())
	return atlas

func _portrait_texture_for(fighter: Fighter) -> Texture2D:
	if fighter == null:
		return null
	return _safe_load_texture("res://assets/pixel_battle/portraits/%s_portrait.png" % fighter.data.id)

func _set_actor_sheet_frame(actor: Fighter, frame_index: int) -> void:
	if actor == null:
		return
	if player != null and actor.data.id == player.data.id and player_sprite != null and player_sheet_source != null:
		player_sprite.texture = _sheet_frame_texture(player_sheet_source, frame_index)
		return
	if enemy != null and actor.data.id == enemy.data.id and enemy_sprite != null and enemy_sheet_source != null:
		enemy_sprite.texture = _sheet_frame_texture(enemy_sheet_source, frame_index)

func _pulse_actor_sheet_frame(actor: Fighter, frame_index: int, duration: float = 0.14) -> void:
	_set_actor_sheet_frame(actor, frame_index)
	var timer := get_tree().create_timer(duration)
	timer.timeout.connect(func() -> void:
		_set_actor_sheet_frame(actor, 0)
	)

func _animate_attacker_sprite(actor: Fighter, profession_id: String, is_finisher: bool = false) -> void:
	var sprite := player_fallback_actor if actor != null and player != null and actor.data.id == player.data.id and player_fallback_actor != null and player_fallback_actor.visible else enemy_fallback_actor if actor != null and enemy != null and actor.data.id == enemy.data.id and enemy_fallback_actor != null and enemy_fallback_actor.visible else player_sprite if actor != null and player != null and actor.data.id == player.data.id else enemy_sprite
	if sprite == null:
		return
	_pulse_actor_sheet_frame(actor, 1, 0.16 if is_finisher else 0.12)
	var start := sprite.position
	var dir := -1.0 if _actor_control_faces_left(sprite) else 1.0
	var tween := create_tween()
	if profession_id == "spearman":
		tween.tween_property(sprite, "position", start + Vector2((28 if not is_finisher else 40) * dir, 0), 0.04)
		tween.tween_property(sprite, "position", start, 0.06)
	else:
		tween.tween_property(sprite, "position", start + Vector2((20 if not is_finisher else 30) * dir, -10), 0.04)
		tween.tween_property(sprite, "position", start, 0.07)

func _actor_control_faces_left(sprite: Control) -> bool:
	if sprite == null:
		return false
	if sprite is TextureRect:
		return (sprite as TextureRect).flip_h
	return sprite.scale.x < 0.0

func _resolve_combo_chain_if_any(actor: Fighter, target: Fighter, intent: IntentData) -> Array[String]:
	var lines := super._resolve_combo_chain_if_any(actor, target, intent)
	if not lines.is_empty() and actor != null and intent != null and intent.actual_card != null and intent.actual_card.damage > 0:
		var is_finisher := intent.actual_card.has_tag("终结")
		_animate_attacker_sprite(actor, actor.data.id, is_finisher)
	return lines

func _on_intent_resolved(actor: Fighter, target: Fighter, intent: IntentData, feedback: Dictionary) -> void:
	if actor == null or target == null or intent == null or intent.actual_card == null:
		return
	if not bool(feedback.get("is_attack", false)):
		return
	var card: CardData = intent.actual_card
	var is_finisher := card.has_tag("终结")
	var effect_color := _strike_feedback_color(actor.data.id, bool(feedback.get("connected", false)))
	_animate_attacker_sprite(actor, actor.data.id, is_finisher)
	_play_profession_shape_feedback(actor.data.id, effect_color, is_finisher, false)
	if bool(feedback.get("connected", false)):
		_show_target_receive_feedback(target, actor.data.id, effect_color, is_finisher)

func _strike_feedback_color(profession_id: String, connected: bool) -> Color:
	if profession_id == "spearman":
		return Color("8fd3ff") if connected else Color("6f94ad")
	return Color("ffb28f") if connected else Color("b68268")

func _spawn_fx_texture(path: String, draw_size: Vector2, at_position: Vector2, tint: Color, rotation_deg: float = 0.0, start_scale: Vector2 = Vector2.ONE) -> TextureRect:
	var texture := _safe_load_texture(path)
	if texture == null:
		return null
	return _fx_pool.acquire(path, texture, draw_size, at_position, tint, rotation_deg, start_scale)

func _release_fx_texture(path: String, fx: TextureRect) -> void:
	_fx_pool.release(path, fx)

func _actor_fx_anchor(target_is_enemy: bool) -> Vector2:
	var sprite := enemy_sprite if target_is_enemy else player_sprite
	if sprite != null:
		return sprite.position + sprite.size * 0.5
	var fallback := enemy_fallback_actor if target_is_enemy else player_fallback_actor
	if fallback != null:
		return fallback.position + fallback.custom_minimum_size * 0.5
	return size * 0.5

func _show_pierce_line(color: Color, is_finisher: bool = false) -> void:
	var fx_path := "res://assets/pixel_battle/fx/pierce_streak.png"
	var fx := _spawn_fx_texture(
		fx_path,
		Vector2(320 if not is_finisher else 380, 72 if not is_finisher else 88),
		Vector2(size.x * 0.5, size.y * 0.5),
		color,
		0.0,
		Vector2(0.78, 1.0)
	)
	if fx == null:
		super(color, is_finisher)
		return
	var start_pos := fx.position + Vector2(-220 if not is_finisher else -280, 0)
	var end_pos := fx.position + Vector2(220 if not is_finisher else 280, 0)
	fx.position = start_pos
	var tween := create_tween()
	tween.tween_property(fx, "modulate", Color(color.r, color.g, color.b, 0.96), 0.03)
	tween.parallel().tween_property(fx, "position", end_pos, 0.09 if not is_finisher else 0.12)
	tween.parallel().tween_property(fx, "scale", Vector2(1.08 if not is_finisher else 1.22, 1.0 if not is_finisher else 1.16), 0.06)
	tween.tween_property(fx, "modulate", Color(color.r, color.g, color.b, 0.0), 0.09)
	tween.finished.connect(func() -> void:
		_release_fx_texture(fx_path, fx)
	)

func _show_slash_cut(color: Color, is_finisher: bool = false) -> void:
	var fx_path := "res://assets/pixel_battle/fx/slash_arc.png"
	var fx := _spawn_fx_texture(
		fx_path,
		Vector2(260 if not is_finisher else 320, 160 if not is_finisher else 200),
		Vector2(size.x * 0.5, size.y * 0.5),
		color,
		-16.0,
		Vector2(0.84, 0.84)
	)
	if fx == null:
		super(color, is_finisher)
		return
	var tween := create_tween()
	tween.tween_property(fx, "modulate", Color(color.r, color.g, color.b, 0.88), 0.03)
	tween.parallel().tween_property(fx, "scale", Vector2(1.02 if not is_finisher else 1.16, 1.02 if not is_finisher else 1.16), 0.06)
	tween.parallel().tween_property(fx, "position", fx.position + Vector2(84, 18), 0.06)
	if is_finisher:
		tween.tween_property(fx, "modulate", Color(color.r, color.g, color.b, 0.98), 0.02)
		tween.parallel().tween_property(fx, "position", fx.position + Vector2(-36, -6), 0.04)
	tween.tween_property(fx, "modulate", Color(color.r, color.g, color.b, 0.0), 0.1)
	tween.finished.connect(func() -> void:
		_release_fx_texture(fx_path, fx)
	)

func _show_target_hit_mark(target_is_enemy: bool, color: Color, profession_id: String, is_finisher: bool = false) -> void:
	var fx_path := "res://assets/pixel_battle/fx/hit_spark.png"
	var fx := _spawn_fx_texture(
		fx_path,
		Vector2(128 if not is_finisher else 156, 128 if not is_finisher else 156),
		_actor_fx_anchor(target_is_enemy) + Vector2(12 if target_is_enemy else -12, -24),
		color,
		0.0,
		Vector2(0.72, 0.72)
	)
	if fx == null:
		super(target_is_enemy, color, profession_id, is_finisher)
		return
	var tween := create_tween()
	tween.tween_property(fx, "modulate", Color(color.r, color.g, color.b, 0.9 if is_finisher else 0.72), 0.03)
	tween.parallel().tween_property(fx, "scale", Vector2(1.0 if not is_finisher else 1.18, 1.0 if not is_finisher else 1.18), 0.05)
	tween.parallel().tween_property(fx, "rotation_degrees", 14.0 if profession_id == "spearman" else -18.0, 0.05)
	tween.tween_property(fx, "modulate", Color(color.r, color.g, color.b, 0.0), 0.1)
	tween.finished.connect(func() -> void:
		_release_fx_texture(fx_path, fx)
	)

func _show_target_receive_feedback(target: Fighter, profession_id: String, color: Color, is_finisher: bool = false) -> void:
	super(target, profession_id, color, is_finisher)
	_pulse_actor_sheet_frame(target, 2, 0.16 if is_finisher else 0.12)
