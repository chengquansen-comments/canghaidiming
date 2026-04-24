# Web 化重构进度看板

本文档根据 `/Users/happy/Downloads/Web化重构.pdf` 的拆解目标，记录当前根目录 Godot 项目的 Web 化推进状态。

更新时间：

- 2026-04-24

评估范围：

- `project.godot`
- `export_presets.cfg`
- `scenes/*`
- `scripts/*`
- `tools/*`
- `web/*`
- `web_shell.html`
- `.github/workflows/build-web-bundle.yml`
- `build/web/*`

说明：

- 这是一份“当前实际落地状态”文档，不是目标方案复述。
- 完成度按三个等级记录：`已完成`、`部分完成`、`未开始 / 基本未开始`。
- 本文档关注 Web 化链路，不重复展开玩法细节和平衡性内容。

## 1. 当前总体判断

当前 Web 化可以判断为：

- 已经完成第一轮工程骨架搭建。
- 已经具备导出、打包、校验、上传 artifact 的基础设施。
- Web bundle pipeline 当前能完整跑通。
- 但还没有形成完整战斗级、可持续性能级的 Web 基线。

最主要的原因有三点：

1. 浏览器运行级 smoke test 已能触发视觉战斗入口链路，但还不是完整打一回合的回归。
2. 结构重构和性能收敛仍未真正收口。
3. 正式 Web runtime 仍然复用当前视觉入口，而不是完全独立收口后的运行时。

## 2. 已完成

以下项目已经基本落地，可以视为当前阶段的已完成项。

### 2.1 Web 可用渲染器

- `project.godot` 已切到 `Compatibility`
- 满足 Godot 4 Web 导出的基础要求

对应文件：

- [project.godot](/Users/happy/Documents/Codex/2026-04-19-files-mentioned-by-the-user-pdf/project.godot:1)

### 2.2 Web 导出预设

- 已存在正式 `Web` export preset
- 已配置 `single-threaded`
- 导出路径固定为 `build/web/index.html`
- 已接入自定义 `web_shell.html`
- 已排除 `build/**`、`dist/**`，避免旧构建产物回灌进 `.pck`

对应文件：

- [export_presets.cfg](/Users/happy/Documents/Codex/2026-04-19-files-mentioned-by-the-user-pdf/export_presets.cfg:1)

### 2.3 本地 Web 运行方式

- 已提供本地静态服务器脚本
- 已为 `.wasm` 和 `.pck` 设置 MIME 类型
- 已关闭缓存，便于本地调试

对应文件：

- [tools/run_web_preview.py](/Users/happy/Documents/Codex/2026-04-19-files-mentioned-by-the-user-pdf/tools/run_web_preview.py:1)

### 2.4 最小 Web 壳页

- 已有加载页
- 已有进度条
- 已有开始加载按钮
- 已有重新加载按钮
- 已有失败提示
- 已支持 `autostart=1` smoke 参数

对应文件：

- [web_shell.html](/Users/happy/Documents/Codex/2026-04-19-files-mentioned-by-the-user-pdf/web_shell.html:1)
- [web/web_shell.html](/Users/happy/Documents/Codex/2026-04-19-files-mentioned-by-the-user-pdf/web/web_shell.html:1)

### 2.5 Web bundle 工具链

以下工具已存在并能串成完整链路：

- 导出
- 基础 bundle 校验
- 体积报告
- budget 检查
- manifest 生成
- checksum 生成
- zip 打包
- smoke test

对应文件：

- [tools/build_web_bundle.sh](/Users/happy/Documents/Codex/2026-04-19-files-mentioned-by-the-user-pdf/tools/build_web_bundle.sh:1)
- [tools/export_web_build.sh](/Users/happy/Documents/Codex/2026-04-19-files-mentioned-by-the-user-pdf/tools/export_web_build.sh:1)
- [tools/validate_web_bundle.py](/Users/happy/Documents/Codex/2026-04-19-files-mentioned-by-the-user-pdf/tools/validate_web_bundle.py:1)
- [tools/report_web_bundle.py](/Users/happy/Documents/Codex/2026-04-19-files-mentioned-by-the-user-pdf/tools/report_web_bundle.py:1)
- [tools/check_web_bundle_budget.py](/Users/happy/Documents/Codex/2026-04-19-files-mentioned-by-the-user-pdf/tools/check_web_bundle_budget.py:1)
- [tools/write_web_bundle_manifest.py](/Users/happy/Documents/Codex/2026-04-19-files-mentioned-by-the-user-pdf/tools/write_web_bundle_manifest.py:1)
- [tools/write_web_bundle_checksums.py](/Users/happy/Documents/Codex/2026-04-19-files-mentioned-by-the-user-pdf/tools/write_web_bundle_checksums.py:1)
- [tools/package_web_bundle.py](/Users/happy/Documents/Codex/2026-04-19-files-mentioned-by-the-user-pdf/tools/package_web_bundle.py:1)
- [tools/smoke_test_web_bundle.py](/Users/happy/Documents/Codex/2026-04-19-files-mentioned-by-the-user-pdf/tools/smoke_test_web_bundle.py:1)

### 2.6 CI 构建工作流

- 已有 GitHub Actions workflow
- 已能在推送时触发 bundle 构建
- 已上传构建目录、zip 和 metadata

对应文件：

- [.github/workflows/build-web-bundle.yml](/Users/happy/Documents/Codex/2026-04-19-files-mentioned-by-the-user-pdf/.github/workflows/build-web-bundle.yml:1)

### 2.7 正式 Web 入口分流

当前设计为：

```text
Main.tscn -> main_runtime_router.gd -> MainDesktop / MainWeb
```

已具备：

- 桌面入口 `MainDesktop.tscn`
- Web 入口 `MainWeb.tscn`
- runtime router
- router 使用延迟切场景，已避免 `_ready()` 直接切场景造成的 busy 报错

对应文件：

- [scripts/main_runtime_router.gd](/Users/happy/Documents/Codex/2026-04-19-files-mentioned-by-the-user-pdf/scripts/main_runtime_router.gd:1)
- [scenes/Main.tscn](/Users/happy/Documents/Codex/2026-04-19-files-mentioned-by-the-user-pdf/scenes/Main.tscn:1)
- [scenes/MainDesktop.tscn](/Users/happy/Documents/Codex/2026-04-19-files-mentioned-by-the-user-pdf/scenes/MainDesktop.tscn:1)
- [scenes/MainWeb.tscn](/Users/happy/Documents/Codex/2026-04-19-files-mentioned-by-the-user-pdf/scenes/MainWeb.tscn:1)

### 2.8 构建产物隔离

- `export_presets.cfg` 已排除 `build/**` 和 `dist/**`
- `tools/export_web_build.sh` 会在导出前清理目标输出目录
- 最新导出日志中已不再出现 `res://build/web/...` 被保存进 `.pck`

对应文件：

- [export_presets.cfg](/Users/happy/Documents/Codex/2026-04-19-files-mentioned-by-the-user-pdf/export_presets.cfg:11)
- [tools/export_web_build.sh](/Users/happy/Documents/Codex/2026-04-19-files-mentioned-by-the-user-pdf/tools/export_web_build.sh:1)

## 3. 部分完成

以下项已经有方向和实现痕迹，但还不能视为完成。

### 3.1 正式 Web 启动壳

`MainWeb.tscn` 和 `web_runtime_launcher.gd` 已存在，但当前行为更接近：

- 先进入一个 Web 启动说明页
- 再跳到 `MainVisual.tscn`

当前补充能力：

- 支持 `smoke_battle=1`，可自动进入视觉战斗入口
- `MainVisual` 在该参数下会自动以枪手开局并进入演武

这说明：

- Web 启动壳已成型
- 但“正式 Web 独立入口”还没有完全从现有视觉入口收口出来

对应文件：

- [scripts/web_runtime_launcher.gd](/Users/happy/Documents/Codex/2026-04-19-files-mentioned-by-the-user-pdf/scripts/web_runtime_launcher.gd:1)
- [scripts/web_runtime_flags.gd](/Users/happy/Documents/Codex/2026-04-19-files-mentioned-by-the-user-pdf/scripts/web_runtime_flags.gd:1)
- [scripts/battle_controller_visual_ui.gd](/Users/happy/Documents/Codex/2026-04-19-files-mentioned-by-the-user-pdf/scripts/battle_controller_visual_ui.gd:1)

### 3.2 烟雾测试

现有 smoke test 现在分为两层：

- manifest 是否存在
- checksums 是否存在
- 文件 hash 是否匹配
- zip 是否被纳入 checksums
- 起本地静态 server
- 拉取 `index.html`
- 校验 Web shell 标题、开始加载按钮、canvas、关键 script 资源
- 若系统存在 Chrome / Chromium，则额外执行 headless browser smoke
- browser smoke 会带 `smoke_battle=1` 自动触发 `MainWeb -> MainVisual -> 默认开局演武`
- bundle 构建前会额外执行 `tools/smoke_battle_hud_helper.gd`，覆盖确认后招式详情保留、HUD helper 强类型渲染和缓存清理路径
- bundle 构建前会额外执行 `tools/smoke_battle_round_core.gd`，在 headless Godot 内跑一轮纯战斗结算，覆盖高武境先手、格挡吸收伤害、耗势和回合推进
- Web 导出已排除 `tools/**`，避免本地构建 / smoke 脚本被打进 `.pck`

当前限制：

- `Chrome --dump-dom` 不稳定保留 Godot Web 异步启动后的 DOM 标记
- 因此当前 browser smoke 能确认壳页启动与自动入口链路被触发
- 若 DOM 快照保留了 battle 标记，则会额外确认已进入视觉战斗入口
- 仍然不是“完整打一回合”的战斗回归测试

对应文件：

- [tools/smoke_test_web_bundle.py](/Users/happy/Documents/Codex/2026-04-19-files-mentioned-by-the-user-pdf/tools/smoke_test_web_bundle.py:1)

### 3.3 包体预算体系

当前默认预算：

- total: `64 MB`
- wasm: `40 MB`
- pck: `16 MB`

最新 bundle 检查：

- `index.wasm`: `35.9 MB`
- `index.pck`: `4.1 MB`
- total: `40.45 MB`

当前结论：

- 总体积在预算内
- wasm 在预算内
- pck 在预算内
- 当前 `build_web_bundle.sh` 已能完整跑通

### 3.4 资源缓存

视觉层已经有一些缓存基础：

- `BattleSkinHelper`
- `BattleStageHelper`
- `BattleHudHelper`

已有缓存内容包括：

- texture
- atlas
- style
- grid geometry
- HUD 文本摘要
- FX 节点池

这是 Web 化性能收敛的一个好开始，但还不是 PDF 里独立 `battle_asset_cache.gd` 的完成形态。

对应文件：

- [scripts/visual/battle_skin.gd](/Users/happy/Documents/Codex/2026-04-19-files-mentioned-by-the-user-pdf/scripts/visual/battle_skin.gd:1)
- [scripts/visual/battle_stage_view.gd](/Users/happy/Documents/Codex/2026-04-19-files-mentioned-by-the-user-pdf/scripts/visual/battle_stage_view.gd:1)
- [scripts/visual/battle_hud_view.gd](/Users/happy/Documents/Codex/2026-04-19-files-mentioned-by-the-user-pdf/scripts/visual/battle_hud_view.gd:1)
- [scripts/visual/battle_fx_pool.gd](/Users/happy/Documents/Codex/2026-04-19-files-mentioned-by-the-user-pdf/scripts/visual/battle_fx_pool.gd:1)

### 3.5 视觉层解耦

视觉逻辑已经比之前更清晰，`battle_controller_visual_ui.gd` 作为统一视觉入口的方向是对的。

但目前仍存在：

- `_process()` 仍承担 HUD / stage / actor / intent 的兜底刷新，但已从逐帧刷新降为节流刷新
- 舞台格子 / 攻击范围已增加状态签名，状态未变化时不会重复重画
- 角色站位 / 朝向已增加状态签名，状态未变化时不会重复写位置和翻转
- HUD 数值和意图气泡已增加状态签名，状态未变化时不会重复写控件
- 手牌区已增加状态签名，手牌内容和可用状态未变化时不会重复重建按钮
- 节点操作按钮区已增加状态签名，会话 / 战斗状态未变化时不会重复重建按钮
- 主要打击 FX 已改为节点池复用
- 攻击范围梯形已改为固定节点复用
- 视觉版弹窗动作按钮已改为按钮池复用，打开不同弹窗时只替换文本和回调
- 视觉版普通按钮样式已改为一次性套用，并避免覆盖招式牌自己的卡牌样式
- 视觉 ownership 还没有完全从 core 里收完

因此：

- 方向正确
- 但离可持续结构还有距离

对应文件：

- [scripts/battle_controller_visual_ui.gd](/Users/happy/Documents/Codex/2026-04-19-files-mentioned-by-the-user-pdf/scripts/battle_controller_visual_ui.gd:1)

## 4. 未开始 / 基本未开始

以下项在当前代码中还看不到明确落地结果，或只能看到零散前置条件。

### 4.1 统一 preview service

当前没有：

- `battle_preview_service.gd`

文本版预览仍然手写在：

- `battle_controller_text_ui.gd::_simulate_preview()`

而 `battle_controller_core.gd` 中对应接口仍是空壳。

这说明：

- 预览与真实结算尚未完全同源
- PDF 中 Epic 3 / Issue 10 仍未完成

对应文件：

- [scripts/battle_controller_text_ui.gd](/Users/happy/Documents/Codex/2026-04-19-files-mentioned-by-the-user-pdf/scripts/battle_controller_text_ui.gd:1)
- [scripts/battle_controller_core.gd](/Users/happy/Documents/Codex/2026-04-19-files-mentioned-by-the-user-pdf/scripts/battle_controller_core.gd:1)

### 4.2 core 拆薄

当前文件规模仍然很大：

- `battle_controller_core.gd`
- `battle_controller_demo_visual.gd`
- `battle_controller_visual_ui.gd`

说明：

- 结构重构已开始
- 但 `core` 仍然承担大量流程与 UI scaffold 责任

### 4.3 更完整的 FX 池化

当前已有：

- `battle_fx_pool.gd`
- 主要打击 FX 使用池化节点
- 攻击范围梯形 `Polygon2D` / `Line2D` 使用固定池复用

但视觉层仍有其他动态节点：

- 视觉版弹窗动作按钮已完成池化复用
- 节点操作按钮区已完成缓存收敛
- 普通按钮样式已完成一次性套用，避免高频重复设置 theme override
- 部分更深层的弹窗内容 / 临时提示仍由当前控制器即时创建

因此性能收敛已经开始，但还不是完整池化。

### 4.4 事件驱动刷新

当前视觉版仍使用 `_process()` 兜底刷新关键 UI。

这意味着：

- 非必要状态下仍会定期刷新舞台
- 当前已经完成节流、舞台格子状态签名、角色站位状态签名、HUD / 意图气泡状态签名、手牌区状态签名、节点按钮签名，但还不是完整事件驱动
- 还没有完全进入“只在状态变化时刷新”的 Web 稳定模式

### 4.5 Web 控制台错误基线文档

已新增基础文档：

- `web_build_known_issues.md`

当前状态：

- 已记录本机 headless Chrome GPU warning
- 已区分阻塞 / 非阻塞 / 待确认项
- 仍需要在真实浏览器调试时继续补充 console warning / error

对应文件：

- [docs/web_build_known_issues.md](/Users/happy/Documents/Codex/2026-04-19-files-mentioned-by-the-user-pdf/docs/web_build_known_issues.md:1)

### 4.6 音频解锁 / 全屏入口

当前 Web 壳页里未看到：

- 首次交互后音频解锁逻辑
- 全屏按钮入口

因此 Epic 5 / Issue 17 尚未开始。

### 4.7 异步博弈版隔离策略

当前没有看到：

- Web 正式分支与异步玩法分支的清晰隔离落地

因此 PDF 中最后一批“避免边导 Web 边大改规则”的策略尚未沉淀。

## 5. 里程碑判断

基于 PDF 中的 Milestone 划分，当前可以这样判断。

### 5.1 Milestone A：第一份可运行 Web 构建

状态：

- `已完成`

理由：

- 已有导出预设、Web 壳页、本地 server、bundle 产物
- runtime router 已稳定
- build + validate + package + smoke 已能完整跑通

### 5.2 Milestone B：稳定 Web 基线

状态：

- `部分完成`

理由：

- budget 检查已能通过
- bundle pipeline 已回到绿灯
- 构建产物已从 `.pck` 打包资源中隔离
- 控制台错误基线文档已建立，但还需要真实浏览器调试继续补充
- 浏览器回归仍不是完整战斗级 smoke

### 5.3 Milestone C：结构进入可持续状态

状态：

- `未完成`

理由：

- preview service 未落地
- core 拆薄未完成
- visual ownership 未完全收口

### 5.4 Milestone D：性能与体验达标

状态：

- `未完成`

理由：

- 资源缓存仅完成一部分
- FX 池化和高频按钮重建收敛已开始，但还不完整
- 事件驱动刷新未完成
- 音频 / 全屏体验未接入

### 5.5 Milestone E：正式内容打磨

状态：

- `暂不建议评估`

理由：

- 前置 Web 基线尚未稳定
- 当前不宜过早把重心转到正式内容接入

## 6. 本次验证记录

### 6.1 Headless 启动

本地执行：

```bash
godot --headless --path . --quit-after 1
```

观察到：

- 引擎可启动
- 当前未复现 router busy 报错

### 6.2 Web bundle 构建

本地执行：

```bash
./tools/build_web_bundle.sh
```

观察到：

- 导出通过
- bundle 校验通过
- budget 检查通过
- manifest / checksum / zip 生成通过
- smoke test 通过
- 最新导出日志不再包含 `res://build/web/...` 被保存进 `.pck`
- 最新导出日志不再包含 `res://tools/...` 被保存进 `.pck`

## 7. 下一批优先事项

建议下一轮优先只做下面三件事。

### 7.1 推进性能收敛第二步

目标：

- 继续减少 Web 端常驻刷新和高频创建销毁

最小验证范围建议：

1. 将剩余弹窗内容和提示控件继续推进为更少重建
2. 继续减少视觉版 `_process()` 兜底刷新范围
3. 为后续更严格预算打基础

### 7.2 补完整战斗级 smoke

目标：

- 从“自动触发进入战斗”推进到“至少打一回合”

建议方向：

- 接入 Playwright / Selenium 这类可等待的浏览器驱动
- 或在 Godot Web 内部提供可被 query flag 驱动的 deterministic smoke 回合

### 7.3 继续补充浏览器错误基线

目标：

- 让 `web_build_known_issues.md` 从 headless 基线扩展到真实浏览器基线

建议方向：

- 用 Chrome / Edge / Firefox 各跑一次本地预览
- 记录 console warning / error
- 将阻塞项转为修复任务，非阻塞项保留为基线

## 8. 文档维护规则

后续更新这份文档时建议保持：

- 每次 review 后只改状态，不重写结构。
- 对每个“部分完成”项，优先补“卡在哪里”。
- 若某项完成，补上对应文件链接。
- 若发现新的阻塞项，优先加到“下一批优先事项”。
