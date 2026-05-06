# Refactor TODO

按 `docs/CODE_ORGANIZATION.md` 执行的小步重构清单。
更新时间：2026-05-06（基于 `python3 tools/audit_file_sizes.py --top 80`）。

## 规则（执行时必须遵守）

- [ ] 单次提交只做一类事：新增 helper 或替换一个函数，不做跨职责大改。
- [ ] `>25KB` 文件不继续追加新功能，只做迁移或 bugfix。
- [ ] 不直接编辑 `data/*.json`，改 `tables/*.tsv` 后用 `python3 scripts/compile_tables.py` 生成。
- [ ] 每次迁移后都跑最小验证命令（见文末）。
- [ ] 未完成拆分前，不删除 legacy fallback。

## P0（本周，必须先做）

### 1) `scripts/compile_tables.py`（58.2KB，HIGH_RISK）

- [ ] 新增 `scripts/table_compile_loader.py`：只负责 TSV/JSON 输入加载。
- [ ] 新增 `scripts/table_compile_validator.py`：只负责 schema/字段校验。
- [ ] 新增 `scripts/table_compile_writer.py`：只负责输出与写盘。
- [ ] `compile_tables.py` 仅保留 CLI 参数解析 + 调度。
- [ ] 每次只迁移 1 个函数，确保编译产物不变。

### 2) `tools/render_art_prompt.py`（33.9KB，SPLIT_REQUIRED）

- [ ] 新增 `tools/art_prompt_loader.py`（清单与模板读取）。
- [ ] 新增 `tools/art_prompt_renderer.py`（渲染与替换逻辑）。
- [ ] 新增 `tools/art_prompt_cli.py`（参数、输出、错误码）。
- [ ] 主脚本保留兼容入口，避免中断现有命令。

## P1（两周内，优先拆分）

### 3) `scripts/narrative_demo_ui_focus_controller.gd`（33.8KB）

- [x] 抽离 Focus UI 纯渲染逻辑到 `scripts/narrative/focus_ui_view.gd`。
- [x] 抽离状态推进到 `scripts/narrative/focus_ui_runtime.gd`。
- [x] 控制器只保留路由与调度。

### 4) `scripts/battle_controller_visual_responsive_ui.gd`（33.6KB）

- [x] 抽离布局计算到 `scripts/visual/responsive_layout_helper.gd`。
- [x] 抽离节点绑定/刷新到 `scripts/visual/responsive_ui_bindings.gd`。
- [x] 保持原交互行为不变（仅职责迁移）。

### 5) `scripts/battle_controller_visual_presentation.gd`（30.5KB）

- [x] 抽离演出队列构建到 `scripts/visual/presentation_queue_builder.gd`。
- [x] 抽离文案格式化到 `scripts/visual/presentation_text_formatter.gd`。
- [x] 控制器仅保留时序调度与入口。

### 6) `scripts/narrative_demo_strategic_legacy_controller.gd`（27.6KB）

- [ ] 抽离 ending/final gate 文案到 `scripts/narrative/strategic_ending_formatter.gd`。
- [ ] 抽离奖励计算到 `scripts/narrative/strategic_reward_runtime.gd`。
- [ ] legacy controller 降到 `<25KB`。

### 7) `scripts/narrative/narrative_demo_controller.gd`（27.0KB）

- [ ] 抽离节点路由到 `scripts/narrative/narrative_route_runtime.gd`。
- [ ] 抽离选择处理到 `scripts/narrative/narrative_choice_runtime.gd`。

### 8) `scripts/narrative_battle_context.gd`（27.0KB）

- [ ] 抽离 player profile 构造到 `scripts/narrative/battle_profile_builder.gd`。
- [ ] 抽离 battle request/result 转换到 `scripts/narrative/battle_context_bridge.gd`。

### 9) `scripts/battle_controller_visual_resolver_preview.gd`（25.7KB）

- [ ] 抽离 preview 数据组装到 `scripts/visual/resolver_preview_runtime.gd`。
- [ ] 抽离 preview 文案输出到 `scripts/visual/resolver_preview_formatter.gd`。

### 10) `scripts/narrative_demo_safe_controller.gd`（25.4KB）

- [ ] 只做兼容层收口，不新增流程逻辑。
- [ ] 将新增逻辑改投到独立 helper/shim。

## P2（观察与预防）

- [ ] `scripts/narrative_demo_canonical_controller.gd`（24.9KB）：新增逻辑先进 helper。
- [ ] `scripts/battle_controller_visual_presentation_stepwise_exchange.gd`（24.5KB）：继续拆 stepwise 子模块。
- [ ] `scripts/narrative_demo_network_map_controller.gd`（22.8KB）：保持 map 调度层，不回填细节逻辑。
- [ ] `scripts/battle_controller_core_deck_builder.gd`（21.4KB）：若加功能，先抽 deck helper。
- [ ] `scripts/battle_controller_visual_cached_ui.gd`（21.1KB）：避免继续堆缓存策略。
- [ ] `tools/art_asset_pipeline.py`（20.5KB）：后续按 loader/processor/exporter 拆。

## 已完成并保持不回退

- [x] `narrative_demo_ui_focus_tuned_controller.gd` 已降到 8.8KB，保持“调度层”定位。
- [x] `strategic_network_map_runtime/formatter/battle_bridge/view/generator` 已拆分，后续功能优先进入这些小文件。
- [x] `narrative_demo_ui_focus_controller.gd` 已拆分为 view/runtime/helper 委托结构，控制器降到 8.4KB。

### 2026-05-06 验收记录（武举线 -> 大地图）

- [x] 验收通过：武举线走完后可正常进入海疆大地图。
- [x] 回归根因：`focus_ui_runtime.gd` 内部直接调用 runtime `_advance_to_node()`，绕开 tuned controller 对 `world_map_entry` 的 override。
- [x] 修复方式：改为 `c._advance_to_node(c.node_index + 1, "")`，恢复经控制器分发的节点推进链路。

### 2026-05-06 验收记录（responsive UI 控制器拆分）

- [x] 验收通过：`battle_controller_visual_responsive_ui.gd` 已降到 `13,078` bytes，低于 `20KB`。
- [x] 拆分结果：布局计算迁到 `scripts/visual/responsive_layout_helper.gd`，节点绑定/刷新迁到 `scripts/visual/responsive_ui_bindings.gd`，catalog 构建迁到 `scripts/visual/responsive_catalog_helper.gd`。
- [x] 行为约束：原交互链路保持不变，控制器保留调度与 preview 结算入口。
- [x] 回归修复：helper 中对 `reward_pool` 的整体赋值改为 `clear + append_array`，恢复 typed 属性初始化兼容性。

### 2026-05-06 验收记录（battle presentation 控制器拆分）

- [x] 验收通过：`battle_controller_visual_presentation.gd` 已降到 `19,368` bytes，低于 `20KB`。
- [x] 拆分结果：演出请求/顺序/side result 迁到 `scripts/visual/presentation_queue_builder.gd`，招式风格/命中文案/颜色/停顿迁到 `scripts/visual/presentation_text_formatter.gd`。
- [x] 额外收口：浮字、火器闪光、未中拖影、破势 FX、势点动画迁到 `scripts/visual/presentation_fx_view.gd`。
- [x] 行为约束：控制器保留时序调度、入口、Tween 调用衔接和兼容 wrapper，原交互行为保持不变。

## 每次提交验收

```bash
python3 scripts/compile_tables.py
godot --headless --quit --path .
godot --headless --path . --quit scenes/NarrativeDemo.tscn
godot --headless --path . --quit scenes/MainVisual.tscn
git diff --check
python3 tools/audit_file_sizes.py --top 80
```

## 提交命名模板

- [ ] `Add <module> helper`
- [ ] `Use <helper> for <single function>`
- [ ] `Move <formatter/runtime/bridge> out of <controller>`
- [ ] `Shrink <file> below 25KB`
