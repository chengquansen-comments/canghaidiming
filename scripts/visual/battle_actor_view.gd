extends RefCounted
class_name BattleActorRenderHelper

const BattleSkinHelper = preload("res://scripts/visual/battle_skin.gd")
const BattleStageHelper = preload("res://scripts/visual/battle_stage_view.gd")

const ACTOR_RENDER_SIZE := Vector2(300, 300)
const ACTOR_FOOT_OFFSET_X := 150.0
const ACTOR_GROUND_Y := 552.0

static func render_size() -> Vector2:
	return ACTOR_RENDER_SIZE

static func ground_y() -> float:
	return ACTOR_GROUND_Y

static func foot_offset_x() -> float:
	return ACTOR_FOOT_OFFSET_X

static func apply_render_bounds(sprite: TextureRect, fallback: Control) -> void:
	if sprite != null:
		sprite.custom_minimum_size = ACTOR_RENDER_SIZE
		sprite.size = ACTOR_RENDER_SIZE
		sprite.clip_contents = false
		sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if fallback != null:
		fallback.custom_minimum_size = ACTOR_RENDER_SIZE
		fallback.size = ACTOR_RENDER_SIZE
		fallback.clip_contents = false

static func frame_texture(source: Texture2D, frame: int, frame_size: Vector2i, sheet_frame_count: int) -> Texture2D:
	if source == null:
		return null
	var source_size: Vector2 = source.get_size()
	var source_width: int = int(round(source_size.x))
	var source_height: int = int(round(source_size.y))
	var expected_width: int = frame_size.x * sheet_frame_count
	var is_standard_horizontal_sheet: bool = source_height == frame_size.y and source_width >= expected_width
	if not is_standard_horizontal_sheet:
		return source
	return BattleSkinHelper.atlas_frame(source, frame_size, frame)

static func slot_top_left(scene_width: float, slot: int, is_player: bool, slot_count: int, slot_width: float, slot_gap: float) -> Vector2:
	return BattleStageHelper.slot_top_left(scene_width, slot, is_player, slot_count, slot_width, slot_gap, ACTOR_GROUND_Y, ACTOR_RENDER_SIZE.y, ACTOR_FOOT_OFFSET_X, ACTOR_FOOT_OFFSET_X)

static func animated_actor_top_left(scene_width: float, is_player: bool, start_slot: int, target_slot: int, active: bool, phase: float, slot_count: int, slot_width: float, slot_gap: float) -> Vector2:
	return BattleStageHelper.animated_actor_top_left(scene_width, is_player, start_slot, target_slot, active, phase, slot_count, slot_width, slot_gap, ACTOR_GROUND_Y, ACTOR_RENDER_SIZE.y, ACTOR_FOOT_OFFSET_X, ACTOR_FOOT_OFFSET_X)
