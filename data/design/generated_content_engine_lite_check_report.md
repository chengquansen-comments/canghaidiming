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
| 1 | lite_export_battle_reward | 0 | PASS | 296 |  |
| 2 | lite_validate | 0 | PASS | 139 |  |
| 3 | lite_godot_probe | 0 | PASS | 1053 |  |
| 4 | battle_reward_runtime_adapter_scaffold_probe | 0 | PASS | 125 |  |
| 5 | battle_reward_runtime_adapter_scaffold_validator | 0 | PASS | 66 |  |
| 6 | battle_reward_shadow_integration_plan_probe | 0 | PASS | 113 |  |
| 7 | battle_reward_shadow_integration_plan_validator | 0 | PASS | 64 |  |
| 8 | battle_reward_shadow_runtime_probe | 0 | PASS | 115 |  |
| 9 | battle_reward_shadow_runtime_validator | 0 | PASS | 68 |  |
| 10 | battle_reward_shadow_freeze_probe | 0 | PASS | 117 |  |
| 11 | battle_reward_shadow_freeze_validator | 0 | PASS | 65 |  |
| 12 | battle_reward_runtime_test_harness | 0 | PASS | 106 |  |
| 13 | battle_reward_runtime_test_harness_validator | 0 | PASS | 63 |  |
| 14 | git_diff_check | 0 | PASS | 39 |  |
| 15 | godot_headless_quit | 0 | PASS | 436 |  |
| 16 | godot_headless_mainvisual | 0 | PASS | 1213 |  |
