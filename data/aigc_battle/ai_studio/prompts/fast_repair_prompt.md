# fast_repair_prompt

- prompt_type: `fast_repair`
- mechanic_profile_id: `weapon_followup_v0_1`
- sequence_template_id: `formal_sequence_12_fast_v1`
- source_pack_id: `weapon_followup_v0_1__formal_sequence_12_fast_v1__hardened_013`
- recommended_release_mode: `fast_run`

输出要求：
- 只能输出 candidates JSONL。
- 不允许输出 runtime_manifest。
- 不允许输出 active_profile。
- 不允许输出 Godot 代码。
- 不允许使用 unsupported effect。
- 必须遵守 sequence_template + mechanic_profile + build_variant 契约。
- 必须遵守武境 / 收式 / 双武器 / clue_pressure / weapon_followup 校验规则。

生成目标：
- 聚焦 fast-run 平均回合数略高问题，优先降低拖长而不破坏 weapon_followup 可见性。

