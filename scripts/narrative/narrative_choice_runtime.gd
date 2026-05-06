extends RefCounted

var c

func _init(controller) -> void:
	c = controller

func on_continue_pressed() -> void:
	if c.showing_prologue:
		c._render_next_prologue_step()
	elif c.waiting_result:
		c.waiting_result = false
		if not c.narrative.current_ending_id.is_empty():
			c._render_ending()
		else:
			c._render_node()
	c._force_cjk_font()

func on_request_battle_pressed() -> void:
	var node := c.narrative.current_node()
	var payload := c.combat_bridge.request_battle(c.narrative.current_node_id, node)
	if payload.is_empty():
		c.result_label.text = "当前节点没有 combat 配置。"
	else:
		c.result_label.text = "已请求战斗：%s" % c._combat_payload_text(payload)
	c._force_cjk_font()

func on_mock_battle_win_pressed() -> void:
	if not c.combat_bridge.has_pending_battle():
		var node := c.narrative.current_node()
		c.combat_bridge.request_battle(c.narrative.current_node_id, node)
	var payload := c.combat_bridge.resolve_win({"source": "narrative_demo_mock"})
	c.result_label.text = "战斗占位胜利：%s。现在可选择战后处理。" % str(payload.get("encounter_id", ""))
	c._force_cjk_font()

func choice_button_text(choice: Dictionary) -> String:
	var text := str(choice.get("text", ""))
	var delta: Dictionary = choice.get("delta", {})
	var parts: Array[String] = []
	for key in delta.keys():
		var value := int(delta.get(key, 0))
		if value == 0:
			continue
		var sign := "+" if value > 0 else ""
		parts.append("%s%s%d" % [c.narrative.variable_short_label(str(key)), sign, value])
	if parts.is_empty():
		return text
	return "%s（%s）" % [text, " / ".join(parts)]

func on_choice_pressed(index: int) -> void:
	var result := c.narrative.choose(index)
	if not bool(result.get("ok", false)):
		c.result_label.text = str(result.get("result", "无效选择。"))
		c._force_cjk_font()
		return
	c._clear_choices()
	c.result_label.text = str(result.get("result", ""))
	c.vars_label.text = c.narrative.variables_text()
	c.route_label.text = c.narrative.route_text()
	c._render_map_strip()
	c.continue_button.visible = true
	c.waiting_result = true
	c._force_cjk_font()

func render_ending() -> void:
	c._clear_choices()
	var ending := c.narrative.current_ending()
	c.title_label.text = "结局：%s" % str(ending.get("title", "沉默"))
	c.type_label.text = "单局结算"
	c.route_label.text = c.narrative.route_text()
	c.body_label.text = str(ending.get("text", "潮声还在。"))
	c.result_label.text = c.narrative.last_result_text
	c.vars_label.text = c.narrative.variables_text()
	c.continue_button.visible = false
	c._render_combat_bridge({})
	c._set_art_placeholder("结局图占位：后续接入上报 / 掩盖 / 私查 / 借势四类结局图。")
	c._set_portrait_placeholder("结局人物占位")
	c._render_map_strip()
	c._force_cjk_font()
