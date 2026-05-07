# Battle Reward Shadow Freeze（v1.0d-prep）

## 1. 阶段定位

本文件定义 `v1.0d-prep` 的 shadow 边界冻结守护。
目标是防止 v1.0c 已完成的 shadow 实接被误改为 runtime 正式生效。

## 2. v1.0c 当前状态

当前接入点固定在 `scripts/narrative_demo_canonical_controller.gd::_battle_reward_for_source`。
`selected_reward` 仍为 legacy，runtime reward 仅用于 candidate/shadow_compare。

## 3. freeze 守护目标

`tools/content_engine/battle_reward_shadow_freeze_probe.py` 重点验证：

1. Adapter 引用白名单不扩散。
2. shadow 接入函数与文件不漂移。
3. runtime_loader_config 持续 disabled。
4. runtime battle_reward 条数保持 45。
5. 正式奖励源与高风险文件未被替换或改动。

## 4. 禁止后续误改范围

禁止把 runtime reward 作为正式返回值。
禁止在 shadow 接入区域调用结算链路关键函数（如 `grant_player_cards`、`set_result`）。
禁止修改正式奖励源与高风险主流程文件。

## 5. 允许后续变更条件

只有在后续阶段明确进入 runtime 正式测试入口并完成专项评审时，才可讨论切换策略。
在此之前，所有改动必须继续满足 freeze validator。

## 6. 验收命令

```bash
python3 tools/content_engine/battle_reward_shadow_freeze_probe.py
python3 tools/content_engine/battle_reward_shadow_freeze_validator.py
```

## 7. 回滚方式

若 freeze 校验失败，先回滚本次工具链改动，再恢复到最近一次通过 `content_engine_regression_validator.py` 的提交点。
随后重新执行 probe/validator，直到 `shadow_freeze_status=pass`。
