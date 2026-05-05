extends RefCounted
class_name ShoushiComboRules

const CardData = preload("res://scripts/card_data.gd")
const CombatResolver = preload("res://scripts/combat_resolver.gd")

static var ENABLE_SHOUSHI_COMBO := true

const MODE_DISABLED := "disabled"
const MODE_EXP_DAMAGE_GUARD := "exp_damage_guard"

static var CURRENT_MODE := MODE_EXP_DAMAGE_GUARD

const _CHINESE_NUMERALS := ["零", "一", "二", "三", "四", "五", "六", "七", "八", "九", "十"]


static func is_enabled() -> bool:
	return ENABLE_SHOUSHI_COMBO and CURRENT_MODE != MODE_DISABLED


static func max_rank_for_realm(realm: int) -> int:
	return clampi(realm, 1, 10)


static func multiplier_for_combo_count(combo_count: int) -> int:
	return 1 << maxi(combo_count - 1, 0)


static func combo_count_text(combo_count: int) -> String:
	if combo_count >= 0 and combo_count < _CHINESE_NUMERALS.size():
		return "%s连" % _CHINESE_NUMERALS[combo_count]
	return "%d连" % combo_count


static func rank_text(rank: int) -> String:
	var safe_rank := clampi(rank, 0, 10)
	if safe_rank < _CHINESE_NUMERALS.size():
		return _CHINESE_NUMERALS[safe_rank]
	return str(safe_rank)


static func combo_brief_text(combo_count: int, multiplier: int) -> String:
	return "%s×%d" % [combo_count_text(combo_count), maxi(multiplier, 1)]


static func evaluate_action(actor, card: CardData, range_result: String, actor_action_canceled: bool) -> Dictionary:
	var previous_rank := 0
	var previous_count := 0
	if actor != null:
		previous_rank = int(actor.last_effective_shoushi_rank)
		previous_count = int(actor.shoushi_combo_count)
	return evaluate_action_state(previous_rank, previous_count, card, range_result, actor_action_canceled)


static func evaluate_action_state(previous_rank: int, previous_count: int, card: CardData, range_result: String, actor_action_canceled: bool) -> Dictionary:
	if not is_enabled():
		return _result(false, false, false, 0, 0, 0, 1, false, "disabled")
	var rank := card.shoushi_rank if card != null else 0
	if actor_action_canceled:
		return _result(true, false, true, rank, previous_rank, 0, 1, false, "canceled")
	if card == null:
		return _result(true, false, false, 0, previous_rank, previous_count, 1, false, "no_card")
	if card.id == "idle" or card.id == "staggered":
		return _result(true, false, false, rank, previous_rank, previous_count, 1, false, "non_action")
	if card.requires_hit_check():
		var hit := range_result == CombatResolver.RANGE_HIT
		var grazed := CombatResolver.ENABLE_GRAZE and range_result == CombatResolver.RANGE_GRAZE
		if not hit and not grazed:
			return _result(true, false, true, rank, previous_rank, 0, 1, false, "missed")
	var combo_count := 1
	var reason := "rank_reset"
	if rank > previous_rank:
		combo_count = maxi(previous_count, 0) + 1
		reason = "rank_increased"
	var multiplier := multiplier_for_combo_count(combo_count)
	return _result(true, true, false, rank, previous_rank, combo_count, multiplier, combo_count > 1, reason)


static func apply_state_to_actor(actor, combo_result: Dictionary) -> void:
	if actor == null or not bool(combo_result.get("enabled", false)):
		return
	if bool(combo_result.get("should_reset", false)):
		actor.reset_shoushi_combo()
		return
	if bool(combo_result.get("is_effective", false)):
		actor.set_shoushi_combo_state(
			int(combo_result.get("rank", 0)),
			int(combo_result.get("combo_count", 0)),
			int(combo_result.get("multiplier", 1))
		)


static func build_effective_card(original: CardData, multiplier: int) -> CardData:
	var result: CardData = original.duplicate_card()
	if not is_enabled():
		return result
	match CURRENT_MODE:
		MODE_EXP_DAMAGE_GUARD:
			result.damage = original.damage * multiplier
			result.guard = original.guard * multiplier
			result.break_momentum = original.break_momentum
			result.gain_momentum = original.gain_momentum
			result.momentum_cost = original.momentum_cost
			result.self_move_after = original.self_move_after
			result.target_push_after = original.target_push_after
			result.target_pull_after = original.target_pull_after
		_:
			pass
	return result


static func _result(enabled: bool, is_effective: bool, should_reset: bool, rank: int, previous_rank: int, combo_count: int, multiplier: int, triggered: bool, reason: String) -> Dictionary:
	return {
		"enabled": enabled,
		"is_effective": is_effective,
		"should_reset": should_reset,
		"rank": rank,
		"previous_rank": previous_rank,
		"combo_count": combo_count,
		"multiplier": multiplier,
		"triggered": triggered,
		"reason": reason
	}
