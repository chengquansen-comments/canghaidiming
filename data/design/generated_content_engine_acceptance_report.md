# Content Engine 交付验收执行报告

- run_id=acceptance-20260508T045746Z-35d8e0c6
- acceptance_status=PASS
- blocking_fail_count=0

## 步骤明细

| step_id | check_id | exit_code | status | duration_ms |
|---|---|---|---|---|
| 1 | battle_reward_shadow_freeze_probe | 0 | PASS | 148 |
| 2 | battle_reward_shadow_freeze_validator | 0 | PASS | 72 |
| 3 | battle_reward_runtime_test_harness | 0 | PASS | 106 |
| 4 | battle_reward_runtime_test_harness_validator | 0 | PASS | 60 |
| 5 | full_preview_readonly_probe_py | 0 | PASS | 49 |
| 6 | full_preview_readonly_probe_godot | 0 | PASS | 332 |
| 7 | full_preview_readonly_validator | 0 | PASS | 86 |
| 8 | full_package_shadow_compare_probe | 0 | PASS | 52 |
| 9 | full_package_shadow_compare_validator | 0 | PASS | 86 |
| 10 | full_package_candidate_path_probe | 0 | PASS | 47 |
| 11 | full_package_candidate_path_validator | 0 | PASS | 90 |
| 12 | full_package_whitelist_test_enable_probe | 0 | PASS | 51 |
| 13 | full_package_whitelist_test_enable_validator | 0 | PASS | 94 |
| 14 | full_package_runtime_readiness_audit | 0 | PASS | 53 |
| 15 | full_package_runtime_readiness_validator | 0 | PASS | 88 |
| 16 | full_content_runtime_bridge_contract_generator | 0 | PASS | 53 |
| 17 | full_content_runtime_bridge_contract_validator | 0 | PASS | 89 |
| 18 | generated_content_runtime_bridge_probe | 0 | PASS | 342 |
| 19 | generated_content_runtime_bridge_validator | 0 | PASS | 82 |
| 20 | generated_content_formal_enable_probe | 0 | PASS | 330 |
| 21 | generated_content_formal_enable_validator | 0 | PASS | 83 |
| 22 | generated_battle_domain_formal_probe | 0 | PASS | 329 |
| 23 | generated_battle_domain_formal_validator | 0 | PASS | 76 |
| 24 | generated_map_route_domain_formal_probe | 0 | PASS | 425 |
| 25 | generated_map_route_domain_formal_validator | 0 | PASS | 79 |
| 26 | generated_full_domain_enable_acceptance_probe | 0 | PASS | 421 |
| 27 | generated_full_domain_enable_acceptance_validator | 0 | PASS | 80 |
| 28 | generated_slice_whitelist_expander | 0 | PASS | 49 |
| 29 | generated_slice_whitelist_validator | 0 | PASS | 111 |
| 30 | generated_full_battle_slot_expander | 0 | PASS | 48 |
| 31 | generated_full_battle_slot_validator | 0 | PASS | 111 |
| 32 | generated_battle_flow_probe | 0 | PASS | 619 |
| 33 | generated_battle_flow_validator | 0 | PASS | 135 |
| 34 | generated_node_route_flow_probe | 0 | PASS | 772 |
| 35 | generated_node_route_flow_validator | 0 | PASS | 87 |
| 36 | generated_player_node_selection_probe | 0 | PASS | 6690 |
| 37 | generated_player_node_selection_validator | 0 | PASS | 85 |
| 38 | generated_node_battle_entry_probe | 0 | PASS | 6591 |
| 39 | generated_node_battle_entry_validator | 0 | PASS | 98 |
| 40 | generated_node_battle_start_probe | 0 | PASS | 7952 |
| 41 | generated_node_battle_start_validator | 0 | PASS | 147 |
| 42 | generated_playable_battle_entry_probe | 0 | PASS | 6721 |
| 43 | generated_playable_battle_entry_validator | 0 | PASS | 85 |
| 44 | generated_playable_battle_scene_probe | 0 | PASS | 7777 |
| 45 | generated_playable_battle_scene_validator | 0 | PASS | 93 |
| 46 | generated_minimal_playable_round_probe | 0 | PASS | 7106 |
| 47 | generated_minimal_playable_round_validator | 0 | PASS | 80 |
| 48 | generated_playable_loop_probe | 0 | PASS | 7492 |
| 49 | generated_playable_loop_validator | 0 | PASS | 75 |
| 50 | generated_player_visible_entry_probe | 0 | PASS | 1593 |
| 51 | generated_player_visible_entry_validator | 0 | PASS | 52 |
| 52 | generated_visible_ui_mount_probe | 0 | PASS | 1487 |
| 53 | generated_visible_ui_mount_validator | 0 | PASS | 58 |
| 54 | generated_playable_battle_loop_probe | 0 | PASS | 1400 |
| 55 | generated_playable_battle_loop_validator | 0 | PASS | 49 |
| 56 | generated_real_node_entry_probe | 0 | PASS | 1801 |
| 57 | generated_real_node_entry_validator | 0 | PASS | 50 |
| 58 | generated_battle_runtime_loadout_probe | 0 | PASS | 429 |
| 59 | generated_battle_runtime_loadout_validator | 0 | PASS | 88 |
| 60 | generated_map_route_runtime_flow_probe | 0 | PASS | 527 |
| 61 | generated_map_route_runtime_flow_validator | 0 | PASS | 80 |
| 62 | generated_slice_full_integration_acceptance_probe | 0 | PASS | 911 |
| 63 | generated_slice_full_integration_acceptance_validator | 0 | PASS | 87 |
| 64 | content_engine_regression_runner | 0 | PASS | 5394 |
| 65 | content_engine_regression_validator | 0 | PASS | 956 |

## 说明

- 本 runner 顺序执行 shadow freeze、runtime harness、full preview readonly、full package shadow compare、full package candidate path、full package whitelist test enable、runtime readiness audit、runtime bridge contract、Godot runtime bridge spine、prologue formal enable、regression 链路。
- selected_reward 仍为 legacy，runtime reward 仍仅 candidate/shadow_compare。
- 本报告用于 v1.0d-final 的验收稳定性加固，确保不读取半写入文件、不依赖并行时序、无需复跑。
- 所有结论都不改变正式业务流程，不改变玩家实际奖励、不改变成长奖励、不改变结算 UI。
