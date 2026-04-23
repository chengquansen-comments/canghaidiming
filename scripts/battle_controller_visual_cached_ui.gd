extends "res://scripts/battle_controller_visual_ui.gd"

const BattleSkinHelper = preload("res://scripts/visual/battle_skin.gd")

func _sheet_frame_texture(source: Texture2D, frame: int) -> Texture2D:
	return BattleSkinHelper.atlas_frame(source, FRAME_SIZE, frame)

func _make_flat_card_style(fill: Color, border: Color, border_width: int) -> StyleBoxFlat:
	return BattleSkinHelper.make_flat_card_style(fill, border, border_width)

func _make_type_tag_style(card: CardData) -> StyleBoxFlat:
	return BattleSkinHelper.make_type_tag_style(card.is_guard_card(), card.is_momentum_card())

func _make_card_art_style(card: CardData) -> StyleBoxFlat:
	return BattleSkinHelper.make_card_art_style(card.is_guard_card(), card.is_momentum_card())

func _make_momentum_dot_style(filled: bool) -> StyleBoxFlat:
	return BattleSkinHelper.make_momentum_dot_style(filled)
