# Pack 审核表：posture_tuned_v0_1b / posture_tuned_v0_1b_formal_sequence_pack_001

## 包基本信息
- active: 否
- pack_storage_mode: `profile_root`
- runtime_manifest_path: `data/aigc_battle/generated/posture_tuned_v0_1b/runtime_manifest.json`
- target_sequence_id: `formal_sequence_mvp_v1`
- replacement_mode: `full_sequence`

## 健康状态
- health_status: `warning`
- health_score: `21`
- ready_for_runtime_export: `True`
- sequence_balance_pass: `True`
- unused_card_count: `5`
- orphan_card_count: `0`

## 全序列节奏
- #1 `enc_beach_ambush` | tier=early | kind=normal | power=23.5 | reward=basic | risk=realm_cap_close
- #2 `enc_fishing_village_embers` | tier=early | kind=normal | power=23.5 | reward=basic | risk=realm_cap_close
- #3 `enc_transport_officer` | tier=early | kind=elite | power=29.5 | reward=basic | risk=realm_cap_close
- #4 `enc_mutiny_camp` | tier=early | kind=elite | power=29.5 | reward=basic | risk=realm_cap_close
- #5 `enc_wakou_boss` | tier=boss | kind=boss | power=56.9 | reward=boss | risk=close_to_target_power_min,realm_cap_close
- #6 `enc_wuke_spear_trial` | tier=mid | kind=elite | power=35.5 | reward=standard_plus | risk=close_to_target_power_min,realm_cap_close
- #7 `enc_wuke_blade_trial` | tier=mid | kind=elite | power=35.5 | reward=standard_plus | risk=close_to_target_power_min,realm_cap_close
- #8 `enc_wuke_final_duel` | tier=boss | kind=boss | power=56.9 | reward=boss | risk=close_to_target_power_min,realm_cap_close
- #9 `enc_wuke_gu_chengyue` | tier=mid | kind=elite | power=35.5 | reward=standard_plus | risk=close_to_target_power_min,realm_cap_close
- #10 `enc_wuke_shen_zhaoye` | tier=mid | kind=elite | power=35.5 | reward=standard_plus | risk=close_to_target_power_min,realm_cap_close
- #11 `enc_wuke_qi_heng` | tier=late | kind=elite | power=52.25 | reward=advanced_plus | risk=realm_cap_close
- #12 `enc_ch2_reed_ambush` | tier=late | kind=normal | power=46.55 | reward=advanced_plus | risk=realm_cap_close
- #13 `enc_ch3_escort_clash` | tier=late | kind=elite | power=52.25 | reward=advanced_plus | risk=realm_cap_close
- #14 `enc_ch4_tide_bandits` | tier=late | kind=normal | power=46.55 | reward=advanced_plus | risk=realm_cap_close
- #15 `enc_boss_ext_wakou_leader` | tier=boss | kind=boss | power=56.9 | reward=boss | risk=close_to_target_power_min,realm_cap_close

## Risk Board
- risk_count: `37`
- fail_count: `0`
- warning_count: `37`
- info_count: `0`
- [warning] deck_power_close_to_min | deck power 接近 target_power_min。 | action=needs_balance_adjustment
- [warning] deck_power_close_to_min | deck power 接近 target_power_min。 | action=needs_balance_adjustment
- [warning] deck_power_close_to_min | deck power 接近 target_power_min。 | action=needs_balance_adjustment
- [warning] deck_power_close_to_min | deck power 接近 target_power_min。 | action=needs_balance_adjustment
- [warning] deck_power_close_to_min | deck power 接近 target_power_min。 | action=needs_balance_adjustment
- [warning] deck_power_close_to_min | deck power 接近 target_power_min。 | action=needs_balance_adjustment
- [warning] deck_power_close_to_min | deck power 接近 target_power_min。 | action=needs_balance_adjustment
- [warning] missing_report | 缺少审核依赖报告：telemetry_probe_report.json | action=needs_rebuild
- [warning] missing_report | 缺少审核依赖报告：sequence_balance_snapshot.json | action=needs_rebuild
- [warning] missing_report | 缺少审核依赖报告：runtime_primitive_probe_report.json | action=needs_rebuild
- [warning] missing_report | 缺少审核依赖报告：rebuild_from_snapshot_probe_report.json | action=needs_rebuild
- [warning] required_wujing_close_to_cap | 卡牌武境要求接近玩家上限。 | action=needs_balance_adjustment
