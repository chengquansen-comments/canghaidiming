extends RefCounted
class_name CardData

# Phase 1: plain card data remains valid for ordinary moves.
var id: String
var display_name: String
var description: String
var min_distance: int
var max_distance: int
var damage: int
var distance_delta: int
var momentum_cost: int
var tags: PackedStringArray


func _init(
	p_id: String = "",
	p_display_name: String = "",
	p_description: String = "",
	p_min_distance: int = 1,
	p_max_distance: int = 3,
	p_damage: int = 0,
	p_distance_delta: int = 0,
	p_momentum_cost: int = 1,
	p_tags: PackedStringArray = PackedStringArray()
) -> void:
	id = p_id
	display_name = p_display_name
	description = p_description
	min_distance = p_min_distance
	max_distance = p_max_distance
	damage = p_damage
	distance_delta = p_distance_delta
	momentum_cost = maxi(p_momentum_cost, 0)
	tags = p_tags.duplicate()


func duplicate_card() -> CardData:
	# Phase 1: duplicate through the script resource to keep typed ordinary cards compatible.
	return load("res://scripts/card_data.gd").new(
		id,
		display_name,
		description,
			min_distance,
			max_distance,
			damage,
			distance_delta,
			momentum_cost,
			tags
		)


func has_tag(tag: String) -> bool:
	return tags.has(tag)


func is_usable_at(distance: int) -> bool:
	return distance >= min_distance and distance <= max_distance


func short_summary() -> String:
	var parts: Array[String] = []
	parts.append("距%d-%d" % [min_distance, max_distance])
	parts.append("耗势 %d" % momentum_cost)
	if damage > 0:
		parts.append("伤害 %d" % damage)
	if distance_delta != 0:
		parts.append("距离 %+d" % distance_delta)
	if not tags.is_empty():
		parts.append("标签 %s" % " / ".join(tags))
	return "%s｜%s" % [display_name, "｜".join(parts)]
