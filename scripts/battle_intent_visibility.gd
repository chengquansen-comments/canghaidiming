extends RefCounted
class_name BattleIntentVisibility

const USE_INTENT_VISIBILITY_POLICY := true

const POLICY_FULL := "full"
const POLICY_REALM_BASED := "realm_based"
const POLICY_HIDDEN := "hidden"

const VISIBILITY_FULL := "full"
const VISIBILITY_TYPE := "type"
const VISIBILITY_NONE := "none"


static func resolve_enemy_visibility(policy: String, is_reactive: bool, player_realm: int, enemy_realm: int) -> String:
	if not USE_INTENT_VISIBILITY_POLICY:
		return VISIBILITY_FULL
	match policy:
		POLICY_FULL:
			return VISIBILITY_FULL
		POLICY_HIDDEN:
			return VISIBILITY_NONE
		POLICY_REALM_BASED:
			if not is_reactive:
				return VISIBILITY_FULL
			if player_realm > enemy_realm:
				return VISIBILITY_FULL
			if player_realm == enemy_realm:
				return VISIBILITY_TYPE
			return VISIBILITY_NONE
		_:
			return VISIBILITY_FULL


static func is_valid_policy(policy: String) -> bool:
	return policy == POLICY_FULL or policy == POLICY_REALM_BASED or policy == POLICY_HIDDEN


static func should_show_enemy_card(visibility: String) -> bool:
	return visibility == VISIBILITY_FULL


static func should_show_enemy_numbers(visibility: String) -> bool:
	return visibility == VISIBILITY_FULL


static func should_show_enemy_range(visibility: String) -> bool:
	return visibility == VISIBILITY_FULL


static func should_show_enemy_final_preview(visibility: String) -> bool:
	return visibility == VISIBILITY_FULL


static func enemy_card_title(card: CardData, visibility: String) -> String:
	if visibility == VISIBILITY_FULL:
		return card.display_name if card != null else "待命"
	if visibility == VISIBILITY_TYPE:
		return "敌方意图：%s" % card_tactic_type_text(card)
	return "敌方意图：不可辨"


static func enemy_intent_bubble_text(card: CardData, visibility: String, full_text: String) -> String:
	if visibility == VISIBILITY_FULL:
		return full_text
	if visibility == VISIBILITY_TYPE:
		return "敌方意图：%s" % card_tactic_type_text(card)
	return "敌方意图：不可辨"


static func card_tactic_type_text(card: CardData) -> String:
	if card == null:
		return "变"
	if card.damage > 0 or card.break_momentum > 0:
		return "攻"
	if card.guard > 0:
		return "守"
	return "变"


static func visibility_label(visibility: String) -> String:
	match visibility:
		VISIBILITY_FULL:
			return "全意图"
		VISIBILITY_TYPE:
			return "仅类型"
		VISIBILITY_NONE:
			return "不可辨"
		_:
			return visibility
