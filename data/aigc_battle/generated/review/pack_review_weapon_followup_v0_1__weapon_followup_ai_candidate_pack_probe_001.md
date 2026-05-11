# Pack 审核表：weapon_followup_v0_1 / weapon_followup_ai_candidate_pack_probe_001

## 包基本信息
- active: 否
- pack_storage_mode: `profile_pack_dir`
- runtime_manifest_path: `data/aigc_battle/generated/weapon_followup_v0_1/packs/weapon_followup_ai_candidate_pack_probe_001/runtime_manifest.json`
- target_sequence_id: `formal_sequence_mvp_v1`
- replacement_mode: `full_sequence`

## 健康状态
- health_status: `fail`
- health_score: `39`
- ready_for_runtime_export: `True`
- sequence_balance_pass: `True`
- unused_card_count: `5`
- orphan_card_count: `0`

## Balance Release
- balance_release: `False`
- source_pack_id: `-`
- playable_balance_gate_pass: `False`

## 全序列节奏
- #1 `enc_beach_ambush` | tier=early | kind=normal | power=25.2 | reward=basic | risk=realm_invalid,realm_cap_close
- #2 `enc_fishing_village_embers` | tier=early | kind=normal | power=22.8 | reward=basic | risk=realm_cap_close
- #3 `enc_transport_officer` | tier=early | kind=elite | power=27.6 | reward=basic | risk=realm_cap_close
- #4 `enc_mutiny_camp` | tier=early | kind=elite | power=27.6 | reward=basic | risk=realm_cap_close
- #5 `enc_wakou_boss` | tier=boss | kind=boss | power=54.6 | reward=boss | risk=realm_cap_close
- #6 `enc_wuke_spear_trial` | tier=mid | kind=elite | power=33.2 | reward=standard | risk=realm_cap_close
- #7 `enc_wuke_blade_trial` | tier=mid | kind=elite | power=33.2 | reward=standard | risk=realm_cap_close
- #8 `enc_wuke_final_duel` | tier=boss | kind=boss | power=54.6 | reward=boss | risk=realm_cap_close
- #9 `enc_wuke_gu_chengyue` | tier=mid | kind=elite | power=33.2 | reward=standard | risk=realm_cap_close
- #10 `enc_wuke_shen_zhaoye` | tier=mid | kind=elite | power=33.2 | reward=standard | risk=realm_cap_close
- #11 `enc_wuke_qi_heng` | tier=late | kind=elite | power=50.8 | reward=advanced | risk=realm_cap_close
- #12 `enc_ch2_reed_ambush` | tier=late | kind=normal | power=43.2 | reward=advanced | risk=realm_cap_close
- #13 `enc_ch3_escort_clash` | tier=late | kind=elite | power=50.8 | reward=advanced | risk=realm_cap_close
- #14 `enc_ch4_tide_bandits` | tier=late | kind=normal | power=43.2 | reward=advanced | risk=realm_cap_close
- #15 `enc_boss_ext_wakou_leader` | tier=boss | kind=boss | power=54.6 | reward=boss | risk=realm_cap_close

## Risk Board
- risk_count: `46`
- fail_count: `2`
- warning_count: `28`
- info_count: `16`
- [fail] deck_card_realm_invalid | deck 卡牌超出玩家武境上限。 | action=blocked_by_validation
- [fail] deck_card_realm_invalid | deck 内存在超出当前玩家武境/收式上限的卡牌。 | action=blocked_by_validation
- [warning] deterministic_fill_used | AI pack 使用了 deterministic fill。 | action=needs_review
- [warning] missing_report | 缺少审核依赖报告：telemetry_probe_report.json | action=needs_rebuild
- [warning] missing_report | 缺少审核依赖报告：sequence_balance_snapshot.json | action=needs_rebuild
- [warning] missing_report | 缺少审核依赖报告：runtime_primitive_probe_report.json | action=needs_rebuild
- [warning] missing_report | 缺少审核依赖报告：rebuild_from_snapshot_probe_report.json | action=needs_rebuild
- [warning] rejected_candidate_count_present | 当前 AI pack 上下文存在 rejected candidates。 | action=needs_review
- [warning] required_wujing_close_to_cap | 卡牌武境要求接近玩家上限。 | action=needs_balance_adjustment
- [warning] required_wujing_close_to_cap | 卡牌武境要求接近玩家上限。 | action=needs_balance_adjustment
- [warning] required_wujing_close_to_cap | 卡牌武境要求接近玩家上限。 | action=needs_balance_adjustment
- [warning] required_wujing_close_to_cap | 卡牌武境要求接近玩家上限。 | action=needs_balance_adjustment
