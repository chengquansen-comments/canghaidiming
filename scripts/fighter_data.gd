extends RefCounted
class_name FighterData

const CardData = preload("res://scripts/card_data.gd")

var id: String
var display_name: String
var weapon_name: String
var max_hp: int
var max_momentum: int
var starting_momentum: int
var starting_realm: int
var preferred_distances: PackedInt32Array
var starting_deck: Array[CardData]
var qinggong: int
var starting_position: int
var starting_facing: String


func _init(
	p_id: String = "",
	p_display_name: String = "",
	p_weapon_name: String = "",
	p_max_hp: int = 20,
	p_max_momentum: int = 6,
	p_starting_momentum: int = 5,
	p_starting_realm: int = 1,
	p_preferred_distances: PackedInt32Array = PackedInt32Array(),
	p_starting_deck: Array[CardData] = [],
	p_qinggong: int = 1,
	p_starting_position: int = 0,
	p_starting_facing: String = "right"
) -> void:
	id = p_id
	display_name = p_display_name
	weapon_name = p_weapon_name
	max_hp = p_max_hp
	max_momentum = maxi(p_max_momentum, 1)
	starting_momentum = clampi(p_starting_momentum, 0, max_momentum)
	starting_realm = p_starting_realm
	preferred_distances = p_preferred_distances
	qinggong = maxi(p_qinggong, 1)
	starting_position = clampi(p_starting_position, 0, 8)
	starting_facing = "left" if p_starting_facing == "left" else "right"
	starting_deck = []
	for card in p_starting_deck:
		starting_deck.append(card.duplicate_card())


func clone_deck() -> Array[CardData]:
	var result: Array[CardData] = []
	for card in starting_deck:
		result.append(card.duplicate_card())
	return result
