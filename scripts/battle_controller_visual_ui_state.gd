extends "res://scripts/battle_controller_demo_visual.gd"

# Dedicated visual battle controller entry.
# This keeps the current demo presentation path explicit and separate
# from the pure text debugging entry, while delegating reusable concerns
# to helper scripts under scripts/visual/.

const BattleSkinHelper = preload("res://scripts/visual/battle_skin.gd")
const BattleStageHelper = preload("res://scripts/visual/battle_stage_view.gd")
const BattleHudHelper = preload("res://scripts/visual/battle_hud_view.gd")
const BattleFxPool = preload("res://scripts/visual/battle_fx_pool.gd")
const BattleActorFootHelper = preload("res://scripts/visual/battle_actor_view.gd")
const WebRuntimeFlags = preload("res://scripts/web_runtime_flags.gd")
const WEB_SMOKE_BATTLE_FLAG := "smoke_battle"
const VISUAL_POLL_REFRESH_INTERVAL := 0.12
const BUTTON_STYLE_META := &"visual_button_style_applied"
const MOMENTUM_DOT_ANIMATING_META := &"momentum_dot_animation_busy"
const ENEMY_PORTRAIT_OVERRIDES := {
	"enemy_blademaster_prologue_raider": "portrait_enemy_prologue_raider",
	"enemy_spearman_beach_ambush": "portrait_enemy_spearman_beach_ambush",
	"enemy_wakou_raider_fishing_village": "portrait_enemy_wakou_raider_fishing_village",
	"enemy_blademaster_transport_officer": "transport_officer",
	"enemy_mutiny_camp_leader": "portrait_mutiny_camp_leader",
	"enemy_blademaster_wakou_leader": "wakou_boss_bust",
}

var _visual_poll_refresh_elapsed := 0.0
var _fx_pool := BattleFxPool.new()
var _stage_grid_signature := ""
var _stage_actor_signature := ""
var _hud_signature := ""
var _player_intent_bubble_signature := ""
var _enemy_intent_bubble_signature := ""
var _range_trapezoid_pool: Array[Dictionary] = []
var _hand_buttons_signature := ""
var _node_buttons_signature := ""
var _overlay_action_buttons: Array = []
var _player_foot_grid_highlight: PanelContainer
var _enemy_foot_grid_highlight: PanelContainer
var _player_momentum_dot_value := -1
var _enemy_momentum_dot_value := -1
var _momentum_dot_animation_serial := 0
