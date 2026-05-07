# Reward Preview Approval

## 概要

- 阶段：v1.2a reward-only preview approval overlay
- 仅处理：generated_battle_reward_plan
- preview_allowed：true
- runtime_allowed：false
- runtime 文件写入：0

## 审批结论

- approval_id：approval_reward_preview_generated_battle_reward_plan
- approval_scope：reward_preview
- approval_status：approved
- approved_for_preview：true
- approved_for_runtime：false
- blockers：none

## 安全边界

- 本审批仅用于 reward preview 候选，不属于 runtime approval。
- 不写 runtime，不接 Godot，不改变玩家奖励与战斗流程。
