extends RefCounted
class_name HiddenMoveData

const CardData = preload("res://scripts/card_data.gd")
const FeintData = preload("res://scripts/feint_data.gd")

var feint: FeintData
var real_card: CardData


func _init(p_feint: FeintData, p_real_card: CardData) -> void:
	feint = p_feint
	real_card = p_real_card


func is_valid() -> bool:
	return feint != null and real_card != null and feint.display_card.id != real_card.id
