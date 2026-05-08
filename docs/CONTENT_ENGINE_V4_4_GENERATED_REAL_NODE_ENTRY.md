# v4.4 Generated Battle Real Node Entry

## 目标
通过现有玩家可触发入口（推荐接敌入口）进入 generated battle，而不是只依赖旁路 probe/validator。

## 验收要点
- real_node_entry_exists / real_node_entry_invoked / reached_battle_from_real_entry
- selected_generated_node_id / battle_slot_id 绑定
- generated enemy/card/reward 可见
- player_input_ready 或 action_executed
- generated_context_preserved_after_action
- legacy_only_path=false

## 边界
- fallback_policy=legacy
- 不写 CardData / story_battles / final combat_result
- 不修改 combat_resolver / battle_state_machine / card_data

## 验收命令
```bash
python3 tools/content_engine/content_engine_check.py
python3 tools/content_engine/content_engine_acceptance_runner.py
python3 tools/content_engine/content_engine_acceptance_validator.py
python3 tools/content_engine/generated_real_node_entry_validator.py
git diff --check

godot --headless --path . --script tools/content_engine/generated_real_node_entry_probe.gd
```
