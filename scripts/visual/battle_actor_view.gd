extends RefCounted
class_name BattleActorFootHelper

const BattleSkinHelper = preload("res://scripts/visual/battle_skin.gd")
const BattleStageHelper = preload("res://scripts/visual/battle_stage_view.gd")

# Visual actor tuning for the 1600x960 battle layout.
# Grid slot is around y=468..516. Foot point is kept just above the lower slot edge,
# so the actor reads as standing inside the selected grid cell.
const DEFAULT_FRAME_SIZE := Vector2i(512, 512)
const DEFAULT_FOOT_ANCHOR := Vector2(256, 500)
const ACTOR_RENDER_SIZE := Vector2(250, 250)
const ACTOR_GROUND_Y := 512.0
const ACTOR_FRAME_FOOT_OFFSET_META := &"actor_frame_foot_offset"
const ACTOR_DEFAULT_FACING_META := &"actor_default_facing"

static func render_size() -> Vector2:
	return ACTOR_RENDER_SIZE

static func ground_y() -> float:
	return ACTOR_GROUND_Y

static func foot_offset_x() -> float:
	return _fallback_foot_offset(ACTOR_RENDER_SIZE).x

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

static func apply_actor_meta_bounds(sprite: TextureRect, frame_size: Vector2i, foot_anchor: Vector2, actor_scale: float = 1.0, default_facing: String = "right") -> void:
	if sprite == null or frame_size.x <= 0 or frame_size.y <= 0:
		return
	var render_size := display_size_for_frame(frame_size, actor_scale)
	sprite.custom_minimum_size = render_size
	sprite.size = render_size
	sprite.clip_contents = false
	sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var scaled_foot := scaled_foot_anchor(render_size, frame_size, foot_anchor)
	sprite.set_meta(ACTOR_FRAME_FOOT_OFFSET_META, scaled_foot)
	sprite.set_meta(ACTOR_DEFAULT_FACING_META, "left" if default_facing == "left" else "right")

static func display_size_for_frame(frame_size: Vector2i, actor_scale: float = 1.0) -> Vector2:
	var safe_frame_size := frame_size if frame_size.x > 0 and frame_size.y > 0 else DEFAULT_FRAME_SIZE
	var render_height: float = ACTOR_RENDER_SIZE.y * maxf(actor_scale, 0.01)
	var render_width: float = render_height * (float(safe_frame_size.x) / float(safe_frame_size.y))
	return Vector2(render_width, render_height)

static func scaled_foot_anchor(display_size: Vector2, frame_size: Vector2i, foot_anchor: Vector2) -> Vector2:
	var safe_frame_size := frame_size if frame_size.x > 0 and frame_size.y > 0 else DEFAULT_FRAME_SIZE
	var safe_foot_anchor := foot_anchor
	if safe_foot_anchor == Vector2.ZERO:
		safe_foot_anchor = DEFAULT_FOOT_ANCHOR
	var frame_w := float(safe_frame_size.x)
	var frame_h := float(safe_frame_size.y)
	var scale := minf(display_size.x / frame_w, display_size.y / frame_h)
	var drawn_size := Vector2(frame_w * scale, frame_h * scale)
	var draw_offset := (display_size - drawn_size) * 0.5
	return draw_offset + safe_foot_anchor * scale

static func frame_foot_offset(sprite: TextureRect) -> Vector2:
	if sprite == null:
		return _fallback_foot_offset(ACTOR_RENDER_SIZE)
	var sprite_size := sprite.size if sprite.size.x > 0 and sprite.size.y > 0 else ACTOR_RENDER_SIZE
	if not sprite.has_meta(ACTOR_FRAME_FOOT_OFFSET_META):
		return _fallback_foot_offset(sprite_size)
	var value: Variant = sprite.get_meta(ACTOR_FRAME_FOOT_OFFSET_META)
	if value is Vector2:
		var offset := value as Vector2
		if sprite.flip_h:
			return Vector2(sprite_size.x - offset.x, offset.y)
		return offset
	return _fallback_foot_offset(sprite_size)

static func default_facing(sprite: TextureRect) -> String:
	if sprite == null or not sprite.has_meta(ACTOR_DEFAULT_FACING_META):
		return "right"
	return "left" if str(sprite.get_meta(ACTOR_DEFAULT_FACING_META)) == "left" else "right"

static func flip_h_for_facing(sprite: TextureRect, faces_left: bool) -> bool:
	var source_faces_left := default_facing(sprite) == "left"
	return faces_left != source_faces_left

static func frame_texture(source: Texture2D, frame: int, frame_size: Vector2i, sheet_frame_count: int) -> Texture2D:
	if source == null:
		return null
	var source_size: Vector2 = source.get_size()
	var source_width: int = int(round(source_size.x))
	var source_height: int = int(round(source_size.y))
	if source_width <= 0 or source_height <= 0:
		return source

	var safe_count: int = maxi(sheet_frame_count, 1)
	if safe_count <= 1:
		return source
	var safe_frame_size := frame_size if frame_size.x > 0 and frame_size.y > 0 else DEFAULT_FRAME_SIZE
	var expected_height: int = safe_frame_size.y * safe_count
	if source_width >= safe_frame_size.x and source_height >= expected_height:
		return BattleSkinHelper.atlas_frame(source, safe_frame_size, clampi(frame, 0, safe_count - 1), "vertical")
	var expected_width: int = safe_frame_size.x * safe_count
	if source_width >= expected_width and source_height >= safe_frame_size.y:
		return BattleSkinHelper.atlas_frame(source, safe_frame_size, clampi(frame, 0, safe_count - 1))

	return source

static func slot_top_left(scene_width: float, slot: int, is_player: bool, slot_count: int, slot_width: float, slot_gap: float) -> Vector2:
	return slot_top_left_for_foot(scene_width, slot, slot_count, slot_width, slot_gap, _fallback_foot_offset(ACTOR_RENDER_SIZE))

static func animated_actor_top_left(scene_width: float, is_player: bool, start_slot: int, target_slot: int, active: bool, phase: float, slot_count: int, slot_width: float, slot_gap: float) -> Vector2:
	return animated_actor_top_left_for_foot(scene_width, is_player, start_slot, target_slot, active, phase, slot_count, slot_width, slot_gap, _fallback_foot_offset(ACTOR_RENDER_SIZE))

static func slot_top_left_for_sprite(scene_width: float, slot: int, is_player: bool, slot_count: int, slot_width: float, slot_gap: float, sprite: TextureRect) -> Vector2:
	return slot_top_left_for_foot(scene_width, slot, slot_count, slot_width, slot_gap, frame_foot_offset(sprite))

static func animated_actor_top_left_for_sprite(scene_width: float, is_player: bool, start_slot: int, target_slot: int, active: bool, phase: float, slot_count: int, slot_width: float, slot_gap: float, sprite: TextureRect) -> Vector2:
	return animated_actor_top_left_for_foot(scene_width, is_player, start_slot, target_slot, active, phase, slot_count, slot_width, slot_gap, frame_foot_offset(sprite))

static func slot_top_left_for_foot(scene_width: float, slot: int, slot_count: int, slot_width: float, slot_gap: float, foot_offset: Vector2) -> Vector2:
	var center_x: float = BattleStageHelper.slot_center_x(scene_width, slot, slot_count, slot_width, slot_gap)
	return Vector2(center_x - foot_offset.x, ACTOR_GROUND_Y - foot_offset.y)

static func animated_actor_top_left_for_foot(scene_width: float, is_player: bool, start_slot: int, target_slot: int, active: bool, phase: float, slot_count: int, slot_width: float, slot_gap: float, foot_offset: Vector2) -> Vector2:
	var start_pos: Vector2 = slot_top_left_for_foot(scene_width, start_slot, slot_count, slot_width, slot_gap, foot_offset)
	if not active:
		return start_pos
	var target_pos: Vector2 = slot_top_left_for_foot(scene_width, target_slot, slot_count, slot_width, slot_gap, foot_offset)
	if phase < 0.26:
		return start_pos.lerp(target_pos, BattleStageHelper.ease_preview(phase / 0.26))
	if phase < 0.68:
		var dir: float = 1.0 if is_player else -1.0
		var attack_t: float = (phase - 0.26) / 0.42
		var lunge: float = sin(attack_t * PI) * 34.0
		return target_pos + Vector2(dir * lunge, -sin(attack_t * PI) * 12.0)
	if phase < 1.0:
		return target_pos.lerp(start_pos, BattleStageHelper.ease_preview((phase - 0.68) / 0.32))
	return start_pos

static func _fallback_foot_offset(display_size: Vector2) -> Vector2:
	return scaled_foot_anchor(display_size, DEFAULT_FRAME_SIZE, DEFAULT_FOOT_ANCHOR)
