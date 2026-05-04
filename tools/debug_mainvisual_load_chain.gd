extends SceneTree

# MainVisual inheritance-chain loader diagnostic.
#
# Usage:
#   HOME=/private/tmp godot --headless --path . --script tools/debug_mainvisual_load_chain.gd
#
# Purpose:
#   Godot often reports the outer child script when any ancestor in the extends
#   chain fails to parse. This script loads the active MainVisual chain from the
#   deepest known base upward, then finally loads the scene script. The first
#   LOAD_FAILED entry is the file to inspect; Godot should also print the real
#   parser error above it.

const CHAIN_PATHS := [
	"res://scripts/battle_controller_core_action_summary.gd",
	"res://scripts/battle_controller_core_actor_resolver.gd",
	"res://scripts/battle_controller_core_battle_flow.gd",
	"res://scripts/battle_controller_core_data.gd",
	"res://scripts/battle_controller_core_session.gd",
	"res://scripts/battle_controller_core_ui.gd",
	"res://scripts/battle_controller_core.gd",
	"res://scripts/battle_controller_visual_ui_theme.gd",
	"res://scripts/battle_controller_visual_ui_controls.gd",
	"res://scripts/battle_controller_visual_ui_overlays.gd",
	"res://scripts/battle_controller_visual_ui_layout.gd",
	"res://scripts/battle_controller_visual_ui.gd",
	"res://scripts/battle_controller_visual_support.gd",
	"res://scripts/battle_controller_visual_responsive_ui.gd",
	"res://scripts/battle_controller_visual_preview_checked.gd",
	"res://scripts/battle_controller_visual_tuning_panel.gd",
	"res://scripts/battle_controller_visual_hot_tuning.gd",
	"res://scripts/battle_controller_visual_resolver_preview.gd",
	"res://scripts/battle_controller_visual_break_preview.gd",
	"res://scripts/battle_controller_visual_narrative_context.gd",
	"res://scripts/battle_controller_visual_narrative_formal.gd",
	"res://scripts/battle_controller_visual_scene_manifest.gd",
	"res://scripts/battle_controller_visual_presentation.gd",
	"res://scripts/battle_controller_visual_presentation_stepwise_fx.gd",
	"res://scripts/battle_controller_visual_presentation_stepwise_focus.gd",
	"res://scripts/battle_controller_visual_presentation_stepwise_facing.gd",
	"res://scripts/battle_controller_visual_presentation_stepwise_draft.gd",
	"res://scripts/battle_controller_visual_presentation_stepwise_exchange.gd",
	"res://scripts/battle_controller_visual_presentation_stepwise.gd",
	"res://scripts/battle_controller_visual_presentation_mode_aware.gd",
	"res://scripts/battle_controller_visual_preview_position_guard.gd",
	"res://scripts/battle_controller_visual_story_selection.gd",
	"res://scripts/battle_controller_visual_reactive_round_flow.gd",
	"res://scripts/battle_controller_visual_settlement_mode.gd",
	"res://scripts/battle_controller_visual_story_return.gd",
	"res://scripts/battle_controller_visual_story_return_intent_visibility.gd",
	"res://scenes/MainVisual.tscn"
]

func _initialize() -> void:
	print("=== MainVisual load-chain diagnostic start ===")
	var failed := false
	for path: String in CHAIN_PATHS:
		print("LOAD_BEGIN: %s" % path)
		var resource := load(path)
		if resource == null:
			printerr("LOAD_FAILED: %s" % path)
			failed = true
			break
		print("LOAD_OK: %s -> %s" % [path, resource.get_class()])
	if failed:
		printerr("=== MainVisual load-chain diagnostic failed ===")
		quit(1)
		return
	print("=== MainVisual load-chain diagnostic passed ===")
	quit(0)
