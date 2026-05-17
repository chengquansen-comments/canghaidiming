extends RefCounted

# Pure text-formatting helpers for strategic network-map UI.
# Keep this file free of UI node creation, scene switching, and battle side effects.

const EFFECT_LABELS := {
	"military_merit": "军功簿",
	"clean_reputation": "乡望",
	"case_clues": "案牍",
	"rival_gu_bond": "顾承岳牒",
	"rival_shen_bond": "沈照夜信",
	"rival_qi_bond": "戚衡旧约",
	"soldier_trust": "兵心",
	"career_choice": "DEBUG 职业选择",
}

const LINE_LABELS := {
	"military": "卫所军功",
	"military_merit": "卫所军功",
	"case": "案牍线索",
	"case_clues": "案牍线索",
	"investigation": "巡检查勘",
	"clean_reputation": "乡望民声",
	"reputation": "乡望民声",
	"folk": "民船乡约",
	"master": "师门旧识",
	"old_item": "旧案物证",
	"combat": "海汛战事",
}

const NODE_TYPE_LABELS := {
	"military": "卫所军令",
	"case": "塘报旧案",
	"investigation": "巡检查勘",
	"combat_common": "海汛接战",
	"combat_elite": "倭警强敌",
	"folk": "民船乡约",
	"reputation": "乡约清望",
	"rest": "水寨整备",
	"master": "师门旧识",
	"old_item": "旧案物证",
	"boss": "海寇首恶",
	"risk": "险汛",
}

const NODE_TYPE_MARKS := {
	"military": "卫",
	"case": "报",
	"investigation": "查",
	"combat_common": "汛",
	"combat_elite": "倭",
	"folk": "民",
	"reputation": "民",
	"rest": "寨",
	"master": "师",
	"old_item": "物",
	"boss": "首",
	"risk": "险",
}

const STATE_LABELS := {
	"start": "起汛",
	"available": "可发牌",
	"locked": "未得塘报",
	"completed": "已销案",
	"unreachable": "本路不通",
	"selected": "已批选",
}

const EFFECT_ORDER := [
	"military_merit",
	"clean_reputation",
	"case_clues",
	"rival_gu_bond",
	"rival_shen_bond",
	"rival_qi_bond",
	"soldier_trust",
	"career_choice",
]

static func node_type_label(node_type: String) -> String:
	return str(NODE_TYPE_LABELS.get(node_type, node_type if not node_type.is_empty() else "未知"))

static func node_type_mark(node_type: String) -> String:
	return str(NODE_TYPE_MARKS.get(node_type, "?"))

static func line_label(line_id: String) -> String:
	return str(LINE_LABELS.get(line_id, line_id if not line_id.is_empty() else "无"))

static func state_label(state: String) -> String:
	return str(STATE_LABELS.get(state, state if not state.is_empty() else "未知"))

static func effects_preview_text(effects: Dictionary) -> String:
	if effects.is_empty():
		return "无"
	var lines: Array[String] = []
	for key in EFFECT_ORDER:
		if not effects.has(key):
			continue
		var amount := int(effects.get(key, 0))
		var label := str(EFFECT_LABELS.get(str(key), str(key)))
		var sign := "+" if amount >= 0 else ""
		lines.append("%s %s%d" % [label, sign, amount])
	for key in effects.keys():
		if key in EFFECT_ORDER:
			continue
		var amount := int(effects.get(key, 0))
		var label := str(EFFECT_LABELS.get(str(key), str(key)))
		var sign := "+" if amount >= 0 else ""
		lines.append("%s %s%d" % [label, sign, amount])
	return "\n".join(lines)

static func tags_text(tags: Array) -> String:
	if tags.is_empty():
		return "无"
	var parts: Array[String] = []
	for item in tags:
		var tag := str(item).strip_edges()
		if not tag.is_empty():
			parts.append(tag)
	return ", ".join(parts) if not parts.is_empty() else "无"

static func combat_debug_text(node: Dictionary, request: Dictionary = {}) -> String:
	var lines: Array[String] = []
	var combat_pool_id := str(node.get("combat_pool_id", ""))
	var encounter_id := str(node.get("encounter_id", ""))
	var battle_id := str(node.get("battle_id", ""))
	if request.has("combat_pool_id") and combat_pool_id.is_empty():
		combat_pool_id = str(request.get("combat_pool_id", ""))
	if request.has("encounter_id") and encounter_id.is_empty():
		encounter_id = str(request.get("encounter_id", ""))
	if request.has("battle_id") and battle_id.is_empty():
		battle_id = str(request.get("battle_id", ""))
	if not combat_pool_id.is_empty():
		lines.append("敌情册：%s" % combat_pool_id)
	if not encounter_id.is_empty():
		lines.append("战目：%s" % encounter_id)
	if not battle_id.is_empty():
		lines.append("战场：%s" % battle_id)
	var enemy_level := int(node.get("enemy_martial_level", 0))
	if enemy_level > 0:
		lines.append("敌武境：%d" % enemy_level)
	var min_level := int(node.get("recommended_martial_min", 0))
	var max_level := int(node.get("recommended_martial_max", 0))
	if min_level > 0 or max_level > 0:
		lines.append("建议武境：%d-%d" % [min_level, max_level])
	if bool(request.get("enabled", true)) == false:
		var reason := str(request.get("blocked_reason", "该战斗暂未接入。"))
		if not reason.is_empty():
			lines.append(reason)
	return "\n".join(lines) if not lines.is_empty() else "否"

static func outgoing_preview_text(graph: Dictionary, node: Dictionary) -> String:
	var outgoing: Array = node.get("outgoing", [])
	if outgoing.is_empty():
		return "无"
	var nodes: Array = graph.get("nodes", [])
	var by_id: Dictionary = {}
	for item in nodes:
		if item is Dictionary:
			var next_node := item as Dictionary
			var node_id := str(next_node.get("map_graph_id", ""))
			if not node_id.is_empty():
				by_id[node_id] = next_node
	var parts: Array[String] = []
	for item in outgoing:
		var next_id := str(item)
		if not by_id.has(next_id):
			parts.append("%s（缺失）" % next_id)
			continue
		var next_node: Dictionary = by_id[next_id] as Dictionary
		parts.append("%s｜%s" % [
			str(next_node.get("title", next_id)),
			node_type_label(str(next_node.get("node_type", ""))),
		])
	return "\n".join(parts)

static func confirm_status_text(confirm_meta: Dictionary) -> String:
	if bool(confirm_meta.get("enabled", false)):
		return "可发牌前往"
	var reason := str(confirm_meta.get("reason", confirm_meta.get("blocked_reason", "不可前往")))
	return "暂不可发牌：%s" % reason

static func _confirm_status_bbcode(confirm_meta: Dictionary) -> String:
	if bool(confirm_meta.get("enabled", false)):
		return "[color=#9dd6a4]可发牌前往[/color]"
	var reason := str(confirm_meta.get("reason", confirm_meta.get("blocked_reason", "不可前往")))
	return "[color=#d98b6f]暂不可发牌：%s[/color]" % reason

static func _body_text(value: String, fallback: String) -> String:
	var text := value.strip_edges()
	return text if not text.is_empty() else fallback

static func _bullet_lines(text: String) -> String:
	var result: Array[String] = []
	for raw in text.split("\n", false):
		var line := str(raw).strip_edges()
		if not line.is_empty():
			result.append("• %s" % line)
	return "\n".join(result) if not result.is_empty() else "无"

static func preview_text(graph: Dictionary, node: Dictionary, confirm_meta: Dictionary = {}, combat_request: Dictionary = {}) -> String:
	if node.is_empty():
		return "[b]尚未批选汛口[/b]\n[color=#5a4227]点击左侧可发牌的汛口，查看塘报、得失与后续水路。[/color]"
	var title := str(node.get("title", "未命名节点"))
	var node_type := str(node.get("node_type", ""))
	var primary_line := str(node.get("primary_line", ""))
	var secondary_line := str(node.get("secondary_line", ""))
	var preview_body := _body_text(str(node.get("preview_text", "")), "暂无风闻描述。")
	var effects_text := _bullet_lines(effects_preview_text(node.get("effects", {}) as Dictionary))
	var outgoing_text := _bullet_lines(outgoing_preview_text(graph, node))
	var tags_value := tags_text(node.get("tags", []) as Array)
	var tags_body := "无" if tags_value == "无" else "• %s" % tags_value
	var combat_body := _bullet_lines(combat_debug_text(node, combat_request))
	var text_lines: Array[String] = []
	text_lines.append("[b]%s %s[/b]" % [node_type_mark(node_type), title])
	text_lines.append("[color=#5a4227]簿类：%s｜牌面：%s[/color]" % [
		node_type_label(node_type),
		state_label(str(node.get("state", "locked"))),
	])
	text_lines.append("[color=#5a4227]主牒：%s｜旁证：%s[/color]" % [
		line_label(primary_line),
		line_label(secondary_line),
	])
	text_lines.append("[b]牌票：[/b]%s" % _confirm_status_bbcode(confirm_meta))
	text_lines.append("")
	text_lines.append("[b]塘报批注[/b]")
	text_lines.append(preview_body)
	text_lines.append("")
	text_lines.append("[b]预计得失[/b]")
	text_lines.append(effects_text)
	text_lines.append("")
	text_lines.append("[b]可转汛口[/b]")
	text_lines.append(outgoing_text)
	text_lines.append("")
	text_lines.append("[b]案签[/b]")
	text_lines.append(tags_body)
	text_lines.append("")
	text_lines.append("[b]战事札记[/b]")
	text_lines.append(combat_body)
	if bool(node.get("debug_fallback", false)):
		text_lines.append("")
		text_lines.append("[color=#d9a441]DEBUG fallback node[/color]")
	return "\n".join(text_lines)

static func final_gate_text(graph: Dictionary, strategic_state: Dictionary, profile: Dictionary = {}) -> String:
	var completed_count := (graph.get("completed_node_ids", []) as Array).size()
	var martial_level := int(profile.get("martial_level", strategic_state.get("martial_level", 1)))
	var lines: Array[String] = []
	lines.append("[b]海门合牌[/b]")
	lines.append("")
	lines.append("诸汛塘报已归一处。")
	lines.append("军功、乡望与案牍都压在最后一纸牌票上。")
	lines.append("")
	lines.append("[b]本局簿册[/b]")
	lines.append("• 军功簿：%d" % int(strategic_state.get("military_merit", strategic_state.get("jun_gong", 0))))
	lines.append("• 乡望：%d" % int(strategic_state.get("clean_reputation", strategic_state.get("qing_wang", 0))))
	lines.append("• 案牍：%d" % int(strategic_state.get("case_clues", strategic_state.get("clues", 0))))
	lines.append("• 武境：%d" % martial_level)
	lines.append("• 已销汛口：%d" % completed_count)
	lines.append("")
	lines.append("[b]临时会剿[/b]")
	lines.append("本轮暂不接 final_boss_rules，先以倭寇首恶战作为会剿收束。")
	return "\n".join(lines)
