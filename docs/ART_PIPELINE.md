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

### 5.3 第三章押运冲突背景

| 正式源图 | 运行素材 | 状态 |
|---|---|---|
| `art_reference/final/pixel_battle/backgrounds/battle_bg_chapter3_escort_clash.png` | `assets/pixel_battle/backgrounds/battle_bg_chapter3_escort_clash.png` | `EXPORTED` |

### 5.4 战斗角色动作

| 正式源图 | 运行素材 | 运行挂接 | 状态 |
|---|---|---|---|
| `art_reference/final/pixel_battle/sheets/spearman_sheet.png` | `assets/pixel_battle/sheets/spearman_sheet.png` | `assets/pixel_battle/actors/spearman/spearman.meta.json` | `EXPORTED / FORMAL_MAIN` |
| `art_reference/final/pixel_battle/sheets/blademaster_sheet.png` | `assets/pixel_battle/sheets/blademaster_sheet.png` | `assets/pixel_battle/actors/blademaster/blademaster.meta.json` | `EXPORTED / FORMAL_MAIN` |
| `art_reference/final/pixel_battle/sheets/enemy_spearman_sheet.png` | `assets/pixel_battle/sheets/enemy_spearman_sheet.png` | `assets/pixel_battle/actors/enemy_spearman/enemy_spearman.meta.json` | `EXPORTED / FORMAL_MAIN` |
| `art_reference/final/pixel_battle/sheets/enemy_blademaster_sheet.png` | `assets/pixel_battle/sheets/enemy_blademaster_sheet.png` | `assets/pixel_battle/actors/enemy_blademaster/enemy_blademaster.meta.json` | `EXPORTED / FORMAL_MAIN` |
| `art_reference/final/pixel_battle/sheets/master_veteran_sheet.png` | `assets/pixel_battle/sheets/master_veteran_sheet.png` | `assets/pixel_battle/actors/master_veteran/master_veteran.meta.json` | `EXPORTED / FORMAL_MAIN` |
| `art_reference/final/pixel_battle/sheets/*_frames/*.png` | `assets/pixel_battle/sheets/*_frames/*.png` | actor `hit` / `break` fallback | `EXPORTED / FALLBACK_FRAME` |
| `art_reference/final/pixel_battle/sheets/*_source.png` | legacy `assets/pixel_battle/sheets/*.png` | legacy sheet fallback | `SOURCE_READY_LEGACY` |

### 5.5 师父角色

| 正式源图 | 运行素材 | 运行挂接 | 状态 |
|---|---|---|---|
| `art_reference/final/pixel_battle/sheets/master_sheets_source.png` | `assets/pixel_battle/sheets/master_veteran_sheet.png` | `assets/pixel_battle/actors/master_veteran/master_veteran.meta.json` | `EXPORTED` |
| `art_reference/final/pixel_battle/portraits/master_portraits_source.png` | `assets/pixel_battle/portraits/master_veteran_bust.png` / `assets/pixel_battle/portraits/performance_master_veteran.png` | `NarrativeDemo` / performance portrait layer | `EXPORTED` |

## 6. 当前缺口

正式战斗动作运行素材已接入：

```text
assets/pixel_battle/sheets/spearman_sheet.png
assets/pixel_battle/sheets/blademaster_sheet.png
assets/pixel_battle/sheets/enemy_spearman_sheet.png
assets/pixel_battle/sheets/enemy_blademaster_sheet.png
assets/pixel_battle/sheets/master_veteran_sheet.png
assets/pixel_battle/portraits/master_veteran_bust.png
assets/pixel_battle/portraits/performance_master_veteran.png
```

正式源图已归档，并通过 `tools/run_art_asset_flow.py` 或 `tools/promote_final_art_assets.py` 导出到运行素材。当前仍需要收口的是：

```text
1. 用 Web 实机截图把角色 / 肖像 / 背景从 GODOT_IMPORTED 推进到 IN_GAME_ACCEPTED。
2. 将旧 frames / legacy source 只保留为 fallback 或归档说明，不再作为正式生产主路径。
3. 清理不再引用的 anchored sheet 和旧临时背景，避免审计噪音。
```

运行素材不要手工二次抠图或去边；如需重导，回到 `art_reference/final/` 源图并重新执行导出脚本。

## 7. 战斗角色规格

| 类型 | 单帧规格 | 运行组织 | 适用角色 |
|---|---:|---|---|
| 全部战斗动作 sheet | `1536x512` | `1536x1536`，3 帧纵向三叠 | `spearman` / `blademaster` / 敌方同类 / `master_veteran` |

生成原则：

1. 肖像和角色 sheet 的正式源图提示词统一要求使用纯色亮绿色抠图底，颜色固定为 `#00FF00`。
2. 抠图底必须是单一纯色，不要渐变、阴影、地面、纹理、光晕或透明棋盘格；角色身上不要出现同样的亮绿色。
3. 角色边缘尽量干净，方便后期一键抠图；源图允许生成模型有轻微边缘不稳定，但运行资源必须是透明 PNG，由导出脚本完成抠图、透明化和尺寸归一。
4. 角色 sheet 必须是 3 帧动作，整张 `1536x1536`，按上中下三叠排列；每帧严格 `1536x512`，不接受横排、2 帧、4 帧或动作数量不明的图。
5. 三帧动作必须有大区分度：`idle_guard`、`attack / thrust`、`recover_guard` 要能一眼读出起手、出招、收势，不得只是手臂微调或同姿势复制。
6. 每一帧以脚底锚点和人体躯干为准，不按“武器整体外接矩形”居中，也不强制把脚点放在画面正中心。
7. 脚点调教必须个性化：`foot_anchor.x` 按角色体态、武器长度、动作重心和运行时站位手工记录，不做全角色统一横向脚点；只允许统一检查每张 sheet 内三帧的脚底 `Y` 基线，避免漂浮或沉底。
8. 脚底必须完整可见，运行帧底部要保留少量透明余量；禁止把脚尖、鞋底或落脚阴影贴到 `1536x512` 单帧最底边。
9. 长枪 / 长兵器的 `idle_guard` 固定为“横枪胸前”的守势：枪杆横在胸前或胸腹前方，双手持枪护住中线，不使用枪尖斜指前方的普通站姿。
10. 角色 sheet 源素材默认朝右；对手朝左由运行时 `facing` / `flip_h` 处理，不在源图层做敌我两套反向素材。

长枪帧原则：

```text
不要按“人+枪整体居中”排版。
每帧按人体自然站位记录脚底锚点；脚点可以偏左或偏右，枪尖可以占用额外横向透明空间。
idle_guard 是横枪胸前的守势，attack / thrust 才是长线突刺，recover_guard 是攻击后收枪防御。
默认长枪锚点：foot_anchor=[560,492]，body_center=[560,300]，head_anchor=[560,145]。
```

脚点验收原则：

```text
1. 每张 sheet 内三帧脚底 Y 基线必须一致，不能一帧漂浮、一帧沉底。
2. foot_anchor.x 是角色级配置，不是全项目统一值；长枪、短刀、老兵、敌兵可以不同。
3. 调整脚点时优先移动单帧内容或更新 actor meta，不用武器外接矩形重新居中。
4. 如果脚底被裁掉或贴边，先整体上移留出透明余量，再更新对应 foot_anchor.y。
```

运行接入链路：

```text
art_reference/final/pixel_battle/sheets/spearman_sheet.png
→ tools/run_art_asset_flow.py battle_sheet_hero_spearman --from-source ... --import --refresh --quiet
→ assets/pixel_battle/sheets/spearman_sheet.png
→ assets/pixel_battle/actors/spearman/spearman.meta.json
→ ActorAnimationRuntime 按 frame_size / foot_anchor / sheet_layout=vertical 渲染
```

### 7.1 后续精细动作包

当前正式主路径是 3 帧竖向三叠 sheet。下一阶段若要提高动作精细度，再从 3 帧 sheet 升级到按动作拆分的多帧动作包：

```text
assets/pixel_battle/actors/spearman/
  spearman_idle.png
  spearman_move_forward.png
  spearman_attack_light.png
  spearman_guard.png
  spearman_hit.png
  spearman_break.png
  spearman.meta.json
```

动作规格：

| 动作 | 帧数 | fps | 重点 |
|---|---:|---:|---|
| `idle` | 6-8 | 8 | 轻微呼吸，枪杆微动，脚底稳定 |
| `move_forward` | 6 | 10-12 | 进身抢位，不在帧内跨格 |
| `attack_light` | 8 | 12-15 | 中平直刺，`hit_frame=5` |
| `guard` | 6 | 8-10 | 横枪或回枪成圆，防守轮廓明确 |
| `hit` | 5 | 12-15 | 短促受击，脚底不跳 |
| `break` | 8 | 10-12 | 破势失衡，枪杆下坠 |

动作包到位后必须依次跑：

```bash
python3 tools/validate_actor_meta.py assets/pixel_battle/actors/spearman/spearman.meta.json
python3 tools/validate_actor_sheet.py assets/pixel_battle/actors/spearman/spearman.meta.json
python3 tools/validate_actor_bundle.py assets/pixel_battle/actors/spearman
```

Web 验收重点：idle 不乱跳、attack 命中帧清楚、guard 轮廓可读、hit / break 不被裁脚，切换动作无明显白屏或透明闪烁。

## 8. 非透明底处理

生成图如果带浅色底、棋盘底、纸色底，不直接进运行资源，也不要在 `assets/` 运行 PNG 上反复擦边。正式角色源图优先使用 `#00FF00` 纯色亮绿色抠图底；先回到 `art_reference/final/...` 的源图层处理，再导出运行图。

绿幕处理原则：

```text
1. 源图提示词必须要求纯 #00FF00、单一平色、无阴影、无渐变、无地面、无纹理、无棋盘格。
2. 源图接收阶段不做零容忍拦截，因为生成模型边缘可能不稳定。
3. 后处理和运行验收必须零容忍：导出的 assets/**/*.png 不允许保留任何可见绿幕、绿边、脏绿半透明像素或非透明绿背景。
4. 如果运行验收失败，优先改抠图/去绿脚本或重新导出；不要手工在 runtime PNG 上局部擦边。
```

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

## 10. 单资产任务单

为了减少反复重读大文档、手改多张表和长说明，新增单资产任务表：

```text
tables/art_asset_manifest.tsv
```

全量资产台账：

```text
tables/art_backlog.tsv
```

台账刷新与筛选命令：

```bash
python3 tools/refresh_art_backlog.py
python3 tools/list_art_backlog.py
python3 tools/list_art_backlog.py --status NEEDS_SOURCE
python3 tools/list_art_backlog.py --priority P0
python3 tools/list_art_backlog.py --todo proxy --format short
python3 tools/list_art_backlog.py --todo scene --priority P0 --format ids
python3 tools/list_art_backlog.py --todo prop --priority P0 --limit 5
python3 tools/list_art_backlog.py --todo next --priority P0 --pick-next
python3 tools/list_art_backlog.py --todo proxy --pick-next
```

资产任务创建命令：

```bash
python3 tools/create_art_asset_task.py <asset_id>
python3 tools/create_art_asset_task.py <asset_id> --update
```

省 token 的正式源图接收命令：

```bash
python3 tools/accept_generated_art.py <asset_id> --latest
python3 tools/accept_generated_art.py <asset_id> --source /abs/path/to/generated.png
```

更省 token 的一键实装命令：

```bash
python3 tools/run_art_asset_flow.py <asset_id> --from-latest --import --refresh --quiet
python3 tools/run_art_asset_flow.py <asset_id> --from-source /abs/path/to/generated.png --import --refresh --quiet
python3 tools/run_art_asset_flow.py <asset_id> --from-latest --print-source --dry-run
```

字段口径：

| 字段 | 含义 |
|---|---|
| `asset_id` | 单资产任务 id，命令入口统一用它 |
| `type` | 导出 profile，当前支持 `battle_background` / `narrative_background` / `narrative_prop` / `battle_portrait` / `performance_portrait` |
| `source_path` | `art_reference/final/**` 正式母版 |
| `runtime_path` | `assets/**` 运行 PNG 目标 |
| `hook_table` | 要回写的表，例如 `tables/battle_scene_manifest.tsv` |
| `hook_key_field` | 表内主键列名，例如 `id` / `track_id` |
| `hook_id` | 表内目标行 id |
| `hook_field` | 要回写的字段，例如 `background` / `visual_path` / `prop_path` |
| `current_asset_class` | 当前挂接资源类型，例如 `svg_placeholder` / `png_temp` / `png_formal` / `portrait_proxy` / `prop_proxy` / `relic_proxy` / `shared_runtime` |
| `planned_asset_class` | 目标资源类型，当前主要区分 `png_formal` / `svg_placeholder` |
| `runtime_role` | 当前资源在流程里的角色，例如 `placeholder` / `proxy` / `shared_existing` / `legacy_target` / `final_target` |
| `status` | 资产任务状态 |
| `note` | 简短备注 |

资产任务状态机：

| 状态 | 含义 |
|---|---|
| `PROMPT_READY` | 提示词已确认 |
| `SOURCE_READY` | 正式母版已入 `art_reference/final` |
| `EXPORTED` | 已导出 runtime PNG |
| `WIRED` | 已回写 hook table |
| `COMPILED` | `scripts/compile_tables.py` 后 JSON 指向正确 |
| `GODOT_IMPORTED` | `.import` / `.ctex` 已生成 |
| `IN_GAME_CHECKED` | 截图或实机验收通过 |

## 11. 生产路线

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

## 12. 提示词

长提示词和角色 / 场景 / 主视觉 prompt 统一放在：

```text
docs/ART_REFERENCE_PROMPTS.md
```

结构化提示词任务单：

```text
tables/art_prompt_manifest.tsv
```

当前表是“短变量表”，只保留节点语义差异；共用风格、输出规格、质量框架由 `render_art_prompt.py` 模板补齐，不再把整段重复规格常驻在表里。

提示词渲染命令：

```bash
python3 tools/render_art_prompt.py <asset_id>
python3 tools/render_art_prompt.py <asset_id> --lang zh
python3 tools/render_art_prompt.py <asset_id> --lang en
python3 tools/render_art_prompt.py <asset_id> --style compact --lang en
```

提示词规则：

1. 参考图输出到 `art_reference/generated/`。
2. 正式源画沉淀到 `art_reference/final/`。
3. 运行资源必须导出到 `assets/` 后再挂接。
4. 运行背景、道具、剪影、角色图不写标题字。
5. 肖像和角色 sheet 的源图提示词必须写“纯色亮绿色抠图底 `#00FF00`”，运行导出再转透明。
6. 角色 sheet 提示词必须写清“3 帧动作”，且三帧动作差异要大。
7. 生成正式源画时必须同时标注目标节点、运行用途、目标 `assets/**/*.png` 导出路径。
8. 新增正式提示词时，优先先补 `tables/art_prompt_manifest.tsv`，再由脚本渲染中英双版，不再手写整段长 prompt。

## 13. 验收命令

```bash
python3 scripts/compile_tables.py
python3 tools/audit_art_asset_structure.py
python3 tools/validate_performance_tracks.py
python3 tools/validate_art_assets.py
python3 tools/validate_actor_meta.py assets/pixel_battle/actors
godot --headless --import --quit
```

单资产标准流程：

```bash
python3 tools/refresh_art_backlog.py
python3 tools/list_art_backlog.py --status NEEDS_SOURCE
python3 tools/create_art_asset_task.py <asset_id>
python3 tools/promote_art_asset.py <asset_id>
python3 scripts/compile_tables.py
python3 tools/validate_art_asset_task.py <asset_id>
godot --headless --import --quit
python3 tools/validate_art_asset_task.py <asset_id> --require-import
```

省 token 的合并入口：

```bash
python3 tools/run_art_asset_flow.py <asset_id> --from-latest --import --refresh --quiet
python3 tools/run_art_asset_flow.py <asset_id> --from-source /abs/path/to/generated.png --import --refresh --quiet
```

说明：

1. `refresh_art_backlog.py` 负责从现有表、prompt manifest、asset manifest 和本地资源状态刷新全量台账，标出已有、代用和待生产项。
2. `create_art_asset_task.py` 负责从 `art_prompt_manifest.tsv` 推导 `art_asset_manifest.tsv` 行，并按源图是否存在自动写 `PROMPT_READY` / `SOURCE_READY`。
3. `accept_generated_art.py` 负责把最新生图或显式 PNG 原子写入 `source_path`，校验非空可读后推进到 `SOURCE_READY`；必须显式传 `--latest` 或 `--source`。
4. `promote_art_asset.py` 负责从 `source_path` 导出到 `runtime_path`，并回写 `hook_table`。
5. `validate_art_asset_task.py` 只校验这一条资产任务，不重扫全仓。
6. `run_art_asset_flow.py` 把 `accept source -> promote -> compile -> validate -> godot import -> refresh` 串成一条命令。
7. `run_art_asset_flow.py --print-source` 可以先显示“将使用哪张生成图 -> 将写到哪个 `source_path`”；加 `--dry-run` 时只打印计划，不落盘。
8. 当前编译校验已支持 `battle_scene_manifest.tsv`、`narrative_mvp_node_status.tsv`、`performance_timeline.tsv`。

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
