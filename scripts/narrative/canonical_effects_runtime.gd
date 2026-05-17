extends RefCounted

# Canonical narrative variable helper for MVP narrative controllers.
#
# Pure helper only. It does not save NarrativeBattleContext, render UI, switch
# scenes, advance nodes, or call owner/controller methods.

const StrategicMapState := preload("res://scripts/strategic_map_state.gd")

const VAR_MILITARY_MERIT := "military_merit"
const VAR_CLEAN_REPUTATION := "clean_reputation"
const VAR_CASE_CLUES := "case_clues"
const VAR_SOLDIER_TRUST := "soldier_trust"
const VAR_RIVAL_GU_BOND := "rival_gu_bond"
const VAR_RIVAL_SHEN_BOND := "rival_shen_bond"
const VAR_RIVAL_QI_BOND := "rival_qi_bond"
const VAR_ROUTE_BIAS_MILITARY := "route_bias_military"
const VAR_ROUTE_BIAS_REPUTATION := "route_bias_reputation"
const VAR_ROUTE_BIAS_OLD_CASE := "route_bias_old_case"
const VAR_SHEN_RESPECT := "shen_respect"
const VAR_SHEN_SUSPICION := "shen_suspicion"
const VAR_GU_TRUST := "gu_trust"
const VAR_GU_AFFECTION := "gu_affection"
const VAR_GU_IDENTITY_KNOWN := "gu_identity_known"
const VAR_GU_IDENTITY_PUBLIC_RISK := "gu_identity_public_risk"
const VAR_QI_TRUST := "qi_trust"
const VAR_TRUTH_PROGRESS := "truth_progress"
const VAR_MILITARY_RANK_PROGRESS := "military_rank_progress"
const VAR_PUBLIC_REPUTATION := "public_reputation"

const LEGACY_NUMERIC_FIELDS := [
	VAR_SOLDIER_TRUST,
	VAR_RIVAL_GU_BOND,
	VAR_RIVAL_SHEN_BOND,
	VAR_RIVAL_QI_BOND,
]

const LEGACY_VAR_ALIASES := {
	"jun_gong": VAR_MILITARY_MERIT,
	"qing_wang": VAR_CLEAN_REPUTATION,
	"clues": VAR_CASE_CLUES,
	"public_repute": VAR_CLEAN_REPUTATION,
	"case_clues": VAR_CASE_CLUES,
	"soldier_trust": VAR_SOLDIER_TRUST,
	"rival_gu_bond": VAR_RIVAL_GU_BOND,
	"rival_shen_bond": VAR_RIVAL_SHEN_BOND,
	"rival_qi_bond": VAR_RIVAL_QI_BOND,
}


static func empty_effects() -> Dictionary:
	var effects: Dictionary = {}
	for key in story_numeric_fields():
		effects[key] = 0
	for key in story_boolean_fields():
		effects[key] = false
	return effects


static func story_numeric_fields() -> Array[String]:
	var fields: Array[String] = []
	for key in StrategicMapState.STORY_NUMERIC_FIELDS:
		if not (str(key) in fields):
			fields.append(str(key))
	for key in LEGACY_NUMERIC_FIELDS:
		if not (str(key) in fields):
			fields.append(str(key))
	return fields


static func story_boolean_fields() -> Array[String]:
	var fields: Array[String] = []
	for key in StrategicMapState.STORY_BOOLEAN_FIELDS:
		fields.append(str(key))
	return fields


static func strategic_story_state_defaults() -> Dictionary:
	var result: Dictionary = {}
	for key in StrategicMapState.STORY_NUMERIC_FIELDS:
		if not (str(key) in [VAR_MILITARY_MERIT, VAR_CLEAN_REPUTATION, VAR_CASE_CLUES]):
			result[str(key)] = 0
	for key in StrategicMapState.STORY_BOOLEAN_FIELDS:
		result[str(key)] = false
	return result


static func canonical_state(military_merit: int, clean_reputation: int, case_clues: int, rival_gu_bond: int, rival_shen_bond: int, rival_qi_bond: int, story_values: Dictionary = {}) -> Dictionary:
	var state := empty_effects()
	state[VAR_MILITARY_MERIT] = military_merit
	state[VAR_CLEAN_REPUTATION] = clean_reputation
	state[VAR_CASE_CLUES] = case_clues
	state[VAR_SOLDIER_TRUST] = int(story_values.get(VAR_SOLDIER_TRUST, 0))
	state[VAR_RIVAL_GU_BOND] = rival_gu_bond
	state[VAR_RIVAL_SHEN_BOND] = rival_shen_bond
	state[VAR_RIVAL_QI_BOND] = rival_qi_bond
	for key in StrategicMapState.STORY_NUMERIC_FIELDS:
		if not (str(key) in [VAR_MILITARY_MERIT, VAR_CLEAN_REPUTATION, VAR_CASE_CLUES]):
			state[str(key)] = int(story_values.get(str(key), state.get(str(key), 0)))
	for key in StrategicMapState.STORY_BOOLEAN_FIELDS:
		state[str(key)] = bool(story_values.get(str(key), state.get(str(key), false)))
	return state


static func normalize_effects(raw_effects: Dictionary) -> Dictionary:
	var normalized := empty_effects()
	for raw_key in raw_effects.keys():
		var key := str(raw_key)
		var canonical_key := str(LEGACY_VAR_ALIASES.get(key, key))
		if canonical_key in story_numeric_fields():
			normalized[canonical_key] = int(normalized[canonical_key]) + int(raw_effects[raw_key])
		elif canonical_key in story_boolean_fields():
			normalized[canonical_key] = bool(raw_effects[raw_key])
	return normalized


static func apply_effects_to_values(values: Dictionary, effects: Dictionary) -> Dictionary:
	var normalized := normalize_effects(effects)
	var next_values := empty_effects()
	for key in story_numeric_fields():
		next_values[key] = int(values.get(key, 0)) + int(normalized.get(key, 0))
	for key in story_boolean_fields():
		next_values[key] = bool(normalized.get(key, false)) if effects.has(key) else bool(values.get(key, false))
	return next_values


static func choice_delta(choice: Dictionary) -> Dictionary:
	return normalize_effects({
		VAR_MILITARY_MERIT: int(choice.get(VAR_MILITARY_MERIT, choice.get("dg", choice.get("jun_gong", 0)))),
		VAR_CLEAN_REPUTATION: int(choice.get(VAR_CLEAN_REPUTATION, choice.get("dq", choice.get("qing_wang", choice.get("public_repute", 0))))),
		VAR_CASE_CLUES: int(choice.get(VAR_CASE_CLUES, choice.get("dc", choice.get("clues", 0)))),
		VAR_SOLDIER_TRUST: int(choice.get(VAR_SOLDIER_TRUST, 0)),
		VAR_RIVAL_GU_BOND: int(choice.get(VAR_RIVAL_GU_BOND, 0)),
		VAR_RIVAL_SHEN_BOND: int(choice.get(VAR_RIVAL_SHEN_BOND, 0)),
		VAR_RIVAL_QI_BOND: int(choice.get(VAR_RIVAL_QI_BOND, 0)),
	})
