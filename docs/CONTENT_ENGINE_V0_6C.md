# Content Engine v0.6c

## 1) v0.6c 目标

v0.6c 的目标是新增统一 validator orchestration 入口，顺序运行当前全部 design-layer content validators，并生成稳定的 validator summary。

本阶段输出 validator summary，不导出 runtime data，不修改 Godot 运行时，也不重跑 generators。

## 2) 为什么需要 validator orchestration

在 v0.6a 里，manifest 默认不重跑 validators，因此多数 artifact 会保留 `NOT_RUN`。
v0.6b report 只是把这个现状展示出来，但还没有统一的执行层。

v0.6c 的作用就是把已有 validators 纳入一个统一入口，得到：

- 稳定的 validator 执行顺序
- 每个 validator 的 return code / warnings / errors / duration
- 可追溯的 log 文件
- 可读的 Markdown validator summary

## 3) 输入文件

orchestrator 直接运行以下 validators：

- `progression_validator.py`
- `enemy_archetype_validator.py`
- `enemy_deck_skeleton_validator.py`
- `card_pool_validator.py`
- `enemy_deck_sets_validator.py`
- `battle_reward_validator.py`
- `operation_node_validator.py`
- `narrative_node_validator.py`
- `route_gate_validator.py`
- `content_package_manifest_validator.py`
- `content_package_report_validator.py`

这些 validators 会读取已有的 design-layer TSV / manifest / report。

## 4) 输出文件

v0.6c 输出：

- `data/design/generated_validator_summary.tsv`
- `data/design/generated_validator_summary.md`
- `data/design/validator_logs/*.log`

本次没有实现 `generated_content_package_manifest_validated.tsv`。
当前策略是：先生成独立 summary，不直接回写 manifest。

## 5) orchestration 会运行哪些 validators

运行顺序固定：

1. progression
2. enemy_archetype
3. enemy_deck_skeleton
4. card_pool
5. enemy_deck_sets
6. battle_reward
7. operation_node
8. narrative_node
9. route_gate
10. content_package_manifest
11. content_package_report

这样可以保证后置 validator 在读取 manifest / report 时，前置 design-layer产物已经稳定存在。

## 6) status 解析规则

orchestrator 对每个 validator 记录：

- `return_code`
- `warning_count`
- `error_count`
- `duration_ms`
- `summary_line`
- `log_path`

状态解析规则：

- 若输出包含 `RESULT: FAIL`，记为 `FAIL`。
- 若输出包含 `RESULT: WARN`，记为 `WARN`。
- 若输出包含 `RESULT: PASS` 且没有 warning，记为 `PASS`。
- 若输出包含 `RESULT: PASS` 但仍有 warning 行，记为 `WARN`。
- 若没有 `RESULT:` 行但 return code 为 0，记为 `WARN`，并标记 `missing_result_marker`。
- 若 return code 非 0，记为 `FAIL`。

## 7) 为什么 validator summary 不等于 runtime approval

validator summary 只是设计层质量状态汇总，不等于 runtime approval，原因包括：

- validator PASS 只说明当前设计层表满足已编码规则。
- 它不代表 runtime schema 已经定义完成。
- 它不代表 artifact 已完成人工审批。
- 它不代表 runtime exporter 已实现。

因此 v0.6c 仍然不能直接导出 runtime data。

## 8) 当前不做什么

v0.6c 明确不做以下事情：

- 不导出 runtime data。
- 不修改 Godot。
- 不修改 story battle TSV。
- 不重跑 generator。
- 不接 LLM API。

## 9) 如何运行 orchestrator

```bash
python3 tools/content_engine/content_validator_orchestrator.py \
  --design-dir data/design \
  --out-tsv data/design/generated_validator_summary.tsv \
  --out-md data/design/generated_validator_summary.md
```

## 10) 如何运行 summary validator

```bash
python3 tools/content_engine/content_validator_summary_validator.py \
  --design-dir data/design
```

## 11) 如何进入 v0.6d

v0.6d 建议进入 content package approval / manual review：

- 基于 manifest + report + validator summary 做人工批准。
- 新增 `approved_content_package_manifest.tsv` 或 approval table。
- 只有 `PASS + approved` 的 artifact 才能交给 v0.7 runtime exporter。
