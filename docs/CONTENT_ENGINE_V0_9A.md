# Content Engine v0.9a

## 1) v0.9a 定位

v0.9a 是 read-only integration gate。  
本阶段新增的是独立 gate scaffold 与 probe/validator，不是正式 runtime loader integration。

## 2) 默认行为（必须 disabled）

`data/runtime/content_engine/runtime_loader_config.json` 默认值：

- `content_engine_runtime_enabled=false`
- `read_only_probe_enabled=false`
- `integration_mode=disabled`
- `fallback_mode=existing_data_source`

当 `content_engine_runtime_enabled=false` 时：

- 不加载 runtime bundle
- 不向主流程返回 runtime domains
- 不修改任何全局状态
- 返回 `gate_status=disabled`

## 3) 边界与约束

- 不替换正式 card/reward 数据源
- 不接入战斗主流程
- 不修改 `card_data.gd` / `battle_state_machine.gd` / `combat_resolver.gd`
- gate 仅做只读配置与目录/manifest 检查，异常时 fail-closed

## 4) 为什么先做 gate

先做 gate 的目的是先锁定“默认关闭 + fail-closed + 可验证边界”，再讨论 domain 级别接入。  
这可以避免直接接 `card_data` / `battle_reward` 时出现不可控回归。

## 5) 验证入口

```bash
python3 tools/content_engine/runtime_integration_gate_probe.py
python3 tools/content_engine/runtime_integration_gate_validator.py
```

生成报告：

- `data/design/generated_runtime_integration_gate_report.tsv`
- `data/design/generated_runtime_integration_gate_report.md`

## 6) 后续计划

- v0.9b 才考虑 `battle_reward` 单 domain 的 read-only compare。
- RID/ObjectDB/resource leak warning 仍作为独立 Godot hygiene issue，不并入 v0.9a gate 结论。
