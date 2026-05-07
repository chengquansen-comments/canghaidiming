# Content Engine v0.8i

## 1) v0.8i 定位

v0.8i 是 CI / workflow draft 阶段。  
目标是把 v0.8h 已稳定的 regression 入口整理为可在本地和未来 CI 重复执行的流程草案。

## 2) 本阶段不做的事

- 不做正式 loader integration
- 不替换 card/reward 正式数据源
- 不修改战斗主流程/结算逻辑
- 不新增 runtime 功能

## 3) 当前稳定入口

```bash
python3 tools/content_engine/content_engine_regression_runner.py
python3 tools/content_engine/content_engine_regression_validator.py
```

以上命令是 v0.8i 的核心执行入口，也是 workflow draft 的核心命令。

## 4) runtime 边界（延续 v0.8h）

- `data/runtime/content_engine/` 正式文件仍限定为：
  - `card_pool.json`
  - `battle_reward.json`
  - `runtime_manifest.json`
- 不接入 loader，不把 runtime 文件接到主流程读取链路。

## 5) v0.9 前瞻

v0.9 才考虑“受控接入正式 runtime 数据源”，并继续保持：

- manifest-first
- fail-closed
- 先验证后接入
