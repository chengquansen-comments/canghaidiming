# Pack 审核表：clue_pressure_v0_1 / r9_showcase_candidate_pack_001

## 包基本信息
- active: 否
- pack_storage_mode: `profile_pack_dir`
- runtime_manifest_path: `data/aigc_battle/generated/clue_pressure_v0_1/packs/r9_showcase_candidate_pack_001/runtime_manifest.json`
- target_sequence_id: `formal_sequence_mvp_v1`
- replacement_mode: `full_sequence`

## 健康状态
- health_status: `warning`
- health_score: `0`
- ready_for_runtime_export: `True`
- sequence_balance_pass: `True`
- unused_card_count: `42`
- orphan_card_count: `0`

## Balance Release
- balance_release: `False`
- source_pack_id: `-`
- playable_balance_gate_pass: `False`

## 全序列节奏
- #1 `enc_beach_ambush` | tier=early | kind=normal | power=22.8 | reward=early | risk=close_to_target_power_min
- #2 `enc_fishing_village_embers` | tier=early | kind=elite | power=27.6 | reward=mid | risk=-
- #3 `enc_transport_officer` | tier=mid | kind=elite | power=33.2 | reward=mid | risk=close_to_target_power_min
- #4 `enc_mutiny_camp` | tier=mid | kind=elite | power=33.2 | reward=advanced | risk=close_to_target_power_min
- #5 `enc_wakou_boss` | tier=late | kind=elite | power=49.2 | reward=advanced | risk=-
- #6 `enc_wuke_spear_trial` | tier=late | kind=boss_lite | power=43.2 | reward=rare | risk=-
- #7 `enc_wuke_blade_trial` | tier=boss | kind=boss | power=53.8 | reward=boss | risk=close_to_target_power_min
- #8 `enc_wuke_final_duel` | tier=boss | kind=boss | power=53.8 | reward=rare | risk=close_to_target_power_min
- #9 `enc_wuke_gu_chengyue` | tier=boss | kind=boss | power=53.8 | reward=boss | risk=close_to_target_power_min

## Risk Board
- risk_count: `66`
- fail_count: `0`
- warning_count: `57`
- info_count: `9`
- [warning] deck_power_close_to_min | deck power 接近 target_power_min。 | action=needs_balance_adjustment
- [warning] deck_power_close_to_min | deck power 接近 target_power_min。 | action=needs_balance_adjustment
- [warning] deck_power_close_to_min | deck power 接近 target_power_min。 | action=needs_balance_adjustment
- [warning] deck_power_close_to_min | deck power 接近 target_power_min。 | action=needs_balance_adjustment
- [warning] deck_power_close_to_min | deck power 接近 target_power_min。 | action=needs_balance_adjustment
- [warning] deck_power_close_to_min | deck power 接近 target_power_min。 | action=needs_balance_adjustment
- [warning] deterministic_fill_used | AI pack 使用了 deterministic fill。 | action=needs_review
- [warning] missing_report | 缺少审核依赖报告：telemetry_probe_report.json | action=needs_rebuild
- [warning] missing_report | 缺少审核依赖报告：sequence_balance_snapshot.json | action=needs_rebuild
- [warning] missing_report | 缺少审核依赖报告：runtime_primitive_probe_report.json | action=needs_rebuild
- [warning] missing_report | 缺少审核依赖报告：rebuild_from_snapshot_probe_report.json | action=needs_rebuild
- [warning] reward_tier_lower_than_encounter | reward_tier 低于 encounter tier。 | action=needs_balance_adjustment
