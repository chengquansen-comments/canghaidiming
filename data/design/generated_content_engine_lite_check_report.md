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
| 1 | lite_export_battle_reward | 0 | PASS | 112 |  |
| 2 | lite_validate | 0 | PASS | 126 |  |
| 3 | lite_godot_probe | 0 | PASS | 758 |  |
| 4 | battle_reward_runtime_adapter_scaffold_probe | 0 | PASS | 98 |  |
| 5 | battle_reward_runtime_adapter_scaffold_validator | 0 | PASS | 52 |  |
| 6 | battle_reward_shadow_integration_plan_probe | 0 | PASS | 101 |  |
| 7 | battle_reward_shadow_integration_plan_validator | 0 | PASS | 72 |  |
| 8 | battle_reward_shadow_runtime_probe | 0 | PASS | 84 |  |
| 9 | battle_reward_shadow_runtime_validator | 0 | PASS | 54 |  |
| 10 | battle_reward_shadow_freeze_probe | 0 | PASS | 90 |  |
| 11 | battle_reward_shadow_freeze_validator | 0 | PASS | 52 |  |
| 12 | battle_reward_runtime_test_harness | 0 | PASS | 85 |  |
| 13 | battle_reward_runtime_test_harness_validator | 0 | PASS | 54 |  |
| 14 | full_preview_readonly_probe_py | 0 | PASS | 43 |  |
| 15 | full_preview_readonly_probe_godot | 0 | PASS | 321 |  |
| 16 | full_preview_readonly_validator | 0 | PASS | 73 |  |
| 17 | full_package_shadow_compare_probe | 0 | PASS | 44 |  |
| 18 | full_package_shadow_compare_validator | 0 | PASS | 75 |  |
| 19 | full_package_candidate_path_probe | 0 | PASS | 41 |  |
| 20 | full_package_candidate_path_validator | 0 | PASS | 75 |  |
| 21 | full_package_whitelist_test_enable_probe | 0 | PASS | 41 |  |
| 22 | full_package_whitelist_test_enable_validator | 0 | PASS | 73 |  |
| 23 | full_package_runtime_readiness_audit | 0 | PASS | 43 |  |
| 24 | full_package_runtime_readiness_validator | 0 | PASS | 72 |  |
| 25 | full_content_runtime_bridge_contract_generator | 0 | PASS | 47 |  |
| 26 | full_content_runtime_bridge_contract_validator | 0 | PASS | 76 |  |
| 27 | generated_content_runtime_bridge_probe | 0 | PASS | 326 |  |
| 28 | generated_content_runtime_bridge_validator | 0 | PASS | 74 |  |
| 29 | generated_content_formal_enable_probe | 0 | PASS | 321 |  |
| 30 | generated_content_formal_enable_validator | 0 | PASS | 84 |  |
| 31 | generated_battle_domain_formal_probe | 0 | PASS | 336 |  |
| 32 | generated_battle_domain_formal_validator | 0 | PASS | 73 |  |
| 33 | generated_map_route_domain_formal_probe | 0 | PASS | 433 |  |
| 34 | generated_map_route_domain_formal_validator | 0 | PASS | 73 |  |
| 35 | generated_full_domain_enable_acceptance_probe | 0 | PASS | 423 |  |
| 36 | generated_full_domain_enable_acceptance_validator | 0 | PASS | 71 |  |
| 37 | generated_slice_whitelist_expander | 0 | PASS | 45 |  |
| 38 | generated_slice_whitelist_validator | 0 | PASS | 99 |  |
| 39 | generated_full_battle_slot_expander | 0 | PASS | 43 |  |
| 40 | generated_full_battle_slot_validator | 0 | PASS | 101 |  |
| 41 | generated_battle_flow_probe | 0 | PASS | 529 |  |
| 42 | generated_battle_flow_validator | 0 | PASS | 70 |  |
| 43 | generated_node_route_flow_probe | 0 | PASS | 624 |  |
| 44 | generated_node_route_flow_validator | 0 | PASS | 73 |  |
| 45 | generated_player_node_selection_probe | 0 | PASS | 6057 |  |
| 46 | generated_player_node_selection_validator | 0 | PASS | 74 |  |
| 47 | generated_node_battle_entry_probe | 0 | PASS | 6079 |  |
| 48 | generated_node_battle_entry_validator | 0 | PASS | 76 |  |
| 49 | generated_node_battle_start_probe | 0 | PASS | 601221 |  |
| 50 | generated_node_battle_start_validator | 0 | PASS | 376 |  |
| 51 | generated_playable_battle_entry_probe | 0 | PASS | 7312 |  |
| 52 | generated_playable_battle_entry_validator | 0 | PASS | 91 |  |
| 53 | generated_playable_battle_scene_probe | 0 | PASS | 8053 |  |
| 54 | generated_playable_battle_scene_validator | 0 | PASS | 94 |  |
| 55 | generated_minimal_playable_round_probe | 0 | PASS | 6886 |  |
| 56 | generated_minimal_playable_round_validator | 0 | PASS | 91 |  |
| 57 | generated_playable_loop_probe | 0 | PASS | 7665 |  |
| 58 | generated_playable_loop_validator | 0 | PASS | 100 |  |
| 59 | generated_player_visible_entry_probe | 0 | PASS | 1603 |  |
| 60 | generated_player_visible_entry_validator | 0 | PASS | 52 |  |
| 61 | generated_visible_ui_mount_probe | 0 | PASS | 1618 |  |
| 62 | generated_visible_ui_mount_validator | 0 | PASS | 53 |  |
| 63 | generated_playable_battle_loop_probe | 0 | PASS | 1490 |  |
| 64 | generated_playable_battle_loop_validator | 0 | PASS | 48 |  |
| 65 | generated_battle_runtime_loadout_probe | 0 | PASS | 524 |  |
| 66 | generated_battle_runtime_loadout_validator | 0 | PASS | 89 |  |
| 67 | generated_map_route_runtime_flow_probe | 0 | PASS | 526 |  |
| 68 | generated_map_route_runtime_flow_validator | 0 | PASS | 77 |  |
| 69 | generated_slice_full_integration_acceptance_probe | 0 | PASS | 731 |  |
| 70 | generated_slice_full_integration_acceptance_validator | 0 | PASS | 89 |  |
| 71 | git_diff_check | 0 | PASS | 34 |  |
| 72 | godot_headless_quit | 0 | PASS | 438 |  |
| 73 | godot_headless_mainvisual | 0 | PASS | 1231 |  |
