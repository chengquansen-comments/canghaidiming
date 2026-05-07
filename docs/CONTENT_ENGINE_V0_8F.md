# Content Engine v0.8f

## 1) v0.8f 定位

v0.8f 是 Godot loader probe / headless-only test harness。
本阶段不是正式 loader integration，不替换 card/reward 正式数据源。

## 2) 本阶段做什么

- 在 Godot headless 环境中实际调用 `scripts/content_engine_runtime_loader.gd`
- 验证 `load_manifest()` / `validate_manifest()` / `load_runtime_bundle()` 行为
- 验证读取结果仅来自已校验 runtime bundle

## 3) 为什么 probe 只输出 stdout

probe GDScript 不写任何文件，避免污染 runtime 与 project 资源。
由 Python 捕获 stdout marker JSON，再生成 design-layer 报告（TSV/MD），保持“Godot 只读、设计层可审计”。

## 4) 阶段边界

- 不接入主流程
- 不替换正式数据源
- 不修改战斗逻辑
- 不修改 scenes / story_battles

## 5) 后续规划

- v0.8g 可考虑 editor-only probe scene 或 fixture tests
- v0.9 才考虑受控接入正式 runtime 数据源

## 6) Godot hygiene 说明

RID/ObjectDB/resource leak warning 仍作为独立 Godot hygiene issue，不作为 v0.8f 阻塞项。
