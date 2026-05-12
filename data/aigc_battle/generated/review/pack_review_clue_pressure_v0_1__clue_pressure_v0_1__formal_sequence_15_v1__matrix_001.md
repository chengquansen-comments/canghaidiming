# Pack 审核表：clue_pressure_v0_1 / clue_pressure_v0_1__formal_sequence_15_v1__matrix_001

## 包基本信息
- active: 否
- pack_storage_mode: `profile_pack_dir`
- runtime_manifest_path: `data/aigc_battle/generated/clue_pressure_v0_1/packs/clue_pressure_v0_1__formal_sequence_15_v1__matrix_001/runtime_manifest.json`
- target_sequence_id: `formal_sequence_mvp_v1`
- replacement_mode: `full_sequence`

## 健康状态
- health_status: `warning`
- health_score: `0`
- ready_for_runtime_export: `True`
- sequence_balance_pass: `True`
- unused_card_count: `46`
- orphan_card_count: `0`

## Balance Release
- balance_release: `False`
- source_pack_id: `-`
- playable_balance_gate_pass: `False`

## 全序列节奏
- #1 `enc_beach_ambush` | tier=early | kind=normal | power=22.8 | reward=early | risk=realm_cap_close
- #2 `enc_fishing_village_embers` | tier=early | kind=normal | power=22.8 | reward=early | risk=realm_cap_close
- #3 `enc_transport_officer` | tier=early | kind=normal | power=22.8 | reward=early | risk=-
- #4 `enc_mutiny_camp` | tier=early | kind=elite | power=27.6 | reward=early | risk=close_to_target_power_max
- #5 `enc_wakou_boss` | tier=mid | kind=normal | power=30.0 | reward=mid | risk=-
- #6 `enc_wuke_spear_trial` | tier=mid | kind=normal | power=30.0 | reward=mid | risk=-
- #7 `enc_wuke_blade_trial` | tier=mid | kind=elite | power=33.2 | reward=mid | risk=-
- #8 `enc_wuke_final_duel` | tier=mid | kind=elite | power=33.2 | reward=mid | risk=-
- #9 `enc_wuke_gu_chengyue` | tier=late | kind=elite | power=49.2 | reward=late | risk=close_to_target_power_max
- #10 `enc_wuke_shen_zhaoye` | tier=late | kind=elite | power=49.2 | reward=late | risk=close_to_target_power_max
- #11 `enc_wuke_qi_heng` | tier=late | kind=elite | power=49.2 | reward=late | risk=close_to_target_power_max
- #12 `enc_ch2_reed_ambush` | tier=late | kind=boss | power=43.2 | reward=late | risk=-
- #13 `enc_ch3_escort_clash` | tier=boss | kind=boss | power=53.8 | reward=boss | risk=-
- #14 `enc_ch4_tide_bandits` | tier=boss | kind=boss | power=53.8 | reward=boss | risk=-
- #15 `enc_boss_ext_wakou_leader` | tier=boss | kind=boss | power=53.8 | reward=boss | risk=-

## Risk Board
- risk_count: `73`
- fail_count: `0`
- warning_count: `58`
- info_count: `15`
- [warning] deck_power_close_to_max | deck power 接近 target_power_max。 | action=needs_balance_adjustment
- [warning] deck_power_close_to_max | deck power 接近 target_power_max。 | action=needs_balance_adjustment
- [warning] deck_power_close_to_max | deck power 接近 target_power_max。 | action=needs_balance_adjustment
- [warning] deck_power_close_to_max | deck power 接近 target_power_max。 | action=needs_balance_adjustment
- [warning] missing_report | 缺少审核依赖报告：telemetry_probe_report.json | action=needs_rebuild
- [warning] missing_report | 缺少审核依赖报告：sequence_balance_snapshot.json | action=needs_rebuild
- [warning] missing_report | 缺少审核依赖报告：runtime_primitive_probe_report.json | action=needs_rebuild
- [warning] missing_report | 缺少审核依赖报告：rebuild_from_snapshot_probe_report.json | action=needs_rebuild
- [warning] required_wujing_close_to_cap | 卡牌武境要求接近玩家上限。 | action=needs_balance_adjustment
- [warning] required_wujing_close_to_cap | 卡牌武境要求接近玩家上限。 | action=needs_balance_adjustment
- [warning] snapshot_missing | 缺少 snapshot 明细。 | action=needs_real_telemetry
- [warning] unused_card | 卡牌未进入任何 deck。 | action=needs_balance_adjustment
