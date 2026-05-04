extends "res://scripts/battle_controller_visual_ui_feedback.gd"

func _ready() -> void:
	super()
	_fx_pool.set_parent(center_fx_layer if center_fx_layer != null else self)
	_mark_web_smoke_battle_state("visual-ready")
	if WebRuntimeFlags.has_query_flag(WEB_SMOKE_BATTLE_FLAG):
		call_deferred("_bootstrap_web_smoke_battle")

func _bootstrap_web_smoke_battle() -> void:
	if player == null:
		_mark_web_smoke_battle_state("session-starting")
		_start_session("spearman")
	if not battle_active:
		_mark_web_smoke_battle_state("battle-starting")
		_start_battle()
	_mark_web_smoke_battle_state("battle-ready")

func _mark_web_smoke_battle_state(state: String) -> void:
	WebRuntimeFlags.set_body_dataset("webSmokeBattle", state)

func _build_catalog() -> void:
	BattleHudHelper.clear_text_cache()
	super()

func _refresh_ui() -> void:
	super()
	_refresh_visual_ui()

func _start_session(role_id: String) -> void:
	BattleHudHelper.clear_text_cache()
	super(role_id)

func _start_battle() -> void:
	_reset_battle_result_visual_state()
	super._start_battle()
	_hud_signature = ""
	_refresh_hud_bars(true)

func _finish_battle() -> void:
	BattleHudHelper.clear_text_cache()
	super()

func _refresh_visual_ui() -> void:
	var has_session := player != null and enemy != null
	_set_battle_chrome_visible(has_session)
	_set_action_buttons_visible(has_session and battle_active)
	if not has_session:
		BattleHudHelper.clear_text_cache()
		_stage_grid_signature = ""
		_stage_actor_signature = ""
		_hud_signature = ""
		_player_intent_bubble_signature = ""
		_enemy_intent_bubble_signature = ""
		_hand_buttons_signature = ""
		_node_buttons_signature = ""
		_clear_range_trapezoids()
		_set_actor_foot_highlights_visible(false)
		_apply_button_styles()
		return
	_refresh_character_visuals()
	_refresh_hud_bars(true)
	_refresh_center_labels()
	_refresh_stage_actor_positions(true)
	_refresh_stage_grid(true)
	_refresh_intent_bubbles(true)
	_refresh_card_detail_panel()
	_refresh_effect_preview_panel()
	_refresh_log_strip()
	_refresh_hand_buttons()
	_apply_button_styles()

func _process(delta: float) -> void:
	preview_anim_time += delta
	if not battle_active:
		return
	_visual_poll_refresh_elapsed += delta
	if _visual_poll_refresh_elapsed < VISUAL_POLL_REFRESH_INTERVAL:
		return
	_visual_poll_refresh_elapsed = 0.0
	_refresh_hud_bars()
	_refresh_stage_actor_positions()
	_refresh_stage_grid()
	_refresh_intent_bubbles()

func _invalidate_stage_preview() -> void:
	_stage_grid_signature = ""
	_stage_actor_signature = ""
	_player_intent_bubble_signature = ""
	_enemy_intent_bubble_signature = ""
