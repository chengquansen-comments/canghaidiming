extends "res://scripts/narrative_demo_ui_focus_tuned_controller.gd"

const WebRuntimeFlags := preload("res://scripts/web_runtime_flags.gd")

func _ready() -> void:
	super._ready()
	WebRuntimeFlags.set_body_dataset("webSmokeBattle", "narrative-web-ready")
