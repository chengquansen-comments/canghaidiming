# Content Engine v1.1 Runtime Export Dry-Run

## 阶段定位

本阶段仅进行 runtime export dry-run 决策模拟，不落地 runtime 文件。

## 输入治理表

- `data/design/generated_content_package_manifest.tsv`
- `data/design/generated_validator_summary.tsv`
- `data/design/generated_content_package_approval.tsv`
- `data/design/generated_runtime_schema_proposal.tsv`

## 决策原则

1. 按 schema proposal 汇总 runtime_domain（当前 7 个）。
2. 每个 domain 校验 source_artifacts 的 approval、validator 与 waiver 条件。
3. 当前 approval 表未给出 `approved_for_export=true`，因此 `would_export` 预期全为 `false`。

## 产物

- `data/design/generated_runtime_export_dry_run.tsv`
- `data/design/generated_runtime_export_dry_run.md`

## 安全边界

- 不创建 `data/runtime`。
- 不写任何 runtime JSON。
- 不改变 selected_reward（仍为 legacy）。
- 不改变 runtime_loader_config（仍为 disabled）。
- 不改变玩家奖励、成长奖励、结算 UI、battle_state、combat_result。
