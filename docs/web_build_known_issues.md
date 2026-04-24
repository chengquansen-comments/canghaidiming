# Web 构建已知问题基线

本文档记录 Web 构建、浏览器启动、headless smoke 过程中已经确认过的 warning / error。

更新时间：

- 2026-04-24

## 判定规则

- `阻塞`：会导致 Web 构建失败、页面无法启动、无法进入主界面或战斗入口。
- `非阻塞`：当前可复现，但不影响 bundle 生成、壳页启动或基础 smoke 通过。
- `待确认`：已出现日志，但还没有足够信息判断是否影响玩家。

## 当前基线

### 1. Headless Chrome GPU shared image warning

状态：

- `非阻塞`

现象：

```text
SharedImageManager::ProduceMemory: Trying to Produce a Memory representation from a non-existent mailbox.
```

出现位置：

- `tools/smoke_test_web_bundle.py` 调用本机 Chrome / Chromium headless smoke 时

当前判断：

- 该 warning 来自 headless Chrome 的 GPU / shared image 路径。
- 当前不影响 `index.html` 加载。
- 当前不影响 Web shell 自动启动标记。
- 当前不影响 `./tools/build_web_bundle.sh` 成功结束。

处理策略：

- 暂不作为 CI 阻塞项。
- 若后续真实浏览器或玩家环境出现黑屏、canvas 不渲染、WebGL context lost，再重新评估。

## 当前阻塞项

暂无。

## 待确认项

### 1. `Chrome --dump-dom` 不能稳定观察 Godot Web 异步启动后的 DOM 标记

状态：

- `待确认`

现象：

- Web shell 会带 `autostart=1&smoke_battle=1` 启动。
- Godot 侧已加入 `MainWeb -> MainVisual -> 默认演武` 的自动入口。
- 但 `Chrome --dump-dom` 不稳定保留 Godot Web 运行后写回的 `data-web-smoke-battle` 标记。

当前判断：

- 更像是当前 headless DOM 快照方式的能力边界，而不是游戏入口本身失败。
- 目前 smoke test 因此采用降级策略：能观察到 `battle-ready` 就校验；观察不到则至少确认壳页启动链路被触发。

后续建议：

- 若要把 smoke 升级到完整战斗级回归，需要引入 Playwright / Selenium 等可等待浏览器驱动。
- 另一条路径是在 Godot Web 内部增加 deterministic smoke 回合，并用更稳定的 JS bridge / postMessage / endpoint 暴露结果。
