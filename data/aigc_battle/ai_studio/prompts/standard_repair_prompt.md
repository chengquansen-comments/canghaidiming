# standard_repair_prompt

- prompt_type: `standard_repair`
- mechanic_profile_id: `weapon_followup_v0_1`
- sequence_template_id: `formal_sequence_15_v1`
- source_pack_id: `weapon_followup_balance_release_007`
- recommended_release_mode: `standard_run`

输出要求：
- 只能输出 candidates JSONL。
- 不允许输出 runtime_manifest。
- 不允许输出 active_profile。
- 不允许输出 Godot 代码。
- 不允许使用 unsupported effect。
- 必须遵守 sequence_template + mechanic_profile + build_variant 契约。
- 必须遵守武境 / 收式 / 双武器 / clue_pressure / weapon_followup 校验规则。

生成目标：
- 修正标准正式包的内容候选，但不能直接产出 runtime_manifest 或 active_profile。

