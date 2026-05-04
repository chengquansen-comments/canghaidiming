extends "res://scripts/battle_controller_core_round_resolution.gd"

# Split from battle_controller_core.gd; keep behavior-compatible with the original controller.

func _ready() -> void:
	position = Vector2.ZERO
	_build_catalog()
	_build_ui()
	state_machine.reset_for_session()
	_show_role_selection()
