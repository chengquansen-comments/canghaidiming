# Content Engine v2.6：prologue_01 Full Generated Content Enable Acceptance

## 目标
- 对 `prologue_01` 白名单的 7 domain 接入进行总体验收。
- 验证全域候选可读、非白名单隔离、legacy 回滚有效。

## 验收范围
- battle_slot
- enemy_deck
- card_pool
- reward
- operation_node
- narrative
- route_gate

## 强约束
- 非白名单必须 legacy。
- fallback_policy 必须 legacy。
- card_pool 不写 CardData。
- narrative 仅 key/hook，不生成正文。
- route_gate 不改变正式分流。
- 不写 game state / battle_state / combat_result。

## 结果产物
- `data/design/generated_full_domain_enable_acceptance_report.tsv`

## 使用命令
- `godot --headless --path . --script tools/content_engine/generated_full_domain_enable_acceptance_probe.gd`
- `python3 tools/content_engine/generated_full_domain_enable_acceptance_validator.py`
- `python3 tools/content_engine/content_engine_check.py`
- `python3 tools/content_engine/content_engine_acceptance_runner.py`
- `python3 tools/content_engine/content_engine_acceptance_validator.py`
