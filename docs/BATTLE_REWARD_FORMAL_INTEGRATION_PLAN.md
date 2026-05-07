# battle_reward 正式接入设计方案（v1.0a）

## 当前 battle_reward content engine 状态

- `content engine v0.9-lite` 已完成，日常总入口已通过。
- `battle_reward runtime` 当前记录数为 45。
- `data/design/generated_battle_reward_plan.tsv` 为 45 条。
- `data/runtime/content_engine/battle_reward.json` 为 45 条。
- Godot headless 只读读取与 `battle_reward_readonly_integration_probe` 已通过。
- `runtime_loader_config.json` 仍为 `disabled`，未接入正式主流程。
- 目前不存在现有 `.gd` 业务脚本引用 loader/gate/probe。
- `card_pool` 仍为 `scaffold_or_unhydrated / out_of_scope`。

## 当前旧奖励流程定位结果

结论：当前仓库内存在多条奖励链路，至少包含以下三类并行来源。

- 战斗内卡牌奖励链路（MainVisual/战斗结果弹层）。
- 叙事战斗资源奖励链路（军功/清望/线索/成长）。
- 旧单局原型路线奖励链路（`Main_*` + `data/rewards.json`）。

因此 `是否存在多个奖励来源` 判断为：`是`。

## 旧奖励数据源候选

- `data/rewards.json`
  - 旧单局原型奖励池（卡牌 ID 列表）。
- `data/enemy_manifest.json` 中 `enemy_config.reward`
  - 叙事战斗敌人配置内奖励字段（资源奖励候选）。
- `scripts/narrative_demo_formal_controller.gd::_formal_reward_for_encounter`
  - 代码内硬编码 encounter 奖励映射（正式剧情 demo 的旧源）。
- `scripts/battle_controller_core_catalog.gd::reward_pool`
  - MainVisual 侧卡牌模板奖励池（运行时内置旧源）。

## 奖励生成函数候选

- `scripts/battle_controller_core_session_rewards.gd::_sample_rewards`
- `scripts/battle_controller_visual_story_return.gd::_sample_battle_reward_choices`
- `scripts/narrative_demo_canonical_controller.gd::_battle_reward_for_source`
- `scripts/narrative_demo_canonical_controller.gd::_battle_growth_reward_for_source`
- `scripts/narrative_demo_formal_controller.gd::_formal_reward_for_encounter`

## 战斗结算入口候选

- `scripts/battle_controller_core_round_resolution.gd::_finish_battle`
- `scripts/battle_controller_core_result_overlay.gd::_queue_battle_result_overlay`
- `scripts/battle_controller_visual_story_return.gd::_on_battle_result_confirm_pressed`
- `scripts/narrative_demo_canonical_controller.gd::_consume_battle_result_if_needed`
- `scripts/narrative_battle_context.gd::set_result`

## 奖励展示入口候选

- `scripts/battle_controller_core_result_overlay.gd::_show_battle_result_overlay`
- `scripts/battle_controller_visual_story_return.gd::_show_battle_result_overlay`
- `scripts/battle_controller_core_session_rewards.gd::_open_gain_move`
- `scripts/battle_controller_core_session_rewards.gd::_open_realm_move_reward`

## 奖励应用入口候选

- `scripts/battle_controller_core_session_rewards.gd::_pick_reward_card`
- `scripts/battle_controller_visual_story_return.gd::_on_battle_result_confirm_pressed`（胜利时调用 `NarrativeBattleContext.grant_player_cards`）
- `scripts/narrative_demo_canonical_controller.gd::_apply_battle_result_reward`
- `scripts/narrative_demo_formal_controller.gd::_apply_battle_result_reward`
- `scripts/narrative_battle_context.gd::grant_player_cards`
- `scripts/narrative_battle_context.gd::apply_player_growth`

## 推荐的最小接入点

推荐最小接入点：

- 首选：`scripts/narrative_demo_canonical_controller.gd::_battle_reward_for_source`
- 次选：`scripts/narrative_demo_canonical_controller.gd::_apply_battle_result_reward`

原因：

- 已具备“来源归一”语义（context/node/formal reward 已在此汇聚）。
- 改动面可控，不需要触碰 `battle_state` / `combat_result` 核心结构。
- 可以在不修改战斗主流程的情况下增加 adapter 旁路调用与比较记录。

## 不推荐直接修改的文件和原因

- `scripts/combat_resolver.gd`
  - 战斗核心解算器，回归风险高。
- `scripts/battle_state_machine.gd`
  - 回合/阶段状态机核心，不应在接入第一步触碰。
- `scripts/card_data.gd`
  - 卡牌基础数据结构，改动会放大全局影响。
- `data/story_battles/*.tsv`
  - 正式剧情战斗配表，当前阶段只允许读。
- `scenes/*.tscn`
  - 场景资源文件，非本阶段必要改动。

## battle_reward adapter 设计

目标：在一个集中模块完成“legacy/runtime 读取、选择、比较、兜底”。

设计约束：

- adapter 不应散落在多个业务文件中。
- 主流程未来最多只接入一个入口（单一调用点）。
- adapter 负责读取 `runtime_loader_config`。
- adapter 负责读取 legacy reward。
- adapter 负责读取 runtime reward。
- adapter 负责 shadow compare。
- adapter 负责 fallback。
- adapter 失败时不得影响正式奖励结算。
- adapter 不应直接修改 `battle_state` 或 `combat_result`。

建议输出结构（示意字段）：

- `selected_reward`: 本次真正生效奖励（默认 legacy）。
- `legacy_reward`: legacy 读取结果。
- `runtime_reward`: runtime 读取结果（可为空）。
- `runtime_compare`: 差异摘要（缺失字段/值差异）。
- `runtime_used_for_result`: bool。
- `reward_result_replaced`: bool。
- `formal_data_source_replaced`: bool。
- `fallback_triggered`: bool。
- `fallback_reason`: string。

## config mode 设计

### legacy

- 是否读取 runtime reward：否（可选仅健康检查，不参与结算）。
- 是否影响正式奖励结果：否。
- 是否允许进入正式战斗流程：是。
- 失败时如何 fallback：不涉及 runtime，直接 legacy。
- 是否可用于测试服 / debug 入口 / 正式版本：全可用，默认。

### shadow

- 是否读取 runtime reward：是（旁路读取与对比）。
- 是否影响正式奖励结果：否，真实结果始终 legacy。
- 是否允许进入正式战斗流程：是。
- 失败时如何 fallback：任何 runtime 错误直接忽略并记录，不影响 legacy。
- 是否可用于测试服 / debug 入口 / 正式版本：测试服与正式版本可用（仅旁路观测）。

shadow 强制字段：

- `runtime_reward_used_for_result=false`
- `reward_result_replaced=false`
- `formal_data_source_replaced=false`

### runtime_test

- 是否读取 runtime reward：是。
- 是否影响正式奖励结果：仅在测试入口显式启用时可影响。
- 是否允许进入正式战斗流程：否（默认不允许）。
- 失败时如何 fallback：自动回退到 legacy，并记录回退原因。
- 是否可用于测试服 / debug 入口 / 正式版本：仅测试服 / debug / internal test。

runtime_test 约束：

- 只允许测试入口 / debug battle / internal test 使用 runtime reward。
- 不允许默认进入正式战斗。
- 需要显式配置启用。

### runtime_enabled

- 是否读取 runtime reward：是。
- 是否影响正式奖励结果：是。
- 是否允许进入正式战斗流程：是（在通过验收后）。
- 失败时如何 fallback：一键关闭后立即回退 legacy。
- 是否可用于测试服 / debug 入口 / 正式版本：最终正式版本模式。

runtime_enabled 前置条件：

- 不在当前阶段实现。
- 必须先通过 shadow 与 runtime_test 验收。
- 必须具备一键关闭。
- 必须具备明确回滚路径。
- 必须具备对比监控。

## shadow 阶段方案

- legacy reward 仍作为真实结果。
- runtime reward 仅做旁路读取和 compare。
- 不替换正式数据源，不改主流程调用顺序。
- runtime 报错仅入日志/报告，不中断结算。

## runtime_test 阶段方案

- 仅在测试入口、debug battle、internal test 显式开启 runtime。
- 正式战斗默认仍走 legacy。
- 每次 runtime 使用都记录 compare 与 fallback 指标。
- 任一异常自动 fallback 到 legacy，且结算继续。

## runtime_enabled 阶段方案

- 本阶段（v1.0a）不实现。
- 仅输出设计与门禁条件。
- 上线前必须完成 shadow/runtime_test 的差异收敛和回归验证。

## fallback 和回滚方案

- fallback 触发条件：
  - runtime 文件缺失/字段错误/记录不匹配/读取失败/adapter 异常。
- fallback 行为：
  - 当次结算立即改用 legacy；
  - `runtime_used_for_result=false`；
  - 写入失败原因指标。
- 回滚路径：
  - 将 mode 切回 `legacy`（或关闭 runtime 开关）即可一键回退。

## 验收标准

- 静态扫描报告可复现，字段完整。
- 设计文档完整覆盖 adapter、mode、shadow/runtime_test/runtime_enabled、fallback。
- `runtime_loader_config` 保持 disabled。
- 未替换正式奖励源，未修改高风险战斗主流程文件。
- 现有 `.gd` 文件仍无 loader/gate/probe 引用。
- 既有 `content_engine_check` 与 readonly probe validator 持续通过。

## 风险清单

- 多奖励来源并存导致语义不一致（卡牌奖励 vs 叙事资源奖励）。
- UI 展示层与应用层分离不彻底时，易出现“显示 A、写入 B”。
- runtime schema 变化可能造成 compare 噪声放大。
- 若 adapter 入口分散，后续回滚与定位成本会上升。

## 后续 v1.0b / v1.0c / v1.0d / v1.0e 建议

- v1.0b：实现 adapter scaffold（只读 compare，不替换结果）。
- v1.0c：接入 shadow 到目标最小入口，建立差异报告闭环。
- v1.0d：开放 runtime_test 到 debug/internal，验证 fallback 稳定性。
- v1.0e：在通过门禁后评估 runtime_enabled 灰度方案与回滚演练。
