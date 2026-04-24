extends SceneTree

const CardData = preload("res://scripts/card_data.gd")
const IntentData = preload("res://scripts/intent_data.gd")
const BattleHudHelper = preload("res://scripts/visual/battle_hud_view.gd")

func _init() -> void:
	var selected_card := CardData.new("selected", "已确认招式", "确认后仍应显示。", 1, 3, 1, CardData.ROLE_DAMAGE, 0, 0, 8, 0)
	var confirmed_intent := IntentData.new()
	confirmed_intent.actual_card = selected_card
	var focused := BattleHudHelper.focused_card(null, confirmed_intent)
	if focused != selected_card:
		push_error("BattleHudHelper.focused_card should keep confirmed player intent visible.")
		quit(1)
		return
	var summary := BattleHudHelper.compact_effect_summary(selected_card)
	if not summary.contains("伤害 8"):
		push_error("BattleHudHelper.compact_effect_summary should render typed CardData effects.")
		quit(1)
		return
	var detail := BattleHudHelper.card_detail_text(selected_card)
	if not detail.contains("已确认招式"):
		push_error("BattleHudHelper.card_detail_text should render the selected CardData.")
		quit(1)
		return
	BattleHudHelper.clear_text_cache()
	quit(0)
