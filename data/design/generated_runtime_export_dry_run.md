# Runtime Export Dry Run

- Runtime export implemented: no
- Runtime files written: 0
- Runtime domains checked: 7
- Would export: 0
- Blocked: 7

## Dry Run Summary

| Runtime Domain | Artifact | Target Path | Would Export | Blocked | Reasons |
|---|---|---|---|---|---|
| enemy_deck | enemy_decks.json | data/runtime/content_engine/enemy_decks.json | false | true | approval_not_granted,approved_for_export_false,export_allowed_now_false,runtime_exporter_not_implemented,validator_warning_unresolved,waiver_required |
| card_pool | card_pool.json | data/runtime/content_engine/card_pool.json | false | true | approval_not_granted,approved_for_export_false,export_allowed_now_false,runtime_exporter_not_implemented |
| battle_reward | battle_rewards.json | data/runtime/content_engine/battle_rewards.json | false | true | approval_not_granted,approved_for_export_false,export_allowed_now_false,runtime_exporter_not_implemented |
| operation_node | operation_nodes.json | data/runtime/content_engine/operation_nodes.json | false | true | approval_not_granted,approved_for_export_false,export_allowed_now_false,runtime_exporter_not_implemented |
| narrative_node | narrative_nodes.json | data/runtime/content_engine/narrative_nodes.json | false | true | approval_not_granted,approved_for_export_false,export_allowed_now_false,runtime_exporter_not_implemented |
| route_gate | route_gates.json | data/runtime/content_engine/route_gates.json | false | true | approval_not_granted,approved_for_export_false,export_allowed_now_false,runtime_exporter_not_implemented |
| package_manifest | content_package_manifest.json | data/runtime/content_engine/content_package_manifest.json | false | true | approval_not_granted,approval_record_missing,export_allowed_now_false,runtime_exporter_not_implemented,source_artifact_missing_in_manifest,validator_not_pass |

## Export Candidates

No runtime export candidates.

## Blocked Runtime Artifacts

| Runtime Domain | Artifact | Block Reasons |
|---|---|---|
| enemy_deck | enemy_decks.json | approval_not_granted,approved_for_export_false,export_allowed_now_false,runtime_exporter_not_implemented,validator_warning_unresolved,waiver_required |
| card_pool | card_pool.json | approval_not_granted,approved_for_export_false,export_allowed_now_false,runtime_exporter_not_implemented |
| battle_reward | battle_rewards.json | approval_not_granted,approved_for_export_false,export_allowed_now_false,runtime_exporter_not_implemented |
| operation_node | operation_nodes.json | approval_not_granted,approved_for_export_false,export_allowed_now_false,runtime_exporter_not_implemented |
| narrative_node | narrative_nodes.json | approval_not_granted,approved_for_export_false,export_allowed_now_false,runtime_exporter_not_implemented |
| route_gate | route_gates.json | approval_not_granted,approved_for_export_false,export_allowed_now_false,runtime_exporter_not_implemented |
| package_manifest | content_package_manifest.json | approval_not_granted,approval_record_missing,export_allowed_now_false,runtime_exporter_not_implemented,source_artifact_missing_in_manifest,validator_not_pass |

## Decision Rules

- approved_for_export=true required
- approval_status=approved required
- validator_status=PASS required
- waiver clearance required for WARN sources
- export_allowed_now=true required
- runtime exporter implementation required

## Current Blocking Summary

| Block Reason | Count |
|---|---:|
| approval_not_granted | 7 |
| export_allowed_now_false | 7 |
| runtime_exporter_not_implemented | 7 |
| approved_for_export_false | 6 |
| approval_record_missing | 1 |
| source_artifact_missing_in_manifest | 1 |
| validator_not_pass | 1 |
| validator_warning_unresolved | 1 |
| waiver_required | 1 |

## Safety Notes

- This dry-run does not write runtime files.
- Runtime exporter must not directly scan data/design/generated_*.tsv.
- Runtime exporter must read manifest + approval + validator summary + schema proposal.
- Design-layer card pool is not CardData runtime data.
- Narrative skeleton is not final prose.
- Route gate plan is not Godot route logic.

## Next Steps

1. v0.7c manual approval overlay or approval update
2. v0.7d runtime export dry-run with approved sample
3. v0.8 runtime exporter implementation only after approved PASS artifacts exist
