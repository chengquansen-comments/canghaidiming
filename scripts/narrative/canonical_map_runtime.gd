extends RefCounted

const CanonicalEffectsRuntime := preload("res://scripts/narrative/canonical_effects_runtime.gd")


static func map_marker_for_index(index: int, current_index: int) -> String:
	if index == current_index:
		return "▶"
	if index < current_index:
		return "●"
	if index == current_index + 1:
		return "◎"
	return "○"


static func vars_text(military_merit: int, clean_reputation: int, case_clues: int) -> String:
	return "军功 %d / 清望 %d / 旧案线索 %d" % [military_merit, clean_reputation, case_clues]


static func current_world_map_title(node: Dictionary) -> String:
	return str(node.get("title", ""))


static func map_text(columns: Array, nodes: Array, current_index: int) -> String:
	var lines: Array[String] = []
	for col in columns:
		var items: Array[String] = []
		for i in range(nodes.size()):
			var node: Dictionary = nodes[i] if nodes[i] is Dictionary else {}
			if str(node.get("column", "")) == str(col):
				items.append("%s %s" % [map_marker_for_index(i, current_index), str(node.get("title", ""))])
		lines.append("【%s】%s" % [str(col), " / ".join(items)])
	return "\n".join(lines)


static func default_map_reward_for_node(node: Dictionary) -> Dictionary:
	match str(node.get("type", "")):
		"普通战斗", "精英战斗":
			return CanonicalEffectsRuntime.normalize_effects({
				CanonicalEffectsRuntime.VAR_MILITARY_MERIT: 1,
				CanonicalEffectsRuntime.VAR_CASE_CLUES: 1,
			})
		"Boss":
			return CanonicalEffectsRuntime.normalize_effects({
				CanonicalEffectsRuntime.VAR_MILITARY_MERIT: 2,
				CanonicalEffectsRuntime.VAR_CASE_CLUES: 1,
			})
		"旧物":
			return CanonicalEffectsRuntime.normalize_effects({
				CanonicalEffectsRuntime.VAR_CASE_CLUES: 2,
			})
		_:
			return CanonicalEffectsRuntime.normalize_effects({
				CanonicalEffectsRuntime.VAR_CLEAN_REPUTATION: 1,
			})
