# Content Engine v0.8g

## 1) v0.8g 定位

v0.8g 是 negative-case / fixture tests。
目标是验证 read-only loader 在异常 runtime content 场景下严格 fail-closed，不是接入正式 loader。

## 2) fixture 隔离边界

- fixture 目录固定在 `data/design/runtime_loader_negative_fixtures/`
- 不写入 `data/runtime/content_engine/`
- 不修改正式 `runtime_manifest.json` / `card_pool.json` / `battle_reward.json`

## 3) 为什么必须覆盖这些异常

必须覆盖 checksum、fingerprint、unknown file、unsafe path、malformed JSON、domain/count mismatch 等场景，
因为这些是 runtime bundle 最常见且最高风险的数据污染入口。

## 4) fail-closed 验证目标

- `valid_control` 必须通过
- 所有 negative fixtures 必须失败
- negative fixtures 返回 domain 数必须为 0
- 不允许 fallback 到未校验 runtime JSON

## 5) 后续规划

- v0.8h 可考虑 editor-only probe scene 或 CI-friendly loader regression
- v0.9 才考虑受控接入正式 runtime 数据源

## 6) Godot hygiene 说明

RID/ObjectDB warning 仍作为独立 Godot hygiene issue，不作为 v0.8g 阻塞项。
