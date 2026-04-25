extends RefCounted
class_name CardData

const ROLE_MOMENTUM := "momentum"
const ROLE_DAMAGE := "damage"
const ROLE_GUARD := "guard"

var id: String
var display_name: String
var description: String
var min_distance: int
var max_distance: int
var momentum_cost: int
var role: String
var gain_momentum: int
var break_momentum: int
var damage: int
var guard: int
var tags: PackedStringArray
var weapon_style: String
var requires_facing: bool


func _init(
	p_id: String = "",
	p_display_name: String = "",
	p_description: String = "",
	p_min_distance: int = 1,
	p_max_distance: int = 3,
	p_momentum_cost: int = 1,
	p_role: String = ROLE_DAMAGE,
	p_gain_momentum: int = 0,
	p_break_momentum: int = 0,
	p_damage: int = 0,
	p_guard: int = 0,
	p_tags: PackedStringArray = PackedStringArray(),
	p_weapon_style: String = "",
	p_requires_facing: bool = true
) -> void:
	id = p_id
	display_name = p_display_name
	description = p_description
	min_distance = p_min_distance
	max_distance = p_max_distance
	momentum_cost = maxi(p_momentum_cost, 0)
	role = p_role
	gain_momentum = maxi(p_gain_momentum, 0)
	break_momentum = maxi(p_break_momentum, 0)
	damage = maxi(p_damage, 0)
	guard = maxi(p_guard, 0)
	tags = p_tags.duplicate()
	weapon_style = p_weapon_style
	requires_facing = p_requires_facing


func duplicate_card() -> CardData:
	return load("res://scripts/card_data.gd").new(
		id,
		display_name,
		description,
		min_distance,
		max_distance,
		momentum_cost,
		role,
		gain_momentum,
		break_momentum,
		damage,
		guard,
		tags,
		weapon_style,
		requires_facing
	)


func has_tag(tag: String) -> bool:
	return tags.has(tag)


func is_usable_at(distance: int) -> bool:
	return distance >= min_distance and distance <= max_distance


func is_momentum_card() -> bool:
	return role == ROLE_MOMENTUM


func is_damage_card() -> bool:
	return role == ROLE_DAMAGE


func is_guard_card() -> bool:
	return role == ROLE_GUARD

func requires_hit_check() -> bool:
	return not is_guard_card() and (damage > 0 or gain_momentum > 0 or break_momentum > 0)


func effect_budget() -> int:
	return gain_momentum * 2 + break_momentum * 2 + damage + guard


func type_label() -> String:
	match role:
		ROLE_MOMENTUM:
			return "势牌"
		ROLE_GUARD:
			return "格挡牌"
		_:
			return "伤害牌"


func short_summary() -> String:
	var parts: Array[String] = []
	parts.append(type_label())
	parts.append("距%d-%d" % [min_distance, max_distance])
	parts.append("耗势 %d" % momentum_cost)
	if gain_momentum > 0:
		parts.append("增己势 %d" % gain_momentum)
	if break_momentum > 0:
		parts.append("削敌势 %d" % break_momentum)
	if damage > 0:
		parts.append("伤害 %d" % damage)
	if guard > 0:
		parts.append("格挡 %d" % guard)
	if not tags.is_empty():
		parts.append("标签 %s" % " / ".join(tags))
	if weapon_style != "":
		parts.append("式 %s" % weapon_style)
	return "%s｜%s" % [display_name, "｜".join(parts)]
