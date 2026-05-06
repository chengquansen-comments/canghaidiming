extends RefCounted

const BattleFontHelper := preload("res://scripts/visual/battle_font_view.gd")
const NarrativeBattleContext := preload("res://scripts/narrative_battle_context.gd")

var c

func _init(controller) -> void:
	c = controller

func consume_battle_result_if_needed() -> void:
	if not NarrativeBattleContext.has_result():
		return
	var source_id := NarrativeBattleContext.source_node_id
	var result := NarrativeBattleContext.last_result
	if source_id == c.PROLOGUE_MASTER_SOURCE_ID:
		c.in_prologue = true
		c.step_index = c.PROLOGUE_AFTER_MASTER_BATTLE_STEP
		if result == "win":
			c.clues += 1
			c.last_hint = "序章战斗胜利：师父斩敌，敌人临死吐出旧案线索。"
		else:
			c.last_hint = "序章战斗返回：当前 Demo 按师父救场继续推进。"
		NarrativeBattleContext.clear()
		c._save_narrative_state_to_context()
		return
	for i in range(c.NODES.size()):
		var node: Dictionary = c.NODES[i]
		if str(node.get("id", "")) == source_id:
			c.node_index = i
			c.in_prologue = false
			break
	if result == "win":
		apply_battle_result_reward(c.node_index)
		NarrativeBattleContext.apply_player_growth("battle_win", 0, 0, 0, true)
		if c.node_index < c.NODES.size() - 1:
			c.node_index += 1
		c.last_hint = "战斗胜利：已返回剧情，并自动推进到下一节点。武境 +1，HP / 轻功 / 势上限按武境刷新。"
	elif result == "lose":
		c.last_hint = "战斗失败：已返回剧情，当前 Demo 暂不惩罚，可选择视为胜利继续或重试。"
	elif result == "draw":
		c.last_hint = "战斗同归于尽：已返回剧情，当前 Demo 暂按线索保留处理。"
	else:
		c.last_hint = "战斗结果未知：已返回剧情。"
	NarrativeBattleContext.clear()
	c._save_narrative_state_to_context()

func apply_battle_result_reward(source_index: int) -> void:
	if source_index < 0 or source_index >= c.NODES.size():
		return
	var node: Dictionary = c.NODES[source_index]
	match str(node.get("type", "")):
		"普通战斗", "精英战斗":
			c.jun_gong += 1
			c.clues += 1
		"Boss":
			c.jun_gong += 2
			c.clues += 2
		_:
			c.jun_gong += 1
	c._save_narrative_state_to_context()

func on_map_node_pressed(target_index: int) -> void:
	if target_index == c.node_index:
		c.last_hint = "地图节点：当前节点。"
	elif target_index < c.node_index:
		c.last_hint = "地图节点：已走过。"
	elif target_index != c.node_index + 1:
		c.last_hint = "地图节点：未开放。"
	else:
		apply_default_map_reward(target_index)
		advance_to_node(target_index, "地图节点：可前往，已通过地图选路推进，并获得默认行军收益。")
		return
	c._render()

func apply_choice_delta(choice: Dictionary) -> void:
	c.jun_gong += int(choice.get("dg", 0))
	c.qing_wang += int(choice.get("dq", 0))
	c.clues += int(choice.get("dc", 0))
	NarrativeBattleContext.apply_player_growth("choice", 0, 0, 0, false)
	c._save_narrative_state_to_context()

func apply_default_map_reward(target_index: int) -> void:
	if target_index < 0 or target_index >= c.NODES.size():
		return
	var node: Dictionary = c.NODES[target_index]
	match str(node.get("type", "")):
		"普通战斗", "精英战斗":
			c.jun_gong += 1
			c.clues += 1
		"Boss":
			c.jun_gong += 2
			c.clues += 1
		"旧物":
			c.clues += 2
		_:
			c.qing_wang += 1
	c._save_narrative_state_to_context()

func advance_to_node(target_index: int, hint: String = "") -> void:
	c.last_hint = hint
	if target_index >= c.NODES.size():
		c._render_ending()
		return
	c.node_index = target_index
	c._save_narrative_state_to_context()
	c._render()

func on_continue_prologue() -> void:
	c.step_index += 1
	if c.step_index >= c.PROLOGUE.size():
		c.in_prologue = false
		c.node_index = 0
		c.last_hint = ""
	c._save_narrative_state_to_context()
	c._render()

func on_select_career(index: int) -> void:
	if index < 0 or index >= c.CAREERS.size():
		return
	var career: Dictionary = c.CAREERS[index]
	NarrativeBattleContext.set_player_profile({
		"role": str(career.get("id", "spearman")),
		"career": str(career.get("career", "长枪武官")),
		"weapon": str(career.get("weapon", "长枪")),
		"max_hp": int(career.get("max_hp", 36)),
		"hp": int(career.get("hp", career.get("max_hp", 36))),
		"max_posture": int(career.get("max_posture", 10)),
		"posture": int(career.get("posture", 5)),
		"martial_level": int(career.get("martial_level", 1)),
		"qinggong": int(career.get("qinggong", 1)),
		"battles_won": 0
	})
	c.career_selected = true
	c.in_prologue = false
	c.node_index = 0
	c.last_hint = "已选择出山职业：%s。玩家数据已初始化，后续战斗将沿用并成长。" % NarrativeBattleContext.player_profile_debug_text()
	c._save_narrative_state_to_context()
	c._render()

func on_request_prologue_master_battle() -> void:
	c._save_narrative_state_to_context()
	NarrativeBattleContext.set_request(c.PROLOGUE_MASTER_ENCOUNTER_ID, c.PROLOGUE_MASTER_SOURCE_ID, "", false)
	c.body_label.text = c.PROLOGUE[c.step_index] + "\n\n[b]序章战斗跳转[/b]\n师父救场战：玩家操控师父，用强力牌击败袭村刀手。\n%s\n即将进入 MainVisual。" % NarrativeBattleContext.debug_text()
	BattleFontHelper.enforce(c)
	c.call_deferred("_change_to_main_visual")

func on_skip_prologue_master_battle() -> void:
	c.step_index = c.PROLOGUE_AFTER_MASTER_BATTLE_STEP
	c.clues += 1
	c.last_hint = "已跳过师父救场战，按胜利继续序章。"
	c._save_narrative_state_to_context()
	c._render()

func on_request_battle() -> void:
	var node: Dictionary = c.NODES[c.node_index]
	var encounter_id := str(node.get("combat", ""))
	var source_node_id := str(node.get("id", ""))
	c._save_narrative_state_to_context()
	NarrativeBattleContext.set_request(encounter_id, source_node_id, "", true)
	c.body_label.text = c._node_body(node) + "\n\n[b]战斗跳转[/b]\n%s\n即将进入 MainVisual。" % NarrativeBattleContext.debug_text()
	BattleFontHelper.enforce(c)
	c.call_deferred("_change_to_main_visual")

func on_mock_battle_win() -> void:
	var node: Dictionary = c.NODES[c.node_index]
	c.body_label.text = c._node_body(node) + "\n\n[b]战斗占位胜利[/b]\n现在可选择战后处理。"
	BattleFontHelper.enforce(c)

func on_choice(index: int) -> void:
	var node: Dictionary = c.NODES[c.node_index]
	var choices: Array = node.get("choices", [])
	if index < 0 or index >= choices.size():
		return
	apply_choice_delta(choices[index])
	if c.node_index < c.NODES.size() - 1:
		advance_to_node(c.node_index + 1, "")
	else:
		c._render_ending()

func restart() -> void:
	c.step_index = 0
	c.node_index = 0
	c.jun_gong = 0
	c.qing_wang = 0
	c.clues = 0
	c.in_prologue = true
	c.career_selected = false
	c.last_hint = ""
	NarrativeBattleContext.clear()
	NarrativeBattleContext.clear_player_profile()
	c._clear_narrative_state_context()
	c._render()
