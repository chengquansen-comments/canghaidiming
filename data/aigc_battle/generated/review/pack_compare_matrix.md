# Pack 对比矩阵

- pack_count: `12`
- strongest_pack_by_avg_power: `posture_tuned_v0_1b::posture_tuned_v0_1b_formal_sequence_pack_001`
- most_risky_pack: `weapon_followup_v0_1::weapon_followup_ai_candidate_pack_001`
- healthiest_pack: `posture_opening_pressure_v0_1::posture_opening_pressure_v0_1_formal_sequence_pack_001`
- weakest_pack_by_avg_power: `posture_basic_v0_1::posture_basic_v0_1_formal_sequence_pack_001`

| Active | Profile | Pack | Health | Score | Avg Power | Risk | Unused | Runtime Primitives |
| --- | --- | --- | --- | ---: | ---: | ---: | ---: | --- |
|  | `posture_basic_v0_1` | `posture_basic_v0_1_formal_sequence_pack_001` | `warning` | 43 | 38.65 | 26 | 5 | `-` |
|  | `posture_llm_candidate_v0_1` | `posture_llm_candidate_v0_1_formal_sequence_pack_001` | `warning` | 43 | 38.65 | 27 | 5 | `-` |
|  | `posture_opening_pressure_v0_1` | `posture_opening_pressure_v0_1_formal_sequence_pack_001` | `warning` | 58 | 38.65 | 37 | 5 | `opening_pressure` |
|  | `posture_opening_pressure_v0_1` | `posture_opening_pressure_p1_probe_snapshot_001` | `warning` | 58 | 38.65 | 38 | 5 | `opening_pressure` |
|  | `posture_opening_pressure_v0_1` | `posture_opening_pressure_p1_probe_snapshot_002` | `warning` | 58 | 38.65 | 38 | 5 | `opening_pressure` |
|  | `posture_opening_pressure_v0_1` | `posture_opening_pressure_snapshot_001` | `warning` | 58 | 38.65 | 38 | 5 | `opening_pressure` |
|  | `posture_tuned_v0_1b` | `posture_tuned_v0_1b_formal_sequence_pack_001` | `warning` | 21 | 41.09 | 37 | 5 | `-` |
| YES | `weapon_followup_v0_1` | `weapon_followup_v0_1_formal_sequence_pack_001` | `warning` | 43 | 39.03 | 41 | 5 | `weapon_followup` |
|  | `weapon_followup_v0_1` | `weapon_followup_ai_candidate_pack_001` | `fail` | 39 | 39.19 | 46 | 5 | `weapon_followup` |
|  | `weapon_followup_v0_1` | `weapon_followup_ai_candidate_pack_probe_001` | `fail` | 39 | 39.19 | 46 | 5 | `weapon_followup` |
|  | `weapon_followup_v0_1` | `weapon_followup_ai_candidate_pack_probe_002` | `fail` | 39 | 39.19 | 46 | 5 | `weapon_followup` |
|  | `weapon_followup_v0_1` | `weapon_followup_real_rebuild_001` | `warning` | 45 | 39.03 | 41 | 5 | `weapon_followup` |
