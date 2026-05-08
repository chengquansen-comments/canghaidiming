# Content Engine v2.1 full content runtime bridge contract + whitelist bundle

## 阶段目标
基于 v2.0 readiness audit，定义 7 个 domain 的 runtime adapter contract，并输出 `prologue_01` 白名单 bridge bundle 与 manifest。

## 本次边界
- 仅生成 contract/binding/bridge 产物。
- 不实现 Godot adapter。
- 不启用正式 generated content。
- 不修改 story/scenes/battle core。

## 主要产物
- `data/design/generated_full_content_adapter_contract.tsv`
- `data/design/generated_full_content_whitelist_binding_map.tsv`
- `data/runtime/content_engine_whitelist/prologue_01.full_content_bridge.json`
- `data/runtime/content_engine_whitelist/full_content_bridge_manifest.json`

## 核心约束
- `global_content_engine_enabled=false`
- `formal_runtime_enabled=false`
- `rollback_policy=legacy`
- `runtime_ready=false`
- `bridge_only=true`
- `write_to_game_state_allowed=false`（7 domain 全部）
