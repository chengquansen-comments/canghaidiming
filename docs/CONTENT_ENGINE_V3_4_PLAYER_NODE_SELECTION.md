# Content Engine v3.4：玩家可见 Generated Node 选择

## 阶段目标
在正式流程上下文中挂入可见且可选的 generated node 池，让玩家入口可消费 generated node，并能拿到对应 battle flow payload。

## 核心实现
- 新增 `scripts/generated_player_node_selection_adapter.gd`：
  - `build_player_visible_generated_node_pool`
  - `get_player_visible_generated_nodes`
  - `select_generated_node`
  - `get_battle_flow_payload_for_node`
  - `get_legacy_node_selection_fallback`
- 在 `battle_controller_visual_narrative_context_loadout.gd` 挂入：
  - `generated_player_node_pool`
  - `generated_player_node_pool_count`
  - `generated_player_node_selection_enabled`
  - `selected_generated_node_payload`

## 玩家可见约束
- 16 个 generated preview battle_slot 全部进入可见节点池。
- 每个节点 `player_visible=true`、`selectable=true`。
- 选择节点后返回 `battle_flow_payload`。
- 非 generated preview slot 不进入生成池并保持 legacy。

## 安全边界
- fallback_policy=legacy。
- narrative 仅 key/hook，不生成正文。
- route_gate 仅 candidate，不改变正式分流。
- 不写 CardData / story_battles / battle_state / combat_result。

## 验收命令
```bash
godot --headless --path . --script tools/content_engine/generated_player_node_selection_probe.gd
python3 tools/content_engine/generated_player_node_selection_validator.py
python3 tools/content_engine/content_engine_check.py
python3 tools/content_engine/content_engine_acceptance_runner.py
python3 tools/content_engine/content_engine_acceptance_validator.py
```
