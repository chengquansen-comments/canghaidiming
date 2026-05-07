# Content Engine v0.4b

## 目标

v0.4b 目标是基于：

- `generated_enemy_deck_skeleton.tsv`（v0.3）
- `generated_card_pool.tsv`（v0.4a）

为每个 skeleton 填充具体 `card_id`，生成设计层敌人卡组表：

- `data/design/generated_enemy_deck_sets.tsv`

## 输入文件

```text
data/design/generated_enemy_deck_skeleton.tsv
data/design/generated_card_pool.tsv
data/design/generated_enemy_archetype_pool.tsv
data/design/generated_enemy_deck_requirement.tsv
```

## 输出文件

```text
data/design/generated_enemy_deck_sets.tsv
```

## long-form 结构

本表采用 long-form：一行表示一个 deck 中的一张卡。

关键字段：

- `deck_id` / `deck_skeleton_id`：卡组身份（默认相同）。
- `card_slot_index`：卡组内顺序（从 1 开始）。
- `slot_role`：来自 skeleton 的槽位角色需求。
- `card_id`：来自 card pool 的具体卡牌。
- `card_*`：拷贝自 card pool，便于 validator 直接检查。
- `selection_score` / `selection_reason`：可解释选卡结果。
- `required_card_tags` / `forbidden_card_tags`：继承自 skeleton。

## card selection 规则

生成器流程：

1. 按 skeleton 角色计数生成 `slot_role` 队列。
2. 对总数与 `target_card_count` 的差额做可重复、可复现的归一化补齐或裁剪。
3. 每个 slot 先做硬过滤，再按软评分排序选择。
4. 同一 deck 的重复 `card_id` 默认受上限约束（普通/精英/武状元 <=2，Boss <=3）。

硬过滤重点：

- `card_deck_role == slot_role`
- `implementation_status != deprecated`
- `card_tags` 与 `forbidden_card_tags` 不相交
- 非 Boss deck 不使用 Boss-only 风格卡
- 不允许把 `lightness_4_required` 作为 required 条件

软评分重点：

- 角色匹配、武器匹配、generic fallback
- required tag 命中
- 距离重叠
- tactic_role 与 skeleton tactic ratio 匹配
- rarity 与 scope 匹配
- budget_delta 偏离程度
- 同卡重复惩罚

## validator 检查项

`enemy_deck_sets_validator.py` 重点检查：

- 文件存在、skeleton/card pool 引用完整
- deck 数量与每 deck 卡数是否符合 skeleton target
- slot role 分布、`card_deck_role` 一致性
- required/forbidden tag 约束
- 普通/精英与 Boss 卡边界
- 轻功 4 硬门槛禁用
- deck 内重复上限
- Boss / 武状元 / firearm 结构性约束
- scope 维度数量统计（22 / 8 / 4 / 5）

## 当前不做

- 不写运行时 deck。
- 不修改 `CardData`。
- 不修改 `combat_resolver`。
- 不接 LLM API。

## 运行生成器

```bash
python3 tools/content_engine/enemy_deck_sets_generator.py \
  --design-dir data/design \
  --out data/design/generated_enemy_deck_sets.tsv
```

## 运行校验器

```bash
python3 tools/content_engine/enemy_deck_sets_validator.py \
  --design-dir data/design
```

## 进入 v0.5

v0.5 建议按设计层继续推进：

- `battle_reward_generator`
- `operation_node_generator`
- `narrative_node_generator`
- `route_gate_generator`

先生成和校验 design 表，再考虑后续 runtime exporter。
