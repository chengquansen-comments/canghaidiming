# Content Engine v1.7 full preview Godot readonly probe

## 阶段目标
在不接入正式 runtime 的前提下，使用 Godot headless 只读加载 full preview package，验证 7 个 domain 可读取。

## 新增工具
- `tools/content_engine/full_preview_readonly_probe.py`
- `tools/content_engine/full_preview_readonly_probe.gd`
- `tools/content_engine/full_preview_readonly_validator.py`

## 报告输出
- `data/design/generated_full_preview_readonly_probe_report.tsv`
- `data/design/generated_full_preview_godot_readonly_report.tsv`

## 校验要点
- 7 个 domain 路径可读取，数量符合：45/16/39/72/10/28/9。
- 全部 `runtime_ready=false`。
- 全部 `preview_only=true`。
- `selected_reward_policy=legacy`。
- `content_engine_enabled=false`。
- 不写正式 runtime，不触发正式战斗流程，不改变 gameplay state。

## 运行命令
```bash
python3 tools/content_engine/full_preview_readonly_probe.py
godot --headless --path . --script tools/content_engine/full_preview_readonly_probe.gd
python3 tools/content_engine/full_preview_readonly_validator.py
```
