extends Control

const DESKTOP_SCENE := "res://scenes/MainDesktop.tscn"
const WEB_SCENE := "res://scenes/MainWeb.tscn"

func _ready() -> void:
	var target := WEB_SCENE if OS.has_feature("web") else DESKTOP_SCENE
	get_tree().change_scene_to_file(target)
