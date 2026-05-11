# AIGC Battle 审核报告：weapon_followup_v0_1 / weapon_followup_ai_candidate_pack_001

## 1. 包基本信息
- active: 否
- pack_storage_mode: `profile_pack_dir`
- target_sequence_id: `formal_sequence_mvp_v1`
- replacement_mode: `full_sequence`

## 2. 机制摘要
- runtime_manifest_path: `data/aigc_battle/generated/weapon_followup_v0_1/packs/weapon_followup_ai_candidate_pack_001/runtime_manifest.json`
- runtime primitives: weapon_followup

## 2.5 Balance Release
- balance_release: `False`
- source_pack_id: `-`
- playable_balance_gate_pass: `False`

## 3. 健康状态
- health_status: `fail`
- health_score: `39`
- ready_for_runtime_export: `True`
- full_sequence_coverage_complete: `True`
- runtime_export_allowed: `True`

## 4. 全序列节奏
- #1 `enc_beach_ambush` | early/normal | power=25.2 | reward=basic | wujing=1
- #2 `enc_fishing_village_embers` | early/normal | power=22.8 | reward=basic | wujing=1
- #3 `enc_transport_officer` | early/elite | power=27.6 | reward=basic | wujing=1
- #4 `enc_mutiny_camp` | early/elite | power=27.6 | reward=basic | wujing=1
- #5 `enc_wakou_boss` | boss/boss | power=54.6 | reward=boss | wujing=4
- #6 `enc_wuke_spear_trial` | mid/elite | power=33.2 | reward=standard | wujing=2
- #7 `enc_wuke_blade_trial` | mid/elite | power=33.2 | reward=standard | wujing=2
- #8 `enc_wuke_final_duel` | boss/boss | power=54.6 | reward=boss | wujing=4
- #9 `enc_wuke_gu_chengyue` | mid/elite | power=33.2 | reward=standard | wujing=2
- #10 `enc_wuke_shen_zhaoye` | mid/elite | power=33.2 | reward=standard | wujing=2
- #11 `enc_wuke_qi_heng` | late/elite | power=50.8 | reward=advanced | wujing=3
- #12 `enc_ch2_reed_ambush` | late/normal | power=43.2 | reward=advanced | wujing=3
- #13 `enc_ch3_escort_clash` | late/elite | power=50.8 | reward=advanced | wujing=3
- #14 `enc_ch4_tide_bandits` | late/normal | power=43.2 | reward=advanced | wujing=3
- #15 `enc_boss_ext_wakou_leader` | boss/boss | power=54.6 | reward=boss | wujing=4

## 5. 战斗列表
- `enc_beach_ambush` -> deck=`weapon_followup_v0_1_deck_001` reward=`weapon_followup_v0_1_reward_001` risk=realm_invalid,realm_cap_close
- `enc_fishing_village_embers` -> deck=`weapon_followup_v0_1_deck_002` reward=`weapon_followup_v0_1_reward_002` risk=realm_cap_close
- `enc_transport_officer` -> deck=`weapon_followup_v0_1_deck_003` reward=`weapon_followup_v0_1_reward_003` risk=realm_cap_close
- `enc_mutiny_camp` -> deck=`weapon_followup_v0_1_deck_004` reward=`weapon_followup_v0_1_reward_004` risk=realm_cap_close
- `enc_wakou_boss` -> deck=`weapon_followup_v0_1_deck_005` reward=`weapon_followup_v0_1_reward_005` risk=realm_cap_close
- `enc_wuke_spear_trial` -> deck=`weapon_followup_v0_1_deck_006` reward=`weapon_followup_v0_1_reward_006` risk=realm_cap_close
- `enc_wuke_blade_trial` -> deck=`weapon_followup_v0_1_deck_007` reward=`weapon_followup_v0_1_reward_007` risk=realm_cap_close
- `enc_wuke_final_duel` -> deck=`weapon_followup_v0_1_deck_008` reward=`weapon_followup_v0_1_reward_008` risk=realm_cap_close
- `enc_wuke_gu_chengyue` -> deck=`weapon_followup_v0_1_deck_009` reward=`weapon_followup_v0_1_reward_009` risk=realm_cap_close
- `enc_wuke_shen_zhaoye` -> deck=`weapon_followup_v0_1_deck_010` reward=`weapon_followup_v0_1_reward_010` risk=realm_cap_close
- `enc_wuke_qi_heng` -> deck=`weapon_followup_v0_1_deck_011` reward=`weapon_followup_v0_1_reward_011` risk=realm_cap_close
- `enc_ch2_reed_ambush` -> deck=`weapon_followup_v0_1_deck_012` reward=`weapon_followup_v0_1_reward_012` risk=realm_cap_close
- `enc_ch3_escort_clash` -> deck=`weapon_followup_v0_1_deck_013` reward=`weapon_followup_v0_1_reward_013` risk=realm_cap_close
- `enc_ch4_tide_bandits` -> deck=`weapon_followup_v0_1_deck_014` reward=`weapon_followup_v0_1_reward_014` risk=realm_cap_close
- `enc_boss_ext_wakou_leader` -> deck=`weapon_followup_v0_1_deck_015` reward=`weapon_followup_v0_1_reward_015` risk=realm_cap_close

## 6. 单场战斗设计卡摘要
- `#1 enc_beach_ambush` | archetype=`spear_pressure` | action=`needs_balance_adjustment`
- `#2 enc_fishing_village_embers` | archetype=`generic_mixed` | action=`needs_balance_adjustment`
- `#3 enc_transport_officer` | archetype=`boss_mixed_pressure` | action=`needs_balance_adjustment`
- `#4 enc_mutiny_camp` | archetype=`spear_pressure` | action=`needs_balance_adjustment`
- `#5 enc_wakou_boss` | archetype=`boss_mixed_pressure` | action=`needs_balance_adjustment`
- `#6 enc_wuke_spear_trial` | archetype=`spear_pressure` | action=`needs_balance_adjustment`
- `#7 enc_wuke_blade_trial` | archetype=`boss_mixed_pressure` | action=`needs_balance_adjustment`
- `#8 enc_wuke_final_duel` | archetype=`boss_mixed_pressure` | action=`needs_balance_adjustment`
- `#9 enc_wuke_gu_chengyue` | archetype=`boss_mixed_pressure` | action=`needs_balance_adjustment`
- `#10 enc_wuke_shen_zhaoye` | archetype=`spear_pressure` | action=`needs_balance_adjustment`
- `#11 enc_wuke_qi_heng` | archetype=`spear_pressure` | action=`needs_balance_adjustment`
- `#12 enc_ch2_reed_ambush` | archetype=`spear_pressure` | action=`needs_balance_adjustment`
- `#13 enc_ch3_escort_clash` | archetype=`boss_mixed_pressure` | action=`needs_balance_adjustment`
- `#14 enc_ch4_tide_bandits` | archetype=`boss_mixed_pressure` | action=`needs_balance_adjustment`
- `#15 enc_boss_ext_wakou_leader` | archetype=`boss_mixed_pressure` | action=`needs_balance_adjustment`

## 7. 卡池摘要
- card_count: `41`
- unused_card_count: `5`
- high_power_card_count: `10`

## 8. Deck 行为摘要
- `weapon_followup_v0_1_deck_005` | archetype=`boss_mixed_pressure` | A=42.64 D=9.8 M=11.8 B=16.0
- `weapon_followup_v0_1_deck_008` | archetype=`boss_mixed_pressure` | A=42.64 D=9.8 M=11.8 B=16.0
- `weapon_followup_v0_1_deck_015` | archetype=`boss_mixed_pressure` | A=42.64 D=9.8 M=11.8 B=16.0
- `weapon_followup_v0_1_deck_011` | archetype=`spear_pressure` | A=40.48 D=8.4 M=3.0 B=21.6
- `weapon_followup_v0_1_deck_013` | archetype=`boss_mixed_pressure` | A=40.48 D=8.4 M=3.0 B=21.6
- `weapon_followup_v0_1_deck_012` | archetype=`spear_pressure` | A=31.44 D=8.4 M=3.0 B=17.8
- `weapon_followup_v0_1_deck_014` | archetype=`boss_mixed_pressure` | A=31.44 D=8.4 M=3.0 B=17.8
- `weapon_followup_v0_1_deck_006` | archetype=`spear_pressure` | A=24.76 D=7.0 M=6.7 B=11.7
- `weapon_followup_v0_1_deck_007` | archetype=`boss_mixed_pressure` | A=24.76 D=7.0 M=6.7 B=11.7
- `weapon_followup_v0_1_deck_009` | archetype=`boss_mixed_pressure` | A=24.76 D=7.0 M=6.7 B=11.7
- `weapon_followup_v0_1_deck_010` | archetype=`spear_pressure` | A=24.76 D=7.0 M=6.7 B=11.7
- `weapon_followup_v0_1_deck_003` | archetype=`boss_mixed_pressure` | A=20.56 D=5.6 M=6.2 B=9.2
- `weapon_followup_v0_1_deck_004` | archetype=`spear_pressure` | A=20.56 D=5.6 M=6.2 B=9.2
- `weapon_followup_v0_1_deck_001` | archetype=`spear_pressure` | A=19.56 D=5.6 M=8.7 B=6.2
- `weapon_followup_v0_1_deck_002` | archetype=`generic_mixed` | A=14.0 D=11.2 M=3.0 B=3.0

## 9. Reward 成长摘要
- `weapon_followup_v0_1_reward_001` | tier=`basic` | items=x1
- `weapon_followup_v0_1_reward_002` | tier=`basic` | items=basic_reward_card_002x1
- `weapon_followup_v0_1_reward_003` | tier=`basic` | items=basic_reward_card_003x1
- `weapon_followup_v0_1_reward_004` | tier=`basic` | items=basic_reward_card_004x1
- `weapon_followup_v0_1_reward_006` | tier=`standard` | items=standard_reward_card_006x1, resource_meritx1
- `weapon_followup_v0_1_reward_007` | tier=`standard` | items=standard_reward_card_007x1, resource_meritx1
- `weapon_followup_v0_1_reward_009` | tier=`standard` | items=standard_reward_card_009x1, resource_meritx1
- `weapon_followup_v0_1_reward_010` | tier=`standard` | items=standard_reward_card_010x1, resource_meritx1
- `weapon_followup_v0_1_reward_011` | tier=`advanced` | items=advanced_reward_card_011x1, resource_meritx2
- `weapon_followup_v0_1_reward_012` | tier=`advanced` | items=advanced_reward_card_012x1, resource_meritx1
- `weapon_followup_v0_1_reward_013` | tier=`advanced` | items=advanced_reward_card_013x1, resource_meritx2
- `weapon_followup_v0_1_reward_014` | tier=`advanced` | items=advanced_reward_card_014x1, resource_meritx1
- `weapon_followup_v0_1_reward_005` | tier=`boss` | items=boss_reward_tokenx1, resource_meritx3
- `weapon_followup_v0_1_reward_008` | tier=`boss` | items=boss_reward_tokenx1, resource_meritx3
- `weapon_followup_v0_1_reward_015` | tier=`boss` | items=boss_reward_tokenx1, resource_meritx3

## 10. Risk Board
- risk_count: `46`
- fail_count: `2`
- warning_count: `28`
- [fail] deck 卡牌超出玩家武境上限。 | action=`blocked_by_validation`
- [fail] deck 内存在超出当前玩家武境/收式上限的卡牌。 | action=`blocked_by_validation`
- [warning] AI pack 使用了 deterministic fill。 | action=`needs_review`
- [warning] 缺少审核依赖报告：telemetry_probe_report.json | action=`needs_rebuild`
- [warning] 缺少审核依赖报告：sequence_balance_snapshot.json | action=`needs_rebuild`
- [warning] 缺少审核依赖报告：runtime_primitive_probe_report.json | action=`needs_rebuild`
- [warning] 缺少审核依赖报告：rebuild_from_snapshot_probe_report.json | action=`needs_rebuild`
- [warning] 当前 AI pack 上下文存在 rejected candidates。 | action=`needs_review`
- [warning] 卡牌武境要求接近玩家上限。 | action=`needs_balance_adjustment`
- [warning] 卡牌武境要求接近玩家上限。 | action=`needs_balance_adjustment`
- [warning] 卡牌武境要求接近玩家上限。 | action=`needs_balance_adjustment`
- [warning] 卡牌武境要求接近玩家上限。 | action=`needs_balance_adjustment`

## 11. Telemetry / Snapshot 状态
- telemetry: `True`
- snapshot: `False`
- missing_reports: telemetry_probe_report.json, sequence_balance_snapshot.json, runtime_primitive_probe_report.json, rebuild_from_snapshot_probe_report.json

## 12. 建议动作
- `ready_for_release_candidate`
