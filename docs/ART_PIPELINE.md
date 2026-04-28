# 《大明之沧海嘀鸣》美术管线总入口

> 当前口径：`main`
> 本文件是美术相关文档入口。若其他文档与本文冲突，以本文、`ART_DIRECTION_GUIDE.md`、`NODE_VISUAL_MATRIX.md`、`ART_PRODUCTION_ROADMAP.md` 为准。当前目标已从“运行级样张”升级为“正式美术质量”。

## 1. 当前权威文档

| 文档 | 负责范围 |
|---|---|
| `docs/ART_PIPELINE.md` | 美术文档入口、源头规则、运行管线、验收命令 |
| `docs/ART_DIRECTION_GUIDE.md` | 风格基准、色板、构图、安全边界、禁止事项 |
| `docs/NODE_VISUAL_MATRIX.md` | 节点 / battle_id / visual_path / performance track / 资源状态 |
| `docs/ART_PRODUCTION_ROADMAP.md` | 当前完成度、下一阶段、截图验收和精修路线 |
| `docs/ART_REFERENCE_PROMPTS.md` | 参考图与概念图提示词；只用于参考，不直接运行 |

## 2. 数据源与运行源

策划入口只看 TSV：

```text
tables/narrative_mvp_prologue_steps.tsv
tables/narrative_mvp_nodes.tsv
tables/narrative_mvp_node_status.tsv
tables/performance_*.tsv
```

运行产物由编译器生成：

```text
data/narrative_mvp_nodes.json
data/performance_tracks.json
```

规则：

1. 改剧情、美术挂接、performance 参数时，先改 TSV。
2. 不直接手改 `data/narrative_mvp_nodes.json` 或 `data/performance_tracks.json`。
3. `visual_path` 以 `tables/narrative_mvp_node_status.tsv` 为源头。
4. 剧情演出焦点、道具、剪影、雾、火光、镜头以 `tables/performance_*.tsv` 为源头。
5. 游戏验收看编译后的 JSON 和实际 `NarrativeDemo` 画面。

## 3. 当前正式运行资产路线

当前 Web / Godot 正式美术运行资源优先使用高质量 PNG：

```text
assets/pixel_battle/backgrounds/*.png
assets/pixel_battle/relics/*.png
assets/pixel_battle/portraits/*.png
assets/pixel_battle/ui/*.png
assets/narrative/props/*.png
assets/narrative/silhouettes/*.png
```

参考 / 源画 PNG 可放在：

```text
art_reference/generated/*.png
art_reference/final/*.png
```

规则：

1. `art_reference/generated/*.png` 是参考图、概念图或临摹母版，不直接写入运行 `visual_path`。
2. `art_reference/final/*.png` 是正式源画 / 精修母版，可作为运行导出的来源。
3. `assets/**/*.png` 是正式运行导出，允许写入 `visual_path` 和 performance track。
4. SVG 只保留给 UI 矢量件、FX、调试占位、临时回退或仍未转正的旧资源，不作为正式美术质量目标。

## 3.5 正式美术生产层

正式美术质量允许存在“源画 / 母版”和“运行导出”两层：

```text
正式源画 / 母版：用于定稿、精修、对外展示，保存在 art_reference/final
运行导出：由母版导出为 Godot/Web 可承载的高质量 PNG，保存在 assets
```

当前建议：

```text
art_reference/generated/*.png      参考图 / 概念草案 / 临摹母版
art_reference/final/*.png          正式源画 / 精修母版
assets/**/*.png                    正式运行导出
assets/**/*.svg                    UI 矢量 / FX / 调试占位 / 旧资源回退
tables/performance_*.tsv           游戏内构图和镜头参数
```

质量分层：

| 层级 | 含义 |
|---|---|
| `RUNTIME_WIRED` | 已接入运行，可以显示 |
| `STYLE_LOCKED` | 风格、构图、叙事焦点已定 |
| `FORMAL_SOURCE_READY` | 有可作为正式质量母版的参考图或精修稿 |
| `RUNTIME_EXPORT_READY` | 正式母版已转为合规高质量 PNG 运行资源 |
| `IN_GAME_ACCEPTED` | 已在 NarrativeDemo / MainVisual 截图验收 |
| `SHOWCASE_READY` | 可用于商店页、宣传页或对外截图 |

注意：正式运行 PNG 不能绕过 TSV / 编译 / performance 管线直接进入运行。参考草图也不能冒充正式运行导出。

角色源画补充规则：

```text
主角必须按职业路线成对生产：
- hero_officer_spear：戚家军枪手 / 长枪路线
- hero_officer_saber：单刀快手 / 腰刀路线

两版必须同脸、同甲、同色系，只改变武器和战斗姿态。
每个角色源画必须写明 weapon_id / role_id / 绑定招式关键词，方便后续战斗动作包和卡牌视觉复用。
```

当前运行层已经落地第一轮路线主角导出：

```text
tools/generate_formal_art_assets.py
assets/pixel_battle/portraits/hero_officer_spear_bust.png
assets/pixel_battle/portraits/hero_officer_saber_bust.png
assets/pixel_battle/portraits/performance_hero_spear.png
assets/pixel_battle/portraits/performance_hero_saber.png
```

`NarrativeDemo` 的焦点半身层和演出 hero 层会根据 `NarrativeBattleContext.player_profile.role` 自动切换，不需要在 TSV 中为同一节点硬分两套 visual_path。

## 4. 节点美术接入规则

主流程判断：

```text
tables/narrative_mvp_node_status.tsv
flow_enabled=true
implementation_status=playable
```

接入链路：

```text
叙事 TSV
→ node_status.tsv visual_path
→ performance_*.tsv 多焦点演出
→ scripts/compile_tables.py
→ data/narrative_mvp_nodes.json / data/performance_tracks.json
→ NarrativeDemo 实机验收
```

禁止：

1. 不把背景路径写死到 GDScript。
2. 不新增第二套背景层。
3. 不让 `art_reference/generated` 的参考草图直接进入运行路径。
4. 不把 SVG 当作正式场景 / 角色 / 道具美术的最终交付格式。
5. 不在背景图里写标题文字。
6. 不把低清、压缩过度、AI 草稿或临时占位 PNG 当作正式资源。

## 5. 当前阶段

当前状态：

```text
P0 主流程 visual_path 已接线
P0 证据道具和核心剪影已接入 performance_tracks
reserved/P2 节点已有首轮运行资源和 track 预接线
角色半身、UI 包装、标题字、行军图底纹已接入 NarrativeDemo 可见层
主角枪版 / 刀版运行 PNG 已按 player_profile 接入剧情焦点层和演出层
正式美术口径已切换为 PNG，现有 SVG 只作为旧资源回退或矢量用途
```

下一阶段：

```text
1. 先收序章 12 拍，全部切到正式高质量 PNG 或 PNG performance 焦点。
2. 再锁定 5 张正式展示截图：黑潮救援、海边伏击、渔村残火、夜半磨刀、军门压案。
3. 为目标节点建立 art_reference/final 母版，并导出到 assets/**/*.png。
4. 通过 TSV / performance 接入 PNG，不手改 JSON，不写死 GDScript。
5. 根据截图调 performance_timeline.tsv 中的焦点位置、scale、alpha。
6. 需要把 reserved 节点转主流程时，只改 node_status.tsv 与对应 TSV，不改 GDScript。
```

## 6. 验收命令

```bash
python3 scripts/compile_tables.py
python3 tools/validate_performance_tracks.py
godot --headless --quit
```

Web 包体或浏览器验收：

```bash
rm -rf build/web build/web.zip
./tools/build_and_serve_web.sh
```

## 7. 已废弃文档口径

以下旧口径不再作为当前美术执行依据：

```text
SVG 优先
参考 PNG 不进入任何 runtime
正式源画必须转 SVG 才能运行
1600 × 900 / 16:9 作为当前 Web 唯一基准
单局 P0 PNG 资产清单
散落的 prompt override 文件互相覆盖
只按 narrative nodes 推进，不看 node_status.tsv
```
