extends RefCounted

var c

func _init(controller) -> void:
	c = controller

func build_exchange_request() -> Dictionary:
	var old_player_slot: int = c.player.position if c.player != null else -1
	var old_enemy_slot: int = c.enemy.position if c.enemy != null else -1
	var selected_player_card: CardData = c._intent_card(c.draft_player_intent)
	if selected_player_card == null:
		selected_player_card = c._intent_card(c.player_intent)
	var visible_enemy_card: CardData = c._enemy_preview_card()
	var p_intent: IntentData = c.draft_player_intent if c.draft_player_intent != null else c.player_intent
	var order: Array[String] = c._preview_resolution_order(p_intent, c.enemy_intent)
	var preview_sim: Dictionary = {}
	if c.player != null and c.enemy != null:
		preview_sim = c._ordered_preview_simulation(p_intent, c.enemy_intent)
	return {
		"player_card": selected_player_card,
		"enemy_card": visible_enemy_card,
		"order": normalized_order(order),
		"old_player_slot": old_player_slot,
		"old_enemy_slot": old_enemy_slot,
		"preview_sim": preview_sim
	}

static func normalized_order(order: Array[String]) -> Array[String]:
	var safe_order: Array[String] = order.duplicate()
	if safe_order.is_empty():
		safe_order = ["player", "enemy"]
	return safe_order

static func result_for_side(preview_sim: Dictionary, side: String) -> Dictionary:
	var fallback := {"range": "hit", "damage": 0, "break": 0, "gain": 0, "guard": 0, "shoushi_combo_count": 0, "shoushi_multiplier": 1, "shoushi_triggered": false}
	var steps_value = preview_sim.get("steps", [])
	if not (steps_value is Array):
		return fallback
	for step_value in steps_value:
		if not (step_value is Dictionary):
			continue
		var step: Dictionary = step_value
		if str(step.get("side", "")) != side:
			continue
		if str(step.get("phase", "")) != "effect":
			continue
		return {
			"range": str(step.get("range", "hit")),
			"damage": int(step.get("damage", 0)),
			"break": int(step.get("break", 0)),
			"gain": int(step.get("gain", 0)),
			"guard": int(step.get("guard", 0)),
			"shoushi_rank": int(step.get("shoushi_rank", 0)),
			"shoushi_combo_count": int(step.get("shoushi_combo_count", 0)),
			"shoushi_multiplier": int(step.get("shoushi_multiplier", 1)),
			"shoushi_triggered": bool(step.get("shoushi_triggered", false)),
			"shoushi_mode": str(step.get("shoushi_mode", ShoushiComboRules.CURRENT_MODE))
		}
	return fallback
