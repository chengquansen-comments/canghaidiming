extends RefCounted
class_name IntentData

const Fighter = preload("res://scripts/fighter.gd")
const CardData = preload("res://scripts/card_data.gd")
const HiddenMoveData = preload("res://scripts/hidden_move_data.gd")

const SIDE_NONE := ""
const SIDE_PLAYER := "player"
const SIDE_ENEMY := "enemy"

var actor_id: String
var actor_side: String = SIDE_NONE
var source_fighter: Fighter
var visible_card: CardData
var actual_card: CardData
var hidden_move: HiddenMoveData
var consumed_cards: Array[CardData] = []
var target_position: int = -1
var target_facing: String = ""


static func from_card(source: Fighter, card: CardData, side: String = SIDE_NONE) -> IntentData:
	var intent: IntentData = load("res://scripts/intent_data.gd").new()
	intent.actor_id = source.data.id
	intent.actor_side = _normalized_side(side)
	intent.source_fighter = source
	intent.visible_card = card
	intent.actual_card = card
	intent.hidden_move = null
	intent.consumed_cards = [card]
	intent.target_position = source.position
	intent.target_facing = source.facing
	return intent


static func from_hidden_move(source: Fighter, hidden: HiddenMoveData, cards_to_consume: Array[CardData], side: String = SIDE_NONE) -> IntentData:
	var intent: IntentData = load("res://scripts/intent_data.gd").new()
	intent.actor_id = source.data.id
	intent.actor_side = _normalized_side(side)
	intent.source_fighter = source
	intent.visible_card = hidden.feint.display_card
	intent.actual_card = hidden.real_card
	intent.hidden_move = hidden
	intent.consumed_cards = cards_to_consume.duplicate()
	intent.target_position = source.position
	intent.target_facing = source.facing
	return intent


static func _normalized_side(value: String) -> String:
	if value == SIDE_PLAYER or value == SIDE_ENEMY:
		return value
	return SIDE_NONE


func set_actor_side(value: String) -> void:
	actor_side = _normalized_side(value)


func set_stance(position: int, facing: String) -> void:
	target_position = clampi(position, 0, 8)
	target_facing = "left" if facing == "left" else "right"


func is_hidden() -> bool:
	return hidden_move != null


func has_tag(tag: String) -> bool:
	return actual_card != null and actual_card.has_tag(tag)


func has_senki() -> bool:
	return has_tag("先机")


func get_visible_name() -> String:
	if visible_card == null:
		return "未定"
	return visible_card.display_name


func get_actual_name() -> String:
	if actual_card == null:
		return "未定"
	return actual_card.display_name


func get_visible_summary() -> String:
	if is_hidden():
		return "藏招｜表招：%s" % visible_card.short_summary()
	return "常招｜%s" % actual_card.short_summary()


func get_actual_summary() -> String:
	if actual_card == null:
		return "未定"
	return "可见意图｜%s" % actual_card.short_summary()


func get_consumed_cards() -> Array[CardData]:
	return consumed_cards.duplicate()


func can_hidden_be_read(_viewer: Fighter) -> bool:
	# Phase 2 hook: keep the interface, but do not implement feint breaking yet.
	return false
