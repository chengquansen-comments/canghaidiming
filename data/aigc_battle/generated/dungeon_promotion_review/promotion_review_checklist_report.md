# AIGC Dungeon Promotion Review Checklist

## Gate Summary

- `promotion_review_checklist_ready=True`
- `pipeline_pass=True`
- `route_content_probe_pass=True`
- `save_bridge_probe_pass=True`
- `candidate_manifest_ready=True`
- `candidate_not_promoted=False`
- `candidate_promoted=True`
- `candidate_promotion_state_consistent=True`
- `manual_review_required=True`
- `set_current_not_allowed_by_candidate=False`
- `current_release_is_dungeon=True`
- `content_pool_target_counts_ready=True`
- `current_release_unchanged=True`
- `active_profile_unchanged=True`
- `active_profile_matches_current_release=True`
- `fallback_release_unchanged=True`
- `scene_unchanged=True`
- `combat_core_untouched=True`
- `blocking_items_ready_for_manual_decision=True`
- `review_report_pass=True`

## Pool Summary

- `battle_slot_count=45`
- `big_map_normal_candidate_count=20`
- `big_map_elite_candidate_count=8`
- `rare_event_candidate_count=3`
- `enemy_deck_count=36`
- `reward_plan_count=34`
- `card_count=38`

## Checklist

- `content_experience_review` 内容体验确认：`needs_human_review`，owner=`design`。normal / elite / rare 池已达到目标下限，三路线关键战斗已闭合。
  决策点：确认敌人风格、奖励节奏、武状元考试口径是否符合项目叙事。
- `technical_gate_review` 技术闸门确认：`pass`，owner=`engineering`。D10-D15 pipeline_pass=true，route content probe_pass=true，save bridge probe_pass=true。
- `release_guard_review` 发布保护确认：`pass`，owner=`engineering`。candidate_status=generated_not_promoted，set_current_allowed=false，current / active / fallback 未变。
- `save_scope_review` 存档范围确认：`needs_human_review`，owner=`design_engineering`。Formal save slot bridge payload 已生成，但未接用户存档 UI。
  决策点：确认下一步是正式存档系统接入，还是继续只用 bridge payload 验证。
- `ending_scope_review` 结局收束确认：`needs_human_review`，owner=`design`。D11 已写 ending reward closure 与 final node ending_result。
  决策点：确认是否进入结局演出 / 奖励收束强化，或先 promotion candidate。

## Next Decision Options

- 继续做结局演出 / 奖励收束强化
- 继续做正式存档系统接入
- 进入人工 promotion 审批后再 set-current
