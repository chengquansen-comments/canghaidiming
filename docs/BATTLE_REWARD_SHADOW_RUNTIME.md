# battle_reward shadow runtime 接入说明（v1.0c）

## 1. 阶段定位

- v1.0c 是最小主流程 shadow 接入。
- 本阶段不是 runtime reward 生效。
- 本阶段不是正式奖励源替换。

## 2. 前置状态

- v1.0a：legacy flow 定位完成。
- v1.0b：adapter scaffold 完成。
- v1.0c-plan：shadow 设计确认完成。

## 3. 本次接入点

- `scripts/narrative_demo_canonical_controller.gd::_battle_reward_for_source`

## 4. 接入方式

- 保留 legacy reward 计算。
- legacy reward 计算完成后旁路调用 adapter。
- adapter 输出 `runtime_candidate / shadow_compare`。
- 正式 `selected_reward` 仍为 legacy。

## 5. shadow 模式语义

- runtime reward 只作为候选。
- `selected_reward_runtime_effective=false`。
- 不改变玩家实际奖励。
- 不改变成长。
- 不改变结算 UI。
- 不改变 battle_state / combat_result。

## 6. fallback 机制

- adapter 缺失 fallback legacy。
- adapter 异常 fallback legacy。
- runtime 缺失 fallback legacy。
- config disabled fallback legacy。
- shadow compare 失败不影响正式奖励。

## 7. 禁止范围

- 不接 `combat_resolver.gd`。
- 不接 `battle_state_machine.gd`。
- 不接 `card_data.gd`。
- 不接 `battle_controller_core_round_resolution.gd`。
- 不接 `battle_controller_core_session_rewards.gd`。
- 不改 `scenes/*.tscn`。
- 不改正式奖励源。

## 8. 风险与回滚

- 软回滚：保持 `runtime_loader_config` disabled。
- 代码回滚：移除 `_battle_reward_for_source` 中 adapter shadow 调用。
- 数据回滚：不需要改正式奖励源。
- 异常回滚：adapter fallback legacy。

## 9. 验收标准

- `selected_reward_source=legacy`。
- `runtime_reward_effective=false`。
- shadow report 生成。
- 日常检查通过。
- 高级回归通过。
- Godot headless 通过。

## 10. 后续 v1.0d 说明

- v1.0d 才能考虑 `runtime_test` 模式。
- `runtime_test` 只能先用于测试入口。
- 仍不得直接替换正式流程。
