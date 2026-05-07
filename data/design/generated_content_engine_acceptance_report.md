# Content Engine 交付验收执行报告

- run_id=acceptance-20260507T123901Z-747533c8
- acceptance_status=PASS
- blocking_fail_count=0

## 步骤明细

| step_id | check_id | exit_code | status | duration_ms |
|---|---|---|---|---|
| 1 | battle_reward_shadow_freeze_probe | 0 | PASS | 113 |
| 2 | battle_reward_shadow_freeze_validator | 0 | PASS | 62 |
| 3 | battle_reward_runtime_test_harness | 0 | PASS | 102 |
| 4 | battle_reward_runtime_test_harness_validator | 0 | PASS | 60 |
| 5 | full_preview_readonly_probe_py | 0 | PASS | 49 |
| 6 | full_preview_readonly_probe_godot | 0 | PASS | 340 |
| 7 | full_preview_readonly_validator | 0 | PASS | 77 |
| 8 | content_engine_regression_runner | 0 | PASS | 5155 |
| 9 | content_engine_regression_validator | 0 | PASS | 951 |

## 说明

- 本 runner 顺序执行 shadow freeze、runtime harness、full preview readonly、regression 链路。
- selected_reward 仍为 legacy，runtime reward 仍仅 candidate/shadow_compare。
- 本报告用于 v1.0d-final 的验收稳定性加固，确保不读取半写入文件、不依赖并行时序、无需复跑。
- 所有结论都不改变正式业务流程，不改变玩家实际奖励、不改变成长奖励、不改变结算 UI。
