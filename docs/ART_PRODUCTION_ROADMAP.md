# 《大明之沧海嘀鸣》正式美术质量路线图

> 版本：v0.2
> 分支：`main`
> 文档入口：`docs/ART_PIPELINE.md`
> 用途：把当前“可运行风格样张”升级为“正式美术质量”的生产、挂接、验收路线。

---

## 0. 总判断

当前项目已经完成第一阶段：

```text
TSV 策划入口
→ JSON 编译产物
→ 高质量 PNG 运行资源
→ visual_path / performance_tracks 挂接
→ NarrativeDemo 可见
```

这说明“美术管线能跑通”，但不等于“正式美术质量已经达标”。下一阶段目标从“补资源缺口”切换为：

```text
正式源画定调
→ 节点级精修
→ 角色 / UI / 战斗背景统一精修
→ 游戏内截图验收
→ 对外展示包
```

核心判断：

```text
P0 主流程已有运行接线基础。
当前最大短板不是缺图，而是旧运行级 SVG 无法承载正式美术细节；下一阶段必须切到高质量 PNG，提升角色辨识度、空间真实感、材质和展示截图质量。
```

---

## 1. 正式美术质量定义

正式美术质量不是单张图更复杂，而是玩家不读 debug、不看文档，也能从画面上稳定读出：

```text
明代海疆
军武秩序
旧案痕迹
压案阴影
忠义牺牲
风起沧海
```

每张正式资产必须满足 6 个维度：

| 维度 | 达标要求 |
|---|---|
| 叙事可读 | 一眼能读到节点核心物件或行动，不靠标题文字解释 |
| 明代可信 | 服饰、武器、军械、营帐、案卷、船、官印不现代化、不玄幻化 |
| 构图稳定 | 主视觉焦点清楚，字幕区和操作区不被关键物遮挡 |
| 材质成立 | 金属、湿沙、木箱、纸张、火光、雾气有区分，不是一层平涂 |
| 色彩统一 | 黑灰、宣纸米色、海雾灰蓝、暗朱红、少量暗金，不跑成泛古风 |
| 实机有效 | 在 `NarrativeDemo` / `MainVisual` 中截图仍清楚、无错位、无过曝、无脏糊 |

---

## 2. 资产分层

正式美术生产分四层，不混用：

| 层级 | 路径 / 产物 | 用途 | 是否运行读取 |
|---|---|---|---|
| 叙事源头 | `tables/narrative_mvp_*.tsv` | 节点语义、visual_path、战斗触发 | 编译后读取 |
| 参考 / 概念草案 | `art_reference/generated/*.png` | 构图、光色、角色设计、方向探索 | 不直接运行 |
| 正式源画 / 母版 | `art_reference/final/*.png` | 精修母版、对外展示、运行导出来源 | 不直接运行 |
| 正式运行导出 | `assets/**/*.png` | Godot / Web 实际读取 | 是 |
| 矢量 / 回退资源 | `assets/**/*.svg` | UI 矢量、FX、调试占位、旧资源回退 | 仅限对应用途 |
| 演出配置 | `tables/performance_*.tsv` → `data/performance_tracks.json` | 多焦点、镜头、雾、火光、角色 / 道具位置 | 是 |

当前规则保持：

```text
art_reference/generated 不直接写入 visual_path。
正式运行层优先使用 assets/**/*.png。
SVG 不再作为正式场景 / 角色 / 道具美术目标，只保留 UI、FX、调试占位和旧资源回退。
PNG 接入仍必须走 TSV / 编译 / performance / 实机截图验收。
```

---

## 3. 质量状态标记

后续在 `NODE_VISUAL_MATRIX.md` 和评审记录中使用以下状态：

| 状态 | 含义 |
|---|---|
| `RUNTIME_WIRED` | 已接入 visual_path 或 performance track，游戏能显示 |
| `STYLE_LOCKED` | 构图、色板、叙事焦点已定，不再大改方向 |
| `FORMAL_SOURCE_READY` | 有可作为正式质量母版的参考图 / 精修稿 |
| `RUNTIME_EXPORT_READY` | 正式母版已转成合规高质量 PNG 运行资源 |
| `IN_GAME_ACCEPTED` | 已在 NarrativeDemo / MainVisual 截图验收通过 |
| `SHOWCASE_READY` | 可用于商店页、宣传页或对外截图 |

当前大多数资源处于：

```text
RUNTIME_WIRED
```

下一阶段目标是把 P0 主流程推进到：

```text
STYLE_LOCKED → FORMAL_SOURCE_READY → RUNTIME_EXPORT_READY → IN_GAME_ACCEPTED
```

---

## 4. 阶段计划

### F0：正式美术基准锁定

目标：把文档口径从“运行样张 / SVG 优先”改为“正式质量 PNG 目标”。

完成标准：

```text
[x] ART_PIPELINE 明确 PNG 正式运行层
[x] ART_DIRECTION_GUIDE 明确正式质量门槛和 PNG 资产规范
[x] ART_PRODUCTION_ROADMAP 改为 PNG 正式质量路线
[x] NODE_VISUAL_MATRIX 按 PNG visual_path / performance 状态滚动更新
```

### F1：序章 12 拍 PNG 化

先把序章所有流程完全切到正式 PNG，避免一开局仍暴露旧 SVG 样张。

| 顺序 | 拍点 | PNG 化目标 |
|---:|---|---|
| 1 | `black_tide` | 黑潮开场背景 PNG，读出夜、潮、火、逃 |
| 2 | `father` | 父亲藏子 PNG 焦点，动作可读 |
| 3 | `door` | 刀背敲门 PNG 道具焦点 |
| 4 | `dead` | 抽象暗场 PNG，不直画屠杀 |
| 5 | `wooden_blade` | 木刀打甲片 PNG 道具焦点 |
| 6 | `fall` | 母亲鞋 / 火边 PNG 焦点 |
| 7 | `master_arrives` | 师父挡眼 / 旧甲 PNG 人物焦点 |
| 8 | `three_cards` | 刀、步、断气的三卡 / 刀谱 PNG 焦点 |
| 9 | `military_word` | “军……”不能硬写成大字，改用黑箭前的压迫 PNG 焦点 |
| 10 | `hidden_arrow` | 黑箭 PNG 焦点 |
| 11 | `dont_look` | 师父看黑箭 PNG 焦点 |
| 12 | `departure` | 旧刀归还 / 出山 PNG 焦点 |

完成标准：

```text
序章 visual_path 和 performance track 不再依赖正式用途的 SVG。
所有正式 PNG 来自 art_reference/final 或明确的 assets 导出。
NarrativeDemo 走完整序章没有文本占位、低清图、debug 遮挡或 UI 遮挡。
```

当前执行状态：

```text
[x] 12 拍已改为逐拍 PNG performance stage。
[x] `dead`、`three_cards`、`military_word` 已补正式 PNG 运行导出。
[x] `tools/smoke_narrative_prologue_png.gd` 已验证 12 拍 stage / background / prop 资源可由 Godot 读取。
[ ] 仍需人工截图确认构图质量与 UI 遮挡。
```

### F2：5 张展示级截图锁定

序章完成后，再锁 5 张能代表项目气质的截图：

| 截图 | 场景 | 目标 |
|---|---|---|
| S01 | 黑潮救援 / 序章 | 师父、黑箭、旧案第一钩子 |
| S02 | 海边伏击 | 官泥脚印、芦苇枪尖、军伍感敌人 |
| S03 | 渔村残火 | 残村、黑烟、孩子线索、村后火 |
| S04 | 夜半磨刀 | 旧刀、火器刻印、师父手停 |
| S05 | 军门压案 | 缺页案卷、空木匣、朱批、门外师父 |

完成标准：

```text
每张截图都能在 3 秒内读出节点主题。
无 debug 遮挡。
字幕、选择按钮、主焦点不互相打架。
可直接作为内部展示材料。
```

### F3：P0 节点正式精修

优先处理主流程，不扩散到 reserved 节点：

| 优先级 | 节点 | 当前状态 | 正式精修目标 |
|---:|---|---|---|
| 1 | `night_knife_camp` | `RUNTIME_WIRED` | 深夜湿地、旧刀、火器刻印、师父停手必须成为强焦点 |
| 2 | `military_coverup` | `RUNTIME_WIRED` | 案卷缺页、朱批、空木匣、门外师父形成压案画面 |
| 3 | `beach_ambush` / aftermath | `RUNTIME_WIRED` | 官泥脚印和军伍感敌人，区别普通海盗伏击 |
| 4 | `fishing_village_embers` / aftermath | `RUNTIME_WIRED` | 村心先烧、孩子咳嗽线索、战后选择后果 |
| 5 | `ming_firearm` | `RUNTIME_WIRED` | 官造刻印和保养良好的火器必须清楚 |
| 6 | `altered_military_report` | `RUNTIME_WIRED` | 墨比血新、涂改痕、倒神像形成证据焦点 |
| 7 | `transport_officer` / aftermath | `RUNTIME_WIRED` | 空车、半页湿名册、押运官恐惧要可读 |
| 8 | `wakou_boss` | `RUNTIME_WIRED` | 破船、火器箱、军门火漆、岸上暗箭成为 Boss 记忆点 |

### F4：角色与 UI 正式精修

角色目标：

| 角色 | 当前状态 | 正式目标 |
|---|---|---|
| 主角枪版 `hero_officer_spear` | 已生成路线半身 / 演出 PNG，并按 `player_profile.role=spearman` 接入 NarrativeDemo | 与刀版同脸同甲，明确明代军用长枪，绑定 `mid_spear` / `chain_thrust` / `pinning_hold` / `dragon_break` |
| 主角刀版 `hero_officer_saber` | 已生成路线半身 / 演出 PNG，并按 `player_profile.role=blademaster` 接入 NarrativeDemo | 与枪版同脸同甲，明确明代腰刀 / 单刀，绑定 `swift_cut` / `cross_slash` / `dragonslash` / `rush_step` |
| 师父老兵 | 运行级半身 PNG | 旧甲、旧刀、迟到的愧疚和危险感 |
| Boss 倭首 | 运行级半身 PNG | 海寇身份 + 明制火器疑点，不能怪物化 |
| 押运官 | 剪影 / portrait 资源 | 恐惧、湿名册、失械案压力 |
| 军门上官 | 规划中 | 制度压迫，不画成脸谱奸臣 |

主角双版本硬规则：

```text
枪版和刀版必须像同一个人。
同一张脸、同一年龄、同一发带、同一明制札甲轮廓、同一深绛红战袍体系。
只改变武器、站姿、手势和战斗重心。
枪版不能手持刀；刀版不能出现长枪。
```

武器和招式绑定必须进入角色设定页、半身图、战斗站姿和后续动作包设计，不能只在文字说明里存在。

当前已落地的运行资源：

```text
assets/pixel_battle/portraits/hero_officer_spear_bust.png
assets/pixel_battle/portraits/hero_officer_saber_bust.png
assets/pixel_battle/portraits/performance_hero_spear.png
assets/pixel_battle/portraits/performance_hero_saber.png
```

接线规则：

```text
NarrativeBattleContext.player_profile.role=spearman
→ 枪版半身 / 枪版演出立绘

NarrativeBattleContext.player_profile.role=blademaster
→ 刀版半身 / 刀版演出立绘
```

UI 目标：

```text
案卷纸文本框
军令牌 / 木签式选择
海防图大地图
兵书残页式卡牌
官印 / 封泥式状态图标
```

原则：UI 精修不能牺牲信息密度和可读性。

### F5：战斗背景正式精修

战斗背景不追求宣发插画，但必须做到：

```text
战斗舞台有空间深度
前中后景清楚
角色不融进背景
敌我职业和距离选择仍易读
背景和剧情节点气质一致
```

优先顺序：

```text
first_act_beach_ambush
first_act_fishing_village_embers
first_act_transport_officer
first_act_wakou_boss
prologue_master_rescue
test_spearman_duel / test_blademaster_duel
```

### F6：展示包

交付物：

```text
1 张主视觉 key art
1 张标题 / capsule 试版
5 张游戏内截图
3 张角色设定页
1 张证据链物件页
1 段 30 秒 Web demo 录屏
```

展示包达标后，才进入下一轮“扩充节点 / 追加人生线 / 更多角色动画”。

---

## 5. 本轮不做

为了保持质量，不在本阶段同时做这些事：

```text
不新增第二套背景层。
不把参考 PNG 直接塞进 visual_path。
不扩写 reserved 节点剧情。
不新增多地图。
不重构战斗规则。
不为了单图漂亮破坏 TSV / performance 管线。
不把 UI 做成遮挡文本的装饰画框。
```

---

## 6. 验收流程

每轮正式美术精修后必须跑：

```bash
python3 scripts/compile_tables.py
python3 tools/validate_performance_tracks.py
godot --headless --quit
```

截图验收：

```text
1. 进入 NarrativeDemo。
2. 关闭 debug。
3. 跑序章和第一幕主流程。
4. 截取 F1 五张目标截图。
5. 检查字幕、操作区、主焦点、角色半身、props 是否互相遮挡。
6. 若遮挡，优先调 performance_timeline.tsv，不改 GDScript。
```

Web 验收：

```bash
rm -rf build/web build/web.zip
./tools/build_and_serve_web.sh
```

通过标准：

```text
Web 可启动
中文不乱码
运行资源无缺失
主流程截图不遮挡
包体仍在可接受范围
```

---

## 7. 下一步执行清单

按顺序推进：

```text
1. 先按 F1 收序章 12 拍，逐拍确认 assets PNG 和 performance 焦点。
2. `dead`、`three_cards`、`military_word` 先补最小正式 PNG，不再留“无 / P2”缺口。
3. 更新 node_status.tsv 和 performance_*.tsv，把正式用途路径切到 PNG。
4. 运行 compile_tables.py / validate_performance_tracks.py / Godot headless。
5. NarrativeDemo 关闭 debug，走完整序章截图验收。
6. 序章通过后，再锁 S01-S05 五张展示截图。
7. 把通过验收的节点在 NODE_VISUAL_MATRIX 标为 IN_GAME_ACCEPTED。
```

当前最优先的一刀：

```text
prologue 12 beats
```

原因：

```text
序章是一开局，必须先确保玩家看到的第一套完整流程已经全部是正式高质量 PNG。
```
