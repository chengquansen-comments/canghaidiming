# 工程协作总入口

本文档是代码组织、重构排期、AI 协作和 Godot 排障的活跃入口。旧文档 `CODE_ORGANIZATION.md`、`REFACTOR_BACKLOG.md`、`chatgpt_debugging_rules.md` 已降级为归档。

## 当前结论

当前最高风险不再只是“单文件过大”，而是：

- 视觉战斗 controller 继承链过深。
- 历史 thin wrapper 过多，行为来源不直观。
- 大型工具脚本仍有拆分空间。
- Godot 继承解析错误容易被误判为最外层脚本问题。

默认策略：

- 小文件。
- 单职责。
- 浅继承。
- 组合式 helper。
- 小步迁移。
- 先定位真实根因，再做最小补丁。

## 文件体积规则

| 文件大小 | 处理规则 |
|---|---|
| `< 15KB` | 健康范围，可正常迭代 |
| `15KB - 20KB` | 可接受，新增功能需注意职责边界 |
| `20KB - 25KB` | 警戒范围，评估 helper / formatter / runtime |
| `25KB - 35KB` | 不建议继续追加功能，优先迁移或 bugfix |
| `> 35KB` | 高维护风险，进入拆分计划 |

新增 GDScript 默认必须控制在 `20KB` 以下。`>25KB` 文件不继续追加新功能，只做迁移、兼容修复或 bugfix。

## 职责拆分

| 职责 | 推荐类型 |
|---|---|
| 流程调度 | controller |
| UI 绘制 | view |
| Overlay / 面板组合 | overlay |
| 状态推进 | runtime / state helper |
| 文案格式化 | formatter |
| 数据生成 | generator |
| 战斗请求与返回 | bridge |
| Debug 入口 | debug_entry / shim |
| 规则纯计算 | rules / resolver |
| 副作用写入 | applier |

Controller 只做调度，不长期承载 UI、状态推进、数据生成、debug 和战斗桥接等多重职责。

## 继承链治理

允许保留历史兼容 wrapper，但不继续新增 controller 继承层。除非是紧急兼容 shim，禁止继续追加：

```text
battle_controller_visual_xxx_yyy.gd
extends battle_controller_visual_xxx.gd
```

新增功能默认使用组合式 helper：

```gdscript
const SomeHelper := preload("res://scripts/some_helper.gd")

func _some_controller_entry() -> void:
    SomeHelper.do_work(...)
```

治理顺序：

1. 识别高频运行链路中的薄继承层。
2. 将纯逻辑迁到 helper / formatter / runtime。
3. 将 UI 节点创建迁到 view / overlay。
4. 将战斗请求、剧情返回迁到 bridge。
5. 最后再考虑让 controller 直接继承更低层父类。

## 当前重构优先级

P0：

| 文件 | 当前问题 | 处理方向 |
|---|---|---|
| `scripts/compile_tables.py` | 约 58KB，高风险工具脚本 | 拆 loader / validator / writer，主脚本只保留 CLI + 调度 |
| `tools/render_art_prompt.py` | 约 34KB，提示词工具过大 | 拆 loader / renderer / cli，主脚本保留兼容入口 |

P1：

| 文件 | 处理方向 |
|---|---|
| `scripts/narrative/narrative_demo_controller.gd` | 抽 route runtime 和 choice runtime |
| `scripts/narrative_battle_context.gd` | 抽 battle profile builder 和 context bridge |
| `scripts/battle_controller_visual_resolver_preview.gd` | 抽 preview runtime 和 formatter |
| `scripts/narrative_demo_safe_controller.gd` | 只做兼容层收口，不新增流程逻辑 |

已完成并保持不回退：

- `narrative_demo_strategic_legacy_controller.gd` 和 `narrative_demo_network_map_controller.gd` 已变为 legacy compatibility alias。
- `battle_controller_visual_responsive_ui.gd` 已降到 20KB 以下。
- `battle_controller_visual_presentation.gd` 已降到 20KB 以下。
- 大势图 runtime / formatter / battle bridge / overlay / confirm / battle result 已拆分。

## Godot 排障规则

看到这类报错时：

```text
Could not resolve super class inheritance from "res://scripts/xxx.gd"
```

不要直接改最外层脚本。真实根因可能在当前脚本、父类、祖先脚本、祖先 preload、缩进、语法或 warning-as-error。

排查顺序：

1. 完整展开 `extends` 链。
2. 跑 headless 校验，优先相信第一条真实 parser / warning / runtime error。
3. 必要时逐层 `load()`，找第一个不能加载的脚本。
4. 只修第一处真实根因，不绕过 MainVisual、不换入口、不复制临时 controller。

项目内诊断命令：

```bash
HOME=/private/tmp godot --headless --path . --script tools/debug_mainvisual_load_chain.gd
```

常规校验命令：

```bash
git diff --check
python3 scripts/compile_tables.py
godot --headless --quit --path .
godot --headless --path . --quit scenes/NarrativeDemo.tscn
godot --headless --path . --quit scenes/MainVisual.tscn
python3 tools/audit_file_sizes.py --top 80
```

Godot headless 输出已有 RID/resource leak 警告时，只要脚本结果为 OK 且退出码为 0，通常不作为本次修改失败。

## 提交边界

- 单次提交只做一类事：新增 helper、替换一个函数、迁移一个职责或修一个 bug。
- 未完成拆分前，不删除 legacy fallback。
- 不直接编辑 `data/*.json`；改 TSV 后运行 `python3 scripts/compile_tables.py`。
- 大文件不做远端整文件替换；优先小补丁、小 helper、小 scene 引用调整。
- 每次改动前先声明补丁边界；提交说明必须写清验证结果。
