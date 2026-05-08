# Content Engine 交付验收执行报告

- run_id=acceptance-20260508T044341Z-bb1807c0
- acceptance_status=PASS
- blocking_fail_count=0

## 步骤明细

| step_id | check_id | exit_code | status | duration_ms |
|---|---|---|---|---|
| 1 | battle_reward_shadow_freeze_probe | 0 | PASS | 167 |
| 2 | battle_reward_shadow_freeze_validator | 0 | PASS | 80 |
| 3 | battle_reward_runtime_test_harness | 0 | PASS | 151 |
| 4 | battle_reward_runtime_test_harness_validator | 0 | PASS | 70 |
| 5 | full_preview_readonly_probe_py | 0 | PASS | 69 |
| 6 | full_preview_readonly_probe_godot | 0 | PASS | 470 |
| 7 | full_preview_readonly_validator | 0 | PASS | 96 |
| 8 | full_package_shadow_compare_probe | 0 | PASS | 65 |
| 9 | full_package_shadow_compare_validator | 0 | PASS | 124 |
| 10 | full_package_candidate_path_probe | 0 | PASS | 58 |
| 11 | full_package_candidate_path_validator | 0 | PASS | 161 |
| 12 | full_package_whitelist_test_enable_probe | 0 | PASS | 51 |
| 13 | full_package_whitelist_test_enable_validator | 0 | PASS | 647 |
| 14 | full_package_runtime_readiness_audit | 0 | PASS | 83 |
| 15 | full_package_runtime_readiness_validator | 0 | PASS | 137 |
| 16 | full_content_runtime_bridge_contract_generator | 0 | PASS | 129 |
| 17 | full_content_runtime_bridge_contract_validator | 0 | PASS | 94 |
| 18 | generated_content_runtime_bridge_probe | 0 | PASS | 340 |
| 19 | generated_content_runtime_bridge_validator | 0 | PASS | 95 |
| 20 | generated_content_formal_enable_probe | 0 | PASS | 437 |
| 21 | generated_content_formal_enable_validator | 0 | PASS | 92 |
| 22 | generated_battle_domain_formal_probe | 0 | PASS | 719 |
| 23 | generated_battle_domain_formal_validator | 0 | PASS | 72 |
| 24 | generated_map_route_domain_formal_probe | 0 | PASS | 425 |
| 25 | generated_map_route_domain_formal_validator | 0 | PASS | 87 |
| 26 | generated_full_domain_enable_acceptance_probe | 0 | PASS | 428 |
| 27 | generated_full_domain_enable_acceptance_validator | 0 | PASS | 97 |
| 28 | generated_slice_whitelist_expander | 0 | PASS | 55 |
| 29 | generated_slice_whitelist_validator | 0 | PASS | 115 |
| 30 | generated_full_battle_slot_expander | 0 | PASS | 53 |
| 31 | generated_full_battle_slot_validator | 0 | PASS | 119 |
| 32 | generated_battle_flow_probe | 0 | PASS | 915 |
| 33 | generated_battle_flow_validator | 0 | PASS | 94 |
| 34 | generated_node_route_flow_probe | 0 | PASS | 788 |
| 35 | generated_node_route_flow_validator | 0 | PASS | 89 |
| 36 | generated_player_node_selection_probe | 0 | PASS | 7031 |
| 37 | generated_player_node_selection_validator | 0 | PASS | 97 |
| 38 | generated_node_battle_entry_probe | 0 | PASS | 6558 |
| 39 | generated_node_battle_entry_validator | 0 | PASS | 85 |
| 40 | generated_node_battle_start_probe | 0 | PASS | 6315 |
| 41 | generated_node_battle_start_validator | 0 | PASS | 86 |
| 42 | generated_playable_battle_entry_probe | 0 | PASS | 6591 |
| 43 | generated_playable_battle_entry_validator | 0 | PASS | 87 |
| 44 | generated_playable_battle_scene_probe | 0 | PASS | 6827 |
| 45 | generated_playable_battle_scene_validator | 0 | PASS | 85 |
| 46 | generated_minimal_playable_round_probe | 0 | PASS | 6897 |
| 47 | generated_minimal_playable_round_validator | 0 | PASS | 83 |
| 48 | generated_playable_loop_probe | 0 | PASS | 7114 |
| 49 | generated_playable_loop_validator | 0 | PASS | 89 |
| 50 | generated_player_visible_entry_probe | 0 | PASS | 1497 |
| 51 | generated_player_visible_entry_validator | 0 | PASS | 48 |
| 52 | generated_visible_ui_mount_probe | 0 | PASS | 1474 |
| 53 | generated_visible_ui_mount_validator | 0 | PASS | 47 |
| 54 | generated_playable_battle_loop_probe | 0 | PASS | 1293 |
| 55 | generated_playable_battle_loop_validator | 0 | PASS | 49 |
| 56 | generated_battle_runtime_loadout_probe | 0 | PASS | 423 |
| 57 | generated_battle_runtime_loadout_validator | 0 | PASS | 81 |
| 58 | generated_map_route_runtime_flow_probe | 0 | PASS | 434 |
| 59 | generated_map_route_runtime_flow_validator | 0 | PASS | 108 |
| 60 | generated_slice_full_integration_acceptance_probe | 0 | PASS | 722 |
| 61 | generated_slice_full_integration_acceptance_validator | 0 | PASS | 88 |
| 62 | content_engine_regression_runner | 0 | PASS | 5264 |
| 63 | content_engine_regression_validator | 0 | PASS | 950 |

## 说明

- 本 runner 顺序执行 shadow freeze、runtime harness、full preview readonly、full package shadow compare、full package candidate path、full package whitelist test enable、runtime readiness audit、runtime bridge contract、Godot runtime bridge spine、prologue formal enable、regression 链路。
- selected_reward 仍为 legacy，runtime reward 仍仅 candidate/shadow_compare。
- 本报告用于 v1.0d-final 的验收稳定性加固，确保不读取半写入文件、不依赖并行时序、无需复跑。
- 所有结论都不改变正式业务流程，不改变玩家实际奖励、不改变成长奖励、不改变结算 UI。
