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

## 武举三锚点与 AIGC 剧情池

目标：把武举三名淘汰赛对手升级为海疆大势图的长期剧情锚点。武举仍在 `world_map_entry` 之前完成；大地图不展示武举战斗，但会在武举后根据三人的关系变量、路线倾向和 AIGC story beat 池生成后续剧情。

三条长期路线：

| 路线 | 武举锚点 | 主收益 | 主代价 | 叙事核心 |
|---|---|---|---|---|
| 军功线 | 沈照夜 | 官职、军令、兵力、升迁 | 民怨、压案、被军门裹挟 | 主角是否用功名换秩序 |
| 清望线 | 顾承月 / 顾成岳 | 民心、声名、顾承月感情线、民间支援 | 身份风险、舆论压力、军门不信任 | 主角是否尊重她的真实选择 |
| 旧案线 | 齐衡 | 证据、真相、隐藏路线 | 升官受阻、牵连旧人、敌人反扑 | 真相公开会伤到谁 |

顾承月规则：

- 武举阶段公开身份使用 `顾成岳`；身份揭露后显示为 `顾承月`。
- 她不是单纯的清望奖励，而是会评价主角选择的长期角色。
- 感情线由 `gu_trust`、`gu_affection`、`gu_identity_known`、`gu_identity_public_risk` 共同决定。
- 身份揭露必须有多路径：主角早知并遮掩、主角晚知但尊重她、敌人揭穿、官府借题发挥、旧案牵连。

核心变量：

| 变量 | 用途 |
|---|---|
| `route_bias_military` | 军功线倾向 |
| `route_bias_reputation` | 清望线倾向 |
| `route_bias_old_case` | 旧案线倾向 |
| `shen_respect` | 沈照夜对主角的军中认可 |
| `shen_suspicion` | 沈照夜对主角追查旧案或偏向民间的疑心 |
| `gu_trust` | 顾承月信任 |
| `gu_affection` | 顾承月感情线温度，早期不直接明示 |
| `gu_identity_known` | 主角是否知道顾承月真实身份 |
| `gu_identity_public_risk` | 顾承月身份暴露风险 |
| `qi_trust` | 齐衡是否愿意交关键证据 |
| `truth_progress` | 旧案真相进度 |
| `military_rank_progress` | 升官进度 |
| `public_reputation` | 清望与民心 |

武举写入规则：

| 事件 | 建议效果 |
|---|---|
| 击败沈照夜且留足体面 | `shen_respect +1`、`route_bias_military +1` |
| 用强硬官路姿态压过沈照夜 | `route_bias_military +1`、`shen_suspicion +1` |
| 发现顾成岳身份破绽并替她遮掩 | `gu_trust +1`、`gu_identity_known=true`、`route_bias_reputation +1` |
| 公开利用顾承月身份换取优势 | `gu_identity_public_risk +2`、`gu_trust -1`、`route_bias_military +1` |
| 接受齐衡旧案线索 | `qi_trust +1`、`truth_progress +1`、`route_bias_old_case +1` |
| 拒绝齐衡但保留余地 | `shen_respect +1`、`qi_trust` 不变 |

三线互相影响：

| 状态 | 影响 |
|---|---|
| 军功高 | 升官更快，军令节点和兵力节点权重提高；`public_reputation` 和 `truth_progress` 可能受压 |
| 清望高 | 民间线索和顾承月节点权重提高；`gu_identity_public_risk` 更容易被推高 |
| 旧案高 | 真相节点和隐藏路线权重提高；`military_rank_progress` 可能受阻 |
| `gu_trust` 高 | 清望线、感情线和部分真相线打开 |
| `shen_respect` 高 | 军功资源打开，但沈照夜会阻止主角触碰军门旧账 |
| `qi_trust` 高 | 关键证据打开，但旧案可能把顾承月卷入身份风险 |

### AIGC story beat schema

剧情 AIGC 必须生成结构化 story beat，不直接把散文案塞进 runtime。每个 beat 至少包含：

```json
{
  "story_beat_id": "beat_reputation_gu_identity_mid_001",
  "route_line": "reputation",
  "npc_focus": "gu_chengyue",
  "phase": "mid",
  "node_type": "reputation",
  "requirements": {
    "gu_trust_min": 2,
    "gu_identity_known": true,
    "military_rank_progress_max": 3
  },
  "effects": {
    "public_reputation": 1,
    "gu_affection": 1,
    "gu_identity_public_risk": 1
  },
  "exclusive_group": "gu_identity_reveal_mid",
  "cooldown_group": "gu_private_scene",
  "cooldown_turns": 2,
  "weight": 100,
  "preview_text": "...",
  "result_text": "...",
  "followup_hooks": ["gu_identity_pressure", "old_case_implicates_gu"]
}
```

runtime 选择规则：

- 先按 `phase`、`route_line`、`requirements` 过滤。
- 再排除已触发的 `exclusive_group` 和冷却中的 `cooldown_group`。
- 再按 `weight` 抽取，避免同一路线连续刷出同质节点。
- `preview_text` 用于大地图右侧批注，`result_text` 用于节点完成反馈。
- `effects` 写回叙事变量，作为后续节点和结局条件。

### 内容规模与重玩目标

10 次以上重玩需要结构化内容池，而不是少量固定文案。目标池：

| 内容池 | 基础 beat 数 |
|---|---:|
| 固定主线 / 序章 / 武举骨架 | 25-35 |
| 军功线 | 45-60 |
| 清望线 | 45-60 |
| 旧案线 | 45-60 |
| 三线交叉冲突 | 50-70 |
| 三名对手专属事件 | 60-90 |
| 顾承月身份与感情节点 | 25-35 |
| 结局前置与结局 | 30-45 |

MVP 先接 62 个结构化 beat：

| MVP 池 | 数量 |
|---|---:|
| 军功线 | 12 |
| 清望线 | 12 |
| 旧案线 | 12 |
| 三线交叉 | 12 |
| 顾承月身份 / 感情 | 8 |
| 结局前置 | 6 |

扩容目标：300 个基础 beat，每个 beat 允许 2-3 个文案变体，实际可见文本规模约 600-900 条。

### 结局组合

结局不只看最高路线，而要看组合条件：

| 条件 | 结局方向 |
|---|---|
| 军功高，旧案低 | 升官平倭，但真相被压 |
| 清望高，顾承月信任高 | 民心结局 / 顾承月同行 |
| 旧案高，齐衡信任高 | 真相结局 |
| 军功高，旧案也高 | 军门内斗结局 |
| 清望高，身份风险爆表 | 顾承月身份风波结局 |
| 三线均衡且关键 NPC 信任达标 | 真结局 |
| 军功过高且牺牲顾承月 | 高官孤行结局 |
| 旧案公开但清望不足 | 真相被污名化结局 |

### 实施阶段

1. 剧情系统定型：落 `story_beat` schema、路线变量、三名 NPC 变量、互斥和冷却规则。
2. 武举写变量：三名对手战斗结算写入 `shen / gu / qi` 关系变量，不再只写 `career_choice`。
3. MVP 剧情池：生成并接入 62 个结构化 beat，覆盖三线、交叉、顾承月身份、结局前置。
4. 大地图接入：大地图节点从 story beat pool 抽取 `preview_text / result_text / effects / requirements`；战斗节点继续接 AIGC loadout。
5. 扩容到 300 beat：AIGC 批量生成后跑重复率、前置可达性、互斥组冲突、结局覆盖校验。
6. 重玩验证：做 10 次自动路线模拟，检查每局节点重复率、三线曝光、结局分布和顾承月身份揭露路径。

验收指标：

| 指标 | 目标 |
|---|---:|
| 单局剧情节点数 | 35-45 |
| 10 局唯一 beat 曝光 | 180+ |
| 前 5 局重复率 | 低于 30% |
| 每条主线可独立通关 | 是 |
| 三线交叉节点每局出现 | 3-6 个 |
| 顾承月身份揭露路径 | 至少 4 种 |
| 结局方向 | 至少 8 个可达 |
| 真结局条件 | 三线均衡 + 三 NPC 关键变量达标 |

### 第一阶段落地状态

已落地内容：

| 模块 | 文件 | 状态 |
|---|---|---|
| 战略状态变量 | `scripts/strategic_map_state.gd` | 已加入三线倾向、三名武举锚点 NPC、顾承月身份/感情、真相/升官/民心变量 |
| story beat 运行时 | `scripts/narrative/aigc_story_beat_runtime.gd` | 已支持 schema 级字段校验、requirements 过滤、exclusive_group、cooldown_group、weighted pick |
| AIGC 数据契约 | `data/aigc_battle/story/story_beat_schema.json` | 已固定 route_line、phase、node_type、requirements/effects 白名单 |
| 种子样例 | `data/aigc_battle/story/story_beat_foundation_samples.json` | 已提供军功、清望/顾承月、旧案、三线交叉 4 个 foundation beat |
| 大地图状态镜像 | `scripts/strategic_network_map_runtime.gd`、`scripts/aigc_dungeon_big_map_loader.gd` | 已同步 story 变量、已触发 beat、互斥组和冷却表，避免 route_state 进入大地图时丢字段 |
| 验证 | `tools/smoke_aigc_story_beat_runtime.gd` | 已覆盖默认字段、effect 写入、requirements、互斥、冷却、weighted pick |

第一阶段不包含的内容：

- 不生成 62 个 MVP beat；这是第二/第三阶段内容。
- 不把武举三名对手的战斗结算写入变量；这是第二阶段内容。
- 不改变大地图节点抽取策略；这是第四阶段内容。
- 不把武举战斗重新塞进大地图；武举仍在 `world_map_entry` 之前完成。

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
- 正式流程仍是“序章战 -> 武举线 -> `world_map_entry`”；武举战斗不再显示在大地图里。
- region / layer 候选节点生成与三选一执行。
- 非战斗节点执行 `effects_json`。
- 战斗节点触发 StoryBattle，胜利后回到大势图并推进层数。
- 战斗返回大势图时保留叙事变量、职业与武举关系变量。
- `network_map` UI 优先显示完整网络图；旧 `current_map` 候选渲染保留为 fallback。
- AIGC dungeon `network_map` 进入正式 runtime 前会先剔除武举节点，并把可见层重新压成连续层号；显示层号不再沿用原始 `node_bigmap_07_*` 之类的 source 编号。

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
source_layer
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
- `layer` 是当前 UI 展示层号与运行推进层号；如果原始图在武举抽离前已有跳层，必须先压缩为连续层。
- `source_layer` 只保留给 debug / 生成追踪，不参与 UI 标号、可选节点计算或推进判断。
- 节点完成后过滤不存在、已完成、已 unreachable 的 outgoing。
- 如果没有有效 available 节点，设置 `map_complete=true`。
- `map_complete=true` 时 UI 显示临时 final gate 或“海图暂止”面板。

当前大地图 UI 口径：

- overlay 标题使用“海防舆图”，语气是武举放榜后启用的军门海防图，而不是抽象 dungeon 图。
- 左侧画布显示完整网络图，右侧显示当前选中节点的批注、预计得失和行动按钮。
- 汛号显示使用压缩后的 `layer`，因此序章后的第一批海防节点显示为“第 3 汛”，不会因武举被抽走而出现“第 8 汛”。
- 节点圆心内只放类型字样；标题显示在节点下方，不与圆心文字混排。

## Debug 入口

主界面开发入口“海疆大势图 Debug”可不经过武举流程直接进入 `NarrativeDemo` 的大势图运行态。

该入口通过 `NarrativeBattleContext` 一次性 debug entry 触发，进入后自动注入临时占位 player profile（默认 `spearman`、武境 1、合法 8 张卡）。该入口不写入正式 `career_choice`，不替代正式 `world_map_entry`。
