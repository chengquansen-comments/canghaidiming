# Battle Reward Shadow Freeze 探测报告

- blocking_fail_count=0

## 关键结论

- shadow_freeze_status=pass
- shadow_integration_file=scripts/narrative_demo_canonical_controller.gd
- shadow_integration_function=_battle_reward_for_source
- selected_reward_source=legacy
- selected_reward_runtime_effective=false
- runtime_reward_candidate_only=true
- runtime_loader_config_disabled=true
- formal_data_source_replaced=false
- high_risk_files_touched=false
- runtime_dir_whitelist_status=pass
- battle_reward_runtime_record_count=45

## 明细

| check_id | status | expected | actual | severity |
|---|---|---|---|---|
| adapter_formal_flow_reference_count | PASS | 0 | 0 | blocking |
| shadow_integration_file | PASS | scripts/narrative_demo_canonical_controller.gd | scripts/narrative_demo_canonical_controller.gd | blocking |
| shadow_integration_function | PASS | _battle_reward_for_source | _battle_reward_for_source | blocking |
| shadow_integration_point_only | PASS | true | true | blocking |
| shadow_marker_present | PASS | true | true | blocking |
| runtime_enabled_formal_logic_absent | PASS | true | true | blocking |
| selected_reward_source | PASS | legacy | legacy | blocking |
| selected_reward_runtime_effective | PASS | false | false | blocking |
| runtime_reward_candidate_only | PASS | true | true | blocking |
| runtime_loader_config_disabled | PASS | true | true | blocking |
| battle_reward_runtime_record_count | PASS | 45 | 45 | blocking |
| formal_data_source_replaced | PASS | false | false | blocking |
| high_risk_files_touched | PASS | false | false | blocking |
| runtime_dir_whitelist_status | PASS | pass | pass | blocking |
| shadow_region_dangerous_call_count | PASS | 0 | 0 | blocking |
| shadow_freeze_status | PASS | pass | pass | blocking |

## 说明

- 本探测用于冻结 v1.0c shadow 边界，禁止 runtime 奖励误入正式流程。
- 任何 blocking 失败都应阻断后续提交。
