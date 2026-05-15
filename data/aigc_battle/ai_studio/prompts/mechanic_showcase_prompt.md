# mechanic_showcase_prompt

- prompt_type: `mechanic_showcase`
- mechanic_profile_id: `clue_pressure_v0_1`
- sequence_template_id: `bossrush_9_v1`
- source_pack_id: `clue_pressure_v0_1__bossrush_9_v1__matrix_001`
- recommended_release_mode: `showcase`

输出要求：
- 只能输出 candidates JSONL。
- 不允许输出 runtime_manifest。
- 不允许输出 active_profile。
- 不允许输出 Godot 代码。
- 不允许使用 unsupported effect。
- 必须遵守 sequence_template + mechanic_profile + build_variant 契约。
- 必须遵守武境 / 收式 / 双武器 / clue_pressure / weapon_followup 校验规则。

生成目标：
- 为 clue_pressure / martial_realm_7_dual_weapon 准备机制展示型 candidates，只能输出 candidates JSONL。

