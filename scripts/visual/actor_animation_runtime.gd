extends RefCounted
class_name ActorAnimationRuntime

const ActorAnimationMeta = preload("res://scripts/visual/actor_animation_meta.gd")
const ActorAnimationPlayer = preload("res://scripts/visual/actor_animation_player.gd")
const BattleActorRenderHelper = preload("res://scripts/visual/battle_actor_view.gd")

signal hit_frame_reached(actor_key: String, animation_name: String, frame_index: int, fx_id: String, impact_offset: Vector2)
signal animation_finished(actor_key: String, animation_name: String)
signal runtime_ready(actor_key: String, role_id: String)
signal runtime_failed(actor_key: String, message: String)

var actor_key: String = ""
var meta: ActorAnimationMeta = null
var player: ActorAnimationPlayer = ActorAnimationPlayer.new()
var target: TextureRect = null
var is_ready: bool = false
var auto_recover_to_idle: bool = true

func bind(p_actor_key: String, meta_path: String, p_target: TextureRect) -> bool:
	actor_key = p_actor_key
	target = p_target
	meta = ActorAnimationMeta.load_from_path(meta_path)
	if meta == null or not meta.is_valid:
		is_ready = false
		var message := "failed to load actor meta: %s" % meta_path
		if meta != null and meta.error_message != "":
			message = meta.error_message
		emit_signal("runtime_failed", actor_key, message)
		return false
	BattleActorRenderHelper.apply_actor_meta_bounds(target, meta.frame_size, meta.foot_anchor, meta.actor_scale, meta.default_facing)
	player.bind(meta, target)
	_connect_player_signals()
	is_ready = true
	emit_signal("runtime_ready", actor_key, meta.role_id)
	play_idle(true)
	return true

func update(delta: float) -> void:
	if not is_ready:
		return
	player.update(delta)

func play(animation_name: String, restart: bool = true) -> void:
	if not is_ready or meta == null:
		return
	if not meta.has_animation(animation_name):
		return
	player.play(animation_name, restart)

func play_idle(restart: bool = false) -> void:
	if not is_ready or meta == null:
		return
	var idle_name: String = meta.preferred_idle()
	if idle_name == "":
		return
	player.play(idle_name, restart)

func play_event(event_name: String, restart: bool = true) -> void:
	var animation_name: String = animation_for_event(event_name)
	if animation_name == "":
		return
	play(animation_name, restart)

func animation_for_event(event_name: String) -> String:
	if meta == null:
		return ""
	match event_name:
		"idle", "round_start", "turn_start":
			return "idle" if meta.has_animation("idle") else meta.first_animation_name()
		"move_forward", "advance":
			return "move_forward" if meta.has_animation("move_forward") else meta.preferred_idle()
		"move_back", "retreat":
			return "move_back" if meta.has_animation("move_back") else meta.preferred_idle()
		"attack_heavy", "finisher":
			if meta.has_animation("attack_heavy"):
				return "attack_heavy"
			return "attack_light" if meta.has_animation("attack_light") else meta.preferred_idle()
		"attack", "attack_light":
			return "attack_light" if meta.has_animation("attack_light") else meta.preferred_idle()
		"guard", "block":
			return "guard" if meta.has_animation("guard") else meta.preferred_idle()
		"hit", "damaged":
			return "hit" if meta.has_animation("hit") else meta.preferred_idle()
		"break", "broken":
			return "break" if meta.has_animation("break") else ("hit" if meta.has_animation("hit") else meta.preferred_idle())
		"focus", "momentum":
			return "focus" if meta.has_animation("focus") else meta.preferred_idle()
		"victory":
			return "victory" if meta.has_animation("victory") else meta.preferred_idle()
		"defeat":
			return "defeat" if meta.has_animation("defeat") else meta.preferred_idle()
		_:
			return event_name if meta.has_animation(event_name) else ""

func has_animation(animation_name: String) -> bool:
	return meta != null and meta.has_animation(animation_name)

func current_animation() -> String:
	return player.current_animation

func current_frame() -> int:
	return player.current_frame

func _connect_player_signals() -> void:
	if not player.hit_frame_reached.is_connected(_on_player_hit_frame_reached):
		player.hit_frame_reached.connect(_on_player_hit_frame_reached)
	if not player.animation_finished.is_connected(_on_player_animation_finished):
		player.animation_finished.connect(_on_player_animation_finished)

func _on_player_hit_frame_reached(animation_name: String, frame_index: int) -> void:
	var fx_id: String = meta.animation_fx(animation_name) if meta != null else ""
	var impact_offset: Vector2 = meta.animation_impact_offset(animation_name) if meta != null else Vector2.ZERO
	emit_signal("hit_frame_reached", actor_key, animation_name, frame_index, fx_id, impact_offset)

func _on_player_animation_finished(animation_name: String) -> void:
	emit_signal("animation_finished", actor_key, animation_name)
	if not auto_recover_to_idle or meta == null:
		return
	var recovery_to: String = meta.animation_recovery_to(animation_name)
	if recovery_to != "" and recovery_to != animation_name and meta.has_animation(recovery_to):
		player.play(recovery_to, true)
	elif animation_name != meta.preferred_idle():
		play_idle(true)
