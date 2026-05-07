# Content Engine v0.8b

## 1) v0.8b 定位

v0.8b 是 guarded write mode。
本阶段在严格保护下允许 runtime content 文件写入，但保持默认 no-write。

## 2) 安全默认与双参数门禁

默认运行：

```bash
python3 tools/content_engine/runtime_exporter.py
```

必须保持 no-write：

- 不创建 `data/runtime/content_engine/`
- 不写 runtime 文件

真实写入必须同时提供双参数：

```bash
python3 tools/content_engine/runtime_exporter.py --write-runtime --confirm-runtime-export
```

仅提供 `--write-runtime` 而缺少 `--confirm-runtime-export` 时必须拒绝写入，并在结果中标记 `missing_confirm_runtime_export`。

## 3) 写入边界

v0.8b 只写 runtime content files，不接入 Godot runtime loader，不修改任何 Godot 运行时逻辑。

允许写入白名单仅限：

- `data/runtime/content_engine/card_pool.json`
- `data/runtime/content_engine/battle_reward.json`

禁止写入：

- `scripts/`
- `scenes/`
- `data/story_battles/`
- 其他非白名单 runtime 路径

## 4) 写入候选与校验条件

写入候选来源：

- `data/design/generated_runtime_exporter_plan.tsv`

仅允许写入满足以下条件的记录：

- allowed candidate
- `export_action == planned_create`
- `diff_status == new_runtime_file_planned`
- `risk_level` 为 `low` 或 `medium`
- `blocked_reason` 为空
- `planned_runtime_path` 位于 `data/runtime/content_engine/` 且文件名在白名单内
- `schema_fingerprint` 非空
- `content_fingerprint` 非空
- `planned_record_count >= 0`
- `planned_field_count >= 0`

## 5) 安全写入流程

每个文件写入采用 guarded safe write：

1. 写 `.tmp` 临时文件
2. 校验 JSON 可解析
3. 再次校验目标路径仍在 `data/runtime/content_engine/` 下
4. 使用原子替换写入正式文件

## 6) 输出与格式

本阶段输出：

- `data/design/generated_runtime_exporter_plan.tsv`
- `data/design/generated_runtime_exporter_plan.md`
- `data/design/generated_runtime_exporter_write_result.tsv`
- `data/design/generated_runtime_exporter_write_result.md`

runtime JSON 采用 scaffold 内容格式，包含：

- `runtime_domain`
- `artifact_id`
- `export_version`
- `source_design_path`
- `schema_fingerprint`
- `content_fingerprint`
- `record_count`
- `field_count`
- `records`
- `generated_by`
- `generated_at`

在 v0.8b 中允许 `records=[]`；不伪造真实业务数据。

## 7) 验证模式

no-write validator：

```bash
python3 tools/content_engine/runtime_exporter_validator.py
```

guarded-write validator：

```bash
python3 tools/content_engine/runtime_exporter_validator.py --allow-runtime-files
```

## 8) 回滚

回滚 v0.8b runtime 写入：删除下列本次生成文件即可：

- `data/runtime/content_engine/card_pool.json`
- `data/runtime/content_engine/battle_reward.json`

## 9) Godot warning 说明

`godot --headless` 仍可能出现 RID/ObjectDB leak warning。
该 warning 归类为独立 Godot hygiene issue，不作为 content engine exporter v0.8b 阻塞项。
