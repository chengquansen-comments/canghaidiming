extends RefCounted

const SPEARMAN_CARDS: Array[String] = [
	"spear_step_thrust",
	"spear_step_thrust",
	"spear_retreat_sting",
	"spear_retreat_sting",
	"reward_push",
	"reward_push",
	"reward_guard",
	"reward_guard",
]

const BLADEMASTER_CARDS: Array[String] = [
	"blade_press_break",
	"blade_press_break",
	"blade_hook_pull",
	"blade_hook_pull",
	"blade_body_press",
	"blade_body_press",
	"reward_guard",
	"reward_guard",
]

static func build_profile(role: String = "spearman", martial_level: int = 1) -> Dictionary:
	var owned_card_ids: Array[String] = BLADEMASTER_CARDS.duplicate() if role == "blademaster" else SPEARMAN_CARDS.duplicate()
	var selected_loadout_ids: Array[String] = owned_card_ids.duplicate()
	return {
		"role": role,
		"career": "调试武生",
		"weapon": "长枪" if role == "spearman" else "腰刀",
		"martial_level": martial_level,
		"max_hp": 32,
		"hp": 32,
		"max_posture": 10,
		"posture": 5,
		"qinggong": 1,
		"owned_card_ids": owned_card_ids,
		"selected_loadout_ids": selected_loadout_ids,
		"deck_slots": [],
		"active_deck_index": 0,
		"debug_profile": true,
	}
