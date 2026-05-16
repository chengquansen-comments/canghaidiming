# AIGC Battle Production Contract

## 当前正式生产路径

- current_release: `weapon_followup_v0_1 / weapon_followup_v0_1__formal_sequence_12_fast_v1__release_drill_005 / formal_sequence_12_fast_v1 / release_drill_005`
- current formal encounter count: `12`
- previous_current / rollback candidate: `weapon_followup_v0_1 / weapon_followup_balance_release_007 / formal_sequence_15_v1 / balance_release_007`
- fallback_release: `posture_opening_pressure_v0_1 / posture_opening_pressure_v0_1_formal_sequence_pack_001`

## 唯一合法链路

1. build
2. validate
3. export
4. preview
5. acceptance
6. human review
7. promotion
8. release switch
9. smoke
10. rollback

## Schema Manifest 摘要

- frozen schemas: `acceptance_report, active_profile, current_release, fallback_release, human_review_note, pack_resolver_entry, preview_profile, promotion_report, release_switch_report`
- prohibited fields: `arbitrary_runtime_manifest_path, arbitrary_current_release_path, arbitrary_active_profile_path, shell_command, external_url, unsafe_file_path`

## Generated File Policy 摘要

- must_commit count: `11`
- commit_when_stage_delivered count: `14`
- local_or_cleanable count: `5`
- never_overwrite_without_gate count: `6`

## Minimal Acceptance Command

- `python3 tools/aigc_battle/build_pack_resolver.py`
- `python3 tools/aigc_battle/aigc_acceptance_run.py --profile weapon_followup_v0_1 --pack weapon_followup_v0_1__formal_sequence_12_fast_v1__release_drill_005 --samples 1 --allow-current`
- `python3 tools/aigc_battle/aigc_release_switch_smoke_probe.py --profile weapon_followup_v0_1 --pack weapon_followup_v0_1__formal_sequence_12_fast_v1__release_drill_005`
- `python3 tools/aigc_battle/aigc_preview_restore_probe.py`
- `python3 tools/aigc_battle/aigc_candidate_promotion_probe.py`
- `python3 tools/aigc_battle/aigc_release_rollback_probe.py`
- `git diff --check`

## 串行执行要求

- 所有 active_profile / current_release 相关脚本必须串行执行。
- 禁止并行跑 acceptance / preview / promotion / release switch。

## 禁止事项

- 不直接写 runtime_manifest。
- 不直接写 current_release。
- 不绕过 acceptance。
- 不绕过 promotion。
- 不并行跑 active_profile 相关脚本。

## 后续扩展规则

- 新机制必须接 schema。
- 新模板必须接 resolver。
- 新候选必须过 acceptance。
- 新 release 必须过 promotion + release switch。

## R15 单目标演练补充

- R15 允许围绕单个非 current 包执行 `Single Candidate Release Drill`。
- drill 必须继续遵守唯一合法链路：
  - `build -> validate -> export -> preview -> acceptance -> human review -> promotion -> release switch(dry-run 默认) -> smoke -> rollback`
- R15 默认只允许 `dry-run switch`，不允许真实 `set-current`；真实切换必须显式传 `--allow-actual-switch`。
- 即使 drill 成功，若没有显式真实切换，`current_release` 与 `active_profile` 也必须保持当前正式版本不变。
- 若 acceptance 得到 `needs_balance` 或 human review 不是 `accepted`，drill 只能停在 partial，不允许 promotion。
- 任何 release drill 包都必须来自已存在 pack 的受控派生，不允许跳过 validate / export / acceptance 直接写入 release channel。

## R16 正式落地补充

- R16 允许把已经完成 `release drill -> acceptance -> human review -> promotion` 的目标包真正切为 `current`。
- R16 只能通过 `aigc_release_switch_console.py` 执行 `set-current`，不能直接写 `current_release.json` 或 `active_profile.json`。
- R16 必须继续遵守唯一合法链路：
  - `acceptance -> promotion -> release switch -> smoke -> gameplay verification -> post-switch acceptance`
- R16 成功后：
  - `current_release` 与 `active_profile` 都必须指向新 current
  - `fallback_release` 不能变化
  - previous current 必须仍可作为 rollback target
- 若 formal entry smoke 或 post-switch acceptance 失败，必须立即 rollback previous current。
- R16 默认不扩系统，只验证真实 cutover 与 gameplay entry 是否读取新 current。

## R17 生产收口补充

- R17 只做 `Production Closeout`，不再新增机制、模板、pack 或新的主链功能。
- R17 的正式 current 已固定为：
  - `weapon_followup_v0_1 / weapon_followup_v0_1__formal_sequence_12_fast_v1__release_drill_005 / formal_sequence_12_fast_v1 / release_drill_005`
- `weapon_followup_balance_release_007` 现在是 previous current / rollback candidate，不再显示为 active current。
- `fallback_release` 继续保持 `posture_opening_pressure_v0_1 / posture_opening_pressure_v0_1_formal_sequence_pack_001`。
- R17 只允许清理 `deprecated_probe_inventory.json` 中明确列为 `safe_to_delete_now` 的 `local_cleanable` 项；不能清理 current/fallback/active/release/acceptance/promotion/release switch 主链文件。
- R17 收口后，后续建议转入：
  - 玩家体验调优
  - 线索破防机制实装
  - 七境双武器正式玩法
  - AI 内容质量提升
- 所有 `active_profile / current_release / preview / release switch` 相关脚本仍必须串行执行，禁止并行。

## D1 Dashboard 展示层补充

- D1 只优化 dashboard 的展示逻辑，不改变任何生产 gate。
- dashboard 现在必须能一眼区分：
  - current
  - previous current
  - fallback
  - release candidate
  - ready for review
  - needs balance
  - ai_studio review
  - matrix review
- dashboard 只允许新增只读汇总 API，不允许新增写接口。
- `current_release.json` / `active_profile.json` / `runtime_manifest.json` 仍不能由 dashboard 直接写入。
- `weapon_followup_balance_release_007` 作为 previous current / rollback candidate 保留可见性，但不再显示为 active current。

## D2 Dashboard 交互收口

- D2 已补齐搜索、状态筛选、详情联动、复制 pack_id、Reports 折叠。
- dashboard 仍保持只读，不新增 POST，不新增 current / preview / promotion / release switch 写操作。
- dashboard 优化线阶段性收口，后续仍以只读生产态可视化为边界。

## D3 Dashboard 总览收口

- D3 已把 Pack 列表与 Pack 对比合并进总览主表。
- D3 新增 `profileStatus / Profile / Template` 本地筛选，dashboard 仍保持只读。

## D4 Dashboard 选择态统一

- D4 已完成 Dashboard 单一 `selected pack` 状态源。
- 总览选择会同步运行态 / 审核 / 卡池 / 卡组 / 详情 / Timeline / Risk。
- 点击 Current / Active 可回到当前正式包。
- 旧 Pack Compare 兼容占位已删除，dashboard 仍保持只读，不提供 current / preview / promotion / release switch 写操作。

## A3 Dashboard 一级页签重组

- Dashboard 一级页签已调整为：`总览 / 运行态 / Pack 详情 / 时间线与风险 / 管理动作`。
- 管理动作页仍默认只读，`--admin-write` 后才启用按钮。
- Dashboard 写操作仍只允许通过 `/api/admin/*`，不直接写 `current_release / active_profile / runtime_manifest`。

## A4 Dashboard Pack 内容页

- Dashboard 新增 `Pack 内容` 一级页签，用于查看 selected pack 的战斗序列、每场战斗、敌人卡组、奖励与总卡池。
- `Pack 内容` 页保持只读；管理动作继续集中在 `管理动作` 页签，禁止直接写 `runtime_manifest / current_release / active_profile`。

## Deprecated Probe Inventory 摘要

- active_required_count: `4`
- deprecated_candidate_count: `12`
- historical_report_count: `290`
- local_cleanable_count: `2`

## DUNGEON-1 Contract Addendum

- 已新增 `data/aigc_battle/progression_templates/dungeon_progression_v1_3.json`。
- 已新增 `data/aigc_battle/generated/dungeon_progression_v1_3/packs/dungeon_pool_pack_001/` skeleton pool pack。
- Dungeon 副本规则以 `progression_template + content_pool_pack` 为主，不再以 fixed sequence 作为主模型。
- content pool 必须离线校验通过后才能进入后续 `map_instance / node materialized loadout` 流程。
- DUNGEON-1 不允许修改 `current_release / active_profile / fallback_release`，也不接入 Godot runtime。

## DUNGEON-2 Contract Addendum

- 已新增离线 `map_instance / route_state_initial / big_map_compatible` 产物，用于 existing big map adapter 验证。
- DUNGEON-2 不以全图节点总数代表单局长度；必须使用 sampled route metrics 校验 big map 路径长度与战斗结构。
- DUNGEON-2 的战斗节点必须携带唯一 `story_beat_id`，并保留实例化后的 `title / preview_text / result_text`，不得再把 compatible map 压平成共享槽文案。
- `big_map_compatible` 必须保真导出 `story_beat_id` 与战斗强度字段，不允许统一写成 0 或泛化结果文本。
- DUNGEON-2 仍不允许修改 `current_release / active_profile / fallback_release`。
- DUNGEON-2 仍未接入 Godot runtime，不改 scene，不改 battle core。

## DUNGEON-3 Contract Addendum

- 已新增离线 `selected_node_materialized_loadout / battle_entry_request / route_state_after_choice` 产物。
- battle node 必须解析到 `battle_slot / enemy_deck / reward_plan`，operation node 必须解析到 `operation_node`。
- battle entry request 仍必须兼容现有 `encounter_id / battle_id / combat_pool_id` bridge 契约。
- battle entry request 额外保留 `source_story_beat_id`，用于把战斗返回结果绑定回唯一剧情事件。
- DUNGEON-3 仍不允许修改 `current_release / active_profile / fallback_release`。
- DUNGEON-3 仍未接入 Godot runtime，不改 scene，不改 battle core。

## DUNGEON-4 Contract Addendum

- 已新增 Dashboard `Pack 内容 / 地图实例` 只读视图。
- `Pack 内容` 页展示 `content_pool_pack` 候选池。
- `地图实例` 页展示 `map_instance / route_state / selected_node_materialized_loadout / battle_entry_request`。
- DUNGEON-4 仍不允许修改 `current_release / active_profile / fallback_release`。
- DUNGEON-4 仍未接入 Godot runtime，不改 scene，不改 battle core。

## DUNGEON-5 Contract Addendum

- 已新增 AIGC dungeon loader 与 Godot headless probe，用于只读加载 `big_map_compatible network_map`。
- AIGC dungeon 节点选择后仍必须走现有 `encounter_id / battle_id / combat_pool_id` battle bridge 契约。
- DUNGEON-5 不重做大地图 UI，不改 scene，不改 battle core。
- DUNGEON-5 仍不允许修改 `current_release / active_profile / fallback_release`。

## DUNGEON-6 Contract Addendum

- 已新增 route branch evaluator 与 Godot headless route branching probe。
- normal / true / wuzhuangyuan 多路线同时满足时必须由玩家选择，不得自动决策。
- `route_branch` 必须通过原大地图节点与 `available_node_ids` 表达，不重做 UI。
- DUNGEON-6 仍不允许修改 `current_release / active_profile / fallback_release`。
- DUNGEON-6 仍不改 scene，不改 battle core，不扩完整正式内容池。

## DUNGEON-7 Contract Addendum

- 已新增轻量 `route_state` snapshot / restore 与 multi-step runtime drill probe。
- `visited_path_order`、`selected_ending_route`、`route_flags` 必须在 restore 后保持不丢失。
- restore 后必须能继续通过原大地图 runtime 推进，不得回退到 fixed sequence。
- DUNGEON-7 仍不允许修改 `current_release / active_profile / fallback_release`。
- DUNGEON-7 仍不改 scene，不改 battle core；本轮不等于正式完整存档系统。

## DUNGEON-8 Contract Addendum

- 已新增 AIGC dungeon formal save bridge，用于 `route_state` 到 save payload 的最小 export / import / validate。
- `wuzhuangyuan` 路线 restore 后必须保持 `selected_ending_route=wuzhuangyuan`，并能继续进入后续 exam path。
- true 路线 save / restore regression 不得被本轮 bridge 破坏。
- DUNGEON-8 仍不允许修改 `current_release / active_profile / fallback_release`。
- DUNGEON-8 仍不改 scene，不改 battle core；本轮仍不是完整用户存档 UI。

## DUNGEON-9 Contract Addendum

- 已新增 normal / true / `wuzhuangyuan` 三路线关键 battle endpoint 的最小正式内容闭环。
- route endpoint 必须闭合到 `battle_slot / enemy_deck / reward_plan / card refs / encounter_id / battle_id / combat_pool_id`。
- route endpoint 的 `enemy_martial_level / recommended_martial_min / recommended_martial_max` 不得继续为 `0`。
- DUNGEON-9 仍不允许修改 `current_release / active_profile / fallback_release`。
- DUNGEON-9 仍不改 scene，不改 battle core；本轮仍不是完整内容池扩容。

## DUNGEON-10 至 DUNGEON-15 Contract Addendum

- DUNGEON-10 允许扩充离线 content pool，但必须保持 `supports_map_instance=true` 与 `supports_fixed_sequence=false`。
- DUNGEON-11 的结局收束只写数据与报告，不新增 scene，不接演出系统。
- DUNGEON-12 的 formal save slot bridge 只生成 generated payload，不写用户 save slot UI。
- DUNGEON-13 的 release candidate manifest 只能是 candidate，不得 `set-current`。
- DUNGEON-14 的 QA matrix 必须覆盖 normal / true / `wuzhuangyuan` 与 save / restore 回归。
- DUNGEON-15 的 promotion dry-run 必须验证 current / active / fallback 未变，并把 promotion 保持为人工动作。

## DUNGEON Final Promotion Contract Addendum

- Dungeon runtime entry 必须由 `current_release + active_profile` 同时指向 `dungeon_progression_v1_3 / dungeon_pool_pack_001` 才可启用。
- `scripts/aigc_dungeon_big_map_loader.gd` 不得再仅凭 generated map 文件存在而抢占大地图入口。
- promotion 必须先写 backup，再写 `current_release / active_profile / fallback_release`，并生成 promotion result 与 final lock report。
- fallback 必须指向 promotion 前的旧 current release，rollback drill 必须能模拟恢复旧 active profile。
- post-promotion 必须通过 route content、save bridge、Godot big map probe。

## DUNGEON-16 Contract Addendum

- formal save slot store 允许写入 `user://aigc_dungeon/save_slots/*.json`，但不得新增存档 UI 或 scene。
- slot payload 必须包裹 `aigc_dungeon_save_v0_1` save payload，并通过 existing network_map validation。
- restore 后必须能继续通过原大地图 runtime 推进，不得回退 fixed sequence。
- DUNGEON-16 仍不改 battle core，不改 scene，不修改 release channel。

## DUNGEON-17 Contract Addendum

- strategic network map flow runtime 可暴露无 UI 的 `save_dungeon_route_slot / restore_dungeon_route_slot`。
- runtime restore 必须重建可选下一节点，避免从旧 graph state 恢复后丢失 available route。
- save / restore runtime controls 不得直接切 scene，不得写 release channel。
- 后续存档 UI 只能调用该 runtime control 层，不得绕过 save slot validation。

## DUNGEON-18 Contract Addendum

- save / load UI 入口只能作为现有大地图 overlay 的动态控件出现，不得新增 scene。
- 动态按钮只允许调用 `save_dungeon_route_slot / restore_dungeon_route_slot`，不得直接写 route_state 或 save 文件。
- 非 AIGC dungeon `network_map` 不显示 dungeon save / load 控件。
- DUNGEON-18 仍不改 battle core，不修改 release channel。

## DUNGEON-19 Contract Addendum

- entry smoke 必须覆盖 release gate、AIGC map load、overlay render、available nodes、save/load button callback。
- 保存 / 读取入口必须通过正式 save slot runtime，并验证 restore 后可继续推进。
- entry smoke 不得新增 scene，不得直接调用 battle core，不得修改 release channel。

## DUNGEON-20 至 DUNGEON-24 Contract Addendum

- full play loop 必须覆盖 `battle request -> NarrativeBattleContext result -> network battle return -> route_state update`。
- normal / true / `wuzhuangyuan` 终点节点必须写入 `ending_result`，并保持玩家选择路线不被系统覆盖。
- route target battle count 必须保持 normal=22、true=23、`wuzhuangyuan`=26。
- full play loop probe 必须进入 final release lock report；不得新增 scene，不得修改 battle core。
