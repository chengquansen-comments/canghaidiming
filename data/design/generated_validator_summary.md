# Content Validator Summary

- Validator count: 11
- PASS count: 11
- WARN count: 0
- FAIL count: 0
- Generated at: 2026-05-07T12:03:01+00:00
- Design dir: data/design

## Validator Results

| Validator | Stage | Target | Status | Warnings | Errors | Duration ms |
|---|---|---|---|---:|---:|---:|
| progression_validator | v0.1-v0.1.1 | generated_battle_slot_plan,generated_enemy_deck_requirement,generated_route_progression_curve,generated_operation_node_requirement | PASS | 0 | 0 | 86 |
| enemy_archetype_validator | v0.2 | generated_enemy_archetype_pool | PASS | 0 | 0 | 59 |
| enemy_deck_skeleton_validator | v0.3 | generated_enemy_deck_skeleton | PASS | 0 | 0 | 59 |
| card_pool_validator | v0.4a | generated_card_pool | PASS | 0 | 0 | 54 |
| enemy_deck_sets_validator | v0.4b | generated_enemy_deck_sets | PASS | 0 | 0 | 58 |
| battle_reward_validator | v0.5a | generated_battle_reward_plan | PASS | 0 | 0 | 57 |
| operation_node_validator | v0.5b | generated_operation_node_plan | PASS | 0 | 0 | 54 |
| narrative_node_validator | v0.5c | generated_narrative_node_plan | PASS | 0 | 0 | 53 |
| route_gate_validator | v0.5d | generated_route_gate_plan | PASS | 0 | 0 | 51 |
| content_package_manifest_validator | v0.6a | generated_content_package_manifest | PASS | 0 | 0 | 67 |
| content_package_report_validator | v0.6b | generated_content_package_report | PASS | 0 | 0 | 61 |

## Failure Details

No failed validators.

## Warning Details

No validator warnings.

## Runtime Export Readiness

- This summary does not approve runtime export.
- Runtime export still requires manual approval and runtime exporter implementation.
- Only artifacts with PASS validators should be considered for later approval.

## Next Steps

1. v0.6d content package approval / manual review
2. v0.7 runtime exporter should read manifest + report + validator summary
3. runtime exporter must not directly scan data/design/generated_*.tsv
