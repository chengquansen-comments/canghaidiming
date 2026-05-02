extends RefCounted
class_name BattleEffectApplier

# v0.4.4 unified battle value writer.
#
# CombatResolver calculates pure results.
# BattleStateMachine owns core round logic.
# BattleEffectApplier owns side-effect writes that currently live in visual wrappers:
# - reactive enemy pre-move commit
# - pressure_profile runtime effects
#
# UI/controllers may still decide WHEN to call these functions, but should not
# directly mutate battle values for these rules.

const Fighter = preload("res://scripts/fighter.gd")
const IntentData = preload("res://scripts/intent_data.gd")
const BattleStateMachine = preload("res://scripts/battle_state_machine.gd")

const PRESSURE_NONE := "none"
const PRESSURE_EDGE := "edge_pressure"
const PRESSURE_BREAK_RESIST := "break_resist"
const BATTLE_SLOT_COUNT := 9


static func apply_reactive_enemy_pre_move(
	state_machine: BattleStateMachine,
	player: Fighter,
	enemy: Fighter,
	enemy_intent: IntentData,
	already_applied_round: int
) -> Dictionary:
	if state_machine == null or not state_machine.is_reactive_mode():
		return {"applied": false, "round": already_applied_round}
	if player == null or enemy == null or enemy_intent == null:
		return {"applied": false, "round": already_applied_round}
	if enemy.is_broken() or enemy.pending_control_state == Fighter.CONTROL_BROKEN:
		return {"applied": false, "round": already_applied_round}
	if already_applied_round == state_machine.round_index:
		return {"applied": false, "round": already_applied_round}
	if enemy_intent.target_position < 0:
		return {"applied": false, "round": already_applied_round}

	var from_position: int = enemy.position
	var from_facing: String = enemy.facing
	var to_position: int = clampi(enemy_intent.target_position, 0, BATTLE_SLOT_COUNT - 1)
	var to_facing: String = enemy_intent.target_facing if enemy_intent.target_facing != "" else enemy.facing
	enemy.position = to_position
	enemy.facing = "left" if to_facing == "left" else "right"
	enemy_intent.set_stance(enemy.position, enemy.facing)
	state_machine.update_distance_from_positions(player, enemy)

	return {
		"applied": true,
		"round": state_machine.round_index,
		"from_position": from_position,
		"to_position": enemy.position,
		"from_facing": from_facing,
		"to_facing": enemy.facing,
		"changed": from_position != enemy.position or from_facing != enemy.facing
	}


static func apply_pressure_profile(
	profile: String,
	player: Fighter,
	enemy: Fighter,
	state_machine: BattleStateMachine,
	context: Dictionary
) -> Dictionary:
	match profile:
		PRESSURE_EDGE:
			return apply_edge_pressure(player, enemy, state_machine, context)
		PRESSURE_BREAK_RESIST:
			return apply_break_resist(enemy, context)
		_:
			return {"applied": false, "events": []}


static func apply_edge_pressure(player: Fighter, enemy: Fighter, state_machine: BattleStateMachine, context: Dictionary) -> Dictionary:
	var events: Array[Dictionary] = []
	var last_edge_positions: Dictionary = context.get("last_edge_positions", {})
	var player_event: Dictionary = _apply_edge_pressure_to_fighter(player, "我方", state_machine, last_edge_positions)
	if bool(player_event.get("applied", false)):
		events.append(player_event)
	var enemy_event: Dictionary = _apply_edge_pressure_to_fighter(enemy, "对手", state_machine, last_edge_positions)
	if bool(enemy_event.get("applied", false)):
		events.append(enemy_event)
	context["last_edge_positions"] = last_edge_positions
	return {"applied": not events.is_empty(), "events": events}


static func _apply_edge_pressure_to_fighter(fighter: Fighter, label: String, state_machine: BattleStateMachine, last_edge_positions: Dictionary) -> Dictionary:
	if fighter == null or state_machine == null:
		return {"applied": false}
	if fighter.position != 0 and fighter.position != BATTLE_SLOT_COUNT - 1:
		return {"applied": false}
	var key := "%s_%d_%d" % [fighter.data.id, state_machine.round_index, fighter.position]
	if last_edge_positions.has(key):
		return {"applied": false}
	last_edge_positions[key] = true
	if fighter.momentum <= 0:
		return {"applied": false}
	var before: int = fighter.momentum
	fighter.momentum = maxi(fighter.momentum - 1, 0)
	var broke := false
	if fighter.momentum == 0:
		fighter.queue_broken_state()
		broke = true
	return {
		"applied": true,
		"type": PRESSURE_EDGE,
		"label": label,
		"fighter_id": fighter.data.id,
		"position": fighter.position,
		"momentum_before": before,
		"momentum_after": fighter.momentum,
		"queued_break": broke
	}


static func apply_break_resist(enemy: Fighter, context: Dictionary) -> Dictionary:
	var available: bool = bool(context.get("break_resist_available", false))
	if not available:
		return {"applied": false, "events": []}
	if enemy == null:
		return {"applied": false, "events": []}
	if enemy.pending_control_state != Fighter.CONTROL_BROKEN:
		return {"applied": false, "events": []}
	context["break_resist_available"] = false
	enemy.pending_control_state = Fighter.CONTROL_NONE
	enemy.momentum = maxi(enemy.momentum, 1)
	var event := {
		"applied": true,
		"type": PRESSURE_BREAK_RESIST,
		"fighter_id": enemy.data.id,
		"momentum_after": enemy.momentum
	}
	return {"applied": true, "events": [event]}


static func is_valid_pressure_profile(value: String) -> bool:
	return value == PRESSURE_NONE or value == PRESSURE_EDGE or value == PRESSURE_BREAK_RESIST
