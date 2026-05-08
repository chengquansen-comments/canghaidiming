# Content Engine v2.2 Godot runtime bridge spine

## 目标
将 v2.1 产出的 `prologue_01` full content bridge bundle 接入 Godot 侧，提供 7 domain 的统一只读 provider。

## 新增内容
- `scripts/generated_content_runtime_bridge.gd`：只读 bridge provider。
- `tools/content_engine/generated_content_runtime_bridge_probe.gd`：Godot headless probe。
- `tools/content_engine/generated_content_runtime_bridge_validator.py`：离线校验。
- `data/design/generated_content_runtime_bridge_probe_report.tsv`：probe 报告。

## 边界
- 不启用正式 generated content。
- 不写 game state。
- 不调用正式战斗流程。
- 不修改 scene / battle core。
