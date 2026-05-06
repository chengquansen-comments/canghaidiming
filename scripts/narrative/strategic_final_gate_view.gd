extends RefCounted

# View helper for the legacy strategic-map final gate.
#
# This file only writes UI nodes and calls existing view helpers on the owner.
# It does not select bosses, mutate strategic_state, save context, or switch scenes.

const StrategicMapState := preload("res://scripts/strategic_map_state.gd")
const BACKGROUND_PATH := "res://assets/pixel_battle/backgrounds/battle_bg_broken_ship.png"
const TITLE_TEXT := "海门收束"
const SCENE_TEXT := "海门风紧，所有线索都被推到最后一战前。"
const DEFAULT_INTRO_TEXT := "倭患仍在海上。案卷仍少一页。"
const MAP_PLACEHOLDER := "终局版本由军功、清望、旧案、武境共同决定。"
const CHOICES_PLACEHOLDER := "终局战胜利后进入对应结局。"

var owner = null


func _init(owner_node) -> void:
	owner = owner_node


func render(boss: Dictionary, strategic_state: Dictionary, last_hint: String, final_boss_callback: Callable) -> void:
	if owner == null:
		return
	owner.title_label.text = TITLE_TEXT
	owner.status_label.text = str(boss.get("title", "终局门槛"))
	owner.map_label.text = "大势图已走完：%d 个节点" % [(strategic_state.get("selected_nodes", []) as Array).size()]
	owner.scene_label.text = owner._format_scene_text(SCENE_TEXT)
	owner._render_visual(BACKGROUND_PATH, TITLE_TEXT)
	owner.body_label.text = str(boss.get("intro_text", DEFAULT_INTRO_TEXT))
	if not last_hint.is_empty():
		owner.body_label.text += "\n\n[i]%s[/i]" % last_hint
	owner.vars_label.text = StrategicMapState.summary_text(strategic_state)
	owner._add_placeholder(owner.map_buttons_box, MAP_PLACEHOLDER)
	owner._add_button(owner.combat_buttons_box, "进入终局战：%s" % str(boss.get("title", TITLE_TEXT)), final_boss_callback)
	owner._add_placeholder(owner.choices_box, CHOICES_PLACEHOLDER)
