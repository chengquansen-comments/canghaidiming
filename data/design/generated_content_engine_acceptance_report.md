# Content Engine 交付验收报告

- acceptance_status=PASS
- blocking_fail_count=0
- non_blocking_warning_count=1

## 步骤明细

| step_id | step_name | exit_code | status | duration_ms | severity |
|---|---|---|---|---|---|
| 1 | content_engine_check | 0 | PASS | 4208 | blocking |
| 2 | content_engine_regression_runner | 0 | PASS | 6246 | blocking |
| 3 | content_engine_regression_validator | 0 | PASS | 1082 | blocking |
| 4 | git_diff_check | 0 | PASS | 38 | blocking |
| 5 | godot_headless_quit | 0 | PASS | 432 | blocking |
| 6 | godot_headless_mainvisual | 0 | NON_BLOCKING_WARNING | 1201 | non_blocking |

## 说明

- 本报告用于 v1.0d-prep 交付验收，不改变任何正式奖励流程。
- Godot 在退出码为 0 时出现 RID/ObjectDB/resource leak warning，按 non-blocking hygiene issue 记录。
- 仅 blocking 失败会使 acceptance_status 失败。
