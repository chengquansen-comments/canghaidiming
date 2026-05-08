# v4.3 Generated Battle Minimal Playable Loop

## 目标
在 v4.2 可见入口基础上，确认玩家进入 generated battle 后能够看到并维持 generated 上下文，并在一次最小行动/输入后仍保持 generated 链路，同时可见 reward pending 状态。

## 可见与可玩要点
- Generated Content: ON
- selected_generated_node_id / battle_slot_id
- enemy_deck_id + enemy summary
- card_pool_count=72
- reward_plan_id + reward_pending_available=true
- narrative_key_count=28
- route_gate_count=9
- player_input_ready 或 action_executed
- generated_context_preserved_after_action=true

## 约束
- fallback_policy=legacy
- 不写 CardData / story_battles / final combat_result
- 不修改 combat_resolver / battle_state_machine / card_data

## 验收命令
```bash
python3 tools/content_engine/content_engine_check.py
python3 tools/content_engine/content_engine_acceptance_runner.py
python3 tools/content_engine/content_engine_acceptance_validator.py
python3 tools/content_engine/generated_playable_battle_loop_validator.py
git diff --check

godot --headless --path . --script tools/content_engine/generated_playable_battle_loop_probe.gd
```
