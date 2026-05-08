# Content Engine v2.9：Generated Map Route Runtime Flow

## 目标
- 让白名单 11 个 slot 的 `battle_slot / operation_node / narrative key/hook / route_gate` 进入 runtime flow candidate。
- 仅提供可消费候选结构，不改正式分流，不生成正文。

## 关键约束
- 非白名单保持 legacy。
- fallback_policy 固定 `legacy`。
- narrative 仅 key/hook/tag，不含正文长文本。
- route_gate 仅候选，`writes_formal_flow=false`。

## 产物
- `data/design/generated_map_route_runtime_flow_report.tsv`

## 验收命令
- `godot --headless --path . --script tools/content_engine/generated_map_route_runtime_flow_probe.gd`
- `python3 tools/content_engine/generated_map_route_runtime_flow_validator.py`
- `python3 tools/content_engine/content_engine_check.py`
- `python3 tools/content_engine/content_engine_acceptance_runner.py`
- `python3 tools/content_engine/content_engine_acceptance_validator.py`
