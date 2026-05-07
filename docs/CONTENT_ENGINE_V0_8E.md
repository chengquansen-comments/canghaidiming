# Content Engine v0.8e

## 1) v0.8e 定位

v0.8e 是 read-only Godot loader scaffold。
本阶段只提供独立只读 loader 骨架，不接入正式战斗流程，不替换现有 card/reward 正式数据源。

## 2) 为什么必须 manifest-first

loader 读取顺序必须先 manifest：

1. 读取 `runtime_manifest.json`
2. 校验文件白名单、路径和 fingerprint/checksum
3. 再按 manifest 文件条目读取 runtime JSON

这样可以避免绕过治理层的 direct runtime file read。

## 3) 为什么必须 fail-closed

任一校验失败时必须 fail-closed：

- 返回 `ok=false`
- 返回明确 errors
- 不返回未校验 runtime data
- 不改全局状态

这是为了避免把不可信 runtime 内容带入正式流程。

## 4) 本阶段边界

- 仅新增 `scripts/content_engine_runtime_loader.gd` 作为独立工具脚本。
- 不接入 MainVisual、battle scene、`card_data.gd`、`battle_state_machine.gd`、`combat_resolver.gd`。
- 不替换现有正式数据源。
- `integration_status` 必须保持 `not_integrated`。

## 5) 后续规划

- v0.8f 才考虑 loader probe scene 或 editor-only test harness。
- v0.9 才考虑受控接入正式 runtime 数据源。

## 6) Godot hygiene 说明

RID/ObjectDB/resource leak warning 仍作为独立 Godot hygiene issue，不作为 v0.8e 阻塞项。
