# bossrush_repair_prompt

- prompt_type: `bossrush_repair`
- mechanic_profile_id: `weapon_followup_v0_1`
- sequence_template_id: `bossrush_9_v1`
- source_pack_id: `weapon_followup_v0_1__bossrush_9_v1__hardened_007`
- recommended_release_mode: `bossrush`

输出要求：
- 只能输出 candidates JSONL。
- 不允许输出 runtime_manifest。
- 不允许输出 active_profile。
- 不允许输出 Godot 代码。
- 不允许使用 unsupported effect。
- 必须遵守 sequence_template + mechanic_profile + build_variant 契约。
- 必须遵守武境 / 收式 / 双武器 / clue_pressure / weapon_followup 校验规则。

生成目标：
- 聚焦 bossrush 胜率过高与 too_long 略高问题，保持高压而非降成普通局。

