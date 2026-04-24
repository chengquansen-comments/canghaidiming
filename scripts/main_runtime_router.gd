extends Control

const DESKTOP_SCENE := "res://scenes/MainDesktop.tscn"
const WEB_SCENE := "res://scenes/MainWeb.tscn"

func _ready() -> void:
	call_deferred("_route_to_runtime")

func _route_to_runtime() -> void:
	if not is_inside_tree():
		return
	var target := WEB_SCENE if OS.has_feature("web") else DESKTOP_SCENE
	var error := get_tree().change_scene_to_file(target)
	if error != OK:
		push_error("Failed to switch runtime scene: %s (%d)" % [target, error])
