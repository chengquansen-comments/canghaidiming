extends "res://scripts/battle_controller_visual_tuning_panel.gd"

# Safe compatibility wrapper for the hot tuning layer.
#
# The split hot-tuning implementation introduced parser-time risk in the battle
# scene inheritance chain. MainVisual reaches this file through:
# battle_controller_visual_story_return_intent_visibility.gd
# -> ...
# -> battle_controller_visual_resolver_preview.gd
# -> battle_controller_visual_hot_tuning.gd
#
# Keep this public path safe for battle entry. The extracted hot-tuning helper
# layers remain in the repository but are not linked into the active battle
# controller until they pass local Godot headless validation.
