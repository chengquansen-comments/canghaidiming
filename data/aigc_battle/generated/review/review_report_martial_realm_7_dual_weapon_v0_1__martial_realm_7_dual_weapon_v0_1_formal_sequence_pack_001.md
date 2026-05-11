# AIGC Battle 审核报告：martial_realm_7_dual_weapon_v0_1 / martial_realm_7_dual_weapon_v0_1_formal_sequence_pack_001

## 1. 包基本信息
- active: 否
- pack_storage_mode: `profile_root`
- target_sequence_id: `formal_sequence_mvp_v1`
- replacement_mode: `full_sequence`

## 2. 机制摘要
- runtime_manifest_path: `data/aigc_battle/generated/martial_realm_7_dual_weapon_v0_1/runtime_manifest.json`
- runtime primitives: dual_weapon, martial_realm_7

## 2.5 Balance Release
- balance_release: `False`
- source_pack_id: `-`
- playable_balance_gate_pass: `False`

## 3. 健康状态
- health_status: `warning`
- health_score: `0`
- ready_for_runtime_export: `True`
- full_sequence_coverage_complete: `True`
- runtime_export_allowed: `True`

## 4. 全序列节奏
- #1 `enc_beach_ambush` | early/normal | power=29.75 | reward=basic | wujing=2
- #2 `enc_fishing_village_embers` | early/normal | power=29.75 | reward=basic | wujing=2
- #3 `enc_transport_officer` | early/elite | power=29.75 | reward=basic | wujing=2
- #4 `enc_mutiny_camp` | early/elite | power=29.75 | reward=basic | wujing=2
- #5 `enc_wakou_boss` | boss/boss | power=67.31 | reward=boss | wujing=7
- #6 `enc_wuke_spear_trial` | mid/elite | power=45.82 | reward=standard | wujing=4
- #7 `enc_wuke_blade_trial` | mid/elite | power=43.49 | reward=standard | wujing=4
- #8 `enc_wuke_final_duel` | boss/boss | power=67.31 | reward=boss | wujing=7
- #9 `enc_wuke_gu_chengyue` | mid/elite | power=47.56 | reward=standard | wujing=4
- #10 `enc_wuke_shen_zhaoye` | mid/elite | power=45.82 | reward=standard | wujing=4
- #11 `enc_wuke_qi_heng` | late/elite | power=52.97 | reward=advanced | wujing=6
- #12 `enc_ch2_reed_ambush` | late/normal | power=56.42 | reward=advanced | wujing=6
- #13 `enc_ch3_escort_clash` | late/elite | power=52.97 | reward=advanced | wujing=6
- #14 `enc_ch4_tide_bandits` | late/normal | power=52.97 | reward=advanced | wujing=6
- #15 `enc_boss_ext_wakou_leader` | boss/boss | power=67.31 | reward=boss | wujing=7

## 5. 战斗列表
- `enc_beach_ambush` -> deck=`martial_realm_7_dual_weapon_v0_1_deck_001` reward=`martial_realm_7_dual_weapon_v0_1_reward_001` risk=realm_cap_close
- `enc_fishing_village_embers` -> deck=`martial_realm_7_dual_weapon_v0_1_deck_002` reward=`martial_realm_7_dual_weapon_v0_1_reward_002` risk=realm_cap_close
- `enc_transport_officer` -> deck=`martial_realm_7_dual_weapon_v0_1_deck_003` reward=`martial_realm_7_dual_weapon_v0_1_reward_003` risk=realm_cap_close
- `enc_mutiny_camp` -> deck=`martial_realm_7_dual_weapon_v0_1_deck_004` reward=`martial_realm_7_dual_weapon_v0_1_reward_004` risk=realm_cap_close
- `enc_wakou_boss` -> deck=`martial_realm_7_dual_weapon_v0_1_deck_005` reward=`martial_realm_7_dual_weapon_v0_1_reward_005` risk=realm_cap_close
- `enc_wuke_spear_trial` -> deck=`martial_realm_7_dual_weapon_v0_1_deck_006` reward=`martial_realm_7_dual_weapon_v0_1_reward_006` risk=realm_cap_close
- `enc_wuke_blade_trial` -> deck=`martial_realm_7_dual_weapon_v0_1_deck_007` reward=`martial_realm_7_dual_weapon_v0_1_reward_007` risk=realm_cap_close
- `enc_wuke_final_duel` -> deck=`martial_realm_7_dual_weapon_v0_1_deck_008` reward=`martial_realm_7_dual_weapon_v0_1_reward_008` risk=realm_cap_close
- `enc_wuke_gu_chengyue` -> deck=`martial_realm_7_dual_weapon_v0_1_deck_009` reward=`martial_realm_7_dual_weapon_v0_1_reward_009` risk=realm_cap_close
- `enc_wuke_shen_zhaoye` -> deck=`martial_realm_7_dual_weapon_v0_1_deck_010` reward=`martial_realm_7_dual_weapon_v0_1_reward_010` risk=realm_cap_close
- `enc_wuke_qi_heng` -> deck=`martial_realm_7_dual_weapon_v0_1_deck_011` reward=`martial_realm_7_dual_weapon_v0_1_reward_011` risk=close_to_target_power_min,realm_cap_close
- `enc_ch2_reed_ambush` -> deck=`martial_realm_7_dual_weapon_v0_1_deck_012` reward=`martial_realm_7_dual_weapon_v0_1_reward_012` risk=realm_cap_close
- `enc_ch3_escort_clash` -> deck=`martial_realm_7_dual_weapon_v0_1_deck_013` reward=`martial_realm_7_dual_weapon_v0_1_reward_013` risk=close_to_target_power_min,realm_cap_close
- `enc_ch4_tide_bandits` -> deck=`martial_realm_7_dual_weapon_v0_1_deck_014` reward=`martial_realm_7_dual_weapon_v0_1_reward_014` risk=realm_cap_close
- `enc_boss_ext_wakou_leader` -> deck=`martial_realm_7_dual_weapon_v0_1_deck_015` reward=`martial_realm_7_dual_weapon_v0_1_reward_015` risk=realm_cap_close

## 6. 单场战斗设计卡摘要
- `#1 enc_beach_ambush` | archetype=`spear_pressure` | action=`needs_balance_adjustment`
- `#2 enc_fishing_village_embers` | archetype=`boss_mixed_pressure` | action=`needs_balance_adjustment`
- `#3 enc_transport_officer` | archetype=`spear_pressure` | action=`needs_balance_adjustment`
- `#4 enc_mutiny_camp` | archetype=`boss_mixed_pressure` | action=`needs_balance_adjustment`
- `#5 enc_wakou_boss` | archetype=`spear_pressure` | action=`needs_balance_adjustment`
- `#6 enc_wuke_spear_trial` | archetype=`spear_pressure` | action=`needs_balance_adjustment`
- `#7 enc_wuke_blade_trial` | archetype=`spear_pressure` | action=`needs_balance_adjustment`
- `#8 enc_wuke_final_duel` | archetype=`spear_pressure` | action=`needs_balance_adjustment`
- `#9 enc_wuke_gu_chengyue` | archetype=`spear_pressure` | action=`needs_balance_adjustment`
- `#10 enc_wuke_shen_zhaoye` | archetype=`spear_pressure` | action=`needs_balance_adjustment`
- `#11 enc_wuke_qi_heng` | archetype=`spear_pressure` | action=`needs_balance_adjustment`
- `#12 enc_ch2_reed_ambush` | archetype=`boss_mixed_pressure` | action=`needs_balance_adjustment`
- `#13 enc_ch3_escort_clash` | archetype=`spear_pressure` | action=`needs_balance_adjustment`
- `#14 enc_ch4_tide_bandits` | archetype=`spear_pressure` | action=`needs_balance_adjustment`
- `#15 enc_boss_ext_wakou_leader` | archetype=`spear_pressure` | action=`needs_balance_adjustment`

## 7. 卡池摘要
- card_count: `70`
- unused_card_count: `23`
- high_power_card_count: `18`

## 8. Deck 行为摘要
- `martial_realm_7_dual_weapon_v0_1_deck_005` | archetype=`spear_pressure` | A=63.83 D=46.78 M=28.38 B=51.52
- `martial_realm_7_dual_weapon_v0_1_deck_008` | archetype=`spear_pressure` | A=63.83 D=46.78 M=28.38 B=51.52
- `martial_realm_7_dual_weapon_v0_1_deck_015` | archetype=`spear_pressure` | A=63.83 D=46.78 M=28.38 B=51.52
- `martial_realm_7_dual_weapon_v0_1_deck_012` | archetype=`boss_mixed_pressure` | A=65.48 D=40.45 M=9.99 B=43.34
- `martial_realm_7_dual_weapon_v0_1_deck_011` | archetype=`spear_pressure` | A=53.62 D=37.97 M=14.43 B=43.69
- `martial_realm_7_dual_weapon_v0_1_deck_013` | archetype=`spear_pressure` | A=53.62 D=37.97 M=14.43 B=43.69
- `martial_realm_7_dual_weapon_v0_1_deck_014` | archetype=`spear_pressure` | A=53.62 D=37.97 M=14.43 B=43.69
- `martial_realm_7_dual_weapon_v0_1_deck_009` | archetype=`spear_pressure` | A=55.54 D=35.74 M=10.36 B=21.52
- `martial_realm_7_dual_weapon_v0_1_deck_006` | archetype=`spear_pressure` | A=46.58 D=30.71 M=11.97 B=28.52
- `martial_realm_7_dual_weapon_v0_1_deck_010` | archetype=`spear_pressure` | A=46.58 D=30.71 M=11.97 B=28.52
- `martial_realm_7_dual_weapon_v0_1_deck_007` | archetype=`spear_pressure` | A=45.62 D=35.09 M=8.32 B=19.87
- `martial_realm_7_dual_weapon_v0_1_deck_001` | archetype=`spear_pressure` | A=25.59 D=10.66 M=5.33 B=11.32
- `martial_realm_7_dual_weapon_v0_1_deck_002` | archetype=`boss_mixed_pressure` | A=25.59 D=10.66 M=5.33 B=11.32
- `martial_realm_7_dual_weapon_v0_1_deck_003` | archetype=`spear_pressure` | A=25.59 D=10.66 M=5.33 B=11.32
- `martial_realm_7_dual_weapon_v0_1_deck_004` | archetype=`boss_mixed_pressure` | A=25.59 D=10.66 M=5.33 B=11.32

## 9. Reward 成长摘要
- `martial_realm_7_dual_weapon_v0_1_reward_001` | tier=`basic` | items=basic_reward_card_001x1
- `martial_realm_7_dual_weapon_v0_1_reward_002` | tier=`basic` | items=basic_reward_card_002x1
- `martial_realm_7_dual_weapon_v0_1_reward_003` | tier=`basic` | items=basic_reward_card_003x1
- `martial_realm_7_dual_weapon_v0_1_reward_004` | tier=`basic` | items=basic_reward_card_004x1
- `martial_realm_7_dual_weapon_v0_1_reward_006` | tier=`standard` | items=standard_reward_card_006x1, resource_meritx1
- `martial_realm_7_dual_weapon_v0_1_reward_007` | tier=`standard` | items=standard_reward_card_007x1, resource_meritx1
- `martial_realm_7_dual_weapon_v0_1_reward_009` | tier=`standard` | items=standard_reward_card_009x1, resource_meritx1
- `martial_realm_7_dual_weapon_v0_1_reward_010` | tier=`standard` | items=standard_reward_card_010x1, resource_meritx1
- `martial_realm_7_dual_weapon_v0_1_reward_011` | tier=`advanced` | items=advanced_reward_card_011x1, resource_meritx2
- `martial_realm_7_dual_weapon_v0_1_reward_012` | tier=`advanced` | items=advanced_reward_card_012x1, resource_meritx1
- `martial_realm_7_dual_weapon_v0_1_reward_013` | tier=`advanced` | items=advanced_reward_card_013x1, resource_meritx2
- `martial_realm_7_dual_weapon_v0_1_reward_014` | tier=`advanced` | items=advanced_reward_card_014x1, resource_meritx1
- `martial_realm_7_dual_weapon_v0_1_reward_005` | tier=`boss` | items=boss_reward_tokenx1, resource_meritx3
- `martial_realm_7_dual_weapon_v0_1_reward_008` | tier=`boss` | items=boss_reward_tokenx1, resource_meritx3
- `martial_realm_7_dual_weapon_v0_1_reward_015` | tier=`boss` | items=boss_reward_tokenx1, resource_meritx3

## 10. Risk Board
- risk_count: `69`
- fail_count: `0`
- warning_count: `54`
- [warning] deck power 接近 target_power_min。 | action=`needs_balance_adjustment`
- [warning] deck power 接近 target_power_min。 | action=`needs_balance_adjustment`
- [warning] 卡牌使用频次偏高，建议检查重复占用。 | action=`needs_balance_adjustment`
- [warning] 卡牌使用频次偏高，建议检查重复占用。 | action=`needs_balance_adjustment`
- [warning] 卡牌使用频次偏高，建议检查重复占用。 | action=`needs_balance_adjustment`
- [warning] 卡牌使用频次偏高，建议检查重复占用。 | action=`needs_balance_adjustment`
- [warning] 卡牌使用频次偏高，建议检查重复占用。 | action=`needs_balance_adjustment`
- [warning] 卡牌使用频次偏高，建议检查重复占用。 | action=`needs_balance_adjustment`
- [warning] 卡牌使用频次偏高，建议检查重复占用。 | action=`needs_balance_adjustment`
- [warning] 卡牌使用频次偏高，建议检查重复占用。 | action=`needs_balance_adjustment`
- [warning] 缺少审核依赖报告：telemetry_probe_report.json | action=`needs_rebuild`
- [warning] 缺少审核依赖报告：sequence_balance_snapshot.json | action=`needs_rebuild`

## 11. Telemetry / Snapshot 状态
- telemetry: `True`
- snapshot: `False`
- missing_reports: telemetry_probe_report.json, sequence_balance_snapshot.json, runtime_primitive_probe_report.json, rebuild_from_snapshot_probe_report.json

## 12. 建议动作
- `safe_to_test`
