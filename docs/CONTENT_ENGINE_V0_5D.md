# Content Engine v0.5d

## 1) v0.5d 目标

v0.5d 目标是聚合 battle reward / operation node / narrative node 中分散的 route 标记，生成设计层路线门槛表：

- `data/design/generated_route_gate_plan.tsv`

本阶段继续保持设计层，不接入运行时。

## 2) 输入文件

```text
data/design/generated_battle_reward_plan.tsv
data/design/generated_operation_node_plan.tsv
data/design/generated_narrative_node_plan.tsv
data/design/generated_route_progression_curve.tsv
data/design/progression_numeric_config_v1_3.tsv
```

## 3) 输出文件

```text
data/design/generated_route_gate_plan.tsv
```

## 4) 字段说明

核心字段：

- `route_gate_id`：gate 唯一 ID。
- `route_id` / `route_type` / `ending_route`：路线归属和结局归属。
- `gate_stage` / `gate_kind` / `priority`：触发阶段、门槛类型和优先级。
- `required_flags` / `optional_flags` / `blocked_by_flags`：结构化标记门槛。
- `required_*` 系列：武境、军功、清望、旧案、轻功等定量或等级约束。
- `source_battle_reward_ids` / `source_operation_node_ids` / `source_narrative_node_ids`：可追溯来源。
- `source_route_gate_tags`：聚合后的 route gate 标签视图。
- `unlock_result` / `fallback_route`：满足与不满足时的结果指向。
- `is_hard_gate` / `is_player_choice`：硬门槛与玩家选择标记。

## 5) 路线分流规则

### 普通结局

- 默认兜底路线。
- 不要求武境 10。
- 不要求高军功。
- 不要求旧案 high。
- 不要求轻功 3/4。

### 真结局

- 旧案真相路线。
- 必须 `required_old_case_progress_level=high`。
- 建议武境 9-10，真 Boss 以 10 境为门槛。
- 不得被武状元路线覆盖。
- 不得硬要求轻功 4。

### 武状元特殊结局

- 制度认可路线，不替代真结局。
- 必须 `martial_realm_10 + high_military_merit`。
- 不要求旧案 high。
- 不要求轻功 4。
- 与真结局条件同时满足时必须走玩家选择 gate。

### 轻功突破

- cap_3 / cap_4 都是稀缺突破 gate。
- cap_4 不是 normal/true_route/wuzhuangyuan 结局硬门槛。

## 6) route gate 聚合逻辑

从三张内容表做结构聚合：

1. battle reward：`can_trigger_*`、`ending_route`、old_case / merit / lightness 触发痕迹。
2. operation node：`route_gate_tags`、`can_prepare_boss`、`can_support_true_ending` 等。
3. narrative node：`route_gate_tags` + flags + `route_affinity`。

每个 gate 输出尽量保留 source ids，可回溯来源。

## 7) validator 检查项

`route_gate_validator.py` 检查：

- 文件存在、ID 唯一、必备 gate 覆盖。
- 枚举合法性（`route_id` / `route_type` / `gate_kind`）。
- 普通/真结局/武状元/轻功突破约束。
- true_route 与 wuzhuangyuan 同时可触发时的 `is_player_choice=true`。
- `lightness_4_required` 禁止项。
- boss_prepare gate 必须回溯到 `can_prepare_boss=true` 的 operation node。

## 8) 当前不做什么

- 不写运行时 route gate。
- 不修改 story battle TSV。
- 不修改 Godot 代码。
- 不接 LLM API。

## 9) 如何运行 generator

```bash
python3 tools/content_engine/route_gate_generator.py \
  --design-dir data/design \
  --out data/design/generated_route_gate_plan.tsv
```

## 10) 如何运行 validator

```bash
python3 tools/content_engine/route_gate_validator.py \
  --design-dir data/design
```

## 11) 如何进入 v0.6

v0.6 建议先做 generated content package manifest，再进入 runtime exporter / content package exporter：

1. 定义 design-layer manifest（版本、来源表、校验哈希、依赖顺序）。
2. 把 battle / operation / narrative / route_gate 的导出边界固定。
3. 在 manifest 通过校验后，再实现运行时导出。
