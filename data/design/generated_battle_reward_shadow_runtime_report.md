# Battle Reward Shadow Runtime 探测报告

- blocking 失败数: 0

## 关键结论

- shadow_integration_present=true
- shadow_integration_file=scripts/narrative_demo_canonical_controller.gd
- shadow_integration_function=_battle_reward_for_source
- selected_reward_source=legacy
- selected_reward_runtime_effective=false
- runtime_reward_candidate_only=true
- formal_data_source_replaced=false
- runtime_loader_config_disabled=true
- battle_state_touched=false
- combat_result_touched=false
- high_risk_files_touched=false
- runtime_dir_whitelist_status=pass
- battle_reward_runtime_record_count=45

## 明细

| check_id | status | expected | actual | severity |
|---|---|---|---|---|
| canonical_file_exists | PASS | true | true | blocking |
| shadow_integration_present | PASS | true | true | blocking |
| shadow_integration_file | PASS | scripts/narrative_demo_canonical_controller.gd | scripts/narrative_demo_canonical_controller.gd | blocking |
| shadow_integration_function | PASS | _battle_reward_for_source | _battle_reward_for_source | blocking |
| shadow_marker_present | PASS | true | true | blocking |
| selected_reward_source | PASS | legacy | legacy | blocking |
| runtime_reward_candidate_only | PASS | true | true | blocking |
| shadow_region_dangerous_call_count | PASS | 0 | 0 | blocking |
| adapter_formal_flow_reference_count | PASS | 0_outside_allowlist | 0 | blocking |
| canonical_controller_adapter_reference_count | PASS | >=1 | 3 | blocking |
| runtime_loader_config_disabled | PASS | true | true | blocking |
| battle_reward_runtime_record_count | PASS | 45 | 45 | blocking |
| runtime_dir_whitelist_status | PASS | pass | pass | blocking |
| high_risk_files_touched | PASS | false | false | blocking |
| formal_data_source_replaced | PASS | false | false | blocking |
| selected_reward_runtime_effective | PASS | false | false | blocking |
| battle_state_touched | PASS | false | false | blocking |
| combat_result_touched | PASS | false | false | blocking |

## 说明

- 本阶段为 shadow 实接：只旁路对比，不改变正式奖励结果。
- 任何 blocking 失败均视为不满足 v1.0c 安全边界。
