# Content Engine v0.9d

## 1）阶段定位

v0.9d 的目标是 **battle_reward read-only Godot compare/probe**：  
在 Godot headless 环境里，实际读取已经 hydration 完成的 `battle_reward` runtime 内容，并与 Python 侧 compare/legacy source 做只读对比。

本阶段不是正式奖励逻辑接入，不替换现有奖励数据源，不修改战斗主流程。

## 2）为什么必须在 Godot headless 里验证

在 v0.9c 中，`battle_reward` 已从空 scaffold 水合为 45 条真实记录，但这仍然只是 Python 侧的数据完整性结论。  
v0.9d 需要补上“引擎读取路径”的证据，确认 Godot 侧在 manifest-first、只读边界下可稳定读取同一份 runtime 数据。

采用 headless-only probe 可以把验证限制在命令行环境，避免场景接入、副作用写入与主流程耦合风险。

## 3）本阶段实现边界

- probe 命令固定为：`godot --headless --path . --script tools/content_engine/content_engine_battle_reward_probe.gd`
- probe 只允许处理 `battle_reward` 单域，`card_pool` 保持 out_of_scope
- probe 必须先读 `runtime_manifest.json`，再按 manifest entry 读取 `battle_reward.json`
- probe 只读，不允许任何 runtime/scene/resource 写入 API
- 输出 marker JSON，供 Python 报告脚本解析

## 4）为什么 `runtime_loader_config` 仍保持 disabled

`runtime_loader_config.json` 继续保持：

- `content_engine_runtime_enabled=false`
- `read_only_probe_enabled=false`
- `integration_mode=disabled`

原因是 v0.9d 仅验证“可读取且可对比”，不做“可接入”。  
若提前改成 enabled，会把验证问题升级成集成行为变化，违反本阶段“只读 compare-only”边界。

## 5）为什么 `integration_status` 仍是 compare_only

v0.9d 的交付物是 Godot compare/probe 报告，不是运行时接入开关。  
因此 `integration_status` 保持 `godot_compare_only`，其含义是：

- 已完成 Godot 侧只读读取与对比
- 尚未把 loader/gate 接到现有战斗脚本
- 尚未替换正式奖励来源

## 6）后续节奏

- v0.9e：再评估 `battle_reward` gated read-only integration probe（仍受 gate 控制，仍不替换正式源）
- v1.0：才评估正式替换奖励数据源与受控接入主流程

## 7）Godot warning 口径

RID/ObjectDB/resource leak warning 继续作为独立 Godot hygiene issue 跟踪。  
在 Godot headless 命令退出码为 0 的前提下，该 warning 仍是 non-blocking，不并入 v0.9d compare/probe 成败判定。
