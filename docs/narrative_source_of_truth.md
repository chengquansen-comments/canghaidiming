# 叙事源头与文档收敛说明

本文档是当前项目叙事相关资料的唯一入口。后续修改剧情、节点流程、美术规划、战斗接入时，优先按本文档判断“该改哪里”。

## 结论

当前叙事系统采用：

```text
TSV 编辑源 → compile_tables.py → data/*.json 运行源 → Godot 读取
```

不要直接编辑 `data/*.json`。运行 JSON 只作为编译产物。

## 当前有效叙事源

### 1. 序章剧情

编辑源：

```text
tables/narrative_mvp_prologue_steps.tsv
```

用途：

- 序章：黑海潮生
- 父母遇害
- 无名老兵救场
- 后来称其为师父
- 十年后出山
- 序章战斗触发

重点字段：

```text
id
title
column
type
text
career_prompt
combat_json
```

### 2. 正篇剧情节点

编辑源：

```text
tables/narrative_mvp_nodes.tsv
```

用途：

- 正篇节点标题
- 场景文案
- 一句一继续的主叙事文案
- 台词碎片
- 叙事选择
- 战斗触发
- 战后结果文案

重点字段：

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

### 3. 节点流程、实装状态、美术挂接

编辑源：

```text
tables/narrative_mvp_node_status.tsv
```

用途：

- 当前哪些节点进入 MVP 主流程
- 主流程排序
- 节点类型
- 地图分组
- 当前美术资源路径
- 节点是否 playable / reserved

重点字段：

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

当前主流程由：

```text
flow_enabled=true
```

并按：

```text
flow_order
```

排序决定。

### 4. 结局与提示

编辑源：

```text
tables/narrative_mvp_ending.tsv
tables/narrative_mvp_hints.tsv
```

用途：

- 第一幕结局评价
- 结局反馈文案
- 运行提示文案

## 当前有效运行源

编译后生成：

```text
data/narrative_mvp_nodes.json
```

Godot 运行时读取该文件作为剧情 MVP 的正式运行源。

其中关键字段：

```text
prologue
nodes
flow_node_ids
node_status
ending
hints
```

## 已归档 / 仅参考的叙事资料

以下文件不再作为剧情推进依据：

```text
data/narrative/mvp_compressed_narrative.json
data/narrative/mvp_static_map_layout.json
```

它们的定位是：

| 文件 | 当前定位 |
|---|---|
| `data/narrative/mvp_compressed_narrative.json` | 旧版压缩叙事草案 / 历史参考 |
| `data/narrative/mvp_static_map_layout.json` | 旧版静态地图布局参考 |

注意：这些文件由：

```text
tables/raw_json_documents.tsv
```

原样生成。除非明确要整理归档材料，否则不要在这里继续扩写正式剧情。

## 美术规划应看哪些表

美术规划优先看两张表：

```text
tables/narrative_mvp_node_status.tsv
tables/narrative_mvp_nodes.tsv
```

推荐读取方式：

| 需求 | 来源 |
|---|---|
| 哪些节点需要画 | `node_status.tsv` 的 `flow_enabled=true` |
| 先画哪个 | `node_status.tsv` 的 `flow_order` |
| 是背景/战斗/旧物/Boss/结尾 | `node_status.tsv` 的 `type` |
| 属于哪个地图阶段 | `node_status.tsv` 的 `column` |
| 当前挂的资源路径 | `node_status.tsv` 的 `visual_path` |
| 场景应该画什么 | `nodes.tsv` 的 `scene` |
| 节点气质和剧情重点 | `nodes.tsv` 的 `text / dialogue_json / choices_json` |

## 战斗叙事接入应看哪些表

战斗触发来自：

```text
tables/narrative_mvp_nodes.tsv 的 choices_json 或 combat_json
```

战斗敌人与数值来自：

```text
tables/enemy_manifest_encounters.tsv
tables/enemy_manifest_enemies.tsv
tables/enemy_manifest_deck.tsv
tables/enemy_manifest_intent_weights.tsv
tables/enemy_manifest_phase_behaviors.tsv
```

编译后生成：

```text
data/enemy_manifest.json
```

不要在剧情表里重复写敌人数值。剧情节点只引用：

```text
encounter_id
battle_id
```

## 变量命名

当前正式变量采用英文 canonical name：

| Canonical | 中文 | 含义 |
|---|---|---|
| `military_merit` | 军功 | 军门、捷报、升赏认可的胜利 |
| `clean_reputation` | 清望 | 百姓、言官、道义评价 |
| `case_clues` | 旧案线索 | 十年前旧案、失械案、师父旧事的线索进度 |
| `soldier_trust` | 兵心 | 士兵、乡勇、部下是否愿意跟随 |

历史别名仅作兼容：

| Legacy | Canonical |
|---|---|
| `jun_gong` | `military_merit` |
| `qing_wang` | `clean_reputation` |
| `clues` | `case_clues` |
| `public_repute` | `clean_reputation` |
| `dg` | `military_merit` |
| `dq` | `clean_reputation` |
| `dc` | `case_clues` |

新增剧情不要再使用 legacy 字段。

## 修改流程

标准流程：

```bash
python3 scripts/compile_tables.py
godot --path .
```

提交时应同时提交：

```text
tables/*.tsv
data/*.json
```

如果 TSV 与 JSON 不一致，以 TSV 为准，重新编译。

## 叙事文档收敛规则

后续新增叙事内容时遵守：

1. 正式剧情只写入 `tables/narrative_mvp_*.tsv`。
2. 美术规划只从 `node_status.tsv + nodes.tsv` 读取。
3. 战斗数值只写入 `enemy_manifest_*.tsv`。
4. `data/narrative/*.json` 只保留历史归档或布局参考，不再扩写正式剧情。
5. 新增叙事说明优先更新本文档，不再散落在多个 README 段落里。
