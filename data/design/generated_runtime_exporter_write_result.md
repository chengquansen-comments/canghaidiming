# Runtime Exporter Write Result

- Records: 7
- written: 2
- blocked: 5
- failed_validation: 0
- not_written: 0

## Write Result Summary

| Runtime Domain | Artifact ID | Would Write | Actual Write Status | Bytes Written | Blocked Reason |
|---|---|---|---|---|---|
| battle_reward | generated_battle_reward_plan | true | written | 656 |  |
| card_pool | generated_card_pool | true | written | 634 |  |
| enemy_deck | generated_enemy_deck_sets,generated_card_pool,generated_enemy_deck_skeleton | false | blocked |  | approval_status_not_approved,approved_for_export_not_true,not_manually_approved,validator_status_not_pass,waiver_flags_present,waiver_not_cleared |
| narrative_node | generated_narrative_node_plan | false | blocked |  | approval_status_not_approved,approved_for_export_not_true,not_manually_approved |
| operation_node | generated_operation_node_plan | false | blocked |  | approval_status_not_approved,approved_for_export_not_true,not_manually_approved |
| package_manifest | generated_content_package_manifest,generated_validator_summary,generated_content_package_approval | false | blocked |  | approval_status_not_approved,approved_for_export_not_true,not_manually_approved,validator_status_not_pass,waiver_not_cleared |
| route_gate | generated_route_gate_plan | false | blocked |  | approval_status_not_approved,approved_for_export_not_true,not_manually_approved |

## Notes

- v0.8b writes guarded runtime scaffold content only.
- Runtime records may be empty in this stage; business data mapping remains out of scope.
