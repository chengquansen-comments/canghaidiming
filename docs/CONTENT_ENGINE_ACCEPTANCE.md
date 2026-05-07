# Content Engine 交付验收入口（v1.0d-prep）

## 1. 阶段定位

本阶段是 `v1.0d-prep`，目标是把 battle_reward 在 v1.0c 之后的交付验收、shadow 边界冻结与 runtime_test 离线准备一次性固化。
本阶段不是 `runtime_enabled`，不让 runtime reward 进入正式游戏流程。

## 2. 为什么需要一键交付验收

日常 `check` 与高级 `regression` 只能覆盖局部脚本链路。
交付前仍需要统一入口，串联全部 blocking 命令并输出单一结论，减少人工漏项。

## 3. runner 覆盖范围

`tools/content_engine/content_engine_acceptance_runner.py` 依次执行：

1. `python3 tools/content_engine/content_engine_check.py`
2. `python3 tools/content_engine/content_engine_regression_runner.py`
3. `python3 tools/content_engine/content_engine_regression_validator.py`
4. `git diff --check`
5. `godot --headless --path . --quit`
6. `godot --headless --path . --quit scenes/MainVisual.tscn`

并生成：

- `data/design/generated_content_engine_acceptance_report.tsv`
- `data/design/generated_content_engine_acceptance_report.md`

## 4. validator 验收标准

`tools/content_engine/content_engine_acceptance_validator.py` 要求：

1. 报告文件存在且步骤完整。
2. 所有 blocking 步骤状态为 PASS。
3. Godot warning 仅允许标记为 non-blocking。
4. Markdown 报告中文说明约束通过。

## 5. non-blocking Godot warning 处理

当 Godot 命令退出码为 0，但日志出现 RID/ObjectDB/resource leak warning：

- 记录为 `NON_BLOCKING_WARNING`；
- `severity=non_blocking`；
- 不影响 `acceptance_status=PASS`。

## 6. 使用命令

```bash
python3 tools/content_engine/content_engine_acceptance_runner.py
python3 tools/content_engine/content_engine_acceptance_validator.py
```

## 7. 后续阶段复用方式

后续阶段可直接复用该入口，只需在 `content_engine_check.py` 与 `content_engine_regression_runner.py` 维护步骤集合。
`acceptance_runner` 保持高层编排，不反向嵌套自身，避免递归调用。
