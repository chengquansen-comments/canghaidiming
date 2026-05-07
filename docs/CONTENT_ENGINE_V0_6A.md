# Content Engine v0.6a

## 1) v0.6a 目标

v0.6a 的目标是为现有设计层 Content Engine 生成内容包清单：

- `data/design/generated_content_package_manifest.tsv`

该 manifest 不生成任何 runtime data，不修改 Godot 运行时，也不重跑前序 generators。它只对当前设计层 artifact 做登记、追踪和导出边界约束。

## 2) 为什么还不能直接进入 runtime exporter

当前设计层虽然已经形成闭环，但还缺少 runtime exporter 所需的几个前提：

- 没有统一的 content package manifest 作为单一入口。
- 没有把 artifact 依赖关系显式固定下来。
- 没有把 row count / checksum 固化为可追踪元数据。
- 还没有把 validator 结果和 runtime blocker 绑定到导出边界。
- 还没有人工批准机制去拦截“结构上存在但未经确认”的 generated 表。

因此 v0.6a 先做 manifest，先把“能导什么、不能导什么、为什么不能导”固定下来，再谈 runtime exporter。

## 3) manifest 的作用

manifest 的职责包括：

- 记录 artifact。
- 记录 artifact 之间的依赖关系。
- 记录每个表的 `row_count`。
- 记录每个表的 `checksum_sha256`。
- 记录每个表的 `validator_status`、warning 和 error 计数。
- 阻止未经校验或未人工批准的 generated 表直接进入 runtime。

换句话说，v0.6a 引入的是“内容包边界层”，不是“运行时导出层”。

## 4) 输出文件

```text
data/design/generated_content_package_manifest.tsv
```

manifest 至少覆盖以下 13 个核心 artifact：

1. `data/design/progression_numeric_config_v1_3.tsv`
2. `data/design/generated_battle_slot_plan.tsv`
3. `data/design/generated_enemy_deck_requirement.tsv`
4. `data/design/generated_route_progression_curve.tsv`
5. `data/design/generated_operation_node_requirement.tsv`
6. `data/design/generated_enemy_archetype_pool.tsv`
7. `data/design/generated_enemy_deck_skeleton.tsv`
8. `data/design/generated_card_pool.tsv`
9. `data/design/generated_enemy_deck_sets.tsv`
10. `data/design/generated_battle_reward_plan.tsv`
11. `data/design/generated_operation_node_plan.tsv`
12. `data/design/generated_narrative_node_plan.tsv`
13. `data/design/generated_route_gate_plan.tsv`

## 5) 字段说明

manifest 字段固定为：

- `manifest_id`
- `package_version`
- `artifact_id`
- `artifact_type`
- `artifact_path`
- `source_stage`
- `generator_script`
- `validator_script`
- `required_inputs`
- `depends_on_artifacts`
- `row_count`
- `checksum_sha256`
- `validator_status`
- `validator_warning_count`
- `validator_error_count`
- `is_runtime_ready`
- `export_scope`
- `export_blockers`
- `notes`

字段用途：

- `artifact_id`：用不带扩展名的文件名标识 artifact。
- `artifact_type`：区分 `source_config` / `generated_table` / `design_plan` / `reward_plan` / `narrative_plan` / `route_gate_plan`。
- `required_inputs`：列出生成该 artifact 所需输入文件。
- `depends_on_artifacts`：列出上游 artifact ID 依赖。
- `row_count`：TSV 数据行数，不含 header。
- `checksum_sha256`：文件内容哈希。
- `validator_status`：当前可记录 `SOURCE_ONLY` / `NOT_RUN` / `PASS` / `WARN` / `FAIL`。
- `is_runtime_ready`：当前阶段默认应为 `false`。
- `export_scope` / `export_blockers`：声明未来导出方向和当前阻塞原因。

## 6) 如何运行 generator

```bash
python3 tools/content_engine/content_package_manifest_generator.py \
  --design-dir data/design \
  --out data/design/generated_content_package_manifest.tsv
```

默认行为：

- 不重跑前序 generators。
- 不自动重跑 validators。
- 只根据现有文件、静态依赖图、实际行数和实际 sha256 生成 manifest。

如果未来需要，也可以扩展为在生成 manifest 时显式执行 validators。

## 7) 如何运行 validator

```bash
python3 tools/content_engine/content_package_manifest_validator.py \
  --design-dir data/design
```

当前 validator 重点检查：

- manifest 文件是否存在。
- 是否包含全部 13 个核心 artifact。
- `artifact_id` 是否唯一。
- `artifact_path` / `generator_script` / `validator_script` 是否存在。
- `row_count` / `checksum_sha256` 是否与实际文件一致。
- generated table 的 `validator_status` 不得为 `FAIL`。
- generated table 的 `is_runtime_ready` 当前应为 `false`。
- generated table 的 `export_blockers` 不得为空。
- `depends_on_artifacts` 是否引用了 manifest 内存在的 artifact。
- 关键链路依赖是否满足：deck sets / reward / operation / narrative / route gate。

## 8) 当前不做什么

v0.6a 明确不做以下事情：

- 不导出 runtime data。
- 不修改 Godot。
- 不修改 story battle TSV。
- 不接 LLM API。
- 不接 auto battle sampler。

## 9) 如何进入 v0.6b

v0.6b 建议做 `content package report generator`，输出：

- `data/design/generated_content_package_report.md`

报告内容建议包括：

- 各 artifact 数量统计。
- 依赖关系摘要。
- validator 状态汇总。
- runtime blockers 汇总。
- 需要人工复核的风险点。

v0.6b 的重点是“可读报告层”，让设计层产物更容易审查和批准。

## 10) 如何进入 v0.7

v0.7 才进入 runtime exporter，并且要满足两条硬约束：

- runtime exporter 必须读取 manifest，而不是绕过 manifest 直接扫表。
- 只允许导出 `validator_status=PASS` 且经过人工批准的 artifact。

在 v0.7 之前，manifest 的职责是阻断不安全导出，而不是放宽导出门槛。
