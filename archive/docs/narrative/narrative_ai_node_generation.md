# AI 节点生成协议（Strict Schema）

本文档定义《大明之沧海嘀鸣》第一幕叙事节点的 AI 生成协议。

目标：让 AI 只生成可落表、可校验、可编译的节点内容，而不是自由发挥的长文案。

## 适用范围

用于生成：

```text
tables/narrative_mvp_nodes.tsv
```

中的单个正篇节点，尤其是：

```text
text
scene
dialogue_json
choices_json
combat_json
```

不用于生成：

```text
敌人数值
战斗牌组
演出 timeline
美术资源
```

这些内容分别由其他表维护。

## 总原则

AI 只负责生成“节点叙事内容”，不负责决定运行架构。

必须遵守：

1. 一句一继续。
2. 不写大段解释。
3. 不在 `text` 或 `result` 文案里直接写“军功+1 / 旧案+1”。
4. 数值变化只能写在结构化字段里。
5. 战斗和选择必须分离。
6. 如果多个选项指向同一场战斗，应先生成一个独立战斗节点，再生成战后选择节点。
7. 节点只能是：纯叙事节点、叙事选择节点、战斗触发节点、战后处理节点、结局门节点。

## 输入 Schema

AI 生成节点时，输入必须符合以下结构：

```json
{
  "project": "大明之沧海嘀鸣",
  "act": "第一幕",
  "node_request": {
    "id": "string",
    "title": "string",
    "column": "军令|初遇|疑点|压迫|破船|军门|自定义",
    "type": "事件|普通战斗|战后处理|旧物|精英战斗|Boss|结尾",
    "position_in_flow": "string",
    "narrative_goal": "string",
    "emotional_tone": "string",
    "must_include": ["string"],
    "must_avoid": ["string"],
    "available_variables": [
      "military_merit",
      "clean_reputation",
      "case_clues",
      "soldier_trust"
    ],
    "allowed_encounter_ids": ["string"],
    "previous_context": {
      "previous_node_id": "string",
      "known_facts": ["string"],
      "player_state_assumption": {
        "military_merit": 0,
        "clean_reputation": 0,
        "case_clues": 0,
        "soldier_trust": 0
      }
    }
  }
}
```

## 输出 Schema

AI 必须只输出 JSON，不输出 Markdown，不输出解释。

```json
{
  "node": {
    "id": "string",
    "title": "string",
    "column": "string",
    "type": "string",
    "scene": "string",
    "text": ["string"],
    "dialogue": [
      {
        "speaker": "string",
        "text": "string"
      }
    ],
    "combat": null,
    "choices": [
      {
        "label": "string",
        "preview": "string",
        "effects": {
          "military_merit": 0,
          "clean_reputation": 0,
          "case_clues": 0,
          "soldier_trust": 0
        },
        "combat": null,
        "result": ["string"]
      }
    ],
    "validation_notes": ["string"]
  }
}
```

### 字段说明

| 字段 | 说明 |
|---|---|
| `id` | 节点唯一 id，必须是 snake_case 英文 |
| `title` | 中文显示标题 |
| `column` | 地图阶段 |
| `type` | 节点类型 |
| `scene` | 场景描述，给美术与演出参考 |
| `text` | 一句一继续正文，数组中每项一屏 |
| `dialogue` | 可选台词碎片 |
| `combat` | 节点级战斗；默认 null，除非该节点就是固定战斗触发节点 |
| `choices` | 叙事选择；纯叙事节点可为空数组 |
| `preview` | UI 预览文案，只说明结果方向 |
| `effects` | 真实变量变化，只能使用 canonical 变量名 |
| `result` | 选择后或战斗胜利后的结果文案，数组中每项一屏 |

## 战斗节点输出 Schema

如果节点是固定战斗触发节点，使用：

```json
{
  "node": {
    "id": "beach_ambush",
    "title": "海边伏击",
    "column": "初遇",
    "type": "普通战斗",
    "scene": "沙滩。脚印。整齐得不像海盗。",
    "text": [
      "脚印从潮线外来。",
      "却没有一双走向海里。",
      "芦苇里，枪尖先亮。"
    ],
    "dialogue": [],
    "combat": {
      "enabled": true,
      "encounter_id": "enc_beach_ambush",
      "battle_id": "first_act_beach_ambush",
      "button": "迎战"
    },
    "choices": [],
    "validation_notes": []
  }
}
```

规则：

```text
固定战斗节点不放三选一。
战斗后的立场选择另建战后处理节点。
```

## 战后处理节点输出 Schema

战后处理节点使用 choices，但不再触发同一场战斗：

```json
{
  "node": {
    "id": "beach_ambush_aftermath",
    "title": "海边伏击：战后处理",
    "column": "初遇",
    "type": "战后处理",
    "scene": "潮水推回尸体。靴底没有海盐。",
    "text": [
      "潮也落下。",
      "尸体没有海盐味。"
    ],
    "dialogue": [],
    "combat": null,
    "choices": [
      {
        "label": "斩首报功",
        "preview": "军功入册。",
        "effects": {
          "military_merit": 1
        },
        "combat": null,
        "result": [
          "首级落进麻袋。",
          "你没有再看靴底。"
        ]
      },
      {
        "label": "搜身留证",
        "preview": "旧案线索增加。",
        "effects": {
          "case_clues": 1
        },
        "combat": null,
        "result": [
          "靴缝里有泥。",
          "不是海泥。"
        ]
      },
      {
        "label": "就地掩埋",
        "preview": "清望增加。",
        "effects": {
          "clean_reputation": 1
        },
        "combat": null,
        "result": [
          "沙子盖上脸。",
          "潮水又掀开一点。"
        ]
      }
    ],
    "validation_notes": []
  }
}
```

## 文案约束

### 正文 text

必须：

```text
每项不超过 24 个汉字。
每项只表达一个画面或动作。
优先使用名词、动作、可见物。
```

允许：

```text
潮声
火光
刀
甲片
火漆
军报
案卷
黑箭
师父停手
```

禁止：

```text
解释世界观
解释人物心理
解释变量变化
写成长段落
写“玩家感到……”
写“这说明……”
```

### preview

必须短，面向 UI：

```text
军功入册。
旧案线索增加。
清望增加。
胜利后：旧案线索增加。
```

禁止：

```text
军功 +1
case_clues +2
获得大量军功并打开后续剧情
```

### result

必须一句一屏。

禁止把数值写进 result。

错误：

```text
潮也落下。军功+1。
```

正确：

```text
潮也落下。
首级落进麻袋。
```

数值变化写入：

```json
"effects": {"military_merit": 1}
```

## 校验规则

AI 输出后必须满足：

1. `node.id` 非空且 snake_case。
2. `node.title` 非空。
3. `node.text` 是数组。
4. `node.text` 每项不超过 24 个汉字，特殊情况不超过 36 个。
5. `choices` 中每个选项必须有 `label / preview / effects / result`。
6. `effects` 只能包含 canonical 变量。
7. `preview/result/text` 里不得出现 `+1/+2/-1` 等数值变化表达。
8. 如果 `combat.enabled=true`，则该节点不应同时有三个立场选择。
9. 如果三个选项都触发同一个 `encounter_id`，必须拆成战斗节点 + 战后处理节点。
10. `combat.encounter_id` 必须来自 `enemy_manifest_encounters.tsv`。

## TSV 落表映射

AI 输出 JSON 需要落到：

```text
tables/narrative_mvp_nodes.tsv
```

映射关系：

| AI 输出 | TSV 字段 |
|---|---|
| `node.id` | `id` |
| `node.title` | `title` |
| `node.column` | 可同步到 `node_status.tsv` |
| `node.type` | 可同步到 `node_status.tsv` |
| `node.scene` | `scene` |
| `node.text` | `text`，用 `\n` 拼接 |
| `node.dialogue` | `dialogue_json` |
| `node.combat` | `combat_json` |
| `node.choices` | `choices_json` |

同时需要同步：

```text
tables/narrative_mvp_node_status.tsv
```

至少补充：

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

## 推荐 Prompt

```text
你是《大明之沧海嘀鸣》的叙事节点生成器。

你只能输出 JSON，不能输出 Markdown 或解释。

请严格按照我提供的输出 schema 生成一个叙事节点。

叙事风格：
- 明代海防、军门、倭寇、旧案、师父、火器、潮声。
- 隐晦叙事。
- 一句一继续。
- 不解释，不抒情，不写长段落。
- 用可见物表达因果。

强约束：
- text/result 每个元素是一屏文案。
- 不允许在文案中写“军功+1”“旧案+1”等数值变化。
- 数值变化只能写入 effects。
- 如果节点触发战斗，不要同时生成三选一立场选择。
- 如果需要战后立场选择，请生成战后处理节点。
- 变量名只能使用 military_merit / clean_reputation / case_clues / soldier_trust。

输入如下：
<在这里粘贴输入 JSON>
```

## 示例输入

```json
{
  "project": "大明之沧海嘀鸣",
  "act": "第一幕",
  "node_request": {
    "id": "fire_seal_trace",
    "title": "火漆旧痕",
    "column": "疑点",
    "type": "旧物",
    "position_in_flow": "明制火器之后，押运官之前",
    "narrative_goal": "让玩家第一次明确意识到火器箱与军门有关，但不能直接说明阴谋。",
    "emotional_tone": "冷、压迫、不安",
    "must_include": ["火器箱", "火漆", "师父停手"],
    "must_avoid": ["直接说军门有罪", "直接解释旧案", "数值写进文案"],
    "available_variables": [
      "military_merit",
      "clean_reputation",
      "case_clues"
    ],
    "allowed_encounter_ids": [],
    "previous_context": {
      "previous_node_id": "ming_firearm",
      "known_facts": ["玩家已见到明制火器", "军门要求尽快报功"],
      "player_state_assumption": {
        "military_merit": 1,
        "clean_reputation": 0,
        "case_clues": 1
      }
    }
  }
}
```

## 示例输出

```json
{
  "node": {
    "id": "fire_seal_trace",
    "title": "火漆旧痕",
    "column": "疑点",
    "type": "旧物",
    "scene": "火器箱半开。箱底火漆未干。师父的手停在箱沿。",
    "text": [
      "箱底有火漆。",
      "火漆还新。",
      "师父的手停了一下。"
    ],
    "dialogue": [
      {
        "speaker": "师父",
        "text": "别急着交。"
      }
    ],
    "combat": null,
    "choices": [
      {
        "label": "上交军门",
        "preview": "军功入册。",
        "effects": {
          "military_merit": 1
        },
        "combat": null,
        "result": [
          "箱子被收走。",
          "收得很快。"
        ]
      },
      {
        "label": "私下留证",
        "preview": "旧案线索增加。",
        "effects": {
          "case_clues": 2
        },
        "combat": null,
        "result": [
          "你拓下一点火漆。",
          "纸很薄。",
          "手却发沉。"
        ]
      },
      {
        "label": "问师父",
        "preview": "旧案线索增加。",
        "effects": {
          "case_clues": 1
        },
        "combat": null,
        "result": [
          "师父没有看你。",
          "他只看箱底。"
        ]
      }
    ],
    "validation_notes": [
      "没有在文案中写数值变化。",
      "没有直接说明军门有罪。",
      "节点为旧物选择节点，不触发战斗。"
    ]
  }
}
```
