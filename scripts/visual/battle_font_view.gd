extends RefCounted
class_name BattleFontHelper

const THEME_PATH := "res://themes/default_ui_theme.tres"
const FONT_PATH := "res://assets/fonts/cjk_font.ttf"

static var _theme_cache: Theme = null
static var _font_cache: Font = null

static func load_theme() -> Theme:
	if _theme_cache != null:
		return _theme_cache
	if ResourceLoader.exists(THEME_PATH):
		_theme_cache = load(THEME_PATH) as Theme
	return _theme_cache

static func load_font() -> Font:
	if _font_cache != null:
		return _font_cache
	if ResourceLoader.exists(FONT_PATH):
		_font_cache = load(FONT_PATH) as Font
	return _font_cache

static func enforce(root: Node) -> void:
	if root == null:
		return
	var theme: Theme = load_theme()
	var font: Font = load_font()
	if root is Control and theme != null:
		(root as Control).theme = theme
	_apply_font_recursive(root, font)

static func _apply_font_recursive(node: Node, font: Font) -> void:
	if node == null:
		return
	if font != null:
		_apply_font_to_node(node, font)
	for child in node.get_children():
		_apply_font_recursive(child, font)

static func _apply_font_to_node(node: Node, font: Font) -> void:
	if node is Label:
		var label := node as Label
		label.add_theme_font_override("font", font)
		return
	if node is RichTextLabel:
		var rich := node as RichTextLabel
		rich.add_theme_font_override("normal_font", font)
		rich.add_theme_font_override("bold_font", font)
		rich.add_theme_font_override("italics_font", font)
		rich.add_theme_font_override("bold_italics_font", font)
		return
	if node is Button:
		var button := node as Button
		button.add_theme_font_override("font", font)
		return
	if node is LineEdit:
		var line_edit := node as LineEdit
		line_edit.add_theme_font_override("font", font)
		return
	if node is TextEdit:
		var text_edit := node as TextEdit
		text_edit.add_theme_font_override("font", font)
		return
