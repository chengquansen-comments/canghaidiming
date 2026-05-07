# Content Engine v1.2a Reward Preview Approval Overlay

## 阶段定位

本阶段仅建立 `generated_battle_reward_plan` 的 preview 审批覆盖层。
这不是 runtime approval，不写 runtime 文件，不接 Godot。

## 输入

- `data/design/generated_content_package_approval.tsv`
- `data/design/generated_validator_summary.tsv`
- `data/design/generated_content_package_manifest.tsv`
- `data/design/generated_runtime_export_dry_run.tsv`
- `data/design/generated_battle_reward_plan.tsv`

## 手工 overlay

`data/design/manual_reward_preview_approval_overlay.tsv` 只允许一条记录：

- `artifact_id=generated_battle_reward_plan`
- `approval_scope=reward_preview`
- `approval_status=approved`
- `approved_for_preview=true`
- `approved_for_runtime=false`

## 输出

- `data/design/generated_reward_preview_approval.tsv`
- `data/design/generated_reward_preview_approval.md`

## 安全边界

- 仅允许 preview 候选，不允许 runtime。
- `runtime_allowed` 固定为 `false`。
- 不改变 selected_reward（仍 legacy）。
- 不改变 runtime_loader_config（仍 disabled）。
- 不改变玩家奖励、成长奖励、结算 UI、battle_state、combat_result。
