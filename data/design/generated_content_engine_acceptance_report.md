# Content Engine 交付验收执行报告

- run_id=acceptance-20260508T035759Z-bffdf8f8
- acceptance_status=PASS
- blocking_fail_count=0

## 步骤明细

| step_id | check_id | exit_code | status | duration_ms |
|---|---|---|---|---|
| 1 | battle_reward_shadow_freeze_probe | 0 | PASS | 132 |
| 2 | battle_reward_shadow_freeze_validator | 0 | PASS | 59 |
| 3 | battle_reward_runtime_test_harness | 0 | PASS | 95 |
| 4 | battle_reward_runtime_test_harness_validator | 0 | PASS | 59 |
| 5 | full_preview_readonly_probe_py | 0 | PASS | 49 |
| 6 | full_preview_readonly_probe_godot | 0 | PASS | 336 |
| 7 | full_preview_readonly_validator | 0 | PASS | 97 |
| 8 | full_package_shadow_compare_probe | 0 | PASS | 55 |
| 9 | full_package_shadow_compare_validator | 0 | PASS | 93 |
| 10 | full_package_candidate_path_probe | 0 | PASS | 49 |
| 11 | full_package_candidate_path_validator | 0 | PASS | 92 |
| 12 | full_package_whitelist_test_enable_probe | 0 | PASS | 50 |
| 13 | full_package_whitelist_test_enable_validator | 0 | PASS | 86 |
| 14 | full_package_runtime_readiness_audit | 0 | PASS | 46 |
| 15 | full_package_runtime_readiness_validator | 0 | PASS | 80 |
| 16 | full_content_runtime_bridge_contract_generator | 0 | PASS | 54 |
| 17 | full_content_runtime_bridge_contract_validator | 0 | PASS | 76 |
| 18 | generated_content_runtime_bridge_probe | 0 | PASS | 341 |
| 19 | generated_content_runtime_bridge_validator | 0 | PASS | 83 |
| 20 | generated_content_formal_enable_probe | 0 | PASS | 468 |
| 21 | generated_content_formal_enable_validator | 0 | PASS | 84 |
| 22 | generated_battle_domain_formal_probe | 0 | PASS | 445 |
| 23 | generated_battle_domain_formal_validator | 0 | PASS | 77 |
| 24 | generated_map_route_domain_formal_probe | 0 | PASS | 428 |
| 25 | generated_map_route_domain_formal_validator | 0 | PASS | 87 |
| 26 | generated_full_domain_enable_acceptance_probe | 0 | PASS | 441 |
| 27 | generated_full_domain_enable_acceptance_validator | 0 | PASS | 130 |
| 28 | generated_slice_whitelist_expander | 0 | PASS | 67 |
| 29 | generated_slice_whitelist_validator | 0 | PASS | 117 |
| 30 | generated_full_battle_slot_expander | 0 | PASS | 53 |
| 31 | generated_full_battle_slot_validator | 0 | PASS | 123 |
| 32 | generated_battle_flow_probe | 0 | PASS | 614 |
| 33 | generated_battle_flow_validator | 0 | PASS | 85 |
| 34 | generated_node_route_flow_probe | 0 | PASS | 722 |
| 35 | generated_node_route_flow_validator | 0 | PASS | 84 |
| 36 | generated_player_node_selection_probe | 0 | PASS | 6531 |
| 37 | generated_player_node_selection_validator | 0 | PASS | 90 |
| 38 | generated_node_battle_entry_probe | 0 | PASS | 6324 |
| 39 | generated_node_battle_entry_validator | 0 | PASS | 78 |
| 40 | generated_node_battle_start_probe | 0 | PASS | 6333 |
| 41 | generated_node_battle_start_validator | 0 | PASS | 84 |
| 42 | generated_playable_battle_entry_probe | 0 | PASS | 6711 |
| 43 | generated_playable_battle_entry_validator | 0 | PASS | 89 |
| 44 | generated_playable_battle_scene_probe | 0 | PASS | 7193 |
| 45 | generated_playable_battle_scene_validator | 0 | PASS | 85 |
| 46 | generated_minimal_playable_round_probe | 0 | PASS | 7183 |
| 47 | generated_minimal_playable_round_validator | 0 | PASS | 83 |
| 48 | generated_playable_loop_probe | 0 | PASS | 7608 |
| 49 | generated_playable_loop_validator | 0 | PASS | 91 |
| 50 | generated_player_visible_entry_probe | 0 | PASS | 1703 |
| 51 | generated_player_visible_entry_validator | 0 | PASS | 57 |
| 52 | generated_visible_ui_mount_probe | 0 | PASS | 1600 |
| 53 | generated_visible_ui_mount_validator | 0 | PASS | 53 |
| 54 | generated_battle_runtime_loadout_probe | 0 | PASS | 526 |
| 55 | generated_battle_runtime_loadout_validator | 0 | PASS | 94 |
| 56 | generated_map_route_runtime_flow_probe | 0 | PASS | 528 |
| 57 | generated_map_route_runtime_flow_validator | 0 | PASS | 88 |
| 58 | generated_slice_full_integration_acceptance_probe | 0 | PASS | 724 |
| 59 | generated_slice_full_integration_acceptance_validator | 0 | PASS | 85 |
| 60 | content_engine_regression_runner | 0 | PASS | 5602 |
| 61 | content_engine_regression_validator | 0 | PASS | 923 |

## 说明

- 本 runner 顺序执行 shadow freeze、runtime harness、full preview readonly、full package shadow compare、full package candidate path、full package whitelist test enable、runtime readiness audit、runtime bridge contract、Godot runtime bridge spine、prologue formal enable、regression 链路。
- selected_reward 仍为 legacy，runtime reward 仍仅 candidate/shadow_compare。
- 本报告用于 v1.0d-final 的验收稳定性加固，确保不读取半写入文件、不依赖并行时序、无需复跑。
- 所有结论都不改变正式业务流程，不改变玩家实际奖励、不改变成长奖励、不改变结算 UI。
