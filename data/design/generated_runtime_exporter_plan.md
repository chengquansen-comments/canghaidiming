# Runtime Exporter Plan

- Stage: v0.8b guarded write mode
- Runtime export implemented: guarded_write
- Runtime files written: 2
- Records: 7
- Allowed candidates: 2
- Blocked records: 5
- write_runtime_requested: true
- confirm_runtime_export: true
- write_enabled: true

## Exporter Plan Summary

| Runtime Domain | Artifact ID | Export Action | Would Write | Actual Write Status | Blocked Reason |
|---|---|---|---|---|---|
| enemy_deck | generated_enemy_deck_sets,generated_card_pool,generated_enemy_deck_skeleton | blocked | false | blocked | approval_status_not_approved,approved_for_export_not_true,not_manually_approved,validator_status_not_pass,waiver_flags_present,waiver_not_cleared |
| card_pool | generated_card_pool | planned_create | true | written |  |
| battle_reward | generated_battle_reward_plan | planned_create | true | written |  |
| operation_node | generated_operation_node_plan | blocked | false | blocked | approval_status_not_approved,approved_for_export_not_true,not_manually_approved |
| narrative_node | generated_narrative_node_plan | blocked | false | blocked | approval_status_not_approved,approved_for_export_not_true,not_manually_approved |
| route_gate | generated_route_gate_plan | blocked | false | blocked | approval_status_not_approved,approved_for_export_not_true,not_manually_approved |
| package_manifest | generated_content_package_manifest,generated_validator_summary,generated_content_package_approval | blocked | false | blocked | approval_status_not_approved,approved_for_export_not_true,not_manually_approved,validator_status_not_pass,waiver_not_cleared |

## Safety Notes

- Default no-write mode remains the safe default.
- Runtime write requires both --write-runtime and --confirm-runtime-export.
- Guarded write allowlist: card_pool.json, battle_reward.json.
- Exporter does not modify scripts/, scenes/, data/story_battles/, or Godot runtime logic.
