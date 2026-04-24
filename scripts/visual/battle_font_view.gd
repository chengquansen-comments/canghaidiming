extends RefCounted
class_name BattleFontHelper

const THEME_PATH := "res://themes/default_ui_theme.tres"
const FONT_PATH := "res://assets/fonts/cjk_font.ttf"

static var _theme_cache: Theme = null
static