extends RefCounted

const ActorAnimationRuntime := preload("res://scripts/visual/actor_animation_runtime.gd")

# Cached actor animation runtime manager for battle visual controller.
#
# Requires owner:
# - player / enemy
# - player_sprite / enemy_sprite
# - player_fallback_actor / enemy_fallback_actor
# - _actor_meta_path_for(fighter, prefer_enemy_variant)
# - _invalidate_stage_preview()
# - _refresh_stage_actor_positions(force)
# - _on_actor_runtime_ready / failed / hit_frame / animation_finished
# - _show_pierce_line(), _show_slash_cut(), _play_profession_shape_feedback()
# - _show_target_receive_feedback(), _impact_feedback()

var c
var player_runtime: ActorAnimationRuntime = null
var enemy_runtime: ActorAnimationRuntime = null
var player_runtime_meta_path := ""
var enemy_runtime_meta_path := ""
var last_player_animation_card: CardData = null
var last_enemy_animation_card: CardData = null

func _init(controller) -> void:
	c = controller


func update_actor_animation_runtimes(delta: float) -> void:
	if player_runtime != null and player_runtime.is_ready:
		player_runtime.update(delta)
	if enemy_runtime != null and enemy_runtime.is_ready:
		enemy_runtime.update(delta)


func ensure_actor_animation_runtimes() -> void:
	ensure_single_actor_runtime(true)
	ensure_single_actor_runtime(false)


func ensure_single_actor_runtime(is_player_actor: bool) -> void:
	var fighter: Fighter = c.player if is_player_actor else c.enemy
	var sprite: TextureRect = c.player_sprite if is_player_actor else c.enemy_sprite
	if fighter == null or sprite == null:
		clear_actor_runtime(is_player_actor)
		return
	var meta_path: String = c._actor_meta_path_for(fighter, not is_player_actor)
	if meta_path == "":
		clear_actor_runtime(is_player_actor)
		return
	if is_player_actor:
		if player_runtime != null and player_runtime_meta_path == meta_path:
			return
		player_runtime = create_actor_runtime("player", meta_path, sprite)
		player_runtime_meta_path = meta_path if player_runtime != null and player_runtime.is_ready else ""
		c._invalidate_stage_preview()
		c.call_deferred("_refresh_stage_actor_positions", true)
	else:
		if enemy_runtime != null and enemy_runtime_meta_path == meta_path:
			return
		enemy_runtime = create_actor_runtime("enemy", meta_path, sprite)
		enemy_runtime_meta_path = meta_path if enemy_runtime != null and enemy_runtime.is_ready else ""
		c._invalidate_stage_preview()
		c.call_deferred("_refresh_stage_actor_positions", true)


func create_actor_runtime(actor_key: String, meta_path: String, sprite: TextureRect) -> ActorAnimationRuntime:
	var runtime: ActorAnimationRuntime = ActorAnimationRuntime.new()
	runtime.runtime_ready.connect(c._on_actor_runtime_ready)
	runtime.runtime_failed.connect(c._on_actor_runtime_failed)
	runtime.hit_frame_reached.connect(c._on_actor_runtime_hit_frame)
	runtime.animation_finished.connect(c._on_actor_runtime_animation_finished)
	var ok: bool = runtime.bind(actor_key, meta_path, sprite)
	return runtime if ok else null


func clear_actor_runtime(is_player_actor: bool) -> void:
	if is_player_actor:
		player_runtime = null
		player_runtime_meta_path = ""
	else:
		enemy_runtime = null
		enemy_runtime_meta_path = ""


func refresh_actor_runtime_visuals() -> void:
	refresh_single_actor_runtime_visual(player_runtime, c.player_fallback_actor)
	refresh_single_actor_runtime_visual(enemy_runtime, c.enemy_fallback_actor)


func refresh_single_actor_runtime_visual(runtime: ActorAnimationRuntime, fallback: Control) -> void:
	if runtime == null or not runtime.is_ready:
		return
	if fallback != null:
		fallback.visible = false
	if runtime.player != null and runtime.player.playing:
		runtime.player._apply_current_frame()
		return
	runtime.play_idle(false)


func intent_card(intent: IntentData) -> CardData:
	if intent != null and intent.actual_card != null:
		return intent.actual_card
	return null


func play_actor_runtime_for_card(is_player_actor: bool, card: CardData) -> void:
	var runtime: ActorAnimationRuntime = player_runtime if is_player_actor else enemy_runtime
	if runtime == null or not runtime.is_ready:
		return
	var event_name: String = animation_event_for_card(card)
	if event_name == "":
		return
	if is_player_actor:
		last_player_animation_card = card
	else:
		last_enemy_animation_card = card
	runtime.play_event(event_name, true)


func animation_event_for_card(card: CardData) -> String:
	if card == null:
		return "idle"
	if card.is_guard_card():
		return "guard"
	if card.is_feint_card():
		return "focus"
	if card.damage > 0:
		return "attack_heavy" if card_has_tag(card, "终结") else "attack_light"
	if card.break_momentum > 0:
		return "focus"
	return "idle"


func card_has_tag(card: CardData, tag: String) -> bool:
	if card == null:
		return false
	for item in card.tags:
		if str(item) == tag:
			return true
	return false


func play_defender_reaction_for_hit_frame(attacker_key: String) -> void:
	var attacking_card: CardData = last_player_animation_card if attacker_key == "player" else last_enemy_animation_card
	var defender_runtime: ActorAnimationRuntime = enemy_runtime if attacker_key == "player" else player_runtime
	var defender: Fighter = c.enemy if attacker_key == "player" else c.player
	if defender_runtime == null or not defender_runtime.is_ready or attacking_card == null:
		return
	var event_name := "hit"
	if defender != null and defender.is_broken():
		event_name = "break"
	elif attacking_card.break_momentum > 0 and attacking_card.damage <= 0:
		event_name = "break"
	elif attacking_card.guard > 0:
		event_name = "guard"
	defender_runtime.play_event(event_name, true)


func trigger_runtime_fx_feedback(actor_key: String, fx_id: String, impact_offset: Vector2) -> void:
	var attacking_card: CardData = last_player_animation_card if actor_key == "player" else last_enemy_animation_card
	var attacker: Fighter = c.player if actor_key == "player" else c.enemy
	var defender: Fighter = c.enemy if actor_key == "player" else c.player
	if attacker == null or defender == null:
		return
	var profession_id: String = str(attacker.data.id)
	var is_finisher: bool = card_has_tag(attacking_card, "终结")
	var color: Color = runtime_fx_color(fx_id, profession_id, is_finisher)
	if fx_id == "pierce_streak" or profession_id == "spearman":
		c._show_pierce_line(color, is_finisher)
	elif fx_id == "slash_arc" or profession_id == "blademaster":
		c._show_slash_cut(color, is_finisher)
	else:
		c._play_profession_shape_feedback(profession_id, color, is_finisher, false)
	c._show_target_receive_feedback(defender, profession_id, color, is_finisher)
	c._impact_feedback(color, 6.2 if is_finisher else 3.8, profession_id == "spearman", is_finisher)


func runtime_fx_color(fx_id: String, profession_id: String, is_finisher: bool) -> Color:
	if fx_id == "pierce_streak" or profession_id == "spearman":
		return Color("dff4ff") if is_finisher else Color("9fd8ff")
	if fx_id == "slash_arc" or profession_id == "blademaster":
		return Color("ffd1a8") if is_finisher else Color("ff9f73")
	return Color("f5d889") if is_finisher else Color("d9c18a")


func actor_runtime(is_player_actor: bool) -> ActorAnimationRuntime:
	return player_runtime if is_player_actor else enemy_runtime


func actor_runtime_is_ready(is_player_actor: bool) -> bool:
	var runtime := actor_runtime(is_player_actor)
	return runtime != null and runtime.is_ready
