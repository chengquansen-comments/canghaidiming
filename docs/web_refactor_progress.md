# Web 化重构进度

本文档是 Web 化当前状态入口。旧版长看板已收敛为状态摘要；具体 UI 分层规则见 [UI_PIPELINE.md](UI_PIPELINE.md)。

## 当前阶段

Milestone D：结构收口 + Web 验证。

当前结论：

- Web 基础导出、打包、校验、manifest、checksum、smoke test 和 GitHub Pages 部署链路已经具备。
- Web 剧情入口当前应进入正式剧情 MVP 控制器；旧 safe / 压缩叙事只作为历史兼容代码保留。
- Visual 分层已形成 `Stage / HUD / Skin / Actor / Cached Controller`。
- cached visual controller 已从“承载大量显示细节”收敛为更接近绑定层，但仍需最终职责检查。
- 下一阶段重点不是继续堆 helper，而是做 Godot 编译、Web 导出、浏览器运行和战斗交互验收。

## 已完成

| 方向 | 状态 |
|---|---|
| Compatibility renderer | 已完成 |
| Web export preset（单线程） | 已完成 |
| Web shell + 本地预览链路 | 已完成 |
| Web bundle 构建 / 校验 / manifest / checksum / smoke test | 已完成 |
| GitHub Pages workflow | 已完成 |
| Web CJK 字体方案 | 已完成 |
| BattleStageHelper | 已完成 |
| BattleHudHelper | 已完成 |
| BattleSkinHelper | 已完成 |
| BattleActorRenderHelper | 已完成 |
| cached visual controller 接入 helper | 已完成 |

## Web 部署口径

### 入口链路

```text
scenes/Main.tscn
→ scripts/main_runtime_router.gd
→ scenes/MainWeb.tscn
→ scripts/web_runtime_launcher.gd
```

Web launcher 支持两个 query flag：

| Flag | 作用 |
|---|---|
| `narrative_mvp` | 自动进入剧情 MVP。Web 端经 `scenes/NarrativeDemoWeb.tscn` 进入正式剧情控制器。 |
| `smoke_battle` | 自动进入 `scenes/MainVisual.tscn`，用于 Web smoke / 战斗入口验证。 |

Web 剧情场景保留 `NarrativeDemoWeb.tscn` 是为了写 Web ready 标记；正式剧情逻辑应与桌面端保持同一条控制器链，不再走 `narrative_demo_safe_controller.gd` 的硬编码占位文本。

### 本地构建

字体子集是 Web 中文显示的前置步骤。正式构建前若新增剧情、按钮、战斗文案或遇到浏览器中文字乱码 / 方框，应先重新生成并校验 runtime CJK 字体：

```bash
python3 tools/subset_cjk_font.py
python3 tools/validate_cjk_font.py assets/fonts/cjk_font_runtime.ttf
```

正式打包：

```bash
./tools/build_web_bundle.sh
```

输出：

| 路径 | 用途 |
|---|---|
| `build/web/` | 可部署的静态站点目录。 |
| `build/web.zip` | 同内容压缩包。 |
| `build/web/manifest.json` | bundle 文件清单。 |
| `build/web/checksums.txt` | bundle 校验和。 |

若本地 Headless Chrome 的 Godot Web DOM 快照不稳定，可跳过浏览器 smoke，仅保留 bundle / manifest / checksum 校验：

```bash
CANGHAI_WEB_SMOKE_BROWSER=0 ./tools/build_web_bundle.sh
```

### Web 字体

Web 端默认主题引用：

```text
themes/default_ui_theme.tres
→ assets/fonts/cjk_font_runtime.ttf
```

字体文件来源：

| 文件 / 脚本 | 作用 |
|---|---|
| `assets/fonts/cjk_font.ttf` | 本地完整 CJK 源字体，不直接作为 Web runtime 首选。 |
| `tools/subset_cjk_font.py` | 从 `scripts/`、`scenes/`、`data/`、`tables/`、`themes/` 收集文本，生成 `assets/fonts/cjk_font_runtime.ttf`。 |
| `tools/validate_cjk_font.py` | 校验 runtime 字体容器和关键中文 glyph 覆盖。 |
| `tools/install_local_cjk_font.py` | 本地缺少 `assets/fonts/cjk_font.ttf` 时，从系统候选字体复制一个真实 `.ttf` 源字体。 |
| `tools/export_web_build.sh` | 导出前会校验 CJK 字体；仅当 runtime 字体缺失时自动生成子集。 |

乱码处理顺序：

1. 确认不要把 `.ttc` 字体集合改名成 `.ttf`；Web 构建需要真实 `.ttf` / `.otf`，如 `NotoSansSC-Regular.ttf`、`SourceHanSansSC-Regular.otf`。
2. 若缺少源字体，先运行 `python3 tools/install_local_cjk_font.py`，或手动放置真实中文 `.ttf` 到 `assets/fonts/cjk_font.ttf`。
3. 只要新增了中文文本或浏览器里出现乱码 / 方框，就运行 `python3 tools/subset_cjk_font.py`。
4. 运行 `python3 tools/validate_cjk_font.py assets/fonts/cjk_font_runtime.ttf`，确认 glyph 覆盖通过。
5. 重新执行 `./tools/build_web_bundle.sh` 或 `./tools/build_and_serve_web.sh`，不要复用旧 `build/web`。

### 本地预览

构建并启动本地预览：

```bash
./tools/build_and_serve_web.sh
```

默认地址：

```text
http://127.0.0.1:8060
```

指定端口和 host：

```bash
./tools/build_and_serve_web.sh build/web 8070 127.0.0.1
```

已有 `build/web` 时，只启动静态服务器：

```bash
python3 tools/run_web_preview.py --dir build/web --host 127.0.0.1 --port 8060
```

端口占用排查：

```bash
lsof -nP -iTCP:8060 -sTCP:LISTEN
```

若确认是旧预览进程，可按查到的 PID 结束：

```bash
kill <PID>
```

### 体积预算

当前默认预算：

| 项 | 默认预算 | 环境变量 |
|---|---:|---|
| 总包 | `300 MB` | `CANGHAI_WEB_TOTAL_BUDGET_MB` |
| PCK | `240 MB` | `CANGHAI_WEB_PCK_BUDGET_MB` |
| WASM | `60 MB` | `CANGHAI_WEB_WASM_BUDGET_MB` |

当前本地包基线约 `141 MB`，其中 `index.pck` 约 `105 MB`、`index.wasm` 约 `36 MB`。预算检查命令：

```bash
python3 tools/check_web_bundle_budget.py build/web
```

### CI / GitHub Pages

部署 workflow：

```text
.github/workflows/build-web-bundle.yml
```

触发条件：

- 手动 `workflow_dispatch`。
- push 到 `main` 且改动命中 Godot 项目、场景、脚本、素材、工具、Web shell 或 workflow。

CI 会运行 `tools/build_web_bundle.sh`，上传 `build/web`、`build/web.zip`、manifest、checksum，并通过 GitHub Pages 发布 `build/web`。CI 当前关闭浏览器 smoke 和部分 Godot 战斗 helper smoke，以降低 GitHub runner 上的环境噪声；本地需要完整验证时可打开对应环境变量。

## 当前待办

优先级从高到低：

1. 运行 Godot 编译 / headless 验证，修 warning-as-error、signature mismatch 和入口加载错误。
2. 确认 `MainVisual` 可进入，战斗主流程可点击、可出牌、可预览。
3. 执行 Web export 和本地浏览器预览。
4. 验证中文字体、角色显示、脚底锚点、range overlay 是否稳定。
5. 做 cached visual controller 最终职责检查，只保留 input collection、diff、pool、apply。

## 验收清单

### Godot

- [ ] Godot Editor 编译无 warning-as-error。
- [ ] `MainVisual` 正常进入。
- [ ] 字符入口仍可进入。
- [ ] 视觉入口角色完整显示，脚底不被裁剪。
- [ ] 战斗主流程可点击、可出牌、可预览。

### Web

- [ ] Web export 成功。
- [ ] 浏览器运行无 Console error。
- [ ] 中文字体正常显示。
- [ ] 角色完整显示，显示边界与脚底锚点基本匹配。
- [ ] Range overlay 无明显节点创建抖动。

## 已知问题基线

| 项目 | 状态 | 当前判断 |
|---|---|---|
| Headless Chrome `SharedImageManager::ProduceMemory` warning | 非阻塞 | 来自 headless Chrome GPU / shared image 路径；当前不影响 bundle、shell 启动或基础 smoke |
| `Chrome --dump-dom` 不稳定观察 Godot Web 异步标记 | 待确认 | 更像 headless DOM 快照方式限制；本地若超时可设 `CANGHAI_WEB_SMOKE_BROWSER=0`；完整战斗级回归应改用 Playwright / Selenium 或 Godot Web 内部 deterministic smoke |

当前阻塞项：暂无。若真实浏览器出现黑屏、canvas 不渲染或 WebGL context lost，再把 GPU warning 升级为阻塞排查项。

## 常用命令

```bash
godot --headless --import --quit
godot --headless --quit res://scenes/MainVisual.tscn
godot --headless --path . --quit res://scenes/NarrativeDemoWeb.tscn
./tools/build_web_bundle.sh
./tools/build_and_serve_web.sh
python3 tools/run_web_preview.py --dir build/web --host 127.0.0.1 --port 8060
```

如果本地没有 Godot CLI，至少保留代码审查和 TSV 编译验证结果，并在提交说明中明确“未跑 Godot / Web”。

## 文档维护规则

- Web 状态只更新本文档，不再维护根目录进度副本。
- 已完成项只保留结论，不追加流水账。
- 新阻塞项直接加入“当前待办”或 [web_build_known_issues.md](web_build_known_issues.md)。
- 涉及 UI 分层或职责边界的长期规则，应同步到 [UI_PIPELINE.md](UI_PIPELINE.md)。
