# AIGC Battle 审核报告：posture_tuned_v0_1b / posture_tuned_v0_1b_formal_sequence_pack_001

## 1. 包基本信息
- active: 否
- pack_storage_mode: `profile_root`
- target_sequence_id: `formal_sequence_mvp_v1`
- replacement_mode: `full_sequence`

## 2. 机制摘要
- runtime_manifest_path: `data/aigc_battle/generated/posture_tuned_v0_1b/runtime_manifest.json`
- runtime primitives: -

## 3. 健康状态
- health_status: `warning`
- health_score: `21`
- ready_for_runtime_export: `True`
- full_sequence_coverage_complete: `True`
- runtime_export_allowed: `True`

## 4. 全序列节奏
- #1 `enc_beach_ambush` | early/normal | power=23.5 | reward=basic | wujing=1
- #2 `enc_fishing_village_embers` | early/normal | power=23.5 | reward=basic | wujing=1
- #3 `enc_transport_officer` | early/elite | power=29.5 | reward=basic | wujing=1
- #4 `enc_mutiny_camp` | early/elite | power=29.5 | reward=basic | wujing=1
- #5 `enc_wakou_boss` | boss/boss | power=56.9 | reward=boss | wujing=4
- #6 `enc_wuke_spear_trial` | mid/elite | power=35.5 | reward=standard_plus | wujing=2
- #7 `enc_wuke_blade_trial` | mid/elite | power=35.5 | reward=standard_plus | wujing=2
- #8 `enc_wuke_final_duel` | boss/boss | power=56.9 | reward=boss | wujing=4
- #9 `enc_wuke_gu_chengyue` | mid/elite | power=35.5 | reward=standard_plus | wujing=2
- #10 `enc_wuke_shen_zhaoye` | mid/elite | power=35.5 | reward=standard_plus | wujing=2
- #11 `enc_wuke_qi_heng` | late/elite | power=52.25 | reward=advanced_plus | wujing=3
- #12 `enc_ch2_reed_ambush` | late/normal | power=46.55 | reward=advanced_plus | wujing=3
- #13 `enc_ch3_escort_clash` | late/elite | power=52.25 | reward=advanced_plus | wujing=3
- #14 `enc_ch4_tide_bandits` | late/normal | power=46.55 | reward=advanced_plus | wujing=3
- #15 `enc_boss_ext_wakou_leader` | boss/boss | power=56.9 | reward=boss | wujing=4

## 5. 战斗列表
- `enc_beach_ambush` -> deck=`posture_tuned_v0_1b_deck_001` reward=`posture_tuned_v0_1b_reward_001` risk=realm_cap_close
- `enc_fishing_village_embers` -> deck=`posture_tuned_v0_1b_deck_002` reward=`posture_tuned_v0_1b_reward_002` risk=realm_cap_close
- `enc_transport_officer` -> deck=`posture_tuned_v0_1b_deck_003` reward=`posture_tuned_v0_1b_reward_003` risk=realm_cap_close
- `enc_mutiny_camp` -> deck=`posture_tuned_v0_1b_deck_004` reward=`posture_tuned_v0_1b_reward_004` risk=realm_cap_close
- `enc_wakou_boss` -> deck=`posture_tuned_v0_1b_deck_005` reward=`posture_tuned_v0_1b_reward_005` risk=close_to_target_power_min,realm_cap_close
- `enc_wuke_spear_trial` -> deck=`posture_tuned_v0_1b_deck_006` reward=`posture_tuned_v0_1b_reward_006` risk=close_to_target_power_min,realm_cap_close
- `enc_wuke_blade_trial` -> deck=`posture_tuned_v0_1b_deck_007` reward=`posture_tuned_v0_1b_reward_007` risk=close_to_target_power_min,realm_cap_close
- `enc_wuke_final_duel` -> deck=`posture_tuned_v0_1b_deck_008` reward=`posture_tuned_v0_1b_reward_008` risk=close_to_target_power_min,realm_cap_close
- `enc_wuke_gu_chengyue` -> deck=`posture_tuned_v0_1b_deck_009` reward=`posture_tuned_v0_1b_reward_009` risk=close_to_target_power_min,realm_cap_close
- `enc_wuke_shen_zhaoye` -> deck=`posture_tuned_v0_1b_deck_010` reward=`posture_tuned_v0_1b_reward_010` risk=close_to_target_power_min,realm_cap_close
- `enc_wuke_qi_heng` -> deck=`posture_tuned_v0_1b_deck_011` reward=`posture_tuned_v0_1b_reward_011` risk=realm_cap_close
- `enc_ch2_reed_ambush` -> deck=`posture_tuned_v0_1b_deck_012` reward=`posture_tuned_v0_1b_reward_012` risk=realm_cap_close
- `enc_ch3_escort_clash` -> deck=`posture_tuned_v0_1b_deck_013` reward=`posture_tuned_v0_1b_reward_013` risk=realm_cap_close
- `enc_ch4_tide_bandits` -> deck=`posture_tuned_v0_1b_deck_014` reward=`posture_tuned_v0_1b_reward_014` risk=realm_cap_close
- `enc_boss_ext_wakou_leader` -> deck=`posture_tuned_v0_1b_deck_015` reward=`posture_tuned_v0_1b_reward_015` risk=close_to_target_power_min,realm_cap_close

## 6. 单场战斗设计卡摘要
- `#1 enc_beach_ambush` | archetype=`spear_pressure` | action=`needs_balance_adjustment`
- `#2 enc_fishing_village_embers` | archetype=`spear_pressure` | action=`needs_balance_adjustment`
- `#3 enc_transport_officer` | archetype=`boss_mixed_pressure` | action=`needs_balance_adjustment`
- `#4 enc_mutiny_camp` | archetype=`spear_pressure` | action=`needs_balance_adjustment`
- `#5 enc_wakou_boss` | archetype=`boss_mixed_pressure` | action=`needs_balance_adjustment`
- `#6 enc_wuke_spear_trial` | archetype=`spear_pressure` | action=`needs_balance_adjustment`
- `#7 enc_wuke_blade_trial` | archetype=`boss_mixed_pressure` | action=`needs_balance_adjustment`
- `#8 enc_wuke_final_duel` | archetype=`boss_mixed_pressure` | action=`needs_balance_adjustment`
- `#9 enc_wuke_gu_chengyue` | archetype=`spear_pressure` | action=`needs_balance_adjustment`
- `#10 enc_wuke_shen_zhaoye` | archetype=`boss_mixed_pressure` | action=`needs_balance_adjustment`
- `#11 enc_wuke_qi_heng` | archetype=`boss_mixed_pressure` | action=`needs_balance_adjustment`
- `#12 enc_ch2_reed_ambush` | archetype=`spear_pressure` | action=`needs_balance_adjustment`
- `#13 enc_ch3_escort_clash` | archetype=`boss_mixed_pressure` | action=`needs_balance_adjustment`
- `#14 enc_ch4_tide_bandits` | archetype=`boss_mixed_pressure` | action=`needs_balance_adjustment`
- `#15 enc_boss_ext_wakou_leader` | archetype=`boss_mixed_pressure` | action=`needs_balance_adjustment`

## 7. 卡池摘要
- card_count: `40`
- unused_card_count: `5`
- high_power_card_count: `10`

## 8. Deck 行为摘要
- `posture_tuned_v0_1b_deck_005` | archetype=`boss_mixed_pressure` | A=33.0 D=19.32 M=8.1 B=16.0
- `posture_tuned_v0_1b_deck_008` | archetype=`boss_mixed_pressure` | A=33.0 D=19.32 M=8.1 B=16.0
- `posture_tuned_v0_1b_deck_015` | archetype=`boss_mixed_pressure` | A=33.0 D=19.32 M=8.1 B=16.0
- `posture_tuned_v0_1b_deck_011` | archetype=`boss_mixed_pressure` | A=32.0 D=16.56 M=3.0 B=18.1
- `posture_tuned_v0_1b_deck_013` | archetype=`boss_mixed_pressure` | A=32.0 D=16.56 M=3.0 B=18.1
- `posture_tuned_v0_1b_deck_012` | archetype=`spear_pressure` | A=32.0 D=8.28 M=3.0 B=18.1
- `posture_tuned_v0_1b_deck_014` | archetype=`boss_mixed_pressure` | A=32.0 D=8.28 M=3.0 B=18.1
- `posture_tuned_v0_1b_deck_006` | archetype=`spear_pressure` | A=25.24 D=6.9 M=7.0 B=12.0
- `posture_tuned_v0_1b_deck_007` | archetype=`boss_mixed_pressure` | A=25.24 D=6.9 M=7.0 B=12.0
- `posture_tuned_v0_1b_deck_009` | archetype=`spear_pressure` | A=25.24 D=6.9 M=7.0 B=12.0
- `posture_tuned_v0_1b_deck_010` | archetype=`boss_mixed_pressure` | A=25.24 D=6.9 M=7.0 B=12.0
- `posture_tuned_v0_1b_deck_003` | archetype=`boss_mixed_pressure` | A=20.98 D=5.52 M=6.47 B=9.47
- `posture_tuned_v0_1b_deck_004` | archetype=`spear_pressure` | A=20.98 D=5.52 M=6.47 B=9.47
- `posture_tuned_v0_1b_deck_001` | archetype=`spear_pressure` | A=14.2 D=11.04 M=3.0 B=3.0
- `posture_tuned_v0_1b_deck_002` | archetype=`spear_pressure` | A=14.2 D=11.04 M=3.0 B=3.0

## 9. Reward 成长摘要
- `posture_tuned_v0_1b_reward_001` | tier=`basic` | items=basic_reward_card_001x1
- `posture_tuned_v0_1b_reward_002` | tier=`basic` | items=basic_reward_card_002x1
- `posture_tuned_v0_1b_reward_003` | tier=`basic` | items=basic_reward_card_003x1
- `posture_tuned_v0_1b_reward_004` | tier=`basic` | items=basic_reward_card_004x1
- `posture_tuned_v0_1b_reward_006` | tier=`standard_plus` | items=standard_reward_card_006x1, resource_meritx2
- `posture_tuned_v0_1b_reward_007` | tier=`standard_plus` | items=standard_reward_card_007x1, resource_meritx2
- `posture_tuned_v0_1b_reward_009` | tier=`standard_plus` | items=standard_reward_card_009x1, resource_meritx2
- `posture_tuned_v0_1b_reward_010` | tier=`standard_plus` | items=standard_reward_card_010x1, resource_meritx2
- `posture_tuned_v0_1b_reward_011` | tier=`advanced_plus` | items=advanced_reward_card_011x1, resource_meritx2
- `posture_tuned_v0_1b_reward_012` | tier=`advanced_plus` | items=advanced_reward_card_012x1, resource_meritx1
- `posture_tuned_v0_1b_reward_013` | tier=`advanced_plus` | items=advanced_reward_card_013x1, resource_meritx2
- `posture_tuned_v0_1b_reward_014` | tier=`advanced_plus` | items=advanced_reward_card_014x1, resource_meritx1
- `posture_tuned_v0_1b_reward_005` | tier=`boss` | items=boss_reward_tokenx1, resource_meritx3
- `posture_tuned_v0_1b_reward_008` | tier=`boss` | items=boss_reward_tokenx1, resource_meritx3
- `posture_tuned_v0_1b_reward_015` | tier=`boss` | items=boss_reward_tokenx1, resource_meritx3

## 10. Risk Board
- risk_count: `37`
- fail_count: `0`
- warning_count: `37`
- [warning] deck power 接近 target_power_min。 | action=`needs_balance_adjustment`
- [warning] deck power 接近 target_power_min。 | action=`needs_balance_adjustment`
- [warning] deck power 接近 target_power_min。 | action=`needs_balance_adjustment`
- [warning] deck power 接近 target_power_min。 | action=`needs_balance_adjustment`
- [warning] deck power 接近 target_power_min。 | action=`needs_balance_adjustment`
- [warning] deck power 接近 target_power_min。 | action=`needs_balance_adjustment`
- [warning] deck power 接近 target_power_min。 | action=`needs_balance_adjustment`
- [warning] 缺少审核依赖报告：telemetry_probe_report.json | action=`needs_rebuild`
- [warning] 缺少审核依赖报告：sequence_balance_snapshot.json | action=`needs_rebuild`
- [warning] 缺少审核依赖报告：runtime_primitive_probe_report.json | action=`needs_rebuild`
- [warning] 缺少审核依赖报告：rebuild_from_snapshot_probe_report.json | action=`needs_rebuild`
- [warning] 卡牌武境要求接近玩家上限。 | action=`needs_balance_adjustment`

## 11. Telemetry / Snapshot 状态
- telemetry: `True`
- snapshot: `False`
- missing_reports: telemetry_probe_report.json, sequence_balance_snapshot.json, runtime_primitive_probe_report.json, rebuild_from_snapshot_probe_report.json

## 12. 建议动作
- `safe_to_test`
