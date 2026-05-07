# Content Engine Acceptance Summary

- run_id=acceptance-20260507T115817Z-6a327ab3
- overall_status=PASS
- selected_reward: legacy
- runtime_loader_config: disabled
- runtime_reward_mode: candidate/shadow_compare only
- actual_player_reward_changed: false
- battle_state_changed: false
- combat_result_changed: false

## Required Reports

| check_id | status | report_path | report_exists | report_non_empty |
|---|---|---|---|---|
| battle_reward_shadow_freeze_probe | pass | data/design/generated_battle_reward_shadow_freeze_report.tsv | true | true |
| battle_reward_shadow_freeze_probe | pass | data/design/generated_battle_reward_shadow_freeze_report.md | true | true |
| battle_reward_shadow_freeze_validator | PASS | none | true | true |
| battle_reward_runtime_test_harness | pass | data/design/generated_battle_reward_runtime_test_harness_report.tsv | true | true |
| battle_reward_runtime_test_harness | pass | data/design/generated_battle_reward_runtime_test_harness_report.md | true | true |
| battle_reward_runtime_test_harness_validator | PASS | none | true | true |
| content_engine_regression_runner | pass | data/design/generated_content_engine_regression_report.tsv | true | true |
| content_engine_regression_runner | pass | data/design/generated_content_engine_regression_report.md | true | true |
| content_engine_regression_validator | PASS | none | true | true |

- `status` 取值：`pass` / `missing_report` / `empty_report` / `stale_report` / `invalid_report:*`。

## 说明

- 本摘要是 validator 的主入口，优先用于判断本轮 run_id 的报告完整性与新鲜度。
- 当出现 missing_report、empty_report、stale_report、invalid_report 任一状态时必须直接判定失败。
- 当前阶段保持 selected_reward=legacy，runtime_loader_config=disabled，runtime reward 仅候选对比，不进入正式奖励结算。
