# Content Engine v1.9 whitelist test enable skeleton

## 目标
仅对白名单 `battle_slot=prologue_01`，在离线 probe 中模拟 `test_content_engine_enabled=true` 的 full package candidate 路径。
正式流程保持 legacy，不启用正式 content engine。

## 强约束
- 正式 `content_engine_enabled=false`
- 正式 `selected_reward=legacy`
- 正式 `runtime_loader_config=disabled`
- 不写 `data/runtime/`
- 不改 Godot 正式流程

## 输出
- `data/design/generated_full_package_whitelist_test_enable_report.tsv`

## 测试模拟范围
- battle_slot: `prologue_01`
- reward: `rw_prologue_01`
- card_pool_count: `72`
- operation_node_count: `10`
- narrative_node_count: `28`（仅 key/hook，不含正文）
- route_gate_count: `9`
- enemy_deck: 若无直接绑定可为不可用，不判失败

## 接入
- `content_engine_check.py` 增加 `full_package_whitelist_test_enable_validator`
- `content_engine_acceptance_runner.py` 增加 probe + validator
- `content_engine_acceptance_validator.py` 校验 summary 覆盖新增 step
