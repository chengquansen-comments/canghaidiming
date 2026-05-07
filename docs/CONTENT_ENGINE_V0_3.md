# Content Engine v0.3

## 目标

v0.3 目标是根据 v0.2 的 enemy archetype 池生成敌人 deck skeleton 表，进入“敌人卡组骨架层”。

本阶段只定义卡组规模、卡牌角色计数、武器与标签约束、AI 使用提示和奖励压力级别，不填具体 `card_id`。

## 输入文件

```text
data/design/generated_enemy_archetype_pool.tsv
data/design/generated_enemy_deck_requirement.tsv
data/design/generated_battle_slot_plan.tsv
```

## 输出文件

```text
data/design/generated_enemy_deck_skeleton.tsv
```

字段：

```text
deck_skeleton_id
archetype_id
scope
route_type
battle_type
tier
variant_index
deck_variant_role
weapon_style
expected_player_realm
complexity_level
target_card_count
attack_card_count
guard_card_count
movement_card_count
posture_break_card_count
tempo_card_count
combo_card_count
special_card_count
preferred_distance_min
preferred_distance_max
tactic_role_ratio
required_card_tags
forbidden_card_tags
ai_behavior_hint
reward_pressure_level
source_archetype_id
source_requirement_id
notes
```

## 字段说明

- `deck_skeleton_id`：敌人卡组骨架 ID，例如 `enemy_<archetype_id>_basic`、`enemy_<archetype_id>_elite_advanced`、`boss_<archetype_id>_phase_1`、`exam_<archetype_id>`。
- `deck_variant_role`：骨架变体定位，例如 `basic`、`advanced`、`aggressive`、`defensive`、`phase_1`、`phase_2`、`exam_standard`、`exam_final`。
- `target_card_count`：卡组骨架规模，不代表已经存在的正式卡牌。
- `*_card_count`：攻击、防御、移动、破架、节奏、连招、特殊等角色槽位数量。后续具体卡牌可一牌多用，因此合计允许略高于 `target_card_count`。
- `required_card_tags`：后续填牌必须满足的标签集合，例如 `weapon_spearman,role_control,role_break`。
- `forbidden_card_tags`：后续填牌不得使用的标签集合，例如 `boss_only,true_boss_only,player_only,weapon_mismatch`。
- `ai_behavior_hint`：短字符串形式的 AI 行为提示。
- `reward_pressure_level`：奖励压力级别，当前使用 `low`、`medium`、`high`、`boss`、`exam`。
- `source_archetype_id` / `source_requirement_id`：保留来源链路，方便 v0.4 继续填具体 deck set。

## 当前不做

- 不填具体 `card_id`。
- 不生成正式敌人 deck。
- 不生成正式卡牌。
- 不修改 Godot 战斗运行时。
- 不接入 LLM API。

## 运行生成器

```bash
python3 tools/content_engine/enemy_deck_skeleton_generator.py \
  --design-dir data/design \
  --out data/design/generated_enemy_deck_skeleton.tsv
```

## 运行校验器

```bash
python3 tools/content_engine/enemy_deck_skeleton_validator.py \
  --design-dir data/design
```

校验器会检查 ID 唯一性、archetype 覆盖、普通 / 精英 / Boss / 武状元数量、卡组规模、角色计数组合、复杂度、武器标签匹配，以及轻功 4 是否被错误写成硬门槛。

## 进入 v0.4

v0.4 建议拆成两步：

- `card_pool_generator`：根据 `docs/COMBAT_CARD_GRAMMAR_V1.md` 和 design 表生成或筛选可用卡池。
- `enemy_deck_sets_generator`：根据 v0.3 skeleton 和 Combat Card Grammar 填具体卡牌，生成敌人 deck set。

v0.4 仍应保持设计层优先，先生成和校验 TSV，再考虑 runtime exporter。
