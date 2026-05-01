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
- 出山职业选择
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

默认 flow 共 27 个节点：

```text
10  military_order
20  ch2_sea_route_unusual
30  ch2_beach_tracks
40  ch2_reed_ambush_battle
50  ch2_reed_ambush_aftermath
60  ch2_silent_village
70  ch2_night_signal_fire
80  ch3_firearm_marking
90  ch3_sealed_crate
100 ch3_escort_silence
110 ch3_escort_clash_battle
120 ch3_escort_aftermath
130 ch3_burned_storehouse
140 ch3_official_notice
150 ch4_tide_reveals_marks
160 ch4_old_anchor_chain
170 ch4_master_hesitation
180 ch4_tide_bandits_battle
190 ch4_tide_aftermath
200 ch4_hidden_document
210 ch4_master_silence
220 boss_ext_burning_ship_sighting
230 boss_ext_hold_full_of_crates
240 boss_ext_master_freeze_arrow
250 boss_ext_wakou_leader_battle
260 boss_ext_aftermath_choice
270 military_coverup
```

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
| `ch2_reed_ambush_battle` | `enc_ch2_reed_ambush` | `chapter2_reed_ambush` | `true` |
| `ch3_escort_clash_battle` | `enc_ch3_escort_clash` | `chapter3_escort_clash` | `true` |
| `ch4_tide_bandits_battle` | `enc_ch4_tide_bandits` | `chapter4_tide_bandits` | `true` |
| `boss_ext_wakou_leader_battle` | `enc_boss_ext_wakou_leader` | `boss_ext_wakou_leader` | `true` |

规则：

- 敌我模板、数值、卡组、结算模式来自 `data/story_battles/*.tsv`。
- `battle_id` 只负责视觉场景，不负责战斗数值。
- 不在 UI 控制器里硬写剧情战敌人和卡组。
- `tables/enemy_manifest_*.tsv` / `data/enemy_manifest.json` 是旧剧情战斗、AI 和 debug 兼容层，不再是正式剧情战斗主源。
- 剧情武器意象要和 StoryBattle 卡组一致。例如枪手写“枪锋”，刀客写“刀光”。

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

结局文案目前在 `scripts/narrative_demo_canonical_controller.gd` 中维护。若后续要彻底表驱动，可新增 `tables/narrative_mvp_endings.tsv`，再由 `compile_tables.py` 编译进入 `data/narrative_mvp_nodes.json`。

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
