# AIGC Battle 审核报告：weapon_followup_v0_1 / weapon_followup_v0_1__formal_sequence_12_fast_v1__baseline_001

## 1. 包基本信息
- active: 否
- pack_storage_mode: `profile_pack_dir`
- target_sequence_id: `formal_sequence_mvp_v1`
- replacement_mode: `full_sequence`

## 2. 机制摘要
- runtime_manifest_path: `data/aigc_battle/generated/weapon_followup_v0_1/packs/weapon_followup_v0_1__formal_sequence_12_fast_v1__baseline_001/runtime_manifest.json`
- runtime primitives: weapon_followup

## 2.5 Balance Release
- balance_release: `False`
- source_pack_id: `-`
- playable_balance_gate_pass: `False`

## 3. 健康状态
- health_status: `warning`
- health_score: `61`
- ready_for_runtime_export: `True`
- full_sequence_coverage_complete: `True`
- runtime_export_allowed: `True`

## 4. 全序列节奏
- #1 `enc_beach_ambush` | early/normal | power=22.8 | reward=early | wujing=1
- #2 `enc_fishing_village_embers` | early/normal | power=22.8 | reward=early | wujing=2
- #3 `enc_transport_officer` | early/elite | power=27.6 | reward=early | wujing=2
- #4 `enc_mutiny_camp` | mid/normal | power=30.0 | reward=mid | wujing=3
- #5 `enc_wakou_boss` | mid/elite | power=33.2 | reward=mid | wujing=4
- #6 `enc_wuke_spear_trial` | mid/elite | power=33.2 | reward=mid | wujing=4
- #7 `enc_wuke_blade_trial` | late/elite | power=50.8 | reward=late | wujing=5
- #8 `enc_wuke_final_duel` | late/elite | power=50.8 | reward=late | wujing=6
- #9 `enc_wuke_gu_chengyue` | late/elite | power=50.8 | reward=late | wujing=6
- #10 `enc_wuke_shen_zhaoye` | boss/boss | power=54.6 | reward=boss | wujing=7
- #11 `enc_wuke_qi_heng` | boss/boss | power=54.6 | reward=boss | wujing=7
- #12 `enc_ch2_reed_ambush` | boss/boss | power=54.6 | reward=boss | wujing=7

## 5. 战斗列表
- `enc_beach_ambush` -> deck=`weapon_followup_v0_1_deck_001` reward=`weapon_followup_v0_1_reward_001` risk=close_to_target_power_min,realm_cap_close
- `enc_fishing_village_embers` -> deck=`weapon_followup_v0_1_deck_002` reward=`weapon_followup_v0_1_reward_002` risk=close_to_target_power_min
- `enc_transport_officer` -> deck=`weapon_followup_v0_1_deck_003` reward=`weapon_followup_v0_1_reward_003` risk=close_to_target_power_max
- `enc_mutiny_camp` -> deck=`weapon_followup_v0_1_deck_004` reward=`weapon_followup_v0_1_reward_004` risk=close_to_target_power_min
- `enc_wakou_boss` -> deck=`weapon_followup_v0_1_deck_005` reward=`weapon_followup_v0_1_reward_005` risk=close_to_target_power_max
- `enc_wuke_spear_trial` -> deck=`weapon_followup_v0_1_deck_006` reward=`weapon_followup_v0_1_reward_006` risk=close_to_target_power_max
- `enc_wuke_blade_trial` -> deck=`weapon_followup_v0_1_deck_007` reward=`weapon_followup_v0_1_reward_007` risk=-
- `enc_wuke_final_duel` -> deck=`weapon_followup_v0_1_deck_008` reward=`weapon_followup_v0_1_reward_008` risk=-
- `enc_wuke_gu_chengyue` -> deck=`weapon_followup_v0_1_deck_009` reward=`weapon_followup_v0_1_reward_009` risk=-
- `enc_wuke_shen_zhaoye` -> deck=`weapon_followup_v0_1_deck_010` reward=`weapon_followup_v0_1_reward_010` risk=close_to_target_power_min
- `enc_wuke_qi_heng` -> deck=`weapon_followup_v0_1_deck_011` reward=`weapon_followup_v0_1_reward_011` risk=close_to_target_power_min
- `enc_ch2_reed_ambush` -> deck=`weapon_followup_v0_1_deck_012` reward=`weapon_followup_v0_1_reward_012` risk=close_to_target_power_min

## 6. 单场战斗设计卡摘要
- `#1 enc_beach_ambush` | archetype=`spear_pressure` | action=`needs_balance_adjustment`
- `#2 enc_fishing_village_embers` | archetype=`generic_mixed` | action=`needs_balance_adjustment`
- `#3 enc_transport_officer` | archetype=`boss_mixed_pressure` | action=`needs_balance_adjustment`
- `#4 enc_mutiny_camp` | archetype=`spear_pressure` | action=`needs_balance_adjustment`
- `#5 enc_wakou_boss` | archetype=`boss_mixed_pressure` | action=`needs_balance_adjustment`
- `#6 enc_wuke_spear_trial` | archetype=`spear_pressure` | action=`needs_balance_adjustment`
- `#7 enc_wuke_blade_trial` | archetype=`boss_mixed_pressure` | action=`ready_for_review`
- `#8 enc_wuke_final_duel` | archetype=`boss_mixed_pressure` | action=`ready_for_review`
- `#9 enc_wuke_gu_chengyue` | archetype=`spear_pressure` | action=`ready_for_review`
- `#10 enc_wuke_shen_zhaoye` | archetype=`boss_mixed_pressure` | action=`needs_balance_adjustment`
- `#11 enc_wuke_qi_heng` | archetype=`spear_pressure` | action=`needs_balance_adjustment`
- `#12 enc_ch2_reed_ambush` | archetype=`spear_pressure` | action=`needs_balance_adjustment`

## 7. 卡池摘要
- card_count: `40`
- unused_card_count: `1`
- high_power_card_count: `10`

## 8. Deck 行为摘要
- `weapon_followup_v0_1_deck_010` | archetype=`boss_mixed_pressure` | A=42.64 D=9.8 M=11.8 B=16.0
- `weapon_followup_v0_1_deck_011` | archetype=`spear_pressure` | A=42.64 D=9.8 M=11.8 B=16.0
- `weapon_followup_v0_1_deck_012` | archetype=`spear_pressure` | A=42.64 D=9.8 M=11.8 B=16.0
- `weapon_followup_v0_1_deck_007` | archetype=`boss_mixed_pressure` | A=40.48 D=8.4 M=3.0 B=21.6
- `weapon_followup_v0_1_deck_008` | archetype=`boss_mixed_pressure` | A=40.48 D=8.4 M=3.0 B=21.6
- `weapon_followup_v0_1_deck_009` | archetype=`spear_pressure` | A=40.48 D=8.4 M=3.0 B=21.6
- `weapon_followup_v0_1_deck_005` | archetype=`boss_mixed_pressure` | A=24.76 D=7.0 M=6.7 B=11.7
- `weapon_followup_v0_1_deck_006` | archetype=`spear_pressure` | A=24.76 D=7.0 M=6.7 B=11.7
- `weapon_followup_v0_1_deck_004` | archetype=`spear_pressure` | A=24.76 D=7.0 M=6.7 B=7.7
- `weapon_followup_v0_1_deck_003` | archetype=`boss_mixed_pressure` | A=20.56 D=5.6 M=6.2 B=9.2
- `weapon_followup_v0_1_deck_001` | archetype=`spear_pressure` | A=14.0 D=11.2 M=3.0 B=3.0
- `weapon_followup_v0_1_deck_002` | archetype=`generic_mixed` | A=14.0 D=11.2 M=3.0 B=3.0

## 9. Reward 成长摘要
- `weapon_followup_v0_1_reward_001` | tier=`early` | items=basic_reward_card_001x1
- `weapon_followup_v0_1_reward_002` | tier=`early` | items=basic_reward_card_002x1
- `weapon_followup_v0_1_reward_003` | tier=`early` | items=basic_reward_card_003x1
- `weapon_followup_v0_1_reward_004` | tier=`mid` | items=basic_reward_card_004x1
- `weapon_followup_v0_1_reward_005` | tier=`mid` | items=basic_reward_card_005x1
- `weapon_followup_v0_1_reward_006` | tier=`mid` | items=basic_reward_card_006x1
- `weapon_followup_v0_1_reward_007` | tier=`late` | items=basic_reward_card_007x1
- `weapon_followup_v0_1_reward_008` | tier=`late` | items=basic_reward_card_008x1
- `weapon_followup_v0_1_reward_009` | tier=`late` | items=basic_reward_card_009x1
- `weapon_followup_v0_1_reward_010` | tier=`boss` | items=boss_reward_tokenx1, resource_meritx3
- `weapon_followup_v0_1_reward_011` | tier=`boss` | items=boss_reward_tokenx1, resource_meritx3
- `weapon_followup_v0_1_reward_012` | tier=`boss` | items=boss_reward_tokenx1, resource_meritx3

## 10. Risk Board
- risk_count: `29`
- fail_count: `0`
- warning_count: `17`
- [warning] deck power 接近 target_power_max。 | action=`needs_balance_adjustment`
- [warning] deck power 接近 target_power_max。 | action=`needs_balance_adjustment`
- [warning] deck power 接近 target_power_max。 | action=`needs_balance_adjustment`
- [warning] deck power 接近 target_power_min。 | action=`needs_balance_adjustment`
- [warning] deck power 接近 target_power_min。 | action=`needs_balance_adjustment`
- [warning] deck power 接近 target_power_min。 | action=`needs_balance_adjustment`
- [warning] deck power 接近 target_power_min。 | action=`needs_balance_adjustment`
- [warning] deck power 接近 target_power_min。 | action=`needs_balance_adjustment`
- [warning] deck power 接近 target_power_min。 | action=`needs_balance_adjustment`
- [warning] 缺少审核依赖报告：telemetry_probe_report.json | action=`needs_rebuild`
- [warning] 缺少审核依赖报告：sequence_balance_snapshot.json | action=`needs_rebuild`
- [warning] 缺少审核依赖报告：runtime_primitive_probe_report.json | action=`needs_rebuild`

## 11. Telemetry / Snapshot 状态
- telemetry: `True`
- snapshot: `False`
- missing_reports: telemetry_probe_report.json, sequence_balance_snapshot.json, runtime_primitive_probe_report.json, rebuild_from_snapshot_probe_report.json

## 12. 建议动作
- `safe_to_test`
