# 对称战斗 v0.3.1 执行清单归档

本文档原为 v0.3.1 对称战斗玩法修改执行清单，现已降级为历史记录。当前战斗入口以 [BATTLE.md](BATTLE.md) 为准，UI 入口以 [UI_PIPELINE.md](UI_PIPELINE.md) 为准。

## 历史目标

v0.3.1 的核心目标是把早期“双方按距离结算”的战斗推进到 9 格横轴、位置、朝向、轻功和敌方选位的对称式玩法。

当时覆盖的模块：

- `FighterData` / `Fighter` 增加初始位置、朝向、轻功和运行时站位。
- `CardData` 增加兵器类型、朝向要求和位移字段。
- `BattleStateMachine` 将 `current_distance` 降级为派生缓存。
- 玩家确认出招前先选目标格和朝向。
- 九格 UI 从展示改为可点击。
- 预览系统显示移动、朝向、攻击范围和确认按钮状态。
- 敌方 AI 增加位置选择和朝向选择。

## 当前状态

- 对称式模式仍保留用于对照和旧规则测试。
- 当前默认模式是 `reactive`，正式剧情战斗优先走反应式流程。
- 位置、朝向、位移、预览和表演的当前规则已收敛到 [BATTLE.md](BATTLE.md) 与 [UI_PIPELINE.md](UI_PIPELINE.md)。

## 后续维护规则

- 不再扩写本文档。
- 如果发现仍有效的细节，应并入 [BATTLE.md](BATTLE.md) 或 [UI_PIPELINE.md](UI_PIPELINE.md)。
- 如果要重开对称式专项，应新建短计划，只写待办和验收，不恢复千行执行清单。
