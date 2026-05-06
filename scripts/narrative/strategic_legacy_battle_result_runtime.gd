extends RefCounted

const StrategicWorldMapRuntime := preload("res://scripts/narrative/strategic_world_map_runtime.gd")

static func consume_result(strategic_config: Dictionary, source_id: String, result: String) -> Dictionary:
	if result != "win":
		return {
			"completed": false,
			"last_hint": "大势图战斗未胜：当前层暂不推进。",
			"node": {},
		}
	var node := StrategicWorldMapRuntime.find_node(strategic_config, source_id)
	if node.is_empty():
		return {
			"completed": false,
			"last_hint": "大势图战斗胜利：未找到节点配置，暂不结算。",
			"node": {},
		}
	return {
		"completed": true,
		"last_hint": "",
		"node": node,
	}
