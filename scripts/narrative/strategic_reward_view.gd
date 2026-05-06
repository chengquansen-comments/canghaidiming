extends RefCounted

# View helper for legacy strategic-map card reward choice.
#
# Owns only UI rendering and selection UI refresh. It does not apply rewards,
# advance the strategic cursor, save context, or mutate node effects.

const BattleFontHelper := preload("res://scripts/visual/battle_font_view.gd")
const StrategicMapState := preload("res://scripts/strategic_map_state.gd")
const CHOICE_MINIMUM_SIZE := Vector2(0, 76)
const CONFIRM_MINIMUM_SIZE := Vector2(0, 64)
const CANCEL_MINIMUM_SIZE := Vector2(0, 54)
const CONFIRM_BUTTON_NAME := "StrategicCardRewardConfirm"
const MAP_PLACEHOLDER := "卡牌奖励不会自动发放，需先三选一。"
const COMBAT_PLACEHOLDER := "非战斗节点"

var owner = null


func _init(owner_node) -> void:
	owner = owner_node


func render_reward_choice(node: Dictionary, card_ids: Array[String], select_callback: Callable, confirm_callback: Callable, cancel_callback: Callable) -> void:
	if owner == null:
		return
	owner._clear_dynamic_boxes()
	owner.title_label.text = str(node.get("title", "得招"))
	owner.status_label.text = "%s / 招式抉择" % owner._strategic_type_label(str(node.get("node_type", "")))
	owner.map_label.text = owner._strategic_progress_text(owner.strategic_state.get("current_map", {}))
	owner.scene_label.text = owner._format_scene_text(str(node.get("preview_text", "")))
	owner._render_visual(str(node.get("visual_path", "")), str(node.get("title", "得招")))
	owner.body_label.text = "%s\n\n选择 1 张新招式加入长期牌库，然后确认。" % str(node.get("result_text", "你得了一次整理招式的机会。"))
	owner.vars_label.text = StrategicMapState.summary_text(owner.strategic_state)
	owner._add_placeholder(owner.map_buttons_box, MAP_PLACEHOLDER)
	owner._add_placeholder(owner.combat_buttons_box, COMBAT_PLACEHOLDER)
	for card_id: String in card_ids:
		var btn := Button.new()
		btn.text = owner._strategic_card_choice_text(card_id, false)
		btn.custom_minimum_size = CHOICE_MINIMUM_SIZE
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.pressed.connect(select_callback.bind(card_id))
		owner.choices_box.add_child(btn)
	var confirm := Button.new()
	confirm.name = CONFIRM_BUTTON_NAME
	confirm.text = "确认"
	confirm.disabled = true
	confirm.custom_minimum_size = CONFIRM_MINIMUM_SIZE
	confirm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	confirm.pressed.connect(confirm_callback)
	owner.choices_box.add_child(confirm)
	var cancel := Button.new()
	cancel.text = "返回本层选择"
	cancel.custom_minimum_size = CANCEL_MINIMUM_SIZE
	cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cancel.pressed.connect(cancel_callback)
	owner.choices_box.add_child(cancel)
	BattleFontHelper.enforce(owner)
	owner._apply_focus_ui()
	owner._hide_scene_art_overlay_nodes()


func refresh_selected_card(card_id: String, card_choices: Array[String], node: Dictionary) -> void:
	if owner == null:
		return
	for child in owner.choices_box.get_children():
		if child is Button:
			var btn := child as Button
			if btn.name == CONFIRM_BUTTON_NAME:
				btn.disabled = card_id.is_empty()
				continue
			if card_id in card_choices:
				for choice_id: String in card_choices:
					if btn.text.find(owner._strategic_card_label(choice_id)) >= 0:
						btn.text = owner._strategic_card_choice_text(choice_id, choice_id == card_id)
	owner.body_label.text = "%s\n\n已选择：%s" % [str(node.get("result_text", "")), owner._strategic_card_label(card_id)]
