# Content Engine v3.0：Generated Slice Full Integration Acceptance

## 目标
- 对 11 个白名单 slot 的 7 domain 生成内容链路进行切片级全域验收。
- 验证全链路可用、非白名单隔离、legacy 回滚、禁止写正式状态。

## 覆盖域
- battle_slot
- enemy_deck
- card_pool
- reward
- operation_node
- narrative（仅 key/hook）
- route_gate（不改正式分流）

## 结果产物
- `data/design/generated_slice_full_integration_acceptance_report.tsv`

## 验收命令
- `godot --headless --path . --script tools/content_engine/generated_slice_full_integration_acceptance_probe.gd`
- `python3 tools/content_engine/generated_slice_full_integration_acceptance_validator.py`
- `python3 tools/content_engine/content_engine_check.py`
- `python3 tools/content_engine/content_engine_acceptance_runner.py`
- `python3 tools/content_engine/content_engine_acceptance_validator.py`
