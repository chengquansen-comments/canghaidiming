# 《大明之沧海嘀鸣》叙事总文档

本文档是叙事规则和数据入口。默认 flow、武举关系、海疆大势图、剧情战斗映射等可变清单拆到 [NARRATIVE_FLOW.md](NARRATIVE_FLOW.md)。

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

`tables/narrative_mvp_expansion_*.tsv` 已归档，不再作为运行输入。后续即使有章节概念，也只写在 `node_status` 的 `column` / `type` / tag 字段中，不再按章节拆文件。

## 活跃源表

| 源表 | 用途 |
|---|---|
| `tables/narrative_mvp_prologue_steps.tsv` | 序章十二拍和师父救场战触发 |
| `tables/narrative_mvp_prologue.tsv` | 序章基础配置 |
| `tables/narrative_mvp_career_choices.tsv` | 玩家初始职业与战斗 profile |
| `tables/narrative_mvp_nodes.tsv` | 正篇节点池 |
| `tables/narrative_mvp_node_status.tsv` | 默认 flow、节点状态、视觉资源路径 |
| `tables/map_node_pool.tsv` | 海疆大势图随机节点池 |
| `tables/map_generation_rules.tsv` | 大势图生成规则 |
| `tables/final_boss_rules.tsv` | 终局收束规则 |
| `tables/combat_enemy_pools.tsv` | 随机战斗敌类池 |
| `tables/enemy_martial_stats.tsv` | 敌方武境数值 |

## 节点写法

`tables/narrative_mvp_nodes.tsv` 关键字段：

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
- `text` 和 `result` 不直接写“军功+1”这类数值提示；数值变化只写在结构化 `effects` 字段。

## 节点状态与流程

`tables/narrative_mvp_node_status.tsv` 关键字段：

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

当前默认 flow、武举关系变量和旧线性正篇拆入随机池的状态见 [NARRATIVE_FLOW.md](NARRATIVE_FLOW.md)。

## 战斗叙事接入

战斗总口径见 [BATTLE.md](BATTLE.md)。叙事层只负责“哪个节点触发哪场战斗”，不直接维护敌我数值和卡组。

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

字段规则：

| 字段 | 规则 |
|---|---|
| `encounter_id` | 必须存在于 `data/story_battles/story_encounters.tsv` |
| `battle_id` | 必须存在于 `tables/battle_scene_manifest.tsv` |
| `override_player_profile` | 必填布尔值；`true` 表示用剧情主角选择和成长覆写玩家配置，`false` 表示保留 StoryBattle 配置 |

规则：

- 敌我模板、数值、卡组、结算模式来自 `data/story_battles/*.tsv`。
- `battle_id` 只负责视觉场景，不负责战斗数值。
- 不在 UI 控制器里硬写剧情战敌人和卡组。
- `tables/enemy_manifest_*.tsv` / `data/enemy_manifest.json` 是旧剧情战斗、AI 和 debug 兼容层，不再是正式剧情战斗主源。
- 剧情武器意象要和 StoryBattle 卡组一致。例如枪手写“枪锋”，刀客写“刀光”。

当前剧情战斗映射见 [NARRATIVE_FLOW.md](NARRATIVE_FLOW.md)。

## 海疆大势图

海疆大势图的当前运行态、network_map 结构、临时 final gate、Debug 直入入口和推进安全规则见 [NARRATIVE_FLOW.md](NARRATIVE_FLOW.md)。

叙事层口径：

- `world_map_entry` 为武举放榜后的正式入口。
- 点击“查看海疆大势图”后进入海疆大势图运行态，而不是直接推进到下一条线性节点。
- 当前保留线性 fallback：若大势图配置缺失，继续到下一个线性节点。
- 随机战斗节点不直接绑定某一个固定敌人，而是绑定“一类战斗 / 一类敌人”。

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

结局文案设计原则：

- 真结局不追加反问。真结局代表本局已经完成“军功让你进堂，旧案让你说话，清望让别人敢信”的完整闭环，本质是个人羁绊、个人追求和民族大义的统一。
- 真结局最终战胜利时走皆大欢喜：大义、羁绊、追求同时保全。
- 真结局最终战失败时不降格为普通失败，而是自我牺牲：主角以自身成全民族大义。
- 非真结局必须留下未竟感，文案末尾追加反问；普通结局的本质是“只求其一”。
- 旧案类非真结局追加：`然而这就是事情的真相吗？`
- 非旧案类非真结局追加：`然而这就是你想要的吗？`
- 武状元线是纯粹武道结局，独立于军功 / 清望 / 旧案统一命题。

第一幕旧结局文案目前在 `scripts/narrative_demo_canonical_controller.gd` 中维护；海疆大势图 9 结局文案目前在 `scripts/narrative_demo_ui_focus_tuned_controller.gd` 中维护。若后续要彻底表驱动，可新增结局 TSV，再由 `compile_tables.py` 编译进入运行时数据。

## AI 节点生成协议

AI 可以辅助生成 `tables/narrative_mvp_nodes.tsv` 的单个节点内容，但必须遵守以下边界：

- 只生成叙事节点内容，不决定运行架构。
- 不生成敌人数值、卡组、美术资源、演出 timeline。
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

```text
1. 修改 tables/narrative_mvp_nodes.tsv。
2. 必要时修改 tables/narrative_mvp_node_status.tsv。
3. 如涉及战斗，补 data/story_battles/*.tsv 与 battle_scene_manifest.tsv。
4. 运行 python3 scripts/compile_tables.py。
5. 检查 data/narrative_mvp_nodes.json / data/story_battles.json / data/battle_scene_manifest.json。
6. 启动 NarrativeDemo 验证。
```

常用验证：

```bash
python3 scripts/compile_tables.py
godot --headless --quit --path .
godot --headless --path . --quit scenes/NarrativeDemo.tscn
```

## 文档归档

旧脚本稿、压缩版记录、安全线进度与 AI 生成协议已经归档到 `archive/docs/narrative/`，只作为历史参考。若与本文档或当前 TSV 冲突，以本文档和 `tables/` 为准。
