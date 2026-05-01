# 《大明之沧海嘀鸣》美术管线总规范

> 本文件是美术唯一权威入口。旧的风格指南、资源结构、资源盘点、生产路线图、节点视觉矩阵已合并到这里。长提示词保留在 `docs/ART_REFERENCE_PROMPTS.md` 作为附录。

## 1. 美术目标

正式美术不是泛古风、泛武侠，而是：

```text
明代海疆旧案感 + 军武压迫感 + 隐晦叙事痕迹
```

玩家不读 debug、不看文档，也应从画面上稳定读出：

- 明代海疆
- 军门案卷
- 残火黑潮
- 旧甲火器
- 压案阴影
- 忠义牺牲

正式资源必须满足：

| 维度 | 要求 |
|---|---|
| 叙事可读 | 一眼能读到节点核心物件或行动，不靠标题文字解释 |
| 明代可信 | 服饰、武器、军械、营帐、案卷、船、官印不现代化、不玄幻化 |
| 构图稳定 | 主视觉焦点清楚，字幕区和操作区不被关键物遮挡 |
| 材质成立 | 金属、湿沙、木箱、纸张、火光、雾气有区分 |
| 色彩统一 | 黑灰、宣纸米色、海雾灰蓝、暗朱红、少量暗金 |
| 实机有效 | 在 `NarrativeDemo` / `MainVisual` 中截图仍清楚、无错位、无过曝、无脏糊 |

## 2. 数据入口

策划入口只看 TSV：

```text
tables/narrative_mvp_prologue_steps.tsv
tables/narrative_mvp_nodes.tsv
tables/narrative_mvp_node_status.tsv
tables/performance_*.tsv
tables/battle_scene_manifest.tsv
```

运行产物由编译器生成：

```text
data/narrative_mvp_nodes.json
data/performance_tracks.json
data/battle_scene_manifest.json
```

规则：

1. 改剧情、美术挂接、performance 参数时，先改 TSV。
2. 不直接手改 `data/narrative_mvp_nodes.json` 或 `data/performance_tracks.json`。
3. `visual_path` 以 `tables/narrative_mvp_node_status.tsv` 为源头。
4. 剧情演出焦点、道具、剪影、雾、火光、镜头以 `tables/performance_*.tsv` 为源头。
5. 游戏验收看编译后的 JSON 和实际画面。

## 3. 资产分层

| 层级 | 路径 | 用途 | 是否运行读取 |
|---|---|---|---|
| 参考草案 | `art_reference/generated/` | AI 初稿、参考图、风格探索 | 否 |
| 正式源图 | `art_reference/final/` | 玩家导入 / 精修母版，保留最大信息量 | 否 |
| 运行导出 | `assets/` | Godot / Web 实际加载的 PNG、SVG、meta | 是 |
| 配置源 | `tables/*.tsv` | visual_path、performance、战斗场景 | 编译后读取 |

硬规则：

1. `art_reference/` 下必须保留 `.gdignore`，防止 Godot 导入源图。
2. `art_reference/generated/*.png` 不直接写入 `visual_path`。
3. `art_reference/final/*.png` 是正式源画 / 精修母版，可作为运行导出的来源。
4. `assets/**/*.png` 是正式运行导出，允许写入 `visual_path` 和 performance track。
5. `assets/` 下不放 `*_source.png`、`ref_*.png`、`raw_*.png`。
6. 每一条 `art_reference/final/...` 到 `assets/...` 的导出路径必须登记在本文映射表。
7. 未登记的源图不得视为已经实装。

## 4. 目录规范

`art_reference/final/pixel_battle/` 镜像 `assets/pixel_battle/`：

```text
art_reference/final/pixel_battle/backgrounds/
art_reference/final/pixel_battle/backgrounds/formal/prologue/
art_reference/final/pixel_battle/portraits/
art_reference/final/pixel_battle/sheets/
art_reference/final/pixel_battle/sheets/spearman_frames/
```

运行素材：

```text
assets/pixel_battle/backgrounds/
assets/pixel_battle/backgrounds/formal/prologue/
assets/pixel_battle/portraits/
assets/pixel_battle/sheets/
assets/pixel_battle/fx/
assets/pixel_battle/ui/
assets/narrative/props/
assets/narrative/silhouettes/
```

推荐命名：

```text
assets/pixel_battle/backgrounds/battle_bg_<battle_id>.png
assets/pixel_battle/backgrounds/narrative_<node_id>.png
assets/pixel_battle/sheets/<role_id>_sheet.png
assets/pixel_battle/sheets/<role_id>_frames/<action>.png
assets/pixel_battle/portraits/<role_id>_bust.png
assets/narrative/props/prop_<object_id>.png
assets/narrative/silhouettes/sil_<subject_id>.png
```

## 5. 源图到运行素材映射表

新增源图或导出路径时，先更新本节，再覆盖 `assets/`。

### 5.1 序章正式背景

| 正式源图 | 运行素材 | 状态 |
|---|---|---|
| `art_reference/final/pixel_battle/backgrounds/formal/prologue/01_black_tide.png` | `assets/pixel_battle/backgrounds/formal/prologue/01_black_tide.png` | `EXPORTED` |
| `art_reference/final/pixel_battle/backgrounds/formal/prologue/02_father.png` | `assets/pixel_battle/backgrounds/formal/prologue/02_father.png` | `EXPORTED` |
| `art_reference/final/pixel_battle/backgrounds/formal/prologue/03_door.png` | `assets/pixel_battle/backgrounds/formal/prologue/03_door.png` | `EXPORTED` |
| `art_reference/final/pixel_battle/backgrounds/formal/prologue/04_dead.png` | `assets/pixel_battle/backgrounds/formal/prologue/04_dead.png` | `EXPORTED` |
| `art_reference/final/pixel_battle/backgrounds/formal/prologue/05_wooden_blade.png` | `assets/pixel_battle/backgrounds/formal/prologue/05_wooden_blade.png` | `EXPORTED` |
| `art_reference/final/pixel_battle/backgrounds/formal/prologue/06_fall.png` | `assets/pixel_battle/backgrounds/formal/prologue/06_fall.png` | `EXPORTED` |
| `art_reference/final/pixel_battle/backgrounds/formal/prologue/07_master_arrives.png` | `assets/pixel_battle/backgrounds/formal/prologue/07_master_arrives.png` | `EXPORTED` |
| `art_reference/final/pixel_battle/backgrounds/formal/prologue/08_three_cards.png` | `assets/pixel_battle/backgrounds/formal/prologue/08_three_cards.png` | `EXPORTED` |
| `art_reference/final/pixel_battle/backgrounds/formal/prologue/09_military_word.png` | `assets/pixel_battle/backgrounds/formal/prologue/09_military_word.png` | `EXPORTED` |
| `art_reference/final/pixel_battle/backgrounds/formal/prologue/10_hidden_arrow.png` | `assets/pixel_battle/backgrounds/formal/prologue/10_hidden_arrow.png` | `EXPORTED` |
| `art_reference/final/pixel_battle/backgrounds/formal/prologue/11_dont_look.png` | `assets/pixel_battle/backgrounds/formal/prologue/11_dont_look.png` | `EXPORTED` |
| `art_reference/final/pixel_battle/backgrounds/formal/prologue/12_departure.png` | `assets/pixel_battle/backgrounds/formal/prologue/12_departure.png` | `EXPORTED` |

### 5.2 第一战背景

| 正式源图 | 运行素材 | 状态 |
|---|---|---|
| `art_reference/final/pixel_battle/backgrounds/battle_bg_coast_ambush.png` | `assets/pixel_battle/backgrounds/battle_bg_coast_ambush.png` | `EXPORTED` |
| `art_reference/final/pixel_battle/backgrounds/narrative_beach_ambush.png` | `assets/pixel_battle/backgrounds/narrative_beach_ambush.png` | `EXPORTED` |

### 5.3 第一战角色动作

| 正式源图 | 运行素材 | 运行挂接 | 状态 |
|---|---|---|---|
| `art_reference/final/pixel_battle/sheets/spearman_frames/idle_guard.png` | `assets/pixel_battle/sheets/spearman_frames/idle_guard.png` | `assets/pixel_battle/actors/spearman/spearman.meta.json` | `EXPORTED` |
| `art_reference/final/pixel_battle/sheets/spearman_frames/thrust.png` | `assets/pixel_battle/sheets/spearman_frames/thrust.png` | `assets/pixel_battle/actors/spearman/spearman.meta.json` | `EXPORTED` |
| `art_reference/final/pixel_battle/sheets/spearman_frames/recover.png` | `assets/pixel_battle/sheets/spearman_frames/recover.png` | `assets/pixel_battle/actors/spearman/spearman.meta.json` | `EXPORTED` |
| `art_reference/final/pixel_battle/sheets/enemy_spearman_frames/idle_guard.png` | `assets/pixel_battle/sheets/enemy_spearman_frames/idle_guard.png` | `assets/pixel_battle/actors/enemy_spearman/enemy_spearman.meta.json` | `EXPORTED` |
| `art_reference/final/pixel_battle/sheets/enemy_spearman_frames/long_weapon_thrust.png` | `assets/pixel_battle/sheets/enemy_spearman_frames/long_weapon_thrust.png` | `assets/pixel_battle/actors/enemy_spearman/enemy_spearman.meta.json` | `EXPORTED` |
| `art_reference/final/pixel_battle/sheets/enemy_spearman_frames/recover_guard.png` | `assets/pixel_battle/sheets/enemy_spearman_frames/recover_guard.png` | `assets/pixel_battle/actors/enemy_spearman/enemy_spearman.meta.json` | `EXPORTED` |
| `art_reference/final/pixel_battle/sheets/enemy_spearman_sheet_source.png` | `assets/pixel_battle/sheets/enemy_spearman_sheet.png` | `assets/pixel_battle/actors/enemy_spearman/enemy_spearman.meta.json` | `EXPORTED` |
| `art_reference/final/pixel_battle/sheets/enemyspearman_sheet_source.png` | `assets/pixel_battle/sheets/enemy_spearman_sheet.png` | legacy sheet fallback | `SOURCE_READY_LEGACY` |

### 5.4 师父角色

| 正式源图 | 运行素材 | 运行挂接 | 状态 |
|---|---|---|---|
| `art_reference/final/pixel_battle/sheets/master_sheets_source.png` | `assets/pixel_battle/sheets/master_veteran_sheet.png` | `assets/pixel_battle/actors/master_veteran/master_veteran.meta.json` | `EXPORTED` |
| `art_reference/final/pixel_battle/portraits/master_portraits_source.png` | `assets/pixel_battle/portraits/master_veteran_bust.png` / `assets/pixel_battle/portraits/performance_master_veteran.png` | `NarrativeDemo` / performance portrait layer | `EXPORTED` |

## 6. 当前缺口

师父运行素材已接入：

```text
assets/pixel_battle/sheets/master_veteran_sheet.png
assets/pixel_battle/portraits/master_veteran_bust.png
assets/pixel_battle/portraits/performance_master_veteran.png
```

正式源图已归档，并通过 `tools/promote_final_art_assets.py` 导出到运行素材。当前源图：

```text
art_reference/final/pixel_battle/sheets/master_sheets_source.png
art_reference/final/pixel_battle/portraits/master_portraits_source.png
```

后续如要统一命名，可在不改变运行路径的前提下规范为：

```text
art_reference/final/pixel_battle/sheets/master_veteran_sheet_source.png
art_reference/final/pixel_battle/portraits/master_veteran_bust_source.png
art_reference/final/pixel_battle/portraits/performance_master_veteran_source.png
```

运行素材不要手工二次抠图或去边；如需重导，回到 `art_reference/final/` 源图并重新执行导出脚本。

## 7. 战斗角色规格

| 类型 | 单帧规格 | 运行组织 | 适用角色 |
|---|---:|---|---|
| 短武器 / 普通体型 | `512x512` | `1536x512`，3 帧横排 | `blademaster` / `enemy_blademaster` |
| 长武器 / 横刺动作 | `1536x512` | 优先多张单帧 PNG；兼容 `4608x512` sheet | `spearman` / `enemy_spearman` |

生成原则：

1. 肖像和角色 sheet 的正式源图提示词统一要求使用纯色亮绿色抠图底，颜色固定为 `#00FF00`。
2. 抠图底必须是单一纯色，不要渐变、阴影、地面、纹理、光晕或透明棋盘格；角色身上不要出现同样的亮绿色。
3. 角色边缘尽量干净，方便后期一键抠图；运行资源仍以透明 PNG 为目标，由导出脚本完成抠图、透明化和尺寸归一。
4. 角色 sheet 必须是 3 帧动作，不接受 2 帧、4 帧或动作数量不明的图。
5. 三帧动作必须有大区分度：`idle_guard`、`attack / thrust`、`recover_guard` 要能一眼读出起手、出招、收势，不得只是手臂微调或同姿势复制。
6. 每一帧以脚底锚点和人体躯干为准，不按“武器整体外接矩形”居中，也不强制把脚点放在画面正中心。
7. 长枪 / 长兵器的 `idle_guard` 固定为“横枪胸前”的守势：枪杆横在胸前或胸腹前方，双手持枪护住中线，不使用枪尖斜指前方的普通站姿。

长枪帧原则：

```text
不要按“人+枪整体居中”排版。
每帧按人体自然站位记录脚底锚点；脚点可以偏左或偏右，枪尖可以占用额外横向透明空间。
idle_guard 是横枪胸前的守势，attack / thrust 才是长线突刺，recover_guard 是攻击后收枪防御。
默认长枪锚点：foot_anchor=[560,492]，body_center=[560,300]，head_anchor=[560,145]。
```

运行接入链路：

```text
art_reference/final/pixel_battle/sheets/spearman_frames/*.png
→ tools/normalize_actor_sheet.py
→ assets/pixel_battle/sheets/spearman_frames/*.png
→ assets/pixel_battle/actors/spearman/spearman.meta.json
→ ActorAnimationRuntime 按 frame_size / foot_anchor 渲染
```

## 8. 非透明底处理

生成图如果带浅色底、棋盘底、纸色底，不直接进运行资源，也不要在 `assets/` 运行 PNG 上反复擦边。正式角色源图优先使用 `#00FF00` 纯色亮绿色抠图底；先回到 `art_reference/final/...` 的源图层处理，再导出运行图。

只有确认是简单浅色底 / 棋盘底时，才使用 alpha matte 清理：

```bash
python3 tools/alpha_matte_cleanup.py \
  --source art_reference/final/source.png \
  --output /tmp/source_clean.png \
  --background auto
```

师父、主角、Boss 等高精角色禁止直接在 runtime PNG 上二次强清边；如果边缘损坏，回源图重导。

角色 sheet 或动作帧归一化示例：

```bash
python3 tools/normalize_actor_sheet.py \
  --source art_reference/final/pixel_battle/sheets/master_veteran_sheet_source.png \
  --output assets/pixel_battle/sheets/master_veteran_sheet.png \
  --frames 3 \
  --frame-width 512 \
  --frame-height 512 \
  --foot-x 256 \
  --foot-y 500 \
  --cleanup-alpha
```

## 9. 节点视觉状态

节点视觉状态不再拆到单独矩阵文档。当前判断口径：

| 状态 | 含义 |
|---|---|
| `VISUAL_WIRED` | `node_status.tsv` 已有 `visual_path` |
| `TRACK_WIRED` | 资源已通过 `performance_tracks` 进入剧情演出层 |
| `ASSET_READY_UNWIRED` | 资源存在，但尚未作为 `visual_path` 或 performance track 挂接 |
| `FORMAL_SOURCE_READY` | 已有可作为正式质量母版的源图 |
| `RUNTIME_EXPORT_READY` | 正式母版已转为合规高质量 PNG 运行资源 |
| `IN_GAME_ACCEPTED` | 已在 NarrativeDemo / MainVisual 截图验收通过 |

当前 P0 主流程以 `tables/narrative_mvp_node_status.tsv` 中 `flow_enabled=true` 的节点为准。资源状态以实际 `visual_path`、`performance_*.tsv` 和本文映射表交叉确认。

## 10. 生产路线

当前阶段判断：

```text
源图 / 运行素材分层已建立
第一战和序章已有一轮 PNG 正式资源
下一步重点是师父源图归档、截图验收、角色边缘质量和 performance track 实机确认
```

优先级：

1. 补齐师父正式源图，重新导出运行素材。
2. 对第一战 `MainVisual` 做截图验收。
3. 对序章 `NarrativeDemo` 做截图验收。
4. 通过验收后，在本文更新对应状态。
5. 新增任何源图时先补映射表。

## 11. 提示词

长提示词和角色 / 场景 / 主视觉 prompt 统一放在：

```text
docs/ART_REFERENCE_PROMPTS.md
```

提示词规则：

1. 参考图输出到 `art_reference/generated/`。
2. 正式源画沉淀到 `art_reference/final/`。
3. 运行资源必须导出到 `assets/` 后再挂接。
4. 运行背景、道具、剪影、角色图不写标题字。
5. 肖像和角色 sheet 的源图提示词必须写“纯色亮绿色抠图底 `#00FF00`”，运行导出再转透明。
6. 角色 sheet 提示词必须写清“3 帧动作”，且三帧动作差异要大。
7. 生成正式源画时必须同时标注目标节点、运行用途、目标 `assets/**/*.png` 导出路径。

## 12. 验收命令

```bash
python3 scripts/compile_tables.py
python3 tools/audit_art_asset_structure.py
python3 tools/validate_performance_tracks.py
python3 tools/validate_art_assets.py
python3 tools/validate_actor_meta.py assets/pixel_battle/actors
godot --headless --import --quit
```

Web 验收：

```bash
rm -rf build/web build/web.zip
./tools/build_and_serve_web.sh
```

结构审计关键结果应保持：

```text
Suspicious Source-Like Files Under assets (0)
art_reference Godot Import Artifacts (0)
```
