# 站位占位牌组与数值（敌我）

本文档提供一套“占位牌组 + 数值”的占位配置，用于新生产战斗与“站位约束”场景。  
新生产的战斗若无明确约束，默认优先使用本占位牌组与数值；若需求明确指定其他方案，再按需求覆盖。

## 使用边界

- 新生产战斗在无明确约束时，默认使用本方案（牌组 + 数值）。
- 仅在以下条件不使用本方案：
`notes`、任务单、或需求文本中明确指定其他 encounter / 牌组 / 数值方案。
- 启用时只改 `story_encounters.tsv` 中某一条或新增一条测试 encounter，不批量覆盖。

## 设计目的

- 玩家：稳定中距离站位，验证“先站位再出牌”的可读性。
- 敌方：稳定逼近与控边，验证玩家站位选择是否有效。
- 数值：避免极端爆发，优先观察位移、距离与回合节奏。

## 推荐数值集（fighter_stat_sets.tsv）

新增两条：

```tsv
stat_set_id	display_name	max_hp	max_momentum	starting_momentum	starting_realm	qinggong	notes
stance_player_probe	站位测试·玩家	26	8	5	1	2	站位约束测试专用；中等容错
stance_enemy_probe	站位测试·敌方	30	8	5	1	2	站位约束测试专用；轻压迫
```

说明：

- `qinggong=2`：让双方都能体现“换位决策”。
- `starting_realm=1`：不引入高武境变量，先看站位机制本身。

## 推荐牌组集（story_deck_sets.tsv）

新增两条（每套固定 8 张）：

```tsv
story_deck_id	display_name	fighter_template_id	deck	tags	notes
player_stance_probe	站位测试·玩家8张	player_spearman	spear_mid_thrust:2,spear_line_press:2,spear_retreat_sting:1,spear_step_thrust:1,spear_focus:1,spear_guard_horse:1	stance_test,player	站位测试专用；2-3格控距+有限前后位移
enemy_stance_probe	站位测试·敌方8张	reed_ambusher	spear_mid_thrust:2,spear_line_press:2,spear_step_thrust:2,spear_guard_horse:1,spear_retreat_sting:1	stance_test,enemy	站位测试专用；持续压线但不过度爆发
```

## 推荐 encounter（story_encounters.tsv）

新增一条，仅用于测试入口：

```tsv
encounter_id	display_name	player_template_id	player_deck_id	player_stat_set_id	opponent_template_id	opponent_deck_id	opponent_stat_set_id	settlement_mode	pressure_profile	intent_visibility_policy	notes
enc_stance_probe	站位约束测试	player_spearman	player_stance_probe	stance_player_probe	reed_ambusher	enemy_stance_probe	stance_enemy_probe	reactive	edge_pressure	full	新生产战斗默认可用；有明确约束时按约束覆盖
```

## 启用/回退规则

- 启用：新生产战斗默认选 `enc_stance_probe`，或在剧情节点里引用同等占位牌组与数值方案。
- 回退：移除剧情引用并切回原 encounter；保留本表项供后续复用。
- 不做的事：不修改 `scripts/card_data.gd`，不新增资源线，不改结算模式。
