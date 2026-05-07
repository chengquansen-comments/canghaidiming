# Runtime Export Rollback Report

## Runtime Files Written

- data/runtime/content_engine/battle_reward.json
- data/runtime/content_engine/card_pool.json

## Rollback Steps

删除以下文件即可回滚本次 runtime content 写入：

- data/runtime/content_engine/battle_reward.json
- data/runtime/content_engine/card_pool.json

`runtime_manifest.json` 是否必要：
- 对于严格回滚到 v0.8b 写入前状态，建议一并删除 `data/runtime/content_engine/runtime_manifest.json`。
- 如果只想保留审计记录，可保留 manifest，但它将描述已删除文件并在 validator 中失败。

## Re-run Commands

回滚后可按顺序重新执行：

1. no-write: `python3 tools/content_engine/runtime_exporter.py`
2. no-write validator: `python3 tools/content_engine/runtime_exporter_validator.py`
3. guarded-write: `python3 tools/content_engine/runtime_exporter.py --write-runtime --confirm-runtime-export`
4. guarded-write validator: `python3 tools/content_engine/runtime_exporter_validator.py --allow-runtime-files`
5. manifest: `python3 tools/content_engine/runtime_export_manifest.py`
6. manifest validator: `python3 tools/content_engine/runtime_export_manifest_validator.py`

## Scope Boundary

当前 rollback 流程只涉及 runtime content files，不涉及 Godot loader（当前尚未接入 loader）。
