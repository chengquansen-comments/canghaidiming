extends RefCounted

# Centralized visual constants for StrategicNetworkMapView.
#
# Keep this file free of graph layout, click handling, state mutation, and UI node creation.
# It only owns drawing style values: sizes, marks, labels, legend text, and colors.

const NODE_RADIUS := 24.0
const SELECTED_RING_EXTRA_RADIUS := 12.0
const OUTLINE_EXTRA_RADIUS := 5.0
const CLICK_EXTRA_RADIUS := 10.0
const VIEW_PADDING := 46.0
const LEGEND_RESERVED_HEIGHT := 54.0
const TITLE_MAX_CHARS := 4
const TITLE_FONT_SIZE := 13
const MARK_FONT_SIZE := 24
const LEGEND_FONT_SIZE := 12
const BADGE_FONT_SIZE := 11
const BADGE_PADDING_X := 8.0
const BADGE_PADDING_Y := 4.0
const BADGE_OFFSET_Y := 30.0
const BADGE_SPACING := 4.0
const DEFAULT_MINIMUM_SIZE := Vector2(1280, 620)
const CANVAS_PADDING_X := 96.0
const CANVAS_PADDING_Y := 92.0
const LAYER_GAP := 118.0
const LANE_CLUSTER_HEIGHT := 360.0
const LEGEND_TEXT := "令军令  案旧案  战战斗  精精英  民清望  息休整  师师父  物旧物  首首领\n角标：B=累计战斗  E=累计精英  O=累计经营，范围表示不同路线会浮动"

const NODE_TYPE_META := {
	"military": {"mark": "令", "label": "军令", "color": Color(0.35, 0.48, 0.62)},
	"case": {"mark": "案", "label": "旧案", "color": Color(0.66, 0.55, 0.28)},
	"investigation": {"mark": "案", "label": "调查", "color": Color(0.66, 0.55, 0.28)},
	"combat_common": {"mark": "战", "label": "普通战斗", "color": Color(0.62, 0.28, 0.20)},
	"combat_elite": {"mark": "精", "label": "精英战", "color": Color(0.50, 0.10, 0.12)},
	"folk": {"mark": "民", "label": "民间", "color": Color(0.22, 0.50, 0.42)},
	"reputation": {"mark": "民", "label": "清望", "color": Color(0.22, 0.50, 0.42)},
	"rest": {"mark": "息", "label": "休整", "color": Color(0.38, 0.48, 0.55)},
	"master": {"mark": "师", "label": "师父", "color": Color(0.30, 0.26, 0.40)},
	"old_item": {"mark": "物", "label": "旧物", "color": Color(0.58, 0.45, 0.22)},
	"boss": {"mark": "首", "label": "首领", "color": Color(0.46, 0.08, 0.08)},
	"risk": {"mark": "险", "label": "风险", "color": Color(0.42, 0.28, 0.24)},
}

const DEFAULT_NODE_META := {"mark": "?", "label": "未知", "color": Color(0.42, 0.42, 0.42)}


static func node_type_meta(node_type: String) -> Dictionary:
	return NODE_TYPE_META.get(node_type, DEFAULT_NODE_META) as Dictionary


static func short_title(title: String) -> String:
	var clean := title.strip_edges()
	if clean.length() <= TITLE_MAX_CHARS:
		return clean
	return clean.substr(0, TITLE_MAX_CHARS) + "…"


static func edge_color(from_state: String, to_state: String, is_highlight: bool) -> Color:
	if is_highlight:
		return Color(0.90, 0.72, 0.35, 0.95)
	if from_state == "unreachable" or to_state == "unreachable":
		return Color(0.20, 0.20, 0.20, 0.35)
	return Color(0.50, 0.55, 0.58, 0.42)


static func state_fill_color(base_color: Color, state: String) -> Color:
	match state:
		"completed":
			return Color(0.35, 0.57, 0.33, 0.98)
		"available", "start":
			return base_color.lightened(0.08)
		"unreachable":
			return Color(0.22, 0.22, 0.22, 0.80)
		"locked":
			return Color(base_color.r * 0.55, base_color.g * 0.55, base_color.b * 0.55, 0.65)
	return base_color


static func state_outline_color(state: String) -> Color:
	match state:
		"completed":
			return Color(0.88, 0.82, 0.45, 0.95)
		"available", "start":
			return Color(0.86, 0.88, 0.90, 0.95)
		"unreachable":
			return Color(0.18, 0.18, 0.18, 0.80)
		"locked":
			return Color(0.45, 0.45, 0.47, 0.70)
	return Color(0.60, 0.60, 0.62, 0.80)


static func state_title_color(state: String) -> Color:
	match state:
		"available", "start":
			return Color(0.95, 0.88, 0.66, 0.96)
		"completed":
			return Color(0.78, 0.92, 0.72, 0.92)
		"unreachable":
			return Color(0.52, 0.52, 0.52, 0.62)
		"locked":
			return Color(0.60, 0.60, 0.62, 0.60)
	return Color(0.86, 0.82, 0.72, 0.82)


static func selected_ring_color() -> Color:
	return Color(0.92, 0.78, 0.38, 0.88)


static func mark_color() -> Color:
	return Color(0.96, 0.94, 0.86)


static func legend_color() -> Color:
	return Color(0.78, 0.70, 0.56, 0.78)


static func badge_fill_color(kind: String) -> Color:
	match kind:
		"B":
			return Color(0.69, 0.25, 0.16, 0.96)
		"E":
			return Color(0.55, 0.12, 0.18, 0.96)
		"O":
			return Color(0.22, 0.44, 0.38, 0.96)
	return Color(0.32, 0.32, 0.32, 0.90)


static func badge_text_color() -> Color:
	return Color(0.97, 0.95, 0.88, 0.98)


static func should_draw_title(state: String, is_selected: bool) -> bool:
	return is_selected or state == "available" or state == "completed" or state == "start"


static func should_draw_badge(state: String, is_selected: bool, node_type: String) -> bool:
	return is_selected or state == "available" or state == "completed" or node_type == "combat_elite"
