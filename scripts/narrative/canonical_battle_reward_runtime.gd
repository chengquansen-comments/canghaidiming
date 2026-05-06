extends RefCounted

# Pure battle reward helper for canonical narrative controllers.
#
# This helper calculates narrative variable rewards and player growth rewards.
# It does not call NarrativeBattleContext, save context, render UI, switch scenes,
# advance nodes, or call owner/controller methods.

const CanonicalEffectsRuntime := preload("res://scripts/narrative/canonical_effects_runtime.gd")


static func empty_reward() -> Dictionary:
	return CanonicalEffectsRuntime.empty_effects()


static func reward_from_context_or_node(context_reward: Dictionary, source_index: int, active_node_count: int, node: Dictionary, formal_reward: Dictionary = {}) -> Dictionary:
	if not context_reward.is_empty():
		return CanonicalEffectsRuntime.normalize_effects(context_reward)
	if source_index < 0 or source_index >= active_node_count:
		return empty_reward()
	if not formal_reward.is_empty():
		return CanonicalEffectsRuntime.normalize_effects(formal_reward)
	return fallback_reward_for_node_type(str(node.get("type", "")))


static func fallback_reward_for_node_type(node_type: String) -> Dictionary:
	match node_type:
		"普通战斗", "精英战斗":
			return CanonicalEffectsRuntime.normalize_effects({
				CanonicalEffectsRuntime.VAR_MILITARY_MERIT: 1,
				CanonicalEffectsRuntime.VAR_CASE_CLUES: 1,
			})
		"Boss":
			return CanonicalEffectsRuntime.normalize_effects({
				CanonicalEffectsRuntime.VAR_MILITARY_MERIT: 2,
				CanonicalEffectsRuntime.VAR_CASE_CLUES: 2,
			})
		_:
			return CanonicalEffectsRuntime.normalize_effects({
				CanonicalEffectsRuntime.VAR_MILITARY_MERIT: 1,
			})


static func growth_reward(source_index: int, active_node_count: int, formal_reward: Dictionary = {}) -> Dictionary:
	if source_index < 0 or source_index >= active_node_count:
		return {"hp_gain": 0, "posture_gain": 0, "martial_gain": 0, "heal_full": false}
	if not formal_reward.is_empty():
		return formal_reward
	return {"hp_gain": 0, "posture_gain": 0, "martial_gain": 0, "heal_full": true}


static func growth_text_or_default(growth: Dictionary) -> String:
	return str(growth.get("reward_text", "战斗胜利：已返回剧情，并自动推进到下一节点。"))
