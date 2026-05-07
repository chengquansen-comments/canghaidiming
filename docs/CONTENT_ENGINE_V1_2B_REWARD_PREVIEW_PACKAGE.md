# Content Engine v1.2b Reward Preview Package Export

## 阶段定位

本阶段仅导出 reward preview 包，不属于 runtime export。

## 输入

- `data/design/generated_reward_preview_approval.tsv`
- `data/design/generated_battle_reward_plan.tsv`

## 输出

- `data/runtime_preview/content_engine/battle_rewards.preview.json`
- `data/runtime_preview/content_engine/battle_rewards.preview_manifest.json`

## 规则

1. 仅允许 `generated_battle_reward_plan` 导出。
2. 需满足 `preview_allowed=true`、`runtime_allowed=false`、`approved_for_runtime=false`。
3. 仅写入 `data/runtime_preview`，不写 `data/runtime`。
4. `runtime_ready` 必须为 `false`。

## 安全边界

- `selected_reward_policy=legacy`。
- 不改 runtime_loader_config。
- 不改玩家奖励、成长奖励、结算 UI、battle_state、combat_result。
