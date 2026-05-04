extends "res://scripts/Main_route.gd"

func _ready() -> void:
	_load_game_data()
	_build_ui()
	if data_load_error != "":
		_show_data_error()
		return
	_show_class_select()

func _on_next_pressed() -> void:
	if reward_pending:
		return
	battle_index += 1
	_start_battle()

