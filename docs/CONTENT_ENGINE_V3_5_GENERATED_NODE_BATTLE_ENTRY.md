# Content Engine v3.5：Generated Node Battle Entry 接入

## 阶段目标
将玩家选择的 generated node 接入现有 battle context 入口，生成可进入战斗准备链路的 `generated_battle_entry_payload`。

## 核心实现
- 新增 `scripts/generated_node_battle_entry_adapter.gd`：
  - `build_battle_entry_from_generated_node`
  - `build_battle_entry_from_battle_slot`
  - `get_selected_generated_node_battle_entry`
  - `validate_generated_battle_entry`
  - `get_legacy_battle_entry_fallback`
- 在 `battle_controller_visual_narrative_context_loadout.gd` 挂入：
  - `selected_generated_node_id`
  - `generated_battle_entry_payload`
  - `generated_battle_entry_available`

## 约束
- 支持 16 个 generated node。
- 缺失内容时 fallback legacy。
- 不调用 combat_resolver。
- 不写 story_battles / battle_state / combat_result。
- narrative 仅 key/hook，route_gate 仅 candidate。

## 验收命令
```bash
godot --headless --path . --script tools/content_engine/generated_node_battle_entry_probe.gd
python3 tools/content_engine/generated_node_battle_entry_validator.py
python3 tools/content_engine/content_engine_check.py
python3 tools/content_engine/content_engine_acceptance_runner.py
python3 tools/content_engine/content_engine_acceptance_validator.py
```
