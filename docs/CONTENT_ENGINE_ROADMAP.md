# Content Engine Roadmap

## 总体结构

Content Engine 建议按六层推进：

1. 基础数字层：维护 `progression_numeric_config_v1_3.tsv` 等来源数字。
2. 派生结构层：生成 battle slot、enemy requirement、route curve、operation node requirement。
3. 内容骨架层：生成 archetype 池、deck skeleton、奖励骨架、节点骨架。
4. 内容实例层：在骨架约束下填具体卡牌、敌人卡组、奖励与叙事节点。
5. 校验与采样层：validator + 自动采样报告，持续约束质量。
6. 运行时导出层：把 design 表转为运行时配置，不直接改战斗核心逻辑。

## v0.1 已完成

当前设计层输出：

- `data/design/generated_battle_slot_plan.tsv`
- `data/design/generated_enemy_deck_requirement.tsv`
- `data/design/generated_route_progression_curve.tsv`

## v0.1.1 本次新增

本阶段新增：

- `data/design/generated_operation_node_requirement.tsv`

结果是“经营节点占比 30%-40%”从文档约束升级为设计层表约束，可被 builder 生成并被 validator 检查。

## v0.2 本次新增

本阶段新增：

- `data/design/generated_enemy_archetype_pool.tsv`

该输出是敌人类型骨架池，只定义 archetype、战斗定位、复杂度、距离偏好、检查点和建议 deck 变体数量，不生成具体卡组与具体卡牌。

## v0.3 本次新增

本阶段新增：

- `data/design/generated_enemy_deck_skeleton.tsv`

该输出是敌人卡组骨架，只定义 deck skeleton ID、变体定位、卡组规模、卡牌角色计数、武器标签约束、禁用标签、AI 行为提示和奖励压力级别。

v0.3 仍不填具体 `card_id`，不生成正式敌人 deck，不生成正式卡牌，不修改 Godot 战斗运行时，也不接入 LLM API。

## 后续阶段边界

### v0.2 enemy_archetype_generator

- 只生成 `generated_enemy_archetype_pool.tsv`。
- 不生成具体卡组。
- 输入至少读取 battle slot + operation node 两类结构。

### v0.3 enemy_deck_skeleton_generator

- 生成 deck 骨架（slot、role 比例、武器约束）。
- 不直接填完整卡牌。
- 输出 `generated_enemy_deck_skeleton.tsv`，作为 v0.4 具体卡池与敌人 deck set 的输入。

### v0.4 card_pool / enemy_deck_sets

v0.4 建议拆分为两个子阶段：

- v0.4a `card_pool_generator`：先生成设计层可用卡池 `generated_card_pool.tsv`。
- v0.4b `enemy_deck_sets_generator`：再根据 deck skeleton 与 card pool 填充具体敌人 deck set。

v0.4a / v0.4b 都应保持设计层边界，不直接修改运行时战斗代码。

v0.4b 的输出建议为 long-form：`generated_enemy_deck_sets.tsv`（一行一张卡），同时保留 `selection_score` / `selection_reason`，便于 validator 和后续调参。

### v0.5 reward / operation / narrative / route gate

v0.5 建议拆分：

- v0.5a `battle_reward_generator`：先生成战斗奖励规划表。
- v0.5b `operation_node_generator`：先补经营节点池与代价规则。
- v0.5c `narrative_node_generator`：生成叙事骨架与 hook 标签。
- v0.5d `route_gate_generator`：汇总路线门槛与触发条件。

本阶段继续保持设计层，不改战斗运行时。

#### v0.5c 当前落地

- 新增输出：`data/design/generated_narrative_node_plan.tsv`
- 输入来源：operation node / battle reward / route curve / battle slot
- 仅生成结构化 narrative skeleton，不写正式正文
- 约束：`should_write_body=false`、`line_budget<=1`、`preview_key/result_key` 分离
- 输出标签可直接作为 v0.5d route gate 汇总输入

#### v0.5d 当前落地

- 新增输出：`data/design/generated_route_gate_plan.tsv`
- 聚合来源：battle reward / operation node / narrative node
- 统一生成 normal / true_route / wuzhuangyuan / lightness / boss_prepare 路线门槛
- 处理 true_route 与 wuzhuangyuan 条件并发时的玩家选择 gate
- 继续保持设计层，不改 Godot 运行时逻辑

### v0.6a content package manifest

- 新增 `generated_content_package_manifest.tsv`。
- 统一登记 design-layer artifact、依赖、row count、checksum、validator 状态和 runtime blockers。
- 继续保持设计层，不导出 runtime data。

### v0.6b content package report

- 基于 manifest 生成 `generated_content_package_report.md`。
- 汇总数量、依赖、风险、validator 状态和 runtime blockers。
- 为人工批准和 runtime exporter 做准备。

### v0.6c validator orchestration

- 统一运行所有现有 validators。
- 将 manifest 中的 `NOT_RUN` 尽量收敛为 `PASS` / `WARN` / `FAIL`。
- 产出统一的 validator summary，作为人工批准前置条件。
- 当前先输出独立 summary，不直接回写 validated manifest。

### v0.6d content package approval

- 在 manifest / report / validator summary 基础上做人审批准。
- 新增 approval table，默认不自动批准任何 artifact。
- 仅允许被明确批准的 artifact 进入后续 runtime exporter 候选集。

### v0.7a runtime schema proposal

- 定义 runtime artifact 目标结构、字段映射和导出策略。
- 输出 schema proposal，不写 runtime data。
- 当前因无 approved artifact，export_allowed_now 保持 false。

### v0.7b runtime export dry-run

- 基于 approval + schema proposal 模拟导出候选和 blocker。
- 必须同时读取 manifest + validator summary + approval + schema proposal。
- 输出 `generated_runtime_export_dry_run.tsv` 与 `generated_runtime_export_dry_run.md`。
- 不写 runtime 文件，只产出可执行计划。

### v0.7c manual approval overlay

- 改为 manual approval overlay / waiver process（仍在 design layer）。
- 新增 `runtime_export_approval.tsv` 人工审批表和 overlay 结果表。
- 允许生成最小可控 `would_export=true` 候选，但不实现 runtime exporter，不写 runtime 文件。

### v0.7d runtime export diff report

- 基于 `generated_runtime_export_approval_overlay.tsv` 生成计划导出差异报告。
- 只评估 would_export=true 候选与 blocked 记录，不写 runtime 文件。
- 产出 `generated_runtime_export_diff_report.tsv` 与 `generated_runtime_export_diff_report.md` 用于审查风险。

### v0.8 runtime exporter

- runtime exporter 必须读取 manifest / report / validator summary / approval / schema proposal / overlay 结果。
- 只允许导出 validator PASS 且人工批准且 waiver 已清理的 artifact。
- 仍然不直接改战斗核心结算逻辑。

### v0.8a runtime exporter scaffold

- 新增 runtime exporter scaffold，默认 no-write preview。
- 输入 `generated_runtime_export_diff_report.tsv`，仅筛选 allowed planned_create 候选。
- 产出 `generated_runtime_exporter_plan.tsv` 与 `generated_runtime_exporter_plan.md`。
- `--write-runtime` 在本阶段禁用，不创建 `data/runtime/content_engine/`。

### v0.8b runtime exporter guarded write mode

- 默认 no-write 仍是安全默认；不带参数运行不得创建 `data/runtime/content_engine/`。
- 真实写入必须同时提供 `--write-runtime --confirm-runtime-export`。
- 写入候选严格来自 `generated_runtime_exporter_plan.tsv` 的 allowed planned_create 记录。
- 仅允许写入白名单 runtime 文件：
  - `data/runtime/content_engine/card_pool.json`
  - `data/runtime/content_engine/battle_reward.json`
- 产出新增 `generated_runtime_exporter_write_result.tsv` 与 `generated_runtime_exporter_write_result.md`。
- v0.8b 只写 runtime content files，不接入 Godot runtime loader，不修改 Godot 运行时逻辑。

### v0.8c runtime manifest / checksum / rollback report

- 在 v0.8b runtime 写入结果基础上新增 runtime 文件治理层。
- 产出 `data/runtime/content_engine/runtime_manifest.json`。
- 产出 `generated_runtime_export_manifest_report.tsv` 与 `generated_runtime_export_manifest_report.md`。
- 产出 `generated_runtime_export_rollback_report.md`，用于明确回滚步骤与重跑顺序。
- manifest 仅登记白名单 runtime 文件（`card_pool.json` / `battle_reward.json`），并校验 `sha256` 与 `file_size_bytes`。
- v0.8c 不接入 Godot loader；loader preflight/read-only loader 放到 v0.8d 或 v0.9 再评估。

### v0.8d Godot loader preflight report（analysis-only）

- 基于 `runtime_manifest.json` + runtime files + manifest report 生成 preflight 报告。
- 新增 `generated_runtime_loader_preflight_report.tsv` 与 `generated_runtime_loader_preflight_report.md`。
- 明确 manifest-first / failure mode / fallback source / future touchpoints 建议，但不实现 loader。
- 不新增任何 `.gd` loader 文件，不修改现有 Godot 运行时逻辑文件。

### v0.8e read-only Godot loader scaffold

- 新增 `scripts/content_engine_runtime_loader.gd` 作为独立只读 scaffold。
- loader 仅做 manifest-first 校验与只读解析，失败时 fail-closed。
- 不接入主流程，不替换正式 card/reward 数据源。
- 输出 `generated_runtime_loader_scaffold_report.tsv` 与 `generated_runtime_loader_scaffold_report.md`。
- integration_status 保持 `not_integrated`。


### v0.8f Godot loader probe / headless-only harness

- 新增 `tools/content_engine/content_engine_loader_probe.gd`（headless-only probe）。
- 通过 `runtime_loader_godot_probe.py` 调用 Godot 并解析 stdout marker JSON。
- 产出 `generated_runtime_loader_godot_probe_report.tsv` 与 `generated_runtime_loader_godot_probe_report.md`。
- 保持 `integration_status=not_integrated`，不接入主流程，不替换正式数据源。


### v0.8g negative-case / fixture tests

- 新增 runtime loader negative fixtures（位于 `data/design/`，不污染正式 runtime）。
- 覆盖 checksum/fingerprint/unknown file/unsafe path/malformed JSON/domain-count mismatch 等异常。
- 产出 `generated_runtime_loader_negative_fixture_report.tsv` 与 `generated_runtime_loader_negative_fixture_report.md`。
- 目标是验证 fail-closed，不接入正式 loader。


### v0.8h CI-friendly regression runner

- 新增统一回归入口：`content_engine_regression_runner.py`。
- 将 v0.7b -> v0.8g 验收链路收束为 step 化执行与报告输出。
- 产出 `generated_content_engine_regression_report.tsv` 与 `generated_content_engine_regression_report.md`。
- no-write 语义升级为“preview 不改变正式 runtime 文件”，不再要求 runtime 目录必须不存在。

### v0.8i CI / workflow draft

- 新增 CI/workflow draft（文档 + workflow 模板），用于稳定运行 content engine regression。
- 核心命令固定为：
  - `python3 tools/content_engine/content_engine_regression_runner.py`
  - `python3 tools/content_engine/content_engine_regression_validator.py`
- 允许将 Godot headless 检查作为 optional job（当 CI 环境已安装 Godot 时启用）。
- v0.8i 不新增 runtime 功能，不接入正式 loader，不替换 card/reward 正式数据源。

### v0.9a read-only integration gate

- 新增 `runtime_loader_config.json` 与独立 gate scaffold（`content_engine_runtime_gate.gd`）。
- gate 默认 `disabled`，只做只读配置/目录/manifest 检查，异常时 fail-closed。
- 不接入战斗主流程，不替换正式 card/reward 数据源，不修改战斗逻辑文件。
- 新增 gate probe/validator 与 gate report（TSV/MD）。

### v0.9b battle_reward single-domain read-only compare

- 新增 `runtime_battle_reward_compare.py` 与 validator。
- compare 输入来自 runtime manifest/config/battle_reward，以及 legacy/design reward source。
- 仅处理 `battle_reward` 单 domain；`card_pool` 保持 out_of_scope。
- 输出差异报告供评估，不替换正式奖励逻辑，不接入战斗主流程。
- legacy source not_found/ambiguous 可记录为非阻塞 compare 结果。

### v0.9 auto battle sampler integration

- 接入自动战斗采样。
- 输出 balance report 并回写设计建议。

## AI 协作边界

- AI 不直接决定数量。
- AI 只填派生出来的结构坑位。
- Validator 先于运行时。
- Runtime exporter 最后做。
- 单一阶段内，不允许同时改 `CardData`、`combat_resolver`、`battle_state_machine`、`data/story_battles/*.tsv`。
