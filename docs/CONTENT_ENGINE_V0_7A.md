# Content Engine v0.7a

## 1) v0.7a 目标

v0.7a 的目标是定义 runtime schema proposal，明确未来 runtime exporter 的目标结构与导出边界。

本阶段只输出 proposal，不导出 runtime data。

## 2) 为什么不能直接 runtime export

当前 approval 表中 `approved_for_export=true` 数量为 0，且仍有 WARN artifact 需要 waiver。
因此 runtime exporter 不能在本阶段实现和执行。

## 3) 输入文件

- `data/design/generated_content_package_manifest.tsv`
- `data/design/generated_validator_summary.tsv`
- `data/design/generated_content_package_approval.tsv`

## 4) 输出文件

- `data/design/generated_runtime_schema_proposal.tsv`
- `data/design/generated_runtime_schema_proposal.md`

## 5) 七类 runtime schema

- enemy_deck (`enemy_decks.json`)
- card_pool (`card_pool.json`)
- battle_reward (`battle_rewards.json`)
- operation_node (`operation_nodes.json`)
- narrative_node (`narrative_nodes.json`)
- route_gate (`route_gates.json`)
- package_manifest (`content_package_manifest.json`)

## 6) export policy

runtime export 候选必须满足：

- `approved_for_export=true`
- `validator_status=PASS`
- `approval_status=approved`
- WARN artifact 需要 manual waiver
- runtime exporter 不得直接扫描 `data/design/generated_*.tsv`

## 7) 当前不做什么

- 不导出 runtime data。
- 不修改 Godot。
- 不修改 story battle TSV。
- 不接 LLM API。

## 8) 如何运行 generator

```bash
python3 tools/content_engine/runtime_schema_proposal_generator.py \
  --design-dir data/design \
  --out data/design/generated_runtime_schema_proposal.tsv \
  --out-md data/design/generated_runtime_schema_proposal.md
```

## 9) 如何运行 validator

```bash
python3 tools/content_engine/runtime_schema_proposal_validator.py \
  --design-dir data/design
```

## 10) 如何进入 v0.7b

v0.7b 建议先做 runtime export dry-run：

- 只模拟导出候选与 blocker。
- 不写 runtime 文件。
- 用于验证 approval + schema proposal 是否能形成可执行导出计划。
