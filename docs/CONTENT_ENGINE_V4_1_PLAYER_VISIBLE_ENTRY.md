# v4.1 player-visible generated content test entry

## 目标
在现有游戏流程的可见入口上暴露 generated content 状态载荷，确保玩家或测试流程能直接看到 generated node/battle 的关键信息。

## 可见字段
- generated_content_enabled
- node_id
- battle_slot_id
- enemy_deck_id
- card_pool_count
- reward_plan_id
- narrative_key_count
- route_gate_count
- player_input_ready/action_executed
- fallback_policy

## 边界
- fallback_policy=legacy
- 非 generated node 仍 legacy
- 不覆盖 CardData，不写 story_battles，不写 final combat_result
- narrative 仅 key/hook，route_gate 仅 candidate

## 验收命令
```bash
godot --headless --path . --script tools/content_engine/generated_player_visible_entry_probe.gd
python3 tools/content_engine/generated_player_visible_entry_validator.py
python3 tools/content_engine/content_engine_check.py
python3 tools/content_engine/content_engine_acceptance_runner.py
python3 tools/content_engine/content_engine_acceptance_validator.py
python3 -m py_compile \
  tools/content_engine/generated_player_visible_entry_validator.py \
  tools/content_engine/content_engine_check.py \
  tools/content_engine/content_engine_acceptance_runner.py \
  tools/content_engine/content_engine_acceptance_validator.py
git diff --check
```
