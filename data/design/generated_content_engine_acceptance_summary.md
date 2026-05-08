# Content Engine Acceptance Summary

- run_id=acceptance-20260508T045746Z-35d8e0c6
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
| full_preview_readonly_probe_py | pass | data/design/generated_full_preview_readonly_probe_report.tsv | true | true |
| full_preview_readonly_probe_godot | pass | data/design/generated_full_preview_godot_readonly_report.tsv | true | true |
| full_preview_readonly_validator | PASS | none | true | true |
| full_package_shadow_compare_probe | pass | data/design/generated_content_domain_switch_matrix.tsv | true | true |
| full_package_shadow_compare_probe | pass | data/design/generated_full_package_shadow_compare_report.tsv | true | true |
| full_package_shadow_compare_validator | PASS | none | true | true |
| full_package_candidate_path_probe | pass | data/design/generated_full_package_candidate_path_report.tsv | true | true |
| full_package_candidate_path_validator | PASS | none | true | true |
| full_package_whitelist_test_enable_probe | pass | data/design/generated_full_package_whitelist_test_enable_report.tsv | true | true |
| full_package_whitelist_test_enable_validator | PASS | none | true | true |
| full_package_runtime_readiness_audit | pass | data/design/generated_full_package_runtime_readiness.tsv | true | true |
| full_package_runtime_readiness_audit | pass | data/design/generated_full_package_runtime_blockers.md | true | true |
| full_package_runtime_readiness_validator | PASS | none | true | true |
| full_content_runtime_bridge_contract_generator | pass | data/design/generated_full_content_adapter_contract.tsv | true | true |
| full_content_runtime_bridge_contract_generator | pass | data/design/generated_full_content_whitelist_binding_map.tsv | true | true |
| full_content_runtime_bridge_contract_generator | pass | data/runtime/content_engine_whitelist/prologue_01.full_content_bridge.json | true | true |
| full_content_runtime_bridge_contract_generator | pass | data/runtime/content_engine_whitelist/full_content_bridge_manifest.json | true | true |
| full_content_runtime_bridge_contract_validator | PASS | none | true | true |
| generated_content_runtime_bridge_probe | pass | data/design/generated_content_runtime_bridge_probe_report.tsv | true | true |
| generated_content_runtime_bridge_validator | PASS | none | true | true |
| generated_content_formal_enable_probe | pass | data/design/generated_content_formal_enable_report.tsv | true | true |
| generated_content_formal_enable_validator | PASS | none | true | true |
| generated_battle_domain_formal_probe | pass | data/design/generated_battle_domain_formal_report.tsv | true | true |
| generated_battle_domain_formal_validator | PASS | none | true | true |
| generated_map_route_domain_formal_probe | pass | data/design/generated_map_route_domain_formal_report.tsv | true | true |
| generated_map_route_domain_formal_validator | PASS | none | true | true |
| generated_full_domain_enable_acceptance_probe | pass | data/design/generated_full_domain_enable_acceptance_report.tsv | true | true |
| generated_full_domain_enable_acceptance_validator | PASS | none | true | true |
| generated_slice_whitelist_expander | pass | data/design/generated_slice_whitelist_config.tsv | true | true |
| generated_slice_whitelist_expander | pass | data/design/generated_slice_whitelist_binding_map.tsv | true | true |
| generated_slice_whitelist_expander | pass | data/design/generated_slice_whitelist_acceptance_report.tsv | true | true |
| generated_slice_whitelist_expander | pass | data/runtime/content_engine_whitelist/generated_slice.full_content_bridge.json | true | true |
| generated_slice_whitelist_expander | pass | data/runtime/content_engine_whitelist/generated_slice_manifest.json | true | true |
| generated_slice_whitelist_validator | PASS | none | true | true |
| generated_full_battle_slot_expander | pass | data/design/generated_full_battle_slot_whitelist_config.tsv | true | true |
| generated_full_battle_slot_expander | pass | data/design/generated_full_battle_slot_binding_map.tsv | true | true |
| generated_full_battle_slot_expander | pass | data/design/generated_full_battle_slot_integration_report.tsv | true | true |
| generated_full_battle_slot_expander | pass | data/runtime/content_engine_whitelist/generated_full_battle_slots.full_content_bridge.json | true | true |
| generated_full_battle_slot_expander | pass | data/runtime/content_engine_whitelist/generated_full_battle_slots_manifest.json | true | true |
| generated_full_battle_slot_validator | PASS | none | true | true |
| generated_battle_flow_probe | pass | data/design/generated_battle_flow_report.tsv | true | true |
| generated_battle_flow_validator | PASS | none | true | true |
| generated_node_route_flow_probe | pass | data/design/generated_node_route_flow_report.tsv | true | true |
| generated_node_route_flow_validator | PASS | none | true | true |
| generated_player_node_selection_probe | pass | data/design/generated_player_node_selection_report.tsv | true | true |
| generated_player_node_selection_validator | PASS | none | true | true |
| generated_node_battle_entry_probe | pass | data/design/generated_node_battle_entry_report.tsv | true | true |
| generated_node_battle_entry_validator | PASS | none | true | true |
| generated_node_battle_start_probe | pass | data/design/generated_node_battle_start_report.tsv | true | true |
| generated_node_battle_start_validator | PASS | none | true | true |
| generated_playable_battle_entry_probe | pass | data/design/generated_playable_battle_entry_report.tsv | true | true |
| generated_playable_battle_entry_validator | PASS | none | true | true |
| generated_playable_battle_scene_probe | pass | data/design/generated_playable_battle_scene_report.tsv | true | true |
| generated_playable_battle_scene_validator | PASS | none | true | true |
| generated_minimal_playable_round_probe | pass | data/design/generated_minimal_playable_round_report.tsv | true | true |
| generated_minimal_playable_round_validator | PASS | none | true | true |
| generated_playable_loop_probe | pass | data/design/generated_playable_loop_report.tsv | true | true |
| generated_playable_loop_validator | PASS | none | true | true |
| generated_player_visible_entry_probe | pass | data/design/generated_player_visible_entry_report.tsv | true | true |
| generated_player_visible_entry_validator | PASS | none | true | true |
| generated_visible_ui_mount_probe | pass | data/design/generated_visible_ui_mount_report.tsv | true | true |
| generated_visible_ui_mount_validator | PASS | none | true | true |
| generated_playable_battle_loop_probe | pass | data/design/generated_playable_battle_loop_report.tsv | true | true |
| generated_playable_battle_loop_validator | PASS | none | true | true |
| generated_real_node_entry_probe | pass | data/design/generated_real_node_entry_report.tsv | true | true |
| generated_real_node_entry_validator | PASS | none | true | true |
| generated_battle_runtime_loadout_probe | pass | data/design/generated_battle_runtime_loadout_report.tsv | true | true |
| generated_battle_runtime_loadout_validator | PASS | none | true | true |
| generated_map_route_runtime_flow_probe | pass | data/design/generated_map_route_runtime_flow_report.tsv | true | true |
| generated_map_route_runtime_flow_validator | PASS | none | true | true |
| generated_slice_full_integration_acceptance_probe | pass | data/design/generated_slice_full_integration_acceptance_report.tsv | true | true |
| generated_slice_full_integration_acceptance_validator | PASS | none | true | true |
| content_engine_regression_runner | pass | data/design/generated_content_engine_regression_report.tsv | true | true |
| content_engine_regression_runner | pass | data/design/generated_content_engine_regression_report.md | true | true |
| content_engine_regression_validator | PASS | none | true | true |

- `status` 取值：`pass` / `missing_report` / `empty_report` / `stale_report` / `invalid_report:*`。

## 说明

- 本摘要是 validator 的主入口，优先用于判断本轮 run_id 的报告完整性与新鲜度。
- 当出现 missing_report、empty_report、stale_report、invalid_report 任一状态时必须直接判定失败。
- 当前阶段保持 selected_reward=legacy，runtime_loader_config=disabled，runtime reward 仅候选对比，不进入正式奖励结算。
