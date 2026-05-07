# Content Engine Regression CI Draft

## 1) 目标

本文件定义 v0.8i 的本地/CI 回归执行口径。  
v0.8i 是 workflow draft，不要求立即启用正式 GitHub Actions。

## 2) 本地运行

在仓库根目录执行：

```bash
python3 tools/content_engine/content_engine_regression_runner.py
python3 tools/content_engine/content_engine_regression_validator.py
```

报告输出：

- `data/design/generated_content_engine_regression_report.tsv`
- `data/design/generated_content_engine_regression_report.md`

## 3) CI 依赖

- Python 3.11+（建议与现有 workflow 保持一致）
- `git`（runner 内会执行 `git diff --check`）
- `godot`（headless，可选但推荐）

## 4) Godot headless 要求

`content_engine_regression_runner.py` 包含两条 Godot 命令：

- `godot --headless --path . --quit`
- `godot --headless --path . --quit scenes/MainVisual.tscn`

如果 CI 环境暂未安装 Godot，建议采用 draft 分层策略：

- `required_python_regression`：必须执行（core regression + validator）
- `optional_godot_headless_check`：仅在可用时执行

注意：当前 runner 本身已包含 Godot 步骤；因此“无 Godot 环境”更适合先保留为 draft，或在未来把 Godot 步骤拆分为可配置开关后再强制启用 required job。

## 5) Blocking / Warning 口径

阻塞（必须失败即中止）：

- `content_engine_regression_runner.py` 非 0 退出
- `content_engine_regression_validator.py` 非 0 退出
- regression report 中 `Failed required steps > 0`
- runtime formal 文件集合不等于 3 个正式文件
- manifest validator / Godot probe validator / negative fixture validator 任何一个失败

当前不阻塞（warning）：

- `warning_detected=true`（例如 RID/ObjectDB/resource leak warning）

`warning_detected=true` 表示 Godot 日志出现 hygiene 类 warning。  
在 Godot 进程退出码为 0 且 required steps 全通过时，该 warning 仅记录，不阻塞 content engine regression。

## 6) 如何查看报告

优先查看：

- `data/design/generated_content_engine_regression_report.md`

重点字段：

- `Overall`
- `Failed required steps`
- `Runtime Safety Summary`
- `Manifest/Checksum Summary`
- `Loader/Probe Summary`
- `Negative Fixture Summary`
- `Godot Warning Summary`（`warning_detected`）

机器解析或逐 step 追查请看：

- `data/design/generated_content_engine_regression_report.tsv`

## 7) Workflow Draft 路径

- `.github/workflows/content-engine-regression.yml.draft`

该文件后缀为 `.draft`，默认不会作为正式 GitHub Actions workflow 自动生效。  
启用前请先确认 CI 环境 Godot 安装策略与 optional job 策略。
