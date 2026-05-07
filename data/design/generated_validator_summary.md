# Content Validator Summary

- Validator count: 11
- PASS count: 9
- WARN count: 2
- FAIL count: 0
- Generated at: 2026-05-07T06:56:08+00:00
- Design dir: data/design

## Validator Results

| Validator | Stage | Target | Status | Warnings | Errors | Duration ms |
|---|---|---|---|---:|---:|---:|
| progression_validator | v0.1-v0.1.1 | generated_battle_slot_plan,generated_enemy_deck_requirement,generated_route_progression_curve,generated_operation_node_requirement | PASS | 0 | 0 | 66 |
| enemy_archetype_validator | v0.2 | generated_enemy_archetype_pool | PASS | 0 | 0 | 74 |
| enemy_deck_skeleton_validator | v0.3 | generated_enemy_deck_skeleton | WARN | 1 | 0 | 84 |
| card_pool_validator | v0.4a | generated_card_pool | PASS | 0 | 0 | 67 |
| enemy_deck_sets_validator | v0.4b | generated_enemy_deck_sets | WARN | 1 | 0 | 64 |
| battle_reward_validator | v0.5a | generated_battle_reward_plan | PASS | 0 | 0 | 64 |
| operation_node_validator | v0.5b | generated_operation_node_plan | PASS | 0 | 0 | 58 |
| narrative_node_validator | v0.5c | generated_narrative_node_plan | PASS | 0 | 0 | 138 |
| route_gate_validator | v0.5d | generated_route_gate_plan | PASS | 0 | 0 | 64 |
| content_package_manifest_validator | v0.6a | generated_content_package_manifest | PASS | 0 | 0 | 82 |
| content_package_report_validator | v0.6b | generated_content_package_report | PASS | 0 | 0 | 63 |

## Failure Details

No failed validators.

## Warning Details

- enemy_deck_skeleton_validator: warning_count=1, log_path=data/design/validator_logs/enemy_deck_skeleton_validator.log, summary_line=WARN: true_boss_hidden_commander skeleton count is near recommended count: expected 1, got 2.
- enemy_deck_sets_validator: warning_count=1, log_path=data/design/validator_logs/enemy_deck_sets_validator.log, summary_line=WARN: required_card_tags weak match on some rows: enemy_scout_footwork_basic:generic_forward_press, enemy_scout_footwork_advanced:generic_forward_press, enemy_scout_footwork_advanced:generic_link_cut, enemy_scout_footwork_aggressive:generic_forward_press, enemy_hungry_garrison_basic:generic_guard, enemy_hungry_garrison_basic:generic_counter_guard, enemy_hungry_garrison_basic:generic_posture_tap, enemy_hungry_garrison_basic:generic_guard_split, enemy_hungry_garrison_basic:generic_tempo_shift, enemy_hungry_garrison_advanced:generic_guard, enemy_hungry_garrison_advanced:generic_counter_guard, enemy_hungry_garrison_advanced:generic_side_step, enemy_hungry_garrison_advanced:generic_posture_tap, enemy_hungry_garrison_advanced:generic_guard_split, enemy_hungry_garrison_advanced:generic_tempo_shift, enemy_hungry_garrison_advanced:generic_link_cut, enemy_elite_dual_blade_raider_elite_basic:generic_counter_guard, enemy_elite_dual_blade_raider_elite_basic:generic_guard, enemy_elite_dual_blade_raider_elite_basic:generic_side_step, enemy_elite_dual_blade_raider_elite_basic:generic_guard_split, enemy_elite_dual_blade_raider_elite_basic:generic_posture_tap, enemy_elite_dual_blade_raider_elite_basic:generic_tempo_shift, enemy_elite_dual_blade_raider_elite_basic:blade_tempo_feint, enemy_elite_dual_blade_raider_elite_advanced:generic_counter_guard, enemy_elite_dual_blade_raider_elite_advanced:generic_guard, enemy_elite_dual_blade_raider_elite_advanced:generic_side_step, enemy_elite_dual_blade_raider_elite_advanced:generic_guard_split, enemy_elite_dual_blade_raider_elite_advanced:generic_posture_tap, enemy_elite_dual_blade_raider_elite_advanced:generic_tempo_shift, enemy_elite_dual_blade_raider_elite_advanced:blade_tempo_feint, enemy_elite_dual_blade_raider_elite_advanced:generic_link_cut, enemy_elite_dual_blade_raider_elite_advanced:blade_dual_cut_chain, boss_normal_boss_old_case_officer_phase_1:boss_range_check, boss_normal_boss_old_case_officer_phase_1:boss_range_check, boss_normal_boss_old_case_officer_phase_1:boss_guard_wall, boss_normal_boss_old_case_officer_phase_1:boss_phase_counter, boss_normal_boss_old_case_officer_phase_1:boss_forward_step, boss_normal_boss_old_case_officer_phase_1:boss_phase_break, boss_normal_boss_old_case_officer_phase_1:boss_tempo_surge, boss_true_boss_gatekeeper_phase_1:boss_range_check, boss_true_boss_gatekeeper_phase_1:boss_range_check, boss_true_boss_gatekeeper_phase_1:boss_guard_wall, boss_true_boss_gatekeeper_phase_1:boss_phase_counter, boss_true_boss_gatekeeper_phase_1:boss_guard_wall, boss_true_boss_gatekeeper_phase_1:boss_forward_step, boss_true_boss_gatekeeper_phase_1:boss_phase_break, boss_true_boss_gatekeeper_phase_1:boss_phase_break, boss_true_boss_gatekeeper_phase_1:generic_posture_tap, boss_true_boss_gatekeeper_phase_1:boss_tempo_surge, boss_true_boss_gatekeeper_phase_1:boss_tempo_surge, boss_true_boss_gatekeeper_phase_1:boss_punish_slice, boss_true_boss_hidden_commander_phase_1:boss_range_check, boss_true_boss_hidden_commander_phase_1:boss_range_check, boss_true_boss_hidden_commander_phase_1:boss_guard_wall, boss_true_boss_hidden_commander_phase_1:boss_phase_counter, boss_true_boss_hidden_commander_phase_1:boss_guard_wall, boss_true_boss_hidden_commander_phase_1:boss_forward_step, boss_true_boss_hidden_commander_phase_1:boss_phase_break, boss_true_boss_hidden_commander_phase_1:boss_phase_break, boss_true_boss_hidden_commander_phase_1:generic_posture_tap, boss_true_boss_hidden_commander_phase_1:boss_tempo_surge, boss_true_boss_hidden_commander_phase_1:boss_tempo_surge, boss_true_boss_hidden_commander_phase_1:generic_tempo_shift, boss_true_boss_hidden_commander_phase_2:boss_range_check, boss_true_boss_hidden_commander_phase_2:boss_range_check, boss_true_boss_hidden_commander_phase_2:boss_guard_wall, boss_true_boss_hidden_commander_phase_2:boss_phase_counter, boss_true_boss_hidden_commander_phase_2:boss_guard_wall, boss_true_boss_hidden_commander_phase_2:boss_forward_step, boss_true_boss_hidden_commander_phase_2:boss_phase_break, boss_true_boss_hidden_commander_phase_2:boss_phase_break, boss_true_boss_hidden_commander_phase_2:generic_posture_tap, boss_true_boss_hidden_commander_phase_2:generic_guard_split, boss_true_boss_hidden_commander_phase_2:boss_tempo_surge, boss_true_boss_hidden_commander_phase_2:boss_tempo_surge, boss_true_boss_hidden_commander_phase_2:generic_tempo_shift, exam_exam_imperial_final_examiner:footwork_evade_cut

## Runtime Export Readiness

- This summary does not approve runtime export.
- Runtime export still requires manual approval and runtime exporter implementation.
- Only artifacts with PASS validators should be considered for later approval.

## Next Steps

1. v0.6d content package approval / manual review
2. v0.7 runtime exporter should read manifest + report + validator summary
3. runtime exporter must not directly scan data/design/generated_*.tsv
