# 叙事流程与海疆大势图

本文档承接 [NARRATIVE.md](NARRATIVE.md) 中拆出的可变流程清单：默认 flow、武举人物关系、旧线性正篇拆入随机池、剧情战斗映射和海疆大势图运行态。

## 当前默认流程

默认 flow 共 36 个节点。开局已调整为：

```text
小组试枪
→ 小组试刀
→ 淘汰定器
→ 顾承岳
→ 沈照夜
→ 戚衡
→ 武科放榜
→ 海疆大势图入口
→ 军门任差（兼容后移）
```

武举开局规则：

- `wuke_group_spear_trial`、`wuke_group_blade_trial` 是临时路线教学战，不写入正式 `career_choice`。
- `wuke_elim_route_choice` 才正式写入 `career_choice`。
- `wuke_elim_gu_chengyue_battle`、`wuke_elim_shen_zhaoye_battle`、`wuke_elim_qi_heng_battle` 读取正式路线。
- `world_map_entry` 是武举后进入海疆大势图的正式入口节点。
- 三名淘汰赛对手已进入长期叙事状态，后续可在海疆大势图随机剧情中引用。

当前 flow：

```text
10  wuke_group_spear_trial
20  wuke_group_blade_trial
30  wuke_elim_route_choice
40  wuke_elim_gu_chengyue_battle
50  wuke_elim_shen_zhaoye_battle
60  wuke_elim_qi_heng_battle
70  wuke_after_choice
80  world_map_entry
90  military_order
100 ch2_sea_route_unusual
110 ch2_beach_tracks
120 ch2_reed_ambush_battle
130 ch2_reed_ambush_aftermath
140 ch2_silent_village
150 ch2_night_signal_fire
160 ch3_firearm_marking
170 ch3_sealed_crate
180 ch3_escort_silence
190 ch3_escort_clash_battle
200 ch3_escort_aftermath
210 ch3_burned_storehouse
220 ch3_official_notice
230 ch4_tide_reveals_marks
240 ch4_old_anchor_chain
250 ch4_master_hesitation
260 ch4_tide_bandits_battle
270 ch4_tide_aftermath
280 ch4_hidden_document
290 ch4_master_silence
300 boss_ext_burning_ship_sighting
310 boss_ext_hold_full_of_crates
320 boss_ext_master_freeze_arrow
330 boss_ext_wakou_leader_battle
340 boss_ext_aftermath_choice
350 military_coverup
```

## 武举人物关系变量

| 对手 | 变量 | 方向 | 当前收益 |
|---|---|---|---|
| 顾承岳 | `rival_gu_bond` | 军门 / 官路互信 | 淘汰赛一战后默认 +1；放榜选择“接军门荐书”额外 +1 |
| 沈照夜 | `rival_shen_bond` | 江湖 / 民间信任 | 淘汰赛二战后默认 +1；放榜选择“去人群中找沈照夜”额外 +1 |
| 戚衡 | `rival_qi_bond` | 劲敌 / 同袍 / 旧案信任 | 淘汰赛三战后默认 +1；放榜选择“追问戚衡”额外 +1 |

放榜三选一：

| 选择 | 主收益 | 人物关系 |
|---|---|---|
| 接军门荐书 | `military_merit +2` | `rival_gu_bond +1` |
| 去人群中找沈照夜 | `clean_reputation +2` | `rival_shen_bond +1` |
| 追问戚衡 | `case_clues +2` | `rival_qi_bond +1` |

这些变量暂不直接参与 9 结局判定。后续可接入旧案隐藏证言、军门堂证、清望证言或随机剧情节点权重。

## 旧线性正篇拆入随机池

第一批已拆入 `tables/map_node_pool.tsv` 的节点：

| 原线性节点 | 随机池节点 | 主线 | 副线 | 定位 |
|---|---|---|---|---|
| `military_order` | `map_military_patrol_order_01` | `military_merit` | `case_clues` | 军令巡海 |
| `ch2_sea_route_unusual` | `map_case_sea_route_unusual_01` | `case_clues` | `military_merit` | 海路异常 |
| `ch2_beach_tracks` | `map_case_beach_tracks_01` | `case_clues` | `clean_reputation` | 滩涂脚印 |
| `ch2_reed_ambush_battle` | `map_combat_reed_ambush_01` | `military_merit` | `case_clues` | 芦苇伏击 |
| `ch2_silent_village` | `map_reputation_silent_village_01` | `clean_reputation` | `case_clues` | 无声渔村 |
| `ch2_night_signal_fire` | `map_case_night_signal_fire_01` | `case_clues` | `military_merit` | 夜火信号 |
| `ch3_firearm_marking` | `map_case_firearm_marking_01` | `case_clues` | `military_merit` | 火器刻痕 |
| `ch3_escort_clash_battle` | `map_combat_escort_clash_01` | `military_merit` | `case_clues` | 押运冲突 |

本轮仅在 tags 中预留人物 hook，不实现人物变体文案系统。不改变 `final_boss_rules.tsv`，不改变 9 结局判定，不关闭旧线性正篇 flow。

旧压缩节点保留为节点池，不进入默认 flow。

## 剧情战斗映射

| 节点 | encounter | battle_id | 玩家覆写 |
|---|---|---|---|
| `master_arrives` | `enc_prologue_master_rescue` | `prologue_master_rescue` | `false` |
| `beach_ambush` | `enc_beach_ambush` | `first_act_beach_ambush` | `true` |
| `fishing_village_embers` | `enc_fishing_village_embers` | `first_act_fishing_village_embers` | `true` |
| `transport_officer` | `enc_transport_officer` | `first_act_transport_officer` | `true` |
| `mutiny_camp` | `enc_mutiny_camp` | `first_act_mutiny_camp` | `true` |
| `wakou_boss` | `enc_wakou_boss` | `first_act_wakou_boss` | `true` |
| `wuke_group_spear_trial` | `enc_wuke_spear_trial` | `wuke_spear_trial` | `true` |
| `wuke_group_blade_trial` | `enc_wuke_blade_trial` | `wuke_blade_trial` | `true` |
| `wuke_elim_gu_chengyue_battle` | `enc_wuke_gu_chengyue` | `wuke_gu_chengyue` | `true` |
| `wuke_elim_shen_zhaoye_battle` | `enc_wuke_shen_zhaoye` | `wuke_shen_zhaoye` | `true` |
| `wuke_elim_qi_heng_battle` | `enc_wuke_qi_heng` | `wuke_qi_heng` | `true` |
| `ch2_reed_ambush_battle` | `enc_ch2_reed_ambush` | `chapter2_reed_ambush` | `true` |
| `ch3_escort_clash_battle` | `enc_ch3_escort_clash` | `chapter3_escort_clash` | `true` |
| `ch4_tide_bandits_battle` | `enc_ch4_tide_bandits` | `chapter4_tide_bandits` | `true` |
| `boss_ext_wakou_leader_battle` | `enc_boss_ext_wakou_leader` | `boss_ext_wakou_leader` | `true` |

武举 `wuke_group_spear_trial` / `wuke_group_blade_trial` 使用 `temporary_player_role` 做临时路线覆写时，临时 profile 必须显式提供合法的 `owned_card_ids` 与 `selected_loadout_ids`；`selected_loadout_ids` 必须正好 8 张且满足同名卡数量上限。

## 海疆大势图运行态

当前最小闭环：

```text
world_map_entry
→ region_01 layer_1
→ 生成候选
→ 玩家选择节点
→ 应用事件或进入战斗
→ 返回大势图下一层
```

当前实现：

- 大势图入口接入 `world_map_entry`。
- region / layer 候选节点生成与三选一执行。
- 非战斗节点执行 `effects_json`。
- 战斗节点触发 StoryBattle，胜利后回到大势图并推进层数。
- 战斗返回大势图时保留叙事变量、职业与武举关系变量。
- `network_map` UI 优先显示完整网络图；旧 `current_map` 候选渲染保留为 fallback。

当前边界：

- 区域 Boss / final gate 尚未完整接入。
- `combat_pool_id -> combat_enemy_pools.tsv -> enemy_martial_stats.tsv` 全链路随机敌仍待补齐。
- `final_boss_rules.tsv` 尚未完整接入。

## network_map 结构

`strategic_state.network_map` 包含：

```text
seed
layer_count
current_layer
selected_node_id
completed_node_ids
available_node_ids
pending_map_node_id
nodes
```

节点包含：

```text
map_graph_id
pool_node_id
layer
lane
x / y
title
node_type
primary_line / secondary_line
preview_text / result_text
effects
tags
combat_pool_id
encounter_id / battle_id
incoming / outgoing
state
```

推进安全规则：

- 路径推进只使用唯一的 `map_graph_id`。
- `pool_node_id` 可以重复，但不参与 completed / available 判断。
- 节点完成后过滤不存在、已完成、已 unreachable 的 outgoing。
- 如果没有有效 available 节点，设置 `map_complete=true`。
- `map_complete=true` 时 UI 显示临时 final gate 或“海图暂止”面板。

## Debug 入口

主界面开发入口“海疆大势图 Debug”可不经过武举流程直接进入 `NarrativeDemo` 的大势图运行态。

该入口通过 `NarrativeBattleContext` 一次性 debug entry 触发，进入后自动注入临时占位 player profile（默认 `spearman`、武境 1、合法 8 张卡）。该入口不写入正式 `career_choice`，不替代正式 `world_map_entry`。
