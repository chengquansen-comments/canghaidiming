extends "res://scripts/battle_controller_visual_presentation_stepwise.gd"

# Phase 12.6 guard wrapper.
# Prevent death fade from being undone by later visual UI refreshes.
# This layer does not alter combat resolution, input, movement, or FX logic.

func _set_battle_chrome_visible(visible: bool) -> void:
	super._set_battle_chrome_visible(visible)
	_apply_dead_actor_visibility_guard()

func _refresh_character_visuals() -> void:
	super._refresh_character_visuals()
	_apply_dead_actor_visibility_guard()

func _apply_dead_actor_visibility_guard() -> void:
	if player != null and player.hp <= 0:
		if player_sprite != null:
			player_sprite.visible = false
		if player_fallback_actor != null:
			player_fallback_actor.visible = false
	if enemy != null and enemy.hp <= 0:
		if enemy_sprite != null:
			enemy_sprite.visible = false
		if enemy_fallback_actor != null:
			enemy_fallback_actor.visible = false
