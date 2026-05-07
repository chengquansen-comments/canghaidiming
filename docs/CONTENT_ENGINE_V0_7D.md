# Content Engine v0.7d

## 1) v0.7d 定位

v0.7d 是 runtime export diff report，不是 runtime exporter。
本阶段只生成“预期导出差异报告”，不写 runtime 文件。

## 2) 阶段边界

- v0.7b：dry-run，判断基础导出条件和 blocker。
- v0.7c：manual approval overlay，形成最小可控 `would_export=true` 候选。
- v0.7d：diff report，评估候选导出将产生的计划差异与风险。
- v0.8：runtime exporter（后续阶段，仍不在本次实现范围）。

## 3) 输入与输出

输入：

- `data/design/generated_runtime_export_approval_overlay.tsv`

输出：

- `data/design/generated_runtime_export_diff_report.tsv`
- `data/design/generated_runtime_export_diff_report.md`

## 4) diff report 如何帮助审查风险

diff report 为每个 runtime_domain 记录：

- 计划导出动作（`export_action`）
- 计划路径（`planned_runtime_path`）
- 预计记录数与字段数
- schema/content 指纹
- 风险等级与阻断状态

这样可以在不触碰 runtime 文件的前提下，先审查“若导出会发生什么”。

## 5) planned_runtime_path 说明

`planned_runtime_path` 只是计划路径，不代表真实文件已写入。
v0.7d 禁止创建 `data/runtime/content_engine/`，也禁止写 runtime JSON/TSV。

## 6) unsafe_path 的判定

当计划路径不在 `data/runtime/content_engine/` 前缀下，或指向不安全目录（如 `scripts/`、`scenes/`、`data/story_battles/`）时，`diff_status=unsafe_path` 且必须 blocked。

## 7) 为什么 v0.7d 仍不创建 data/runtime/content_engine/

因为 v0.7d 的目标是审查计划差异而非执行导出。
执行导出属于后续 runtime exporter 阶段，并且依赖更严格的审批与实现边界。

## 8) 运行命令

```bash
python3 tools/content_engine/runtime_export_diff_report.py \
  --design-dir data/design \
  --overlay data/design/generated_runtime_export_approval_overlay.tsv \
  --out data/design/generated_runtime_export_diff_report.tsv \
  --out-md data/design/generated_runtime_export_diff_report.md
```

```bash
python3 tools/content_engine/runtime_export_diff_report_validator.py \
  --design-dir data/design
```
