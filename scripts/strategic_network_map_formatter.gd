extends RefCounted

# Pure text-formatting helpers for strategic network-map UI.
# Keep this file free of UI node creation, scene switching, and battle side effects.

const EFFECT_LABELS := {
	"military_merit": "军功",
	"clean_reputation": "清望",
	"case_clues": "旧案",
	"rival_gu_bond": "顾承岳",
	"rival_shen_bond": "沈照夜",
	"rival_qi_bond": "戚衡",
	"soldier_trust": "兵心",
	"career_choice": "DEBUG 职业选择",
}

const LINE_LABELS := {
	"military": "军功",
	"military_merit": "军功",
	"case": "旧案",
	"case_clues": "旧案",
	"investigation": "调查",
	"clean_reputation": "清望",
	"reputation": "清望",
	"folk": "民间",
	"master": "师父",
	"old_item": "旧物",
	"combat": "战斗",
}

const NODE_TYPE_LABELS := {
	"military": "军令",
	"case": "旧案",
	"investigation": "调查",
	"combat_common": "普通战斗",
	"combat_elite": "精英战",
	"folk": "民间",
	"reputation": "清望",
	"rest": "休整",
	"master": "师父",
	"old_item": "旧物",
	"boss": "首领",
	"risk": "风险",
}

const NODE_TYPE_MARKS := {
	"military": "令",
	"case": "案",
	"investigation": "案",
	"combat_common": "战",
	"combat_elite": "精",
	"folk": "民",
	"reputation": "民",
	"rest": "息",
	"master": "师",
	"old_item": "物",
	"boss": "首",
	"risk": "险",
}

const STATE_LABELS := {
	"start": "起点",
	"available": "可前往",
	"locked": "未解锁",
	"completed": "已完成",
	"unreachable": "当前路线不可达",
	"selected": "已选中",
}

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
	for key in effects.keys():
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
		lines.append("combat_pool_id=%s" % combat_pool_id)
	if not encounter_id.is_empty():
		lines.append("encounter_id=%s" % encounter_id)
	if not battle_id.is_empty():
		lines.append("battle_id=%s" % battle_id)
	var enemy_level := int(node.get("enemy_martial_level", 0))
	if enemy_level > 0:
		lines.append("enemy_martial_level=%d" % enemy_level)
	var min_level := int(node.get("recommended_martial_min", 0))
	var max_level := int(node.get("recommended_martial_max", 0))
	if min_level > 0 or max_level > 0:
		lines.append("recommended=%d-%d" % [min_level, max_level])
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
		var next_node: Dictionary = by_id[next_id]
		parts.append("%s｜%s" % [
			str(next_node.get("title", next_id)),
			node_type_label(str(next_node.get("node_type", ""))),
		])
	return "\n".join(parts)

static func confirm_status_text(confirm_meta: Dictionary) -> String:
	if bool(confirm_meta.get("enabled", false)):
		return "可确认前往"
	var reason := str(confirm_meta.get("reason", confirm_meta.get("blocked_reason", "不可前往")))
	return "不可前往：%s" % reason

static func preview_text(graph: Dictionary, node: Dictionary, confirm_meta: Dictionary = {}, combat_request: Dictionary = {}) -> String:
	if node.is_empty():
		return "[b]未选择节点[/b]\n\n请选择一个海图节点。"
	var title := str(node.get("title", "未命名节点"))
	var node_type := str(node.get("node_type", ""))
	var primary_line := str(node.get("primary_line", ""))
	var secondary_line := str(node.get("secondary_line", ""))
	var text_lines: Array[String] = []
	text_lines.append("[b]【%s】%s[/b]" % [title, node_type_mark(node_type)])
	text_lines.append("类型：%s" % node_type_label(node_type))
	text_lines.append("状态：%s" % state_label(str(node.get("state", "locked"))))
	text_lines.append("前往状态：%s" % confirm_status_text(confirm_meta))
	text_lines.append("主线：%s｜副线：%s" % [line_label(primary_line), line_label(secondary_line)])
	text_lines.append("")
	text_lines.append(str(node.get("preview_text", "")))
	text_lines.append("")
	text_lines.append("[b]预期影响：[/b]")
	text_lines.append(effects_preview_text(node.get("effects", {}) as Dictionary))
	text_lines.append("")
	text_lines.append("[b]后续可达：[/b]")
	text_lines.append(outgoing_preview_text(graph, node))
	text_lines.append("")
	text_lines.append("[b]标签：[/b]")
	text_lines.append(tags_text(node.get("tags", []) as Array))
	text_lines.append("")
	text_lines.append("[b]战斗：[/b]")
	text_lines.append(combat_debug_text(node, combat_request))
	if bool(node.get("debug_fallback", false)):
		text_lines.append("")
		text_lines.append("[color=#d9a441]DEBUG fallback node[/color]")
	return "\n".join(text_lines)

static func final_gate_text(graph: Dictionary, strategic_state: Dictionary, profile: Dictionary = {}) -> String:
	var completed_count := (graph.get("completed_node_ids", []) as Array).size()
	var martial_level := int(profile.get("martial_level", strategic_state.get("martial_level", 1)))
	var lines: Array[String] = []
	lines.append("[b]海门收束[/b]")
	lines.append("")
	lines.append("海图上的线走到尽头。")
	lines.append("潮声压低，旧案、军功与人声都被推到最后一战前。")
	lines.append("")
	lines.append("[b]本局状态[/b]")
	lines.append("军功：%d" % int(strategic_state.get("military_merit", strategic_state.get("jun_gong", 0))))
	lines.append("清望：%d" % int(strategic_state.get("clean_reputation", strategic_state.get("qing_wang", 0))))
	lines.append("旧案：%d" % int(strategic_state.get("case_clues", strategic_state.get("clues", 0))))
	lines.append("武境：%d" % martial_level)
	lines.append("已完成节点：%d" % completed_count)
	lines.append("")
	lines.append("[b]临时收束[/b]")
	lines.append("本轮暂不接 final_boss_rules，先使用倭寇首领战作为 final gate fallback。")
	return "\n".join(lines)
