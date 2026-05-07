# Runtime 导出回滚报告

## 已写入 Runtime 文件

- data/runtime/content_engine/battle_reward.json
- data/runtime/content_engine/card_pool.json

## 回滚步骤

删除以下文件即可回滚本次 runtime 内容写入：

- data/runtime/content_engine/battle_reward.json
- data/runtime/content_engine/card_pool.json

`runtime_manifest.json` 处理建议：
- 若要严格回滚到 v0.8b 写入前状态，建议一并删除 `data/runtime/content_engine/runtime_manifest.json`。
- 若仅保留审计记录，可保留 manifest；但其会描述已删除文件，并在 validator 中失败。

## 重跑命令

回滚后可按顺序重新执行：

1. no-write: `python3 tools/content_engine/runtime_exporter.py`
2. no-write validator: `python3 tools/content_engine/runtime_exporter_validator.py`
3. guarded-write: `python3 tools/content_engine/runtime_exporter.py --write-runtime --confirm-runtime-export`
4. guarded-write validator: `python3 tools/content_engine/runtime_exporter_validator.py --allow-runtime-files`
5. manifest: `python3 tools/content_engine/runtime_export_manifest.py`
6. manifest validator: `python3 tools/content_engine/runtime_export_manifest_validator.py`

## 范围边界

当前回滚流程仅涉及 runtime 内容文件，不涉及 Godot loader（当前尚未接入 loader）。
