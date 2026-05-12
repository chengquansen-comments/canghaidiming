# AIGC Battle 审核报告：martial_realm_7_dual_weapon_v0_1 / martial_realm_7_dual_weapon_v0_1__formal_sequence_12_fast_v1__matrix_001

## 1. 包基本信息
- active: 否
- pack_storage_mode: `profile_pack_dir`
- target_sequence_id: `formal_sequence_mvp_v1`
- replacement_mode: `full_sequence`

## 2. 机制摘要
- runtime_manifest_path: `data/aigc_battle/generated/martial_realm_7_dual_weapon_v0_1/packs/martial_realm_7_dual_weapon_v0_1__formal_sequence_12_fast_v1__matrix_001/runtime_manifest.json`
- runtime primitives: dual_weapon, martial_realm_7

## 2.5 Balance Release
- balance_release: `False`
- source_pack_id: `-`
- playable_balance_gate_pass: `False`

## 3. 健康状态
- health_status: `warning`
- health_score: `13`
- ready_for_runtime_export: `True`
- full_sequence_coverage_complete: `True`
- runtime_export_allowed: `True`

## 4. 全序列节奏
- #1 `enc_beach_ambush` | early/normal | power=31.48 | reward=early | wujing=1
- #2 `enc_fishing_village_embers` | early/normal | power=29.75 | reward=early | wujing=2
- #3 `enc_transport_officer` | early/elite | power=29.75 | reward=early | wujing=2
- #4 `enc_mutiny_camp` | mid/normal | power=34.11 | reward=mid | wujing=3
- #5 `enc_wakou_boss` | mid/elite | power=45.82 | reward=mid | wujing=4
- #6 `enc_wuke_spear_trial` | mid/elite | power=45.82 | reward=mid | wujing=4
- #7 `enc_wuke_blade_trial` | late/elite | power=54.05 | reward=late | wujing=5
- #8 `enc_wuke_final_duel` | late/elite | power=52.97 | reward=late | wujing=6
- #9 `enc_wuke_gu_chengyue` | late/elite | power=56.42 | reward=late | wujing=6
- #10 `enc_wuke_shen_zhaoye` | boss/boss | power=67.31 | reward=boss | wujing=7
- #11 `enc_wuke_qi_heng` | boss/boss | power=67.31 | reward=boss | wujing=7
- #12 `enc_ch2_reed_ambush` | boss/boss | power=67.31 | reward=boss | wujing=7

## 5. 战斗列表
- `enc_beach_ambush` -> deck=`martial_realm_7_dual_weapon_v0_1_deck_001` reward=`martial_realm_7_dual_weapon_v0_1_reward_001` risk=close_to_target_power_max,realm_cap_close
- `enc_fishing_village_embers` -> deck=`martial_realm_7_dual_weapon_v0_1_deck_002` reward=`martial_realm_7_dual_weapon_v0_1_reward_002` risk=realm_cap_close
- `enc_transport_officer` -> deck=`martial_realm_7_dual_weapon_v0_1_deck_003` reward=`martial_realm_7_dual_weapon_v0_1_reward_003` risk=realm_cap_close
- `enc_mutiny_camp` -> deck=`martial_realm_7_dual_weapon_v0_1_deck_004` reward=`martial_realm_7_dual_weapon_v0_1_reward_004` risk=realm_cap_close
- `enc_wakou_boss` -> deck=`martial_realm_7_dual_weapon_v0_1_deck_005` reward=`martial_realm_7_dual_weapon_v0_1_reward_005` risk=close_to_target_power_max,realm_cap_close
- `enc_wuke_spear_trial` -> deck=`martial_realm_7_dual_weapon_v0_1_deck_006` reward=`martial_realm_7_dual_weapon_v0_1_reward_006` risk=close_to_target_power_max,realm_cap_close
- `enc_wuke_blade_trial` -> deck=`martial_realm_7_dual_weapon_v0_1_deck_007` reward=`martial_realm_7_dual_weapon_v0_1_reward_007` risk=realm_cap_close
- `enc_wuke_final_duel` -> deck=`martial_realm_7_dual_weapon_v0_1_deck_008` reward=`martial_realm_7_dual_weapon_v0_1_reward_008` risk=realm_cap_close
- `enc_wuke_gu_chengyue` -> deck=`martial_realm_7_dual_weapon_v0_1_deck_009` reward=`martial_realm_7_dual_weapon_v0_1_reward_009` risk=realm_cap_close
- `enc_wuke_shen_zhaoye` -> deck=`martial_realm_7_dual_weapon_v0_1_deck_010` reward=`martial_realm_7_dual_weapon_v0_1_reward_010` risk=close_to_target_power_max,realm_cap_close
- `enc_wuke_qi_heng` -> deck=`martial_realm_7_dual_weapon_v0_1_deck_011` reward=`martial_realm_7_dual_weapon_v0_1_reward_011` risk=close_to_target_power_max,realm_cap_close
- `enc_ch2_reed_ambush` -> deck=`martial_realm_7_dual_weapon_v0_1_deck_012` reward=`martial_realm_7_dual_weapon_v0_1_reward_012` risk=close_to_target_power_max,realm_cap_close

## 6. 单场战斗设计卡摘要
- `#1 enc_beach_ambush` | archetype=`spear_pressure` | action=`needs_balance_adjustment`
- `#2 enc_fishing_village_embers` | archetype=`boss_mixed_pressure` | action=`needs_balance_adjustment`
- `#3 enc_transport_officer` | archetype=`spear_pressure` | action=`needs_balance_adjustment`
- `#4 enc_mutiny_camp` | archetype=`spear_pressure` | action=`needs_balance_adjustment`
- `#5 enc_wakou_boss` | archetype=`spear_pressure` | action=`needs_balance_adjustment`
- `#6 enc_wuke_spear_trial` | archetype=`spear_pressure` | action=`needs_balance_adjustment`
- `#7 enc_wuke_blade_trial` | archetype=`spear_pressure` | action=`needs_balance_adjustment`
- `#8 enc_wuke_final_duel` | archetype=`spear_pressure` | action=`needs_balance_adjustment`
- `#9 enc_wuke_gu_chengyue` | archetype=`boss_mixed_pressure` | action=`needs_balance_adjustment`
- `#10 enc_wuke_shen_zhaoye` | archetype=`spear_pressure` | action=`needs_balance_adjustment`
- `#11 enc_wuke_qi_heng` | archetype=`spear_pressure` | action=`needs_balance_adjustment`
- `#12 enc_ch2_reed_ambush` | archetype=`spear_pressure` | action=`needs_balance_adjustment`

## 7. 卡池摘要
- card_count: `70`
- unused_card_count: `17`
- high_power_card_count: `18`

## 8. Deck 行为摘要
- `martial_realm_7_dual_weapon_v0_1_deck_010` | archetype=`spear_pressure` | A=63.83 D=46.78 M=28.38 B=51.52
- `martial_realm_7_dual_weapon_v0_1_deck_011` | archetype=`spear_pressure` | A=63.83 D=46.78 M=28.38 B=51.52
- `martial_realm_7_dual_weapon_v0_1_deck_012` | archetype=`spear_pressure` | A=63.83 D=46.78 M=28.38 B=51.52
- `martial_realm_7_dual_weapon_v0_1_deck_009` | archetype=`boss_mixed_pressure` | A=65.48 D=40.45 M=9.99 B=43.34
- `martial_realm_7_dual_weapon_v0_1_deck_007` | archetype=`spear_pressure` | A=67.5 D=41.8 M=6.92 B=33.64
- `martial_realm_7_dual_weapon_v0_1_deck_008` | archetype=`spear_pressure` | A=53.62 D=37.97 M=14.43 B=43.69
- `martial_realm_7_dual_weapon_v0_1_deck_005` | archetype=`spear_pressure` | A=46.58 D=30.71 M=11.97 B=28.52
- `martial_realm_7_dual_weapon_v0_1_deck_006` | archetype=`spear_pressure` | A=46.58 D=30.71 M=11.97 B=28.52
- `martial_realm_7_dual_weapon_v0_1_deck_004` | archetype=`spear_pressure` | A=34.05 D=22.41 M=6.98 B=11.55
- `martial_realm_7_dual_weapon_v0_1_deck_001` | archetype=`spear_pressure` | A=26.06 D=10.83 M=5.66 B=11.66
- `martial_realm_7_dual_weapon_v0_1_deck_002` | archetype=`boss_mixed_pressure` | A=25.59 D=10.66 M=5.33 B=11.32
- `martial_realm_7_dual_weapon_v0_1_deck_003` | archetype=`spear_pressure` | A=25.59 D=10.66 M=5.33 B=11.32

## 9. Reward 成长摘要
- `martial_realm_7_dual_weapon_v0_1_reward_001` | tier=`early` | items=basic_reward_card_001x1
- `martial_realm_7_dual_weapon_v0_1_reward_002` | tier=`early` | items=basic_reward_card_002x1
- `martial_realm_7_dual_weapon_v0_1_reward_003` | tier=`early` | items=basic_reward_card_003x1
- `martial_realm_7_dual_weapon_v0_1_reward_004` | tier=`mid` | items=basic_reward_card_004x1
- `martial_realm_7_dual_weapon_v0_1_reward_005` | tier=`mid` | items=basic_reward_card_005x1
- `martial_realm_7_dual_weapon_v0_1_reward_006` | tier=`mid` | items=basic_reward_card_006x1
- `martial_realm_7_dual_weapon_v0_1_reward_007` | tier=`late` | items=basic_reward_card_007x1
- `martial_realm_7_dual_weapon_v0_1_reward_008` | tier=`late` | items=basic_reward_card_008x1
- `martial_realm_7_dual_weapon_v0_1_reward_009` | tier=`late` | items=basic_reward_card_009x1
- `martial_realm_7_dual_weapon_v0_1_reward_010` | tier=`boss` | items=boss_reward_tokenx1, resource_meritx3
- `martial_realm_7_dual_weapon_v0_1_reward_011` | tier=`boss` | items=boss_reward_tokenx1, resource_meritx3
- `martial_realm_7_dual_weapon_v0_1_reward_012` | tier=`boss` | items=boss_reward_tokenx1, resource_meritx3

## 10. Risk Board
- risk_count: `53`
- fail_count: `0`
- warning_count: `41`
- [warning] deck power 接近 target_power_max。 | action=`needs_balance_adjustment`
- [warning] deck power 接近 target_power_max。 | action=`needs_balance_adjustment`
- [warning] deck power 接近 target_power_max。 | action=`needs_balance_adjustment`
- [warning] deck power 接近 target_power_max。 | action=`needs_balance_adjustment`
- [warning] deck power 接近 target_power_max。 | action=`needs_balance_adjustment`
- [warning] deck power 接近 target_power_max。 | action=`needs_balance_adjustment`
- [warning] 缺少审核依赖报告：telemetry_probe_report.json | action=`needs_rebuild`
- [warning] 缺少审核依赖报告：sequence_balance_snapshot.json | action=`needs_rebuild`
- [warning] 缺少审核依赖报告：runtime_primitive_probe_report.json | action=`needs_rebuild`
- [warning] 缺少审核依赖报告：rebuild_from_snapshot_probe_report.json | action=`needs_rebuild`
- [warning] 卡牌武境要求接近玩家上限。 | action=`needs_balance_adjustment`
- [warning] 卡牌武境要求接近玩家上限。 | action=`needs_balance_adjustment`

## 11. Telemetry / Snapshot 状态
- telemetry: `True`
- snapshot: `False`
- missing_reports: telemetry_probe_report.json, sequence_balance_snapshot.json, runtime_primitive_probe_report.json, rebuild_from_snapshot_probe_report.json

## 12. 建议动作
- `safe_to_test`
