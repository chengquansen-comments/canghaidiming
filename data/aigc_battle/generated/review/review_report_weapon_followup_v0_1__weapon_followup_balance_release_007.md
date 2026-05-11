# AIGC Battle 审核报告：weapon_followup_v0_1 / weapon_followup_balance_release_007

## 1. 包基本信息
- active: 是
- pack_storage_mode: `profile_pack_dir`
- target_sequence_id: `formal_sequence_mvp_v1`
- replacement_mode: `full_sequence`

## 2. 机制摘要
- runtime_manifest_path: `data/aigc_battle/generated/weapon_followup_v0_1/packs/weapon_followup_balance_release_007/runtime_manifest.json`
- runtime primitives: weapon_followup

## 2.5 Balance Release
- balance_release: `True`
- source_pack_id: `weapon_followup_v0_1_formal_sequence_pack_001`
- playable_balance_gate_pass: `True`

## 3. 健康状态
- health_status: `warning`
- health_score: `0`
- ready_for_runtime_export: `True`
- full_sequence_coverage_complete: `True`
- runtime_export_allowed: `True`

## 4. 全序列节奏
- #1 `enc_beach_ambush` | early/normal | power=12.0 | reward=basic | wujing=1
- #2 `enc_fishing_village_embers` | early/normal | power=12.0 | reward=basic | wujing=1
- #3 `enc_transport_officer` | early/elite | power=12.0 | reward=basic | wujing=1
- #4 `enc_mutiny_camp` | early/elite | power=12.0 | reward=basic | wujing=1
- #5 `enc_wakou_boss` | boss/boss | power=12.0 | reward=boss | wujing=4
- #6 `enc_wuke_spear_trial` | mid/elite | power=12.0 | reward=mid | wujing=2
- #7 `enc_wuke_blade_trial` | mid/elite | power=12.0 | reward=mid | wujing=2
- #8 `enc_wuke_final_duel` | boss/boss | power=12.0 | reward=boss | wujing=4
- #9 `enc_wuke_gu_chengyue` | mid/elite | power=12.0 | reward=mid | wujing=2
- #10 `enc_wuke_shen_zhaoye` | mid/elite | power=12.0 | reward=mid | wujing=2
- #11 `enc_wuke_qi_heng` | late/elite | power=12.0 | reward=late | wujing=3
- #12 `enc_ch2_reed_ambush` | late/normal | power=12.0 | reward=late | wujing=3
- #13 `enc_ch3_escort_clash` | late/elite | power=12.0 | reward=late | wujing=3
- #14 `enc_ch4_tide_bandits` | late/normal | power=12.0 | reward=late | wujing=3
- #15 `enc_boss_ext_wakou_leader` | boss/boss | power=12.0 | reward=boss | wujing=4

## 5. 战斗列表
- `enc_beach_ambush` -> deck=`weapon_followup_v0_1_deck_001` reward=`weapon_followup_v0_1_reward_001` risk=realm_cap_close
- `enc_fishing_village_embers` -> deck=`weapon_followup_v0_1_deck_002` reward=`weapon_followup_v0_1_reward_002` risk=realm_cap_close
- `enc_transport_officer` -> deck=`weapon_followup_v0_1_deck_003` reward=`weapon_followup_v0_1_reward_003` risk=realm_cap_close
- `enc_mutiny_camp` -> deck=`weapon_followup_v0_1_deck_004` reward=`weapon_followup_v0_1_reward_004` risk=realm_cap_close
- `enc_wakou_boss` -> deck=`weapon_followup_v0_1_deck_005` reward=`weapon_followup_v0_1_reward_005` risk=-
- `enc_wuke_spear_trial` -> deck=`weapon_followup_v0_1_deck_006` reward=`weapon_followup_v0_1_reward_006` risk=-
- `enc_wuke_blade_trial` -> deck=`weapon_followup_v0_1_deck_007` reward=`weapon_followup_v0_1_reward_007` risk=-
- `enc_wuke_final_duel` -> deck=`weapon_followup_v0_1_deck_008` reward=`weapon_followup_v0_1_reward_008` risk=-
- `enc_wuke_gu_chengyue` -> deck=`weapon_followup_v0_1_deck_009` reward=`weapon_followup_v0_1_reward_009` risk=-
- `enc_wuke_shen_zhaoye` -> deck=`weapon_followup_v0_1_deck_010` reward=`weapon_followup_v0_1_reward_010` risk=-
- `enc_wuke_qi_heng` -> deck=`weapon_followup_v0_1_deck_011` reward=`weapon_followup_v0_1_reward_011` risk=-
- `enc_ch2_reed_ambush` -> deck=`weapon_followup_v0_1_deck_012` reward=`weapon_followup_v0_1_reward_012` risk=-
- `enc_ch3_escort_clash` -> deck=`weapon_followup_v0_1_deck_013` reward=`weapon_followup_v0_1_reward_013` risk=-
- `enc_ch4_tide_bandits` -> deck=`weapon_followup_v0_1_deck_014` reward=`weapon_followup_v0_1_reward_014` risk=-
- `enc_boss_ext_wakou_leader` -> deck=`weapon_followup_v0_1_deck_015` reward=`weapon_followup_v0_1_reward_015` risk=-

## 6. 单场战斗设计卡摘要
- `#1 enc_beach_ambush` | archetype=`spear_pressure` | action=`needs_balance_adjustment`
- `#2 enc_fishing_village_embers` | archetype=`generic_mixed` | action=`needs_balance_adjustment`
- `#3 enc_transport_officer` | archetype=`generic_mixed` | action=`needs_balance_adjustment`
- `#4 enc_mutiny_camp` | archetype=`spear_pressure` | action=`needs_balance_adjustment`
- `#5 enc_wakou_boss` | archetype=`generic_mixed` | action=`ready_for_review`
- `#6 enc_wuke_spear_trial` | archetype=`spear_pressure` | action=`ready_for_review`
- `#7 enc_wuke_blade_trial` | archetype=`generic_mixed` | action=`ready_for_review`
- `#8 enc_wuke_final_duel` | archetype=`generic_mixed` | action=`ready_for_review`
- `#9 enc_wuke_gu_chengyue` | archetype=`generic_mixed` | action=`ready_for_review`
- `#10 enc_wuke_shen_zhaoye` | archetype=`spear_pressure` | action=`ready_for_review`
- `#11 enc_wuke_qi_heng` | archetype=`spear_pressure` | action=`ready_for_review`
- `#12 enc_ch2_reed_ambush` | archetype=`spear_pressure` | action=`ready_for_review`
- `#13 enc_ch3_escort_clash` | archetype=`generic_mixed` | action=`ready_for_review`
- `#14 enc_ch4_tide_bandits` | archetype=`generic_mixed` | action=`ready_for_review`
- `#15 enc_boss_ext_wakou_leader` | archetype=`generic_mixed` | action=`ready_for_review`

## 7. 卡池摘要
- card_count: `40`
- unused_card_count: `34`
- high_power_card_count: `10`

## 8. Deck 行为摘要
- `weapon_followup_v0_1_deck_001` | archetype=`spear_pressure` | A=14.8 D=0.0 M=6.0 B=6.0
- `weapon_followup_v0_1_deck_002` | archetype=`generic_mixed` | A=14.8 D=0.0 M=6.0 B=6.0
- `weapon_followup_v0_1_deck_003` | archetype=`generic_mixed` | A=14.8 D=0.0 M=6.0 B=6.0
- `weapon_followup_v0_1_deck_004` | archetype=`spear_pressure` | A=14.8 D=0.0 M=6.0 B=6.0
- `weapon_followup_v0_1_deck_005` | archetype=`generic_mixed` | A=14.8 D=0.0 M=6.0 B=6.0
- `weapon_followup_v0_1_deck_006` | archetype=`spear_pressure` | A=14.8 D=0.0 M=6.0 B=6.0
- `weapon_followup_v0_1_deck_007` | archetype=`generic_mixed` | A=14.8 D=0.0 M=6.0 B=6.0
- `weapon_followup_v0_1_deck_008` | archetype=`generic_mixed` | A=14.8 D=0.0 M=6.0 B=6.0
- `weapon_followup_v0_1_deck_009` | archetype=`generic_mixed` | A=14.8 D=0.0 M=6.0 B=6.0
- `weapon_followup_v0_1_deck_010` | archetype=`spear_pressure` | A=14.8 D=0.0 M=6.0 B=6.0
- `weapon_followup_v0_1_deck_011` | archetype=`spear_pressure` | A=14.8 D=0.0 M=6.0 B=6.0
- `weapon_followup_v0_1_deck_012` | archetype=`spear_pressure` | A=14.8 D=0.0 M=6.0 B=6.0
- `weapon_followup_v0_1_deck_013` | archetype=`generic_mixed` | A=14.8 D=0.0 M=6.0 B=6.0
- `weapon_followup_v0_1_deck_014` | archetype=`generic_mixed` | A=14.8 D=0.0 M=6.0 B=6.0
- `weapon_followup_v0_1_deck_015` | archetype=`generic_mixed` | A=14.8 D=0.0 M=6.0 B=6.0

## 9. Reward 成长摘要
- `weapon_followup_v0_1_reward_001` | tier=`basic` | items=basic_reward_card_001x1
- `weapon_followup_v0_1_reward_002` | tier=`basic` | items=basic_reward_card_002x1
- `weapon_followup_v0_1_reward_003` | tier=`basic` | items=basic_reward_card_003x1
- `weapon_followup_v0_1_reward_004` | tier=`basic` | items=basic_reward_card_004x1
- `weapon_followup_v0_1_reward_006` | tier=`mid` | items=standard_reward_card_006x1, resource_meritx1
- `weapon_followup_v0_1_reward_007` | tier=`mid` | items=standard_reward_card_007x1, resource_meritx1
- `weapon_followup_v0_1_reward_009` | tier=`mid` | items=standard_reward_card_009x1, resource_meritx1
- `weapon_followup_v0_1_reward_010` | tier=`mid` | items=standard_reward_card_010x1, resource_meritx1
- `weapon_followup_v0_1_reward_011` | tier=`late` | items=advanced_reward_card_011x1, resource_meritx2
- `weapon_followup_v0_1_reward_012` | tier=`late` | items=advanced_reward_card_012x1, resource_meritx1
- `weapon_followup_v0_1_reward_013` | tier=`late` | items=advanced_reward_card_013x1, resource_meritx2
- `weapon_followup_v0_1_reward_014` | tier=`late` | items=advanced_reward_card_014x1, resource_meritx1
- `weapon_followup_v0_1_reward_005` | tier=`boss` | items=boss_reward_tokenx1, resource_meritx3
- `weapon_followup_v0_1_reward_008` | tier=`boss` | items=boss_reward_tokenx1, resource_meritx3
- `weapon_followup_v0_1_reward_015` | tier=`boss` | items=boss_reward_tokenx1, resource_meritx3

## 10. Risk Board
- risk_count: `65`
- fail_count: `0`
- warning_count: `50`
- [warning] 卡牌使用频次偏高，建议检查重复占用。 | action=`needs_balance_adjustment`
- [warning] 卡牌使用频次偏高，建议检查重复占用。 | action=`needs_balance_adjustment`
- [warning] 卡牌使用频次偏高，建议检查重复占用。 | action=`needs_balance_adjustment`
- [warning] 卡牌使用频次偏高，建议检查重复占用。 | action=`needs_balance_adjustment`
- [warning] 卡牌使用频次偏高，建议检查重复占用。 | action=`needs_balance_adjustment`
- [warning] 卡牌使用频次偏高，建议检查重复占用。 | action=`needs_balance_adjustment`
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
