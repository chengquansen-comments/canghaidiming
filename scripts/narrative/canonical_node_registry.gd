extends RefCounted

# Static MVP node registry and node merge helpers for canonical narrative controllers.
#
# Pure helper only. It does not render UI, save context, advance nodes, start
# battles, or call owner/controller methods.

const MVP_NODE_IDS := [
	"military_order",
	"beach_ambush",
	"beach_ambush_aftermath",
	"fishing_village_embers",
	"fishing_village_embers_aftermath",
	"ming_firearm",
	"altered_military_report",
	"transport_officer",
	"transport_officer_aftermath",
	"night_knife_camp",
	"wakou_boss",
	"military_coverup",
]

const MVP_NODE_META := {
	"military_order": {"column":"军令", "type":"事件", "visual_path":"res://assets/pixel_battle/backgrounds/narrative_military_order.png"},
	"beach_ambush": {"column":"初遇", "type":"普通战斗", "visual_path":"res://assets/pixel_battle/backgrounds/narrative_beach_ambush.png"},
	"beach_ambush_aftermath": {"column":"初遇", "type":"战后处理", "visual_path":"res://assets/pixel_battle/backgrounds/narrative_beach_ambush.png"},
	"fishing_village_embers": {"column":"初遇", "type":"普通战斗", "visual_path":"res://assets/pixel_battle/backgrounds/narrative_fishing_village_embers.png"},
	"fishing_village_embers_aftermath": {"column":"初遇", "type":"战后处理", "visual_path":"res://assets/pixel_battle/backgrounds/narrative_fishing_village_embers.png"},
	"ming_firearm": {"column":"疑点", "type":"旧物", "visual_path":"res://assets/pixel_battle/relics/relic_ming_firearm.png"},
	"altered_military_report": {"column":"疑点", "type":"旧物", "visual_path":"res://assets/pixel_battle/relics/relic_altered_military_report.png"},
	"transport_officer": {"column":"压迫", "type":"精英战斗", "visual_path":"res://assets/pixel_battle/portraits/transport_officer.png"},
	"transport_officer_aftermath": {"column":"压迫", "type":"战后处理", "visual_path":"res://assets/pixel_battle/portraits/transport_officer.png"},
	"night_knife_camp": {"column":"压迫", "type":"事件", "visual_path":"res://assets/pixel_battle/backgrounds/narrative_night_knife_camp.png"},
	"wakou_boss": {"column":"破船", "type":"Boss", "visual_path":"res://assets/pixel_battle/portraits/wakou_leader.png"},
	"military_coverup": {"column":"军门", "type":"结尾", "visual_path":"res://assets/pixel_battle/backgrounds/narrative_military_coverup.png"},
}


static func active_node_ids(flow_node_ids: Array = []) -> Array:
	if not flow_node_ids.is_empty():
		return flow_node_ids.duplicate()
	return MVP_NODE_IDS.duplicate()


static func node_id_at(active_ids: Array, index: int) -> String:
	if index >= 0 and index < active_ids.size():
		return str(active_ids[index])
	return ""


static func node_meta(node_id: String) -> Dictionary:
	var meta = MVP_NODE_META.get(node_id, {})
	if meta is Dictionary:
		return (meta as Dictionary).duplicate(true)
	return {}


static func merge_node_data(node_id: String, configured: Dictionary) -> Dictionary:
	var node: Dictionary = node_meta(node_id)
	for key in configured.keys():
		node[key] = configured[key]
	node["id"] = node_id
	if not node.has("title"):
		node["title"] = node_id
	if not node.has("column"):
		node["column"] = ""
	if not node.has("type"):
		node["type"] = "事件"
	if not node.has("visual_path"):
		node["visual_path"] = ""
	return node


static func configured_choices(configured_node: Dictionary) -> Array:
	var choices = configured_node.get("choices", [])
	if choices is Array:
		return choices
	return []
