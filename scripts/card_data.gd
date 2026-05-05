extends RefCounted
class_name CardData

# Current tactical role ids. role is a UI / intent / AI / analytics label only.
# It must not be used by CombatResolver as a hard counter table.
const ROLE_GUARD := "guard"
const ROLE_ATTACK := "attack"
const ROLE_FEINT := "feint"

# Legacy role ids. Kept only for one-time normalization of old card definitions.
const ROLE_MOMENTUM := "momentum"
const ROLE_DAMAGE := "damage"
const ROLE_DEFENSE := "defense"

const MOVE_NONE := "none"
const MOVE_ON_HIT := "on_hit"
const MOVE_ALWAYS := "always"
const MOVE_ON_BREAK := "on_break"
const MOVE_ON_GRAZE := "on_graze"

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
var self_move_after: int
var target_push_after: int
var target_pull_after: int
var move_condition: String
var shoushi_rank: int


func _init(
	p_id: String = "",
	p_display_name: String = "",
	p_description: String = "",
	p_min_distance: int = 1,
	p_max_distance: int = 3,
	p_momentum_cost: int = 1,
	p_role: String = ROLE_ATTACK,
	p_gain_momentum: int = 0,
	p_break_momentum: int = 0,
	p_damage: int = 0,
	p_guard: int = 0,
	p_tags: PackedStringArray = PackedStringArray(),
	p_weapon_style: String = "",
	p_requires_facing: bool = true,
	p_self_move_after: int = 0,
	p_target_push_after: int = 0,
	p_target_pull_after: int = 0,
	p_move_condition: String = MOVE_NONE,
	p_shoushi_rank: int = 1
) -> void:
	id = p_id
	display_name = p_display_name
	description = p_description
	min_distance = p_min_distance
	max_distance = p_max_distance
	momentum_cost = maxi(p_momentum_cost, 0)
	gain_momentum = maxi(p_gain_momentum, 0)
	break_momentum = maxi(p_break_momentum, 0)
	damage = maxi(p_damage, 0)
	guard = maxi(p_guard, 0)
	tags = p_tags.duplicate()
	weapon_style = p_weapon_style
	requires_facing = p_requires_facing
	self_move_after = clampi(p_self_move_after, -1, 1)
	target_push_after = clampi(p_target_push_after, 0, 1)
	target_pull_after = clampi(p_target_pull_after, 0, 1)
	move_condition = _normalize_move_condition(p_move_condition)
	shoushi_rank = clampi(p_shoushi_rank, 1, 10)
	role = _normalize_role_once(p_role)


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
		requires_facing,
		self_move_after,
		target_push_after,
		target_pull_after,
		move_condition,
		shoushi_rank
	)


func _normalize_role_once(value: String) -> String:
	# New explicit tactical role ids.
	match value:
		ROLE_GUARD, ROLE_ATTACK, ROLE_FEINT:
			return value

	# Legacy values are converted once at construction time.
	# Prefer card fields over old semantic names so old ROLE_MOMENTUM cards with
	# break/damage become attack, while pure movement/tempo cards become feint.
	if damage > 0 or break_momentum > 0:
		return ROLE_ATTACK
	if self_move_after != 0 or target_push_after > 0 or target_pull_after > 0:
		return ROLE_FEINT
	if gain_momentum > 0 and guard <= 0:
		return ROLE_FEINT
	match value:
		ROLE_DAMAGE:
			return ROLE_ATTACK
		ROLE_DEFENSE, ROLE_MOMENTUM:
			return ROLE_GUARD
		_:
			return ROLE_GUARD


func _normalize_move_condition(value: String) -> String:
	match value:
		MOVE_ON_HIT, MOVE_ALWAYS, MOVE_ON_BREAK, MOVE_ON_GRAZE:
			return value
		_:
			return MOVE_NONE


func has_tag(tag: String) -> bool:
	return tags.has(tag)


func is_usable_at(distance: int) -> bool:
	return distance >= min_distance and distance <= max_distance


func is_momentum_card() -> bool:
	return role == ROLE_FEINT


func is_damage_card() -> bool:
	return role == ROLE_ATTACK


func is_guard_card() -> bool:
	return role == ROLE_GUARD


func is_attack_card() -> bool:
	return role == ROLE_ATTACK


func is_defense_card() -> bool:
	return role == ROLE_GUARD


func is_feint_card() -> bool:
	return role == ROLE_FEINT


func category_role() -> String:
	return role


func requires_hit_check() -> bool:
	return damage > 0 or break_momentum > 0


func effect_budget() -> int:
	return gain_momentum * 2 + break_momentum * 2 + damage + guard


func type_label() -> String:
	match role:
		ROLE_GUARD:
			return "守"
		ROLE_ATTACK:
			return "攻"
		ROLE_FEINT:
			return "变"
		_:
			return "守"


func movement_summary_parts() -> Array[String]:
	var parts: Array[String] = []
	if target_push_after > 0:
		parts.append("击退%d" % target_push_after)
	if target_pull_after > 0:
		parts.append("拉近%d" % target_pull_after)
	if self_move_after > 0:
		parts.append("进身%d" % self_move_after)
	elif self_move_after < 0:
		parts.append("后撤%d" % absi(self_move_after))
	if move_condition != MOVE_NONE and not parts.is_empty():
		parts.append("条件%s" % move_condition)
	return parts


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
	parts.append("收式 %d" % shoushi_rank)
	var move_parts := movement_summary_parts()
	if not move_parts.is_empty():
		parts.append("位移 %s" % " / ".join(move_parts))
	return "%s｜%s" % [display_name, "｜".join(parts)]
