# Runtime Schema Proposal

- Package stage: v0.7a
- Runtime export implemented: no
- Export allowed now: no
- Runtime-ready artifact count: 0

## Proposed Runtime Artifacts

| Runtime Artifact | Domain | Target Path | Source Artifacts | Export Allowed Now |
|---|---|---|---|---|
| enemy_decks.json | enemy_deck | data/runtime/content_engine/enemy_decks.json | generated_enemy_deck_sets,generated_card_pool,generated_enemy_deck_skeleton | false |
| card_pool.json | card_pool | data/runtime/content_engine/card_pool.json | generated_card_pool | false |
| battle_rewards.json | battle_reward | data/runtime/content_engine/battle_rewards.json | generated_battle_reward_plan | false |
| operation_nodes.json | operation_node | data/runtime/content_engine/operation_nodes.json | generated_operation_node_plan | false |
| narrative_nodes.json | narrative_node | data/runtime/content_engine/narrative_nodes.json | generated_narrative_node_plan | false |
| route_gates.json | route_gate | data/runtime/content_engine/route_gates.json | generated_route_gate_plan | false |
| content_package_manifest.json | package_manifest | data/runtime/content_engine/content_package_manifest.json | generated_content_package_manifest,generated_validator_summary,generated_content_package_approval | false |

## Export Policy

- approved_for_export=true required
- validator_status=PASS required
- approval_status=approved required
- WARN requires manual waiver
- runtime exporter must not directly scan generated_*.tsv

## Blockers

- no approved artifacts
- runtime schema not implemented in Godot
- runtime exporter not implemented
- two warning artifacts require waiver before export

## Next Steps

1. v0.7b runtime export dry-run
2. only evaluate export candidates and blockers, without writing runtime files
3. v0.7c runtime exporter implementation must read approval + schema proposal and only export approved artifacts
