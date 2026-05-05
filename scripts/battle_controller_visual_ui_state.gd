extends "res://scripts/battle_controller_demo_visual.gd"

# Dedicated visual battle controller entry.
# This keeps the current demo presentation path explicit and separate
# from the pure text debugging entry, while delegating reusable concerns
# to helper scripts under scripts/visual/.

const BattleSkinHelper = preload("res://scripts/visual/battle_skin.gd")
const BattleStageHelper = preload("res://scripts/visual/battle_stage_view.gd")
const BattleHudHelper = preload("res://scripts/visual/battle_hud_view.gd")
const BattleFxPool = preload("res://scripts/visual/battle_fx_pool.gd")
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

var foot_alignment_debug_enabled := false
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
var _foot_debug_ground_line: Line2D
var _player_foot_debug_cross: Line2D
var _enemy_foot_debug_cross: Line2D
var _player_momentum_dot_value := -1
var _enemy_momentum_dot_value := -1
var _momentum_dot_animation_serial := 0

func _show_role_selection() -> void:
	_show_overlay(
		"选择角色",
		"[b]这版原型只做枪手与刀客。[/b]\n\n当前规则：当一方的势在本回合被削到 0 时，其将在下一回合崩势：无法行动，且受击伤害翻倍。打崩对手的一方，会在该回合获得一次连招窗口；若其打出的下一招接上已解锁的职业连招起手，则会自动连段。",
		[
			{"text": "枪手开局", "callback": Callable(self, "_start_session").bind("spearman")},
			{"text": "刀客开局", "callback": Callable(self, "_start_session").bind("blademaster")},
			{"text": "Debug 设置", "callback": Callable(self, "_show_debug_settings")}
		]
	)
	_refresh_ui()

func _show_debug_settings() -> void:
	var foot_state := "开" if foot_alignment_debug_enabled else "关"
	_show_overlay(
		"Debug 设置",
		"[b]调试辅助开关[/b]\n\n脚点辅助定位线：%s\n开启后显示黄色格子中心线，以及我方/敌方脚点十字，用于校验角色脚点是否对齐格子中心。默认关闭。" % foot_state,
		[
			{"text": "脚点辅助定位线：%s" % foot_state, "callback": Callable(self, "_toggle_foot_alignment_debug")},
			{"text": "返回", "callback": Callable(self, "_show_role_selection")}
		]
	)

func _toggle_foot_alignment_debug() -> void:
	foot_alignment_debug_enabled = not foot_alignment_debug_enabled
	_stage_grid_signature = ""
	_stage_actor_signature = ""
	_set_actor_foot_highlights_visible(player != null and enemy != null and battle_active)
	if player != null and enemy != null:
		_refresh_stage_actor_positions(true)
		_refresh_stage_grid(true)
	_show_debug_settings()
