extends RefCounted

const StrategicMapState := preload("res://scripts/strategic_map_state.gd")
const NarrativeBattleContext := preload("res://scripts/narrative_battle_context.gd")

static func sync_context_cards_to_state(strategic_state: Dictionary) -> Dictionary:
	var profile: Dictionary = NarrativeBattleContext.get_player_profile()
	if profile.is_empty():
		return strategic_state
	return StrategicMapState.sync_card_state_from_profile(strategic_state, profile)

static func sync_state_cards_to_context(strategic_state: Dictionary) -> void:
	if not NarrativeBattleContext.has_player_profile():
		return
	NarrativeBattleContext.set_player_card_state(
		strategic_state.get("owned_card_ids", []),
		strategic_state.get("selected_loadout_ids", []),
		strategic_state.get("deck_slots", []),
		int(strategic_state.get("active_deck_index", 0))
	)
