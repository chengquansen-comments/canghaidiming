extends RefCounted
class_name NarrativeFontHelper

const BattleFontHelper := preload("res://scripts/visual/battle_font_view.gd")

static func enforce(root: Node) -> void:
	BattleFontHelper.enforce(root)

static func enforce_deferred(root: Node) -> void:
	if root == null:
		return
	root.call_deferred("_force_cjk_font")
