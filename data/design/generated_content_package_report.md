# Content Package Report

- Package version: v0.6a
- Source manifest: data/design/generated_content_package_manifest.tsv
- Artifact count: 13
- Runtime ready artifacts: 0
- Blocked artifacts: 13

## 2. Executive Summary

- Current package state: design-layer package only.
- Runtime exporter status: not implemented.
- Runtime consumption rule: all generated design tables should remain outside runtime until validator orchestration and manual approval are in place.
- Validator status note: validator_status may be NOT_RUN because v0.6a manifest generation did not re-run validators.
- Next phase recommendation: finish report-driven review and validator orchestration before starting runtime exporter work.

## 3. Artifact Inventory

| Artifact | Type | Stage | Rows | Validator | Runtime Ready | Export Scope |
|---|---|---|---:|---|---|---|
| progression_numeric_config_v1_3 | source_config | v0.1 | 101 | SOURCE_ONLY | false | none |
| generated_battle_slot_plan | design_plan | v0.1 | 16 | NOT_RUN | false | future_runtime |
| generated_enemy_deck_requirement | design_plan | v0.1 | 6 | NOT_RUN | false | future_runtime |
| generated_route_progression_curve | design_plan | v0.1 | 8 | NOT_RUN | false | future_runtime |
| generated_operation_node_requirement | design_plan | v0.1.1 | 3 | NOT_RUN | false | future_runtime |
| generated_enemy_archetype_pool | generated_table | v0.2 | 21 | NOT_RUN | false | future_runtime |
| generated_enemy_deck_skeleton | generated_table | v0.3 | 39 | NOT_RUN | false | future_runtime |
| generated_card_pool | generated_table | v0.4a | 72 | NOT_RUN | false | future_runtime |
| generated_enemy_deck_sets | generated_table | v0.4b | 466 | NOT_RUN | false | future_runtime |
| generated_battle_reward_plan | reward_plan | v0.5a | 45 | NOT_RUN | false | future_runtime |
| generated_operation_node_plan | generated_table | v0.5b | 10 | NOT_RUN | false | future_runtime |
| generated_narrative_node_plan | narrative_plan | v0.5c | 28 | NOT_RUN | false | future_runtime |
| generated_route_gate_plan | route_gate_plan | v0.5d | 9 | NOT_RUN | false | future_runtime |

## 4. Dependency Graph

- progression_numeric_config_v1_3
  - depends on: none
- generated_battle_slot_plan
  - depends on: progression_numeric_config_v1_3
- generated_enemy_deck_requirement
  - depends on: progression_numeric_config_v1_3
- generated_route_progression_curve
  - depends on: progression_numeric_config_v1_3
- generated_operation_node_requirement
  - depends on: progression_numeric_config_v1_3
- generated_enemy_archetype_pool
  - depends on: generated_enemy_deck_requirement, generated_battle_slot_plan, generated_route_progression_curve, generated_operation_node_requirement
- generated_enemy_deck_skeleton
  - depends on: generated_enemy_archetype_pool, generated_enemy_deck_requirement, generated_battle_slot_plan
- generated_card_pool
  - depends on: generated_enemy_deck_skeleton, generated_enemy_archetype_pool, generated_enemy_deck_requirement
- generated_enemy_deck_sets
  - depends on: generated_enemy_deck_skeleton, generated_card_pool, generated_enemy_archetype_pool, generated_enemy_deck_requirement
- generated_battle_reward_plan
  - depends on: generated_battle_slot_plan, generated_enemy_deck_skeleton, generated_enemy_deck_sets, generated_enemy_archetype_pool, generated_route_progression_curve, progression_numeric_config_v1_3
- generated_operation_node_plan
  - depends on: generated_operation_node_requirement, generated_battle_reward_plan, generated_route_progression_curve, progression_numeric_config_v1_3
- generated_narrative_node_plan
  - depends on: generated_operation_node_plan, generated_battle_reward_plan, generated_route_progression_curve, generated_battle_slot_plan
- generated_route_gate_plan
  - depends on: generated_battle_reward_plan, generated_operation_node_plan, generated_narrative_node_plan, generated_route_progression_curve, progression_numeric_config_v1_3

## 5. Validator Status Summary

| Status | Count |
|---|---:|
| SOURCE_ONLY | 1 |
| NOT_RUN | 12 |
| PASS | 0 |
| WARN | 0 |
| FAIL | 0 |

NOT_RUN does not mean invalid. It means the manifest generator did not re-run validators.

## 6. Export Readiness

### 6.1 Runtime-ready candidates

No runtime-ready artifacts in this package.

### 6.2 Blocked artifacts

| Artifact | Export Scope | Blockers |
|---|---|---|
| progression_numeric_config_v1_3 | none | runtime_exporter_not_implemented, runtime_schema_not_defined |
| generated_battle_slot_plan | future_runtime | runtime_exporter_not_implemented, runtime_schema_not_defined, needs_manual_review |
| generated_enemy_deck_requirement | future_runtime | runtime_exporter_not_implemented, runtime_schema_not_defined, needs_manual_review |
| generated_route_progression_curve | future_runtime | runtime_exporter_not_implemented, runtime_schema_not_defined, needs_manual_review |
| generated_operation_node_requirement | future_runtime | runtime_exporter_not_implemented, runtime_schema_not_defined, needs_manual_review |
| generated_enemy_archetype_pool | future_runtime | runtime_exporter_not_implemented, runtime_schema_not_defined, needs_manual_review |
| generated_enemy_deck_skeleton | future_runtime | runtime_exporter_not_implemented, runtime_schema_not_defined, needs_manual_review |
| generated_card_pool | future_runtime | runtime_exporter_not_implemented, runtime_schema_not_defined, needs_manual_review |
| generated_enemy_deck_sets | future_runtime | runtime_exporter_not_implemented, runtime_schema_not_defined, needs_manual_review |
| generated_battle_reward_plan | future_runtime | runtime_exporter_not_implemented, runtime_schema_not_defined, needs_manual_review |
| generated_operation_node_plan | future_runtime | runtime_exporter_not_implemented, runtime_schema_not_defined, needs_manual_review |
| generated_narrative_node_plan | future_runtime | runtime_exporter_not_implemented, runtime_schema_not_defined, needs_manual_review |
| generated_route_gate_plan | future_runtime | runtime_exporter_not_implemented, runtime_schema_not_defined, needs_manual_review |

### 6.3 Manual-review candidates

These artifacts need manual review or validator orchestration before runtime export remains thinkable:

- generated_battle_slot_plan: validator_status=NOT_RUN, type=design_plan, export_scope=future_runtime
- generated_enemy_deck_requirement: validator_status=NOT_RUN, type=design_plan, export_scope=future_runtime
- generated_route_progression_curve: validator_status=NOT_RUN, type=design_plan, export_scope=future_runtime
- generated_operation_node_requirement: validator_status=NOT_RUN, type=design_plan, export_scope=future_runtime
- generated_enemy_archetype_pool: validator_status=NOT_RUN, type=generated_table, export_scope=future_runtime
- generated_enemy_deck_skeleton: validator_status=NOT_RUN, type=generated_table, export_scope=future_runtime
- generated_card_pool: validator_status=NOT_RUN, type=generated_table, export_scope=future_runtime
- generated_enemy_deck_sets: validator_status=NOT_RUN, type=generated_table, export_scope=future_runtime
- generated_battle_reward_plan: validator_status=NOT_RUN, type=reward_plan, export_scope=future_runtime
- generated_operation_node_plan: validator_status=NOT_RUN, type=generated_table, export_scope=future_runtime
- generated_narrative_node_plan: validator_status=NOT_RUN, type=narrative_plan, export_scope=future_runtime
- generated_route_gate_plan: validator_status=NOT_RUN, type=route_gate_plan, export_scope=future_runtime

## 7. Runtime Export Blockers

| Blocker | Count |
|---|---:|
| needs_manual_review | 12 |
| runtime_exporter_not_implemented | 13 |
| runtime_schema_not_defined | 13 |

## 8. Risk Notes

- validators were not run as part of manifest generation.
- no artifact should be consumed by runtime exporter yet.
- narrative plan contains skeleton keys only, not final prose.
- route gate plan is design-layer only, not runtime route logic.
- card pool and enemy deck sets are design-layer content, not CardData runtime records.

## 9. Suggested Next Steps

- v0.6c: validator orchestration.
- v0.6c detail: run all existing validators through one orchestration entrypoint.
- v0.6c detail: update manifest validator_status fields or generate a validator status summary artifact.
- v0.6d: content package approval and manual review.
- v0.6d detail: manually confirm exportable artifacts and mark approved_for_export in a future controlled layer.
- v0.7: runtime exporter.
- v0.7 detail: only read manifest/report, only export approved + PASS artifacts, and never scan data/design/generated_*.tsv directly.
