extends "res://scripts/battle_controller_visual_hot_tuning_ui.gd"

# Active hot tuning controller wrapper.
#
# The former monolithic implementation has been split into focused layers:
# - battle_controller_visual_hot_tuning_state.gd
# - battle_controller_visual_hot_tuning_profile_collect.gd
# - battle_controller_visual_hot_tuning_profile_snapshot.gd
# - battle_controller_visual_hot_tuning_profile_format.gd
# - battle_controller_visual_hot_tuning_profile_store.gd
# - battle_controller_visual_hot_tuning_profile.gd
# - battle_controller_visual_hot_tuning_sampler_core.gd
# - battle_controller_visual_hot_tuning_sampler_cards.gd
# - battle_controller_visual_hot_tuning_sampler.gd
# - battle_controller_visual_hot_tuning_config.gd
# - battle_controller_visual_hot_tuning_pipeline.gd
# - battle_controller_visual_hot_tuning_ui.gd
#
# Keep this public path thin so scenes and downstream scripts can continue
# extending the original controller while implementation details stay small.
