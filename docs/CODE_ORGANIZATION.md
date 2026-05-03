# 代码组织原则

本文档定义《大明之沧海嘀鸣》项目的代码文件体积、职责拆分、AI 协作和重构提交原则。目标是让 Godot/GDScript 项目在 GitHub 远端读写、Codex/ChatGPT 辅助修改、人工 review 和后续维护中保持低风险、可定位、可逐步演进。

## 一、核心原则

1. 单个 `.gd` 脚本建议控制在 **25KB 以下**。
2. 文件超过 **20KB** 时，应开始评估是否需要拆分职责。
3. 文件超过 **25KB** 时，原则上不再继续追加功能，应优先拆分或抽 helper。
4. 文件超过 **35KB** 时，视为高维护风险文件，需要进入重构计划。
5. 大型 controller 不应继续堆积 UI、状态机、战斗桥接、数据生成、debug 入口等多种职责。
6. 新功能优先进入小型专职文件，而不是继续追加到已有大 controller。
7. 远端 AI 修改应优先选择小文件、helper 文件、shim 文件或 scene 引用调整，避免整文件替换大文件。

## 二、为什么控制 25KB

25KB 不是运行性能限制，而是工程协作和工具链安全边界。

单文件过大后会带来以下问题：

- GitHub 远端文件读取容易被工具截断。
- AI 工具无法安全进行整文件替换。
- 小改动也需要提交整文件，误删后半段风险高。
- 函数职责混杂，问题定位困难。
- Review 成本升高，无法快速判断改动边界。
- UI、状态、战斗、debug、数据生成容易互相污染。
- 后续重构时难以保证行为不被破坏。

因此，项目采用“**小文件、单职责、逐步迁移**”作为默认工程策略。

## 三、文件体积分级

| 文件大小 | 建议处理 |
|---|---|
| `< 15KB` | 健康范围，可正常迭代。 |
| `15KB - 20KB` | 可接受，但新增功能时要注意职责边界。 |
| `20KB - 25KB` | 警戒范围，应评估拆分 helper / formatter / runtime。 |
| `25KB - 35KB` | 不建议继续追加功能，应优先重构。 |
| `> 35KB` | 高风险文件，应进入拆分计划，避免远端整文件修改。 |

## 四、职责拆分原则

当一个文件同时承担以下多种职责时，应拆分：

```text
入口控制
UI 渲染
状态推进
战斗请求
战斗返回
final gate
debug profile
数据生成
文本格式化
校验逻辑
资源加载
```

推荐职责边界：

| 职责 | 推荐文件类型 |
|---|---|
| 流程调度 | controller |
| 纯 UI 绘制 | view |
| Overlay / 面板组合 | overlay |
| 状态推进 | runtime / state helper |
| 数据生成 | generator |
| 文案格式化 | formatter |
| 战斗请求与返回 | bridge |
| Debug 入口 | debug_entry / shim |
| 校验与摘要 | validator / generator 内部 helper |

controller 只做调度，不应长期承载大量细节逻辑。

## 五、海疆大势图推荐结构

海疆大势图相关逻辑应逐步拆成以下结构：

```text
scripts/strategic_network_map_generator.gd
```

只负责生成 `network_map` graph：层数、节点、连线、节点池抽样、debug fallback、生成校验、summary。

```text
scripts/strategic_network_map_runtime.gd
```

只负责 graph 状态推进：

```text
find_node
node_by_id
valid_available_ids
has_available_node
ensure_selected_node
complete_node
refresh_node_states
clear_pending
sync_mirror_fields
```

```text
scripts/strategic_network_map_view.gd
```

只负责绘制网络图：节点、连线、状态颜色、点击检测、标题、图例、坐标适配。

```text
scripts/strategic_network_map_overlay.gd
```

可后续新增。只负责 overlay UI：左侧地图、右侧 preview、底部按钮和状态栏。

```text
scripts/strategic_network_map_formatter.gd
```

可后续新增。只负责 preview 和 final gate 文案格式化：节点类型、effects、tags、combat debug、状态提示。

```text
scripts/strategic_network_battle_bridge.gd
```

可后续新增。只负责战斗桥接：combat_pool fallback、pending 保存、进入 `MainVisual`、战斗返回消费。

```text
scripts/narrative_demo_ui_focus_tuned_controller.gd
```

最终只保留 NarrativeDemo 调度职责：进入大地图、调用 overlay、调用 runtime、保存上下文、与旧 flow 兼容。

## 六、拆分方式

不要一次性大拆。采用小步迁移：

```text
1. 先新增小 helper 文件。
2. 不立即接入主流程，先保证 helper 独立可读。
3. 每次只替换 controller 中一个函数。
4. 每替换一个函数就运行验证。
5. 旧函数确认无引用后再删除。
6. 大文件降到安全范围前，不继续往里面追加功能。
```

推荐迁移顺序：

```text
find_node
valid_available_ids
has_available_node
ensure_selected_node
complete_node
refresh_node_states
clear_pending
preview formatter
final gate formatter
combat bridge
overlay renderer
```

每次迁移都应保持行为不变，只改变职责归属。

## 七、提交粒度

每个 commit 尽量只做一类事情。

推荐：

```text
Add strategic network map runtime helper
Use runtime helper for network find_node
Use runtime helper for valid_available_ids
Move network preview formatting to formatter
Move final gate text to formatter
Move network combat request bridge
Improve network map view scaling
Add network map validation summary
```

不推荐：

```text
同时改 UI、状态推进、战斗返回、final gate、文档
一次性删除 legacy fallback
一次性重写大 controller
整文件替换超过 25KB 的脚本
```

## 八、AI 协作要求

给 Codex / ChatGPT 的提示词中应明确：

```text
不要整文件重写大 controller。
不要一次迁移多个函数。
不要改 data/*.json。
不要顺手重构无关逻辑。
每次只替换一个函数或新增一个小文件。
完成后运行 headless 验证。
```

当文件超过 25KB 时，优先使用：

```text
新增 helper 文件
新增 shim 文件
修改小 scene 引用
逐个函数替换
```

避免使用：

```text
整文件替换
跨多个职责的大重构
一次性删除旧 fallback
```

## 九、远端读写策略

远端工具通常更适合处理小文件。对于大文件，采用以下策略：

### 小文件可直接改

适合直接远端读写：

```text
小型 .gd helper
小型 .tscn scene 引用
小型 docs 文档
小型 generator / view 文件
```

### 大文件不整文件改

不建议远端整文件替换：

```text
大型 controller
长文档
超过 25KB 的复杂脚本
```

### 大文件替代方案

优先选择：

```text
1. 新增 shim 脚本，override 单个函数。
2. 修改小 scene 文件，让场景挂载 shim。
3. 新增 helper，小步在本地/Codex 中替换大文件函数。
4. 拆出 formatter / runtime / bridge 后再逐步迁移。
```

例如：

```gdscript
# scripts/narrative_demo_ui_focus_tuned_controller_shim.gd
extends "res://scripts/narrative_demo_ui_focus_tuned_controller.gd"

const StrategicNetworkMapRuntime := preload("res://scripts/strategic_network_map_runtime.gd")

func _network_valid_available_ids(graph: Dictionary, candidate_ids: Array) -> Array:
    return StrategicNetworkMapRuntime.valid_available_ids(graph, candidate_ids)
```

然后只修改小场景文件：

```text
scenes/NarrativeDemo.tscn
```

把 script 指向 shim。

## 十、运行源与生成产物边界

不要直接编辑 `data/*.json`。

项目运行链路是：

```text
tables/*.tsv
→ scripts/compile_tables.py
→ data/*.json
```

代码组织调整不应绕过表格编译链路，也不应把运行配置硬写进 UI controller。

## 十一、当前代码风险清单

以下清单来自 `python3 tools/audit_file_sizes.py` 的代码风险分组。它只用于指导代码重构优先级；`data/*.json`、`tables/*.tsv`、文档和场景文件另按“数据 / 文档风险”处理。

### P0：禁止继续追加功能

这些文件已经超过 35KB，属于高维护风险文件。原则上只允许 bugfix，不继续追加新功能；新增能力必须进入 helper、runtime、view、formatter、bridge、debug_entry 或 shim 文件。

| Size | File | 建议方向 |
|---:|---|---|
| 83.8KB | `scripts/battle_controller_core.gd` | 拆出回合执行、资源状态、距离服务、卡牌执行、敌方意图和结算计算。 |
| 68.3KB | `scripts/narrative_demo_ui_focus_tuned_controller.gd` | 大地图逻辑继续迁往 `strategic_network_map_*` 小文件，只保留调度。 |
| 61.4KB | `scripts/battle_controller_visual_ui.gd` | 拆出 HUD / 面板 / 操作区 / 状态区 view helper。 |
| 60.6KB | `scripts/battle_controller_visual_presentation_stepwise.gd` | 拆出演出 step runner、队列、动画策略。 |
| 58.2KB | `scripts/compile_tables.py` | 拆出表编译模块、校验模块、输出模块；保持 CLI 入口轻量。 |
| 50.1KB | `scripts/Main.gd` | 拆出 launcher / mode router / debug entry。 |
| 46.2KB | `scripts/battle_controller_visual_hot_tuning.gd` | 拆出调参模型、UI、应用逻辑。 |
| 42.3KB | `scripts/battle_controller_demo_visual.gd` | 拆出演示入口、战斗装配、debug 逻辑。 |
| 40.1KB | `scripts/battle_controller_visual_narrative_context.gd` | 拆出 narrative context 读写、战斗请求转换、返回处理。 |

### P1：拆分候选

这些文件超过 25KB，不应继续追加功能。后续遇到相关改动时，应优先抽小文件，而不是继续在原文件里堆逻辑。

| Size | File | 建议方向 |
|---:|---|---|
| 33.9KB | `tools/render_art_prompt.py` | 拆出 prompt loader / renderer / CLI。 |
| 32.5KB | `scripts/narrative_demo_ui_focus_controller.gd` | 保持 Focus UI 基类稳定，新增逻辑放子模块或 shim。 |
| 30.8KB | `scripts/auto_battle_sampler.gd` | 拆出采样策略、结果统计、报告输出。 |
| 29.5KB | `scripts/battle_controller_visual_presentation.gd` | 拆出演出格式化和播放策略。 |
| 27.0KB | `scripts/narrative/narrative_demo_controller.gd` | 拆出叙事状态、节点路由、选择处理。 |
| 27.0KB | `scripts/narrative_battle_context.gd` | 拆出 player profile、battle request、battle result、strategic map snapshot。 |
| 25.4KB | `scripts/narrative_demo_safe_controller.gd` | 后续只做兼容修补，不再追加新流程。 |

### P2：观察名单

这些文件处于 20KB - 25KB 警戒区。可以维护，但新增大段逻辑前要先评估是否应拆出 helper。

| Size | File |
|---:|---|
| 25.0KB | `scripts/battle_controller_visual_settlement_mode.gd` |
| 25.0KB | `scripts/battle_controller_visual_responsive_ui.gd` |
| 24.9KB | `scripts/narrative_demo_canonical_controller.gd` |
| 23.8KB | `scripts/battle_controller_text_ui.gd` |
| 22.6KB | `scripts/battle_controller_visual_resolver_preview.gd` |
| 21.1KB | `scripts/battle_controller_visual_cached_ui.gd` |
| 20.5KB | `tools/art_asset_pipeline.py` |

### 数据 / 文档大文件例外

以下文件体积较大，但不按代码风险处理：

```text
tables/art_prompt_manifest.tsv
data/strategic_map.json
data/narrative_mvp_nodes.json
data/story_battles.json
data/enemy_manifest.json
tables/narrative_mvp_nodes.tsv
data/performance_tracks.json
```

其中 `data/*.json` 多为编译产物，不直接编辑；如需治理，应优先拆源 TSV、编译输出或文档归档，而不是按 controller 拆分方式处理。

## 十二、验证要求

每次代码组织调整后，至少运行：

```bash
python3 scripts/compile_tables.py
godot --headless --quit --path .
godot --headless --path . --quit scenes/NarrativeDemo.tscn
git diff --check
```

涉及 UI 可见性、点击、战斗返回、final gate 的改动，还需要本地图形界面点测：

```text
进入大地图
点击节点刷新 preview
非战斗节点推进
战斗节点进入 MainVisual
战斗胜利返回推进
战斗失败返回可重试
map_complete 后进入 final gate
继续旧线性流程 fallback 可用
```

## 十三、当前项目适用结论

当前 `scripts/narrative_demo_ui_focus_tuned_controller.gd` 已超过理想体积，后续不应继续追加大地图功能。

后续新增或迁移大地图能力，应优先进入：

```text
scripts/strategic_network_map_runtime.gd
scripts/strategic_network_map_view.gd
scripts/strategic_network_map_generator.gd
scripts/strategic_network_map_formatter.gd
scripts/strategic_network_battle_bridge.gd
```

`narrative_demo_ui_focus_tuned_controller.gd` 后续只做调度，不继续堆 UI 细节、状态推进和战斗桥接。
