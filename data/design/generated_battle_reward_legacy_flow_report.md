# Battle Reward 旧流程定位报告

## 扫描范围

- scripts/
- data/
- scenes/

## 总览

- 候选总数：478
- 旧奖励数据源候选数：22
- 奖励生成函数候选数：8
- 战斗结算入口候选数：4
- 奖励展示入口候选数：4
- 奖励应用入口候选数：6
- 测试/调试入口候选数：40
- 高风险触点候选数：6
- 是否存在多个奖励来源：是

## 最小接入点建议

- `scripts/narrative_demo_canonical_controller.gd`::_battle_reward_for_source：可作为 shadow 对比基线。
- `scripts/narrative_demo_canonical_controller.gd`::_battle_reward_for_source：最小接入点候选：建议将 runtime/legacy 决策集中到该链路前。（seed）
- `scripts/narrative_demo_canonical_controller.gd`::_battle_reward_for_source：最小接入点候选：建议将 runtime/legacy 决策集中到该链路前。

## 候选明细

| 类型 | 文件 | 符号/行 | 关键词 | 角色判断 | 置信度 | 风险 | 建议动作 |
|---|---|---|---|---|---|---|---|
| high_risk_touchpoint | data/story_battles/story_encounters.tsv | line:1 | settlement | 不建议直接修改的高风险文件触点 | high | high | 保持只读，避免在 v1.0a 修改该文件。 |
| high_risk_touchpoint | scenes/MainVisual.tscn | line:13 | settlement | 不建议直接修改的高风险文件触点 | high | high | 保持只读，避免在 v1.0a 修改该文件。 |
| high_risk_touchpoint | scripts/battle_state_machine.gd | set_settlement_mode | settlement | 不建议直接修改的高风险文件触点 | high | high | 保持只读，避免在 v1.0a 修改该文件。 |
| high_risk_touchpoint | scripts/battle_state_machine.gd | set_settlement_mode_id | settlement | 不建议直接修改的高风险文件触点 | high | high | 保持只读，避免在 v1.0a 修改该文件。 |
| high_risk_touchpoint | scripts/battle_state_machine.gd | settlement_mode | settlement | 不建议直接修改的高风险文件触点 | high | high | 保持只读，避免在 v1.0a 修改该文件。 |
| high_risk_touchpoint | scripts/battle_state_machine.gd | settlement_mode_id | settlement | 不建议直接修改的高风险文件触点 | high | high | 保持只读，避免在 v1.0a 修改该文件。 |
| legacy_reward_source | data/enemy_manifest.json | line:1090 | reward | 可能是旧奖励数据源 | high | medium | 纳入 adapter 的 legacy 读取分支，不直接改写原源数据。 |
| legacy_reward_source | data/enemy_manifest.json | line:226 | reward | 可能是旧奖励数据源 | high | medium | 纳入 adapter 的 legacy 读取分支，不直接改写原源数据。 |
| legacy_reward_source | data/enemy_manifest.json | line:364 | reward | 可能是旧奖励数据源 | high | medium | 纳入 adapter 的 legacy 读取分支，不直接改写原源数据。 |
| legacy_reward_source | data/enemy_manifest.json | line:4 | reward | 可能是旧奖励数据源 | high | medium | 纳入 adapter 的 legacy 读取分支，不直接改写原源数据。 |
| legacy_reward_source | data/enemy_manifest.json | line:505 | reward | 可能是旧奖励数据源 | high | medium | 纳入 adapter 的 legacy 读取分支，不直接改写原源数据。 |
| legacy_reward_source | data/enemy_manifest.json | line:660 | reward | 可能是旧奖励数据源 | high | medium | 纳入 adapter 的 legacy 读取分支，不直接改写原源数据。 |
| legacy_reward_source | data/enemy_manifest.json | line:800 | reward | 可能是旧奖励数据源 | high | medium | 纳入 adapter 的 legacy 读取分支，不直接改写原源数据。 |
| legacy_reward_source | data/enemy_manifest.json | line:961 | reward | 可能是旧奖励数据源 | high | medium | 纳入 adapter 的 legacy 读取分支，不直接改写原源数据。 |
| legacy_reward_source | data/rewards.json | line:1 | reward | 可能是旧奖励数据源 | high | medium | 纳入 adapter 的 legacy 读取分支，不直接改写原源数据。 |
| legacy_reward_source | data/story_battles.json | line:577 | settlement | 可能是旧奖励数据源 | high | medium | 纳入 adapter 的 legacy 读取分支，不直接改写原源数据。 |
| legacy_reward_source | data/story_battles.json | line:591 | settlement | 可能是旧奖励数据源 | high | medium | 纳入 adapter 的 legacy 读取分支，不直接改写原源数据。 |
| legacy_reward_source | data/story_battles.json | line:605 | settlement | 可能是旧奖励数据源 | high | medium | 纳入 adapter 的 legacy 读取分支，不直接改写原源数据。 |
| legacy_reward_source | data/story_battles.json | line:619 | settlement | 可能是旧奖励数据源 | high | medium | 纳入 adapter 的 legacy 读取分支，不直接改写原源数据。 |
| legacy_reward_source | data/story_battles.json | line:633 | settlement | 可能是旧奖励数据源 | high | medium | 纳入 adapter 的 legacy 读取分支，不直接改写原源数据。 |
| legacy_reward_source | data/story_battles.json | line:647 | settlement | 可能是旧奖励数据源 | high | medium | 纳入 adapter 的 legacy 读取分支，不直接改写原源数据。 |
| legacy_reward_source | data/story_battles.json | line:661 | settlement | 可能是旧奖励数据源 | high | medium | 纳入 adapter 的 legacy 读取分支，不直接改写原源数据。 |
| legacy_reward_source | data/story_battles.json | line:675 | settlement | 可能是旧奖励数据源 | high | medium | 纳入 adapter 的 legacy 读取分支，不直接改写原源数据。 |
| legacy_reward_source | scripts/Main_data.gd | _load_game_data | reward | 可能是旧奖励数据源 | medium | medium | 纳入 adapter 的 legacy 读取分支，不直接改写原源数据。 |
| legacy_reward_source | scripts/narrative/focus_ui_runtime.gd | _battle_growth_reward_for_source | reward | 可能是旧奖励数据源 | medium | medium | 纳入 adapter 的 legacy 读取分支，不直接改写原源数据。 |
| legacy_reward_source | scripts/narrative_demo_canonical_controller.gd | _battle_reward_for_source | reward | 可能是旧奖励数据源 | medium | medium | 纳入 adapter 的 legacy 读取分支，不直接改写原源数据。 |
| legacy_reward_source | scripts/narrative_demo_choice_combat_controller.gd | _battle_growth_reward_for_source | reward | 可能是旧奖励数据源 | medium | medium | 纳入 adapter 的 legacy 读取分支，不直接改写原源数据。 |
| legacy_reward_source | scripts/narrative_demo_formal_controller.gd | _apply_battle_result_reward | reward | 可能是旧奖励数据源 | medium | medium | 纳入 adapter 的 legacy 读取分支，不直接改写原源数据。 |
| battle_settlement_entry | scripts/battle_controller_core_round_resolution.gd | _finish_battle | battle_end | 可能是战斗结束结算入口 | high | medium | 避免直接改动结算主流程，在外层增加可控接入点。 |
| battle_settlement_entry | scripts/narrative/focus_ui_runtime.gd | _consume_battle_result_if_needed | 结算 | 可能是战斗结束结算入口 | high | medium | 避免直接改动结算主流程，在外层增加可控接入点。 |
| battle_settlement_entry | scripts/narrative_battle_context.gd | set_result | result | 可能是战斗结束结算入口 | high | medium | 避免直接改动结算主流程，在外层增加可控接入点。 |
| battle_settlement_entry | scripts/narrative_demo_choice_combat_controller.gd | _consume_battle_result_if_needed | 结算 | 可能是战斗结束结算入口 | high | medium | 避免直接改动结算主流程，在外层增加可控接入点。 |
| reward_generation_function | scripts/battle_controller_core_session_rewards.gd | _sample_rewards | reward | 可能是奖励生成逻辑 | medium | medium | 后续由单一 adapter 接管奖励生成输入，函数保持调用层稳定。 |
| reward_generation_function | scripts/battle_controller_core_session_rewards.gd | _sample_rewards | rewards | 可能是奖励生成逻辑 | medium | medium | 后续由单一 adapter 接管奖励生成输入，函数保持调用层稳定。 |
| reward_generation_function | scripts/narrative/canonical_battle_reward_runtime.gd | reward_from_context_or_node | reward | 可能是奖励生成逻辑 | medium | medium | 后续由单一 adapter 接管奖励生成输入，函数保持调用层稳定。 |
| reward_generation_function | scripts/narrative/focus_ui_runtime.gd | _battle_growth_reward_for_source | reward | 可能是奖励生成逻辑 | medium | medium | 后续由单一 adapter 接管奖励生成输入，函数保持调用层稳定。 |
| reward_generation_function | scripts/narrative_demo_canonical_controller.gd | _battle_reward_for_source | battle_reward | 可能是奖励生成逻辑 | high | medium | 后续由单一 adapter 接管奖励生成输入，函数保持调用层稳定。 |
| reward_generation_function | scripts/narrative_demo_canonical_controller.gd | _battle_reward_for_source | reward | 可能是奖励生成逻辑 | high | medium | 后续由单一 adapter 接管奖励生成输入，函数保持调用层稳定。 |
| reward_generation_function | scripts/narrative_demo_choice_combat_controller.gd | _battle_growth_reward_for_source | reward | 可能是奖励生成逻辑 | medium | medium | 后续由单一 adapter 接管奖励生成输入，函数保持调用层稳定。 |
| reward_generation_function | scripts/narrative_demo_ui_focus_controller.gd | _battle_growth_reward_for_source | reward | 可能是奖励生成逻辑 | medium | medium | 后续由单一 adapter 接管奖励生成输入，函数保持调用层稳定。 |
| reward_apply_entry | scripts/battle_controller_core_session_rewards.gd | _pick_reward_card | reward | 可能是奖励写入玩家状态逻辑 | high | medium | adapter 输出标准奖励结构后，通过单一应用入口落地。 |
| reward_apply_entry | scripts/battle_controller_core_session_rewards.gd | _pick_reward_card | 获得 | 可能是奖励写入玩家状态逻辑 | high | medium | adapter 输出标准奖励结构后，通过单一应用入口落地。 |
| reward_apply_entry | scripts/narrative_battle_context.gd | apply_player_growth | reward | 可能是奖励写入玩家状态逻辑 | high | medium | adapter 输出标准奖励结构后，通过单一应用入口落地。 |
| reward_apply_entry | scripts/narrative_battle_context.gd | grant_player_cards | reward | 可能是奖励写入玩家状态逻辑 | high | medium | adapter 输出标准奖励结构后，通过单一应用入口落地。 |
| reward_apply_entry | scripts/narrative_demo_formal_controller.gd | _apply_battle_result_reward | reward | 可能是奖励写入玩家状态逻辑 | high | medium | adapter 输出标准奖励结构后，通过单一应用入口落地。 |
| reward_apply_entry | scripts/narrative_demo_safe_controller.gd | _apply_battle_result_reward | reward | 可能是奖励写入玩家状态逻辑 | high | medium | adapter 输出标准奖励结构后，通过单一应用入口落地。 |
| reward_display_entry | scripts/battle_controller_core_session_rewards.gd | _open_gain_move | gain | 可能是奖励展示逻辑 | high | medium | 保持 UI 展示层不感知 runtime 细节，只接收统一奖励结果。 |
| reward_display_entry | scripts/battle_controller_core_session_rewards.gd | _open_gain_move | reward | 可能是奖励展示逻辑 | high | medium | 保持 UI 展示层不感知 runtime 细节，只接收统一奖励结果。 |
| reward_display_entry | scripts/battle_controller_core_session_rewards.gd | _open_gain_move | rewards | 可能是奖励展示逻辑 | high | medium | 保持 UI 展示层不感知 runtime 细节，只接收统一奖励结果。 |
| reward_display_entry | scripts/battle_controller_visual_story_return.gd | _show_battle_result_overlay | result | 可能是奖励展示逻辑 | high | medium | 保持 UI 展示层不感知 runtime 细节，只接收统一奖励结果。 |
| debug_or_test_entry | scripts/Main_combat.gd | _begin_player_turn | 获得 | 可能是测试战斗或 debug 入口 | medium | low | runtime_test 模式仅允许从这类入口显式启用。 |
| debug_or_test_entry | scripts/Main_combat.gd | _effect_guard | 获得 | 可能是测试战斗或 debug 入口 | medium | low | runtime_test 模式仅允许从这类入口显式启用。 |
| debug_or_test_entry | scripts/Main_combat.gd | _enemy_phase | 获得 | 可能是测试战斗或 debug 入口 | medium | low | runtime_test 模式仅允许从这类入口显式启用。 |
| debug_or_test_entry | scripts/Main_combat.gd | _on_card_pressed | reward | 可能是测试战斗或 debug 入口 | medium | low | runtime_test 模式仅允许从这类入口显式启用。 |
| debug_or_test_entry | scripts/Main_combat.gd | _on_end_turn_pressed | reward | 可能是测试战斗或 debug 入口 | medium | low | runtime_test 模式仅允许从这类入口显式启用。 |
| debug_or_test_entry | scripts/Main_combat.gd | _reward_text | reward | 可能是测试战斗或 debug 入口 | medium | low | runtime_test 模式仅允许从这类入口显式启用。 |
| debug_or_test_entry | scripts/Main_combat.gd | _start_battle | reward | 可能是测试战斗或 debug 入口 | medium | low | runtime_test 模式仅允许从这类入口显式启用。 |
| debug_or_test_entry | scripts/Main_data.gd | _validate_game_data | reward | 可能是测试战斗或 debug 入口 | medium | low | runtime_test 模式仅允许从这类入口显式启用。 |
| debug_or_test_entry | scripts/Main_foundation.gd | line:12 | rewards | 可能是测试战斗或 debug 入口 | medium | low | runtime_test 模式仅允许从这类入口显式启用。 |
| debug_or_test_entry | scripts/Main_foundation.gd | reward_options | reward | 可能是测试战斗或 debug 入口 | medium | low | runtime_test 模式仅允许从这类入口显式启用。 |
| debug_or_test_entry | scripts/Main_foundation.gd | reward_pending | reward | 可能是测试战斗或 debug 入口 | medium | low | runtime_test 模式仅允许从这类入口显式启用。 |
| debug_or_test_entry | scripts/Main_foundation.gd | reward_pool | reward | 可能是测试战斗或 debug 入口 | medium | low | runtime_test 模式仅允许从这类入口显式启用。 |
| debug_or_test_entry | scripts/Main_route.gd | _apply_order_choice | reward | 可能是测试战斗或 debug 入口 | medium | low | runtime_test 模式仅允许从这类入口显式启用。 |
| debug_or_test_entry | scripts/Main_route.gd | _resolve_school_node | reward | 可能是测试战斗或 debug 入口 | medium | low | runtime_test 模式仅允许从这类入口显式启用。 |
| debug_or_test_entry | scripts/Main_route.gd | _show_class_select | reward | 可能是测试战斗或 debug 入口 | medium | low | runtime_test 模式仅允许从这类入口显式启用。 |
| debug_or_test_entry | scripts/Main_runtime.gd | _on_next_pressed | reward | 可能是测试战斗或 debug 入口 | medium | low | runtime_test 模式仅允许从这类入口显式启用。 |
| debug_or_test_entry | scripts/Main_ui.gd | _intent_status_text | 获得 | 可能是测试战斗或 debug 入口 | medium | low | runtime_test 模式仅允许从这类入口显式启用。 |
| debug_or_test_entry | scripts/Main_ui.gd | _refresh_hand_buttons | reward | 可能是测试战斗或 debug 入口 | medium | low | runtime_test 模式仅允许从这类入口显式启用。 |
| debug_or_test_entry | scripts/battle_controller_visual_narrative_context_result.gd | _on_continue_narrative_pressed | result | 可能是测试战斗或 debug 入口 | medium | low | runtime_test 模式仅允许从这类入口显式启用。 |
| debug_or_test_entry | scripts/battle_controller_visual_narrative_context_result.gd | _update_battle_result_debug | result | 可能是测试战斗或 debug 入口 | medium | low | runtime_test 模式仅允许从这类入口显式启用。 |
| debug_or_test_entry | scripts/narrative_battle_context.gd | consume_debug_entry | clear | 可能是测试战斗或 debug 入口 | medium | low | runtime_test 模式仅允许从这类入口显式启用。 |
| debug_or_test_entry | scripts/narrative_demo_canonical_controller.gd | CanonicalBattleRewardRuntime | reward | 可能是测试战斗或 debug 入口 | medium | low | runtime_test 模式仅允许从这类入口显式启用。 |
| debug_or_test_entry | scripts/narrative_demo_choice_combat_controller.gd | _apply_battle_growth | reward | 可能是测试战斗或 debug 入口 | medium | low | runtime_test 模式仅允许从这类入口显式启用。 |
| debug_or_test_entry | scripts/narrative_demo_fragmented_controller.gd | _render_ending | 结算 | 可能是测试战斗或 debug 入口 | medium | low | runtime_test 模式仅允许从这类入口显式启用。 |
| debug_or_test_entry | scripts/narrative_demo_safe_controller.gd | _apply_default_map_reward | reward | 可能是测试战斗或 debug 入口 | medium | low | runtime_test 模式仅允许从这类入口显式启用。 |
| debug_or_test_entry | scripts/narrative_demo_ui_focus_controller.gd | _ensure_ending_settlement_popup | settlement | 可能是测试战斗或 debug 入口 | medium | low | runtime_test 模式仅允许从这类入口显式启用。 |
| debug_or_test_entry | scripts/narrative_demo_ui_focus_controller.gd | _render_ending | settlement | 可能是测试战斗或 debug 入口 | medium | low | runtime_test 模式仅允许从这类入口显式启用。 |
| debug_or_test_entry | scripts/narrative_demo_ui_focus_controller.gd | ending_settlement_confirm | settlement | 可能是测试战斗或 debug 入口 | medium | low | runtime_test 模式仅允许从这类入口显式启用。 |
| debug_or_test_entry | scripts/narrative_demo_ui_focus_controller.gd | ending_settlement_layer | settlement | 可能是测试战斗或 debug 入口 | medium | low | runtime_test 模式仅允许从这类入口显式启用。 |
| debug_or_test_entry | scripts/narrative_demo_ui_focus_controller.gd | ending_settlement_panel | settlement | 可能是测试战斗或 debug 入口 | medium | low | runtime_test 模式仅允许从这类入口显式启用。 |
| debug_or_test_entry | scripts/narrative_demo_ui_focus_controller.gd | ending_settlement_text | settlement | 可能是测试战斗或 debug 入口 | medium | low | runtime_test 模式仅允许从这类入口显式启用。 |
| debug_or_test_entry | scripts/narrative_demo_ui_focus_tuned_controller.gd | StrategicRewardRuntime | reward | 可能是测试战斗或 debug 入口 | medium | low | runtime_test 模式仅允许从这类入口显式启用。 |
| debug_or_test_entry | scripts/narrative_demo_ui_focus_tuned_controller.gd | _reward_runtime | reward | 可能是测试战斗或 debug 入口 | medium | low | runtime_test 模式仅允许从这类入口显式启用。 |
| debug_or_test_entry | scripts/narrative_demo_ui_focus_tuned_controller.gd | _strategic_reward_runtime | reward | 可能是测试战斗或 debug 入口 | medium | low | runtime_test 模式仅允许从这类入口显式启用。 |
| debug_or_test_entry | scripts/narrative_demo_ui_focus_tuned_controller.gd | line:6 | reward | 可能是测试战斗或 debug 入口 | medium | low | runtime_test 模式仅允许从这类入口显式启用。 |
| debug_or_test_entry | scripts/narrative_demo_ui_focus_tuned_controller.gd | selected_strategic_card_reward | reward | 可能是测试战斗或 debug 入口 | medium | low | runtime_test 模式仅允许从这类入口显式启用。 |
| debug_or_test_entry | scripts/safe_demo_runtime.gd | consume_battle_result_if_needed | clear | 可能是测试战斗或 debug 入口 | medium | low | runtime_test 模式仅允许从这类入口显式启用。 |
| debug_or_test_entry | scripts/safe_demo_runtime.gd | consume_battle_result_if_needed | result | 可能是测试战斗或 debug 入口 | medium | low | runtime_test 模式仅允许从这类入口显式启用。 |
| debug_or_test_entry | scripts/safe_demo_runtime.gd | consume_battle_result_if_needed | reward | 可能是测试战斗或 debug 入口 | medium | low | runtime_test 模式仅允许从这类入口显式启用。 |
| debug_or_test_entry | scripts/safe_demo_view.gd | render_ending | 结算 | 可能是测试战斗或 debug 入口 | medium | low | runtime_test 模式仅允许从这类入口显式启用。 |
| unknown_candidate | data/cards.json | line:106 | 获得 | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/cards.json | line:140 | 获得 | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/cards.json | line:194 | 获得 | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/cards.json | line:210 | 获得 | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/cards.json | line:6 | 获得 | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/generated_battle_reward_legacy_flow_report.md | line:1 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/generated_battle_reward_legacy_flow_report.md | line:12 | 奖励 | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/generated_battle_reward_legacy_flow_report.md | line:13 | 奖励 | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/generated_battle_reward_legacy_flow_report.md | line:14 | 战斗结算 | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/generated_battle_reward_legacy_flow_report.md | line:15 | 奖励 | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/generated_battle_reward_legacy_flow_report.md | line:16 | 奖励 | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/generated_battle_reward_legacy_flow_report.md | line:19 | 奖励 | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/generated_battle_reward_legacy_flow_report.md | line:23 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/generated_battle_reward_legacy_flow_report.tsv | line:2 | settlement | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/generated_battle_reward_legacy_flow_report.tsv | line:3 | settlement | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/generated_battle_reward_legacy_flow_report.tsv | line:4 | settlement | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/generated_battle_reward_legacy_flow_report.tsv | line:5 | settlement | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/generated_battle_reward_legacy_flow_report.tsv | line:6 | settlement | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/generated_battle_reward_legacy_flow_report.tsv | line:7 | settlement | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/generated_battle_reward_legacy_flow_report.tsv | line:8 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/generated_battle_reward_legacy_flow_report.tsv | line:9 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/generated_battle_reward_plan.tsv | line:1 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/generated_battle_reward_plan.tsv | line:2 | 奖励 | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/generated_battle_reward_plan.tsv | line:3 | 奖励 | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/generated_battle_reward_plan.tsv | line:4 | 奖励 | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/generated_battle_reward_plan.tsv | line:6 | 奖励 | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/generated_battle_reward_plan.tsv | line:7 | 奖励 | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/generated_battle_reward_plan.tsv | line:8 | 奖励 | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/generated_battle_reward_plan.tsv | line:9 | 奖励 | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/generated_battle_reward_readonly_integration_probe_report.md | line:1 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/generated_battle_reward_readonly_integration_probe_report.md | line:26 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/generated_battle_reward_readonly_integration_probe_report.md | line:3 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/generated_battle_reward_readonly_integration_probe_report.tsv | line:2 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/generated_battle_reward_runtime_adapter_scaffold_report.md | line:1 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/generated_battle_reward_runtime_adapter_scaffold_report.md | line:19 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/generated_battle_reward_runtime_adapter_scaffold_report.md | line:25 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/generated_battle_reward_runtime_adapter_scaffold_report.md | line:8 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/generated_battle_reward_runtime_adapter_scaffold_report.md | line:9 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/generated_battle_reward_runtime_adapter_scaffold_report.tsv | line:1 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/generated_battle_reward_runtime_adapter_scaffold_report.tsv | line:2 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/generated_battle_reward_shadow_integration_plan_report.md | line:1 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/generated_battle_reward_shadow_integration_plan_report.md | line:12 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/generated_battle_reward_shadow_integration_plan_report.md | line:13 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/generated_battle_reward_shadow_integration_plan_report.md | line:14 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/generated_battle_reward_shadow_integration_plan_report.md | line:15 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/generated_battle_reward_shadow_integration_plan_report.md | line:19 | 奖励 | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/generated_battle_reward_shadow_integration_plan_report.md | line:21 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/generated_battle_reward_shadow_integration_plan_report.md | line:27 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/generated_battle_reward_shadow_integration_plan_report.tsv | line:12 | 奖励 | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/generated_battle_reward_shadow_integration_plan_report.tsv | line:14 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/generated_battle_reward_shadow_integration_plan_report.tsv | line:20 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/generated_battle_reward_shadow_integration_plan_report.tsv | line:21 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/generated_battle_reward_shadow_integration_plan_report.tsv | line:5 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/generated_battle_reward_shadow_integration_plan_report.tsv | line:6 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/generated_battle_reward_shadow_integration_plan_report.tsv | line:7 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/generated_battle_reward_shadow_integration_plan_report.tsv | line:8 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/generated_content_engine_lite_check_report.md | line:21 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/generated_content_engine_lite_check_report.md | line:24 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/generated_content_engine_lite_check_report.md | line:25 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/generated_content_engine_lite_check_report.md | line:26 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/generated_content_engine_lite_check_report.md | line:27 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/generated_content_engine_lite_check_report.md | line:4 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/generated_content_engine_lite_check_report.md | line:5 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/generated_content_engine_lite_check_report.md | line:6 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/generated_content_engine_lite_check_report.tsv | line:2 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/generated_content_engine_lite_check_report.tsv | line:5 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/generated_content_engine_lite_check_report.tsv | line:6 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/generated_content_engine_lite_check_report.tsv | line:7 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/generated_content_engine_lite_check_report.tsv | line:8 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/generated_content_engine_regression_report.tsv | line:2 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/generated_content_engine_regression_report.tsv | line:43 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/generated_content_engine_regression_report.tsv | line:44 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/generated_content_engine_regression_report.tsv | line:45 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/generated_content_engine_regression_report.tsv | line:46 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/generated_content_engine_regression_report.tsv | line:58 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/generated_content_engine_regression_report.tsv | line:64 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/generated_content_engine_regression_report.tsv | line:70 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/generated_content_package_approval.tsv | line:11 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/generated_content_package_approval_report.md | line:33 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/generated_content_package_manifest.tsv | line:11 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/generated_content_package_manifest.tsv | line:12 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/generated_content_package_manifest.tsv | line:13 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/generated_content_package_manifest.tsv | line:14 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/generated_content_package_report.md | line:112 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/generated_content_package_report.md | line:30 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/generated_content_package_report.md | line:55 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/generated_content_package_report.md | line:58 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/generated_content_package_report.md | line:60 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/generated_content_package_report.md | line:62 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/generated_content_package_report.md | line:95 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/generated_enemy_deck_skeleton.tsv | line:1 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/generated_narrative_node_plan.tsv | line:1 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/generated_narrative_node_plan.tsv | line:12 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/generated_narrative_node_plan.tsv | line:13 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/generated_narrative_node_plan.tsv | line:14 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/generated_narrative_node_plan.tsv | line:15 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/generated_narrative_node_plan.tsv | line:16 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/generated_narrative_node_plan.tsv | line:17 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/generated_narrative_node_plan.tsv | line:18 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/generated_operation_node_plan.tsv | line:1 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/generated_route_gate_plan.tsv | line:1 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/generated_route_progression_curve.tsv | line:9 | 获得 | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/generated_runtime_battle_reward_compare_report.md | line:1 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/generated_runtime_battle_reward_compare_report.md | line:15 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/generated_runtime_battle_reward_compare_report.md | line:3 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/generated_runtime_battle_reward_compare_report.md | line:4 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/generated_runtime_battle_reward_compare_report.tsv | line:2 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/generated_runtime_battle_reward_godot_compare_report.md | line:1 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/generated_runtime_battle_reward_godot_compare_report.md | line:15 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/generated_runtime_battle_reward_godot_compare_report.md | line:29 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/generated_runtime_battle_reward_godot_compare_report.md | line:3 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/generated_runtime_battle_reward_godot_compare_report.md | line:4 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/generated_runtime_battle_reward_godot_compare_report.tsv | line:2 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/generated_runtime_battle_reward_hydration_report.md | line:1 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/generated_runtime_battle_reward_hydration_report.md | line:10 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/generated_runtime_battle_reward_hydration_report.md | line:11 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/generated_runtime_battle_reward_hydration_report.md | line:35 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/generated_runtime_battle_reward_hydration_report.md | line:5 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/generated_runtime_battle_reward_hydration_report.md | line:6 | 奖励 | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/generated_runtime_battle_reward_hydration_report.tsv | line:2 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/generated_runtime_export_approval_overlay.md | line:16 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/generated_runtime_export_approval_overlay.md | line:27 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/generated_runtime_export_approval_overlay.tsv | line:4 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/generated_runtime_export_approval_overlay.tsv | line:5 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/generated_runtime_export_diff_report.md | line:16 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/generated_runtime_export_diff_report.md | line:27 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/generated_runtime_export_diff_report.tsv | line:4 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/generated_runtime_export_diff_report.tsv | line:5 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/generated_runtime_export_dry_run.md | line:15 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/generated_runtime_export_dry_run.md | line:31 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/generated_runtime_export_dry_run.tsv | line:4 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/generated_runtime_export_dry_run.tsv | line:5 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/generated_runtime_export_manifest_report.md | line:11 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/generated_runtime_export_manifest_report.tsv | line:2 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/generated_runtime_export_rollback_report.md | line:12 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/generated_runtime_export_rollback_report.md | line:5 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/generated_runtime_exporter_plan.md | line:19 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/generated_runtime_exporter_plan.md | line:29 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/generated_runtime_exporter_plan.tsv | line:4 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/generated_runtime_exporter_plan.tsv | line:5 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/generated_runtime_exporter_write_result.md | line:15 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/generated_runtime_exporter_write_result.tsv | line:4 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/generated_runtime_exporter_write_result.tsv | line:5 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/generated_runtime_loader_godot_probe_report.md | line:6 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/generated_runtime_loader_godot_probe_report.tsv | line:2 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/generated_runtime_loader_preflight_report.md | line:12 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/generated_runtime_loader_preflight_report.tsv | line:2 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/generated_runtime_loader_scaffold_report.tsv | line:2 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/generated_runtime_schema_proposal.md | line:14 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/generated_runtime_schema_proposal.tsv | line:12 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/generated_runtime_schema_proposal.tsv | line:13 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/generated_runtime_schema_proposal.tsv | line:14 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/generated_runtime_schema_proposal.tsv | line:15 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/generated_runtime_schema_proposal.tsv | line:16 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/generated_runtime_schema_proposal.tsv | line:17 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/generated_runtime_schema_proposal.tsv | line:18 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/generated_runtime_schema_proposal.tsv | line:19 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/generated_validator_summary.md | line:19 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/generated_validator_summary.tsv | line:7 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/progression_numeric_config_v1_3.tsv | line:32 | 奖励 | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/progression_numeric_config_v1_3.tsv | line:61 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/progression_numeric_config_v1_3.tsv | line:62 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/progression_numeric_config_v1_3.tsv | line:63 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/progression_numeric_config_v1_3.tsv | line:64 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/progression_numeric_config_v1_3.tsv | line:65 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/progression_numeric_config_v1_3.tsv | line:66 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/progression_numeric_config_v1_3.tsv | line:9 | 获得 | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/runtime_export_approval.tsv | line:6 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/runtime_loader_negative_fixtures/checksum_mismatch/battle_reward.json | line:2 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/runtime_loader_negative_fixtures/checksum_mismatch/battle_reward.json | line:3 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/runtime_loader_negative_fixtures/checksum_mismatch/battle_reward.json | line:5 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/runtime_loader_negative_fixtures/checksum_mismatch/runtime_manifest.json | line:13 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/runtime_loader_negative_fixtures/checksum_mismatch/runtime_manifest.json | line:14 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/runtime_loader_negative_fixtures/checksum_mismatch/runtime_manifest.json | line:15 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/runtime_loader_negative_fixtures/checksum_mismatch/runtime_manifest.json | line:16 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/runtime_loader_negative_fixtures/checksum_mismatch/runtime_manifest.json | line:25 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/runtime_loader_negative_fixtures/checksum_mismatch/runtime_manifest.json | line:8 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/runtime_loader_negative_fixtures/content_fingerprint_mismatch/battle_reward.json | line:2 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/runtime_loader_negative_fixtures/content_fingerprint_mismatch/battle_reward.json | line:3 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/runtime_loader_negative_fixtures/content_fingerprint_mismatch/battle_reward.json | line:5 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/runtime_loader_negative_fixtures/content_fingerprint_mismatch/runtime_manifest.json | line:13 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/runtime_loader_negative_fixtures/content_fingerprint_mismatch/runtime_manifest.json | line:14 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/runtime_loader_negative_fixtures/content_fingerprint_mismatch/runtime_manifest.json | line:15 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/runtime_loader_negative_fixtures/content_fingerprint_mismatch/runtime_manifest.json | line:16 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/runtime_loader_negative_fixtures/content_fingerprint_mismatch/runtime_manifest.json | line:25 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/runtime_loader_negative_fixtures/content_fingerprint_mismatch/runtime_manifest.json | line:8 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/runtime_loader_negative_fixtures/domain_mismatch/battle_reward.json | line:2 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/runtime_loader_negative_fixtures/domain_mismatch/battle_reward.json | line:3 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/runtime_loader_negative_fixtures/domain_mismatch/battle_reward.json | line:5 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/runtime_loader_negative_fixtures/domain_mismatch/runtime_manifest.json | line:13 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/runtime_loader_negative_fixtures/domain_mismatch/runtime_manifest.json | line:14 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/runtime_loader_negative_fixtures/domain_mismatch/runtime_manifest.json | line:15 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/runtime_loader_negative_fixtures/domain_mismatch/runtime_manifest.json | line:16 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/runtime_loader_negative_fixtures/domain_mismatch/runtime_manifest.json | line:25 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/runtime_loader_negative_fixtures/domain_mismatch/runtime_manifest.json | line:8 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/runtime_loader_negative_fixtures/extra_runtime_file_present/battle_reward.json | line:2 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/runtime_loader_negative_fixtures/extra_runtime_file_present/battle_reward.json | line:3 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/runtime_loader_negative_fixtures/extra_runtime_file_present/battle_reward.json | line:5 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/runtime_loader_negative_fixtures/extra_runtime_file_present/runtime_manifest.json | line:13 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/runtime_loader_negative_fixtures/extra_runtime_file_present/runtime_manifest.json | line:14 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/runtime_loader_negative_fixtures/extra_runtime_file_present/runtime_manifest.json | line:15 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/runtime_loader_negative_fixtures/extra_runtime_file_present/runtime_manifest.json | line:16 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/runtime_loader_negative_fixtures/extra_runtime_file_present/runtime_manifest.json | line:25 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/runtime_loader_negative_fixtures/extra_runtime_file_present/runtime_manifest.json | line:8 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/runtime_loader_negative_fixtures/field_count_mismatch/battle_reward.json | line:2 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/runtime_loader_negative_fixtures/field_count_mismatch/battle_reward.json | line:3 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/runtime_loader_negative_fixtures/field_count_mismatch/battle_reward.json | line:5 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/runtime_loader_negative_fixtures/field_count_mismatch/runtime_manifest.json | line:13 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/runtime_loader_negative_fixtures/field_count_mismatch/runtime_manifest.json | line:14 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/runtime_loader_negative_fixtures/field_count_mismatch/runtime_manifest.json | line:15 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/runtime_loader_negative_fixtures/field_count_mismatch/runtime_manifest.json | line:16 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/runtime_loader_negative_fixtures/field_count_mismatch/runtime_manifest.json | line:25 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/runtime_loader_negative_fixtures/field_count_mismatch/runtime_manifest.json | line:8 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/runtime_loader_negative_fixtures/fixture_manifest.json | line:6 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/runtime_loader_negative_fixtures/malformed_runtime_json/battle_reward.json | line:2 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/runtime_loader_negative_fixtures/malformed_runtime_json/battle_reward.json | line:3 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/runtime_loader_negative_fixtures/malformed_runtime_json/battle_reward.json | line:5 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/runtime_loader_negative_fixtures/malformed_runtime_json/runtime_manifest.json | line:13 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/runtime_loader_negative_fixtures/malformed_runtime_json/runtime_manifest.json | line:14 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/runtime_loader_negative_fixtures/malformed_runtime_json/runtime_manifest.json | line:15 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/runtime_loader_negative_fixtures/malformed_runtime_json/runtime_manifest.json | line:16 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/runtime_loader_negative_fixtures/malformed_runtime_json/runtime_manifest.json | line:25 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/runtime_loader_negative_fixtures/malformed_runtime_json/runtime_manifest.json | line:8 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/runtime_loader_negative_fixtures/missing_manifest_field/battle_reward.json | line:2 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/runtime_loader_negative_fixtures/missing_manifest_field/battle_reward.json | line:3 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/runtime_loader_negative_fixtures/missing_manifest_field/battle_reward.json | line:5 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/runtime_loader_negative_fixtures/missing_manifest_field/runtime_manifest.json | line:12 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/runtime_loader_negative_fixtures/missing_manifest_field/runtime_manifest.json | line:13 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/runtime_loader_negative_fixtures/missing_manifest_field/runtime_manifest.json | line:14 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/runtime_loader_negative_fixtures/missing_manifest_field/runtime_manifest.json | line:15 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/runtime_loader_negative_fixtures/missing_manifest_field/runtime_manifest.json | line:24 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/runtime_loader_negative_fixtures/missing_manifest_field/runtime_manifest.json | line:7 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/runtime_loader_negative_fixtures/record_count_mismatch/battle_reward.json | line:2 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/runtime_loader_negative_fixtures/record_count_mismatch/battle_reward.json | line:3 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/runtime_loader_negative_fixtures/record_count_mismatch/battle_reward.json | line:5 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/runtime_loader_negative_fixtures/record_count_mismatch/runtime_manifest.json | line:13 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/runtime_loader_negative_fixtures/record_count_mismatch/runtime_manifest.json | line:14 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/runtime_loader_negative_fixtures/record_count_mismatch/runtime_manifest.json | line:15 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/runtime_loader_negative_fixtures/record_count_mismatch/runtime_manifest.json | line:16 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/runtime_loader_negative_fixtures/record_count_mismatch/runtime_manifest.json | line:25 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/runtime_loader_negative_fixtures/record_count_mismatch/runtime_manifest.json | line:8 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/runtime_loader_negative_fixtures/schema_fingerprint_mismatch/battle_reward.json | line:2 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/runtime_loader_negative_fixtures/schema_fingerprint_mismatch/battle_reward.json | line:3 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/runtime_loader_negative_fixtures/schema_fingerprint_mismatch/battle_reward.json | line:5 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/runtime_loader_negative_fixtures/schema_fingerprint_mismatch/runtime_manifest.json | line:13 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/runtime_loader_negative_fixtures/schema_fingerprint_mismatch/runtime_manifest.json | line:14 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/runtime_loader_negative_fixtures/schema_fingerprint_mismatch/runtime_manifest.json | line:15 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/runtime_loader_negative_fixtures/schema_fingerprint_mismatch/runtime_manifest.json | line:16 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/runtime_loader_negative_fixtures/schema_fingerprint_mismatch/runtime_manifest.json | line:25 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/runtime_loader_negative_fixtures/schema_fingerprint_mismatch/runtime_manifest.json | line:8 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/runtime_loader_negative_fixtures/unknown_runtime_file/battle_reward.json | line:2 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/runtime_loader_negative_fixtures/unknown_runtime_file/battle_reward.json | line:3 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/runtime_loader_negative_fixtures/unknown_runtime_file/battle_reward.json | line:5 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/runtime_loader_negative_fixtures/unknown_runtime_file/runtime_manifest.json | line:13 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/runtime_loader_negative_fixtures/unknown_runtime_file/runtime_manifest.json | line:14 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/runtime_loader_negative_fixtures/unknown_runtime_file/runtime_manifest.json | line:15 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/runtime_loader_negative_fixtures/unknown_runtime_file/runtime_manifest.json | line:16 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/runtime_loader_negative_fixtures/unknown_runtime_file/runtime_manifest.json | line:25 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/runtime_loader_negative_fixtures/unknown_runtime_file/runtime_manifest.json | line:8 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/runtime_loader_negative_fixtures/unsafe_runtime_path/battle_reward.json | line:2 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/runtime_loader_negative_fixtures/unsafe_runtime_path/battle_reward.json | line:3 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/runtime_loader_negative_fixtures/unsafe_runtime_path/battle_reward.json | line:5 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/runtime_loader_negative_fixtures/unsafe_runtime_path/runtime_manifest.json | line:13 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/runtime_loader_negative_fixtures/unsafe_runtime_path/runtime_manifest.json | line:14 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/runtime_loader_negative_fixtures/unsafe_runtime_path/runtime_manifest.json | line:16 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/runtime_loader_negative_fixtures/unsafe_runtime_path/runtime_manifest.json | line:25 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/runtime_loader_negative_fixtures/unsafe_runtime_path/runtime_manifest.json | line:8 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/runtime_loader_negative_fixtures/valid_control/battle_reward.json | line:2 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/runtime_loader_negative_fixtures/valid_control/battle_reward.json | line:3 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/runtime_loader_negative_fixtures/valid_control/battle_reward.json | line:5 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/runtime_loader_negative_fixtures/valid_control/runtime_manifest.json | line:13 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/runtime_loader_negative_fixtures/valid_control/runtime_manifest.json | line:14 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/runtime_loader_negative_fixtures/valid_control/runtime_manifest.json | line:15 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/runtime_loader_negative_fixtures/valid_control/runtime_manifest.json | line:16 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/runtime_loader_negative_fixtures/valid_control/runtime_manifest.json | line:25 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/design/runtime_loader_negative_fixtures/valid_control/runtime_manifest.json | line:8 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/narrative/mvp_compressed_narrative.json | line:81 | 获得 | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/runtime/content_engine/battle_reward.json | line:12 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/runtime/content_engine/battle_reward.json | line:2 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/runtime/content_engine/battle_reward.json | line:23 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/runtime/content_engine/battle_reward.json | line:24 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/runtime/content_engine/battle_reward.json | line:25 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/runtime/content_engine/battle_reward.json | line:26 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/runtime/content_engine/battle_reward.json | line:3 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/runtime/content_engine/battle_reward.json | line:5 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/runtime/content_engine/runtime_manifest.json | line:13 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/runtime/content_engine/runtime_manifest.json | line:14 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/runtime/content_engine/runtime_manifest.json | line:15 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/runtime/content_engine/runtime_manifest.json | line:16 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/runtime/content_engine/runtime_manifest.json | line:25 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/runtime/content_engine/runtime_manifest.json | line:3 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | data/runtime/content_engine/runtime_manifest.json | line:8 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | scripts/auto_battle_sampler_foundation.gd | _resolution_order | settlement | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | scripts/auto_battle_sampler_foundation.gd | _resolve_sampler_exchange | settlement | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | scripts/auto_battle_sampler_optimization.gd | run_batch | settlement | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | scripts/auto_battle_sampler_report.gd | format_report | settlement | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | scripts/auto_battle_sampler_simulation.gd | run_single | settlement | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | scripts/battle_context_bridge.gd | fallback_mapping | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | scripts/battle_context_bridge.gd | with_current_player_role | result | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | scripts/battle_controller_core_catalog.gd | _build_catalog | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | scripts/battle_controller_core_catalog.gd | reward_pool | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | scripts/battle_controller_core_result_overlay.gd | line:1 | rewards | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | scripts/battle_controller_core_round_resolution.gd | _resolve_round | 结算 | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | scripts/battle_controller_core_session_rewards.gd | _show_role_selection | 获得 | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | scripts/battle_controller_core_state.gd | reward_pool | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | scripts/battle_controller_visual_break_preview.gd | _effect_preview_text | 结算 | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | scripts/battle_controller_visual_hot_tuning_profile_collect.gd | _all_runtime_cards | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | scripts/battle_controller_visual_hot_tuning_sampler_core.gd | _current_sampler_settlement_mode | settlement | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | scripts/battle_controller_visual_hot_tuning_sampler_core.gd | _sample_number_config | settlement | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | scripts/battle_controller_visual_narrative_context_apply.gd | _apply_battle_loadout_once | settlement | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | scripts/battle_controller_visual_narrative_context_foundation.gd | _story_loader_card_catalog | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | scripts/battle_controller_visual_narrative_context_loadout.gd | _resolve_battle_loadout | settlement | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | scripts/battle_controller_visual_reactive_preview_formatter.gd | line:3 | settlement | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | scripts/battle_controller_visual_reactive_preview_formatter.gd | threat_preview_text | result | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | scripts/battle_controller_visual_reactive_round_flow.gd | _try_apply_reactive_enemy_pre_move | result | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | scripts/battle_controller_visual_reactive_round_flow.gd | _unhandled_input | settlement | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | scripts/battle_controller_visual_reactive_round_flow.gd | line:3 | settlement | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | scripts/battle_controller_visual_reactive_round_flow.gd | line:8 | settlement | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | scripts/battle_controller_visual_settlement_mode.gd | _mode_status_suffix | settlement | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | scripts/battle_controller_visual_settlement_mode.gd | _mode_status_suffix | 结算 | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | scripts/battle_controller_visual_settlement_mode.gd | line:3 | settlement | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | scripts/battle_controller_visual_settlement_mode.gd | line:8 | settlement | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | scripts/battle_controller_visual_story_return.gd | _battle_result_confirm_button | result | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | scripts/battle_controller_visual_story_return.gd | _battle_reward_choices | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | scripts/battle_controller_visual_story_return.gd | _effect_preview_text | 结算 | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | scripts/battle_controller_visual_story_return.gd | _on_battle_result_confirm_pressed | result | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | scripts/battle_controller_visual_story_return.gd | _reactive_threat_preview_text | result | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | scripts/battle_controller_visual_story_return.gd | _refresh_ui | result | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | scripts/battle_controller_visual_story_return.gd | _selected_battle_reward_card_id | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | scripts/battle_controller_visual_story_return.gd | line:1 | settlement | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | scripts/battle_controller_visual_story_selection.gd | _add_story_encounter_button | settlement | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | scripts/battle_controller_visual_story_selection.gd | _on_story_selection_back_pressed | clear | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | scripts/battle_controller_visual_story_selection.gd | _ready | settlement | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | scripts/battle_controller_visual_story_selection.gd | _show_story_encounter_selection | 结算 | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | scripts/battle_controller_visual_story_selection.gd | line:19 | settlement | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | scripts/battle_controller_visual_story_selection.gd | line:3 | settlement | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | scripts/battle_controller_visual_story_selection.gd | line:6 | settlement | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | scripts/battle_controller_visual_story_selection.gd | line:8 | settlement | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | scripts/battle_controller_visual_ui_state.gd | _show_role_selection | 获得 | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | scripts/battle_profile_builder.gd | martial_reward_cards_for_level | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | scripts/battle_profile_builder.gd | martial_reward_cards_for_level | rewards | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | scripts/content_engine_runtime_gate.gd | line:9 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | scripts/content_engine_runtime_loader.gd | line:8 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | scripts/narrative/battle_reward_runtime_adapter.gd | RUNTIME_REWARD_PATH | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | scripts/narrative/battle_reward_runtime_adapter.gd | _build_output | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | scripts/narrative/battle_reward_runtime_adapter.gd | resolve_reward | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | scripts/narrative/canonical_battle_reward_runtime.gd | empty_reward | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | scripts/narrative/canonical_battle_reward_runtime.gd | line:3 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | scripts/narrative/canonical_battle_reward_runtime.gd | line:5 | rewards | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | scripts/narrative/canonical_battle_reward_runtime.gd | reward_from_context_or_node | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | scripts/narrative/canonical_map_runtime.gd | default_map_reward_for_node | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | scripts/narrative/focus_ending_settlement_view.gd | ensure_popup | settlement | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | scripts/narrative/focus_ending_settlement_view.gd | line:3 | settlement | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | scripts/narrative/focus_ending_settlement_view.gd | line:6 | settlement | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | scripts/narrative/focus_ending_settlement_view.gd | line:8 | settlement | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | scripts/narrative/focus_ui_view.gd | FocusEndingSettlementView | settlement | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | scripts/narrative/focus_ui_view.gd | _ending_settlement_view | settlement | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | scripts/narrative/focus_ui_view.gd | _ensure_ending_settlement_popup | settlement | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | scripts/narrative/focus_ui_view.gd | _focus_ending_settlement_view | settlement | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | scripts/narrative/narrative_choice_runtime.gd | render_ending | 结算 | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | scripts/narrative/strategic_debug_profile_builder.gd | line:10 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | scripts/narrative/strategic_debug_profile_builder.gd | line:11 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | scripts/narrative/strategic_debug_profile_builder.gd | line:21 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | scripts/narrative/strategic_debug_profile_builder.gd | line:22 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | scripts/narrative/strategic_debug_profile_builder.gd | line:8 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | scripts/narrative/strategic_debug_profile_builder.gd | line:9 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | scripts/narrative/strategic_legacy_battle_result_runtime.gd | consume_result | 结算 | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | scripts/narrative/strategic_legacy_map_view.gd | line:6 | rewards | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | scripts/narrative/strategic_reward_runtime.gd | StrategicRewardView | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | scripts/narrative/strategic_reward_runtime.gd | _reward_view | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | scripts/narrative/strategic_reward_runtime.gd | _view | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | scripts/narrative/strategic_reward_runtime.gd | strategic_card_reward_choices | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | scripts/narrative/strategic_reward_view.gd | MAP_PLACEHOLDER | 奖励 | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | scripts/narrative/strategic_reward_view.gd | line:3 | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | scripts/narrative/strategic_reward_view.gd | line:5 | rewards | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | scripts/narrative/strategic_reward_view.gd | render_reward_choice | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | scripts/narrative_battle_context.gd | line:21 | result | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | scripts/narrative_battle_context.gd | line:22 | result | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | scripts/narrative_battle_context.gd | set_request | clear | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | scripts/narrative_battle_context.gd | set_request | result | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | scripts/story_battle_loader.gd | build_card_catalog | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | scripts/story_battle_loader.gd | build_story_battle | settlement | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | scripts/strategic_map_state.gd | apply_card_rewards | rewards | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | scripts/strategic_map_state.gd | apply_effects | rewards | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | scripts/visual/battle_hud_view.gd | card_detail_text | 获得 | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | scripts/visual/resolver_preview_formatter.gd | effect_preview_text | 结算 | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | scripts/visual/responsive_catalog_helper.gd | build_catalog | reward | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |
| unknown_candidate | scripts/visual/responsive_catalog_helper.gd | build_catalog | rewards | 可能只是 UI 文案或无关匹配 | low | low | 保留观察，不作为首批接入点。 |

## 说明

- 本报告仅基于静态文本扫描，不执行战斗逻辑。
- `result/clear/gain` 这类弱关键词已做上下文过滤，仍可能存在少量噪声候选。
- 正式接入应通过单一 adapter 完成，避免在多个业务脚本散落条件分支。
