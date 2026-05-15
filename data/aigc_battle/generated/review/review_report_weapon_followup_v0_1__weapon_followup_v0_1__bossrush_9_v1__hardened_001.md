# AIGC Battle 审核报告：weapon_followup_v0_1 / weapon_followup_v0_1__bossrush_9_v1__hardened_001

## 1. 包基本信息
- active: 否
- pack_storage_mode: `profile_pack_dir`
- target_sequence_id: `formal_sequence_mvp_v1`
- replacement_mode: `full_sequence`

## 2. 机制摘要
- runtime_manifest_path: `data/aigc_battle/generated/weapon_followup_v0_1/packs/weapon_followup_v0_1__bossrush_9_v1__hardened_001/runtime_manifest.json`
- runtime primitives: weapon_followup

## 2.5 Balance Release
- balance_release: `False`
- source_pack_id: `-`
- playable_balance_gate_pass: `False`

## 3. 健康状态
- health_status: `warning`
- health_score: `41`
- ready_for_runtime_export: `True`
- full_sequence_coverage_complete: `True`
- runtime_export_allowed: `True`

## 4. 全序列节奏
- #1 `enc_beach_ambush` | early/normal | power=26.2 | reward=early | wujing=2
- #2 `enc_fishing_village_embers` | early/elite | power=31.2 | reward=mid | wujing=3
- #3 `enc_transport_officer` | mid/elite | power=36.2 | reward=mid | wujing=4
- #4 `enc_mutiny_camp` | mid/elite | power=35.2 | reward=boss | wujing=5
- #5 `enc_wakou_boss` | late/elite | power=49.8 | reward=boss | wujing=5
- #6 `enc_wuke_spear_trial` | late/boss_lite | power=42.2 | reward=rare | wujing=6
- #7 `enc_wuke_blade_trial` | boss/boss | power=51.4 | reward=boss | wujing=7
- #8 `enc_wuke_final_duel` | boss/boss | power=55.6 | reward=rare | wujing=7
- #9 `enc_wuke_gu_chengyue` | boss/boss | power=52.6 | reward=boss | wujing=7

## 5. 战斗列表
- `enc_beach_ambush` -> deck=`weapon_followup_v0_1_deck_001` reward=`weapon_followup_v0_1_reward_001` risk=early_high_power_card,realm_cap_close
- `enc_fishing_village_embers` -> deck=`weapon_followup_v0_1_deck_002` reward=`weapon_followup_v0_1_reward_002` risk=early_high_power_card,realm_cap_close
- `enc_transport_officer` -> deck=`weapon_followup_v0_1_deck_003` reward=`weapon_followup_v0_1_reward_003` risk=realm_cap_close
- `enc_mutiny_camp` -> deck=`weapon_followup_v0_1_deck_004` reward=`weapon_followup_v0_1_reward_004` risk=-
- `enc_wakou_boss` -> deck=`weapon_followup_v0_1_deck_005` reward=`weapon_followup_v0_1_reward_005` risk=-
- `enc_wuke_spear_trial` -> deck=`weapon_followup_v0_1_deck_006` reward=`weapon_followup_v0_1_reward_006` risk=close_to_target_power_min
- `enc_wuke_blade_trial` -> deck=`weapon_followup_v0_1_deck_007` reward=`weapon_followup_v0_1_reward_007` risk=close_to_target_power_min
- `enc_wuke_final_duel` -> deck=`weapon_followup_v0_1_deck_008` reward=`weapon_followup_v0_1_reward_008` risk=-
- `enc_wuke_gu_chengyue` -> deck=`weapon_followup_v0_1_deck_009` reward=`weapon_followup_v0_1_reward_009` risk=close_to_target_power_min

## 6. 单场战斗设计卡摘要
- `#1 enc_beach_ambush` | archetype=`spear_pressure` | action=`needs_balance_adjustment`
- `#2 enc_fishing_village_embers` | archetype=`boss_mixed_pressure` | action=`needs_balance_adjustment`
- `#3 enc_transport_officer` | archetype=`boss_mixed_pressure` | action=`needs_balance_adjustment`
- `#4 enc_mutiny_camp` | archetype=`spear_pressure` | action=`ready_for_review`
- `#5 enc_wakou_boss` | archetype=`boss_mixed_pressure` | action=`ready_for_review`
- `#6 enc_wuke_spear_trial` | archetype=`spear_pressure` | action=`needs_balance_adjustment`
- `#7 enc_wuke_blade_trial` | archetype=`boss_mixed_pressure` | action=`needs_balance_adjustment`
- `#8 enc_wuke_final_duel` | archetype=`boss_mixed_pressure` | action=`ready_for_review`
- `#9 enc_wuke_gu_chengyue` | archetype=`spear_pressure` | action=`needs_balance_adjustment`

## 7. 卡池摘要
- card_count: `40`
- unused_card_count: `8`
- high_power_card_count: `10`

## 8. Deck 行为摘要
- `weapon_followup_v0_1_deck_008` | archetype=`boss_mixed_pressure` | A=53.84 D=0.0 M=11.8 B=16.0
- `weapon_followup_v0_1_deck_009` | archetype=`spear_pressure` | A=49.64 D=0.0 M=11.8 B=16.0
- `weapon_followup_v0_1_deck_007` | archetype=`boss_mixed_pressure` | A=47.92 D=9.8 M=7.9 B=8.0
- `weapon_followup_v0_1_deck_005` | archetype=`boss_mixed_pressure` | A=47.48 D=0.0 M=3.0 B=21.6
- `weapon_followup_v0_1_deck_006` | archetype=`spear_pressure` | A=38.44 D=0.0 M=3.0 B=17.8
- `weapon_followup_v0_1_deck_003` | archetype=`boss_mixed_pressure` | A=35.96 D=0.0 M=6.7 B=11.7
- `weapon_followup_v0_1_deck_004` | archetype=`spear_pressure` | A=34.56 D=0.0 M=6.7 B=11.7
- `weapon_followup_v0_1_deck_002` | archetype=`boss_mixed_pressure` | A=33.6 D=0.0 M=3.0 B=6.0
- `weapon_followup_v0_1_deck_001` | archetype=`spear_pressure` | A=21.96 D=5.6 M=6.7 B=6.7

## 9. Reward 成长摘要
- `weapon_followup_v0_1_reward_001` | tier=`early` | items=basic_reward_card_001x1
- `weapon_followup_v0_1_reward_006` | tier=`rare` | items=basic_reward_card_006x1
- `weapon_followup_v0_1_reward_008` | tier=`rare` | items=basic_reward_card_008x1
- `weapon_followup_v0_1_reward_002` | tier=`mid` | items=basic_reward_card_002x1
- `weapon_followup_v0_1_reward_003` | tier=`mid` | items=basic_reward_card_003x1
- `weapon_followup_v0_1_reward_004` | tier=`boss` | items=advanced_reward_card_004x1, resource_meritx2
- `weapon_followup_v0_1_reward_005` | tier=`boss` | items=advanced_reward_card_005x1, resource_meritx2
- `weapon_followup_v0_1_reward_007` | tier=`boss` | items=boss_reward_tokenx1, resource_meritx3
- `weapon_followup_v0_1_reward_009` | tier=`boss` | items=boss_reward_tokenx1, resource_meritx3

## 10. Risk Board
- risk_count: `36`
- fail_count: `0`
- warning_count: `27`
- [warning] deck power 接近 target_power_min。 | action=`needs_balance_adjustment`
- [warning] deck power 接近 target_power_min。 | action=`needs_balance_adjustment`
- [warning] deck power 接近 target_power_min。 | action=`needs_balance_adjustment`
- [warning] early encounter 出现高 power 卡。 | action=`needs_balance_adjustment`
- [warning] early encounter 出现高 power 卡。 | action=`needs_balance_adjustment`
- [warning] 卡牌使用频次偏高，建议检查重复占用。 | action=`needs_balance_adjustment`
- [warning] 卡牌使用频次偏高，建议检查重复占用。 | action=`needs_balance_adjustment`
- [warning] 卡牌使用频次偏高，建议检查重复占用。 | action=`needs_balance_adjustment`
- [warning] 缺少审核依赖报告：telemetry_probe_report.json | action=`needs_rebuild`
- [warning] 缺少审核依赖报告：sequence_balance_snapshot.json | action=`needs_rebuild`
- [warning] 缺少审核依赖报告：runtime_primitive_probe_report.json | action=`needs_rebuild`
- [warning] 缺少审核依赖报告：rebuild_from_snapshot_probe_report.json | action=`needs_rebuild`

## 11. Telemetry / Snapshot 状态
- telemetry: `True`
- snapshot: `False`
- missing_reports: telemetry_probe_report.json, sequence_balance_snapshot.json, runtime_primitive_probe_report.json, rebuild_from_snapshot_probe_report.json

## 12. 建议动作
- `safe_to_test`
