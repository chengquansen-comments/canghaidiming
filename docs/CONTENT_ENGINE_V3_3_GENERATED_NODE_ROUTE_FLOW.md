# Content Engine v3.3：Generated Node Route Flow 实装

## 目标
将 16 个 generated preview battle_slot 的 battle_flow_payload 接入节点/叙事上下文候选流程，形成可消费的 `generated_node_candidate`。

## 实现
- 新增 `scripts/generated_node_route_flow_adapter.gd`：
  - `build_generated_node_candidate`
  - `build_generated_node_candidate_pool`
  - `get_generated_node_candidate`
  - `is_generated_node_available`
  - `get_legacy_node_fallback`
- 在 `scripts/battle_controller_visual_narrative_context_loadout.gd` 挂入：
  - `generated_node_candidate`
  - `generated_node_candidate_pool_count`

## 约束
- narrative 仅 key/hook，不生成正文。
- route_gate 仅候选，`route_gate_writes_formal_flow=false`。
- 不写 story_battles / battle_state / combat_result。
- fallback_policy 始终 legacy。

## 验收
```bash
godot --headless --path . --script tools/content_engine/generated_node_route_flow_probe.gd
python3 tools/content_engine/generated_node_route_flow_validator.py
python3 tools/content_engine/content_engine_check.py
python3 tools/content_engine/content_engine_acceptance_runner.py
python3 tools/content_engine/content_engine_acceptance_validator.py
```
