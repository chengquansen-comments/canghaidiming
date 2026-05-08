# Runtime Export Dry Run

## Dry Run Summary

- dry_run_id: dryrun-20260508T044443Z-b0e5a02f
- runtime_domain_count: 7
- would_export_count: 0
- blocked_count: 7
- runtime_files_written: 0

## Export Candidates

- 当前无可导出候选（would_export 全部为 false）。

## Blocked Runtime Artifacts

- battle_reward -> battle_rewards.json (blocked=true, reasons=approval_status:generated_battle_reward_plan=pending_review,approved_for_export_false:generated_battle_reward_plan,schema_export_allowed_now_false)
- card_pool -> card_pool.json (blocked=true, reasons=approval_status:generated_card_pool=pending_review,approved_for_export_false:generated_card_pool,schema_export_allowed_now_false)
- enemy_deck -> enemy_decks.json (blocked=true, reasons=approval_status:generated_card_pool=pending_review,approval_status:generated_enemy_deck_sets=waiver_required,approval_status:generated_enemy_deck_skeleton=waiver_required,approved_for_export_false:generated_card_pool,approved_for_export_false:generated_enemy_deck_sets,approved_for_export_false:generated_enemy_deck_skeleton,schema_export_allowed_now_false,waiver_required:generated_enemy_deck_sets,waiver_required:generated_enemy_deck_skeleton)
- narrative_node -> narrative_nodes.json (blocked=true, reasons=approval_status:generated_narrative_node_plan=pending_review,approved_for_export_false:generated_narrative_node_plan,schema_export_allowed_now_false)
- operation_node -> operation_nodes.json (blocked=true, reasons=approval_status:generated_operation_node_plan=pending_review,approved_for_export_false:generated_operation_node_plan,schema_export_allowed_now_false)
- package_manifest -> content_package_manifest.json (blocked=true, reasons=approval_missing:generated_content_package_approval,approval_missing:generated_content_package_manifest,approval_missing:generated_validator_summary,manifest_missing:generated_content_package_approval,manifest_missing:generated_content_package_manifest,manifest_missing:generated_validator_summary,schema_export_allowed_now_false,validator_status:generated_content_package_approval=MISSING,validator_status:generated_validator_summary=MISSING)
- route_gate -> route_gates.json (blocked=true, reasons=approval_status:generated_route_gate_plan=pending_review,approved_for_export_false:generated_route_gate_plan,schema_export_allowed_now_false)

## Decision Rules

- 必须同时满足 approval_check=pass、validator_check=pass、waiver_check=pass、schema_check=pass。
- 且 export_allowed_now=true 才会 would_export=true。

## Current Blocking Summary

- 当前 approval 表未给出 approved_for_export=true，且 schema export_allowed_now 仍为 false。
- 因此本次 dry-run 全部 blocked，且不会写 runtime 文件。

## Safety Notes

- 本工具只做决策模拟，不创建 data/runtime，不写任何 runtime JSON。
- 不改变 selected_reward、battle_state、combat_result 与任何正式奖励流程。

## Next Steps

- 补齐 approved_for_export 审批链路。
- 在后续阶段实现真实 runtime exporter 前，继续保持 dry-run only。
