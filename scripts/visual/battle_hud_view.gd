extends RefCounted
class_name BattleHudHelper

static var _summary_cache: Dictionary = {}
static var _button_text_cache: Dictionary = {}
static var _detail_cache: Dictionary = {}
static var _empty_detail_cache: String = ""

static func _card_key(card: CardData) -> String:
	if card == null:
		return "null"
	var tags: PackedStringArray = card.tags if card.tags != null else PackedStringArray()
	return "%s|%s|%d|%d|%d|%d|%d|%d|%s|%s" % [
		card.id,
		card.display_name,
		card.momentum_cost,
		card.min_distance,
		card.max_distance,
		card.damage,
		card.guard,
		card.gain_momentum,
		str(card.break_momentum),
		"/".join(tags)
	]

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
	_empty_detail_cache = ""
