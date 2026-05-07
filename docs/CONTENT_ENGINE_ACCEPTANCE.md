# Content Engine 交付验收入口（v1.0d-final）

## 1. 阶段定位

本阶段是 `v1.0d-final`，目标是对 reward 验收链路做 **Acceptance Determinism Hardening**。
本阶段不是 `runtime_enabled`，不让 runtime reward 进入正式游戏流程。

## 2. 为什么需要 determinism hardening

此前在并行触发条件下出现过一次瞬时“缺少报告”，说明验收链路存在读取时序风险。
本阶段要求 runner 与 validator 在单次顺序执行和连续两轮执行中都稳定 PASS，不依赖复跑。

## 3. runner 顺序执行流程

`tools/content_engine/content_engine_acceptance_runner.py` 固定顺序执行：

1. `python3 tools/content_engine/battle_reward_shadow_freeze_probe.py`
2. `python3 tools/content_engine/battle_reward_shadow_freeze_validator.py`
3. `python3 tools/content_engine/battle_reward_runtime_test_harness.py`
4. `python3 tools/content_engine/battle_reward_runtime_test_harness_validator.py`
5. `python3 tools/content_engine/content_engine_regression_runner.py`
6. `python3 tools/content_engine/content_engine_regression_validator.py`
7. 写出 acceptance step report 与 acceptance summary。

## 4. required reports 列表

当前 acceptance summary 要求以下报告路径存在且非空：

- `data/design/generated_battle_reward_shadow_freeze_report.tsv`
- `data/design/generated_battle_reward_shadow_freeze_report.md`
- `data/design/generated_battle_reward_runtime_test_harness_report.tsv`
- `data/design/generated_battle_reward_runtime_test_harness_report.md`
- `data/design/generated_content_engine_regression_report.tsv`
- `data/design/generated_content_engine_regression_report.md`

## 5. atomic report write 策略

所有 acceptance 产物使用原子写入：

1. 先写 `*.tmp`。
2. close + flush + fsync。
3. `os.replace(tmp, final)` 原子替换。

本阶段 acceptance 产物包括：

- `data/design/generated_content_engine_acceptance_report.tsv`
- `data/design/generated_content_engine_acceptance_report.md`
- `data/design/generated_content_engine_acceptance_summary.tsv`
- `data/design/generated_content_engine_acceptance_summary.md`

## 6. 旧报告清理策略

runner 启动时先清理上述 4 个 acceptance 自有输出，避免 stale acceptance 文件误判。
不会清理无关 generated 设计表。

## 7. 状态定义

summary 的 `status` 使用以下语义：

- `pass`：本轮报告存在、非空、可读，且与本轮 step 状态一致。
- `missing_report`：缺失 required report。
- `empty_report`：报告为空文件。
- `stale_report`：报告时间戳早于本轮 run 起点。
- `invalid_report:*`：格式或可读性异常，或 step 失败导致结果无效。

## 8. validator 如何判定 PASS

`tools/content_engine/content_engine_acceptance_validator.py` 以 acceptance summary 为主入口，校验：

1. summary 与 step report 文件存在且非空。
2. summary `run_id` 唯一，且 step report `run_id` 与 summary 一致。
3. required check_id 全覆盖。
4. required report 的存在性、非空状态与 summary 记录一致。
5. 任一 `missing/empty/stale/invalid` 直接 FAIL。
6. shadow freeze 与 runtime harness 关键约束仍满足。

## 9. 连续两轮验收要求

必须连续执行两轮：

```bash
python3 tools/content_engine/content_engine_acceptance_runner.py
python3 tools/content_engine/content_engine_acceptance_validator.py
python3 tools/content_engine/content_engine_acceptance_runner.py
python3 tools/content_engine/content_engine_acceptance_validator.py
```

要求两轮均 PASS，且不出现瞬时“缺少报告”。

## 10. 当前业务边界声明

- `selected_reward` 仍为 `legacy`。
- runtime reward 仍只允许 `candidate/shadow_compare`。
- `runtime_loader_config` 仍为 `disabled`。
- 当前仍不替换正式奖励源（`data/rewards.json` / `data/enemy_manifest.json` / `data/story_battles.json`）。
