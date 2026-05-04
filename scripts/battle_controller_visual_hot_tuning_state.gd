extends "res://scripts/battle_controller_visual_tuning_panel.gd"

const AutoBattleSampler = preload("res://scripts/auto_battle_sampler.gd")
const HotTuningCardDataScript = preload("res://scripts/card_data.gd")
const HotTuningNarrativeBattleContext = preload("res://scripts/narrative_battle_context.gd")

const NUMBER_PROFILE_SCHEMA := 2
const NUMBER_PROFILE_STORE_PATH := "user://battle_number_profiles.json"

var _hot_controls_root: VBoxContainer
var _last_sample_report := "未采样"
var _number_configs: Array[Dictionary] = []
var _active_number_config_index := -1
var _number_config_select: OptionButton
var _target_select: OptionButton
var _number_config_status := "未生成数值方案"
var _number_config_serial := 1
var _number_pipeline_fields: Dictionary = {}
var _number_pipeline_baseline: Dictionary = {}
var _number_pipeline_sample_count: SpinBox
var _number_pipeline_seed: SpinBox

# Shared state for hot tuning split layers.
