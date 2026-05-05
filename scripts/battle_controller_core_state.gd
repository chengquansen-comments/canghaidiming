extends Control

const BattleStateMachine = preload("res://scripts/battle_state_machine.gd")
const EnemyAI = preload("res://scripts/enemy_ai.gd")
const FighterData = preload("res://scripts/fighter_data.gd")
const Fighter = preload("res://scripts/fighter.gd")
const CardData = preload("res://scripts/card_data.gd")
const IntentData = preload("res://scripts/intent_data.gd")

const HAND_SIZE := 4
const PLAYER_BATTLE_DECK_SIZE := 8
const PLAYER_DECK_SLOT_COUNT := 4
const PLAYER_DECK_CARD_COPY_LIMIT := 2
const DECK_LIBRARY_FILTERS := ["全部", "攻", "守", "变"]
const ENEMY_SESSION_REALM := 2
const ROUND_MOMENTUM_RECOVERY := 2
const BATTLE_SLOT_COUNT := 9

var state_machine := BattleStateMachine.new()
var enemy_ai := EnemyAI.new()
var fighter_catalog: Dictionary[String, FighterData] = {}
var reward_pool: Array[CardData] = []
var combo_registry: Dictionary[String, Array] = {}

var player: Fighter
var enemy: Fighter
var player_role_id := ""
var battle_active := false
var awaiting_player_input := false
var battle_count := 0
var completed_battle_count := 0
var node_pick_count := 0

var player_intent: IntentData
var enemy_intent: IntentData
var draft_player_intent: IntentData
var draft_player_position := -1
var draft_player_facing := ""
var draft_player_has_position := false
var declaration_order: PackedStringArray = PackedStringArray()
var declaration_index := 0

var fusion_first_index := -1
var deck_builder_selected_slot_index := -1
var deck_builder_filter := "全部"
var deck_builder_library_page := 0

var title_label: Label
var subtitle_label: Label
var round_label: Label
var phase_label: Label
var player_label: RichTextLabel
var enemy_label: RichTextLabel
var player_visible_label: RichTextLabel
var enemy_visible_label: RichTextLabel
var status_label: RichTextLabel
var preview_label: RichTextLabel
var hand_flow: Container
var log_label: RichTextLabel
var node_buttons_box: HBoxContainer
var deck_button: Button
var reset_pick_button: Button
var confirm_button: Button
var overlay_scrim: ColorRect
var overlay_panel: PanelContainer
var overlay_title: Label
var overlay_body: RichTextLabel
var overlay_actions: VBoxContainer
var battle_result_scrim: ColorRect
var battle_result_panel: PanelContainer
var battle_result_title: Label
var battle_result_body: Label
var battle_result_actions: VBoxContainer
var combat_banner: PanelContainer
var combat_banner_label: Label
var screen_flash: ColorRect
var pierce_line: ColorRect
var slash_cut: ColorRect
var left_hit_mark: ColorRect
var right_hit_mark: ColorRect

# Shared state layer for the battle controller inheritance chain.
