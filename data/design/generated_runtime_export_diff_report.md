# Runtime Export Diff Report

- Stage: v0.7d runtime export diff report
- Runtime export implemented: no
- Runtime files written: 0
- Records: 7
- Planned export candidates: 2
- Blocked records: 5

## Diff Summary

| Runtime Domain | Artifact ID | Would Export | Planned Runtime Path | Export Action | Diff Status |
|---|---|---|---|---|---|
| battle_reward | generated_battle_reward_plan | true | data/runtime/content_engine/battle_reward.json | planned_create | new_runtime_file_planned |
| card_pool | generated_card_pool | true | data/runtime/content_engine/card_pool.json | planned_create | new_runtime_file_planned |
| enemy_deck | generated_enemy_deck_sets,generated_card_pool,generated_enemy_deck_skeleton | false | data/runtime/content_engine/enemy_deck.json | blocked | blocked |
| narrative_node | generated_narrative_node_plan | false | data/runtime/content_engine/narrative_node.json | blocked | blocked |
| operation_node | generated_operation_node_plan | false | data/runtime/content_engine/operation_node.json | blocked | blocked |
| package_manifest | generated_content_package_manifest,generated_validator_summary,generated_content_package_approval | false | data/runtime/content_engine/package_manifest.json | blocked | blocked |
| route_gate | generated_route_gate_plan | false | data/runtime/content_engine/route_gate.json | blocked | blocked |

## Planned Candidates

| Runtime Domain | Artifact ID | Planned Runtime Path |
|---|---|---|
| battle_reward | generated_battle_reward_plan | data/runtime/content_engine/battle_reward.json |
| card_pool | generated_card_pool | data/runtime/content_engine/card_pool.json |

## Safety Notes

- This is a design-layer diff report only.
- planned_runtime_path is a planning target and does not mean files are written.
- data/runtime/content_engine/ is not created in v0.7d.
- Runtime exporter implementation remains out of scope.
