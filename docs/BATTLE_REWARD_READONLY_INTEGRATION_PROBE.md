# Battle Reward 受控只读接入试验说明

## 1）定位

`battle_reward_readonly_integration_probe` 是 battle_reward 的受控只读接入试验。  
它的目标是验证 runtime battle_reward 与 legacy 设计源在 Godot 环境下是否可只读对齐。

## 2）明确边界

- 不是正式奖励逻辑接入
- 不替换现有奖励源
- 不参与真实战斗结算
- 不改战斗主流程脚本
- `card_pool` 保持 out_of_scope

本试验只用于“读取 + 对比 + 报告”，不用于玩家流程决策。

## 3）执行入口

Godot 探针（headless-only）：

```bash
godot --headless --path . --script tools/content_engine/battle_reward_readonly_integration_probe.gd
```

Python 报告入口：

```bash
python3 tools/content_engine/battle_reward_readonly_integration_probe.py
python3 tools/content_engine/battle_reward_readonly_integration_probe_validator.py
```

输出报告：

- `data/design/generated_battle_reward_readonly_integration_probe_report.tsv`
- `data/design/generated_battle_reward_readonly_integration_probe_report.md`

## 4）为什么 `runtime_loader_config` 仍保持 disabled

当前 `runtime_loader_config.json` 仍保持 disabled，是为了确保本试验停留在“受控只读验证”层，不进入正式接入行为。  
如果在此阶段改为 enabled，会把对比试验升级为运行时接入，超出本阶段边界并提高回滚风险。

## 5）验证内容

试验重点验证：

- manifest 可读取且有效
- runtime `battle_reward.json` 可读取
- runtime 与 legacy 记录数/字段数对齐
- 缺失/多余记录为 0
- `formal_data_source_replaced=false`
- `combat_flow_touched=false`
- `battle_state_touched=false`
- `integration_status=readonly_probe_only`

## 6）后续正式接入前置条件

如果未来要进入正式接入，需要另行设计并完成：

- 明确的开关控制策略（默认关闭、灰度启用、可审计）
- 可执行回滚方案（含数据回滚与开关回退）
- 小范围测试计划（固定样本、失败场景、验收阈值）
- 与主流程战斗结算解耦的安全验证步骤

在上述条件满足前，本试验结果仅作为只读对齐证据，不作为正式接入依据。
