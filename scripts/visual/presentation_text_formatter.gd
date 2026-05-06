extends RefCounted

const PRESENTATION_LUNGE_SLASH := 70.0
const PRESENTATION_LUNGE_THRUST := 92.0
const PRESENTATION_HIT_PAUSE_LIGHT := 0.080
const PRESENTATION_HIT_PAUSE_HEAVY := 0.130
const PRESENTATION_HIT_PAUSE_BREAK := 0.180

static func style_for_card(card: CardData) -> String:
	if card == null:
		return "idle"
	if card.is_guard_card():
		return "guard"
	if card.is_feint_card() and int(card.damage) <= 0 and int(card.break_momentum) <= 0:
		return "focus"
	var weapon_style: String = str(card.weapon_style)
	var card_id: String = str(card.id)
	var card_name: String = str(card.display_name)
	if weapon_style.findn("火") >= 0 or weapon_style.findn("fire") >= 0 or card_id.findn("fire") >= 0 or card_name.findn("铳") >= 0 or card_name.findn("火") >= 0:
		return "firearm"
	if weapon_style.findn("枪") >= 0 or weapon_style.findn("spear") >= 0:
		return "thrust"
	if card_id.findn("spear") >= 0:
		return "thrust"
	return "slash"

static func result_should_hit(card: CardData, result: Dictionary) -> bool:
	if card == null:
		return false
	if not card.requires_hit_check():
		return true
	var range_result: String = str(result.get("range", "hit"))
	return range_result == CombatResolver.RANGE_HIT or (CombatResolver.ENABLE_GRAZE and range_result == CombatResolver.RANGE_GRAZE)

static func lunge_distance(style: String, result: Dictionary) -> float:
	if style == "firearm":
		return 26.0
	var base_distance: float = PRESENTATION_LUNGE_THRUST if style == "thrust" else PRESENTATION_LUNGE_SLASH
	if normalized_range_for_display(str(result.get("range", "hit"))) == CombatResolver.RANGE_GRAZE:
		return base_distance * 0.78
	return base_distance

static func attack_color(style: String, result: Dictionary) -> Color:
	var color: Color = Color("9fd8ff") if style == "thrust" else Color("ff9f73")
	if style == "firearm":
		color = Color("e4572e")
	var range_result: String = normalized_range_for_display(str(result.get("range", "hit")))
	if range_result == CombatResolver.RANGE_GRAZE:
		return color.darkened(0.22)
	if range_result == CombatResolver.RANGE_MISS_RANGE or range_result == CombatResolver.RANGE_MISS_FACING:
		return Color(0.72, 0.72, 0.68, 0.62)
	return color

static func normalized_range_for_display(range_result: String) -> String:
	if range_result == CombatResolver.RANGE_GRAZE and not CombatResolver.ENABLE_GRAZE:
		return CombatResolver.RANGE_MISS_RANGE
	return range_result

static func hit_pause_duration(result: Dictionary, target_will_break: bool) -> float:
	if target_will_break:
		return PRESENTATION_HIT_PAUSE_BREAK
	var damage_value: int = int(result.get("damage", 0))
	var break_value: int = int(result.get("break", 0))
	if damage_value >= 6 or break_value >= 4:
		return PRESENTATION_HIT_PAUSE_HEAVY
	if damage_value > 0 or break_value > 0:
		return PRESENTATION_HIT_PAUSE_LIGHT
	return 0.0

static func guard_label(result: Dictionary) -> String:
	var guard_value: int = int(result.get("guard", 0))
	return "守+%d" % guard_value if guard_value > 0 else "守"

static func focus_label(result: Dictionary) -> String:
	var gain_value: int = int(result.get("gain", 0))
	return "势+%d" % gain_value if gain_value > 0 else "势"

static func miss_label(result: Dictionary) -> String:
	var range_result: String = str(result.get("range", "hit"))
	if range_result == "miss_range":
		return "距外"
	if range_result == "miss_facing":
		return "背向"
	return "未中"

static func result_text_data(target_is_enemy: bool, card: CardData, result: Dictionary) -> Dictionary:
	if card == null:
		return {"visible": false}
	var parts: Array[String] = []
	var range_result: String = normalized_range_for_display(str(result.get("range", "hit")))
	var damage_value: int = int(result.get("damage", card.damage))
	var break_value: int = int(result.get("break", card.break_momentum))
	var gain_value: int = int(result.get("gain", card.gain_momentum))
	if range_result == CombatResolver.RANGE_GRAZE:
		parts.append("擦中")
	elif range_result == "miss_range":
		parts.append("距外")
	elif range_result == "miss_facing":
		parts.append("背向")
	if damage_value > 0:
		parts.append("-%d" % damage_value)
	if break_value > 0:
		parts.append("势-%d" % break_value)
	if damage_value <= 0 and break_value <= 0 and gain_value > 0 and not target_is_enemy:
		parts.append("势+%d" % gain_value)
	if parts.is_empty():
		return {"visible": false}
	var color: Color = Color("c44a3f")
	if range_result == CombatResolver.RANGE_GRAZE:
		color = Color("d9b66c")
	elif range_result == "miss_range" or range_result == "miss_facing":
		color = Color(0.72, 0.72, 0.68, 0.9)
	return {
		"visible": true,
		"text": " / ".join(parts),
		"target_is_player": not target_is_enemy,
		"color": color
	}

static func shoushi_text(result: Dictionary) -> String:
	if int(result.get("shoushi_multiplier", 1)) <= 1:
		return ""
	var combo_count := int(result.get("shoushi_combo_count", 0))
	var multiplier := int(result.get("shoushi_multiplier", 1))
	return "收式%s ×%d" % [ShoushiComboRules.combo_count_text(combo_count), multiplier]
