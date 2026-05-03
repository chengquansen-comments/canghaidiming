# 《大明之沧海嘀鸣》Godot 4 单局 Demo

这是一个 Godot 4 可运行原型，当前已经拆成三条入口：剧情 MVP、字符版战斗、视觉版战斗。主入口会按平台路由到桌面或 Web 版 launcher。

## 文档与结构索引

### 首读入口

| 文档 | 用途 |
|---|---|
| [README.md](README.md) | 项目入口、运行方式、当前主链路、文档索引 |
| [docs/ART_PIPELINE.md](docs/ART_PIPELINE.md) | 美术唯一总入口：风格、目录、源图映射、节点状态、路线图、验收命令 |
| [docs/ART_REFERENCE_PROMPTS.md](docs/ART_REFERENCE_PROMPTS.md) | 美术提示词附录 |
| [docs/NARRATIVE.md](docs/NARRATIVE.md) | 叙事唯一总入口：数据源、流程、战斗接入、结局、AI 生成边界 |
| [docs/BATTLE.md](docs/BATTLE.md) | 战斗唯一总入口：配置主源、剧情接入、结算模式、表演节奏、调参与验证 |
| [docs/UI_PIPELINE.md](docs/UI_PIPELINE.md) | UI 管线总入口：视觉战斗界面、层级、预览、演出、缓存、Web UI 验收 |
| [docs/CODE_ORGANIZATION.md](docs/CODE_ORGANIZATION.md) | 代码组织原则：单文件体积、职责拆分、AI 协作和重构提交规范 |

### 专项文档

| 分类 | 文档 |
|---|---|
| 策划与数据 | [NARRATIVE](docs/NARRATIVE.md) |
| 美术与演出 | [ART_PIPELINE](docs/ART_PIPELINE.md), [ART_REFERENCE_PROMPTS](docs/ART_REFERENCE_PROMPTS.md), [BATTLE_PRESENTATION_LAYER](docs/BATTLE_PRESENTATION_LAYER.md), [text_preview_stage_design](docs/text_preview_stage_design.md) |
| 战斗系统 | [BATTLE](docs/BATTLE.md), [single_battle_rules_current](docs/single_battle_rules_current.md), [BATTLE_PRESENTATION_LAYER](docs/BATTLE_PRESENTATION_LAYER.md), [reactive_settlement_v040](docs/reactive_settlement_v040.md), [balance_rules](docs/balance_rules.md), [carddata_movement_v032_change_list](docs/carddata_movement_v032_change_list.md), [symmetry_gameplay_v031_execution_list](docs/symmetry_gameplay_v031_execution_list.md), [SPEARMAN_MIN_ACTION_PACKAGE_PLAN](SPEARMAN_MIN_ACTION_PACKAGE_PLAN.md), [ENEMY_MANIFEST_RUNTIME](docs/ENEMY_MANIFEST_RUNTIME.md) |
| UI / Web / 工程 | [UI_PIPELINE](docs/UI_PIPELINE.md), [CODE_ORGANIZATION](docs/CODE_ORGANIZATION.md), [web_refactor_progress](docs/web_refactor_progress.md), [web_build_known_issues](docs/web_build_known_issues.md), [ui_architecture_refactor](docs/ui_architecture_refactor.md), [wuxia_battle_ui_godot_design](docs/wuxia_battle_ui_godot_design.md) |
| 历史归档 | 旧叙事脚本、进度与生成协议见 `archive/docs/narrative/` |

### 文件结构

| 路径 | 类型 | 说明 |
|---|---|---|
| `project.godot` | Godot 配置 | 项目入口配置，不随意改 |
| `scenes/` | 运行场景 | Godot `.tscn` 场景 |
| `scripts/` | 运行脚本 | GDScript 运行逻辑 |
| `tables/` | 策划源表 | TSV 是策划入口，优先改这里 |
| `data/` | 编译产物 / 运行数据 | 由 `scripts/compile_tables.py` 或专项流程生成 |
| `assets/` | 游戏运行素材 | Godot / Web 实际加载的图片、字体、主题等 |
| `art_reference/` | 图源仓 | AI 草案、玩家导入源图、正式母版；不直接运行 |
| `docs/` | 项目文档 | 专项设计、规范、进度 |
| `tools/` | 工具脚本 | 编译、校验、导出、smoke test |
| `themes/` | UI 主题 | Godot theme 资源 |
| `web/` | Web 静态辅助 | Web shell / 静态资源辅助目录 |
| `reports/` | 报告输出 | 校验、截图、分析报告 |
| `archive/` | 归档 | 旧表、旧方案、迁移前备份 |
| `build/` / `export/` / `.godot/` | 本地产物 | 构建输出和 Godot 缓存，不作为源 |

### 代码组织原则

- 单个 `.gd` 脚本建议控制在 **25KB 以下**；超过 **20KB** 开始评估拆分，超过 **25KB** 原则上不继续追加功能。
- Controller 只做调度，不长期承载 UI 细节、状态推进、战斗桥接、数据生成和 debug 入口等多重职责。
- 新功能优先进入小型专职文件：`runtime` / `view` / `generator` / `formatter` / `bridge` / `debug_entry`。
- 大文件不做远端整文件替换；优先新增 helper、shim 或小 scene 引用，再逐个函数迁移。
- 不要直接编辑 `data/*.json`；运行数据由 TSV 和编译脚本生成。

详细规范见 [docs/CODE_ORGANIZATION.md](docs/CODE_ORGANIZATION.md)。

### 核心结构链路

```text
project.godot
→ scenes/Main.tscn
→ scripts/main_runtime_router.gd
```

```text
tables/*.tsv
→ scripts/compile_tables.py
→ data/*.json
```

```text
art_reference/generated/   参考草案，不直接运行
art_reference/final/       正式源图 / 精修母版，不直接运行
assets/                    游戏运行素材，可被 res://assets/... 引用
```

```text
scenes/MainVisual.tscn
→ scripts/battle_controller_visual_story_return.gd
→ scripts/battle_controller_visual_settlement_mode.gd
→ scripts/battle_controller_visual_presentation_mode_aware.gd
→ scripts/battle_controller_visual_presentation_stepwise.gd
→ scripts/battle_controller_visual_cached_ui.gd
→ scripts/battle_controller_visual_ui.gd
→ scripts/battle_controller_demo_visual.gd
→ scripts/battle_controller_core.gd
```

### 常用命令

```bash
python3 scripts/compile_tables.py
python3 tools/audit_art_asset_structure.py
python3 tools/validate_art_assets.py
godot --headless --import --quit
```

## 当前入口

- `scenes/Main.tscn`：总入口，挂载 `scripts/main_runtime_router.gd`
- 桌面端：`scenes/MainDesktop.tscn`
  - 进入剧情 MVP：`scenes/NarrativeDemo.tscn`
  - 进入字符版战斗：`scenes/MainText.tscn`
  - 进入视觉版战斗：`scenes/MainVisual.tscn`
- Web 端：`scenes/MainWeb.tscn`
  - 支持直接进入剧情 MVP 或战斗测试
  - 支持 query flag：`narrative_mvp` / `smoke_battle`

## 当前已实现内容

- 2 个开局模板
  - `戚家军枪手`：优势距离 `2-3`，强调压势与打断
  - `单刀快手`：优势距离 `1-2`，强调连压与爆发
- 剧情 MVP
  - 序章：父母遇害、师父救场、十年后出山
  - 行军图一：初出山
  - 剧情节点可跳转到视觉战斗
  - 战斗结果可返回剧情并继续推进
- 视觉战斗
  - 支持 `battle_scene_manifest.json` 场景背景与镜头参数
  - 支持 `story_battles.json` 中的剧情战敌我数值、卡组、结算模式与压力规则
  - `enemy_manifest.json` 保留为旧剧情战斗 / AI / debug 兼容层，不再是正式剧情战斗主源
- 表格编译链路
  - `tables/*.tsv` 与 `data/story_battles/*.tsv` 是策划入口
  - `scripts/compile_tables.py` 生成运行所需 JSON

## 运行方式

如果本机 `godot` 已在 PATH 中：

```bash
cd /Users/happy/Documents/Codex/canghaidiming
godot --path .
```

如果你更习惯编辑器，也可以直接用 Godot 4 打开项目目录。

## 运行源与文档源

当前项目明确区分“运行源”和“文档/布局源”：

| 类型 | 文件 | 用途 |
|---|---|---|
| 运行源 | `data/narrative_mvp_nodes.json` | 剧情 MVP 实际读取的序章、节点、选项、战斗触发与结局提示 |
| 运行源 | `data/story_battles.json` | 正式剧情战斗 encounter、敌我模板、数值方案、卡组方案、结算模式 |
| 运行源 | `data/enemy_manifest.json` | 旧剧情战斗 / AI / debug 兼容层 |
| 运行源 | `data/battle_scene_manifest.json` | 视觉战斗 battle_id 对应的背景、标签、镜头参数 |
| 运行源 | `data/performance_tracks.json` | 剧情演出镜头、角色、雾、暗角、火光等表现参数 |
| 文档/布局源 | `data/narrative/mvp_compressed_narrative.json` | 初出山压缩叙事文档，不作为当前剧情推进逻辑源 |
| 文档/布局源 | `data/narrative/mvp_static_map_layout.json` | 静态地图布局数据，用于后续地图 UI 展示，不作为当前节点推进逻辑源 |

短期规则：

- 剧情推进以 `data/narrative_mvp_nodes.json` 为准。
- 地图视觉布局可参考 `data/narrative/mvp_static_map_layout.json`。
- `data/narrative/mvp_compressed_narrative.json` 只作为设计文档/备份，不参与当前运行逻辑。

## 叙事变量命名规范

运行期统一使用英文工程名作为 canonical variable names：

| 变量 | 中文 | 含义 |
|---|---|---|
| `military_merit` | 军功 | 军门、捷报、升赏认可的胜利 |
| `clean_reputation` | 清望 | 百姓、言官、道义评价 |
| `case_clues` | 旧案线索 | 十年前旧案、失械案、师父旧事的线索进度 |
| `soldier_trust` | 兵心 | 士兵、乡勇、部下是否愿意跟随 |

历史兼容别名：

| Legacy | Canonical |
|---|---|
| `jun_gong` | `military_merit` |
| `qing_wang` | `clean_reputation` |
| `clues` | `case_clues` |
| `public_repute` | `clean_reputation` |
| `dg` | `military_merit`，旧静态节点选择字段 |
| `dq` | `clean_reputation`，旧静态节点选择字段 |
| `dc` | `case_clues`，旧静态节点选择字段 |

`scenes/NarrativeDemo.tscn` 当前挂载 `scripts/narrative_demo_canonical_controller.gd`，该控制器会把旧字段自动映射到 canonical variables，避免旧 Demo 节点和新 TSV 运行源混用时出现变量含义漂移。

## 数据驱动说明

核心 JSON：

- `classes.json`：开局模板、武器、优势距离、初始牌组
- `cards.json`：卡牌文字、费用、类别、效果列表
- `effects.json`：效果类型注册表，定义处理器名、必填字段、效果说明
- `enemies.json`：旧字符版/基础战斗敌人基础属性、优势距离、意图序列
- `routes.json`：旧字符版/基础战斗路线节点、分支连接、地图长度、初始距离
- `rewards.json`：战后可进入奖励池的卡牌 id
- `narrative_mvp_nodes.json`：剧情 MVP 当前运行源
- `story_battles.json`：正式剧情战斗当前运行源
- `enemy_manifest.json`：旧剧情战斗 / AI / debug 兼容层
- `battle_scene_manifest.json`：视觉战斗场景运行源
- `performance_tracks.json`：剧情演出运行源

## TSV 配表流程

`tables/*.tsv` 与 `data/story_battles/*.tsv` 是策划入口。不要直接编辑 `data/*.json`；运行编译器后 JSON 会被 TSV 覆盖生成。

主要源表：

- `tables/classes.tsv`：开局模板
- `tables/cards.tsv`：卡牌基础信息
- `tables/card_effects.tsv`：卡牌效果明细，一行一个效果
- `tables/effect_types.tsv`：效果类型注册表
- `tables/enemies.tsv`：敌人基础属性
- `tables/enemy_intents.tsv`：敌人招式意图，一行一个意图
- `tables/routes.tsv`：路线节点、下一跳、地图长度、初始距离
- `tables/rewards.tsv`：奖励池
- `tables/battle_scene_manifest.tsv`：战斗 battle_id、背景、镜头参数
- `data/story_battles/*.tsv`：正式剧情战斗 encounter、敌我模板、数值方案、卡组方案、结算模式
- `tables/enemy_manifest_*.tsv`：旧剧情战斗 / AI / debug 兼容数据
- `tables/narrative_mvp_*.tsv`：MVP 剧情节点、序章、选项、战斗触发、结局提示
- `tables/performance_*.tsv`：剧情演出 timeline 与 beats
- `tables/raw_json_documents.tsv`：暂未拆表的大型叙事文档，由 TSV 原样生成到 `data/narrative/*.json`

编译命令：

```bash
cd /Users/happy/Documents/Codex/canghaidiming
python3 scripts/compile_tables.py
```

编译器会同时校验剧情 visual_path 与 performance track 的运行资源路径，避免 TSV 指到缺失资源、非法 SVG、外链图片或远程资源。只想单独验收剧情演出资源时可运行：

```bash
python3 tools/validate_performance_tracks.py
```

## 美术管线文档

当前美术文档只保留两个入口：

- `docs/ART_PIPELINE.md`：唯一权威入口，包含风格、目录、源图到运行素材映射、节点状态、正式路线和验收命令。
- `docs/ART_REFERENCE_PROMPTS.md`：提示词附录，不作为运行资源清单。

当前规则：正式运行资源优先使用高质量 PNG；参考 PNG 只放在 `art_reference/generated/`，正式源图放在 `art_reference/final/`，运行素材导出到 `assets/` 后再挂接。

编译完成后会自动覆盖生成：

- `data/classes.json`
- `data/cards.json`
- `data/effects.json`
- `data/enemies.json`
- `data/routes.json`
- `data/rewards.json`
- `data/battle_scene_manifest.json`
- `data/story_battles.json`
- `data/enemy_manifest.json`
- `data/narrative_mvp_nodes.json`
- `data/performance_tracks.json`
- `data/narrative/mvp_compressed_narrative.json`
- `data/narrative/mvp_static_map_layout.json`

### 表格字段约定

- 多值字段统一用 `|` 分隔：
  - 例如 `preferred_ranges` 写成 `2|3`
  - 例如 `tags` 写成 `突进|流血`
  - 例如 `deck` 写成 `mid_spear|mid_spear|guard_frame`
- 布尔字段用 `true / false`
- `card_effects.tsv` 与 `enemy_intents.tsv` 的 `order` 用来决定执行顺序
- 每条卡牌效果、每条敌人意图都单独占一行，这样更适合在表格里筛选、排序和批量编辑

### TSV 规则

- 提交策划改动时应提交 `tables/*.tsv` 和由编译器生成的对应 `data/*.json`
- 如果 JSON 和 TSV 不一致，以 TSV 为准，重新运行 `python3 scripts/compile_tables.py`
- 编译器仍兼容历史 `.csv` fallback，但项目内规范只使用 TSV，避免双入口混淆

## 扩展效果类型

现在新增一个效果类型的最小步骤是：

1. 在 `tables/effect_types.tsv` 注册新类型，声明 `handler` 和 `required_fields`
2. 在对应战斗控制器中实现处理函数
3. 在 `tables/card_effects.tsv` 里把该效果写进某张卡牌的 `effects`
4. 运行 `python3 scripts/compile_tables.py` 生成 JSON

## 当前 demo 的设计取舍

- 当前剧情 MVP 不是随机地图，而是静态压缩路线，用于验证碎片化叙事和战斗桥接。
- `data/narrative/mvp_static_map_layout.json` 只作为后续地图 UI 展示参考。
- `data/narrative_mvp_nodes.json` 是当前剧情推进的唯一运行源。
- 视觉战斗优先服务剧情 MVP，字符版战斗保留用于规则调试。
