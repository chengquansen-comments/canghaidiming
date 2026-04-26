extends RefCounted
class_name FeintData

@warning_ignore("shadowed_global_identifier")
const CardData = preload("res://scripts/card_data.gd")

var display_card: CardData


func _init(p_display_card: CardData) -> void:
	display_card = p_display_card


func visible_name() -> String:
	return display_card.display_name
