extends RefCounted
class_name NarrativeMapClickRouter

static func can_click_node(narrative: NarrativeState, node_id: String) -> bool:
	if narrative == null:
		return false
	if node_id.is_empty():
		return false
	if not narrative.current_ending_id.is_empty():
		return false
	return narrative.can_choose_next_node(node_id)

static func click_node(narrative: NarrativeState, node_id: String) -> Dictionary:
	if narrative == null:
		return {"ok": false, "result": "叙事状态未初始化。"}
	if node_id.is_empty():
		return {"ok": false, "result": "节点为空。"}
	if not narrative.current_ending_id.is_empty():
		return {"ok": false, "result": "当前已经进入结局，不能继续选路。"}
	return narrative.choose_next_node(node_id)

static func click_hint(narrative: NarrativeState, node_id: String) -> String:
	if narrative == null:
		return "未初始化"
	if node_id == narrative.current_node_id:
		return "当前节点"
	if narrative.visited_node_ids.has(node_id):
		return "已走过"
	if narrative.can_choose_next_node(node_id):
		return "可前往"
	return "未开放"
