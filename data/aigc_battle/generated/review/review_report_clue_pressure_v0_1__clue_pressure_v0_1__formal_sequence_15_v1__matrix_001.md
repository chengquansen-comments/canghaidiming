# AIGC Battle 审核报告：clue_pressure_v0_1 / clue_pressure_v0_1__formal_sequence_15_v1__matrix_001

## 1. 包基本信息
- active: 否
- pack_storage_mode: `profile_pack_dir`
- target_sequence_id: `formal_sequence_mvp_v1`
- replacement_mode: `full_sequence`

## 2. 机制摘要
- runtime_manifest_path: `data/aigc_battle/generated/clue_pressure_v0_1/packs/clue_pressure_v0_1__formal_sequence_15_v1__matrix_001/runtime_manifest.json`
- runtime primitives: clue_pressure

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
- #1 `enc_beach_ambush` | early/normal | power=22.8 | reward=early | wujing=1
- #2 `enc_fishing_village_embers` | early/normal | power=22.8 | reward=early | wujing=1
- #3 `enc_transport_officer` | early/normal | power=22.8 | reward=early | wujing=2
- #4 `enc_mutiny_camp` | early/elite | power=27.6 | reward=early | wujing=2
- #5 `enc_wakou_boss` | mid/normal | power=30.0 | reward=mid | wujing=3
- #6 `enc_wuke_spear_trial` | mid/normal | power=30.0 | reward=mid | wujing=3
- #7 `enc_wuke_blade_trial` | mid/elite | power=33.2 | reward=mid | wujing=4
- #8 `enc_wuke_final_duel` | mid/elite | power=33.2 | reward=mid | wujing=4
- #9 `enc_wuke_gu_chengyue` | late/elite | power=49.2 | reward=late | wujing=5
- #10 `enc_wuke_shen_zhaoye` | late/elite | power=49.2 | reward=late | wujing=5
- #11 `enc_wuke_qi_heng` | late/elite | power=49.2 | reward=late | wujing=6
- #12 `enc_ch2_reed_ambush` | late/boss | power=43.2 | reward=late | wujing=6
- #13 `enc_ch3_escort_clash` | boss/boss | power=53.8 | reward=boss | wujing=7
- #14 `enc_ch4_tide_bandits` | boss/boss | power=53.8 | reward=boss | wujing=7
- #15 `enc_boss_ext_wakou_leader` | boss/boss | power=53.8 | reward=boss | wujing=7

## 5. 战斗列表
- `enc_beach_ambush` -> deck=`clue_pressure_v0_1_deck_001` reward=`clue_pressure_v0_1_reward_001` risk=realm_cap_close
- `enc_fishing_village_embers` -> deck=`clue_pressure_v0_1_deck_002` reward=`clue_pressure_v0_1_reward_002` risk=realm_cap_close
- `enc_transport_officer` -> deck=`clue_pressure_v0_1_deck_003` reward=`clue_pressure_v0_1_reward_003` risk=-
- `enc_mutiny_camp` -> deck=`clue_pressure_v0_1_deck_004` reward=`clue_pressure_v0_1_reward_004` risk=close_to_target_power_max
- `enc_wakou_boss` -> deck=`clue_pressure_v0_1_deck_005` reward=`clue_pressure_v0_1_reward_005` risk=-
- `enc_wuke_spear_trial` -> deck=`clue_pressure_v0_1_deck_006` reward=`clue_pressure_v0_1_reward_006` risk=-
- `enc_wuke_blade_trial` -> deck=`clue_pressure_v0_1_deck_007` reward=`clue_pressure_v0_1_reward_007` risk=-
- `enc_wuke_final_duel` -> deck=`clue_pressure_v0_1_deck_008` reward=`clue_pressure_v0_1_reward_008` risk=-
- `enc_wuke_gu_chengyue` -> deck=`clue_pressure_v0_1_deck_009` reward=`clue_pressure_v0_1_reward_009` risk=close_to_target_power_max
- `enc_wuke_shen_zhaoye` -> deck=`clue_pressure_v0_1_deck_010` reward=`clue_pressure_v0_1_reward_010` risk=close_to_target_power_max
- `enc_wuke_qi_heng` -> deck=`clue_pressure_v0_1_deck_011` reward=`clue_pressure_v0_1_reward_011` risk=close_to_target_power_max
- `enc_ch2_reed_ambush` -> deck=`clue_pressure_v0_1_deck_012` reward=`clue_pressure_v0_1_reward_012` risk=-
- `enc_ch3_escort_clash` -> deck=`clue_pressure_v0_1_deck_013` reward=`clue_pressure_v0_1_reward_013` risk=-
- `enc_ch4_tide_bandits` -> deck=`clue_pressure_v0_1_deck_014` reward=`clue_pressure_v0_1_reward_014` risk=-
- `enc_boss_ext_wakou_leader` -> deck=`clue_pressure_v0_1_deck_015` reward=`clue_pressure_v0_1_reward_015` risk=-

## 6. 单场战斗设计卡摘要
- `#1 enc_beach_ambush` | archetype=`spear_pressure` | action=`needs_balance_adjustment`
- `#2 enc_fishing_village_embers` | archetype=`generic_mixed` | action=`needs_balance_adjustment`
- `#3 enc_transport_officer` | archetype=`generic_mixed` | action=`ready_for_review`
- `#4 enc_mutiny_camp` | archetype=`spear_pressure` | action=`needs_balance_adjustment`
- `#5 enc_wakou_boss` | archetype=`boss_mixed_pressure` | action=`ready_for_review`
- `#6 enc_wuke_spear_trial` | archetype=`spear_pressure` | action=`ready_for_review`
- `#7 enc_wuke_blade_trial` | archetype=`boss_mixed_pressure` | action=`ready_for_review`
- `#8 enc_wuke_final_duel` | archetype=`spear_pressure` | action=`ready_for_review`
- `#9 enc_wuke_gu_chengyue` | archetype=`spear_pressure` | action=`needs_balance_adjustment`
- `#10 enc_wuke_shen_zhaoye` | archetype=`boss_mixed_pressure` | action=`needs_balance_adjustment`
- `#11 enc_wuke_qi_heng` | archetype=`spear_pressure` | action=`needs_balance_adjustment`
- `#12 enc_ch2_reed_ambush` | archetype=`spear_pressure` | action=`ready_for_review`
- `#13 enc_ch3_escort_clash` | archetype=`boss_mixed_pressure` | action=`ready_for_review`
- `#14 enc_ch4_tide_bandits` | archetype=`boss_mixed_pressure` | action=`ready_for_review`
- `#15 enc_boss_ext_wakou_leader` | archetype=`boss_mixed_pressure` | action=`ready_for_review`

## 7. 卡池摘要
- card_count: `80`
- unused_card_count: `46`
- high_power_card_count: `20`

## 8. Deck 行为摘要
- `clue_pressure_v0_1_deck_013` | archetype=`boss_mixed_pressure` | A=32.52 D=19.6 M=7.9 B=16.0
- `clue_pressure_v0_1_deck_014` | archetype=`boss_mixed_pressure` | A=32.52 D=19.6 M=7.9 B=16.0
- `clue_pressure_v0_1_deck_015` | archetype=`boss_mixed_pressure` | A=32.52 D=19.6 M=7.9 B=16.0
- `clue_pressure_v0_1_deck_009` | archetype=`spear_pressure` | A=31.44 D=16.8 M=3.0 B=17.8
- `clue_pressure_v0_1_deck_010` | archetype=`boss_mixed_pressure` | A=31.44 D=16.8 M=3.0 B=17.8
- `clue_pressure_v0_1_deck_011` | archetype=`spear_pressure` | A=31.44 D=16.8 M=3.0 B=17.8
- `clue_pressure_v0_1_deck_012` | archetype=`spear_pressure` | A=31.44 D=8.4 M=3.0 B=17.8
- `clue_pressure_v0_1_deck_007` | archetype=`boss_mixed_pressure` | A=24.76 D=7.0 M=6.7 B=11.7
- `clue_pressure_v0_1_deck_008` | archetype=`spear_pressure` | A=24.76 D=7.0 M=6.7 B=11.7
- `clue_pressure_v0_1_deck_005` | archetype=`boss_mixed_pressure` | A=24.76 D=7.0 M=6.7 B=7.7
- `clue_pressure_v0_1_deck_006` | archetype=`spear_pressure` | A=24.76 D=7.0 M=6.7 B=7.7
- `clue_pressure_v0_1_deck_004` | archetype=`spear_pressure` | A=20.56 D=5.6 M=6.2 B=9.2
- `clue_pressure_v0_1_deck_001` | archetype=`spear_pressure` | A=14.0 D=11.2 M=3.0 B=3.0
- `clue_pressure_v0_1_deck_002` | archetype=`generic_mixed` | A=14.0 D=11.2 M=3.0 B=3.0
- `clue_pressure_v0_1_deck_003` | archetype=`generic_mixed` | A=14.0 D=11.2 M=3.0 B=3.0

## 9. Reward 成长摘要
- `clue_pressure_v0_1_reward_001` | tier=`early` | items=basic_reward_card_001x1
- `clue_pressure_v0_1_reward_002` | tier=`early` | items=basic_reward_card_002x1
- `clue_pressure_v0_1_reward_003` | tier=`early` | items=basic_reward_card_003x1
- `clue_pressure_v0_1_reward_004` | tier=`early` | items=basic_reward_card_004x1
- `clue_pressure_v0_1_reward_005` | tier=`mid` | items=basic_reward_card_005x1
- `clue_pressure_v0_1_reward_006` | tier=`mid` | items=basic_reward_card_006x1
- `clue_pressure_v0_1_reward_007` | tier=`mid` | items=basic_reward_card_007x1
- `clue_pressure_v0_1_reward_008` | tier=`mid` | items=basic_reward_card_008x1
- `clue_pressure_v0_1_reward_009` | tier=`late` | items=basic_reward_card_009x1
- `clue_pressure_v0_1_reward_010` | tier=`late` | items=basic_reward_card_010x1
- `clue_pressure_v0_1_reward_011` | tier=`late` | items=basic_reward_card_011x1
- `clue_pressure_v0_1_reward_012` | tier=`late` | items=basic_reward_card_012x1
- `clue_pressure_v0_1_reward_013` | tier=`boss` | items=boss_reward_tokenx1, resource_meritx3
- `clue_pressure_v0_1_reward_014` | tier=`boss` | items=boss_reward_tokenx1, resource_meritx3
- `clue_pressure_v0_1_reward_015` | tier=`boss` | items=boss_reward_tokenx1, resource_meritx3

## 10. Risk Board
- risk_count: `73`
- fail_count: `0`
- warning_count: `58`
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
- [warning] 缺少 snapshot 明细。 | action=`needs_real_telemetry`
- [warning] 卡牌未进入任何 deck。 | action=`needs_balance_adjustment`

## 11. Telemetry / Snapshot 状态
- telemetry: `True`
- snapshot: `False`
- missing_reports: telemetry_probe_report.json, sequence_balance_snapshot.json, runtime_primitive_probe_report.json, rebuild_from_snapshot_probe_report.json

## 12. 建议动作
- `safe_to_test`
