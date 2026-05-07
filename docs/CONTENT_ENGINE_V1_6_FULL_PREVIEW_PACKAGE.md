# Content Engine v1.6 full preview package expansion

## 阶段目标
v1.6 在不重做 reward 链路的前提下，复用既有 `battle_rewards.preview.json`，补齐其他 domain 的 preview JSON，并产出 full preview manifest。

## 输入与输出
输入（只读）：
- `data/runtime_preview/content_engine/battle_rewards.preview.json`
- `data/runtime_preview/content_engine/battle_rewards.preview_manifest.json`
- `data/design/generated_battle_slot_plan.tsv`
- `data/design/generated_enemy_deck_sets.tsv`
- `data/design/generated_card_pool.tsv`
- `data/design/generated_operation_node_plan.tsv`
- `data/design/generated_narrative_node_plan.tsv`
- `data/design/generated_route_gate_plan.tsv`

输出（仅 `data/runtime_preview/content_engine/`）：
- `battle_slots.preview.json`
- `enemy_decks.preview.json`
- `card_pool.preview.json`
- `operation_nodes.preview.json`
- `narrative_nodes.preview.json`
- `route_gates.preview.json`
- `full_content_package.preview_manifest.json`

## 关键规则
- 全部 preview JSON 顶层包含：`runtime_ready=false`、`preview_only=true`、`source_artifact`、`generated_at`。
- `narrative_nodes` 仅导出 key/hook 字段，不导出正式正文。
- `enemy_decks` 由 `generated_enemy_deck_sets.tsv` 按 `deck_id` 聚合。
- full manifest 必须覆盖 7 个 domain：
  - `battle_rewards`
  - `battle_slots`
  - `enemy_decks`
  - `card_pool`
  - `operation_nodes`
  - `narrative_nodes`
  - `route_gates`

## 安全边界
- 不写 `data/runtime/`。
- 不改 Godot 正式 runtime 流程。
- `selected_reward=legacy`、`content_engine_enabled=false`、`runtime_loader_config=disabled` 约束保持不变。
