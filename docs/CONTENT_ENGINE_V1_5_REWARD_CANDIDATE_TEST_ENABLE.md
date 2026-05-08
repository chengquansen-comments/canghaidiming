# Content Engine v1.5 reward candidate test enable

## 阶段定位
v1.5 仅在离线 probe/test harness 中，对单一测试战斗槽位验证 `content_engine_candidate` 可被读取和命中。
本阶段不改变正式奖励流程，`selected_reward` 仍保持 legacy。

## 配置文件
- `data/design/reward_candidate_test_enable_config.tsv`

字段：
- `test_id`
- `battle_slot_id`
- `reward_plan_id`
- `test_mode`
- `candidate_allowed`
- `formal_selected_reward_policy`
- `notes`

约束：
- 仅允许 1 个测试 battle_slot。
- `test_mode=content_engine_candidate`
- `candidate_allowed=true`
- `formal_selected_reward_policy=legacy`

## Probe 与 Validator
- Probe：`tools/content_engine/reward_candidate_test_enable_probe.py`
- Report：`data/design/generated_reward_candidate_test_enable_report.tsv`
- Validator：`tools/content_engine/reward_candidate_test_enable_validator.py`

核心保障：
- 仅验证 candidate 可选，不改写正式 selected_reward。
- `runtime_loader_config` 仍 disabled。
- `content_engine_enabled` 不启用。
- 不写 `data/runtime/content_engine/battle_rewards.json`。

## 安全边界
- 不修改 Godot 正式流程文件。
- 不修改 story/scenes/battle core。
- 不改变玩家实际奖励、成长奖励、结算 UI、battle_state、combat_result。

## 运行命令
```bash
python3 tools/content_engine/reward_candidate_test_enable_probe.py
python3 tools/content_engine/reward_candidate_test_enable_validator.py
```
