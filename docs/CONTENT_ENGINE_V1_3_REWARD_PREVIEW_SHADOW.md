# Content Engine v1.3 Reward Preview Read-Only Shadow Probe

## 阶段定位

本阶段仅做 reward preview package 的只读探测与 shadow 对比报告生成。
不替换正式奖励，不接入正式运行时流程。

## 输入

- `data/runtime_preview/content_engine/battle_rewards.preview.json`
- `data/runtime_preview/content_engine/battle_rewards.preview_manifest.json`
- 既有 shadow freeze 报告（用于复核 selected_reward 与 runtime_loader_config）

## 输出

- `data/design/generated_reward_preview_readonly_probe_report.tsv`
- `data/design/generated_reward_preview_shadow_compare_report.tsv`

## 只读规则

1. preview manifest 必须 `runtime_ready=false`。
2. preview manifest 必须 `selected_reward_policy=legacy`。
3. preview reward 数量必须为 45。
4. 每条 preview reward 仅作为 candidate 信息。
5. `selected_reward` 保持 legacy，不做写回。

## 安全边界

- 不写 `data/runtime` 正式 runtime 文件。
- 不改变玩家实际奖励、成长奖励、结算 UI。
- 不改变 battle_state 与 combat_result。
- 保持 `runtime_loader_config=disabled`。
