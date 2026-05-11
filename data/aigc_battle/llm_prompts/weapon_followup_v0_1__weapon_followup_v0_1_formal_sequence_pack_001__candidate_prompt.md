# AIGC Battle 候选生成提示词：weapon_followup_v0_1 / weapon_followup_v0_1_formal_sequence_pack_001

## 1. profile 摘要
- mechanic_profile_id: `weapon_followup_v0_1`
- content_pack_id: `weapon_followup_v0_1_formal_sequence_pack_001`
- target_sequence_id: `formal_sequence_mvp_v1`
- replacement_mode: `full_sequence`
- runtime_primitives: `weapon_followup`
- allowed_runtime_effects: `damage, gain_block, gain_momentum, break_momentum`
- weapon_styles: `spearman, blademaster`
- card_eligibility_rules: `{"technique_requires_player_realm": true, "forbid_required_wujing_above_player_cap": true, "forbid_closing_form_above_player_cap": true, "missing_realm_metadata_policy": "fail"}`
- player_progression_policy: `{"default_player_wujing_cap": 1, "tier_wujing_cap": {"early": 1, "mid": 2, "late": 3, "boss": 4}}`
- balance_policy: `{"sequence_tiers": [{"tier": "early", "position_min": 1, "position_max_ratio": 0.34, "deck_power_min": 20, "deck_power_max": 30, "reward_tier": "basic"}, {"tier": "mid", "position_min_ratio": 0.34, "position_max_ratio": 0.67, "deck_power_min": 28, "deck_power_max": 38, "reward_tier": "standard"}, {"tier": "late", "position_min_ratio": 0.67, "position_max_ratio": 0.95, "deck_power_min": 40, "deck_power_max": 50, "reward_tier": "advanced"}, {"tier": "boss", "deck_power_min": 52, "deck_power_max": 62, "reward_tier": "boss"}], "enemy_role_curve": {"early": ["spearman", "blademaster"], "mid": ["blademaster", "spearman"], "late": ["spearman", "blademaster"], "boss": ["spearman", "blademaster"]}, "boss_keywords": ["boss", "wakou_leader", "final"], "elite_keywords": ["trial", "duel", "officer", "escort", "transport", "mutiny", "gu_chengyue", "shen_zhaoye", "qi_heng"], "elite_power_bonus_min": 3, "elite_power_bonus_max": 5, "min_late_avg_power_over_early": 20}`

## 2. 生成边界
- 只能生成 candidates。
- 不允许生成 runtime_manifest。
- 不允许生成 active_profile。
- 不允许生成 Godot 脚本。
- 不允许使用 unsupported effect。
- 不允许突破 required_wujing / closing_form_tier。
- 不允许缺 required fields。
- 不允许单场不覆盖。

## 3. 输出格式
- 输出格式必须是 JSONL。
- 每行一个 candidate。
- candidate_type 只允许：`card_candidate` / `deck_candidate` / `reward_candidate` / `battle_slot_candidate`。
- 每行必须包含：`candidate_id` / `candidate_type` / `mechanic_profile_id` / `target_sequence_id` / `source` / `content`。

## 4. weapon_followup 约束
- 必须包含 followup_group / followup_trigger / followup_bonus / followup_chain_role / weapon_style。
- followup constraints: `{"max_followup_links_per_deck": 4, "max_bonus_damage": 4, "max_bonus_momentum": 2, "max_bonus_block": 4, "allowed_triggers": ["same_weapon_previous_card", "specific_tag_previous_card", "stance_gain_previous_card"]}`
- followup_trigger 只能使用 same_weapon_previous_card / specific_tag_previous_card / stance_gain_previous_card。
- followup_chain_role 只能使用 opener / linker / finisher / standalone。

## 5. 风险修复上下文
- top_risks: `[{"severity": "warning", "risk_type": "missing_report", "message": "缺少审核依赖报告：telemetry_probe_report.json", "profile_id": "weapon_followup_v0_1", "content_pack_id": "weapon_followup_v0_1_formal_sequence_pack_001", "formal_encounter_id": "", "deck_id": "", "card_id": "", "suggested_action": "needs_rebuild"}, {"severity": "warning", "risk_type": "missing_report", "message": "缺少审核依赖报告：sequence_balance_snapshot.json", "profile_id": "weapon_followup_v0_1", "content_pack_id": "weapon_followup_v0_1_formal_sequence_pack_001", "formal_encounter_id": "", "deck_id": "", "card_id": "", "suggested_action": "needs_rebuild"}, {"severity": "warning", "risk_type": "missing_report", "message": "缺少审核依赖报告：runtime_primitive_probe_report.json", "profile_id": "weapon_followup_v0_1", "content_pack_id": "weapon_followup_v0_1_formal_sequence_pack_001", "formal_encounter_id": "", "deck_id": "", "card_id": "", "suggested_action": "needs_rebuild"}, {"severity": "warning", "risk_type": "missing_report", "message": "缺少审核依赖报告：rebuild_from_snapshot_probe_report.json", "profile_id": "weapon_followup_v0_1", "content_pack_id": "weapon_followup_v0_1_formal_sequence_pack_001", "formal_encounter_id": "", "deck_id": "", "card_id": "", "suggested_action": "needs_rebuild"}, {"severity": "warning", "risk_type": "required_wujing_close_to_cap", "message": "卡牌武境要求接近玩家上限。", "profile_id": "weapon_followup_v0_1", "content_pack_id": "weapon_followup_v0_1_formal_sequence_pack_001", "formal_encounter_id": "enc_beach_ambush", "deck_id": "weapon_followup_v0_1_deck_001", "card_id": "", "suggested_action": "needs_balance_adjustment"}, {"severity": "warning", "risk_type": "required_wujing_close_to_cap", "message": "卡牌武境要求接近玩家上限。", "profile_id": "weapon_followup_v0_1", "content_pack_id": "weapon_followup_v0_1_formal_sequence_pack_001", "formal_encounter_id": "enc_boss_ext_wakou_leader", "deck_id": "weapon_followup_v0_1_deck_015", "card_id": "", "suggested_action": "needs_balance_adjustment"}, {"severity": "warning", "risk_type": "required_wujing_close_to_cap", "message": "卡牌武境要求接近玩家上限。", "profile_id": "weapon_followup_v0_1", "content_pack_id": "weapon_followup_v0_1_formal_sequence_pack_001", "formal_encounter_id": "enc_ch2_reed_ambush", "deck_id": "weapon_followup_v0_1_deck_012", "card_id": "", "suggested_action": "needs_balance_adjustment"}, {"severity": "warning", "risk_type": "required_wujing_close_to_cap", "message": "卡牌武境要求接近玩家上限。", "profile_id": "weapon_followup_v0_1", "content_pack_id": "weapon_followup_v0_1_formal_sequence_pack_001", "formal_encounter_id": "enc_ch3_escort_clash", "deck_id": "weapon_followup_v0_1_deck_013", "card_id": "", "suggested_action": "needs_balance_adjustment"}, {"severity": "warning", "risk_type": "required_wujing_close_to_cap", "message": "卡牌武境要求接近玩家上限。", "profile_id": "weapon_followup_v0_1", "content_pack_id": "weapon_followup_v0_1_formal_sequence_pack_001", "formal_encounter_id": "enc_ch4_tide_bandits", "deck_id": "weapon_followup_v0_1_deck_014", "card_id": "", "suggested_action": "needs_balance_adjustment"}, {"severity": "warning", "risk_type": "required_wujing_close_to_cap", "message": "卡牌武境要求接近玩家上限。", "profile_id": "weapon_followup_v0_1", "content_pack_id": "weapon_followup_v0_1_formal_sequence_pack_001", "formal_encounter_id": "enc_fishing_village_embers", "deck_id": "weapon_followup_v0_1_deck_002", "card_id": "", "suggested_action": "needs_balance_adjustment"}]`
- rebuild_recommendations: `[{"generated_battle_slot_id": "weapon_followup_v0_1_slot_001", "recommendation": "too_hard", "adjustment": {"target_power_shift": -2, "followup_density_shift": -0.05}}, {"generated_battle_slot_id": "weapon_followup_v0_1_slot_002", "recommendation": "too_hard", "adjustment": {"target_power_shift": -2, "followup_density_shift": -0.05}}, {"generated_battle_slot_id": "weapon_followup_v0_1_slot_003", "recommendation": "too_hard", "adjustment": {"target_power_shift": -2, "followup_density_shift": -0.05}}, {"generated_battle_slot_id": "weapon_followup_v0_1_slot_004", "recommendation": "too_hard", "adjustment": {"target_power_shift": -2, "followup_density_shift": -0.05}}, {"generated_battle_slot_id": "weapon_followup_v0_1_slot_005", "recommendation": "too_hard", "adjustment": {"target_power_shift": -2, "followup_density_shift": -0.05}}]`
- too_hard_candidates: `[{"formal_encounter_id": "enc_beach_ambush", "generated_battle_slot_id": "weapon_followup_v0_1_slot_001", "reason": "low_hp_or_loss"}, {"formal_encounter_id": "enc_fishing_village_embers", "generated_battle_slot_id": "weapon_followup_v0_1_slot_002", "reason": "low_hp_or_loss"}, {"formal_encounter_id": "enc_transport_officer", "generated_battle_slot_id": "weapon_followup_v0_1_slot_003", "reason": "low_hp_or_loss"}, {"formal_encounter_id": "enc_mutiny_camp", "generated_battle_slot_id": "weapon_followup_v0_1_slot_004", "reason": "low_hp_or_loss"}, {"formal_encounter_id": "enc_wakou_boss", "generated_battle_slot_id": "weapon_followup_v0_1_slot_005", "reason": "low_hp_or_loss"}]`
- too_easy_candidates: `[]`
- underused_card_candidates: `[{"card_id": "weapon_followup_v0_1_spearman_early_guard", "usage_count": 0}, {"card_id": "weapon_followup_v0_1_spearman_early_pressure", "usage_count": 0}, {"card_id": "weapon_followup_v0_1_spearman_early_finisher", "usage_count": 0}, {"card_id": "weapon_followup_v0_1_spearman_mid_strike", "usage_count": 0}, {"card_id": "weapon_followup_v0_1_spearman_mid_guard", "usage_count": 0}, {"card_id": "weapon_followup_v0_1_spearman_mid_pressure", "usage_count": 0}, {"card_id": "weapon_followup_v0_1_spearman_mid_focus", "usage_count": 0}, {"card_id": "weapon_followup_v0_1_spearman_mid_finisher", "usage_count": 0}, {"card_id": "weapon_followup_v0_1_spearman_late_strike", "usage_count": 0}, {"card_id": "weapon_followup_v0_1_spearman_late_guard", "usage_count": 0}]`
- overused_card_candidates: `[]`
- reward_mismatch_candidates: `[]`

## 6. prompt_context
```json
{
  "profile_id": "weapon_followup_v0_1",
  "content_pack_id": "weapon_followup_v0_1_formal_sequence_pack_001",
  "generated_at": "2026-05-11T06:16:59.772388+00:00",
  "source_pack_review_path": "data/aigc_battle/generated/review/pack_review_weapon_followup_v0_1__weapon_followup_v0_1_formal_sequence_pack_001.json",
  "source_real_telemetry_snapshot_path": "data/aigc_battle/generated/weapon_followup_v0_1/real_telemetry_snapshot.json",
  "risk_summary": {
    "risk_count": 41,
    "fail_count": 0,
    "warning_count": 26,
    "info_count": 15,
    "risks_by_type": {
      "unused_card_count_present": 1,
      "missing_report": 4,
      "required_wujing_close_to_cap": 15,
      "runtime_primitive_present": 15,
      "unused_card": 5,
      "snapshot_missing": 1
    },
    "risks_by_encounter": {
      "enc_beach_ambush": 2,
      "enc_fishing_village_embers": 2,
      "enc_transport_officer": 2,
      "enc_mutiny_camp": 2,
      "enc_wakou_boss": 2,
      "enc_wuke_spear_trial": 2,
      "enc_wuke_blade_trial": 2,
      "enc_wuke_final_duel": 2,
      "enc_wuke_gu_chengyue": 2,
      "enc_wuke_shen_zhaoye": 2,
      "enc_wuke_qi_heng": 2,
      "enc_ch2_reed_ambush": 2,
      "enc_ch3_escort_clash": 2,
      "enc_ch4_tide_bandits": 2,
      "enc_boss_ext_wakou_leader": 2
    },
    "risks_by_card": {
      "weapon_followup_v0_1_spearman_boss_strike": 1,
      "weapon_followup_v0_1_spearman_boss_guard": 1,
      "weapon_followup_v0_1_spearman_boss_pressure": 1,
      "weapon_followup_v0_1_spearman_boss_focus": 1,
      "weapon_followup_v0_1_spearman_boss_finisher": 1
    },
    "risks_by_deck": {
      "weapon_followup_v0_1_deck_001": 2,
      "weapon_followup_v0_1_deck_002": 2,
      "weapon_followup_v0_1_deck_003": 2,
      "weapon_followup_v0_1_deck_004": 2,
      "weapon_followup_v0_1_deck_005": 2,
      "weapon_followup_v0_1_deck_006": 2,
      "weapon_followup_v0_1_deck_007": 2,
      "weapon_followup_v0_1_deck_008": 2,
      "weapon_followup_v0_1_deck_009": 2,
      "weapon_followup_v0_1_deck_010": 2,
      "weapon_followup_v0_1_deck_011": 2,
      "weapon_followup_v0_1_deck_012": 2,
      "weapon_followup_v0_1_deck_013": 2,
      "weapon_followup_v0_1_deck_014": 2,
      "weapon_followup_v0_1_deck_015": 2
    },
    "top_risks": [
      {
        "severity": "warning",
        "risk_type": "missing_report",
        "message": "缺少审核依赖报告：telemetry_probe_report.json",
        "profile_id": "weapon_followup_v0_1",
        "content_pack_id": "weapon_followup_v0_1_formal_sequence_pack_001",
        "formal_encounter_id": "",
        "deck_id": "",
        "card_id": "",
        "suggested_action": "needs_rebuild"
      },
      {
        "severity": "warning",
        "risk_type": "missing_report",
        "message": "缺少审核依赖报告：sequence_balance_snapshot.json",
        "profile_id": "weapon_followup_v0_1",
        "content_pack_id": "weapon_followup_v0_1_formal_sequence_pack_001",
        "formal_encounter_id": "",
        "deck_id": "",
        "card_id": "",
        "suggested_action": "needs_rebuild"
      },
      {
        "severity": "warning",
        "risk_type": "missing_report",
        "message": "缺少审核依赖报告：runtime_primitive_probe_report.json",
        "profile_id": "weapon_followup_v0_1",
        "content_pack_id": "weapon_followup_v0_1_formal_sequence_pack_001",
        "formal_encounter_id": "",
        "deck_id": "",
        "card_id": "",
        "suggested_action": "needs_rebuild"
      },
      {
        "severity": "warning",
        "risk_type": "missing_report",
        "message": "缺少审核依赖报告：rebuild_from_snapshot_probe_report.json",
        "profile_id": "weapon_followup_v0_1",
        "content_pack_id": "weapon_followup_v0_1_formal_sequence_pack_001",
        "formal_encounter_id": "",
        "deck_id": "",
        "card_id": "",
        "suggested_action": "needs_rebuild"
      },
      {
        "severity": "warning",
        "risk_type": "required_wujing_close_to_cap",
        "message": "卡牌武境要求接近玩家上限。",
        "profile_id": "weapon_followup_v0_1",
        "content_pack_id": "weapon_followup_v0_1_formal_sequence_pack_001",
        "formal_encounter_id": "enc_beach_ambush",
        "deck_id": "weapon_followup_v0_1_deck_001",
        "card_id": "",
        "suggested_action": "needs_balance_adjustment"
      },
      {
        "severity": "warning",
        "risk_type": "required_wujing_close_to_cap",
        "message": "卡牌武境要求接近玩家上限。",
        "profile_id": "weapon_followup_v0_1",
        "content_pack_id": "weapon_followup_v0_1_formal_sequence_pack_001",
        "formal_encounter_id": "enc_boss_ext_wakou_leader",
        "deck_id": "weapon_followup_v0_1_deck_015",
        "card_id": "",
        "suggested_action": "needs_balance_adjustment"
      },
      {
        "severity": "warning",
        "risk_type": "required_wujing_close_to_cap",
        "message": "卡牌武境要求接近玩家上限。",
        "profile_id": "weapon_followup_v0_1",
        "content_pack_id": "weapon_followup_v0_1_formal_sequence_pack_001",
        "formal_encounter_id": "enc_ch2_reed_ambush",
        "deck_id": "weapon_followup_v0_1_deck_012",
        "card_id": "",
        "suggested_action": "needs_balance_adjustment"
      },
      {
        "severity": "warning",
        "risk_type": "required_wujing_close_to_cap",
        "message": "卡牌武境要求接近玩家上限。",
        "profile_id": "weapon_followup_v0_1",
        "content_pack_id": "weapon_followup_v0_1_formal_sequence_pack_001",
        "formal_encounter_id": "enc_ch3_escort_clash",
        "deck_id": "weapon_followup_v0_1_deck_013",
        "card_id": "",
        "suggested_action": "needs_balance_adjustment"
      },
      {
        "severity": "warning",
        "risk_type": "required_wujing_close_to_cap",
        "message": "卡牌武境要求接近玩家上限。",
        "profile_id": "weapon_followup_v0_1",
        "content_pack_id": "weapon_followup_v0_1_formal_sequence_pack_001",
        "formal_encounter_id": "enc_ch4_tide_bandits",
        "deck_id": "weapon_followup_v0_1_deck_014",
        "card_id": "",
        "suggested_action": "needs_balance_adjustment"
      },
      {
        "severity": "warning",
        "risk_type": "required_wujing_close_to_cap",
        "message": "卡牌武境要求接近玩家上限。",
        "profile_id": "weapon_followup_v0_1",
        "content_pack_id": "weapon_followup_v0_1_formal_sequence_pack_001",
        "formal_encounter_id": "enc_fishing_village_embers",
        "deck_id": "weapon_followup_v0_1_deck_002",
        "card_id": "",
        "suggested_action": "needs_balance_adjustment"
      },
      {
        "severity": "warning",
        "risk_type": "required_wujing_close_to_cap",
        "message": "卡牌武境要求接近玩家上限。",
        "profile_id": "weapon_followup_v0_1",
        "content_pack_id": "weapon_followup_v0_1_formal_sequence_pack_001",
        "formal_encounter_id": "enc_mutiny_camp",
        "deck_id": "weapon_followup_v0_1_deck_004",
        "card_id": "",
        "suggested_action": "needs_balance_adjustment"
      },
      {
        "severity": "warning",
        "risk_type": "required_wujing_close_to_cap",
        "message": "卡牌武境要求接近玩家上限。",
        "profile_id": "weapon_followup_v0_1",
        "content_pack_id": "weapon_followup_v0_1_formal_sequence_pack_001",
        "formal_encounter_id": "enc_transport_officer",
        "deck_id": "weapon_followup_v0_1_deck_003",
        "card_id": "",
        "suggested_action": "needs_balance_adjustment"
      }
    ]
  },
  "candidate_schema_path": "data/aigc_battle/llm_prompts/weapon_followup_v0_1__weapon_followup_v0_1_formal_sequence_pack_001__candidate_schema.json"
}
```

## 7. 输出提醒
- 默认 offline mode，只导出候选内容，不调用在线 LLM。
- source 字段请写明来源，例如 `offline_llm_candidate` / `designer_candidate`。
- 所有候选会进入 import / validate / diff / build / export / review / release gate；不合规会被拒绝。
