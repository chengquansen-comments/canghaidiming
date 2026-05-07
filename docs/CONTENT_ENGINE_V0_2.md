# Content Engine v0.2

## 目标

v0.2 目标是从 v0.1 / v0.1.1 的派生结构表中生成敌人 archetype 池，形成“敌人类型骨架层”，供 v0.3 deck skeleton 继续使用。

本阶段只生成 archetype 骨架，不生成具体卡组，不生成具体卡牌，不修改运行时。

## 输入文件

```text
data/design/generated_enemy_deck_requirement.tsv
data/design/generated_battle_slot_plan.tsv
data/design/generated_route_progression_curve.tsv
data/design/generated_operation_node_requirement.tsv
```

## 输出文件

```text
data/design/generated_enemy_archetype_pool.tsv
```

字段：

```text
archetype_id
scope
route_type
battle_type
tier
weapon_style
enemy_role
complexity_level
expected_player_realm
preferred_distance_min
preferred_distance_max
primary_checks
secondary_checks
tactic_role_ratio
recommended_deck_variant_count
visual_identity_hint
forbidden_tags
discouraged_tags
source_requirement_id
notes
```

## 当前不做

- 不生成具体卡组。
- 不生成具体卡牌。
- 不修改战斗运行时。
- 不接入 LLM API。

## 运行生成器

```bash
python3 tools/content_engine/enemy_archetype_generator.py \
  --design-dir data/design \
  --out data/design/generated_enemy_archetype_pool.tsv
```

## 运行校验器

```bash
python3 tools/content_engine/enemy_archetype_validator.py \
  --design-dir data/design
```

## 进入 v0.3

v0.3 建议实现 `enemy_deck_skeleton_generator`，输入 `generated_enemy_archetype_pool.tsv` 并生成 deck skeleton。v0.3 仍保持设计层，不直接写运行时。
