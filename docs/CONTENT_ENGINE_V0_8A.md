# Content Engine v0.8a

## 1) v0.8a 定位

v0.8a 是 runtime exporter scaffold，不是真实 exporter release。
本阶段只做 exporter 框架、输入校验、候选筛选和 no-write 预览计划输出。

## 2) 阶段边界

- v0.7b：runtime export dry-run（基础导出条件与 blocker）。
- v0.7c：manual approval overlay（人工批准与 waiver 清理结果）。
- v0.7d：runtime export diff report（计划差异与风险审查）。
- v0.8a：exporter scaffold（默认 no-write）。

## 3) 为什么默认 no-write

当前阶段仍处于治理链路验证阶段，目标是验证导出入口与保护条件，而不是执行写入。
因此默认必须是 preview/no-write，避免提前生成 runtime 文件。

## 4) 为什么 v0.8a 不创建 data/runtime/content_engine/

因为 v0.8a 只输出 design-layer 的 exporter plan：

- `generated_runtime_exporter_plan.tsv`
- `generated_runtime_exporter_plan.md`

计划路径（`planned_runtime_path`）只是预期目标，不代表文件实际存在。

## 5) --write-runtime 在 v0.8a 的处理

`--write-runtime` 在 v0.8a 只作为占位参数，明确输出：

`write-runtime is intentionally disabled in v0.8a`

并保持：

- `write_enabled=false`
- `would_write=false`
- `actual_write_status=not_written`

## 6) v0.8b 才考虑 guarded write mode

v0.8b 或后续阶段才考虑受保护的写入模式，且需要附加 guardrail。

## 7) runtime 写入前的必备条件

真实 runtime 写入前必须同时满足：

- approval PASS
- waiver 清理完成
- diff report PASS
- exporter validator PASS
- 明确启用受保护写入模式

## 8) 运行命令

```bash
python3 tools/content_engine/runtime_exporter.py \
  --design-dir data/design \
  --diff-report data/design/generated_runtime_export_diff_report.tsv \
  --out data/design/generated_runtime_exporter_plan.tsv \
  --out-md data/design/generated_runtime_exporter_plan.md
```

```bash
python3 tools/content_engine/runtime_exporter_validator.py \
  --design-dir data/design
```
