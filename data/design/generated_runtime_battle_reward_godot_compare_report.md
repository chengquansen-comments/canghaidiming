# Runtime Battle Reward Godot 对比报告

- 阶段：v0.9d battle_reward read-only Godot compare/probe
- runtime_domain: battle_reward
- godot_probe_exit_code: 0
- godot_probe_ok: true
- record_count_match_status: matched
- field_count_match_status: matched
- blocked_reason: none

## 对比结果行

| Runtime Domain | Godot Records | Python Records | Legacy Records | Godot Fields | Python Fields | Record Match | Field Match | Missing In Godot | Extra In Godot |
|---|---|---|---|---|---|---|---|---|---|
| battle_reward | 45 | 45 | 45 | 30 | 30 | matched | matched | 0 | 0 |

## 边界检查

- manifest_first: true
- read_only: true
- formal_data_source_replaced: false
- integration_status: godot_compare_only
- gate_config_enabled: false
- gate_integration_mode: disabled
- existing_gd_reference_count: 0

## 说明

- v0.9d 仅做 battle_reward Godot 只读探针对比，不接入正式奖励逻辑，不替换正式数据源。 Python compare integration_status=hydrated_compare_only。
