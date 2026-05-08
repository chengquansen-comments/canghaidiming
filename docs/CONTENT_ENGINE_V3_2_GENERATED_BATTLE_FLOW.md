# Content Engine v3.2：Generated Battle Slot Flow 实装

## 阶段目标
把 16 个 generated preview battle_slot 从“白名单可用”推进到“可被当前 battle context 消费的 battle flow payload”。

## 核心实现
- 新增 `generated_battle_flow_adapter.gd`，统一组装 battle flow payload。
- 在 `battle_controller_visual_narrative_context_loadout.gd` 挂入 `generated_battle_flow_payload`。
- 保持非 generated preview slot 走 legacy fallback。

## payload 字段
- `battle_slot_id`
- `battle_slot_source`
- `enemy_deck_id`
- `enemy_deck_source`
- `card_pool_count`
- `reward_plan_id`
- `reward_source`
- `operation_node_count`
- `narrative_key_count`
- `route_gate_count`
- `fallback_policy`
- `flow_source`

## 安全边界
- 不调用 `combat_resolver`。
- 不写 `battle_state` / `combat_result`。
- 不写 `CardData`。
- 不写 `story_battles`。
- narrative 仅 key/hook，route_gate 仅候选。

## 验收
```bash
godot --headless --path . --script tools/content_engine/generated_battle_flow_probe.gd
python3 tools/content_engine/generated_battle_flow_validator.py
python3 tools/content_engine/content_engine_check.py
python3 tools/content_engine/content_engine_acceptance_runner.py
python3 tools/content_engine/content_engine_acceptance_validator.py
```
