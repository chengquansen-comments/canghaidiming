# Runtime Export Approval Overlay

- Overlay stage: v0.7c manual approval overlay
- Runtime export implemented: no
- Runtime files written: 0
- Runtime domains checked: 7
- Would export: 2
- Blocked: 5

## Overlay Summary

| Runtime Domain | Artifact | Would Export | Blocked | Block Reasons |
|---|---|---|---|---|
| battle_reward | battle_rewards.json | true | false |  |
| card_pool | card_pool.json | true | false |  |
| enemy_deck | enemy_decks.json | false | true | approval_status_not_approved,approved_for_export_not_true,not_manually_approved,validator_status_not_pass,waiver_flags_present,waiver_not_cleared |
| narrative_node | narrative_nodes.json | false | true | approval_status_not_approved,approved_for_export_not_true,not_manually_approved |
| operation_node | operation_nodes.json | false | true | approval_status_not_approved,approved_for_export_not_true,not_manually_approved |
| package_manifest | content_package_manifest.json | false | true | approval_status_not_approved,approved_for_export_not_true,not_manually_approved,validator_status_not_pass,waiver_not_cleared |
| route_gate | route_gates.json | false | true | approval_status_not_approved,approved_for_export_not_true,not_manually_approved |

## Overlay Candidates

| Runtime Domain | Artifact | Source Artifacts |
|---|---|---|
| battle_reward | battle_rewards.json | generated_battle_reward_plan |
| card_pool | card_pool.json | generated_card_pool |

## Blocked Runtime Artifacts

| Runtime Domain | Artifact | Block Reasons |
|---|---|---|
| enemy_deck | enemy_decks.json | approval_status_not_approved,approved_for_export_not_true,not_manually_approved,validator_status_not_pass,waiver_flags_present,waiver_not_cleared |
| narrative_node | narrative_nodes.json | approval_status_not_approved,approved_for_export_not_true,not_manually_approved |
| operation_node | operation_nodes.json | approval_status_not_approved,approved_for_export_not_true,not_manually_approved |
| package_manifest | content_package_manifest.json | approval_status_not_approved,approved_for_export_not_true,not_manually_approved,validator_status_not_pass,waiver_not_cleared |
| route_gate | route_gates.json | approval_status_not_approved,approved_for_export_not_true,not_manually_approved |

## Blocking Summary

| Block Reason | Count |
|---|---:|
| approval_status_not_approved | 5 |
| approved_for_export_not_true | 5 |
| not_manually_approved | 5 |
| validator_status_not_pass | 2 |
| waiver_not_cleared | 2 |
| waiver_flags_present | 1 |

## Safety Notes

- This overlay does not write runtime files.
- This stage is manual approval overlay only, not runtime exporter.
- Runtime exporter remains out of scope until later stage.
