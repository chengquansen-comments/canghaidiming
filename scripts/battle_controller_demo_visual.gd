extends "res://scripts/battle_controller_demo_visual_runtime.gd"

# Demo visual public path wrapper.
#
# The former monolithic implementation has been split into focused layers:
# - battle_controller_demo_visual_foundation.gd
# - battle_controller_demo_visual_stage.gd
# - battle_controller_demo_visual_hud.gd
# - battle_controller_demo_visual_bottom.gd
# - battle_controller_demo_visual_overlay.gd
# - battle_controller_demo_visual_runtime.gd
#
# Keep this file stable because the MainVisual inheritance chain reaches it
# through battle_controller_visual_ui_state.gd.
