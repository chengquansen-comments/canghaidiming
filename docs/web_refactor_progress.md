# Web 化重构进度

本文档是 Web 化当前状态入口。旧版长看板已收敛为状态摘要；具体 UI 分层规则见 [UI_PIPELINE.md](UI_PIPELINE.md)。

## 当前阶段

Milestone D：结构收口 + Web 验证。

当前结论：

- Web 基础导出、打包、校验、manifest、checksum、smoke test 链路已经具备。
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
| Web CJK 字体方案 | 已完成 |
| BattleStageHelper | 已完成 |
| BattleHudHelper | 已完成 |
| BattleSkinHelper | 已完成 |
| BattleActorRenderHelper | 已完成 |
| cached visual controller 接入 helper | 已完成 |

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
| `Chrome --dump-dom` 不稳定观察 Godot Web 异步标记 | 待确认 | 更像 headless DOM 快照方式限制；完整战斗级回归应改用 Playwright / Selenium 或 Godot Web 内部 deterministic smoke |

当前阻塞项：暂无。若真实浏览器出现黑屏、canvas 不渲染或 WebGL context lost，再把 GPU warning 升级为阻塞排查项。

## 常用命令

```bash
godot --headless --import --quit
godot --headless --quit res://scenes/MainVisual.tscn
./tools/build_web_bundle.sh
python3 tools/run_web_preview.py
```

如果本地没有 Godot CLI，至少保留代码审查和 TSV 编译验证结果，并在提交说明中明确“未跑 Godot / Web”。

## 文档维护规则

- Web 状态只更新本文档，不再维护根目录进度副本。
- 已完成项只保留结论，不追加流水账。
- 新阻塞项直接加入“当前待办”或 [web_build_known_issues.md](web_build_known_issues.md)。
- 涉及 UI 分层或职责边界的长期规则，应同步到 [UI_PIPELINE.md](UI_PIPELINE.md)。
