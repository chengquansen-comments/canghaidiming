extends "res://scripts/battle_controller_core_state.gd"

# Split from battle_controller_core.gd; keep behavior-compatible with the original controller.

func _ready_card(
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
	p_requires_facing: bool = true
) -> CardData:
	return CardData.new(
		p_id,
		p_name,
		p_desc,
		p_min_distance,
		p_max_distance,
		p_cost,
		p_role,
		p_gain_momentum,
		p_break_momentum,
		p_damage,
		p_guard,
		p_tags,
		p_weapon_style,
		p_requires_facing
	)

func _build_catalog() -> void:
	var spear_read := _ready_card("spear_read", "拧枪探势", "长枪控距试探，稳住中远节奏。", 3, 5, 1, CardData.ROLE_FEINT, 2, 0, 0, 0, PackedStringArray(), "枪")
	var spear_break := _ready_card("spear_break", "压杆破势", "枪杆压住来路，专削远处敌势。", 3, 5, 1, CardData.ROLE_ATTACK, 0, 2, 0, 0, PackedStringArray(), "枪")
	var spear_senki := _ready_card("spear_senki", "回身截枪", "错身后反手截势，背向也可命中。", 2, 4, 2, CardData.ROLE_ATTACK, 2, 2, 0, 0, PackedStringArray(["先机", "回身"]), "枪")
	var spear_mid := _ready_card("spear_mid", "中平长刺", "标准中远枪刺。", 3, 5, 1, CardData.ROLE_ATTACK, 0, 0, 4, 0, PackedStringArray(["连招起手", "起手"]), "枪")
	var spear_heavy := _ready_card("spear_heavy", "龙脊贯刺", "大开大合的远距重刺。", 4, 5, 2, CardData.ROLE_ATTACK, 0, 0, 8, 0, PackedStringArray(["终结"]), "枪")
	var spear_guard := _ready_card("spear_guard", "回圆架", "回枪成圆，以守化险。", 0, 5, 1, CardData.ROLE_GUARD, 0, 0, 0, 4, PackedStringArray(), "枪", false)
	var spear_wall := _ready_card("spear_wall", "封门守", "稳固门户，重守待机。", 0, 5, 2, CardData.ROLE_GUARD, 0, 0, 0, 8, PackedStringArray(), "枪", false)

	var blade_probe := _ready_card("blade_probe", "贴步探刀", "刀客贴身试探，抢近身势。", 0, 2, 1, CardData.ROLE_FEINT, 2, 0, 0, 0, PackedStringArray(), "刀")
	var blade_press := _ready_card("blade_press", "逼身断势", "短兵贴压，专破近处敌势。", 0, 2, 1, CardData.ROLE_ATTACK, 0, 2, 0, 0, PackedStringArray(), "刀")
	var blade_senki := _ready_card("blade_senki", "回身燕返", "错身回刀争先，背向也可命中。", 0, 2, 2, CardData.ROLE_ATTACK, 2, 2, 0, 0, PackedStringArray(["先机", "回身"]), "刀")
	var blade_cut := _ready_card("blade_cut", "贴身快斩", "迅捷近身斩击。", 0, 2, 1, CardData.ROLE_ATTACK, 0, 0, 4, 0, PackedStringArray(["连招起手", "起手"]), "刀")
	var blade_heavy := _ready_card("blade_heavy", "断流重斩", "势大力沉的贴身压胜一斩。", 0, 1, 2, CardData.ROLE_ATTACK, 0, 0, 8, 0, PackedStringArray(["终结"]), "刀")
	var blade_guard := _ready_card("blade_guard", "藏锋格", "低身藏锋，以格挡化险。", 0, 3, 1, CardData.ROLE_GUARD, 0, 0, 0, 4, PackedStringArray(), "刀", false)
	var blade_wall := _ready_card("blade_wall", "锁门架", "以刀封门，强守不退。", 0, 3, 2, CardData.ROLE_GUARD, 0, 0, 0, 8, PackedStringArray(), "刀", false)

	var spear_deck: Array[CardData] = [spear_read, spear_break, spear_senki, spear_mid, spear_mid.duplicate_card(), spear_heavy, spear_guard, spear_wall]
	var blade_deck: Array[CardData] = [blade_probe, blade_press, blade_senki, blade_cut, blade_cut.duplicate_card(), blade_heavy, blade_guard, blade_wall]

	fighter_catalog["spearman"] = FighterData.new("spearman", "枪手", "长枪", 24, 6, 5, 1, PackedInt32Array([3, 4, 5]), spear_deck, 1, 2, "right")
	fighter_catalog["blademaster"] = FighterData.new("blademaster", "刀客", "单刀", 22, 6, 5, 2, PackedInt32Array([0, 1, 2]), blade_deck, 1, 6, "left")
	fighter_catalog["master_veteran"] = FighterData.new("master_veteran", "沉默老兵", "旧腰刀", 48, 12, 9, 4, PackedInt32Array([0, 1, 2]), blade_deck, 3, 2, "right")

	reward_pool = [
		_ready_card("reward_momentum_up", "聚势", "专注提振自身势头。", 1, 3, 1, CardData.ROLE_FEINT, 2, 0, 0, 0),
		_ready_card("reward_momentum_break", "断势", "专注削弱敌方势头。", 1, 3, 1, CardData.ROLE_ATTACK, 0, 2, 0, 0),
		_ready_card("reward_senki", "争先", "以先机抢夺势头。", 1, 2, 2, CardData.ROLE_ATTACK, 2, 2, 0, 0, PackedStringArray(["先机"])),
		_ready_card("reward_damage", "重手", "纯粹追求压倒性伤害。", 1, 3, 2, CardData.ROLE_ATTACK, 0, 0, 8, 0, PackedStringArray(["追击"])),
		_ready_card("reward_guard", "铁壁", "纯粹追求稳固格挡。", 1, 3, 2, CardData.ROLE_GUARD, 0, 0, 0, 8)
	]

	combo_registry["spearman"] = [
		{
			"id": "spear_combo_001",
			"display_name": "穿云三刺",
			"starter_card_id": "spear_mid",
			"required_card_ids": PackedStringArray(["spear_mid", "spear_heavy"]),
			"followups": [
				{"name": "追喉刺", "base_damage": 2, "segment_type": "追击"},
				{"name": "龙脊送枪", "base_damage": 4, "segment_type": "终结", "is_finisher": true}
			]
		}
	]
	combo_registry["blademaster"] = [
		{
			"id": "blade_combo_001",
			"display_name": "断流三斩",
			"starter_card_id": "blade_cut",
			"required_card_ids": PackedStringArray(["blade_cut", "blade_heavy"]),
			"followups": [
				{"name": "回身快斩", "base_damage": 2, "segment_type": "追击"},
				{"name": "断流收刀", "base_damage": 5, "segment_type": "终结", "is_finisher": true}
			]
		}
	]
