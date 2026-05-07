# Content Engine v0.1

Content Engine v0.1 是数字驱动的内容规划工具。它从 `data/design/progression_numeric_config_v1_3.tsv` 派生战斗坑位、敌人卡组需求和路线成长曲线，为后续 AI 生成敌人、卡组、奖励和叙事节点提供受约束的结构。

本阶段不生成正式卡牌，不生成正式敌人卡组，不修改战斗运行时。

## 输入文件

```text
data/design/progression_numeric_config_v1_3.tsv
```

输入使用 TSV，字段包括：

```text
config_id
category
scope
route
stage
metric
min_value
default_value
max_value
unit
value_type
enum_value
is_tunable
source_section
notes
```

loader 使用 Python 标准库 `csv.DictReader`，delimiter 为 tab。缺失必需字段会报错；缺失文件时 builder 会写一个最小可运行样例。

## 输出文件

所有 v0.1.1 输出都写入 `data/design/`：

```text
generated_battle_slot_plan.tsv
generated_enemy_deck_requirement.tsv
generated_route_progression_curve.tsv
generated_operation_node_requirement.tsv
```

这些文件是设计层计划，不是 Godot runtime 数据。

## 战斗坑位表

`generated_battle_slot_plan.tsv` 描述整局游戏需要哪些战斗坑位。

字段：

```text
battle_slot_id
stage
route_type
battle_type
slot_index
min_count
default_count
max_count
expected_player_realm
expected_lightness_level
enemy_pool_scope
is_fixed
notes
```

当前包含序章 1 战、武举线 5 战、大地图普通池、大地图精英池、普通 Boss、真结局 Boss、武状元 5 场考试。

## 敌人卡组需求表

`generated_enemy_deck_requirement.tsv` 根据战斗数量反推敌人卡组候选数量。

字段：

```text
requirement_id
scope
route_type
battle_type
actual_battle_count_min
actual_battle_count_default
actual_battle_count_max
pool_multiplier
required_deck_count_min
required_deck_count_default
required_deck_count_max
recommended_archetype_count
recommended_visual_identity_count
notes
```

大地图候选池约为实际体验战斗数量 2 倍。Boss 与武状元考试为固定内容，不走 2 倍随机池。

## 经营节点需求表

`generated_operation_node_requirement.tsv` 把经营节点比例从文档约束升级为设计层结构约束。

字段：

```text
requirement_id
scope
route_type
node_type
actual_node_count_min
actual_node_count_default
actual_node_count_max
ratio_min
ratio_default
ratio_max
recommended_subtypes
notes
```

默认目标：

- 大地图战斗节点：`14-16`，默认 `15`
- 经营 / 事件 / 修行节点：`7-10`，默认 `8`
- 总经过节点：`22-26`，默认 `23`
- 经营占比：`30%-40%`，默认约 `0.348 (8/23)`

该表会被后续 `narrative_node_generator` / `operation_node_generator` 消费，防止后续内容生产只偏向战斗节点。

## 路线成长曲线表

`generated_route_progression_curve.tsv` 描述不同路线的累计成长。

字段：

```text
route
checkpoint
battle_count_cumulative
martial_xp_min
martial_xp_default
martial_xp_max
expected_realm_min
expected_realm_default
expected_realm_max
expected_lightness_min
expected_lightness_default
expected_lightness_max
can_reach_realm_10
can_unlock_true_ending
can_unlock_wuzhuangyuan
notes
```

当前路线目标：

- 普通路线：最终 8-9 境，轻功不超过 2。
- 精英 / 真结局路线：可稳定达到 10 境，真 Boss 按 10 境设计。
- 武状元路线：触发前必须武境 10、军功高，回京考试 5 战。

## 运行 Builder

```bash
python3 tools/content_engine/progression_plan_builder.py \
  --config data/design/progression_numeric_config_v1_3.tsv \
  --out-dir data/design
```

## 运行 Validator

```bash
python3 tools/content_engine/progression_validator.py \
  --design-dir data/design
```

validator 输出 `PASS`、`WARN`、`FAIL`。当前检查：

- 四张 generated TSV 是否存在。
- 大地图总战斗 default 是否为 15。
- 大地图战斗范围是否为 14-16。
- 默认精英比例是否在 20%-30%。
- `generated_operation_node_requirement.tsv` 是否存在。
- 经营节点比例是否在 30%-40%。
- 默认经营节点是否约为 8。
- 默认总经过节点是否约为 23。
- 大地图总候选 deck default 是否为 30。
- 普通路线最终武境是否为 8-9。
- 精英或真结局路线是否可达到 10。
- 武状元是否有 5 场考试。
- 武状元路线是否标记 `can_unlock_wuzhuangyuan`。
- 普通路线轻功 max 是否不超过 2。
- 轻功 4 是否只出现在特殊路线。

## v0.1 不做

- 不生成正式卡牌。
- 不生成正式敌人卡组。
- 不修改 `combat_resolver.gd`。
- 不修改 `battle_state_machine.gd`。
- 不修改 `CardData`。
- 不批量修改 `data/story_battles/*.tsv`。
- 不接入 LLM API。
- 不直接写运行时 JSON。
- 不做自动战斗采样。

## v0.2 扩展方向

v0.2 可以在 validator 通过后增加这些设计层生成器：

- `enemy_archetype_generator`
- `enemy_deck_generator`
- `battle_reward_generator`
- `narrative_node_generator`

建议先做 `enemy_archetype_generator`，并且同时读取 battle slot 与 operation node 两类结构，避免只生成战斗内容而丢失经营节点节奏。

扩展顺序仍应是：文档约束、结构生成、validator、人工确认，最后才考虑运行时迁移。

## AI 协作边界

- AI 不直接决定数量，只能使用数字配置派生出来的结构坑位。
- AI 只填结构坑位，不绕过 `generated_*` 表自由生成内容。
- Validator 先于运行时。
- 不直接修改 `combat_resolver.gd`、`battle_state_machine.gd` 或 `CardData`。
- 不把设计表直接接入 Godot runtime。
