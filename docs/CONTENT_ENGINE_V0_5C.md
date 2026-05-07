# Content Engine v0.5c

## 目标

v0.5c 目标是生成设计层叙事节点骨架表：

- `data/design/generated_narrative_node_plan.tsv`

该阶段只生成结构化叙事骨架，不写正式剧情正文，不接入运行时。

## 输入文件

```text
data/design/generated_operation_node_plan.tsv
data/design/generated_battle_reward_plan.tsv
data/design/generated_route_progression_curve.tsv
data/design/generated_battle_slot_plan.tsv
docs/NARRATIVE.md (可选读取，不做复杂解析)
```

## 输出文件

```text
data/design/generated_narrative_node_plan.tsv
```

## 字段说明

主要字段：

- `narrative_node_id`：叙事骨架唯一 ID。
- `source_type` / `source_id`：来源类型与来源对象 ID。
- `scope` / `route_type` / `stage` / `trigger_stage`：触发范围与阶段信息。
- `node_kind` / `narrative_role` / `route_affinity`：节点类型、叙事职责和路线亲和。
- `hook_tags` / `route_gate_tags`：结构标签；供后续 route gate 汇总，不直接写正文。
- `required_flags` / `optional_flags` / `blocked_by_flags`：结构门槛标记。
- `preview_key` / `result_key`：稳定文本 key，仅用于后续文本挂接。
- `should_write_body` / `body_style` / `line_budget`：正文写作占位控制（v0.5c 固定为不写正文）。
- `source_operation_node_id` / `source_reward_plan_id`：回溯来源关联。

## 叙事约束

- 一句一继续。
- 不写长段。
- 不解释世界观。
- 不直接说情绪。
- `preview` / `result` 分离。
- 不直接显示数值。

在 v0.5c 中具体落地为：

- `should_write_body=false`
- `line_budget<=1`
- `preview_key` 与 `result_key` 必须同时存在且不同
- `effect_profile` 仅写结构类型，不写数值展示文本

## 路线分流约束

### 普通结局

- `route_affinity` 使用 `normal` 或 `common`。
- 不强制 `martial_realm_10`、`high_military_merit`。
- 不强制 `lightness_3` / `lightness_4`。

### 真结局

- `route_affinity=true_route`。
- 需要 `old_case` / `true_route` 相关标签支持。
- 可要求 `realm_9_or_10`。

### 武状元特殊结局

- `route_affinity=wuzhuangyuan`。
- `required_flags` 至少包含 `martial_realm_10,high_military_merit`。
- 主题是回京考试 / 制度认可，不以旧案高推进为硬门槛。

## 当前不做什么

- 不写正式剧情正文。
- 不生成 route gate。
- 不写运行时 narrative data。
- 不修改 story battle TSV。
- 不接 LLM API。

## 运行 generator

```bash
python3 tools/content_engine/narrative_node_generator.py \
  --design-dir data/design \
  --out data/design/generated_narrative_node_plan.tsv
```

## 运行 validator

```bash
python3 tools/content_engine/narrative_node_validator.py \
  --design-dir data/design
```

## 如何进入 v0.5d

下一阶段建议实现 `route_gate_generator`：

1. 汇总 `generated_battle_reward_plan.tsv` 的 `route gate` 触发线索。
2. 汇总 `generated_operation_node_plan.tsv` 的 `route_gate_tags`。
3. 汇总 `generated_narrative_node_plan.tsv` 的 `route_gate_tags`。
4. 统一生成可校验的路线门槛结构，并补对应 validator。
