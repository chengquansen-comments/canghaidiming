extends RefCounted

# Canonical narrative variable helper for MVP narrative controllers.
#
# Pure helper only. It does not save NarrativeBattleContext, render UI, switch
# scenes, advance nodes, or call owner/controller methods.

const VAR_MILITARY_MERIT := "military_merit"
const VAR_CLEAN_REPUTATION := "clean_reputation"
const VAR_CASE_CLUES := "case_clues"
const VAR_SOLDIER_TRUST := "soldier_trust"
const VAR_RIVAL_GU_BOND := "rival_gu_bond"
const VAR_RIVAL_SHEN_BOND := "rival_shen_bond"
const VAR_RIVAL_QI_BOND := "rival_qi_bond"

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
	return {
		VAR_MILITARY_MERIT: 0,
		VAR_CLEAN_REPUTATION: 0,
		VAR_CASE_CLUES: 0,
		VAR_SOLDIER_TRUST: 0,
		VAR_RIVAL_GU_BOND: 0,
		VAR_RIVAL_SHEN_BOND: 0,
		VAR_RIVAL_QI_BOND: 0,
	}


static func canonical_state(military_merit: int, clean_reputation: int, case_clues: int, rival_gu_bond: int, rival_shen_bond: int, rival_qi_bond: int) -> Dictionary:
	return {
		VAR_MILITARY_MERIT: military_merit,
		VAR_CLEAN_REPUTATION: clean_reputation,
		VAR_CASE_CLUES: case_clues,
		VAR_SOLDIER_TRUST: 0,
		VAR_RIVAL_GU_BOND: rival_gu_bond,
		VAR_RIVAL_SHEN_BOND: rival_shen_bond,
		VAR_RIVAL_QI_BOND: rival_qi_bond,
	}


static func normalize_effects(raw_effects: Dictionary) -> Dictionary:
	var normalized := empty_effects()
	for raw_key in raw_effects.keys():
		var key := str(raw_key)
		var canonical_key := str(LEGACY_VAR_ALIASES.get(key, key))
		if normalized.has(canonical_key):
			normalized[canonical_key] = int(normalized[canonical_key]) + int(raw_effects[raw_key])
	return normalized


static func apply_effects_to_values(values: Dictionary, effects: Dictionary) -> Dictionary:
	var normalized := normalize_effects(effects)
	return {
		VAR_MILITARY_MERIT: int(values.get(VAR_MILITARY_MERIT, 0)) + int(normalized[VAR_MILITARY_MERIT]),
		VAR_CLEAN_REPUTATION: int(values.get(VAR_CLEAN_REPUTATION, 0)) + int(normalized[VAR_CLEAN_REPUTATION]),
		VAR_CASE_CLUES: int(values.get(VAR_CASE_CLUES, 0)) + int(normalized[VAR_CASE_CLUES]),
		VAR_SOLDIER_TRUST: int(values.get(VAR_SOLDIER_TRUST, 0)) + int(normalized[VAR_SOLDIER_TRUST]),
		VAR_RIVAL_GU_BOND: int(values.get(VAR_RIVAL_GU_BOND, 0)) + int(normalized[VAR_RIVAL_GU_BOND]),
		VAR_RIVAL_SHEN_BOND: int(values.get(VAR_RIVAL_SHEN_BOND, 0)) + int(normalized[VAR_RIVAL_SHEN_BOND]),
		VAR_RIVAL_QI_BOND: int(values.get(VAR_RIVAL_QI_BOND, 0)) + int(normalized[VAR_RIVAL_QI_BOND]),
	}


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
