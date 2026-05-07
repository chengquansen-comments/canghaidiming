# Battle Reward Runtime Test 离线计划（v1.0d-prep）

## 1. 阶段定位

本阶段只做 runtime_test 设计与离线 harness。
本阶段不是 runtime_enabled，不接 Godot 正式流程，不替换正式奖励源。

## 2. runtime_test 与 runtime_enabled 的区别

`runtime_test`：离线读取 runtime reward，做候选对齐、比较与报告。
`runtime_enabled`：正式流程选择 runtime reward 并实际生效。
本阶段仅允许前者。

## 3. 为什么只做离线 harness

先验证 runtime 数据可读、可对齐、可回退，避免直接进入正式战斗流程带来行为漂移风险。
离线 harness 可在不改业务代码的前提下提供可审计结果。

## 4. harness 如何模拟 runtime_test

`tools/content_engine/battle_reward_runtime_test_harness.py`：

1. 读取 runtime battle_reward、manifest、loader_config 与 legacy 报告。
2. 在脚本内部构造 `runtime_test_harness_mode=true`。
3. 对 45 条记录模拟候选选择：harness 视角可选 runtime_candidate；正式视角固定 legacy。
4. 输出 TSV/Markdown 报告，不写回 runtime 配置。

## 5. 为什么不修改 runtime_loader_config

`runtime_loader_config.json` 是正式运行态开关。
本阶段必须保持 `content_engine_runtime_enabled=false` 与 `integration_mode=disabled`，避免误入正式流程。

## 6. 为什么不接正式流程

正式流程涉及玩家奖励、成长结算、UI 与战斗状态写入。
当前阶段目标仅为离线可验证性，不承载线上行为变更。

## 7. v1.0d 后续进入测试入口条件

需要同时满足：

1. freeze 守护连续稳定通过。
2. runtime_test 报告连续稳定通过。
3. 新阶段设计明确评审通过并允许修改业务入口。

## 8. 禁止范围

禁止新增 runtime 目录文件。
禁止扩大 runtime 白名单。
禁止修改正式奖励源与高风险业务文件。
禁止改动玩家奖励、成长奖励、结算 UI、battle_state/combat_result。

## 9. 风险与回滚

若 harness 报告出现 blocking 失败，视为数据或边界回归风险。
应回滚到最近一次 `runtime_test_harness_status=pass` 的提交，再逐项恢复。

## 10. 验收命令

```bash
python3 tools/content_engine/battle_reward_runtime_test_harness.py
python3 tools/content_engine/battle_reward_runtime_test_harness_validator.py
```
