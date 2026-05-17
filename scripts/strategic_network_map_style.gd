extends RefCounted

# Centralized visual constants for StrategicNetworkMapView.
#
# Keep this file free of graph layout, click handling, state mutation, and UI node creation.
# It only owns drawing style values: sizes, marks, labels, legend text, and colors.

const NODE_RADIUS := 24.0
const SELECTED_RING_EXTRA_RADIUS := 14.0
const AVAILABLE_AURA_EXTRA_RADIUS := 20.0
const OUTLINE_EXTRA_RADIUS := 5.0
const CLICK_EXTRA_RADIUS := 12.0
const VIEW_PADDING := 42.0
const HEADER_RESERVED_HEIGHT := 48.0
const LEGEND_RESERVED_HEIGHT := 88.0
const TITLE_MAX_CHARS := 5
const TITLE_FONT_SIZE := 14
const MARK_FONT_SIZE := 24
const LAYER_HEADER_FONT_SIZE := 14
const LEGEND_FONT_SIZE := 13
const BADGE_FONT_SIZE := 12
const BADGE_PADDING_X := 9.0
const BADGE_PADDING_Y := 4.0
const BADGE_OFFSET_Y := 32.0
const BADGE_SPACING := 4.0
const DEFAULT_MINIMUM_SIZE := Vector2(1380, 760)
const CANVAS_PADDING_X := 122.0
const CANVAS_PADDING_Y := 116.0
const LAYER_GAP := 136.0
const LANE_CLUSTER_HEIGHT := 420.0
const LEGEND_TEXT := "卫卫所  报塘报  汛海汛  倭倭警  民乡约  寨水寨  师师门  物物证  首首恶"

const BACKGROUND_FILL_COLOR := Color(0.72, 0.66, 0.53, 0.98)
const BACKGROUND_BORDER_COLOR := Color(0.32, 0.25, 0.16, 0.78)
const SEA_WASH_COLOR := Color(0.29, 0.46, 0.50, 0.30)
const SEA_LINE_COLOR := Color(0.15, 0.29, 0.33, 0.26)
const COAST_LINE_COLOR := Color(0.18, 0.13, 0.08, 0.55)
const COAST_FILL_COLOR := Color(0.45, 0.39, 0.26, 0.18)
const GRID_LINE_COLOR := Color(0.20, 0.16, 0.10, 0.12)
const LAYER_DIVIDER_COLOR := Color(0.20, 0.16, 0.10, 0.18)
const CURRENT_LAYER_BAND_COLOR := Color(0.63, 0.13, 0.08, 0.09)
const CURRENT_LAYER_BORDER_COLOR := Color(0.64, 0.14, 0.08, 0.30)
const LAYER_HEADER_COLOR := Color(0.24, 0.19, 0.12, 0.72)
const ACTIVE_LAYER_HEADER_COLOR := Color(0.55, 0.11, 0.07, 0.96)
const AVAILABLE_AURA_COLOR := Color(0.77, 0.25, 0.13, 0.16)
const CURRENT_NODE_DOT_COLOR := Color(0.64, 0.10, 0.07, 0.98)
const LEGEND_PANEL_FILL_COLOR := Color(0.62, 0.55, 0.40, 0.90)
const LEGEND_PANEL_BORDER_COLOR := Color(0.31, 0.24, 0.15, 0.66)
const COMPASS_COLOR := Color(0.25, 0.18, 0.10, 0.55)
const SEAL_COLOR := Color(0.58, 0.08, 0.06, 0.62)

const NODE_TYPE_META := {
	"military": {"mark": "卫", "label": "卫所军令", "color": Color(0.20, 0.36, 0.40)},
	"case": {"mark": "报", "label": "塘报旧案", "color": Color(0.50, 0.34, 0.12)},
	"investigation": {"mark": "查", "label": "巡检查勘", "color": Color(0.50, 0.34, 0.12)},
	"combat_common": {"mark": "汛", "label": "海汛接战", "color": Color(0.58, 0.17, 0.10)},
	"combat_elite": {"mark": "倭", "label": "倭警强敌", "color": Color(0.47, 0.06, 0.05)},
	"folk": {"mark": "民", "label": "民船乡约", "color": Color(0.20, 0.40, 0.30)},
	"reputation": {"mark": "民", "label": "乡约清望", "color": Color(0.20, 0.40, 0.30)},
	"rest": {"mark": "寨", "label": "水寨整备", "color": Color(0.27, 0.38, 0.43)},
	"master": {"mark": "师", "label": "师门旧识", "color": Color(0.27, 0.23, 0.34)},
	"old_item": {"mark": "物", "label": "旧案物证", "color": Color(0.47, 0.34, 0.12)},
	"boss": {"mark": "首", "label": "海寇首恶", "color": Color(0.42, 0.04, 0.04)},
	"risk": {"mark": "险", "label": "险汛", "color": Color(0.39, 0.24, 0.16)},
}

const DEFAULT_NODE_META := {"mark": "?", "label": "未知", "color": Color(0.42, 0.42, 0.42)}


static func node_type_meta(node_type: String) -> Dictionary:
	return NODE_TYPE_META.get(node_type, DEFAULT_NODE_META) as Dictionary


static func short_title(title: String) -> String:
	var clean := title.strip_edges()
	if clean.length() <= TITLE_MAX_CHARS:
		return clean
	return clean.substr(0, TITLE_MAX_CHARS) + "…"


static func layer_label(layer: int) -> String:
	return "第 %d 汛" % [layer + 1]


static func edge_color(from_state: String, to_state: String, is_highlight: bool) -> Color:
	if is_highlight:
		return Color(0.56, 0.10, 0.06, 0.92)
	if from_state == "unreachable" or to_state == "unreachable":
		return Color(0.18, 0.15, 0.10, 0.26)
	return Color(0.25, 0.20, 0.13, 0.34)


static func state_fill_color(base_color: Color, state: String) -> Color:
	match state:
		"completed":
			return Color(0.29, 0.43, 0.29, 0.98)
		"available", "start":
			return base_color.lightened(0.08)
		"unreachable":
			return Color(0.35, 0.33, 0.27, 0.82)
		"locked":
			return Color(base_color.r * 0.65, base_color.g * 0.65, base_color.b * 0.65, 0.58)
	return base_color


static func state_outline_color(state: String) -> Color:
	match state:
		"completed":
			return Color(0.18, 0.30, 0.18, 0.95)
		"available", "start":
			return Color(0.64, 0.12, 0.08, 0.95)
		"unreachable":
			return Color(0.18, 0.18, 0.18, 0.80)
		"locked":
			return Color(0.36, 0.31, 0.23, 0.70)
	return Color(0.40, 0.31, 0.20, 0.80)


static func state_title_color(state: String) -> Color:
	match state:
		"available", "start":
			return Color(0.38, 0.08, 0.05, 0.96)
		"completed":
			return Color(0.17, 0.28, 0.16, 0.92)
		"unreachable":
			return Color(0.52, 0.52, 0.52, 0.62)
		"locked":
			return Color(0.34, 0.30, 0.23, 0.60)
	return Color(0.30, 0.24, 0.16, 0.82)


static func selected_ring_color() -> Color:
	return Color(0.63, 0.10, 0.07, 0.86)


static func available_aura_color() -> Color:
	return AVAILABLE_AURA_COLOR


static func current_node_dot_color() -> Color:
	return CURRENT_NODE_DOT_COLOR


static func mark_color() -> Color:
	return Color(0.96, 0.90, 0.76)


static func legend_color() -> Color:
	return Color(0.22, 0.17, 0.10, 0.86)


static func background_fill_color() -> Color:
	return BACKGROUND_FILL_COLOR


static func background_border_color() -> Color:
	return BACKGROUND_BORDER_COLOR


static func layer_divider_color() -> Color:
	return LAYER_DIVIDER_COLOR


static func current_layer_band_color() -> Color:
	return CURRENT_LAYER_BAND_COLOR


static func current_layer_border_color() -> Color:
	return CURRENT_LAYER_BORDER_COLOR


static func layer_header_color(active: bool) -> Color:
	return ACTIVE_LAYER_HEADER_COLOR if active else LAYER_HEADER_COLOR


static func legend_panel_fill_color() -> Color:
	return LEGEND_PANEL_FILL_COLOR


static func legend_panel_border_color() -> Color:
	return LEGEND_PANEL_BORDER_COLOR


static func sea_wash_color() -> Color:
	return SEA_WASH_COLOR


static func sea_line_color() -> Color:
	return SEA_LINE_COLOR


static func coast_line_color() -> Color:
	return COAST_LINE_COLOR


static func coast_fill_color() -> Color:
	return COAST_FILL_COLOR


static func grid_line_color() -> Color:
	return GRID_LINE_COLOR


static func compass_color() -> Color:
	return COMPASS_COLOR


static func seal_color() -> Color:
	return SEAL_COLOR


static func badge_fill_color(kind: String) -> Color:
	match kind:
		"战":
			return Color(0.56, 0.10, 0.06, 0.96)
		"倭":
			return Color(0.42, 0.04, 0.04, 0.96)
		"营":
			return Color(0.18, 0.35, 0.29, 0.96)
	return Color(0.25, 0.20, 0.14, 0.90)


static func badge_text_color() -> Color:
	return Color(0.97, 0.95, 0.88, 0.98)


static func should_draw_title(state: String, is_selected: bool) -> bool:
	return is_selected or state == "available" or state == "completed" or state == "start"


static func should_draw_badge(state: String, is_selected: bool, node_type: String) -> bool:
	return is_selected or state == "available" or state == "completed" or node_type == "combat_elite"
