# Content Engine v0.7b

## 1) v0.7b 目标

v0.7b 的目标是实现 runtime export dry-run，模拟未来 runtime exporter 的导出决策链。

本阶段只输出 dry-run 结果，不导出 runtime data。

## 2) 为什么需要 runtime export dry-run

当前 approval 表中 `approved_for_export=true` 数量为 0，且 runtime exporter 尚未实现。
在这种状态下，先用 dry-run 固化“会导出什么/为什么被阻断”的可复现决策结果，避免直接进入 runtime 写文件阶段。

## 3) 输入文件

- `data/design/generated_content_package_manifest.tsv`
- `data/design/generated_validator_summary.tsv`
- `data/design/generated_content_package_approval.tsv`
- `data/design/generated_runtime_schema_proposal.tsv`

## 4) 输出文件

- `data/design/generated_runtime_export_dry_run.tsv`
- `data/design/generated_runtime_export_dry_run.md`

## 5) dry-run 决策规则

`would_export=true` 必须同时满足：

- schema proposal 存在且结构完整
- `export_allowed_now=true`
- source artifacts 全部存在 approval 表
- source artifacts 的 `approval_status=approved`
- source artifacts 的 `approved_for_export=true`
- source artifacts 的 `validator_status=PASS`
- 对 `requires_waiver_clearance=true` 的 schema，waiver 已清除
- `target_path` 合法（`data/runtime/content_engine/` 前缀）
- runtime exporter 已实现

## 6) 当前为什么所有 would_export=false

当前阶段同时存在以下事实：

- `export_allowed_now` 全部为 `false`
- `approved_for_export=true` 数量为 `0`
- runtime exporter 未实现

因此所有 runtime_domain 都应 `would_export=false` 且 `blocked=true`。

## 7) 当前不做什么

- 不写 runtime JSON
- 不创建 `data/runtime`
- 不修改 Godot
- 不修改 story battle TSV
- 不接 LLM API

## 8) 如何运行 dry-run

```bash
python3 tools/content_engine/runtime_export_dry_run.py \
  --design-dir data/design \
  --out data/design/generated_runtime_export_dry_run.tsv \
  --out-md data/design/generated_runtime_export_dry_run.md
```

## 9) 如何运行 validator

```bash
python3 tools/content_engine/runtime_export_dry_run_validator.py \
  --design-dir data/design
```

## 10) 如何进入下一步

- v0.7c manual approval overlay / waiver process
- 或先做 v0.7c dry-run diff report
- 真正 runtime exporter 仍需等 `approved_for_export=true` artifact 出现
