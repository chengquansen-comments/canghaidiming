# Content Engine v0.9b

## 1) v0.9b 定位

v0.9b 是 `battle_reward` 单 domain 的 read-only compare。  
它只做 runtime 与 legacy/design source 的差异评估，不替换正式奖励逻辑。

## 2) 本阶段边界

- 不接 `battle_state_machine` / `combat_resolver`
- 不替换正式奖励数据源
- 不处理 `card_pool` compare（保持 out_of_scope）
- 不接入主流程，`integration_status` 维持 `compare_only` / `not_integrated`

## 3) compare 输入

- `data/runtime/content_engine/runtime_manifest.json`
- `data/runtime/content_engine/runtime_loader_config.json`
- `data/runtime/content_engine/battle_reward.json`
- 现有 legacy/design 奖励源（优先 `runtime_manifest.files[*].source_design_path`）

## 4) legacy source 不确定时的处理

若 legacy source 找不到或有歧义：

- 不阻塞整个 v0.9b
- `comparable=false`
- `compare_scope=runtime_only` 或 `legacy_source_ambiguous`
- `blocked_reason=legacy_source_not_found` / `legacy_source_ambiguous`

## 5) 报告用途

- 差异报告仅用于评估与后续接入设计，不作为运行时数据源
- 不改变正式 reward 流程和战斗结算逻辑

## 6) 运行命令

```bash
python3 tools/content_engine/runtime_battle_reward_compare.py
python3 tools/content_engine/runtime_battle_reward_compare_validator.py
```

输出：

- `data/design/generated_runtime_battle_reward_compare_report.tsv`
- `data/design/generated_runtime_battle_reward_compare_report.md`

## 7) 后续阶段

- v0.9c 再考虑 battle_reward read-only Godot probe 或 gated compare
- v0.9d / v1.0 才考虑正式替换数据源
