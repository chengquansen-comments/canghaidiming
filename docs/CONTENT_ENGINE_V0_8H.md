# Content Engine v0.8h

## 1) v0.8h 定位

v0.8h 是 CI-friendly regression runner。
它不是正式 loader integration，不替换 card/reward 数据源。

## 2) 作用

将 v0.7b → v0.8g 的长链路验收收束为统一入口：

- 一键执行全部关键脚本与验证器
- 记录 step 级别 exit/status/duration/stdout_tail/stderr_tail
- 汇总 runtime safety / manifest / loader / fixture / Godot warning

## 3) no-write 安全语义（v0.8h）

当前 no-write 语义是：

- preview 不改变已有正式 runtime 文件 sha256
- preview 不新增额外 runtime 文件
- preview 不修改 manifest

不是“runtime 目录必须不存在”。

## 4) 本地运行方式

```bash
python3 tools/content_engine/content_engine_regression_runner.py
python3 tools/content_engine/content_engine_regression_validator.py
```

## 5) 如何看报告

- TSV: step 级别明细，适合 CI 机器解析
- MD: 人类可读总结（phase 摘要、失败步骤、安全与风险摘要）

## 6) 后续规划

- v0.8i 可考虑 GitHub Actions / CI wiring
- v0.9 才考虑受控接入正式 runtime 数据源
