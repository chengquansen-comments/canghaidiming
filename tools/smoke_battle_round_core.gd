extends SceneTree

const BattleStateMachine = preload("res://scripts/battle_state_machine.gd")
const CardData = preload("res://scripts/card_data.gd")
const Fighter = preload("res://scripts/fighter.gd")
const FighterData = preload("res://scripts/fighter_data.gd")
const IntentData = preload("res://scripts/intent_data.gd")

func _init() -> void:
	var thrust := CardData.new("smoke_thrust", "烟测突刺", "用于回归测试的一格伤害。", 1, 3, 1, CardData.ROLE_DAMAGE, 0, 0, 8, 0)
	var guard := CardData.new("smoke_guard", "烟测守势", "用于回归测试的格挡。", 1, 3, 1, CardData.ROLE_GUARD, 0, 0, 0, 6)
	var player := Fighter.new(FighterData.new("player", "玩家", "枪", 30, 5, 5, 1, PackedInt32Array([2]), [thrust, guard]))
	var enemy := Fighter.new(FighterData.new("enemy", "敌人", "刀", 30, 5, 5, 2, PackedInt32Array([2]), [thrust.duplicate_card(), guard.duplicate_card()]))
	var state_machine := BattleStateMachine.new()
	state_machine.begin_battle(2)

	var player_intent := IntentData.from_card(player, thrust)
	var enemy_intent := IntentData.from_card(enemy, guard)
	if not player.spend_momentum(thrust.momentum_cost):
		_fail("Player should have enough momentum for smoke thrust.")
		return
	if not enemy.spend_momentum(guard.momentum_cost):
		_fail("Enemy should have enough momentum for smoke guard.")
		return

	var order := state_machine.get_resolution_order(player, enemy, player_intent, enemy_intent)
	if order.size() != 2 or order[0] != enemy_intent:
		_fail("Higher-realm enemy should resolve before lower-realm player without 先机.")
		return

	for intent in order:
		var actor: Fighter = player if intent.actor_id == player.data.id else enemy
		var target: Fighter = enemy if intent.actor_id == player.data.id else player
		state_machine.resolve_intent(intent, actor, target)

	if enemy.guard_points != 0:
		_fail("Player thrust should consume enemy guard before HP damage.")
		return
	if enemy.hp != 28:
		_fail("Enemy should take 2 HP after guarding 6 from 8 damage, got %d." % enemy.hp)
		return
	if player.momentum != 4 or enemy.momentum != 4:
		_fail("Both smoke actors should spend exactly 1 momentum.")
		return

	state_machine.finish_round(player, enemy)
	if state_machine.round_index != 2 or state_machine.phase != BattleStateMachine.BattlePhase.DECLARE:
		_fail("Smoke round should advance back to declare phase.")
		return
	if player.guard_points != 0 or enemy.guard_points != 0:
		_fail("Round finish should clear guard points.")
		return

	quit(0)

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
