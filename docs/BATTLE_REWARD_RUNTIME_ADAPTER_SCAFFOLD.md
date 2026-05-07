# battle_reward runtime adapter scaffold（v1.0b）

## 1. 阶段定位

v1.0b 的目标是补齐 `battle_reward` 正式接入前的 adapter 形状，建立只读、可验证、可回归的中间层。此阶段不进入主流程，只做 scaffold 与静态边界校验。

## 2. 为什么 v1.0b 仍不接主流程

- 当前 `runtime_loader_config.json` 必须保持 `disabled`。
- 旧奖励流程仍有多来源并行，直接切换有回归风险。
- 需要先通过 adapter 的边界验证：只读、可 fallback、可 compare、不改正式状态。

## 3. adapter 职责

- 提供统一接口：`resolve_reward(source_id, legacy_reward, context)`。
- 读取 `runtime_loader_config` 与 runtime `battle_reward.json`。
- 在返回结构中输出：`selected_reward`、`runtime_candidate`、`shadow_compare`、`fallback` 信息。
- 在 v1.0b 中强制 `selected_reward` 仍为 legacy。

## 4. adapter 明确不负责的事项

- 不负责调用奖励应用逻辑（例如卡牌发放、成长结算）。
- 不负责触发战斗结算 UI。
- 不负责修改战斗状态机、战斗结果对象、玩家库存或剧情标记。
- 不负责接入正式战斗主流程。

## 5. 输入结构

建议输入：

- `source_id: String`
- `legacy_reward: Dictionary`
- `context: Dictionary = {}`

说明：`legacy_reward` 是正式结果基线，adapter 仅读取并复制，不在原对象上写入。

## 6. 输出结构

当前 scaffold 输出包含：

- `selected_reward`
- `selected_source`
- `mode`
- `config_enabled`
- `runtime_candidate`
- `shadow_compare`
- `fallback_used`
- `fallback_reason`
- `read_only`
- `formal_data_source_replaced`
- `combat_flow_touched`
- `battle_state_touched`
- `selected_reward_runtime_effective`

## 7. config mode 设计

adapter 中保留 mode 常量：

- `legacy`
- `shadow`
- `runtime_test`
- `runtime_enabled`

但 v1.0b 仅作为形状保留，不允许 runtime 实际生效。

## 8. fallback 策略

- 配置读取失败：`fallback_used=true`，原因 `config_missing_or_invalid`。
- runtime 读取失败：`fallback_used=true`，原因 `runtime_missing_or_invalid`。
- 即使 runtime 可读，只要不满足 v1.0b 边界，仍返回 legacy。

## 9. shadow compare 设计

- `runtime_candidate` 仅记录候选数据。
- `shadow_compare` 仅记录对比信息（候选是否存在、字段规模、等价性摘要）。
- v1.0b 严格要求 `selected_reward_runtime_effective=false`。

## 10. 风险边界

- `read_only=true`
- `formal_data_source_replaced=false`
- `combat_flow_touched=false`
- `battle_state_touched=false`
- `config_enabled=false`（由 disabled 配置保证）

## 11. 后续 v1.0c 才能做什么

- 在不触碰高风险核心文件前提下，把 adapter 以“旁路 compare”方式接入单一入口。
- 建立 shadow 阶段差异监控与采样报告。
- 仍不允许 runtime 改写正式奖励结果，直到 runtime_test 验收通过。

## 12. 验收命令

- `python3 tools/content_engine/content_engine_check.py`
- `python3 tools/content_engine/content_engine_validate.py`
- `python3 tools/content_engine/content_engine_godot_probe.py`
- `python3 tools/content_engine/battle_reward_readonly_integration_probe.py`
- `python3 tools/content_engine/battle_reward_readonly_integration_probe_validator.py`
- `python3 tools/content_engine/battle_reward_legacy_flow_probe.py`
- `python3 tools/content_engine/battle_reward_legacy_flow_validator.py`
- `python3 tools/content_engine/battle_reward_runtime_adapter_scaffold_probe.py`
- `python3 tools/content_engine/battle_reward_runtime_adapter_scaffold_validator.py`
- `python3 tools/content_engine/content_engine_regression_runner.py`
- `python3 tools/content_engine/content_engine_regression_validator.py`
- `git diff --check`
- `godot --headless --path . --quit`
- `godot --headless --path . --quit scenes/MainVisual.tscn`
