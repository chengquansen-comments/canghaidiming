# Runtime Battle Reward Hydration 报告

## 目标

- 本次目标是将 `battle_reward.json` 从空 scaffold 水合为来自 `generated_battle_reward_plan.tsv` 的真实 records。
- 本阶段仍不接入正式奖励逻辑，不替换主流程数据源。

## 输入与输出

- 输入源：`data/design/generated_battle_reward_plan.tsv`、`data/runtime/content_engine/battle_reward.json`、`data/runtime/content_engine/runtime_manifest.json`
- 输出文件：`data/runtime/content_engine/battle_reward.json`、`data/runtime/content_engine/runtime_manifest.json`、`data/design/generated_runtime_battle_reward_hydration_report.tsv`、`data/design/generated_runtime_battle_reward_hydration_report.md`

## 关键变化

- source_record_count: 45
- hydrated_record_count: 45
- previous_runtime_record_count: 0
- previous_runtime_field_count: 0
- hydrated_field_count: 30

## Fingerprint 与 Manifest

- previous_content_fingerprint: cf6ffc4e9ad078df51fc26e5b84746aeae3edd429cff92ceae0f48e79c4059bb
- new_content_fingerprint: 75cf5f5d651876ef4b7a95c51360f7abf2913f454e889044e6a291647ece62f6
- manifest_updated: true

## 不变性检查

- card_pool_unchanged: true
- runtime_loader_config_unchanged: true

## 边界与后续

- 本阶段仅修复 runtime 内容可比对性，避免在主流程接入前带着空 records 做对比。
- 建议 v0.9d 再推进 battle_reward read-only Godot compare/probe，在 gate 约束下验证运行时读取行为。
