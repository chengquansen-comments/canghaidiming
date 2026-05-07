# Content Engine v0.4a

## 目标

v0.4a 目标是基于 `Combat Card Grammar` 与 v0.3 的 deck skeleton 需求，生成“设计层可用卡池”：

- `data/design/generated_card_pool.tsv`

本阶段只生成设计层卡池，不生成运行时卡牌，不填敌人正式 deck set。

## 输入文件

```text
data/design/generated_enemy_deck_skeleton.tsv
data/design/generated_enemy_archetype_pool.tsv
data/design/generated_enemy_deck_requirement.tsv
docs/COMBAT_CARD_GRAMMAR_V1.md (可选读取，用于 source_grammar)
```

## 输出文件

```text
data/design/generated_card_pool.tsv
```

字段：

```text
card_id
display_name
card_class
weapon_style
weapon_requirement
is_generic
rarity
tactic_role
deck_role
min_distance
max_distance
preferred_distance
momentum_cost
gain_momentum
break_momentum
damage
guard
self_move_after
target_push_after
target_pull_after
move_condition
tags
combo_tags
ai_usage_hint
power_budget
budget_target
budget_delta
implementation_status
source_grammar
notes
```

## 字段说明

- `card_id`：snake_case 卡牌标识。
- `card_class`：`attack` / `guard` / `movement` / `posture_break` / `tempo` / `combo` / `special`。
- `weapon_style`：`generic` / `spearman` / `blademaster` / `firearm` / `footwork` / `official` / `mixed` / `boss`。
- `deck_role`：与 v0.3 skeleton 卡组计数槽位对应。
- `tags`：至少包含 `weapon_xxx`、`role_xxx`、`deck_xxx`、`ai_xxx`。
- `power_budget`：`gain_momentum * 2 + break_momentum * 2 + damage + guard`。
- `budget_target`：`momentum_cost * 4`。
- `budget_delta`：`power_budget - budget_target`。
- `implementation_status`：当前以 `design_only` / `data_ready` 为主。

## 设计卡池与运行时 CardData 边界

`generated_card_pool.tsv` 是设计层候选池，不等于运行时正式卡池。

本阶段不会：

- 写入 `scripts/card_data.gd`。
- 写入 `scripts/combat_resolver.gd`。
- 写入 `scripts/battle_state_machine.gd`。
- 写入 `data/story_battles/*.tsv`。

## 当前不做

- 不填 enemy deck sets。
- 不生成 runtime card data。
- 不修改 CardData。
- 不修改 combat_resolver。
- 不接 LLM API。

## 运行生成器

```bash
python3 tools/content_engine/card_pool_generator.py \
  --design-dir data/design \
  --out data/design/generated_card_pool.tsv
```

## 运行校验器

```bash
python3 tools/content_engine/card_pool_validator.py \
  --design-dir data/design
```

校验范围包括：字段完整性、ID 唯一性、预算公式、武器与 deck role 覆盖、boss/generic 标签边界、`lightness_4_required` 禁止项、firearm 反制覆盖。

## 进入 v0.4b

v0.4b 建议实现 `enemy_deck_sets_generator`，以：

- `generated_enemy_deck_skeleton.tsv`（结构约束）
- `generated_card_pool.tsv`（可用候选）

为输入，按 `deck_role` 计数、`tags` 约束和 `forbidden` 规则填充具体 `card_id`，输出 enemy deck set 设计表。
