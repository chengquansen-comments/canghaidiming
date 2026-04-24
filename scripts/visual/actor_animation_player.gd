extends RefCounted
class_name ActorAnimationPlayer

const BattleSkinHelper = preload("res://scripts/visual/battle_skin.gd")
const ActorAnimationMeta = preload("res://scripts/visual/actor_animation_meta.gd")

signal frame_changed(animation_name: String, frame_index: int)
signal hit_frame_reached(animation_name: String, frame_index: int)
signal animation_finished(animation_name: String)

var meta: ActorAnimationMeta = null
var target: TextureRect = null
var current_animation: String = ""
var current_frame: int = 0
var elapsed: float = 0.0
var playing: bool = false
var _hit_emitted: bool = false
var _source_texture_cache: Dictionary = {}

func bind(p_meta: ActorAnimationMeta, p_target: TextureRect) -> void:
	meta = p_meta
	target = p_target
	current_animation = ""
	current_frame = 0
	elapsed = 0.0
	playing = false
	_hit_emitted = false
	_source_texture_cache.clear()

func play(animation_name: String, restart: bool = false) -> void:
	if meta == null or not meta.is_valid or target == null:
		return
	if not meta.has_animation(animation_name):
		return
	if current_animation == animation_name and playing and not restart:
		return
	current_animation = animation_name
	current_frame = 0
	elapsed = 0.0
	playing = true
	_hit_emitted = false
	_apply_current_frame()

func stop() -> void:
	playing = false
	elapsed = 0.0

func update(delta: float) -> void:
	if not playing or meta == null or target == null or current_animation == "":
		return
	var fps: float = maxf(meta.animation_fps(current_animation), 0.001)
	var frame_duration: float = 1.0 / fps
	elapsed += delta
	while elapsed >= frame_duration and playing:
		elapsed -= frame_duration
		_advance_frame()
		if playing:
			_apply_current_frame()

func is_playing(animation_name: String = "") -> bool:
	if animation_name == "":
		return playing
	return playing and current_animation == animation_name

func _advance_frame() -> void:
	var frame_count: int = maxi(meta.animation_frames(current_animation), 1)
	var loops: bool = meta.animation_loops(current_animation)
	current_frame += 1
	if current_frame >= frame_count:
		if loops:
			current_frame = 0
			_hit_emitted = false
		else:
			current_frame = frame_count - 1
			playing = false
			_apply_current_frame()
			emit_signal("animation_finished", current_animation)

func _apply_current_frame() -> void:
	var texture: Texture2D = _texture_for_animation(current_animation)
	if texture == null:
		return
	var frame_count: int = maxi(meta.animation_frames(current_animation), 1)
	var frame_size: Vector2i = meta.frame_size
	var frame: int = clampi(current_frame, 0, frame_count - 1)
	target.texture = BattleSkinHelper.atlas_frame(texture, frame_size, frame)
	emit_signal("frame_changed", current_animation, frame)
	var hit_frame: int = meta.animation_hit_frame(current_animation)
	if hit_frame >= 0 and frame == hit_frame and not _hit_emitted:
		_hit_emitted = true
		emit_signal("hit_frame_reached", current_animation, frame)

func _texture_for_animation(animation_name: String) -> Texture2D:
	if animation_name == "":
		return null
	if _source_texture_cache.has(animation_name):
		return _source_texture_cache[animation_name] as Texture2D
	var path: String = meta.animation_texture_path(animation_name)
	if path == "":
		return null
	var texture: Texture2D = load(path) as Texture2D
	_source_texture_cache[animation_name] = texture
	return texture
