extends RefCounted
class_name BattleHudHelper

static var _summary_cache: Dictionary = {}
static var _button_text_cache: Dictionary = {}
static var _detail_cache: Dictionary = {}
static var _empty_detail_cache: String = ""
static var _intent_text_cache: Dictionary = {}
static var _effect_preview_cache: Dictionary = {}

static func _card_key(card: CardData) -> String:
	if card == null:
		return "null"
	var tags: PackedStringArray = card.tags if card.tags != null else PackedStringArray()
	return "%s|%s|%d|%d|%d|%d|%d|%d|%s|%s|%s|%s" % [
		card.id,
		card.display_name,
		card.momentum_cost,
		card.min_distance,
		card.max_distance,
		card.damage,
		card.guard,
		card.gain_momentum,
		str(card.break_momentum),
		"/".join(tags),
		card.weapon_style,
		str(card.requires_facing)
	]

static func intent_bubble_text(card: CardData, actor_slot: int, opponent_slot: int, target_slot: int) -> String:
	if card == null:
		return "观察中"
	var key: String = "%s|%d|%d|%d" % [_card_key(card), actor_slot, opponent_slot, target_slot]
	if _intent_text_cache.has(key):
		return _intent_text_cache[key] as String
	var parts: Array[String] = []
	parts.append(_intent_move_text(actor_slot, opponent_slot, target_slot))
	parts.append(card.display_name)
	parts.append_array(_intent_effect_parts(card))
	var text: String = "｜".join(parts)
	_intent_text_cache[key] = text
	return text

static func _intent_move_text(actor_slot: int, opponent_slot: int, target_slot: int) -> String:
	var delta: int = target_slot - actor_slot
	if delta == 0:
		return "原地"
	var facing_dir: int = signi(opponent_slot - actor_slot)
	if facing_dir == 0:
		return "原地"
	var steps: int = absi(delta)
	return "进%d" % steps if signi(delta) == facing_dir else "退%d" % steps

static func _intent_effect_parts(card: CardData) -> Array[String]:
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

static func build_effect_preview_context(input: Dictionary) -> Dictionary:
	if input.is_empty() or not bool(input.get("has_data", false)):
		return {"has_data": false}
	var preview_card: CardData = input.get("preview_card", null) as CardData
	var enemy_card: CardData = input.get("enemy_card", null) as CardData
	var hits_enemy: bool = bool(input.get("hits_enemy", false))
	var enemy_hits_player: bool = bool(input.get("enemy_hits_player", false))
	var player_momentum: int = int(input.get("player_momentum", 0))
	var player_max_momentum: int = int(input.get("player_max_momentum", 0))
	var enemy_momentum: int = int(input.get("enemy_momentum", 0))
	var enemy_max_momentum: int = int(input.get("enemy_max_momentum", 0))
	var player_hp: int = int(input.get("player_hp", 0))
	var player_max_hp: int = int(input.get("player_max_hp", 0))
	var enemy_hp: int = int(input.get("enemy_hp", 0))
	var enemy_max_hp: int = int(input.get("enemy_max_hp", 0))
	var player_damage: int = int(input.get("player_damage", 0))
	var enemy_damage: int = int(input.get("enemy_damage", 0))
	var player_momentum_after: int = player_momentum
	var enemy_momentum_after: int = enemy_momentum
	var enemy_self_momentum_after: int = enemy_momentum
	var player_momentum_after_enemy: int = player_momentum
	if preview_card != null:
		player_momentum_after = clampi(player_momentum - preview_card.momentum_cost + (preview_card.gain_momentum if hits_enemy else 0), 0, player_max_momentum)
		var player_break_amount := int(input.get("player_break_amount", preview_card.break_momentum if hits_enemy else 0))
		enemy_momentum_after = clampi(enemy_momentum - player_break_amount, 0, enemy_max_momentum)
	if enemy_card != null:
		enemy_self_momentum_after = clampi(enemy_momentum - enemy_card.momentum_cost + (enemy_card.gain_momentum if enemy_hits_player else 0), 0, enemy_max_momentum)
		var enemy_break_amount := int(input.get("enemy_break_amount", enemy_card.break_momentum if enemy_hits_player else 0))
		player_momentum_after_enemy = clampi(player_momentum - enemy_break_amount, 0, player_max_momentum)
	var context: Dictionary = {
		"has_data": true,
		"current_card_name": input.get("current_card_name", "未选招，按不动预览"),
		"distance": int(input.get("distance", 0)),
		"player_slot_label": input.get("player_slot_label", "未知"),
		"player_target_label": input.get("player_target_label", "未知"),
		"player_facing": input.get("player_facing", "未知"),
		"player_range_text": input.get("player_range_text", "无"),
		"player_hit_text": input.get("player_hit_text", "敌方" if hits_enemy and preview_card != null and preview_card.requires_hit_check() else "无"),
		"player_damage": player_damage,
		"show_player_momentum": preview_card != null and (preview_card.gain_momentum > 0 or preview_card.break_momentum > 0 or preview_card.momentum_cost > 0),
		"player_momentum_before": player_momentum,
		"player_momentum_after": player_momentum_after,
		"enemy_momentum_before": enemy_momentum,
		"enemy_momentum_after": enemy_momentum_after,
		"enemy_hp_before": enemy_hp,
		"enemy_max_hp": enemy_max_hp,
		"enemy_hp_after": maxi(enemy_hp - player_damage, 0),
		"has_enemy_card": enemy_card != null,
		"player_hp_before": player_hp,
		"player_max_hp": player_max_hp,
		"player_hp_after": maxi(player_hp - enemy_damage, 0)
	}
	if input.has("player_break_amount"):
		context["player_break_amount"] = input.get("player_break_amount", 0)
	if enemy_card != null:
		context["enemy_card_name"] = enemy_card.display_name
		context["enemy_slot_label"] = input.get("enemy_slot_label", "未知")
		context["enemy_target_label"] = input.get("enemy_target_label", "未知")
		context["enemy_facing"] = input.get("enemy_facing", "未知")
		context["enemy_range_text"] = input.get("enemy_range_text", "无")
		context["enemy_hit_text"] = input.get("enemy_hit_text", "我方" if enemy_hits_player and enemy_card.requires_hit_check() else "无")
		context["enemy_damage"] = enemy_damage
		context["show_enemy_momentum"] = enemy_card.gain_momentum > 0 or enemy_card.break_momentum > 0 or enemy_card.momentum_cost > 0
		context["enemy_self_momentum_before"] = enemy_momentum
		context["enemy_self_momentum_after"] = enemy_self_momentum_after
		context["player_momentum_after_enemy"] = player_momentum_after_enemy
		if input.has("enemy_break_amount"):
			context["enemy_break_amount"] = input.get("enemy_break_amount", 0)
	return context

static func effect_preview_text(context: Dictionary) -> String:
	var key: String = str(context)
	if _effect_preview_cache.has(key):
		return _effect_preview_cache[key] as String
	if context.is_empty() or not context.get("has_data", false):
		return "[font_size=18][b]效果预览[/b][/font_size]\n等待战斗数据。"
	var lines: Array[String] = []
	lines.append("[font_size=18][b]效果预览[/b][/font_size]")
	lines.append("当前：%s，距离 %d" % [context.get("current_card_name", "未选招，按不动预览"), int(context.get("distance", 0))])
	lines.append("我方位置：%s → %s" % [context.get("player_slot_label", "未知"), context.get("player_target_label", "未知")])
	if context.has("player_facing"):
		lines.append("我方朝向：%s" % context.get("player_facing", "未知"))
	lines.append("影响格位：%s" % context.get("player_range_text", "无"))
	lines.append("预计命中：%s" % context.get("player_hit_text", "无"))
	lines.append("预计伤害：%d" % int(context.get("player_damage", 0)))
	if context.has("player_break_amount"):
		lines.append("预计削势：%d" % int(context.get("player_break_amount", 0)))
	if bool(context.get("show_player_momentum", false)):
		lines.append("我方势：%d → %d" % [int(context.get("player_momentum_before", 0)), int(context.get("player_momentum_after", 0))])
		lines.append("敌方势：%d → %d" % [int(context.get("enemy_momentum_before", 0)), int(context.get("enemy_momentum_after", 0))])
	lines.append("敌方气血：%d/%d → %d/%d" % [int(context.get("enemy_hp_before", 0)), int(context.get("enemy_max_hp", 0)), int(context.get("enemy_hp_after", 0)), int(context.get("enemy_max_hp", 0))])
	if bool(context.get("has_enemy_card", false)):
		lines.append("")
		lines.append("[b]敌方可见意图[/b]：%s" % context.get("enemy_card_name", "未知"))
		lines.append("敌方位置：%s → %s" % [context.get("enemy_slot_label", "未知"), context.get("enemy_target_label", "未知")])
		if context.has("enemy_facing"):
			lines.append("敌方朝向：%s" % context.get("enemy_facing", "未知"))
		lines.append("敌方影响格位：%s" % context.get("enemy_range_text", "无"))
		lines.append("敌方预计命中：%s" % context.get("enemy_hit_text", "无"))
		lines.append("敌方预计伤害：%d" % int(context.get("enemy_damage", 0)))
		if context.has("enemy_break_amount"):
			lines.append("敌方预计削势：%d" % int(context.get("enemy_break_amount", 0)))
		if bool(context.get("show_enemy_momentum", false)):
			lines.append("敌方势：%d → %d" % [int(context.get("enemy_self_momentum_before", 0)), int(context.get("enemy_self_momentum_after", 0))])
			lines.append("我方势：%d → %d" % [int(context.get("player_momentum_before", 0)), int(context.get("player_momentum_after_enemy", 0))])
		lines.append("我方气血：%d/%d → %d/%d" % [int(context.get("player_hp_before", 0)), int(context.get("player_max_hp", 0)), int(context.get("player_hp_after", 0)), int(context.get("player_max_hp", 0))])
	var text: String = "\n".join(lines)
	_effect_preview_cache[key] = text
	return text

static func compact_effect_summary(card: CardData) -> String:
	var key: String = _card_key(card)
	if _summary_cache.has(key):
		return _summary_cache[key] as String
	var pieces: Array[String] = []
	pieces.append("耗势 %d  距 %d-%d" % [card.momentum_cost, card.min_distance, card.max_distance])
	if card.damage > 0:
		pieces.append("伤害 %d" % card.damage)
	if card.guard > 0:
		pieces.append("格挡 %d" % card.guard)
	if card.gain_momentum > 0 or card.break_momentum > 0:
		var momentum_parts: Array[String] = []
		if card.gain_momentum > 0:
			momentum_parts.append("增势 %d" % card.gain_momentum)
		if card.break_momentum > 0:
			momentum_parts.append("削势 %d" % card.break_momentum)
		pieces.append(" / ".join(momentum_parts))
	var summary: String = "\n".join(pieces)
	_summary_cache[key] = summary
	return summary

static func compact_button_text(card: CardData, card_role_prefix: String, marker: String, is_drafted: bool) -> String:
	var cache_key: String = "%s|%s|%s|%s" % [_card_key(card), card_role_prefix, marker, str(is_drafted)]
	if _button_text_cache.has(cache_key):
		return _button_text_cache[cache_key] as String
	var title: String = "%s %s" % [card_role_prefix, card.display_name]
	if is_drafted:
		title = "[已选] " + title
	var lines: Array[String] = [title, compact_effect_summary(card)]
	if marker != "":
		lines.append(marker)
	var text: String = "\n".join(lines)
	_button_text_cache[cache_key] = text
	return text

static func card_detail_text(card: CardData) -> String:
	var key: String = _card_key(card)
	if _detail_cache.has(key):
		return _detail_cache[key] as String
	var lines: Array[String] = []
	lines.append("[font_size=30][b]%s[/b][/font_size]" % card.display_name)
	lines.append("[color=#7f261d]%s[/color]" % card.type_label())
	lines.append("")
	lines.append("势力消耗：[color=#284f73][b]%d[/b][/color]" % card.momentum_cost)
	lines.append("招式范围：%d-%d 格" % [card.min_distance, card.max_distance])
	if not card.tags.is_empty():
		lines.append("招式标签：%s" % " / ".join(card.tags))
	var effect_lines: Array[String] = []
	if card.damage > 0:
		effect_lines.append("造成 [color=#a73221]%d[/color] 点伤害。" % card.damage)
	if card.guard > 0:
		effect_lines.append("获得 [color=#30566f]%d[/color] 点格挡。" % card.guard)
	if card.gain_momentum > 0:
		effect_lines.append("回复 [color=#2f6d63]%d[/color] 点势。" % card.gain_momentum)
	if card.break_momentum > 0:
		effect_lines.append("削减对手 [color=#7c3d1b]%d[/color] 点势。" % card.break_momentum)
	if effect_lines.is_empty():
		effect_lines.append("本招式没有直接伤害、格挡或势变化。")
	lines.append("")
	lines.append("[b]招式效果[/b]")
	lines.append("".join(effect_lines))
	lines.append("")
	lines.append("[b]招式描述[/b]")
	lines.append(card.description)
	var detail: String = "\n".join(lines)
	_detail_cache[key] = detail
	return detail

static func empty_detail_text() -> String:
	if _empty_detail_cache != "":
		return _empty_detail_cache
	_empty_detail_cache = "[font_size=28][b]招式详情[/b][/font_size]\n\n从左侧选择一张招式牌，这里会显示完整说明、势力消耗、范围与效果。"
	return _empty_detail_cache

static func focused_card(draft_player_intent: IntentData, player_intent: IntentData) -> CardData:
	if draft_player_intent != null and draft_player_intent.actual_card != null:
		return draft_player_intent.actual_card
	if player_intent != null and player_intent.actual_card != null:
		return player_intent.actual_card
	return null

static func clear_text_cache() -> void:
	_summary_cache.clear()
	_button_text_cache.clear()
	_detail_cache.clear()
	_intent_text_cache.clear()
	_effect_preview_cache.clear()
	_empty_detail_cache = ""
