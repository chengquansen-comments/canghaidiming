# 《大明之沧海嘀鸣》叙事总文档

本文档是当前叙事工作的唯一活跃入口。旧脚本稿、压缩版记录、安全线进度与 AI 生成协议已经归档到 `archive/docs/narrative/`，只作为历史参考。

## 当前结论

叙事运行链路：

```text
tables/*.tsv
→ scripts/compile_tables.py
→ data/*.json
→ scenes/NarrativeDemo.tscn / scenes/MainVisual.tscn
```

不要直接编辑 `data/*.json`。运行 JSON 是编译产物。

当前正篇叙事源只保留两个正式 TSV：

```text
tables/narrative_mvp_nodes.tsv
tables/narrative_mvp_node_status.tsv
```

`tables/narrative_mvp_expansion_*.tsv` 已归档，不再作为运行输入。后续即使有章节概念，也只写在 `node_status` 的 `column` / `type` / 后续 tag 字段中，不再按章节拆文件。

## 活跃源表

### 序章

```text
tables/narrative_mvp_prologue_steps.tsv
tables/narrative_mvp_prologue.tsv
tables/narrative_mvp_career_choices.tsv
```

用途：

- 序章十二拍
- 师父救场战触发
- 出山过场衔接（不再在序章内选刀枪）
- 玩家初始职业与战斗 profile

### 正篇节点

```text
tables/narrative_mvp_nodes.tsv
```

关键字段：

```text
order
id
title
scene
text
dialogue_json
combat_json
choices_json
```

写法规则：

- `text` 保持一句一继续。
- `scene` 是场景一句话，不写成长篇说明。
- `choices_json` 写选择、收益、战斗触发和结果文案。
- 战斗节点也必须有可点击 choice；不要只写 node-level `combat_json` 后留下空 `choices_json`。
- 多个选择指向同一战斗时，优先拆成“战斗触发节点 + 战后处理节点”。

### 节点状态与流程

```text
tables/narrative_mvp_node_status.tsv
```

关键字段：

```text
id
flow_enabled
flow_order
column
type
visual_path
implementation_status
note
```

规则：

- `flow_enabled=true` 的节点必须有 `flow_order`。
- `flow_node_ids` 只由 `flow_enabled=true` 的节点按 `flow_order` 生成。
- 旧压缩节点可以保留在节点池，但设为 `reserved`，不进默认 flow。
- `visual_path` 必须是可加载的 `res://` 资源。

## 当前默认流程

默认 flow 共 36 个节点。

开局已调整为：小组试枪 → 小组试刀 → 淘汰定器 → 顾承岳 → 沈照夜 → 戚衡 → 武科放榜 → 海疆大势图入口 → 军门任差（兼容后移）。

武举开局规则：
- `wuke_group_spear_trial`、`wuke_group_blade_trial` 是临时路线教学战，不写入正式 `career_choice`。
- `wuke_elim_route_choice` 才正式写入 `career_choice`。
- `wuke_elim_gu_chengyue_battle`、`wuke_elim_shen_zhaoye_battle`、`wuke_elim_qi_heng_battle` 读取正式路线。
- `world_map_entry` 目前是叙事入口占位，不接入随机大地图运行时。
- 三名淘汰赛对手已进入长期叙事状态，后续可在海疆大势图随机剧情中引用。

武举开局现在分为小组赛与淘汰赛：

1. 小组试枪：临时枪路线体验，不写入正式 `career_choice`。
2. 小组试刀：临时刀路线体验，不写入正式 `career_choice`。
3. 淘汰定器：正式选择 `spearman` / `blademaster`，并写入 `career_choice`。
4. 淘汰赛一：顾承岳，军门 / 军功 / 官路型对手。
5. 淘汰赛二：沈照夜，江湖 / 清望 / 民间型对手。
6. 淘汰赛三：戚衡，主劲敌 / 旧案 / 后续至交候选。
7. 武科放榜：三选一，分别强化军门、民间、旧案方向。
8. 海疆大势图入口：当前为占位，后续接入随机大地图。

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

武举淘汰赛的三名对手会进入长期叙事状态：

- 顾承岳：`rival_gu_bond`
  - 军门同僚 / 官路互信。
  - 后续可解锁军令同行、争功让功、堂上作证类节点。
  - 淘汰赛一战后默认 +1；放榜选择“接军门荐书”额外 +1。

- 沈照夜：`rival_shen_bond`
  - 江湖 / 民间信任。
  - 后续可解锁护民、盐户证言、江湖传名类节点。
  - 淘汰赛二战后默认 +1；放榜选择“去人群中找沈照夜”额外 +1。

- 戚衡：`rival_qi_bond`
  - 主劲敌 / 同袍可能 / 旧案信任。
  - 后续可解锁巡海重逢、奉令再斗、旧案证言、至交节点。
  - 淘汰赛三战后默认 +1；放榜选择“追问戚衡”额外 +1。

放榜三选一不再只是抽象收益，而是第一次主动选择靠近哪一名武举对手：

| 选择 | 主收益 | 人物关系 |
|---|---|---|
| 接军门荐书 | `military_merit +2` | `rival_gu_bond +1` |
| 去人群中找沈照夜 | `clean_reputation +2` | `rival_shen_bond +1` |
| 追问戚衡 | `case_clues +2` | `rival_qi_bond +1` |

后续使用边界：

- 本轮仅接入人物关系变量，不改变随机大地图生成规则。后续 Step 8/9 会在 `map_node_pool.tsv` 中使用 `rival_*_bond` 作为随机剧情节点条件或权重来源。
- 这些变量暂不直接参与 9 结局判定。后续可以将高 `rival_qi_bond` 接入旧案隐藏证言或至交节点，将高 `rival_gu_bond` 接入军门堂证节点，将高 `rival_shen_bond` 接入清望证言节点。

旧压缩节点保留为节点池，不进入默认 flow：

```text
beach_ambush
beach_ambush_aftermath
fishing_village_embers
fishing_village_embers_aftermath
merchant_banquet
ming_firearm
altered_military_report
transport_officer
transport_officer_aftermath
mutiny_camp
mutiny_camp_aftermath
military_messenger
night_knife_camp
wakou_boss
wuke_spear_trial
wuke_blade_trial
wuke_route_choice
wuke_final_duel
```

## 战斗叙事接入

战斗总口径见 `docs/BATTLE.md`。叙事层只负责“哪个节点触发哪场战斗”，不直接维护敌我数值和卡组。

叙事战斗可由节点级 `combat_json` 或 choice 的 `combat` 触发：

```json
{
  "label": "迎战",
  "combat": {
    "enabled": true,
    "encounter_id": "enc_ch2_reed_ambush",
    "battle_id": "chapter2_reed_ambush",
    "override_player_profile": true
  },
  "result": "枪尖折进沙里。\n潮声又回来了。"
}
```

相关源表：

```text
tables/narrative_mvp_prologue_steps.tsv
tables/narrative_mvp_nodes.tsv
data/story_battles/fighter_templates.tsv
data/story_battles/fighter_stat_sets.tsv
data/story_battles/story_deck_sets.tsv
data/story_battles/story_encounters.tsv
tables/battle_scene_manifest.tsv
```

字段规则：

| 字段 | 规则 |
|---|---|
| `encounter_id` | 必须存在于 `data/story_battles/story_encounters.tsv` |
| `battle_id` | 必须存在于 `tables/battle_scene_manifest.tsv` |
| `override_player_profile` | 必填布尔值；`true` 表示用剧情主角选择和成长覆写玩家配置，`false` 表示保留 StoryBattle 配置 |

当前正式剧情战斗映射：

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

规则：

- 敌我模板、数值、卡组、结算模式来自 `data/story_battles/*.tsv`。
- `battle_id` 只负责视觉场景，不负责战斗数值。
- 不在 UI 控制器里硬写剧情战敌人和卡组。
- 武举 `wuke_group_spear_trial` / `wuke_group_blade_trial` 使用 `temporary_player_role` 做临时路线覆写时，临时 profile 必须显式提供合法的 `owned_card_ids` 与 `selected_loadout_ids`；其中 `selected_loadout_ids` 必须正好 8 张且满足同名卡数量上限，否则 `_start_battle()` 会因入战牌组不合法拒绝开战。
- `tables/enemy_manifest_*.tsv` / `data/enemy_manifest.json` 是旧剧情战斗、AI 和 debug 兼容层，不再是正式剧情战斗主源。
- 剧情武器意象要和 StoryBattle 卡组一致。例如枪手写“枪锋”，刀客写“刀光”。

## 海疆大势图随机战斗

随机节点源表：

```text
tables/map_node_pool.tsv
tables/map_generation_rules.tsv
tables/final_boss_rules.tsv
tables/combat_enemy_pools.tsv
tables/enemy_martial_stats.tsv
```

随机战斗节点不直接绑定某一个固定敌人，而是绑定“一类战斗 / 一类敌人”。节点字段：

| 字段 | 规则 |
|---|---|
| `combat_pool_id` | 敌类池，例如 `spear_patrol`、`coastal_veteran`、`military_elite`、`old_case_elite` |
| `recommended_martial_min` | 推荐玩家武境下限 |
| `recommended_martial_max` | 推荐玩家武境上限 |
| `enemy_martial_level` | 该敌类在本节点使用的敌方武境，不要求等于玩家武境 |

运行原则：

- 大势图刷新当前层随机战斗候选时，根据玩家当前武境筛选 `recommended_martial_min` 到 `recommended_martial_max` 内的节点。
- 进入随机战斗时，我方数值使用当前玩家武境推导出的 HP、轻功、势上限。
- 敌方先根据 `combat_pool_id` 从 `tables/combat_enemy_pools.tsv` 抽取具体敌人模板和牌组，再使用节点携带的 `enemy_martial_level` 到 `tables/enemy_martial_stats.tsv` 套用敌方 HP、轻功、势上限和起始势。
- 敌方武境可以低于、等于或高于玩家武境。
- 剧情线战斗仍保留 `override_player_profile` 口径；需要剧情指定我方数值时，由剧情战斗请求覆写玩家配置。

## 结局

结尾节点：

```text
military_coverup
```

最终选择通过 `choices_json.effects.ending_flag` 标记本次结局：

```text
truth_report
private_investigation
merit_cover
silence
```

运行时会显示结局结算弹窗：

- 当前结局标题和文案
- 当前结局评价
- 军功 / 清望 / 旧案线索
- 已解锁结局与未解锁结局列表
- 确认按钮

结局文案设计原则：

- 真结局不追加反问。真结局代表本局已经完成“军功让你进堂，旧案让你说话，清望让别人敢信”的完整闭环。
- 非真结局必须留下未竟感，文案末尾追加反问。
- 旧案类非真结局追加：`然而这就是事情的真相吗？`
- 非旧案类非真结局追加：`然而这就是你想要的吗？`
- 当前旧案类非真结局包括：`堂审翻案`、`清望昭雪`、`私查真相`、`孤证难鸣`。
- 当前非旧案类非真结局包括：`封海得众`、`军功升迁`、`武境破围`、`表层平倭`。

第一幕旧结局文案目前在 `scripts/narrative_demo_canonical_controller.gd` 中维护；海疆大势图 9 结局文案目前在 `scripts/narrative_demo_ui_focus_tuned_controller.gd` 中维护。若后续要彻底表驱动，可新增结局 TSV，再由 `compile_tables.py` 编译进入运行时数据。

## AI 节点生成协议

AI 可以辅助生成 `tables/narrative_mvp_nodes.tsv` 的单个节点内容，但必须遵守以下边界：

- 只生成叙事节点内容，不决定运行架构。
- 不生成敌人数值、卡组、美术资源、演出 timeline。
- `text` 和 `result` 不直接写“军功+1”这类数值提示。
- 数值变化只写在结构化 `effects` 字段。
- 战斗和战后选择分离。
- 输出必须能落入 TSV 字段。

最小输出结构：

```json
{
  "order": 0,
  "id": "node_id",
  "title": "标题",
  "scene": "一句场景",
  "text": "一句。\n\n一句。\n\n一句。",
  "dialogue_json": [],
  "combat_json": {"enabled": false},
  "choices_json": []
}
```

## 修改流程

常规叙事改动：

```text
1. 修改 tables/narrative_mvp_nodes.tsv
2. 必要时修改 tables/narrative_mvp_node_status.tsv
3. 如涉及战斗，补 data/story_battles/*.tsv 与 battle_scene_manifest.tsv
4. 运行 python3 scripts/compile_tables.py
5. 检查 data/narrative_mvp_nodes.json / data/story_battles.json / data/battle_scene_manifest.json
6. 启动 NarrativeDemo 验证
```

常用验证：

```bash
python3 scripts/compile_tables.py
godot --headless --quit --path .
godot --headless --path . --quit scenes/NarrativeDemo.tscn
```

## 文档归档

以下文档已经归档到 `archive/docs/narrative/`：

```text
MVP_NARRATIVE_SCRIPT.md
MVP_NARRATIVE_SCRIPT_COMPRESSED.md
NARRATIVE_MVP_SCRIPT_FRAGMENTED.md
NARRATIVE_IMPLEMENTATION_PROGRESS.md
NARRATIVE_MVP_PROGRESS.md
NARRATIVE_MVP_PROGRESS_MAP_CLICK_ADDENDUM.md
narrative_ai_node_generation.md
narrative_source_of_truth.md
```

它们记录了早期设计、压缩脚本、安全线和历史进度。若与本文档或当前 TSV 冲突，以本文档和 `tables/` 为准。
