extends "res://scripts/battle_controller_demo_visual.gd"

# Dedicated visual battle controller entry.
# This keeps the current demo presentation path explicit and separate
# from the pure text debugging entry, while delegating reusable concerns
# to helper scripts under scripts/visual/.

const BattleSkinHelper = preload("res://scripts/visual/battle_skin.gd")
const BattleStageHelper = preload("res://scripts/visual/battle_stage_view.gd")
const BattleHudHelper = preload("res://scripts/visual/battle_hud_view.gd")

func _safe_load_texture(path: String) -> Texture2D:
	return BattleSkinHelper.load_texture_or_svg(path)

func _make_demo_panel_style(fill: Color, border: Color) -> StyleBox:
	return BattleSkinHelper.make_visual_panel_style(fill, border, PANEL_FRAME_PATH)

func _make_button_style(tint: Color) -> StyleBox:
	return BattleSkinHelper.make_button_style(tint, BUTTON_FRAME_PATH, PANEL_FRAME_PATH)

func _grid_total_width() -> float:
	return BattleStageHelper.grid_total_width(GRID_SLOT_COUNT, GRID_SLOT_WIDTH, GRID_SLOT_GAP)

func _slot_center_x(slot: int) -> float:
	return BattleStageHelper.slot_center_x(size.x, slot, GRID_SLOT_COUNT, GRID_SLOT_WIDTH, GRID_SLOT_GAP)

func _current_grid_positions() -> Dictionary:
	var distance := state_machine.current_distance if state_machine != null else 2
	return BattleStageHelper.current_grid_positions(distance, GRID_RIGHT_ANCHOR_SLOT, GRID_SLOT_COUNT)

func _target_slot_for_preview(is_player: bool, player_slot: int, enemy_slot: int, card: CardData) -> int:
	return BattleStageHelper.target_slot_for_preview(is_player, player_slot, enemy_slot, card, GRID_SLOT_COUNT)

func _attack_range_slots(is_player: bool, origin_slot: int, card: CardData) -> Array[int]:
	return BattleStageHelper.attack_range_slots(is_player, origin_slot, card, GRID_SLOT_COUNT)

func _ease_preview(value: float) -> float:
	return BattleStageHelper.ease_preview(value)

func _compact_effect_summary(card: CardData) -> String:
	return BattleHudHelper.compact_effect_summary(card)

func _compact_button_text(card: CardData, marker: String, reason: String) -> String:
	var text := BattleHudHelper.compact_button_text(card, _card_role_prefix(card), marker, _draft_uses_card(card))
	if reason != "":
		text += "\n限制：%s" % reason
	return text

func _card_detail_text(card: CardData) -> String:
	return BattleHudHelper.card_detail_text(card)
