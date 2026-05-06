extends "res://scripts/narrative_demo_safe_controller.gd"

const WebRuntimeFlags := preload("res://scripts/web_runtime_flags.gd")

func _ready() -> void:
	super._ready()
	WebRuntimeFlags.set_body_dataset("webSmokeBattle", "narrative-web-ready")
