# battle_reward shadow 接入设计确认（v1.0c-plan）

## 1. 阶段定位

- v1.0c-plan 仅为 shadow 接入设计确认层。
- 本阶段不实现 shadow。
- 本阶段不修改主流程。
- 本阶段不让 runtime reward 生效。

## 2. 前置状态

- v1.0a 已完成 legacy flow 静态定位。
- v1.0b 已完成 adapter scaffold。
- runtime `battle_reward.json` 已验证 45 条。
- `runtime_loader_config.json` 仍为 `disabled`。

## 3. 推荐最小接入点

- 首选：`scripts/narrative_demo_canonical_controller.gd::_battle_reward_for_source`
- 次选：`scripts/narrative_demo_canonical_controller.gd::_apply_battle_result_reward`
- 本阶段只做设计确认，不修改这些文件。

## 4. 为什么首选 `_battle_reward_for_source`

- 该点位于 narrative reward 源头附近，语义集中。
- 相比 battle controller 核心文件风险更低。
- 可以保持 legacy reward 继续作为 `selected_reward`。
- 可以旁路调用 adapter 产生 `shadow_compare`。
- 回滚成本低，删除调用点即可回退。

## 5. 明确不接入的位置

- `scripts/combat_resolver.gd`
- `scripts/battle_state_machine.gd`
- `scripts/card_data.gd`
- `scripts/battle_controller_core_round_resolution.gd::_finish_battle`
- `scripts/battle_controller_core_session_rewards.gd::_pick_reward_card`
- `scripts/battle_controller_core_session_rewards.gd::_open_gain_move`
- `scenes/*.tscn`

## 6. shadow 模式语义

- legacy reward 仍然是正式奖励。
- runtime reward 只作为 runtime_candidate。
- adapter 输出 shadow_compare。
- selected_reward 必须来自 legacy。
- runtime_reward_effective=false。
- adapter 失败必须 fallback legacy。
- 不改变玩家获得卡牌。
- 不改变成长奖励。
- 不改变结算 UI。
- 不修改 battle_state。
- 不修改 combat_result。

## 7. config mode 语义

- `disabled`：当前状态，不做正式接入。
- `legacy`：未来接入 adapter 后仍选 legacy。
- `shadow`：未来接入 adapter 后输出 shadow 对比，但仍选 legacy。
- `runtime_test`：未来仅测试入口可生效。
- `runtime_enabled`：未来小范围正式启用，本阶段不实现。
- 本阶段 `runtime_loader_config` 必须保持 disabled。

## 8. v1.0c 未来实现草案

- 在 `_battle_reward_for_source` 内部保留原 legacy reward 计算。
- 在 legacy reward 计算后调用 `adapter.resolve_reward(...)`。
- 使用 `adapter_result.selected_reward` 作为返回结果。
- `shadow_compare` 只写入调试报告或可选日志。
- 若 adapter 缺失、异常、runtime 缺失、config disabled，则返回 legacy。
- 禁止 adapter 直接应用奖励。

## 9. shadow report 设计

未来 v1.0c 可生成：

- `data/design/generated_battle_reward_shadow_report.tsv`
- `data/design/generated_battle_reward_shadow_report.md`

建议字段：

- `source_id`
- `legacy_reward_id`
- `runtime_reward_id`
- `selected_source`
- `selected_reward_runtime_effective`
- `match_status`
- `fallback_used`
- `fallback_reason`
- `config_mode`
- `adapter_error`
- `read_only`
- `formal_data_source_replaced`
- `battle_state_touched`
- `combat_flow_touched`

## 10. 回滚策略

- 软回滚：`runtime_loader_config` 保持或改回 `disabled`。
- 代码回滚：删除 `_battle_reward_for_source` 内 adapter 调用。
- 数据回滚：不需要修改正式奖励源。
- 异常回滚：adapter fallback legacy。
- 验证回滚：validator 证明 `selected_reward_source=legacy`。

## 11. 风险边界

- 不接 combat。
- 不接 card_pool。
- 不改 battle_state。
- 不改 combat_result。
- 不替换正式奖励源。
- 不改正式 UI。
- 不影响玩家实际奖励。

## 12. v1.0c 进入条件

- v1.0c-plan 文档通过。
- adapter scaffold validator 通过。
- shadow integration plan validator 通过。
- `content_engine_check.py` 通过。
- 高级回归通过。
- 明确授权修改 `scripts/narrative_demo_canonical_controller.gd`。
- `runtime_loader_config` 的目标 mode 仍需单独授权。

## 13. 验收命令

- `python3 tools/content_engine/content_engine_check.py`
- `python3 tools/content_engine/content_engine_validate.py`
- `python3 tools/content_engine/content_engine_godot_probe.py`
- `python3 tools/content_engine/battle_reward_readonly_integration_probe.py`
- `python3 tools/content_engine/battle_reward_readonly_integration_probe_validator.py`
- `python3 tools/content_engine/battle_reward_legacy_flow_probe.py`
- `python3 tools/content_engine/battle_reward_legacy_flow_validator.py`
- `python3 tools/content_engine/battle_reward_runtime_adapter_scaffold_probe.py`
- `python3 tools/content_engine/battle_reward_runtime_adapter_scaffold_validator.py`
- `python3 tools/content_engine/battle_reward_shadow_integration_plan_probe.py`
- `python3 tools/content_engine/battle_reward_shadow_integration_plan_validator.py`
- `python3 tools/content_engine/content_engine_regression_runner.py`
- `python3 tools/content_engine/content_engine_regression_validator.py`
- `git diff --check`
- `godot --headless --path . --quit`
- `godot --headless --path . --quit scenes/MainVisual.tscn`
