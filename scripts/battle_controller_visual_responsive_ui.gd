extends "res://scripts/battle_controller_visual_cached_ui.gd"

# v0.3.3 top-level controller patch:
# - Restores this file as a complete, compile-safe override layer.
# - Keeps committed actor sprites on their real battle positions.
# - Uses translucent ghosts to preview final positions after ordered resolution.
# - Preview order follows BattleStateMachine.get_resolution_order when both intents exist.

const RESPONSIVE_BOTTOM_TOP := 560.0
const RESPONSIVE_BOTTOM_MARGIN := 12.0
const RESPONSIVE_BOTTOM_SEPARATION := 8
const RESPONSIVE_CONTROL_BAR_HEIGHT := 40.0
const RESPONSIVE_HAND_HEIGHT := 176.0
const RESPONSIVE_CARD_SIZE := Vector2(152, 168)
const RESPONSIVE_DETAIL_PANEL_HEIGHT := 132.0
const RESPONSIVE_DETAIL_LABEL_HEIGHT := 94.0
const BUBBLE_GAP_Y := 12.0
const BUBBLE_SAFE_MARGIN_X := 24.0

var _last_resolved_position_signature := ""
var player_preview_ghost: TextureRect
var enemy_preview_ghost: TextureRect
var player_preview_label: Label
var enemy_preview_label: Label


func _process(delta: float) -> void:
	super(delta)
	_refresh_positions_immediately_after_movement()
	_refresh_preview_ghosts()
	_bind_intent_bubbles_to_actor_sprites()


func _build_catalog() -> void:
	# v0.3.2/0.3.3 runtime card catalog. Kept here as a safe override so the large
	# core controller does not need to be rewritten while movement tuning is volatile.
	fighter_catalog.clear()
	reward_pool.clear()
	combo_registry.clear()

	var spear_guard_basic := _ready_v032_card("spear_guard_basic", "回圆架", "回枪成圆，以守化险。", 0, 8, 1, CardData.ROLE_GUARD, 0, 0, 0, 4, PackedStringArray(), "枪", false, 0, 0, 0, CardData.MOVE_NONE, 1)
	var spear_wall_basic := _ready_v032_card("spear_wall_basic", "封门守", "稳固门户，重守待机。", 0, 8, 2, CardData.ROLE_GUARD, 0, 0, 0, 6, PackedStringArray(), "枪", false, 0, 0, 0, CardData.MOVE_NONE, 1)
	var spear_read_basic := _ready_v032_card("spear_read_basic", "拧枪定势", "先稳住枪势，再谋下一承式。", 0, 8, 1, CardData.ROLE_FEINT, 2, 0, 0, 0, PackedStringArray(), "枪", false, 0, 0, 0, CardData.MOVE_NONE, 1)
	var spear_probe_basic := _ready_v032_card("spear_probe_basic", "平枪试探", "平枪轻探，试出中距离节奏。", 2, 3, 1, CardData.ROLE_ATTACK, 0, 0, 3, 0, PackedStringArray(), "枪", true, 0, 0, 0, CardData.MOVE_NONE, 1)
	var spear_press_basic := _ready_v032_card("spear_press_basic", "压杆试破", "枪杆压路，专试对手守势。", 2, 3, 1, CardData.ROLE_ATTACK, 0, 1, 0, 0, PackedStringArray(), "枪", true, 0, 0, 0, CardData.MOVE_NONE, 1)

	var spear_read := _ready_v032_card("spear_read", "拧枪探势", "第二承式，稳枪探势。", 0, 8, 1, CardData.ROLE_FEINT, 2, 0, 0, 0, PackedStringArray(), "枪", false, 0, 0, 0, CardData.MOVE_NONE, 2)
	var spear_shift := _ready_v032_card("spear_shift", "退步量距", "退半步量距，重定下一口气。", 0, 8, 1, CardData.ROLE_FEINT, 0, 0, 0, 0, PackedStringArray(["调距"]), "枪", false, -1, 0, 0, CardData.MOVE_ALWAYS, 2)
	var spear_break := _ready_v032_card("spear_break", "压杆破势", "枪杆压住来路，专削远处敌势。", 2, 3, 1, CardData.ROLE_ATTACK, 0, 2, 0, 0, PackedStringArray(), "枪", true, 0, 0, 0, CardData.MOVE_NONE, 2)
	var spear_guard_advance := _ready_v032_card("spear_guard_advance", "进步架枪", "守中带进，顶住来势。", 0, 8, 1, CardData.ROLE_GUARD, 0, 0, 0, 4, PackedStringArray(), "枪", false, 1, 0, 0, CardData.MOVE_ALWAYS, 2)
	var spear_mid := _ready_v032_card("spear_mid", "中平长刺", "标准中平长刺。", 2, 3, 1, CardData.ROLE_ATTACK, 0, 0, 4, 0, PackedStringArray(), "枪", true, 0, 0, 0, CardData.MOVE_NONE, 3)
	var spear_round_guard := _ready_v032_card("spear_round_guard", "回圆合势", "守中合势，稳住中线。", 0, 8, 2, CardData.ROLE_GUARD, 0, 0, 0, 5, PackedStringArray(), "枪", false, 0, 0, 0, CardData.MOVE_NONE, 3)
	var spear_focus_step := _ready_v032_card("spear_focus_step", "定步换势", "定步调气，换得下一式余裕。", 0, 8, 1, CardData.ROLE_FEINT, 2, 0, 0, 0, PackedStringArray(["调距"]), "枪", false, -1, 0, 0, CardData.MOVE_ALWAYS, 3)
	var spear_senki := _ready_v032_card("spear_senki", "回身截枪", "借回身争先，承接更高收式。", 1, 3, 2, CardData.ROLE_FEINT, 2, 1, 0, 0, PackedStringArray(["先机", "回身", "兼容"]), "枪", false, 0, 0, 0, CardData.MOVE_NONE, 3)
	var spear_heavy := _ready_v032_card("spear_heavy", "龙脊贯刺", "高阶贯刺，一口气压到底。", 3, 4, 2, CardData.ROLE_ATTACK, 0, 0, 8, 0, PackedStringArray(["终式", "兼容"]), "枪", true, 0, 0, 0, CardData.MOVE_NONE, 4)

	var blade_guard_basic := _ready_v032_card("blade_guard_basic", "藏锋格", "低身藏锋，以格挡化险。", 0, 8, 1, CardData.ROLE_GUARD, 0, 0, 0, 4, PackedStringArray(), "刀", false, 0, 0, 0, CardData.MOVE_NONE, 1)
	var blade_evade_basic := _ready_v032_card("blade_evade_basic", "低身避锋", "守身闪锋，微退避其来路。", 0, 8, 1, CardData.ROLE_GUARD, 0, 0, 0, 2, PackedStringArray(), "刀", false, -1, 0, 0, CardData.MOVE_ALWAYS, 1)
	var blade_probe_basic := _ready_v032_card("blade_probe_basic", "贴步试探", "贴步试探，先试近身气口。", 0, 2, 1, CardData.ROLE_FEINT, 2, 0, 0, 0, PackedStringArray(), "刀", false, 0, 0, 0, CardData.MOVE_NONE, 1)
	var blade_cut_basic := _ready_v032_card("blade_cut_basic", "短斩", "短促一斩，打清近身节奏。", 1, 2, 1, CardData.ROLE_ATTACK, 0, 0, 3, 0, PackedStringArray(), "刀", true, 0, 0, 0, CardData.MOVE_NONE, 1)
	var blade_press_basic := _ready_v032_card("blade_press_basic", "逼身试断", "逼身短压，试断对手势口。", 1, 1, 1, CardData.ROLE_ATTACK, 0, 1, 0, 0, PackedStringArray(), "刀", true, 0, 0, 0, CardData.MOVE_NONE, 1)

	var blade_probe := _ready_v032_card("blade_probe", "贴步探刀", "进身探刀，承住下一口短兵节奏。", 0, 2, 1, CardData.ROLE_FEINT, 2, 0, 0, 0, PackedStringArray(), "刀", false, 1, 0, 0, CardData.MOVE_ALWAYS, 2)
	var blade_shift := _ready_v032_card("blade_shift", "斜身换步", "斜身调距，换出再进的口子。", 0, 8, 1, CardData.ROLE_FEINT, 1, 0, 0, 0, PackedStringArray(["调距"]), "刀", false, -1, 0, 0, CardData.MOVE_ALWAYS, 2)
	var blade_press := _ready_v032_card("blade_press", "逼身断势", "贴身压架，专破近处敌势。", 1, 1, 1, CardData.ROLE_ATTACK, 0, 2, 0, 0, PackedStringArray(), "刀", true, 0, 0, 0, CardData.MOVE_NONE, 2)
	var blade_guard_advance := _ready_v032_card("blade_guard_advance", "藏锋进步", "守里进步，逼近下一口刀势。", 0, 8, 1, CardData.ROLE_GUARD, 0, 0, 0, 4, PackedStringArray(), "刀", false, 1, 0, 0, CardData.MOVE_ALWAYS, 2)
	var blade_cut := _ready_v032_card("blade_cut", "贴身快斩", "贴身快斩，利落收口。", 1, 2, 1, CardData.ROLE_ATTACK, 0, 0, 4, 0, PackedStringArray(), "刀", true, 0, 0, 0, CardData.MOVE_NONE, 3)
	var blade_lock_guard := _ready_v032_card("blade_lock_guard", "锁门架", "封门稳守，不给对手穿门。", 0, 8, 2, CardData.ROLE_GUARD, 0, 0, 0, 5, PackedStringArray(), "刀", false, 0, 0, 0, CardData.MOVE_NONE, 3)
	var blade_shift_follow := _ready_v032_card("blade_shift_follow", "连步换身", "连步换身，回到短兵最顺的一线。", 0, 8, 1, CardData.ROLE_FEINT, 2, 0, 0, 0, PackedStringArray(["调距"]), "刀", false, 1, 0, 0, CardData.MOVE_ALWAYS, 3)
	var blade_senki := _ready_v032_card("blade_senki", "回身燕返", "借回身争先，为下一刀制造空门。", 0, 2, 2, CardData.ROLE_FEINT, 2, 1, 0, 0, PackedStringArray(["先机", "回身", "兼容"]), "刀", false, 0, 0, 0, CardData.MOVE_NONE, 3)
	var blade_heavy := _ready_v032_card("blade_heavy", "断流重斩", "高阶重斩，势沉而狠。", 0, 1, 2, CardData.ROLE_ATTACK, 0, 0, 8, 0, PackedStringArray(["终式", "兼容"]), "刀", true, 0, 0, 0, CardData.MOVE_NONE, 4)

	var spear_guard := _ready_v032_card("spear_guard", "回圆架", "基础守式兼容卡。", 0, 8, 1, CardData.ROLE_GUARD, 0, 0, 0, 4, PackedStringArray(["兼容"]), "枪", false, 0, 0, 0, CardData.MOVE_NONE, 1)
	var spear_wall := _ready_v032_card("spear_wall", "封门守", "重守兼容卡。", 0, 8, 2, CardData.ROLE_GUARD, 0, 0, 0, 6, PackedStringArray(["兼容"]), "枪", false, 0, 0, 0, CardData.MOVE_NONE, 1)
	var blade_guard := _ready_v032_card("blade_guard", "藏锋格", "基础守式兼容卡。", 0, 8, 1, CardData.ROLE_GUARD, 0, 0, 0, 4, PackedStringArray(["兼容"]), "刀", false, 0, 0, 0, CardData.MOVE_NONE, 1)
	var blade_wall := _ready_v032_card("blade_wall", "锁门架", "稳守兼容卡。", 0, 8, 2, CardData.ROLE_GUARD, 0, 0, 0, 5, PackedStringArray(["兼容"]), "刀", false, 0, 0, 0, CardData.MOVE_NONE, 3)

	var spear_mid_thrust := _ready_v032_card("spear_mid_thrust", "中平直刺", "剧情旧表兼容：基础枪刺。", 2, 3, 1, CardData.ROLE_ATTACK, 0, 0, 3, 0, PackedStringArray(["兼容"]), "枪", true, 0, 0, 0, CardData.MOVE_NONE, 1)
	var spear_line_press := _ready_v032_card("spear_line_press", "拦枪压线", "剧情旧表兼容：压线控距。", 2, 3, 1, CardData.ROLE_ATTACK, 0, 1, 0, 0, PackedStringArray(["兼容"]), "枪", true, 0, 1, 0, CardData.MOVE_ON_HIT, 1)
	var spear_retreat_sting := _ready_v032_card("spear_retreat_sting", "退枪留锋", "剧情旧表兼容：命中后后撤。", 1, 2, 1, CardData.ROLE_ATTACK, 0, 1, 3, 0, PackedStringArray(["兼容"]), "枪", true, -1, 0, 0, CardData.MOVE_ON_HIT, 2)
	var spear_guard_horse := _ready_v032_card("spear_guard_horse", "架枪拒马", "剧情旧表兼容：稳守拒止。", 0, 8, 1, CardData.ROLE_GUARD, 0, 0, 0, 4, PackedStringArray(["兼容"]), "枪", false, 0, 1, 0, CardData.MOVE_ALWAYS, 1)
	var spear_step_thrust := _ready_v032_card("spear_step_thrust", "顺步送枪", "剧情旧表兼容：进身追刺。", 2, 3, 1, CardData.ROLE_ATTACK, 0, 0, 4, 0, PackedStringArray(["兼容"]), "枪", true, 1, 0, 0, CardData.MOVE_ON_HIT, 3)
	var spear_focus := _ready_v032_card("spear_focus", "稳架蓄枪", "剧情旧表兼容：聚势换位。", 0, 8, 0, CardData.ROLE_FEINT, 2, 0, 0, 0, PackedStringArray(["兼容"]), "枪", false, -1, 0, 0, CardData.MOVE_ALWAYS, 1)

	var blade_front_cut := _ready_v032_card("blade_front_cut", "迎门斩", "剧情旧表兼容：基础近斩。", 1, 2, 1, CardData.ROLE_ATTACK, 0, 0, 3, 0, PackedStringArray(["兼容"]), "刀", true, 0, 0, 0, CardData.MOVE_NONE, 1)
	var blade_press_break := _ready_v032_card("blade_press_break", "压刀破架", "剧情旧表兼容：贴身破势。", 1, 1, 1, CardData.ROLE_ATTACK, 0, 2, 0, 0, PackedStringArray(["兼容"]), "刀", true, 0, 0, 1, CardData.MOVE_ON_HIT, 2)
	var blade_chase_cut := _ready_v032_card("blade_chase_cut", "赶步追斩", "剧情旧表兼容：追身快斩。", 1, 2, 1, CardData.ROLE_ATTACK, 0, 0, 4, 0, PackedStringArray(["兼容"]), "刀", true, 1, 0, 0, CardData.MOVE_ON_HIT, 3)
	var blade_hook_pull := _ready_v032_card("blade_hook_pull", "挂刀带步", "剧情旧表兼容：拉回近身。", 1, 2, 1, CardData.ROLE_ATTACK, 0, 1, 3, 0, PackedStringArray(["兼容"]), "刀", true, 0, 0, 1, CardData.MOVE_ON_HIT, 3)
	var blade_body_press := _ready_v032_card("blade_body_press", "贴身撞刀", "剧情旧表兼容：逼身撞压。", 0, 1, 1, CardData.ROLE_ATTACK, 0, 2, 3, 0, PackedStringArray(["兼容"]), "刀", true, 1, 0, 0, CardData.MOVE_ON_HIT, 3)
	var blade_breathe := _ready_v032_card("blade_breathe", "收刀换气", "剧情旧表兼容：短兵调息。", 0, 8, 0, CardData.ROLE_FEINT, 2, 0, 0, 0, PackedStringArray(["兼容"]), "刀", false, 1, 0, 0, CardData.MOVE_ALWAYS, 1)

	var spear_deck: Array[CardData] = [
		spear_guard_basic,
		spear_guard_basic.duplicate_card(),
		spear_wall_basic,
		spear_read_basic,
		spear_read_basic.duplicate_card(),
		spear_probe_basic,
		spear_probe_basic.duplicate_card(),
		spear_press_basic
	]
	var blade_deck: Array[CardData] = [
		blade_guard_basic,
		blade_guard_basic.duplicate_card(),
		blade_evade_basic,
		blade_probe_basic,
		blade_probe_basic.duplicate_card(),
		blade_cut_basic,
		blade_cut_basic.duplicate_card(),
		blade_press_basic
	]
	var veteran_deck: Array[CardData] = [
		blade_guard_advance,
		blade_lock_guard,
		blade_probe,
		blade_probe.duplicate_card(),
		blade_cut,
		blade_cut.duplicate_card(),
		blade_senki,
		blade_heavy
	]

	fighter_catalog["spearman"] = FighterData.new("spearman", "枪手", "长枪", 24, 6, 5, 2, PackedInt32Array([2, 3]), spear_deck, 1, 2, "right")
	fighter_catalog["blademaster"] = FighterData.new("blademaster", "刀客", "单刀", 22, 6, 5, 2, PackedInt32Array([1, 2]), blade_deck, 1, 6, "left")
	fighter_catalog["master_veteran"] = FighterData.new("master_veteran", "沉默老兵", "旧腰刀", 48, 12, 9, 4, PackedInt32Array([0, 1, 2]), veteran_deck, 3, 2, "right")

	reward_pool = [
		spear_read,
		spear_shift,
		spear_break,
		spear_guard_advance,
		spear_mid,
		spear_round_guard,
		spear_focus_step,
		blade_probe,
		blade_shift,
		blade_press,
		blade_guard_advance,
		blade_cut,
		blade_lock_guard,
		blade_shift_follow,
		_ready_v032_card("reward_momentum_up", "聚势", "通用承式，提振自身势头。", 0, 8, 1, CardData.ROLE_FEINT, 2, 0, 0, 0, PackedStringArray(), "通用", false, 0, 0, 0, CardData.MOVE_NONE, 2),
		_ready_v032_card("reward_momentum_break", "断势", "通用压制，专门削弱敌势。", 1, 3, 1, CardData.ROLE_ATTACK, 0, 2, 0, 0, PackedStringArray(), "通用", true, 0, 0, 0, CardData.MOVE_NONE, 2),
		_ready_v032_card("reward_damage", "重手", "高阶收口，专注打血。", 1, 3, 2, CardData.ROLE_ATTACK, 0, 0, 5, 0, PackedStringArray(), "通用", true, 0, 0, 0, CardData.MOVE_NONE, 3),
		_ready_v032_card("reward_guard", "铁壁", "高阶稳守，纯粹追求格挡。", 0, 8, 2, CardData.ROLE_GUARD, 0, 0, 0, 6, PackedStringArray(), "通用", false, 0, 0, 0, CardData.MOVE_NONE, 3),
		_ready_v032_card("reward_senki", "争先", "通用变式，争一个更好的口子。", 0, 8, 2, CardData.ROLE_FEINT, 2, 0, 0, 0, PackedStringArray(["先机"]), "通用", false, 0, 0, 0, CardData.MOVE_NONE, 3),
		_ready_v032_card("reward_push", "压线", "旧奖励兼容：命中后击退敌人一格。", 2, 3, 2, CardData.ROLE_ATTACK, 0, 2, 0, 0, PackedStringArray(["兼容"]), "通用", true, 0, 1, 0, CardData.MOVE_ON_HIT, 4),
		_ready_v032_card("reward_pull", "挂带", "旧奖励兼容：命中后拉近敌人一格。", 1, 2, 2, CardData.ROLE_ATTACK, 0, 1, 0, 0, PackedStringArray(["兼容"]), "通用", true, 0, 0, 1, CardData.MOVE_ON_HIT, 4),
		spear_guard,
		spear_wall,
		spear_senki,
		spear_heavy,
		blade_guard,
		blade_wall,
		blade_senki,
		blade_heavy,
		spear_mid_thrust,
		spear_line_press,
		spear_retreat_sting,
		spear_guard_horse,
		spear_step_thrust,
		spear_focus,
		blade_front_cut,
		blade_press_break,
		blade_chase_cut,
		blade_hook_pull,
		blade_body_press,
		blade_breathe
	]

	combo_registry["spearman"] = []
	combo_registry["blademaster"] = []
	combo_registry["master_veteran"] = []


func _ready_v032_card(
	p_id: String,
	p_name: String,
	p_desc: String,
	p_min_distance: int,
	p_max_distance: int,
	p_cost: int,
	p_role: String,
	p_gain_momentum: int,
	p_break_momentum: int,
	p_damage: int,
	p_guard: int,
	p_tags: PackedStringArray = PackedStringArray(),
	p_weapon_style: String = "",
	p_requires_facing: bool = true,
	p_self_move_after: int = 0,
	p_target_push_after: int = 0,
	p_target_pull_after: int = 0,
	p_move_condition: String = CardData.MOVE_NONE,
	p_shoushi_rank: int = 1
) -> CardData:
	return CardData.new(p_id, p_name, p_desc, p_min_distance, p_max_distance, p_cost, p_role, p_gain_momentum, p_break_momentum, p_damage, p_guard, p_tags, p_weapon_style, p_requires_facing, p_self_move_after, p_target_push_after, p_target_pull_after, p_move_condition, p_shoushi_rank)


func _build_ui() -> void:
	super()
	_ensure_preview_ghosts()
	_configure_responsive_bottom_layout()
	call_deferred("_configure_responsive_bottom_layout")
	call_deferred("_bind_intent_bubbles_to_actor_sprites")


func _refresh_visual_ui() -> void:
	super()
	_force_real_actor_positions()
	_refresh_preview_ghosts()
	_configure_responsive_bottom_layout()
	_stabilize_actor_runtime_textures()
	_bind_intent_bubbles_to_actor_sprites()


func _refresh_stage_actor_positions(force: bool = false) -> void:
	super(force)
	_force_real_actor_positions()
	_refresh_preview_ghosts()
	_stabilize_actor_runtime_textures()
	_bind_intent_bubbles_to_actor_sprites()


func _current_grid_positions() -> Dictionary:
	# Real stage markers should represent committed state only. Future results are
	# represented by ghosts.
	return {
		"player": player.position if player != null else 0,
		"enemy": enemy.position if enemy != null else GRID_RIGHT_ANCHOR_SLOT
	}


func _refresh_hand_buttons() -> void:
	super()
	_configure_responsive_bottom_layout()
	_configure_hand_button_sizes()
	_bind_intent_bubbles_to_actor_sprites()


func _refresh_intent_bubbles(force: bool = false) -> void:
	super(force)
	_bind_intent_bubbles_to_actor_sprites()


func _resolved_position_signature() -> String:
	if player == null or enemy == null:
		return "no-session"
	return "%d|%s|%d|%s|%d" % [player.position, player.facing, enemy.position, enemy.facing, state_machine.current_distance if state_machine != null else -1]


func _refresh_positions_immediately_after_movement() -> void:
	if player == null or enemy == null or not battle_active:
		_last_resolved_position_signature = _resolved_position_signature()
		return
	var signature := _resolved_position_signature()
	if signature == _last_resolved_position_signature:
		return
	_last_resolved_position_signature = signature
	_stage_grid_signature = ""
	_stage_actor_signature = ""
	_player_intent_bubble_signature = ""
	_enemy_intent_bubble_signature = ""
	_refresh_stage_actor_positions(true)
	_refresh_stage_grid(true)
	_refresh_intent_bubbles(true)
	_refresh_effect_preview_panel()


func _ensure_preview_ghosts() -> void:
	if stage_layer == null:
		return
	if player_preview_ghost == null:
		player_preview_ghost = _build_preview_ghost(true)
		stage_layer.add_child(player_preview_ghost)
	if enemy_preview_ghost == null:
		enemy_preview_ghost = _build_preview_ghost(false)
		stage_layer.add_child(enemy_preview_ghost)
	if player_preview_label == null:
		player_preview_label = _build_preview_label(true)
		stage_layer.add_child(player_preview_label)
	if enemy_preview_label == null:
		enemy_preview_label = _build_preview_label(false)
		stage_layer.add_child(enemy_preview_label)


func _build_preview_ghost(is_player: bool) -> TextureRect:
	var ghost := TextureRect.new()
	ghost.visible = false
	ghost.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	ghost.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ghost.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ghost.custom_minimum_size = ACTOR_DISPLAY_SIZE
	ghost.size = ACTOR_DISPLAY_SIZE
	ghost.clip_contents = true
	ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ghost.z_index = 14
	ghost.modulate = Color(0.55, 0.78, 1.0, 0.34) if is_player else Color(1.0, 0.64, 0.48, 0.32)
	return ghost


func _build_preview_label(is_player: bool) -> Label:
	var label := Label.new()
	label.visible = false
	label.z_index = 32
	label.custom_minimum_size = Vector2(260, 54)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.max_lines_visible = 2
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", Color("dff1ff") if is_player else Color("ffe0d0"))
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 2)
	return label


func _force_real_actor_positions() -> void:
	if player != null and player_sprite != null:
		player_sprite.position = _slot_top_left(player.position, true)
		if player_fallback_actor != null:
			player_fallback_actor.position = player_sprite.position
	if enemy != null and enemy_sprite != null:
		enemy_sprite.position = _slot_top_left(enemy.position, false)
		if enemy_fallback_actor != null:
			enemy_fallback_actor.position = enemy_sprite.position


func _refresh_preview_ghosts() -> void:
	_ensure_preview_ghosts()
	if player_preview_ghost == null or enemy_preview_ghost == null or player_preview_label == null or enemy_preview_label == null:
		return
	if player == null or enemy == null or not battle_active:
		_set_preview_ghosts_visible(false)
		return
	var preview := _compute_ordered_preview()
	if not bool(preview.get("has_preview", false)):
		_set_preview_ghosts_visible(false)
		return
	player_preview_ghost.texture = player_sprite.texture if player_sprite != null else null
	enemy_preview_ghost.texture = enemy_sprite.texture if enemy_sprite != null else null
	player_preview_ghost.position = _slot_top_left(preview.get("player_final", player.position), true)
	enemy_preview_ghost.position = _slot_top_left(preview.get("enemy_final", enemy.position), false)
	player_preview_label.text = str(preview.get("player_text", "预期"))
	enemy_preview_label.text = str(preview.get("enemy_text", "预期"))
	player_preview_label.position = player_preview_ghost.position + Vector2(-16, -56)
	enemy_preview_label.position = enemy_preview_ghost.position + Vector2(-16, -56)
	_set_preview_ghosts_visible(true)


func _set_preview_ghosts_visible(value: bool) -> void:
	if player_preview_ghost != null:
		player_preview_ghost.visible = value
	if enemy_preview_ghost != null:
		enemy_preview_ghost.visible = value
	if player_preview_label != null:
		player_preview_label.visible = value
	if enemy_preview_label != null:
		enemy_preview_label.visible = value


func _compute_ordered_preview() -> Dictionary:
	var p_intent: IntentData = draft_player_intent if draft_player_intent != null else player_intent
	var e_intent: IntentData = enemy_intent
	var p_card: CardData = p_intent.actual_card if p_intent != null else null
	var e_card: CardData = e_intent.actual_card if e_intent != null else null
	var has_preview := draft_player_has_position or p_card != null or e_card != null
	if not has_preview:
		return {"has_preview": false}

	var p_pos := _player_preview_position()
	var e_pos := enemy.position
	if e_intent != null and e_intent.target_position >= 0:
		e_pos = e_intent.target_position
	var p_facing := _player_preview_facing()
	var e_facing := _enemy_preview_facing()
	var p_text := "预期：待命"
	var e_text := "预期：待命"

	var order := _preview_resolution_order(p_intent, e_intent)
	for side in order:
		if side == "player" and p_card != null:
			var result := _preview_range_result_at(p_card, p_pos, p_facing, e_pos)
			var outcome := _preview_outcome_text(p_card, player, enemy, result)
			p_text = str(outcome.get("actor", "预期"))
			e_text = str(outcome.get("target", e_text))
			var moved := _apply_preview_movement(p_card, true, p_pos, e_pos, p_facing, result)
			p_pos = moved.get("player", p_pos)
			e_pos = moved.get("enemy", e_pos)
		elif side == "enemy" and e_card != null:
			var result2 := _preview_range_result_at(e_card, e_pos, e_facing, p_pos)
			var outcome2 := _preview_outcome_text(e_card, enemy, player, result2)
			e_text = str(outcome2.get("actor", "预期"))
			p_text = str(outcome2.get("target", p_text))
			var moved2 := _apply_preview_movement(e_card, false, p_pos, e_pos, e_facing, result2)
			p_pos = moved2.get("player", p_pos)
			e_pos = moved2.get("enemy", e_pos)

	return {
		"has_preview": true,
		"player_final": clampi(p_pos, 0, GRID_SLOT_COUNT - 1),
		"enemy_final": clampi(e_pos, 0, GRID_SLOT_COUNT - 1),
		"player_text": p_text,
		"enemy_text": e_text
	}


func _preview_resolution_order(p_intent: IntentData, e_intent: IntentData) -> Array[String]:
	if p_intent != null and e_intent != null and state_machine != null:
		var ordered := state_machine.get_resolution_order(player, enemy, p_intent, e_intent)
		var result: Array[String] = []
		for intent in ordered:
			if intent == p_intent:
				result.append("player")
			elif intent == e_intent:
				result.append("enemy")
		if not result.is_empty():
			return result
	if p_intent != null and e_intent == null:
		return ["player"]
	if p_intent == null and e_intent != null:
		return ["enemy"]
	return ["player", "enemy"]


func _preview_range_result_at(card: CardData, actor_pos: int, actor_facing: String, target_pos: int) -> String:
	return CombatResolver.evaluate_range(card, actor_pos, actor_facing, target_pos)


func _preview_outcome_text(card: CardData, actor: Fighter, target: Fighter, range_result: String) -> Dictionary:
	if card == null:
		return {"actor": "预期：待命", "target": "预期：待命"}
	if actor != null and actor.is_broken():
		return {"actor": "预期：崩势无效 / 伤0", "target": "预期：无伤害"}
	var damage := _preview_damage_for_result(card, target, range_result)
	var break_value := _preview_break_for_result(card, range_result)
	var actor_parts: Array[String] = []
	actor_parts.append(_range_result_text(range_result))
	actor_parts.append("伤%d" % damage)
	if break_value > 0:
		actor_parts.append("势-%d" % break_value)
	var is_effective_hit := range_result == CombatResolver.RANGE_HIT or (CombatResolver.ENABLE_GRAZE and range_result == CombatResolver.RANGE_GRAZE)
	if card.gain_momentum > 0 and is_effective_hit:
		actor_parts.append("势+%d" % card.gain_momentum)
	var target_parts: Array[String] = []
	if damage == 0 and break_value == 0:
		target_parts.append("无伤害")
	else:
		if damage > 0:
			target_parts.append("受伤%d" % damage)
		if break_value > 0:
			target_parts.append("失势%d" % break_value)
		if target != null and target.momentum > 0 and target.momentum - break_value <= 0:
			target_parts.append("预期崩势")
	return {"actor": "预期：%s" % " / ".join(actor_parts), "target": "预期：%s" % " / ".join(target_parts)}


func _apply_preview_movement(card: CardData, is_player_actor: bool, p_pos: int, e_pos: int, actor_facing: String, range_result: String) -> Dictionary:
	var can_move := false
	match card.move_condition:
		CardData.MOVE_ALWAYS:
			can_move = true
		CardData.MOVE_ON_HIT:
			can_move = range_result == CombatResolver.RANGE_HIT
		CardData.MOVE_ON_GRAZE:
			can_move = CombatResolver.ENABLE_GRAZE and range_result == CombatResolver.RANGE_GRAZE
		_:
			can_move = false
	if not can_move:
		return {"player": p_pos, "enemy": e_pos}
	var actor_pos := p_pos if is_player_actor else e_pos
	var target_pos := e_pos if is_player_actor else p_pos
	if card.target_push_after > 0:
		target_pos = _preview_push(actor_pos, target_pos, actor_facing, card.target_push_after)
	elif card.target_pull_after > 0:
		target_pos = _preview_pull(actor_pos, target_pos, actor_facing, card.target_pull_after)
	elif card.self_move_after != 0:
		actor_pos = _preview_self(actor_pos, target_pos, actor_facing, card.self_move_after)
	return {"player": actor_pos if is_player_actor else target_pos, "enemy": target_pos if is_player_actor else actor_pos}


func _preview_dir(actor_pos: int, target_pos: int, facing: String) -> int:
	if target_pos > actor_pos:
		return 1
	if target_pos < actor_pos:
		return -1
	return 1 if facing == "right" else -1


func _preview_self(actor_pos: int, target_pos: int, facing: String, amount: int) -> int:
	var dir := _preview_dir(actor_pos, target_pos, facing)
	return clampi(actor_pos + dir if amount > 0 else actor_pos - dir, 0, GRID_SLOT_COUNT - 1)


func _preview_push(actor_pos: int, target_pos: int, facing: String, amount: int) -> int:
	return clampi(target_pos + _preview_dir(actor_pos, target_pos, facing) * amount, 0, GRID_SLOT_COUNT - 1)


func _preview_pull(actor_pos: int, target_pos: int, facing: String, amount: int) -> int:
	var dir := _preview_dir(actor_pos, target_pos, facing)
	var result := clampi(target_pos - dir * amount, 0, GRID_SLOT_COUNT - 1)
	if dir > 0 and result < actor_pos:
		result = actor_pos
	if dir < 0 and result > actor_pos:
		result = actor_pos
	return result


func _preview_faces_target(actor_position: int, actor_facing: String, target_position: int) -> bool:
	if actor_position == target_position:
		return true
	if target_position > actor_position:
		return actor_facing == "right"
	return actor_facing == "left"


func _preview_break_for_result(card: CardData, range_result: String) -> int:
	if card == null:
		return 0
	if range_result == CombatResolver.RANGE_HIT:
		return card.break_momentum
	if CombatResolver.ENABLE_GRAZE and range_result == CombatResolver.RANGE_GRAZE:
		return maxi(card.break_momentum - 1, 0)
	return 0


func _configure_responsive_bottom_layout() -> void:
	_configure_bottom_root_bounds()
	_configure_control_bar_priority()
	_configure_hand_area_priority()
	_configure_scrollable_detail_panels()
	_configure_hand_button_sizes()


func _configure_bottom_root_bounds() -> void:
	if bottom_backdrop != null:
		bottom_backdrop.anchor_left = 0.0
		bottom_backdrop.anchor_right = 1.0
		bottom_backdrop.anchor_top = 0.0
		bottom_backdrop.anchor_bottom = 1.0
		bottom_backdrop.offset_top = RESPONSIVE_BOTTOM_TOP - 10.0
		bottom_backdrop.offset_bottom = 0.0
	if bottom_root != null:
		bottom_root.offset_left = 20.0
		bottom_root.offset_right = -20.0
		bottom_root.offset_top = RESPONSIVE_BOTTOM_TOP
		bottom_root.offset_bottom = -RESPONSIVE_BOTTOM_MARGIN
		bottom_root.clip_contents = true
		bottom_root.add_theme_constant_override("separation", RESPONSIVE_BOTTOM_SEPARATION)
		bottom_root.size_flags_vertical = Control.SIZE_EXPAND_FILL


func _configure_control_bar_priority() -> void:
	var control_bar := _control_bar_node()
	if control_bar == null:
		return
	control_bar.custom_minimum_size = Vector2(0, RESPONSIVE_CONTROL_BAR_HEIGHT)
	control_bar.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	control_bar.clip_contents = true
	if control_bar is BoxContainer:
		(control_bar as BoxContainer).add_theme_constant_override("separation", 8)


func _configure_hand_area_priority() -> void:
	if hand_flow == null:
		return
	hand_flow.custom_minimum_size = Vector2(0, RESPONSIVE_HAND_HEIGHT)
	hand_flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hand_flow.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	hand_flow.clip_contents = true
	if hand_flow is BoxContainer:
		(hand_flow as BoxContainer).add_theme_constant_override("separation", 8)


func _configure_scrollable_detail_panels() -> void:
	_configure_detail_panel(card_detail_panel, card_detail_label)
	_configure_detail_panel(effect_preview_panel, effect_preview_label)
	_configure_detail_parent(card_detail_panel)
	_configure_detail_parent(effect_preview_panel)


func _configure_detail_panel(panel: PanelContainer, label: RichTextLabel) -> void:
	if panel != null:
		panel.custom_minimum_size = Vector2(0, RESPONSIVE_DETAIL_PANEL_HEIGHT)
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
		panel.clip_contents = true
	if label != null:
		label.fit_content = false
		label.scroll_active = true
		label.scroll_following = false
		label.clip_contents = true
		label.custom_minimum_size = Vector2(0, RESPONSIVE_DETAIL_LABEL_HEIGHT)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.size_flags_vertical = Control.SIZE_EXPAND_FILL


func _configure_detail_parent(panel: PanelContainer) -> void:
	if panel == null:
		return
	var parent := panel.get_parent()
	if parent == null or parent == bottom_root:
		return
	if parent is Control:
		var parent_control := parent as Control
		parent_control.custom_minimum_size = Vector2(0, RESPONSIVE_DETAIL_PANEL_HEIGHT)
		parent_control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		parent_control.size_flags_vertical = Control.SIZE_EXPAND_FILL
		parent_control.clip_contents = true
		if parent_control is BoxContainer:
			(parent_control as BoxContainer).add_theme_constant_override("separation", 8)


func _configure_hand_button_sizes() -> void:
	if hand_flow == null:
		return
	for child in hand_flow.get_children():
		if child is Button:
			var button := child as Button
			button.custom_minimum_size = RESPONSIVE_CARD_SIZE
			button.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
			button.clip_text = true
			button.clip_contents = true
			button.add_theme_font_size_override("font_size", 11)
		elif child is Control:
			var control := child as Control
			control.custom_minimum_size = Vector2(0, RESPONSIVE_HAND_HEIGHT)
			control.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
			control.clip_contents = true


func _stabilize_actor_runtime_textures() -> void:
	_ensure_actor_animation_runtimes()
	_refresh_actor_runtime_visuals()


func _bind_intent_bubbles_to_actor_sprites() -> void:
	_bind_single_intent_bubble(player_intent_bubble, player_sprite, true)
	_bind_single_intent_bubble(enemy_intent_bubble, enemy_sprite, false)


func _bind_single_intent_bubble(bubble: PanelContainer, sprite: TextureRect, is_player_actor: bool) -> void:
	if bubble == null or sprite == null or not bubble.visible:
		return
	var bubble_size: Vector2 = bubble.size
	if bubble_size.x <= 1.0 or bubble_size.y <= 1.0:
		bubble_size = bubble.custom_minimum_size
	var sprite_rect: Rect2 = _sprite_visible_rect(sprite)
	var foot_point := _actor_foot_point(is_player_actor)
	var target_x: float = foot_point.x - bubble_size.x * 0.5
	var target_y: float = sprite_rect.position.y - bubble_size.y - BUBBLE_GAP_Y
	bubble.position = Vector2(clampf(target_x, BUBBLE_SAFE_MARGIN_X, maxf(BUBBLE_SAFE_MARGIN_X, size.x - bubble_size.x - BUBBLE_SAFE_MARGIN_X)), maxf(STAGE_AREA_TOP + 8.0, target_y))


func _sprite_visible_rect(sprite: TextureRect) -> Rect2:
	var rect := Rect2(sprite.position, sprite.size)
	if sprite.texture == null:
		return rect
	var texture_size: Vector2 = sprite.texture.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0 or sprite.size.x <= 0.0 or sprite.size.y <= 0.0:
		return rect
	var draw_scale: float = minf(sprite.size.x / texture_size.x, sprite.size.y / texture_size.y)
	var draw_size: Vector2 = texture_size * draw_scale
	var draw_offset: Vector2 = (sprite.size - draw_size) * 0.5
	return Rect2(sprite.position + draw_offset, draw_size)


func _control_bar_node() -> Control:
	if bottom_root != null:
		var named := bottom_root.get_node_or_null("ControlBar")
		if named is Control:
			return named as Control
	if bottom_root != null and bottom_root.get_child_count() > 0 and bottom_root.get_child(0) is Control:
		return bottom_root.get_child(0) as Control
	return null
