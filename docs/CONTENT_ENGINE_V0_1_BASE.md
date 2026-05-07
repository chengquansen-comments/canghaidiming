# Content Engine v0.1 基础设计文档

## 一、目标

Content Engine v0.1 的目标是把《大明之沧海嘀鸣》的基础数值规划转化为可扩展的内容生产结构。

本阶段不直接生成具体卡牌、不直接生成敌人卡组、不修改战斗运行时。

本阶段只做一件事：

> 由 `data/design/progression_numeric_config_v1_3.tsv` 派生出战斗坑位、敌人卡组需求、路线成长曲线三张设计表。

这一步是后续 AI 生成敌人、卡组、奖励、叙事节点的基础。

## 二、输入文件

推荐输入文件：

```text
data/design/progression_numeric_config_v1_3.tsv
```

该文件记录序章、武举线、大地图、精英比例、经营节点比例、敌人池倍率、Boss 数量、武状元路线、武道阈值、奖励、轻功上限和结局触发条件等基础规划数字。

## 三、核心设计原则

### 1. 数字先于内容

Content Engine 不允许 AI 直接决定“应该有多少敌人、多少战斗、多少 Boss”。所有数量先由 TSV 中的基础数字派生。

### 2. 结构先于文本

v0.1 只生成结构表，不生成正式文案。

输出：

```text
generated_battle_slot_plan.tsv
generated_enemy_deck_requirement.tsv
generated_route_progression_curve.tsv
```

不输出正式卡牌、正式敌人卡组、正式剧情文本或 Godot runtime 数据。

### 3. 设计层先于运行时

所有生成结果先放在 `data/design/`。不要直接写入 `data/story_battles/`、`scripts/` 或 `scenes/`。

### 4. Validator 优先

Content Engine 的核心不是“生成”，而是“约束生成”。v0.1 至少检查大地图战斗数、精英比例、经营节点比例提示、敌人候选池倍率、路线武境目标、轻功上限和武状元路线条件。

## 四、输出文件

### `generated_battle_slot_plan.tsv`

描述整局游戏需要哪些战斗坑位。字段：

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

固定结构：序章 1 战、武举线 5 战、大地图普通战 10-12、大地图精英战 3-5、普通结局 Boss 1、真结局 Boss 2、武状元路线 5 战。

### `generated_enemy_deck_requirement.tsv`

根据战斗数量反推敌人卡组需求。大地图候选池约为实际体验战斗数量 2 倍；武状元考试和 Boss 不走 2 倍池。

### `generated_route_progression_curve.tsv`

描述普通路线、精英路线、真结局路线、武状元路线的累计战斗数、累计 `martial_xp`、武道境界、轻功预期和解锁标记。

## 五、成长规则

武道使用累计 `martial_xp`，不按单场直接升级。推荐阈值：

| 境界 | 累计 martial_xp |
|---:|---:|
| 1 | 0 |
| 2 | 8 |
| 3 | 18 |
| 4 | 30 |
| 5 | 44 |
| 6 | 60 |
| 7 | 78 |
| 8 | 98 |
| 9 | 120 |
| 10 | 145 |

轻功不是十境体系。轻功上限为 4，正常路线最多到 2，奇遇或特殊路线下可以到 4。轻功 4 不作为普通 Boss 或真 Boss 的硬门槛。

## 六、v0.1 不做

Content Engine v0.1 不生成正式卡牌、正式敌人卡组、正式剧情文本，不修改 `combat_resolver.gd`、`battle_state_machine.gd`、`CardData`，不批量修改 `data/story_battles/*.tsv`，不接入 LLM API，不直接写运行时 JSON，不做自动战斗采样。

## 七、验收

v0.1 必须能读取数字配置，生成三张设计 TSV，运行 validator，并保持所有输出在设计层。
