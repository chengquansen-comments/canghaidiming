# Dungeon Pool Validation Report

## Summary
- progression_template: `data/aigc_battle/progression_templates/dungeon_progression_v1_3.json`
- content_pool_pack: `data/aigc_battle/generated/dungeon_progression_v1_3/packs/dungeon_pool_pack_001`
- all_checks_passed: `true`
- prologue_slot_count: `1`
- wuju_slot_count: `5`
- big_map_normal_candidate_count: `10`
- big_map_elite_candidate_count: `5`
- rare_event_candidate_count: `2`

## Checks
- `prologue_fixed_battle_count=pass` actual=`1` expected=`1`
- `wuju_fixed_battle_count=pass` actual=`5` expected=`5`
- `big_map_battle_count_target=pass` actual=`15` expected=`15`
- `big_map_battle_count_min=pass` actual=`14` expected=`14`
- `big_map_battle_count_max=pass` actual=`16` expected=`16`
- `big_map_candidate_pool_target=pass` actual=`30` expected=`30`
- `normal_route_target_total=pass` actual=`22` expected=`22`
- `true_route_target_total=pass` actual=`23` expected=`23`
- `wuzhuangyuan_route_target_total=pass` actual=`26` expected=`26`
- `martial_realm_max=pass` actual=`10` expected=`10`
- `lightness_max=pass` actual=`4` expected=`4`
- `normal_lightness_cap=pass` actual=`2` expected=`2`
- `no_fixed_linear_sequence=pass` actual=`True` expected=`True`
- `route_choice_required=pass` actual=`True` expected=`True`
- `all_battle_slot_enemy_deck_refs_exist=pass` actual=`[]` expected=`[]`
- `all_battle_slot_reward_plan_refs_exist=pass` actual=`[]` expected=`[]`
- `all_reward_card_refs_exist_or_placeholder_allowed=pass` actual=`[]` expected=`[]`
- `operation_node_pool_exists=pass` actual=`9` expected=`>0`
- `existing_big_map_adapter_fields_exist=pass` actual=`[]` expected=`[]`
- `current_release_unchanged=pass` actual=`c79c57cd675fb0a50767ce9101a73ad42df70b981a4b55cf552babbbe577341c` expected=`c79c57cd675fb0a50767ce9101a73ad42df70b981a4b55cf552babbbe577341c`
- `active_profile_matches_current_release=pass` actual=`{'active_mechanic_profile_id': 'weapon_followup_v0_1', 'active_content_pack_id': 'weapon_followup_v0_1__formal_sequence_12_fast_v1__release_drill_005', 'runtime_manifest_path': 'data/aigc_battle/generated/weapon_followup_v0_1/packs/weapon_followup_v0_1__formal_sequence_12_fast_v1__release_drill_005/runtime_manifest.json'}` expected=`{'mechanic_profile_id': 'weapon_followup_v0_1', 'content_pack_id': 'weapon_followup_v0_1__formal_sequence_12_fast_v1__release_drill_005', 'runtime_manifest_path': 'data/aigc_battle/generated/weapon_followup_v0_1/packs/weapon_followup_v0_1__formal_sequence_12_fast_v1__release_drill_005/runtime_manifest.json'}`
- `fallback_release_unchanged=pass` actual=`32d8518870cf647df997d4ff8493b8891c996ced87fbd6d7e28beb47bbe06803` expected=`32d8518870cf647df997d4ff8493b8891c996ced87fbd6d7e28beb47bbe06803`
