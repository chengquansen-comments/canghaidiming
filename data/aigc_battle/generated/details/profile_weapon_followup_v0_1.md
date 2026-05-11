# 机制包明细：weapon_followup_v0_1

- display_name: 武器追击机制
- version: 0.1.0
- active_pack_id: weapon_followup_v0_1_formal_sequence_pack_001
- target_sequence_id: formal_sequence_mvp_v1
- replacement_mode: full_sequence
- runtime_primitives: weapon_followup
- allowed_runtime_effects: damage, gain_block, gain_momentum, break_momentum
- 是否有武境/收式限制: 是

## 这套机制能支持什么
- resources: hp, posture, block
- card_types: attack, defense, skill
- weapon_styles: spearman, blademaster

## content packs
- weapon_followup_v0_1_formal_sequence_pack_001 | mode=profile_root | active=true | export=true
- snapshot_pack_id_required | mode=profile_pack_dir | active=false | export=true
- weapon_followup_ai_candidate_pack_001 | mode=profile_pack_dir | active=false | export=true
- weapon_followup_ai_candidate_pack_probe_001 | mode=profile_pack_dir | active=false | export=true
- weapon_followup_ai_candidate_pack_probe_002 | mode=profile_pack_dir | active=false | export=true
- weapon_followup_eval_rebuild_001 | mode=profile_pack_dir | active=false | export=true
- weapon_followup_eval_rebuild_002 | mode=profile_pack_dir | active=false | export=true
- weapon_followup_eval_rebuild_003 | mode=profile_pack_dir | active=false | export=true
- weapon_followup_real_rebuild_001 | mode=profile_pack_dir | active=false | export=true
