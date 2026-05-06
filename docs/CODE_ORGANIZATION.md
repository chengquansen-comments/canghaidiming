# 代码组织原则

本文档定义《大明之沧海嘀鸣》项目的代码文件体积、职责拆分、AI 协作和重构提交原则。目标是让 Godot/GDScript 项目在 GitHub 远端读写、Codex/ChatGPT 辅助修改、人工 review 和后续维护中保持低风险、可定位、可逐步演进。

更新时间：2026-05-06

## 一、当前结论

当前项目已经完成一轮有效拆分：多个旧的大 controller 已经变成 thin wrapper，代码体积风险明显下降。

当前最高风险不再只是“单文件过大”，而是：

```text
继承链过深，AI 可读性开始下降。
```

典型表现：

```text
MainVisual.tscn
→ battle_controller_visual_story_return_intent_visibility.gd
→ battle_controller_visual_story_return.gd
→ battle_controller_visual_settlement_mode.gd
→ battle_controller_visual_reactive_round_flow.gd
→ battle_controller_visual_story_selection.gd
→ battle_controller_visual_presentation_mode_aware.gd
→ battle_controller_visual_presentation_stepwise.gd
→ ...
```

以及：

```text
battle_controller_visual_presentation_stepwise.gd
→ battle_controller_visual_presentation_stepwise_exchange.gd
→ battle_controller_visual_presentation_stepwise_draft.gd
→ battle_controller_visual_presentation_stepwise_facing.gd
→ battle_controller_visual_presentation_stepwise_focus.gd
→ battle_controller_visual_presentation_stepwise_fx.gd
→ ...
```

这些继承链短期保证了兼容性，但后续 AI 修改时会出现：

- super 调用路径过长；
- 状态变量来源不明显；
- 新功能不知道应该插在哪一层；
- 薄 wrapper 越叠越多；
- debug 时难以快速定位行为归属。

因此当前 P0 是：**控制继承链继续增长，并逐步把高频薄层迁成 helper / runtime / view / formatter / bridge。**

## 二、核心原则

1. 单个 `.gd` 脚本建议控制在 **25KB 以下**。
2. 文件超过 **20KB** 时，应开始评估是否需要拆分职责。
3. 文件超过 **25KB** 时，原则上不再继续追加功能，应优先拆分或抽 helper。
4. 文件超过 **35KB** 时，视为高维护风险文件，需要进入重构计划。
5. Controller 只做调度，不长期承载 UI、状态推进、战斗桥接、数据生成和 debug 入口等多重职责。
6. 新功能优先进入小型专职文件，而不是继续追加到已有 controller。
7. 远端 AI 修改应优先选择小文件、helper 文件、shim 文件或 scene 引用调整，避免整文件替换大文件。
8. 保留现有兼容 wrapper，但**不继续新增 controller 继承层**。
9. 新增能力默认使用组合式 helper：`preload + 调用`，不要默认用 `extends` 叠层。
10. 不为了缩短继承链而整文件合并 controller。

## 三、为什么控制 25KB 与继承深度

25KB 不是运行性能限制，而是工程协作和工具链安全边界。

单文件过大后会带来：

- GitHub 远端文件读取容易被工具截断；
- AI 工具无法安全进行整文件替换；
- 小改动也需要提交整文件，误删后半段风险高；
- 函数职责混杂，问题定位困难；
- Review 成本升高；
- UI、状态、战斗、debug、数据生成容易互相污染。

继承链过深后会带来：

- 行为来源不直观；
- `super()` 结果难预测；
- 同名函数覆盖顺序需要跨文件追踪；
- AI 容易只读到当前层，漏掉父层副作用；
- 新功能倾向继续新增 wrapper，导致链路越来越长。

因此项目采用：

```text
小文件、单职责、浅继承、组合式 helper、逐步迁移
```

作为默认工程策略。

## 四、文件体积分级

| 文件大小 | 建议处理 |
|---|---|
| `< 15KB` | 健康范围，可正常迭代。 |
| `15KB - 20KB` | 可接受，但新增功能时要注意职责边界。 |
| `20KB - 25KB` | 警戒范围，应评估拆分 helper / formatter / runtime。 |
| `25KB - 35KB` | 不建议继续追加功能，应优先重构。 |
| `> 35KB` | 高风险文件，应进入拆分计划，避免远端整文件修改。 |

## 五、职责拆分原则

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
| 规则纯计算 | rules / resolver |
| 副作用写入 | applier |

controller 只做调度，不应长期承载大量细节逻辑。

## 六、继承链治理规则

### 允许保留

现有历史兼容 wrapper 可以保留，例如：

```text
battle_controller_core.gd
battle_controller_visual_ui.gd
battle_controller_visual_presentation_stepwise.gd
```

这些文件作为旧 scene / subclass 的稳定入口存在，不再向内追加逻辑。

### 禁止继续扩大

除非是紧急兼容 shim，否则不要再新增：

```text
battle_controller_visual_story_return_xxx_yyy.gd
extends battle_controller_visual_story_return_xxx.gd
```

新增功能默认使用：

```gdscript
const SomeHelper := preload("res://scripts/some_helper.gd")

func _some_controller_entry() -> void:
    SomeHelper.do_work(...)
```

### 治理顺序

1. 先识别高频运行链路中的薄继承层。
2. 将纯逻辑迁到 helper / formatter / runtime。
3. 将 UI 节点创建迁到 view / overlay。
4. 将战斗请求、剧情返回迁到 bridge。
5. 最后再考虑让 controller 直接继承更低层父类。

注意：**不要一次性拉平整条继承链。**

## 七、海疆大势图推荐结构

大地图相关逻辑应维持以下结构：

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
scripts/strategic_network_map_formatter.gd
```

只负责 preview 和 final gate 文案格式化：节点类型、effects、tags、combat debug、状态提示。

```text
scripts/strategic_network_battle_bridge.gd
```

只负责战斗桥接数据：combat_pool fallback、encounter/battle request 构造、block reason。

后续建议新增：

```text
scripts/strategic_network_map_overlay.gd
```

只负责 overlay UI：左侧地图、右侧 preview、底部按钮和状态栏。

`narrative_demo_network_map_controller.gd` 最终只保留调度职责：进入大地图、调用 overlay、调用 runtime、保存上下文、与旧 flow 兼容。

## 八、拆分方式

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
pure formatter
pure runtime helper
bridge request builder
view / overlay renderer
controller 调用替换
删除重复 controller 函数
```

## 九、提交粒度

每个 commit 尽量只做一类事情。

推荐：

```text
Add strategic network map runtime helper
Use runtime helper for network complete_node
Use runtime helper for refresh_node_states
Move network preview formatting to formatter
Move final gate text to formatter
Move network combat request bridge
Add network map overlay view
Shrink story return inheritance chain by one layer
```

不推荐：

```text
同时改 UI、状态推进、战斗返回、final gate、文档
一次性删除 legacy fallback
一次性重写大 controller
整文件替换超过 25KB 的脚本
为了减少继承链而合并多个 controller
```

## 十、AI 协作要求

给 Codex / ChatGPT 的提示词中应明确：

```text
不要整文件重写大 controller。
不要一次迁移多个函数。
不要改 data/*.json。
不要顺手重构无关逻辑。
每次只替换一个函数或新增一个小文件。
完成后运行 headless 验证。
不要新增 controller 继承层；新功能优先进入 helper / runtime / view / formatter / bridge。
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
继续叠 wrapper 继承层
```

## 十一、远端读写策略

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

### 继承链调整策略

远端可以做继承链调整，但必须小步：

```text
1. 先选一个薄层。
2. 把薄层逻辑迁入 helper 或直接迁到子层。
3. 子层改为继承薄层的父类。
4. 原薄层保留兼容说明或退化为 wrapper。
5. 必须跑 MainVisual / NarrativeDemo smoke。
```

不允许一次性做：

```text
MainVisual 整条继承链拉平
stepwise 整条继承链拉平
把多个父类内容复制进一个子类
```

## 十二、运行源与生成产物边界

不要直接编辑 `data/*.json`。

项目运行链路是：

```text
tables/*.tsv
→ scripts/compile_tables.py
→ data/*.json
```

代码组织调整不应绕过表格编译链路，也不应把运行配置硬写进 UI controller。

## 十三、当前代码风险清单

以下清单基于 2026-05-06 当前代码状态与 `tools/audit_file_sizes.py --top 80` 结果整理。详细审计见：

```text
reports/file_size_audit.md
docs/REFACTOR_BACKLOG.md
```

### P0：继承链治理

| 风险 | 链路 | 建议方向 |
|---|---|---|
| 视觉战斗链路过深 | `MainVisual.tscn → battle_controller_visual_story_return_intent_visibility.gd → ...` | 不再新增 story_return wrapper；优先把 settlement/status/preview glue 迁为 helper，再减少薄继承层。 |
| stepwise 演出链路过深 | `stepwise → exchange → draft → facing → focus → fx` | 保留当前兼容入口；下一步拆 `exchange` 中 pending effect move / lethal finish / slot settle。 |
| 大地图 controller 调度层偏厚 | `narrative_demo_network_map_controller.gd` | 使用 `StrategicNetworkMapRuntime.complete_node()`、`refresh_node_states()`、`sync_mirror_fields()` 删除重复实现。 |

### P0：禁止继续追加功能

| Size | File | 建议方向 |
|---:|---|---|
| 58.2KB | `scripts/compile_tables.py` | 拆出 table loader / validator / writer；主文件只保留 CLI 调度。 |

### P1：拆分候选

| Size | File | 建议方向 |
|---:|---|---|
| 33.9KB | `tools/render_art_prompt.py` | 拆出 prompt loader / renderer / CLI。 |
| 27.6KB | `scripts/narrative_demo_strategic_legacy_controller.gd` | 拆出 ending/final gate 文案和奖励 runtime。 |
| 27.0KB | `scripts/narrative/narrative_demo_controller.gd` | 拆出节点路由和选择处理。 |
| 27.0KB | `scripts/narrative_battle_context.gd` | 拆出 player profile 与 battle request/result bridge。 |
| 25.7KB | `scripts/battle_controller_visual_resolver_preview.gd` | 拆出 preview runtime 与 formatter。 |
| 25.4KB | `scripts/narrative_demo_safe_controller.gd` | 只做兼容修补，不再追加新流程。 |

### P2：观察名单

| Size | File | 建议方向 |
|---:|---|---|
| 24.9KB | `scripts/narrative_demo_canonical_controller.gd` | 新增逻辑先进 helper。 |
| 24.5KB | `scripts/battle_controller_visual_presentation_stepwise_exchange.gd` | 继续拆 stepwise 子模块，避免 exchange 层变大。 |
| 22.8KB | `scripts/narrative_demo_network_map_controller.gd` | 保持 map 调度层，不回填 overlay/runtime/bridge 细节。 |
| 21.4KB | `scripts/battle_controller_core_deck_builder.gd` | 若加功能，先抽 deck helper。 |
| 21.1KB | `scripts/battle_controller_visual_cached_ui.gd` | 避免继续堆缓存策略。 |
| 20.5KB | `tools/art_asset_pipeline.py` | 后续按 loader / processor / exporter 拆。 |

### 已清理出旧 P0/P1 的文件

这些文件在旧清单中曾是高风险，但当前已经变为 thin wrapper 或健康范围：

| File | 当前状态 |
|---|---|
| `scripts/battle_controller_core.gd` | 已变为 thin wrapper，真实逻辑拆入 `battle_controller_core_*` 层。 |
| `scripts/battle_controller_visual_ui.gd` | 已变为 thin compatibility entry，真实逻辑拆入 `battle_controller_visual_ui_*` 层。 |
| `scripts/battle_controller_visual_presentation_stepwise.gd` | 已变为 stepwise wrapper，真实逻辑拆入 fx/focus/facing/draft/exchange 层。 |
| `scripts/narrative_demo_ui_focus_tuned_controller.gd` | 已降到约 8.8KB，保持调度层定位。 |
| `scripts/narrative_demo_ui_focus_controller.gd` | 已拆分为 view/runtime/helper 委托结构，约 8.4KB。 |
| `scripts/battle_controller_visual_responsive_ui.gd` | 已降到 13,078 bytes，低于 20KB。 |
| `scripts/battle_controller_visual_presentation.gd` | 已降到 19,368 bytes，低于 20KB。 |

### 数据 / 文档大文件例外

以下类型文件体积较大时，不按代码风险处理：

```text
tables/*.tsv
data/*.json
docs/*.md
scenes/*.tscn
*.tres
```

其中 `data/*.json` 多为编译产物，不直接编辑；如需治理，应优先拆源 TSV、编译输出或文档归档，而不是按 controller 拆分方式处理。

## 十四、验证要求

每次代码组织调整后，至少运行：

```bash
python3 scripts/compile_tables.py
godot --headless --quit --path .
godot --headless --path . --quit scenes/NarrativeDemo.tscn
godot --headless --path . --quit scenes/MainVisual.tscn
git diff --check
python3 tools/audit_file_sizes.py --top 80
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

## 十五、当前项目适用结论

当前项目已经从“大文件优先治理”进入“继承链和职责收口”阶段。

下一步推荐顺序：

```text
1. 控制 MainVisual / stepwise 继承链继续增长。
2. 收口 narrative_demo_network_map_controller.gd 中已被 runtime 覆盖的重复逻辑。
3. 拆 compile_tables.py。
4. 拆 render_art_prompt.py。
5. 新增功能继续进入 helper / runtime / view / formatter / bridge。
```

短期禁止：

```text
继续新增 battle_controller_visual_story_return_* 继承层
继续往 narrative_demo_network_map_controller.gd 塞 overlay 细节
继续往 compile_tables.py 塞新表编译逻辑
继续直接改 data/*.json
```
