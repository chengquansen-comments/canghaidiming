extends RefCounted
class_name BattleHudHelper

static func compact_effect_summary(card: Object) -> String:
	var pieces: Array[String] = []
	pieces.append("耗势 %d" % card.momentum_cost)
	pieces.append("距%d-%d" % [card.min_distance, card.max_distance])
	if card.damage > 0:
		pieces.append("伤害 %d" % card.damage)
	elif card.guard > 0:
		pieces.append("格挡 %d" % card.guard)
	elif card.gain_momentum > 0 or card.break_momentum > 0:
		var momentum_parts: Array[String] = []
		if card.gain_momentum > 0:
			momentum_parts.append("增势 %d" % card.gain_momentum)
		if card.break_momentum > 0:
			momentum_parts.append("削势 %d" % card.break_momentum)
		pieces.append(" / ".join(momentum_parts))
	if not card.tags.is_empty():
		pieces.append("标签 %s" % " / ".join(card.tags))
	return "｜".join(pieces)

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
	lines.append("[b]招式详情｜%s[/b]" % card.display_name)
	lines.append("%s｜距离 %d-%d｜耗势 %d" % [card.type_label(), card.min_distance, card.max_distance, card.momentum_cost])
	if not card.tags.is_empty():
		lines.append("标签：%s" % " / ".join(card.tags))
	var effect_lines: Array[String] = []
	if card.damage > 0:
		effect_lines.append("造成 %d 点伤害。" % card.damage)
	if card.guard > 0:
		effect_lines.append("提供 %d 点格挡。" % card.guard)
	if card.gain_momentum > 0:
		effect_lines.append("回复 %d 点势。" % card.gain_momentum)
	if card.break_momentum > 0:
		effect_lines.append("削减对手 %d 点势。" % card.break_momentum)
	if effect_lines.is_empty():
		effect_lines.append("本招式没有直接伤害、格挡或势变化。")
	lines.append("效果：%s" % " ".join(effect_lines))
	lines.append("说明：%s" % card.description)
	return "\n".join(lines)
