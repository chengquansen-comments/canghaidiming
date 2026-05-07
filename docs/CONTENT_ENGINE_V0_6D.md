# Content Engine v0.6d

## 1) v0.6d 目标

v0.6d 的目标是基于 manifest + report + validator summary，生成 design-layer content package approval gate。

这个 approval gate 是审批模板，不是 runtime export 清单。

## 2) 为什么需要 approval gate

v0.6c 已经把 validator 状态稳定汇总出来，但 validator PASS 不等于 runtime export 批准。

在 runtime exporter 落地前，仍需要一个显式审批层去回答：

- 哪些 artifact 理论上可以进入未来导出候选。
- 哪些 artifact 因 warning 需要 waiver。
- 哪些 artifact 因 design-layer 边界、runtime schema 缺失或审批未授予而继续阻断。

## 3) 输入文件

v0.6d 读取：

- `data/design/generated_content_package_manifest.tsv`
- `data/design/generated_validator_summary.tsv`

## 4) 输出文件

v0.6d 输出：

- `data/design/generated_content_package_approval.tsv`
- `data/design/generated_content_package_approval_report.md`

## 5) approval_status 规则

当前 generator 默认规则：

- `validator_status=PASS` -> `pending_review`
- `validator_status=WARN` -> `waiver_required`
- `validator_status=FAIL` -> `blocked`
- `SOURCE_ONLY` -> `pending_review`（用于 source config）
- `NOT_RUN / NOT_VALIDATED` -> `blocked`

本阶段不会自动生成 `approved`。

## 6) WARN / FAIL 的处理规则

- WARN artifact 不得自动批准。
- WARN artifact 必须带 `waiver_required` 标记。
- WARN artifact 必须要求 `resolve_validator_warning` 或 `manual_waiver_required`。
- FAIL artifact 必须保持 `blocked`。

当前已知 WARN artifact：

- `generated_enemy_deck_skeleton`
- `generated_enemy_deck_sets`

## 7) 为什么本阶段不自动批准任何 artifact

v0.6d 只生成审批模板，不替代人工审批，原因包括：

- runtime exporter 还没有实现。
- runtime schema 还没有定义完成。
- 设计层 PASS 只代表通过当前 validator 规则，不代表运行时映射已经安全。
- WARN artifact 需要人工 waiver 才可能进入后续候选。

因此 `approved_for_export` 在本阶段默认全部为 `false`。

## 8) 当前不做什么

v0.6d 明确不做以下事情：

- 不导出 runtime data。
- 不修改 Godot。
- 不修改 story battle TSV。
- 不接 LLM API。

## 9) 如何运行 generator

```bash
python3 tools/content_engine/content_package_approval_generator.py \
  --design-dir data/design \
  --out data/design/generated_content_package_approval.tsv \
  --out-md data/design/generated_content_package_approval_report.md
```

## 10) 如何运行 validator

```bash
python3 tools/content_engine/content_package_approval_validator.py \
  --design-dir data/design
```

## 11) 如何进入 v0.7

v0.7 runtime exporter 必须满足以下规则：

- 只能读取 manifest + report + validator summary + approval table。
- 只允许 `approved_for_export=true` 且 `validator_status=PASS` 的 artifact 作为候选。
- WARN artifact 必须先人工 waiver 后才可进入候选。
- runtime exporter 不得直接扫描 `data/design/generated_*.tsv`。
