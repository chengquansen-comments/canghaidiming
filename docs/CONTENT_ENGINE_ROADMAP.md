# Content Engine Roadmap

## 总体结构

Content Engine 建议按六层推进：

1. 基础数字层：维护 `progression_numeric_config_v1_3.tsv` 等来源数字。
2. 派生结构层：生成 battle slot、enemy requirement、route curve、operation node requirement。
3. 内容骨架层：生成 archetype 池、deck skeleton、奖励骨架、节点骨架。
4. 内容实例层：在骨架约束下填具体卡牌、敌人卡组、奖励与叙事节点。
5. 校验与采样层：validator + 自动采样报告，持续约束质量。
6. 运行时导出层：把 design 表转为运行时配置，不直接改战斗核心逻辑。

## v0.1 已完成

当前设计层输出：

- `data/design/generated_battle_slot_plan.tsv`
- `data/design/generated_enemy_deck_requirement.tsv`
- `data/design/generated_route_progression_curve.tsv`

## v0.1.1 本次新增

本阶段新增：

- `data/design/generated_operation_node_requirement.tsv`

结果是“经营节点占比 30%-40%”从文档约束升级为设计层表约束，可被 builder 生成并被 validator 检查。

## v0.2 本次新增

本阶段新增：

- `data/design/generated_enemy_archetype_pool.tsv`

该输出是敌人类型骨架池，只定义 archetype、战斗定位、复杂度、距离偏好、检查点和建议 deck 变体数量，不生成具体卡组与具体卡牌。

## v0.3 本次新增

本阶段新增：

- `data/design/generated_enemy_deck_skeleton.tsv`

该输出是敌人卡组骨架，只定义 deck skeleton ID、变体定位、卡组规模、卡牌角色计数、武器标签约束、禁用标签、AI 行为提示和奖励压力级别。

v0.3 仍不填具体 `card_id`，不生成正式敌人 deck，不生成正式卡牌，不修改 Godot 战斗运行时，也不接入 LLM API。

## 后续阶段边界

### v0.2 enemy_archetype_generator

- 只生成 `generated_enemy_archetype_pool.tsv`。
- 不生成具体卡组。
- 输入至少读取 battle slot + operation node 两类结构。

### v0.3 enemy_deck_skeleton_generator

- 生成 deck 骨架（slot、role 比例、武器约束）。
- 不直接填完整卡牌。
- 输出 `generated_enemy_deck_skeleton.tsv`，作为 v0.4 具体卡池与敌人 deck set 的输入。

### v0.4 card_pool / enemy_deck_sets

v0.4 建议拆分为两个子阶段：

- v0.4a `card_pool_generator`：先生成设计层可用卡池 `generated_card_pool.tsv`。
- v0.4b `enemy_deck_sets_generator`：再根据 deck skeleton 与 card pool 填充具体敌人 deck set。

v0.4a / v0.4b 都应保持设计层边界，不直接修改运行时战斗代码。

### v0.5 reward / narrative / route gate

- 生成奖励规划。
- 生成经营节点规划。
- 生成叙事节点规划。
- 生成路线门槛规划。

### v0.6 runtime exporter

- 从 design 表导出运行时数据。
- 仍然不直接改战斗核心结算逻辑。

### v0.7 auto battle sampler integration

- 接入自动战斗采样。
- 输出 balance report 并回写设计建议。

## AI 协作边界

- AI 不直接决定数量。
- AI 只填派生出来的结构坑位。
- Validator 先于运行时。
- Runtime exporter 最后做。
- 单一阶段内，不允许同时改 `CardData`、`combat_resolver`、`battle_state_machine`、`data/story_battles/*.tsv`。
