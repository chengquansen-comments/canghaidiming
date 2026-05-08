# Content Engine Lite 日常检查报告

- 总体状态：PASS
- battle_reward record_count: 45
- battle_reward Godot record_count: 45
- runtime 目录文件列表: battle_reward.json, card_pool.json, runtime_loader_config.json, runtime_manifest.json
- manifest 校验结果: PASS
- Godot probe 结果: PASS
- runtime_loader_config 保持 disabled: 是
- 仍未接入正式 loader: 是
- 是否替换正式数据源: 否
- 是否修改高风险文件: 否
- card_pool 状态: scaffold_or_unhydrated
- card_pool 集成状态: out_of_scope
- 是否还有 Godot warning: 是

## 步骤结果

| Step | Name | Exit Code | Status | Duration(ms) | Blocked Reason |
|---|---|---|---|---|---|
| 1 | lite_export_battle_reward | 0 | PASS | 144 |  |
| 2 | lite_validate | 0 | PASS | 122 |  |
| 3 | lite_godot_probe | 0 | PASS | 887 |  |
| 4 | battle_reward_runtime_adapter_scaffold_probe | 0 | PASS | 108 |  |
| 5 | battle_reward_runtime_adapter_scaffold_validator | 0 | PASS | 66 |  |
| 6 | battle_reward_shadow_integration_plan_probe | 0 | PASS | 111 |  |
| 7 | battle_reward_shadow_integration_plan_validator | 0 | PASS | 60 |  |
| 8 | battle_reward_shadow_runtime_probe | 0 | PASS | 111 |  |
| 9 | battle_reward_shadow_runtime_validator | 0 | PASS | 61 |  |
| 10 | battle_reward_shadow_freeze_probe | 0 | PASS | 124 |  |
| 11 | battle_reward_shadow_freeze_validator | 0 | PASS | 62 |  |
| 12 | battle_reward_runtime_test_harness | 0 | PASS | 98 |  |
| 13 | battle_reward_runtime_test_harness_validator | 0 | PASS | 61 |  |
| 14 | full_preview_readonly_probe_py | 0 | PASS | 51 |  |
| 15 | full_preview_readonly_probe_godot | 0 | PASS | 328 |  |
| 16 | full_preview_readonly_validator | 0 | PASS | 79 |  |
| 17 | full_package_shadow_compare_probe | 0 | PASS | 49 |  |
| 18 | full_package_shadow_compare_validator | 0 | PASS | 83 |  |
| 19 | full_package_candidate_path_probe | 0 | PASS | 48 |  |
| 20 | full_package_candidate_path_validator | 0 | PASS | 77 |  |
| 21 | full_package_whitelist_test_enable_probe | 0 | PASS | 45 |  |
| 22 | full_package_whitelist_test_enable_validator | 0 | PASS | 81 |  |
| 23 | full_package_runtime_readiness_audit | 0 | PASS | 47 |  |
| 24 | full_package_runtime_readiness_validator | 0 | PASS | 83 |  |
| 25 | full_content_runtime_bridge_contract_generator | 0 | PASS | 51 |  |
| 26 | full_content_runtime_bridge_contract_validator | 0 | PASS | 80 |  |
| 27 | generated_content_runtime_bridge_probe | 0 | PASS | 324 |  |
| 28 | generated_content_runtime_bridge_validator | 0 | PASS | 80 |  |
| 29 | generated_content_formal_enable_probe | 0 | PASS | 329 |  |
| 30 | generated_content_formal_enable_validator | 0 | PASS | 81 |  |
| 31 | generated_battle_domain_formal_probe | 0 | PASS | 423 |  |
| 32 | generated_battle_domain_formal_validator | 0 | PASS | 77 |  |
| 33 | generated_map_route_domain_formal_probe | 0 | PASS | 453 |  |
| 34 | generated_map_route_domain_formal_validator | 0 | PASS | 83 |  |
| 35 | generated_full_domain_enable_acceptance_probe | 0 | PASS | 425 |  |
| 36 | generated_full_domain_enable_acceptance_validator | 0 | PASS | 75 |  |
| 37 | generated_slice_whitelist_expander | 0 | PASS | 50 |  |
| 38 | generated_slice_whitelist_validator | 0 | PASS | 170 |  |
| 39 | generated_full_battle_slot_expander | 0 | PASS | 50 |  |
| 40 | generated_full_battle_slot_validator | 0 | PASS | 116 |  |
| 41 | generated_battle_flow_probe | 0 | PASS | 618 |  |
| 42 | generated_battle_flow_validator | 0 | PASS | 85 |  |
| 43 | generated_node_route_flow_probe | 0 | PASS | 729 |  |
| 44 | generated_node_route_flow_validator | 0 | PASS | 85 |  |
| 45 | generated_player_node_selection_probe | 0 | PASS | 6616 |  |
| 46 | generated_player_node_selection_validator | 0 | PASS | 79 |  |
| 47 | generated_node_battle_entry_probe | 0 | PASS | 7248 |  |
| 48 | generated_node_battle_entry_validator | 0 | PASS | 81 |  |
| 49 | generated_node_battle_start_probe | 0 | PASS | 7389 |  |
| 50 | generated_node_battle_start_validator | 0 | PASS | 95 |  |
| 51 | generated_playable_battle_entry_probe | 0 | PASS | 6737 |  |
| 52 | generated_playable_battle_entry_validator | 0 | PASS | 79 |  |
| 53 | generated_playable_battle_scene_probe | 0 | PASS | 7669 |  |
| 54 | generated_playable_battle_scene_validator | 0 | PASS | 76 |  |
| 55 | generated_minimal_playable_round_probe | 0 | PASS | 6997 |  |
| 56 | generated_minimal_playable_round_validator | 0 | PASS | 67 |  |
| 57 | generated_playable_loop_probe | 0 | PASS | 7676 |  |
| 58 | generated_playable_loop_validator | 0 | PASS | 86 |  |
| 59 | generated_player_visible_entry_probe | 0 | PASS | 1505 |  |
| 60 | generated_player_visible_entry_validator | 0 | PASS | 47 |  |
| 61 | generated_visible_ui_mount_probe | 0 | PASS | 1497 |  |
| 62 | generated_visible_ui_mount_validator | 0 | PASS | 51 |  |
| 63 | generated_playable_battle_loop_probe | 0 | PASS | 1413 |  |
| 64 | generated_playable_battle_loop_validator | 0 | PASS | 48 |  |
| 65 | generated_real_node_entry_probe | 0 | PASS | 1882 |  |
| 66 | generated_real_node_entry_validator | 0 | PASS | 52 |  |
| 67 | generated_battle_runtime_loadout_probe | 0 | PASS | 653 |  |
| 68 | generated_battle_runtime_loadout_validator | 0 | PASS | 100 |  |
| 69 | generated_map_route_runtime_flow_probe | 0 | PASS | 424 |  |
| 70 | generated_map_route_runtime_flow_validator | 0 | PASS | 77 |  |
| 71 | generated_slice_full_integration_acceptance_probe | 0 | PASS | 713 |  |
| 72 | generated_slice_full_integration_acceptance_validator | 0 | PASS | 87 |  |
| 73 | git_diff_check | 0 | PASS | 44 |  |
| 74 | godot_headless_quit | 0 | PASS | 424 |  |
| 75 | godot_headless_mainvisual | 0 | PASS | 1205 |  |
