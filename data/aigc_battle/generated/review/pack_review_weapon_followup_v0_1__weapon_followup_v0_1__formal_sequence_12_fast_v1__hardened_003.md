# Pack 审核表：weapon_followup_v0_1 / weapon_followup_v0_1__formal_sequence_12_fast_v1__hardened_003

## 包基本信息
- active: 否
- pack_storage_mode: `profile_pack_dir`
- runtime_manifest_path: `data/aigc_battle/generated/weapon_followup_v0_1/packs/weapon_followup_v0_1__formal_sequence_12_fast_v1__hardened_003/runtime_manifest.json`
- target_sequence_id: `formal_sequence_mvp_v1`
- replacement_mode: `full_sequence`

## 健康状态
- health_status: `fail`
- health_score: `0`
- ready_for_runtime_export: `False`
- sequence_balance_pass: `True`
- unused_card_count: `6`
- orphan_card_count: `0`

## Balance Release
- balance_release: `False`
- source_pack_id: `-`
- playable_balance_gate_pass: `False`

## 全序列节奏
- #1 `enc_beach_ambush` | tier=early | kind=normal | power=25.2 | reward=early | risk=realm_cap_close
- #2 `enc_fishing_village_embers` | tier=early | kind=normal | power=27.2 | reward=early | risk=early_high_power_card,realm_cap_close
- #3 `enc_transport_officer` | tier=early | kind=elite | power=30.6 | reward=early | risk=early_high_power_card,realm_cap_close
- #4 `enc_mutiny_camp` | tier=mid | kind=normal | power=32.0 | reward=mid | risk=realm_cap_close
- #5 `enc_wakou_boss` | tier=mid | kind=elite | power=36.2 | reward=mid | risk=realm_cap_close
- #6 `enc_wuke_spear_trial` | tier=mid | kind=elite | power=35.2 | reward=mid | risk=realm_cap_close
- #7 `enc_wuke_blade_trial` | tier=late | kind=elite | power=48.6 | reward=late | risk=-
- #8 `enc_wuke_final_duel` | tier=late | kind=elite | power=52.8 | reward=late | risk=-
- #9 `enc_wuke_gu_chengyue` | tier=late | kind=elite | power=49.8 | reward=late | risk=-
- #10 `enc_wuke_shen_zhaoye` | tier=boss | kind=boss | power=52.6 | reward=boss | risk=close_to_target_power_min
- #11 `enc_wuke_qi_heng` | tier=boss | kind=boss | power=52.6 | reward=boss | risk=close_to_target_power_min
- #12 `enc_ch2_reed_ambush` | tier=boss | kind=boss | power=52.6 | reward=boss | risk=close_to_target_power_min

## Risk Board
- risk_count: `41`
- fail_count: `2`
- warning_count: `27`
- info_count: `12`
- [fail] ready_for_runtime_export | 内容包未准备好导出 runtime。 | action=blocked_by_runtime
- [fail] runtime_export_allowed | runtime export gate 未通过。 | action=blocked_by_runtime
- [warning] deck_power_close_to_min | deck power 接近 target_power_min。 | action=needs_balance_adjustment
- [warning] deck_power_close_to_min | deck power 接近 target_power_min。 | action=needs_balance_adjustment
- [warning] deck_power_close_to_min | deck power 接近 target_power_min。 | action=needs_balance_adjustment
- [warning] early_high_power_card | early encounter 出现高 power 卡。 | action=needs_balance_adjustment
- [warning] early_high_power_card | early encounter 出现高 power 卡。 | action=needs_balance_adjustment
- [warning] high_usage_card | 卡牌使用频次偏高，建议检查重复占用。 | action=needs_balance_adjustment
- [warning] high_usage_card | 卡牌使用频次偏高，建议检查重复占用。 | action=needs_balance_adjustment
- [warning] high_usage_card | 卡牌使用频次偏高，建议检查重复占用。 | action=needs_balance_adjustment
- [warning] high_usage_card | 卡牌使用频次偏高，建议检查重复占用。 | action=needs_balance_adjustment
- [warning] missing_report | 缺少审核依赖报告：telemetry_probe_report.json | action=needs_rebuild
