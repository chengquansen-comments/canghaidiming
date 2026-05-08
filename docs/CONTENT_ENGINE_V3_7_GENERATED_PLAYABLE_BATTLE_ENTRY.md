# Content Engine v3.7：Player-Facing Generated Playable Battle Entry

## 阶段目标
把玩家可见 generated node 与现有 battle controller 上下文串联，形成可运行的 playable battle entry：
- 选择 generated node 后可得到 playable entry。
- battle context 携带 generated enemy_deck/card_pool/reward/narrative/route 信息。
- 缺失时回落 legacy。

## 新增
- `scripts/generated_playable_battle_entry_adapter.gd`
- `tools/content_engine/generated_playable_battle_entry_probe.gd`
- `tools/content_engine/generated_playable_battle_entry_validator.py`
- `data/design/generated_playable_battle_entry_report.tsv`

## 上下文字段挂接
在 `battle_controller_visual_narrative_context_loadout.gd` 增加：
- `generated_playable_battle_entry`
- `generated_battle_context`
- `generated_enemy_deck_id`
- `generated_card_pool_count`
- `generated_reward_plan_id`
- `generated_narrative_keys`
- `generated_route_gates`

## 安全边界
- fallback_policy=legacy。
- narrative 仅 key/hook。
- route_gate 仅 candidate，不改正式分流。
- 不写 CardData / story_battles / final combat_result。
- 不改 combat_resolver / battle_state_machine / scenes。

## 验收命令
```bash
godot --headless --path . --script tools/content_engine/generated_playable_battle_entry_probe.gd
python3 tools/content_engine/generated_playable_battle_entry_validator.py
python3 tools/content_engine/content_engine_check.py
python3 tools/content_engine/content_engine_acceptance_runner.py
python3 tools/content_engine/content_engine_acceptance_validator.py
```
