extends RefCounted
class_name BattleActorRenderHelper

const BattleSkinHelper = preload("res://scripts/visual/battle_skin.gd")
const BattleStageHelper = preload("res://scripts/visual/battle_stage_view.gd")

# Visual actor tuning for the 1600x960 battle layout.
# Grid slot is around y=468..516. Foot point is kept just above the lower slot edge,
# so the actor reads as standing inside the selected grid cell.
const ACTOR_RENDER_SIZE := Vector2(250, 250)
const ACTOR_FOOT_OFFSET_X := 140.0
const ACTOR_GROUND_Y := 512.0
const MIN_HORIZONTAL_SHEET_RATIO := 2.35

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
	if source_width <= 0 or source_height <= 0:
		return source

	# First handle the real production case: a horizontal multi-frame actor sheet.
	# Do not require a fixed 384px height; otherwise tall sheets fall through and get
	# displayed as three repeated actors in one TextureRect.
	var safe_count: int = maxi(sheet_frame_count, 1)
	var looks_like_horizontal_sheet: bool = safe_count > 1 and float(source_width) / float(source_height) >= MIN_HORIZONTAL_SHEET_RATIO
	if looks_like_horizontal_sheet:
		var dynamic_frame_width: int = int(round(float(source_width) / float(safe_count)))
		var dynamic_frame_size := Vector2i(dynamic_frame_width, source_height)
		var safe_frame: int = clampi(frame, 0, safe_count - 1)
		return BattleSkinHelper.atlas_frame(source, dynamic_frame_size, safe_frame)

	# Keep compatibility with old fixed-size 384x384 sheets.
	var expected_width: int = frame_size.x * safe_count
	if source_height == frame_size.y and source_width >= expected_width:
		return BattleSkinHelper.atlas_frame(source, frame_size, frame)

	return source

static func slot_top_left(scene_width: float, slot: int, is_player: bool, slot_count: int, slot_width: float, slot_gap: float) -> Vector2:
	return BattleStageHelper.slot_top_left(scene_width, slot, is_player, slot_count, slot_width, slot_gap, ACTOR_GROUND_Y, ACTOR_RENDER_SIZE.y, ACTOR_FOOT_OFFSET_X, ACTOR_FOOT_OFFSET_X)

static func animated_actor_top_left(scene_width: float, is_player: bool, start_slot: int, target_slot: int, active: bool, phase: float, slot_count: int, slot_width: float, slot_gap: float) -> Vector2:
	return BattleStageHelper.animated_actor_top_left(scene_width, is_player, start_slot, target_slot, active, phase, slot_count, slot_width, slot_gap, ACTOR_GROUND_Y, ACTOR_RENDER_SIZE.y, ACTOR_FOOT_OFFSET_X, ACTOR_FOOT_OFFSET_X)
