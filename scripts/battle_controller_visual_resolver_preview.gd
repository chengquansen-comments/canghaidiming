extends "res://scripts/battle_controller_visual_hot_tuning.gd"

# Preview routing layer: keep all UI/debug/hot tuning behavior, but make the
# ghost preview use the shared CombatResolver instead of local preview rules.
# v0.3.4: ghost labels are hidden; ghosts only indicate expected displacement.

const CombatResolver = preload("res://scripts/combat_resolver.gd")
const PREVIEW_GHOST_ALPHA := 0.30
const PREVIEW_GHOST_OVERLAP_ALPHA := 0.00


func _refresh_preview_ghosts() -> void:
	_ensure_preview_ghosts()
	if player_preview_ghost == null or enemy_preview_ghost == null or player_preview_label == null or enemy_preview_label == null:
		return
	if player == null or enemy == null or not battle_active:
		_set_preview_ghosts_visible(false)
		return
	var preview: Dictionary = _compute_ordered_preview()
	if not bool(preview.get("has_preview", false)):
		_set_preview_ghosts_visible(false)
		return
	var player_final: int = int(preview.get("player_final", player.position))
	var enemy_final: int = int(preview.get("enemy_final", enemy.position))
	player_preview_ghost.texture = player_sprite.texture if player_sprite != null else null
	enemy_preview_ghost.texture = enemy_sprite.texture if enemy_sprite != null else null
	player_preview_ghost.position = _slot_top_left(player_final, true)
	enemy_preview_ghost.position = _slot_top_left(enemy_final, false)
	player_preview_ghost.modulate = _preview_ghost_modulate(true, player_final == player.position)
	enemy_preview_ghost.modulate = _preview_ghost_modulate(false, enemy_final == enemy.position)
	player_preview_label.text = ""
	enemy_preview_label.text = ""
	player_preview_label.visible = false
	enemy_preview_label.visible = false
	_set_preview_ghosts_visible(true)


func _preview_ghost_modulate(is_player: bool, overlaps_real_actor: bool) -> Color:
	var alpha: float = PREVIEW_GHOST_OVERLAP_ALPHA if overlaps_real_actor else PREVIEW_GHOST_ALPHA
	if overlaps_real_actor:
		return Color(1.0, 1.0, 1.0, alpha)
	return Color(0.55, 0.78, 1.0, alpha) if is_player else Color(1.0, 0.64, 0.48, alpha)


func _compute_ordered_preview() -> Dictionary:
	var p_intent: IntentData = draft_player_intent if draft_player_intent != null else player_intent
	var e_intent: IntentData = enemy_intent
	var p_card: CardData = p_intent.actual_card if p_intent != null else null
	var e_card: CardData = e_intent.actual_card if e_intent != null else null
	var has_preview: bool = draft_player_has_position or p_card != null or e_card != null
	if not has_preview:
		return {"has_preview": false}

	var p_state: Dictionary = _resolver_preview_state(true, p_intent)
	var e_state: Dictionary = _resolver_preview_state(false, e_intent)
	var order: Array[String] = _preview_resolution_order(p_intent, e_intent)
	var sim: Dictionary = CombatResolver.resolve_exchange(p_state, e_state, p_card, e_card, order)
	return {
		"has_preview": true,
		"player_final": clampi(int(sim.get("player_final", p_state.get("position", 0))), 0, GRID_SLOT_COUNT - 1),
		"enemy_final": clampi(int(sim.get("enemy_final", e_state.get("position", 0))), 0, GRID_SLOT_COUNT - 1),
		"player_text": "",
		"enemy_text": "",
		"source": "CombatResolver"
	}


func _resolver_preview_state(is_player: bool, intent: IntentData) -> Dictionary:
	var fighter: Fighter = player if is_player else enemy
	if fighter == null:
		return {"hp": 0, "momentum": 0, "guard": 0, "position": 0, "facing": "right", "broken": false}
	var pos: int = fighter.position
	var facing: String = fighter.facing
	if is_player:
		pos = _player_preview_position()
		facing = _player_preview_facing()
	else:
		if intent != null and intent.target_position >= 0:
			pos = intent.target_position
		facing = _enemy_preview_facing()
	return {
		"hp": fighter.hp,
		"momentum": fighter.momentum,
		"guard": fighter.guard_points,
		"position": pos,
		"facing": facing,
		"broken": fighter.is_broken()
	}
