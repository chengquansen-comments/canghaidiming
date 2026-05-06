extends RefCounted

const BattleStageHelper := preload("res://scripts/visual/battle_stage_view.gd")

# Cached range overlay polygon/line renderer for battle grid previews.
#
# Requires owner:
# - range_overlay_layer
# - _range_trapezoid_points(slot, origin_slot)

var c
var _range_polygon_pool: Array[Polygon2D] = []
var _range_line_pool: Array[Line2D] = []
var _active_range_polygons: Array[Polygon2D] = []
var _active_range_lines: Array[Line2D] = []

func _init(controller) -> void:
	c = controller


func clear_range_trapezoids() -> void:
	recycle_range_overlay_nodes()


func refresh_range_trapezoids(player_range: Array[int], player_origin_slot: int, enemy_range: Array[int], enemy_origin_slot: int) -> void:
	if c.range_overlay_layer == null:
		return
	recycle_range_overlay_nodes()
	var player_style: Dictionary = BattleStageHelper.range_overlay_style(true)
	for slot in player_range:
		draw_range_trapezoid(slot, player_origin_slot, int(player_style.get("polygon_z", 2)), player_style.get("fill_color", Color(1, 1, 1, 0.2)) as Color, player_style.get("outline_color", Color(1, 1, 1, 0.7)) as Color)
	var enemy_style: Dictionary = BattleStageHelper.range_overlay_style(false)
	for slot in enemy_range:
		draw_range_trapezoid(slot, enemy_origin_slot, int(enemy_style.get("polygon_z", 2)), enemy_style.get("fill_color", Color(1, 1, 1, 0.2)) as Color, enemy_style.get("outline_color", Color(1, 1, 1, 0.7)) as Color)


func draw_range_trapezoid(slot: int, origin_slot: int, z_index: int, fill_color: Color, outline_color: Color) -> void:
	if c.range_overlay_layer == null:
		return
	var points: PackedVector2Array = c._range_trapezoid_points(slot, origin_slot)
	var polygon: Polygon2D = take_range_polygon()
	polygon.polygon = points
	polygon.color = fill_color
	polygon.z_index = z_index
	polygon.visible = true
	_active_range_polygons.append(polygon)
	var outline: Line2D = take_range_line()
	outline.points = points
	outline.closed = true
	outline.width = 3.0
	outline.default_color = outline_color
	outline.joint_mode = Line2D.LINE_JOINT_ROUND
	outline.z_index = z_index + 1
	outline.visible = true
	_active_range_lines.append(outline)


func take_range_polygon() -> Polygon2D:
	if not _range_polygon_pool.is_empty():
		return _range_polygon_pool.pop_back()
	var polygon: Polygon2D = Polygon2D.new()
	c.range_overlay_layer.add_child(polygon)
	return polygon


func take_range_line() -> Line2D:
	if not _range_line_pool.is_empty():
		return _range_line_pool.pop_back()
	var line: Line2D = Line2D.new()
	c.range_overlay_layer.add_child(line)
	return line


func recycle_range_overlay_nodes() -> void:
	for polygon in _active_range_polygons:
		polygon.visible = false
		_range_polygon_pool.append(polygon)
	for line in _active_range_lines:
		line.visible = false
		_range_line_pool.append(line)
	_active_range_polygons.clear()
	_active_range_lines.clear()
