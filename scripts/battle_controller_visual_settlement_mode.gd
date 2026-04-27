extends "res://scripts/battle_controller_visual_presentation_assets.gd"

# Thin runtime wrapper for switching battle settlement mode without touching the
# existing visual presentation chain.
#
# Default remains "symmetric" to preserve current main behavior.
# Set `settlement_mode_id` to "reactive" in the scene inspector, or call
# `set_visual_settlement_mode("reactive")` at runtime to test v0.4.

@export_enum("symmetric", "reactive") var settlement_mode_id: String = "symmetric"


func _ready() -> void:
	super()
	_apply_visual_settlement_mode()


func set_visual_settlement_mode(value: String) -> void:
	settlement_mode_id = value
	_apply_visual_settlement_mode()
	_refresh_ui()


func toggle_visual_settlement_mode() -> void:
	if settlement_mode_id == BattleStateMachine.MODE_REACTIVE_ID:
		set_visual_settlement_mode(BattleStateMachine.MODE_SYMMETRIC_ID)
	else:
		set_visual_settlement_mode(BattleStateMachine.MODE_REACTIVE_ID)


func _apply_visual_settlement_mode() -> void:
	if state_machine == null:
		return
	state_machine.set_settlement_mode_id(settlement_mode_id)
	print("[settlement-mode] ", state_machine.settlement_mode_id())


func _mode_status_suffix() -> String:
	if state_machine == null:
		return ""
	return "\n结算模式：%s（%s）" % [state_machine.settlement_mode_label(), state_machine.settlement_mode_id()]


func _refresh_ui() -> void:
	super()
	if status_label != null and state_machine != null:
		status_label.append_text(_mode_status_suffix())
