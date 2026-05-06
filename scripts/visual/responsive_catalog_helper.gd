extends RefCounted

var c

func _init(controller) -> void:
	c = controller

func build_catalog() -> void:
	# v0.3.2/0.3.3 runtime card catalog. Kept as a helper so the responsive
	# controller can stay focused on layout/preview orchestration.
	c.fighter_catalog.clear()
	c.reward_pool.clear()
	c.combo_registry.clear()

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

	c.fighter_catalog["spearman"] = FighterData.new("spearman", "枪手", "长枪", 24, 6, 5, 2, PackedInt32Array([2, 3]), spear_deck, 1, 2, "right")
	c.fighter_catalog["blademaster"] = FighterData.new("blademaster", "刀客", "单刀", 22, 6, 5, 2, PackedInt32Array([1, 2]), blade_deck, 1, 6, "left")
	c.fighter_catalog["master_veteran"] = FighterData.new("master_veteran", "沉默老兵", "旧腰刀", 48, 12, 9, 4, PackedInt32Array([0, 1, 2]), veteran_deck, 3, 2, "right")

	var rewards: Array[CardData] = [
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
	c.reward_pool.append_array(rewards)

	c.combo_registry["spearman"] = []
	c.combo_registry["blademaster"] = []
	c.combo_registry["master_veteran"] = []

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
