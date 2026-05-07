# Content Package Approval Report

- Package version: v0.6d
- Artifact count: 13
- Approved for export count: 0
- Pending review count: 11
- Waiver required count: 2
- Blocked count: 0

## Approval Summary

| Status | Count |
|---|---:|
| approved | 0 |
| pending_review | 11 |
| waiver_required | 2 |
| blocked | 0 |
| rejected | 0 |

## Artifact Approval Table

| Artifact | Validator | Approval | Risk | Approved for Export | Required Actions |
|---|---|---|---|---|---|
| progression_numeric_config_v1_3 | SOURCE_ONLY | pending_review | medium | false | manual_review_required, define_runtime_schema, add_runtime_export_mapping, approve_before_v0_7 |
| generated_battle_slot_plan | PASS | pending_review | low | false | manual_review_required, define_runtime_schema, add_runtime_export_mapping, approve_before_v0_7 |
| generated_enemy_deck_requirement | PASS | pending_review | low | false | manual_review_required, define_runtime_schema, add_runtime_export_mapping, approve_before_v0_7 |
| generated_route_progression_curve | PASS | pending_review | low | false | manual_review_required, define_runtime_schema, add_runtime_export_mapping, approve_before_v0_7 |
| generated_operation_node_requirement | PASS | pending_review | low | false | manual_review_required, define_runtime_schema, add_runtime_export_mapping, approve_before_v0_7 |
| generated_enemy_archetype_pool | PASS | pending_review | medium | false | manual_review_required, define_runtime_schema, add_runtime_export_mapping, approve_before_v0_7 |
| generated_enemy_deck_skeleton | WARN | waiver_required | high | false | manual_review_required, define_runtime_schema, add_runtime_export_mapping, approve_before_v0_7, resolve_validator_warning, manual_waiver_required |
| generated_card_pool | PASS | pending_review | high | false | manual_review_required, define_runtime_schema, add_runtime_export_mapping, approve_before_v0_7, sampler_validation_required |
| generated_enemy_deck_sets | WARN | waiver_required | high | false | manual_review_required, define_runtime_schema, add_runtime_export_mapping, approve_before_v0_7, resolve_validator_warning, manual_waiver_required, sampler_validation_required |
| generated_battle_reward_plan | PASS | pending_review | medium | false | manual_review_required, define_runtime_schema, add_runtime_export_mapping, approve_before_v0_7 |
| generated_operation_node_plan | PASS | pending_review | medium | false | manual_review_required, define_runtime_schema, add_runtime_export_mapping, approve_before_v0_7 |
| generated_narrative_node_plan | PASS | pending_review | high | false | manual_review_required, define_runtime_schema, add_runtime_export_mapping, approve_before_v0_7 |
| generated_route_gate_plan | PASS | pending_review | high | false | manual_review_required, define_runtime_schema, add_runtime_export_mapping, approve_before_v0_7 |

## Waiver Required

- generated_enemy_deck_skeleton
- generated_enemy_deck_sets
- WARN artifact cannot enter runtime export without manual waiver.

## Runtime Export Rule

- v0.7 runtime exporter must only consume approved_for_export=true artifacts.
- Current v0.6d generator does not approve any artifact automatically.
- Runtime exporter must not directly scan data/design/generated_*.tsv.
