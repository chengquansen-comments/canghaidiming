# Content Engine v0.9c

## 1）阶段定位

v0.9c 的目标是 **battle_reward runtime hydration**：  
把 `data/runtime/content_engine/battle_reward.json` 从空 scaffold 内容，水合为来自 `data/design/generated_battle_reward_plan.tsv` 的真实 runtime records。

本阶段不是正式奖励逻辑接入，不替换现有奖励源，不接入战斗主流程。

## 2）为什么先做 hydration

在 v0.9b 中，`runtime_record_count=0` 与 `legacy_record_count=45` 存在显著差异。  
若在空 records 基础上直接做 Godot compare/probe，结论会被“数据缺失”主导，难以评估 runtime 结构是否可用。

因此 v0.9c 先修复 runtime 内容完整性，再进入后续 probe/compare 阶段。

## 3）输入与输出

输入：

- `data/design/generated_battle_reward_plan.tsv`
- `data/runtime/content_engine/battle_reward.json`
- `data/runtime/content_engine/runtime_manifest.json`

输出（本阶段核心）：

- `data/runtime/content_engine/battle_reward.json`
- `data/runtime/content_engine/runtime_manifest.json`
- `data/design/generated_runtime_battle_reward_hydration_report.tsv`
- `data/design/generated_runtime_battle_reward_hydration_report.md`

## 4）manifest 为什么必须更新 checksum

hydration 后 `battle_reward.json` 的 records、`record_count`、`field_count`、`content_fingerprint` 都会变化。  
如果不更新 manifest 的 `sha256`、`file_size_bytes`、fingerprint 与计数，manifest 将与实际文件不一致，后续 validator 会误报或失去审计意义。

## 5）边界约束

- 不修改 `card_pool.json`
- 不修改 `runtime_loader_config.json`
- 不修改 `combat_resolver.gd` / `battle_state_machine.gd` / `card_data.gd`
- 不修改 `data/story_battles/*.tsv` 与 `scenes/*.tscn`
- 不接入 loader/gate 到现有 Godot 主流程

## 6）后续路线

- v0.9d 再考虑 battle_reward 的 read-only Godot compare/probe
- v1.0 前再评估是否进入受控正式替换

## 7）Godot warning 口径

RID/ObjectDB/resource leak warning 继续作为独立 Godot hygiene issue 追踪，不并入 v0.9c hydration 成败判定。
