# Content Engine v2.5：prologue_01 Generated Map / Route Domain

## 阶段定位
- 在 v2.3（reward）和 v2.4（battle domain）基础上，补齐 `battle_slot`、`operation_node`、`narrative`、`route_gate` 四个 domain 的白名单候选接入。
- 仅对白名单 `prologue_01` 生效，非白名单保持 legacy。

## 实现范围
- 新增 `GeneratedMapRouteDomainAdapter`，只读读取 whitelist bridge + preview 包。
- 在 narrative battle context loadout 构造层最小挂载 `generated_map_route_domain_candidate`。
- 不改正式地图流程，不改正式路线分流，不改剧情正文渲染。

## 安全约束
- fallback_policy 固定 `legacy`。
- narrative 仅 `key/hook`，不生成正文文本。
- route_gate 仅 candidate 判断，`writes_formal_flow=false`。
- 不修改 `combat_resolver`、`battle_state_machine`、`card_data`、`story_battles`、`scenes`。

## 验收命令
- `godot --headless --path . --script tools/content_engine/generated_map_route_domain_formal_probe.gd`
- `python3 tools/content_engine/generated_map_route_domain_formal_validator.py`
- `python3 tools/content_engine/content_engine_check.py`
- `python3 tools/content_engine/content_engine_acceptance_runner.py`
- `python3 tools/content_engine/content_engine_acceptance_validator.py`

## 当前结论
- `prologue_01` 的 map/route 四域已可只读候选接入。
- 非白名单仍 legacy。
- 正式战斗核心与结算语义未改变。
