# Content Engine v0.8c

## 1) v0.8c 定位

v0.8c 聚焦 runtime manifest / checksum / rollback report。
本阶段只做 runtime content 文件治理，不接入 Godot loader，不修改任何 Godot 运行时逻辑。

## 2) v0.8c 产物

- `data/runtime/content_engine/runtime_manifest.json`
- `data/design/generated_runtime_export_manifest_report.tsv`
- `data/design/generated_runtime_export_manifest_report.md`
- `data/design/generated_runtime_export_rollback_report.md`

## 3) runtime_manifest.json 的作用

`runtime_manifest.json` 作为 runtime content 写入后的审计登记表，记录：

- manifest 元信息（版本、生成器、生成时间、来源 write result）
- runtime 根路径和允许文件白名单
- 每个 runtime 文件的治理信息（size、sha256、fingerprint、record/field 计数、来源设计表）

## 4) checksum 的作用

manifest 中的 `sha256` 和 `file_size_bytes` 用于后续安全校验：

- 检测 runtime JSON 是否被意外修改
- 在后续 loader preflight/read-only loader 阶段做只读一致性验证
- 为回滚与重放提供可追溯基线

## 5) rollback report 使用方式

`generated_runtime_export_rollback_report.md` 提供：

- 本次 runtime 写入文件列表
- 删除哪些文件可以回滚
- `runtime_manifest.json` 是否建议同步删除
- 回滚后重跑 no-write / guarded-write / manifest validator 的命令顺序

当前 rollback 仅涉及 runtime content files，不涉及 Godot loader（当前尚未接入 loader）。

## 6) 阶段边界

- v0.8c 不是 Godot loader 接入阶段。
- v0.8d 或 v0.9 才考虑 loader preflight / read-only loader。
- RID/ObjectDB/resource leak warning 仍作为独立 Godot hygiene issue，不作为 content exporter 阻塞项。
