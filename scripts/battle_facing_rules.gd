extends RefCounted

# Phase 13.0 helper.
# Owns facing/back-hit/turn-card decisions. It is intentionally pure:
# no UI mutation, no combat resolution, no animation side effects.

static func is_valid_facing(facing_value: String) -> bool:
	return facing_value == "left" or facing_value == "right"

static func opposite_facing(facing_value: String) -> String:
	if facing_value == "left":
		return "right"
	if facing_value == "right":
		return "left"
	return ""

static func facing_sign(facing_value: String) -> float:
	return -1.0 if facing_value == "left" else 1.0

static func facing_toward_slot(actor_slot: int, target_slot: int) -> String:
	if target_slot > actor_slot:
		return "right"
	if target_slot < actor_slot:
		return "left"
	return ""

static func exposes_back_to_slot(facing_value: String, actor_slot: int, attacker_slot: int) -> bool:
	if not is_valid_facing(facing_value):
		return false
	if attacker_slot > actor_slot:
		return facing_value == "left"
	if attacker_slot < actor_slot:
		return facing_value == "right"
	return false

static func card_has_turn_during_action(card) -> bool:
	if card == null:
		return false
	if card_has_tag(card, "转身") or card_has_tag(card, "回身") or card_has_tag(card, "反身") or card_has_tag(card, "翻身") or card_has_tag(card, "回马"):
		return true
	var id_text: String = str(card.id)
	var name_text: String = str(card.display_name)
	return id_text.findn("turn") >= 0 or id_text.findn("reverse") >= 0 or id_text.findn("backturn") >= 0 or name_text.find("转身") >= 0 or name_text.find("回身") >= 0 or name_text.find("反身") >= 0 or name_text.find("翻身") >= 0 or name_text.find("回马") >= 0

static func card_has_tag(card, tag: String) -> bool:
	if card == null:
		return false
	for item in card.tags:
		if str(item) == tag:
			return true
	return false

static func should_turn_after_back_hit(result: Dictionary, player, enemy) -> bool:
	if player == null or enemy == null:
		return false
	if not bool(result.get("was_back_hit", false)):
		return false
	if bool(result.get("will_die", false)) or bool(result.get("will_break", false)):
		return false
	return player.hp > 0

static func back_hit_turn_to(result: Dictionary, player, enemy) -> String:
	var turn_to: String = str(result.get("back_hit_turn_to", ""))
	if is_valid_facing(turn_to):
		return turn_to
	if player == null or enemy == null:
		return ""
	return facing_toward_slot(player.position, enemy.position)
