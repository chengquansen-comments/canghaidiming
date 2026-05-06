# File Size Audit

更新时间：2026-05-06

本报告同步当前代码体积治理状态，用于配合 `docs/CODE_ORGANIZATION.md` 和 `docs/REFACTOR_BACKLOG.md` 做后续小步重构。数据来源为仓库内最近一次 `python3 tools/audit_file_sizes.py --top 80` 结果，以及本轮已确认的 thin wrapper 拆分状态。

## Scope Model

本审计把文件体积风险分成两类：

- **Code risk**：`.gd`、`.py`、shader 等代码文件。严格适用 20KB / 25KB / 35KB 阈值。
- **Content risk**：`data/*.json`、`tables/*.tsv`、Markdown、scene/resource/config 等内容或生成产物。大文件不直接等同于代码风险，应优先治理源表、生成链路或文档结构。

## Thresholds

| Level | Range | Code Action |
|---|---:|---|
| OK | `< 20KB` | 健康范围，可正常迭代。 |
| WARN | `20KB - 25KB` | 新增逻辑前先评估是否抽 helper。 |
| SPLIT_REQUIRED | `25KB - 35KB` | 不继续追加功能，优先拆分或抽 helper。 |
| HIGH_RISK | `>= 35KB` | 高维护风险，只允许 bugfix / 小步拆分 / 兼容 shim。 |

## Current P0 Structural Risk

当前最高优先级不再只是单文件体积，而是：**视觉战斗与大地图 controller 的继承链过深，AI 追踪 super 调用和状态来源的成本升高。**

治理原则：

- 保留现有兼容 wrapper，但不继续新增 controller 继承层。
- 新功能优先进入 helper / runtime / view / formatter / bridge。
- 优先减少高频运行链路中的薄继承层，而不是一次性拉平整条链。
- 禁止为了缩短继承链而整文件合并大 controller。

## Code Action Required

| Size | Level | File | 建议方向 |
|---:|---|---|---|
| 58.2KB | HIGH_RISK | `scripts/compile_tables.py` | 拆出 table loader / validator / writer，主文件只保留 CLI 调度。 |
| 33.9KB | SPLIT_REQUIRED | `tools/render_art_prompt.py` | 拆出 prompt loader / renderer / CLI。 |
| 27.6KB | SPLIT_REQUIRED | `scripts/narrative_demo_strategic_legacy_controller.gd` | 拆出 ending/final gate 文案与奖励 runtime。 |
| 27.0KB | SPLIT_REQUIRED | `scripts/narrative/narrative_demo_controller.gd` | 拆出节点路由与选择处理。 |
| 27.0KB | SPLIT_REQUIRED | `scripts/narrative_battle_context.gd` | 拆出 player profile 与 battle request/result bridge。 |
| 25.7KB | SPLIT_REQUIRED | `scripts/battle_controller_visual_resolver_preview.gd` | 拆出 preview runtime 与 formatter。 |
| 25.4KB | SPLIT_REQUIRED | `scripts/narrative_demo_safe_controller.gd` | 只做兼容收口，新逻辑转 helper/shim。 |

## Code Watch List

| Size | Level | File | 建议方向 |
|---:|---|---|---|
| 24.9KB | WARN | `scripts/narrative_demo_canonical_controller.gd` | 新增逻辑先进 helper。 |
| 24.5KB | WARN | `scripts/battle_controller_visual_presentation_stepwise_exchange.gd` | 继续拆 stepwise 子模块，避免 exchange 层变大。 |
| 22.8KB | WARN | `scripts/narrative_demo_network_map_controller.gd` | 保持 map 调度层，不回填 overlay/runtime/bridge 细节。 |
| 21.4KB | WARN | `scripts/battle_controller_core_deck_builder.gd` | 若加功能，先抽 deck helper。 |
| 21.1KB | WARN | `scripts/battle_controller_visual_cached_ui.gd` | 避免继续堆缓存策略。 |
| 20.5KB | WARN | `tools/art_asset_pipeline.py` | 后续按 loader / processor / exporter 拆。 |

## Cleared Since Previous Audit

这些文件曾在旧风险清单中被列为 P0/P1，但当前已经拆成 thin wrapper 或降到健康范围，不再作为当前阻塞项：

| File | 当前状态 |
|---|---|
| `scripts/battle_controller_core.gd` | 已变为 thin wrapper，真实逻辑拆入 `battle_controller_core_*` 层。 |
| `scripts/battle_controller_visual_ui.gd` | 已变为 thin compatibility entry，真实逻辑拆入 `battle_controller_visual_ui_*` 层。 |
| `scripts/battle_controller_visual_presentation_stepwise.gd` | 已变为 stepwise wrapper，真实逻辑拆入 fx/focus/facing/draft/exchange 层。 |
| `scripts/narrative_demo_ui_focus_tuned_controller.gd` | 已降到约 8.8KB，保持调度层定位。 |
| `scripts/narrative_demo_ui_focus_controller.gd` | 已拆分为 view/runtime/helper 委托结构，约 8.4KB。 |
| `scripts/battle_controller_visual_responsive_ui.gd` | 已降到 13,078 bytes，低于 20KB。 |
| `scripts/battle_controller_visual_presentation.gd` | 已降到 19,368 bytes，低于 20KB。 |

## Data / Document Large Files

`data/*.json`、`tables/*.tsv`、长 Markdown、Godot scene/resource 文件不按 controller 拆分方式处理。治理原则：

- 不直接编辑 `data/*.json`。
- 运行数据以 `tables/*.tsv` 与编译脚本为准。
- 如果内容文件编辑困难，优先拆源 TSV、归档历史文档、或调整编译输出，而不是把数据硬写入 controller。

## Recommended Next Work

1. 先治理继承链 P0：减少 MainVisual 高频链路中的薄继承层，但不整文件合并 controller。
2. 拆 `scripts/compile_tables.py`，因为它是唯一仍超过 35KB 的代码文件。
3. 拆 `tools/render_art_prompt.py`，风险低、收益高。
4. 收口 `scripts/narrative_demo_network_map_controller.gd`：调用 `StrategicNetworkMapRuntime.complete_node()`、`refresh_node_states()`、`sync_mirror_fields()`，删除重复实现。
5. 不再新增 controller 继承层；新功能优先进入 helper / runtime / view / formatter / bridge。

## Validation Commands

```bash
python3 scripts/compile_tables.py
godot --headless --quit --path .
godot --headless --path . --quit scenes/NarrativeDemo.tscn
godot --headless --path . --quit scenes/MainVisual.tscn
git diff --check
python3 tools/audit_file_sizes.py --top 80
```
