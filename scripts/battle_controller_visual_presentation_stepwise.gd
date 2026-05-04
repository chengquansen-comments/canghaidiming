extends "res://scripts/battle_controller_visual_presentation_stepwise_exchange.gd"

# Active stepwise presentation wrapper.
#
# The former monolithic implementation has been split into focused layers:
# - battle_controller_visual_presentation_stepwise_fx.gd
# - battle_controller_visual_presentation_stepwise_focus.gd
# - battle_controller_visual_presentation_stepwise_facing.gd
# - battle_controller_visual_presentation_stepwise_draft.gd
# - battle_controller_visual_presentation_stepwise_exchange.gd
#
# Keep this file thin so downstream scripts can continue extending the original
# public path while the implementation remains maintainable.
