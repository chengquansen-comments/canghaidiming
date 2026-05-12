# AIGC Battle Pipeline

## v1 目标

当前 v1 目标是 `Full Formal Battle Sequence Replacement`：用 `posture_basic_v0_1` 的 generated content pack 覆盖当前正式流程里的全部正式战斗节点，不接受单场替换、mini run 或 debug-only 终点。

## 职责边界

- `Mechanic Profile`：声明当前 runtime 真正支持的资源、效果、卡牌和牌组约束。
- `Content Recipe`：声明目标正式序列、替换模式和生成规则。
- `Content Pack`：生成 `cards / enemy_decks / battle_slots / rewards / formal_sequence_mapping`。
- `Runtime Manifest`：只保留 Godot 运行时需要读取的对象。
- `Active Profile`：只声明当前激活的 profile、pack 和 runtime manifest 路径。

## coverage 基准

`formal_sequence_inventory.generated.json` 是 v1 coverage 基准。它从 `tables/narrative_mvp_nodes.tsv` 的正式战斗引用抽取 formal encounter 清单，再与 `story_encounters` 对齐。validator 以它为唯一覆盖标准。

## validator gate

validator 是 v1 的 coverage gate：

- formal inventory 不能为空。
- 每个 formal encounter 都必须有 generated mapping。
- `full_sequence_coverage_complete=true` 才能导出 runtime manifest。
- fallback 只能保底，不能参与 v1 验收通过。

## Godot 侧

Godot 只读 `active_profile.json` 和 `runtime_manifest.json`。正式流程解析 battle loadout 时优先命中 generated manifest，未命中时才回落到 `StoryBattleLoader`。

## 当前 v1 已完成项

- formal sequence inventory 生成
- profile/recipe/content pack 构建
- coverage validator
- runtime manifest 导出
- active profile 切换
- formal encounter 级别的 generated loadout probe

## 下一步

v2 补 full sequence reward / progression closure。

## v2 奖励闭环

v2 目标是 `full sequence reward / progression closure`：

- generated reward 从 `runtime_manifest` 读取
- formal battle 命中 generated manifest 后，reward 随 loadout 一起进入结算层
- 胜利后展示 generated reward，并以确认动作视为领取
- fallback 只保底，不参与 v2 PASS

当前限制：

- 当前 probe 验证的是 loader、loadout、结算桥和可观测字段，不是完整自动通关脚本

## v3：Full Sequence Balance Pass
- v3 目标：full sequence balance pass。
- battle_slot / deck / reward 增加 sequence_position、encounter_tier、encounter_kind、target_power_range、reward_tier。
- validator 新增 balance gate，要求全序列 deck power 落入目标区间，后段平均强于前段，boss 强于 late / elite。
- export runtime_manifest 依赖 sequence_balance_pass=true，并写入 balance_summary。
- 当前仍不做复杂模拟，不新增战斗机制。

## v4：Full Sequence Mechanic Profile Switch
- v4 目标：full sequence mechanic profile switch。
- 新增 `posture_tuned_v0_1b`，与 `posture_basic_v0_1` 一样覆盖完整 formal sequence。
- `active_profile.json` 是唯一切换入口，Godot loader 保持 profile-agnostic。
- A/B 两套 content_pack、runtime_manifest、generated 目录必须隔离。
- build / validate / export / switch / probe 必须串行执行，禁止并行。

## v5：Mechanic Diff + Full Sequence Rebuild Policy
- v5 目标：mechanic diff + full sequence rebuild policy。
- `change_type` 五类：`no_change` / `value_rebalance` / `partial_regeneration` / `full_sequence_regeneration` / `not_runtime_playable`。
- runtime 不支持的 design effect 不能进入 playable `runtime_manifest`。
- validate / export 现在会用 policy gate 阻止不可运行内容进入 runtime。
- build / validate / export / switch / probe / diff 必须串行执行，禁止并行。

## v6：LLM Candidate Import for Full Sequence Pack
- v6 目标：LLM candidate import for full sequence pack。
- 当前不调用在线 LLM，只导入本地 JSONL candidate fixture。
- LLM candidates 不能绕过 validator / export / runtime gate。
- invalid candidates 必须被拒绝，不能进入 playable runtime_manifest。
- build / import / validate / export / switch / probe 必须串行执行，禁止并行。
- v6 结束后 active_profile 默认切回 `posture_basic_v0_1`。

## v7
- v7 目标：Real New Runtime Mechanic for Full Sequence。
- 新增 opening_pressure runtime primitive。
- opening_pressure 是 battle_slot/loadout primitive，不是 card effect。
- 15 个 formal encounter 都必须带 opening_pressure。
- validator / export / loader / apply / probe 都必须支持 opening_pressure。
- 如果不能真实应用，不允许伪造 PASS。
- build / validate / export / switch / probe 必须串行执行，禁止并行。

## v8
- v8 目标：Full Sequence Telemetry + Rebuild Loop。
- telemetry 是轻量 JSONL，不是复杂埋点平台。
- snapshot 只做异常标记和最小调参，不做机器学习。
- rebuild 读取 snapshot 后，仍必须通过 coverage / reward / balance / runtime primitive gate。
- build / validate / export / switch / probe / telemetry / rebuild 必须串行执行，禁止并行。

## 武境 / 收式卡组合法性修复
- 新增武境 / 收式卡组合法性硬校验，规则声明在 `mechanic_profile.json`。
- `content_recipe.json` 负责声明玩家武境曲线，并为 battle_slot 生成 `player_wujing_cap`。
- build / import 先做前置过滤，禁止超武境招式牌进入 deck。
- `validate_content_pack.py` 是硬门禁，缺失 `required_wujing` / `closing_form_tier` 或超过 `player_wujing_cap` 都直接失败。
- `export_runtime_manifest.py` 是二次门禁，不允许违规内容导出 runtime。
- Godot loader 不负责内容合法性校验，只读取已通过 validator 的 manifest。
- build / import / validate / export / switch / probe 必须串行执行，禁止并行。

## v9
- v9 只做游戏外查看和切换，不做游戏内 UI。
- `build_aigc_content_index.py` 生成统一内容索引、Markdown 总览和本地静态 HTML dashboard。
- `aigc_external_profile_switch.py` 是唯一推荐的手动切换入口，必须复用现有校验门禁后再写 `active_profile.json`。
- 不做单场 override，不允许直接编辑 generated 文件或绕过校验切 active。
- index / validate / switch / probe 必须串行执行，禁止并行。

## v9
- v9 只做游戏外查看和切换，不做游戏内 UI。
- 外部 dashboard 现在支持 profile / content_pack 双键查看与切换。
- `data/aigc_battle/generated/{profile_id}/` 视为 root pack，`packs/{content_pack_id}/` 支持同一 profile 下多内容包。
- 浏览器点击切换必须运行 localhost server；静态 HTML 只读。
- 切换仍走安全 gate，不允许直接编辑 generated 文件或传任意 runtime_manifest 路径。
- index / validate / switch / probe / server check 必须串行执行，禁止并行。

## v9.2
- 外部控制台支持机制包明细和内容包明细。
- 机制包明细展示 mechanic_profile / content_recipe 的规则摘要。
- 内容包明细展示 pack 总览、整体卡池、formal encounter → battle_slot → deck → cards → reward → runtime primitive。
- Pack 层整体卡池展示使用情况、未使用卡、orphan card、武境/收式信息。
- 明细页只读，不允许编辑 generated 文件；切换仍走安全 switch。
- index / detail / server / probe 必须串行执行，禁止并行。

## v10
- v10 是外部控制台审核工作台，不再只是 detail JSON 浏览器。
- Review 数据优先来自 v9.2 的 detail JSON；detail 缺失时只标记 missing_detail，不直接改 generated 内容。
- 审核工作台支持 Pack 对比、整局节奏、Formal Encounter 链路表、单场战斗设计卡、整体卡池表、Deck 行为表、Reward 表、Risk Board、审核报告导出。
- 风险聚合只用于审核排序和策划判断，不替代 validator gate。
- 控制台仍然只读展示 generated 内容；切换仍然只能走 safe switch API。
- `build_aigc_review_workspace.py` / `aigc_dashboard_review_probe.py` 都必须串行执行，禁止并行。

## P1
- P1 是 Production Console。
- 控制台支持审核、备注、生产、快照、验证、导出、切换、回滚、冻结、release candidate、归档。
- 所有写操作必须走 localhost server 或安全 CLI，不能让浏览器直接写 generated JSON。
- Review Notes 独立存储在 `data/aigc_battle/review_notes/`，不修改 generated 内容。
- Release Manifest 独立存储在 `data/aigc_battle/release/`，不修改 generated 内容。
- Pack Factory / switch / rollback / freeze / archive / probe 全部必须串行执行，禁止并行。

## P2
- P2 是 Playable Mechanic Loop。
- 新增 `weapon_followup_v0_1` 机制包，目标是把可生产内容推进到真实玩家可感机制。
- `weapon_followup` 是真实战斗 primitive，不是只做链路验证的 metadata。
- full sequence 15 场 formal encounter 必须覆盖 followup card / deck / battle_slot runtime metadata。
- validator / export / loader / runtime apply / telemetry / dashboard 都要理解 `weapon_followup`。
- real telemetry 至少记录 `turn_count` / `hp_delta` / `card usage` / `weapon_followup_trigger_count`，不允许继续停留在全 `minimal`。
- `build_real_telemetry_snapshot.py` 负责从实战 JSONL 生成规则化平衡建议，不做机器学习。
- `build-from-real-telemetry` 读取 snapshot 后做最小调参，再走 validate / export / review 刷新。
- 旧 profile 在无 followup 字段时行为必须保持兼容。
- build / validate / export / switch / telemetry / rebuild / probe 必须串行执行，禁止并行。

## R1
- R1 是 Playable AI Release。
- R1 目标是让游戏正式流程默认体验 AI release pack，而不是只在控制台里可切包。
- Release Channel 分为 `current` / `candidate` / `fallback` / `archived`；`current` / `candidate` / `fallback` 独立存储在 `data/aigc_battle/release_channels/`。
- 正式流程仍只读取 `data/aigc_battle/runtime/active_profile.json`；R1 通过 `activate-current` 把 `current_release` 安全切到 `active_profile`，不在 Godot 运行时引入双入口。
- `fallback` 只用于 rollback，不能掩盖 `current_release` smoke 失败。
- formal entry smoke test 必须证明玩家走的是正式 narrative / formal battle entry，不是 debug-only，也不是 mini route。
- `set-current` / `set-candidate` / `set-fallback` / `activate-current` / `rollback-to-fallback` / smoke / probe 都必须串行执行，禁止并行。
- R1 推荐 `current_release = weapon_followup_v0_1 / weapon_followup_v0_1_formal_sequence_pack_001`。
- R1 推荐 `fallback_release = posture_opening_pressure_v0_1 / posture_opening_pressure_v0_1_formal_sequence_pack_001`。

## R2
- R2 是 Mechanic Content Expansion。
- R2 新增 `clue_pressure_v0_1`：线索破防；新增 `martial_realm_7_dual_weapon_v0_1`：七境双武器。
- `clue_pressure_v0_1` 不是完整嘴遁 UI，而是可生成、可校验、可导出、可 runtime observable 的最小线索破防 primitive。
- `martial_realm_7_dual_weapon_v0_1` 不是简单数值扩展，而是七境曲线、双武器 deck、主副武器比例和高境卡合法性一起进 validator gate。
- 两套新机制都必须生成 full sequence 15 场正式内容包，并通过 validate / export / review / probe。
- 两套新机制都必须 runtime observable；Godot 正式流程至少要暴露 clue pressure / wujing cap / dual weapon loadout 的 last_* 字段。
- 两套新机制只进入 release candidate，不自动替换 current release。
- current release 保持 `weapon_followup_v0_1 / weapon_followup_v0_1_formal_sequence_pack_001`。
- fallback release 保持 `posture_opening_pressure_v0_1 / posture_opening_pressure_v0_1_formal_sequence_pack_001`。
- 控制台和 review 需要能看到 mechanic compare matrix。
- R2 不做 `firearm_pressure` / `command_pressure`。
- build / validate / export / candidate / smoke / probe / compare matrix 都必须串行执行，禁止并行。

## R3
- R3 是 Real Evaluation Loop。
- R3 不再满足于 partial telemetry / probe pass，而是要求基于 deterministic headless evaluation 形成可审、可比较、可重建的评估闭环。
- `aigc_headless_evaluation_runner.py` 负责 multi-pack evaluation，默认覆盖 `current release`、`candidate`、`clue_pressure`、`fallback`，并写入统一 `evaluation event schema` JSONL。
- `source=headless_eval`、`result_source=deterministic_headless`、`telemetry_detail_level` 都必须真实标记；不允许 fake real。
- R3 支持 `turn_count` / `hp_delta` / `card usage` / `runtime primitive trigger` / `win_rate` / `avg_turn_count` / `reward_claim_rate` 等 pack 与 encounter 级指标。
- `build_real_evaluation_snapshot.py` 负责把 event、runtime manifest、reward、compare matrix 汇总成 Balance Snapshot 2.0。
- `build_rebuild_recommendations.py` 负责把 snapshot 转成可执行 recommendation；高风险项必须 `requires_designer_review=true`。
- `aigc_build_from_evaluation_snapshot.py` 只应用 `safe_to_auto_apply=true` 的 recommendation，生成新的 reviewing pack，不自动切 current。
- current release、candidate release、fallback release 与 active_profile 都不能被 evaluation / rebuild 自动改写。
- dashboard / review workspace / compare matrix 需要显示 evaluation summary、actionability score、needs_rebuild 与 rebuild recommendation 信息。
- evaluation 不等于 release gate，但必须为 release / rebuild 决策提供依据。
- eval / snapshot / recommendation / rebuild / probe / regression 都必须串行执行，禁止并行。

## R4
- R4 是 Playable Balance Release。
- R4 使用 R3 的 evaluation snapshot 与 rebuild recommendations 修正当前 `weapon_followup` release 偏难问题，不新增机制，也不接在线 LLM。
- `resolve_rebuild_recommendation_conflicts.py` 负责移除同一 encounter 的升强 / 降强冲突建议；当 pack 全局偏难时，不允许再保留 `increase_deck_power`。
- `aigc_build_balance_release.py` 基于 resolved recommendations 生成新的 balanced pack，只应用安全可自动落地的调优，不允许手工硬改 runtime manifest。
- balanced pack 必须重新跑 evaluation；只有 `playable_balance_gate_pass=true` 才允许 `accepted -> freeze -> release candidate -> set-current -> activate-current`。
- fallback release 继续保持 `posture_opening_pressure_v0_1`，只用于 rollback，不允许掩盖 balanced pack 失败。
- previous current release 必须可 rollback；如果 balanced current smoke 失败，必须回滚到 previous current 或 fallback。
- dashboard / review workspace / compare matrix 需要显示 `balance_release`、`source_pack_id`、`source_vs_balanced_delta`、`playable_balance_gate_pass` 与 balance release API。
- R4 的 build / validate / export / evaluate / release / smoke / rollback / probe 全部必须串行执行，禁止并行。

## R5
- R5 是 Sequence Template + Mechanic Pack Binding Contract。
- content pack 的来源契约必须显式化为 `sequence_template_id + mechanic_profile_id + build_variant = content_pack_id`。
- sequence template 负责定义战斗数量、阶段分布、遭遇类型、目标 power、奖励曲线、武境曲线与 mechanic density 曲线；mechanic profile 只负责玩法机制内容。
- 默认正式模板是 `formal_sequence_15_v1`，必须兼容现有 current release；验证模板 `formal_sequence_12_fast_v1` 用于证明 encounter count 与 stage pacing 可配置，但不自动切 current。
- build / validate / export / evaluation / review / release channel 都必须带上 `sequence_template_id`、`build_variant` 与 `pack_identity` 字段。
- `pack_resolver.json` 负责把 current / candidate / fallback / review / archived channel 与 pack identity 绑定起来。
- current release 继续保持 `weapon_followup_v0_1 / weapon_followup_balance_release_007`，只补齐 `sequence_template_id=formal_sequence_15_v1` 与 `build_variant=balance_release_007` 的契约信息。
- formal12fast 生成的 `weapon_followup_v0_1__formal_sequence_12_fast_v1__baseline_001` 只作为 candidate/review pack 验证模板可调，不自动替换 current。
- R5 的 validate / plan / build / export / evaluation / resolver / probe 全部必须串行执行，禁止并行。
## R6：Template Portfolio Release Strategy

- R6 将 R5 的 sequence template 配置能力推进为多模板组合库。
- 新增 `bossrush_9_v1` 与 `elite_heavy_15_v1`，并与既有 `formal_sequence_15_v1`、`formal_sequence_12_fast_v1` 共同组成 template portfolio。
- 同一个 `weapon_followup_v0_1` 机制可在不同模板下生成不同节奏的候选 pack。
- portfolio build / validate / export / evaluation 全部走串行脚本，不允许并行。
- R6 输出 `template_portfolio_summary`、`template_portfolio_evaluation_report`、`template_release_strategy`。
- current release 保持 `weapon_followup_v0_1 / weapon_followup_balance_release_007`，不自动切换。
- 新模板包只进入 `review` 或 `candidate` 观察状态，不自动 activate。

## R7：Mechanic × Template Matrix

- R7 将单机制多模板推进为多机制 × 多模板矩阵。
- 交叉机制：`weapon_followup_v0_1`、`clue_pressure_v0_1`、`martial_realm_7_dual_weapon_v0_1`。
- 交叉模板：`formal_sequence_15_v1`、`formal_sequence_12_fast_v1`、`bossrush_9_v1`。
- 输出 `matrix_build_report`、`matrix_evaluation_report`、`matrix_release_strategy`。
- current release 保持 `weapon_followup_v0_1 / weapon_followup_balance_release_007 / formal_sequence_15_v1` 不变。
- matrix pack 只进入 `matrix_review` / `review` 观察层，不自动 set-current，不自动 activate。
