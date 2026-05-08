# Content Engine v3.6：Generated Node Battle Start 路径接入

## 阶段目标
将 v3.5 的 `generated_battle_entry_payload` 接入 battle context 初始化链路，形成可初始化战斗上下文的 `generated_battle_start_payload`。

## 核心实现
- 新增 `scripts/generated_node_battle_start_adapter.gd`：
  - `build_battle_start_payload_from_generated_node`
  - `build_battle_start_payload_from_entry`
  - `validate_battle_start_payload`
  - `get_legacy_battle_start_fallback`
- 在 `battle_controller_visual_narrative_context_loadout.gd` 增加：
  - `generated_battle_start_payload`
  - `generated_battle_start_available`
  - `generated_battle_start_source`

## 边界
- 支持 16 个 generated node。
- 仅初始化 battle context payload，不直接写 final combat_result。
- fallback_policy=legacy。
- narrative 仅 key/hook，route_gate 仅 candidate。
- 不改 combat_resolver / battle_state_machine / card_data / story_battles / scenes。

## 验收命令
```bash
godot --headless --path . --script tools/content_engine/generated_node_battle_start_probe.gd
python3 tools/content_engine/generated_node_battle_start_validator.py
python3 tools/content_engine/content_engine_check.py
python3 tools/content_engine/content_engine_acceptance_runner.py
python3 tools/content_engine/content_engine_acceptance_validator.py
```
