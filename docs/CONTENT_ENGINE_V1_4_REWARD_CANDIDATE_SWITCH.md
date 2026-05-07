# Content Engine v1.4 reward candidate switch skeleton

## 阶段定位
v1.4 仅建立 `reward_source_mode` 候选开关骨架，用于测试与探针读取候选奖励，不进入正式 Godot 奖励流程。

## 模式定义
- `legacy`：默认模式，正式选择仍为 legacy。
- `shadow_compare`：只做对比，不替换正式 selected_reward。
- `content_engine_candidate`：只作为候选读取，不写入正式结算。
- `content_engine_enabled`：本阶段禁止启用。

## 当前默认配置
设计层配置文件：`data/design/reward_source_mode_config.tsv`

- `reward_source_mode=legacy`

## Probe 与 Validator
- Probe：`tools/content_engine/reward_candidate_switch_probe.py`
- Validator：`tools/content_engine/reward_candidate_switch_validator.py`
- 报告：`data/design/generated_reward_candidate_switch_probe_report.tsv`

Probe 会输出四种模式的只读检查状态，覆盖：
- preview 包是否存在
- preview 奖励数量
- selected_reward 是否保持 legacy
- runtime_loader_config 是否 disabled
- 是否存在 runtime 写入痕迹

Validator 会阻断以下风险：
- 默认模式不是 legacy
- `content_engine_enabled` 被启用
- selected_reward 被改写
- runtime_loader_config 被启用
- preview 奖励数量不是 45
- 写入 `data/runtime/content_engine/battle_rewards.json`
- 修改 story/runtime/scenes/battle core 禁止文件

## 安全边界
- 不新增 `data/runtime/` 文件。
- 不替换正式奖励源。
- 不改变玩家实际奖励、成长奖励、结算 UI、battle_state、combat_result。
- runtime reward 仍仅 candidate/shadow_compare。

## 使用命令
```bash
python3 tools/content_engine/reward_candidate_switch_probe.py
python3 tools/content_engine/reward_candidate_switch_validator.py
```
