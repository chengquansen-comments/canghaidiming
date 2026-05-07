# 《大明之沧海嘀鸣》Godot 4 单局 Demo

这是一个 Godot 4 可运行原型，当前主链路分为剧情 MVP、视觉战斗与 Web 导出验证。主入口会按平台路由到桌面或 Web launcher。

## 快速入口

```text
project.godot
→ scenes/Main.tscn
→ scripts/main_runtime_router.gd
→ scenes/MainDesktop.tscn / scenes/MainWeb.tscn
```

常用运行命令：

```bash
godot --path .
```

常用校验命令：

```bash
python3 scripts/compile_tables.py
godot --headless --import --quit
godot --headless --quit res://scenes/MainVisual.tscn
godot --headless --quit res://scenes/NarrativeDemo.tscn
```

Web 构建 / 预览入口：

```bash
python3 tools/subset_cjk_font.py
python3 tools/validate_cjk_font.py assets/fonts/cjk_font_runtime.ttf
./tools/build_web_bundle.sh
./tools/build_and_serve_web.sh
python3 tools/run_web_preview.py --dir build/web --host 127.0.0.1 --port 8060
```

Web 部署、字体子集、预算、端口和 GitHub Pages 口径见 [docs/web_refactor_progress.md](docs/web_refactor_progress.md)。

## Content Engine Regression（v0.8h / v0.8i）

当前稳定回归入口：

```bash
python3 tools/content_engine/content_engine_regression_runner.py
python3 tools/content_engine/content_engine_regression_validator.py
```

回归报告输出：

- `data/design/generated_content_engine_regression_report.tsv`
- `data/design/generated_content_engine_regression_report.md`

v0.8i 仅新增 CI / workflow draft，不接入正式 loader，不替换正式 card/reward 数据源。详见：

- `docs/CONTENT_ENGINE_V0_8I.md`
- `docs/CONTENT_ENGINE_CI.md`
- `docs/CONTENT_ENGINE_ROADMAP.md`

## 当前主链路

| 方向 | 当前入口 | 说明 |
|---|---|---|
| 总入口 | `scenes/Main.tscn` | 平台路由 |
| 桌面端 | `scenes/MainDesktop.tscn` | 进入剧情 MVP 或视觉战斗 |
| Web 端 | `scenes/MainWeb.tscn` | 支持 `narrative_mvp` / `smoke_battle` query flag |
| 剧情 MVP | `scenes/NarrativeDemo.tscn` | 序章、武举、海疆节点推进 |
| 视觉战斗 | `scenes/MainVisual.tscn` | 剧情战斗与战斗测试列表 |

旧 `scripts/Main*.gd` 字符战斗链路仍保留为早期原型，当前默认启动流不再挂载。

## 文档入口

首读 [docs/README.md](docs/README.md)。当前只维护少数活跃总文档：

| 文档 | 用途 |
|---|---|
| [docs/NARRATIVE.md](docs/NARRATIVE.md) | 叙事运行源、节点流程、变量、战斗触发 |
| [docs/BATTLE.md](docs/BATTLE.md) | 战斗配置、结算模式、位移、表演节奏、验证命令 |
| [docs/UI_PIPELINE.md](docs/UI_PIPELINE.md) | UI / 视觉战斗 / Web UI 管线 |
| [docs/ART_PIPELINE.md](docs/ART_PIPELINE.md) | 美术目录、源图到运行素材、验收 |
| [docs/ENGINEERING.md](docs/ENGINEERING.md) | 代码组织、重构优先级、AI 协作、Godot 排障 |
| [docs/web_refactor_progress.md](docs/web_refactor_progress.md) | Web 化当前状态 |

旧执行清单、早期设计案和长篇脚本文档只作为历史参考；若与上述总文档或运行代码冲突，以总文档和代码为准。

## 数据源规则

不要直接编辑 `data/*.json`。运行 JSON 由 TSV 和编译脚本生成：

```text
tables/*.tsv
data/story_battles/*.tsv
→ scripts/compile_tables.py
→ data/*.json
```

关键运行源：

| 运行源 | 用途 |
|---|---|
| `data/narrative_mvp_nodes.json` | 剧情 MVP 当前运行节点 |
| `data/story_battles.json` | 正式剧情战斗 encounter、数值、卡组、结算模式 |
| `data/battle_scene_manifest.json` | 战斗背景、标签、镜头参数 |
| `data/performance_tracks.json` | 剧情演出参数 |
| `data/enemy_manifest.json` | 旧剧情战斗 / AI / debug 兼容层 |

短期口径：

- 剧情推进以 `tables/narrative_mvp_nodes.tsv` 和 `tables/narrative_mvp_node_status.tsv` 为准。
- 正式剧情战斗以 `data/story_battles/*.tsv` 为准。
- `enemy_manifest` 不再是正式剧情战斗主源。
- `data/narrative/*.json` 中的大型叙事文档只作为文档/布局源，不参与当前默认推进逻辑。

## 项目结构

| 路径 | 说明 |
|---|---|
| `scenes/` | Godot 运行场景 |
| `scripts/` | GDScript 运行逻辑 |
| `tables/` | 策划源表 |
| `data/` | 编译产物 / 运行数据 |
| `assets/` | 游戏运行素材 |
| `art_reference/` | 图源、参考图、正式母版 |
| `docs/` | 当前文档与历史附录 |
| `tools/` | 编译、校验、导出、smoke test |
| `reports/` | 校验和分析报告 |
| `archive/` | 旧表、旧方案、迁移前备份 |

## 代码维护底线

- 单个 `.gd` 脚本建议控制在 25KB 以下；超过 20KB 先评估拆分。
- Controller 只做调度，不长期承载 UI、状态推进、数据生成和 debug 入口等多重职责。
- 新功能优先进入小型专职文件：`runtime`、`view`、`generator`、`formatter`、`bridge`、`debug_entry`。
- 大文件不做远端整文件替换；优先新增 helper、shim 或小 scene 引用，再逐个函数迁移。
