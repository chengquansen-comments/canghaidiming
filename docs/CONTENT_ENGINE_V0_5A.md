# Content Engine v0.5a

## 目标

v0.5a 目标是生成设计层战斗奖励规划表：

- `data/design/generated_battle_reward_plan.tsv`

该表基于 battle slot、敌人 deck skeleton、敌人 deck set、路线成长曲线，对每场（或每个候选 deck）给出奖励建议。

## 输入文件

```text
data/design/generated_battle_slot_plan.tsv
data/design/generated_enemy_deck_skeleton.tsv
data/design/generated_enemy_deck_sets.tsv
data/design/generated_enemy_archetype_pool.tsv
data/design/generated_route_progression_curve.tsv
data/design/progression_numeric_config_v1_3.tsv
```

## 输出文件

```text
data/design/generated_battle_reward_plan.tsv
```

## 字段说明

核心字段：

- `reward_plan_id`：奖励规划 ID（固定战斗或按 deck 展开）。
- `battle_slot_id`：对应战斗 slot。
- `deck_id` / `deck_skeleton_id` / `archetype_id`：奖励关联的敌人配置来源。
- `reward_profile`：奖励模板类型（`normal_standard`、`elite_high`、`true_boss`、`wuzhuangyuan_final` 等）。
- `martial_xp_reward` / `weapon_xp_reward` / `military_merit_reward`：成长核心奖励。
- `clean_reputation_reward` / `old_case_progress_reward`：路线叙事相关资源（本阶段只做数字规划）。
- `lightness_reward_type` / `lightness_cap_unlock`：轻功奖励与上限规划。
- `can_trigger_realm_10` / `can_trigger_wuzhuangyuan_route`：路线分流触发标记。
- `source_route_checkpoint`：奖励挂接到路线曲线检查点。

## 奖励生成规则

1. 固定战斗（序章 / 武举 / Boss / 武状元）单独生成固定奖励行。  
2. `big_map_normal_pool` 按 22 个 normal deck 展开奖励行。  
3. `big_map_elite_pool` 按 8 个 elite deck 展开奖励行。  
4. Boss 按 v0.4b 的 4 个 boss deck 生成奖励行。  
5. 武状元考试按 5 个 exam deck 生成奖励行。  

## 路线成长目标

- 普通路线估算应落在约 `140 martial_xp`，对应 8-9 境。  
- 精英路线估算应稳定达到 10 境（约 `154 martial_xp`）。  
- 武状元考试奖励继续增长，但不改变武境上限目标。  

## 轻功稀缺规则

- 普通路线与普通 Boss 不超过 `cap_2`。  
- `cap_4` 只应出现在极稀缺奖励行（例如武状元终试）。  
- `rare_breakthrough` 行数应非常少。  

## validator 检查项

`battle_reward_validator.py` 检查：

- 文件存在性、ID 唯一性、deck 引用合法性。  
- battle/reward 枚举合法性。  
- XP 与核心奖励字段有效性。  
- normal/elite/boss/wuzhuangyuan 奖励分布。  
- 普通路线与精英路线 martial_xp 估算。  
- 轻功上限、稀缺突破、武状元触发标记约束。  

## 当前不做

- 不生成经营节点。  
- 不生成叙事节点。  
- 不生成 route gate。  
- 不写运行时 reward。  
- 不修改 story battle TSV。  
- 不接 LLM API。  

## 运行 generator

```bash
python3 tools/content_engine/battle_reward_generator.py \
  --design-dir data/design \
  --out data/design/generated_battle_reward_plan.tsv
```

## 运行 validator

```bash
python3 tools/content_engine/battle_reward_validator.py \
  --design-dir data/design
```

## 进入 v0.5b

v0.5b 建议继续设计层拆分：

- `operation_node_generator`
- `narrative_node_generator`
- `route_gate_generator`

先保持 TSV 生成 + validator 闭环，再进入运行时导出阶段。
