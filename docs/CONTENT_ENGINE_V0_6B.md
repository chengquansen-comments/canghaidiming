# Content Engine v0.6b

## 1) v0.6b 目标

v0.6b 的目标是基于 manifest 生成一份稳定、可 diff、可人工审阅的 design-layer content package report：

- `data/design/generated_content_package_report.md`

该 report 只做设计层汇总，不生成 runtime data，不修改 Godot 运行时，也不重跑前序 generators 或 validators。

## 2) 输入文件

```text
data/design/generated_content_package_manifest.tsv
```

## 3) 输出文件

```text
data/design/generated_content_package_report.md
```

## 4) report 章节说明

report 固定输出以下内容：

- 顶部 summary：package version、source manifest、artifact count、runtime-ready count、blocked count。
- Executive Summary：说明当前仍是 design-layer package、runtime exporter 尚未实现、NOT_RUN 的语义、下一阶段方向。
- Artifact Inventory：列出 artifact / type / stage / rows / validator / runtime-ready / export scope。
- Dependency Graph：逐项列出 `depends_on_artifacts`。
- Validator Status Summary：按状态聚合并解释 `NOT_RUN`。
- Export Readiness：拆分 runtime-ready、blocked、manual-review candidates。
- Runtime Export Blockers：按 blocker 聚合计数。
- Risk Notes：基于 manifest 现状输出风险提示。
- Suggested Next Steps：明确 v0.6c / v0.6d / v0.7 的推进路径。

## 5) report 与 manifest 的关系

manifest 是结构化内容包登记表。
report 是 manifest 的可读摘要层。

两者职责不同：

- manifest 负责记录 artifact、依赖、row count、checksum、validator 状态和 runtime blockers。
- report 负责把这些信息整理成人和后续 Codex 可以快速理解的 Markdown 视图。

因此 report 不是新的真相来源，它必须从 manifest 派生，不能绕过 manifest 自行推断运行时结论。

## 6) 为什么 report 不等于 runtime exporter

v0.6b 仍然不导出任何 runtime data，原因包括：

- report 只是审阅层，不是导出执行层。
- manifest 当前仍可能含有大量 `NOT_RUN` 状态。
- `is_runtime_ready` 当前默认仍为 `false`。
- `export_blockers` 仍明确包含 `runtime_exporter_not_implemented` / `runtime_schema_not_defined` / `needs_manual_review`。

因此 report 的职责是说明“为什么现在不能导出”，而不是放宽导出条件。

## 7) 当前不做什么

v0.6b 明确不做以下事情：

- 不导出 runtime data。
- 不修改 Godot。
- 不修改 story battle TSV。
- 不重跑全部 validator。
- 不接 LLM API。

## 8) 如何运行 report generator

```bash
python3 tools/content_engine/content_package_report_generator.py \
  --design-dir data/design \
  --out data/design/generated_content_package_report.md
```

generator 只读取 manifest，不重跑 validator，不重跑 generator，不扫描 runtime 文件，也不修改任何输入 TSV。

## 9) 如何运行 report validator

```bash
python3 tools/content_engine/content_package_report_validator.py \
  --design-dir data/design
```

validator 重点检查：

- report / manifest 文件是否存在。
- 标题与关键章节是否存在。
- 顶部 artifact 数量是否与 manifest 一致。
- 每个 `artifact_id` 是否至少在 report 中出现一次。
- `NOT_RUN` 和 runtime block 提示是否存在。
- report 是否错误声称已经生成 runtime data 或可以直接导出 runtime。

## 10) 如何进入 v0.6c

v0.6c 建议做 validator orchestration：

- 统一运行所有 existing validators。
- 生成或回写统一的 validator status summary。
- 将 `NOT_RUN` 尽量收敛为 `PASS` / `WARN` / `FAIL`。
- 在 validator 结果稳定后，再决定 v0.7 runtime exporter 的准入边界。
