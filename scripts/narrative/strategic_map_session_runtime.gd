extends RefCounted

# Pure session-state builder for strategic map entry.
#
# This helper builds the initial strategic_state for world-map entry. It has no
# UI writes, no context saves, no scene switching, and no render calls. The
# controller remains responsible for assigning the returned state and triggering
# presentation updates.

const StrategicMapState := preload("res://scripts/strategic_map_state.gd")
const StrategicMapGenerator := preload("res://scripts/strategic_map_generator.gd")
const StrategicNetworkMapGenerator := preload("res://scripts/strategic_network_map_generator.gd")
const StrategicNetworkMapRuntime := preload("res://scripts/strategic_network_map_runtime.gd")
const AigcDungeonBigMapLoader := preload("res://scripts/aigc_dungeon_big_map_loader.gd")

const BASE_SEED := 1701
const MILITARY_SEED_WEIGHT := 17
const REPUTATION_SEED_WEIGHT := 31
const CLUE_SEED_WEIGHT := 43


static func build_initial_state(strategic_config: Dictionary, profile: Dictionary, military_merit: int, clean_reputation: int, case_clues: int) -> Dictionary:
	var state := StrategicMapState.default_state()
	state["active"] = true
	state["seed"] = BASE_SEED + military_merit * MILITARY_SEED_WEIGHT + clean_reputation * REPUTATION_SEED_WEIGHT + case_clues * CLUE_SEED_WEIGHT
	state["military_merit"] = military_merit
	state["clean_reputation"] = clean_reputation
	state["case_clues"] = case_clues
	state["martial_level"] = int(profile.get("martial_level", 1))
	state = StrategicMapState.sync_card_state_from_profile(state, profile)
	if AigcDungeonBigMapLoader.has_compatible_map_file():
		var bundle := AigcDungeonBigMapLoader.load_runtime_bundle()
		if bool(bundle.get("ok", false)):
			AigcDungeonBigMapLoader.apply_bundle_to_state(state, bundle)
			state["seed"] = int((bundle.get("network_map", {}) as Dictionary).get("seed", state["seed"]))
			return state
		push_error("AIGC dungeon session bootstrap failed: %s" % str(bundle.get("error", "unknown")))
	state["current_map"] = StrategicMapGenerator.generate_map(strategic_config, state, int(state["seed"]))
	var network_map := StrategicNetworkMapGenerator.generate_network_map(strategic_config, state, int(state["seed"]))
	state["network_map"] = network_map
	StrategicNetworkMapRuntime.sync_mirror_fields(state, network_map)
	return state


static func summarize_network_map(state: Dictionary) -> String:
	return StrategicNetworkMapGenerator.summarize_network_map(state.get("network_map", {}) as Dictionary)
