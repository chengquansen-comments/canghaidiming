extends RefCounted
class_name BattleHudHelper

static func compact_effect_summary(card: Object) -> String:
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
	return "\n".join(pieces)

static func compact_button_text(card: Object, card_role_prefix: String, marker: String, is_drafted: bool) -> String:
	var title := "%s %s" % [card_role_prefix, card.display_name]
	if is_drafted:
		title = "[已选] " + title
	var lines: Array[String] = [title, compact_effect_summary(card)]
	if marker != "":
		lines.append(marker)
	return "\n".join(lines)

static func card_detail_text(card: Object) -> String:
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
	return "\n".join(lines)

static func empty_detail_text() -> String:
	return "[font_size=28][b]招式详情[/b][/font_size]\n\n从左侧选择一张招式牌，这里会显示完整说明、势力消耗、范围与效果。"

static func focused_card(draft_player_intent: Object, player_intent: Object, awaiting_player_input: bool) -> Object:
	if draft_player_intent != null and draft_player_intent.actual_card != null:
		return draft_player_intent.actual_card
	if player_intent != null and player_intent.actual_card != null and awaiting_player_input:
		return player_intent.actual_card
	return null
