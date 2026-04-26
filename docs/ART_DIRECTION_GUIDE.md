# 《大明之沧海嘀鸣》美术风格基准文档

> 版本：v0.3  
> 对齐分支：`main`  
> 当前叙事源表：`tables/narrative_mvp_prologue_steps.tsv`、`tables/narrative_mvp_nodes.tsv`  
> 辅助参考：`data/battle_scene_manifest.json`、`data/performance_tracks.json`  
> 适用范围：战斗背景、剧情演出背景、叙事道具、角色剪影、UI 包装、主视觉方向。

---

## 0. 当前口径声明

当前美术管线以 `tables/` 下 TSV 为叙事源表，不再以旧版 `data/narrative_mvp_nodes.json` 作为剧情判断主依据。

必须优先对齐：

```text
tables/narrative_mvp_prologue_steps.tsv
tables/narrative_mvp_nodes.tsv
```

这意味着：

- 第一幕节点已从原先的连续事件节点，拆成“遭遇 → 战斗 → 战后处理”的更明确结构。
- 关键战斗节点的 `combat.enabled` 不再直接放在 node 顶层，而是放在 choice 的 `combat` 字段里触发。
- 资源和演出必须支持 aftermath 节点，而不是只服务战斗前节点。
- 数值变量名以 TSV 为准：`military_merit`、`clean_reputation`、`case_clues`。

---

## 1. 当前实装剧情结构

### 1.1 序章十二拍：黑海潮生

源表：`tables/narrative_mvp_prologue_steps.tsv`

当前序章标题为：

```text
序章：黑海潮生
```

序章按 `column` 分为四段：

| column | steps | 视觉主题 |
|---|---|---|
| 旧村 | `black_tide` / `father` / `door` / `dead` / `wooden_blade` / `fall` | 黑潮、旧村、柴堆、敲门、父母遇害、木刀无效、母亲的鞋 |
| 救场 | `master_arrives` / `three_cards` | 旧甲味、师父挡眼、换我、刀/步/断气 |
| 旧案 | `military_word` / `hidden_arrow` / `dont_look` | “军……”、黑箭、不是海上、不是倭人、老兵一直看着箭 |
| 出山 | `departure` | 十年后，学刀学枪学活，师父还刀，该走了 |

序章的核心视觉句：

```text
黑潮没有远过。
箭从岸上来。
后来，你叫他师父。
```

序章美术重点：

- 师父不只是“救援者”，而是“旧甲味 + 看着黑箭的人”。
- 主角成长不是升官动机，而是追问那支箭从哪来。
- `fall` 已更新为“父亲没有再说话，母亲的鞋停在火边”，需补母亲鞋 / 火边小物件。
- `departure` 已更新为“学刀，学枪，学怎么活”，需支持训练、还刀、十年潮声。

### 1.2 第一幕节点链：16 个 TSV 节点

源表：`tables/narrative_mvp_nodes.tsv`

当前第一幕节点顺序：

```text
1. military_order
2. beach_ambush
3. beach_ambush_aftermath
4. fishing_village_embers
5. fishing_village_embers_aftermath
6. merchant_banquet
7. ming_firearm
8. altered_military_report
9. transport_officer
10. transport_officer_aftermath
11. mutiny_camp
12. mutiny_camp_aftermath
13. military_messenger
14. night_knife_camp
15. wakou_boss
16. military_coverup
```

当前结构特征：

- `beach_ambush` / `fishing_village_embers` / `transport_officer` / `mutiny_camp` 是“遭遇节点”，通过 choice 触发战斗。
- `beach_ambush_aftermath` / `fishing_village_embers_aftermath` / `transport_officer_aftermath` / `mutiny_camp_aftermath` 是“战后处理节点”，负责军功、清望、线索分流。
- `wakou_boss` 当前没有单独 aftermath 节点，三种处理直接放在本节点 choice 中。
- `night_knife_camp` 已加入“火器刻印”线索，师父反应成为重点美术信号。

---

## 2. 项目美术定位

《大明之沧海嘀鸣》的美术不是泛古风、泛武侠，而是：

> 明代海疆军武世界中的旧案、压案、忠义与牺牲。

当前叙事更准确的美术主轴是：

```text
海上来的未必是真凶。
岸上射来的箭，军门压下的案，才是潮声不散的原因。
```

玩家第一眼应感受到：

- 海疆风浪压迫
- 明代军门秩序
- 卫所、军旗、军械、火器与案卷
- 倭寇暗袭与海商阴影
- 旧案未明、证据残缺、官泥未干
- 战后处理的道德压力：报功、留证、救人、收编、压案
- 动作先于解释，情绪先于真相

---

## 3. 视觉总原则

### 3.1 不直接解释阴谋，只呈现痕迹

美术不应直接画出“谁是幕后黑手”，而应画出：

- 官泥
- 官造二字
- 新封泥
- 火器刻印
- 缺页案卷
- 涂改军报
- 半页名册
- 无封泥信封
- 第二封信
- 空车
- 空粮袋
- 账本泡烂
- 火器箱
- 黑箭
- 木匣不见
- 师父旧刀

### 3.2 遭遇与战后处理要区分美术语法

TSV 已把多个节点拆成“遭遇 / 战后处理”。美术上必须区分：

| 类型 | 美术重心 | 示例 |
|---|---|---|
| 遭遇节点 | 动作、压迫、战斗触发 | 枪尖出来、烟里刀光、押运官阻拦、营头举枪 |
| 战后处理节点 | 证据、选择、后果 | 尸体脚印、村后火痕、半页名册、跪下的人、账本泡烂 |

不能把 aftermath 继续做成战斗前同一张图的重复。

### 3.3 情绪克制，不做热血爽图

整体气质应为：

```text
冷、压、旧、沉、黑、湿、雾、火光很少但刺眼。
```

尤其 aftermath 节点要更冷、更静、更像“战斗结束后证据还在”。

避免：

- 大面积高饱和红色
- 仙侠光效
- 过度华丽粒子
- 过亮火焰
- 卡通化人物
- 日漫式二次元立绘感
- 直接画明幕后反派

---

## 4. 色彩规范

### 4.1 主色板

| 用途 | 色值 | 说明 |
|---|---:|---|
| 主墨色 | `#080909` / `#111312` | 前景剪影、残木、暗礁、军械 |
| 深夜黑灰 | `#151819` / `#202323` | 海雾、铁器、暗部 |
| 宣纸米色 | `#d8c9a5` / `#e0d0aa` | 天光、纸张、旧案卷 |
| 烟灰 | `#5f6665` / `#687274` | 雾气、烟、远景 |
| 海雾灰蓝 | `#3f565b` / `#31484c` | 海岸、潮水、远礁 |
| 军营土黄 | `#8b806a` / `#5f563e` | 营帐、土路、粮袋 |
| 暗朱红 | `#7e2e28` / `#8f2f27` | 火光、血线、军旗、封泥、箭线 |
| 暗金 | `#8a6a3a` | 官印、甲片边缘、火器铭痕 |

### 4.2 按节点组色彩策略

| 节点组 | 色彩策略 |
|---|---|
| 序章旧村 | 黑灰、海雾灰蓝、火边暗朱红 |
| 海边伏击 | 冷灰蓝、黑礁、官泥土黄、暗箭朱线 |
| 海边战后 | 更低饱和沙灰、尸体黑影、脚印残留 |
| 渔村残火 | 烟灰、米色、村后暗火 |
| 渔村战后 | 黑烟渐低、冷灰、火痕暗红、孩子线索 |
| 海商 / 火器 | 暗金、铁黑、热酒暗红、雨灰 |
| 涂改军报 | 宣纸米、墨黑、破庙灰、血暗红 |
| 押运官 | 土黄灰、泥路黑灰、名册米色 |
| 押运官战后 | 湿纸、空车、泥水、半页名册焦点 |
| 欠饷营 | 土黄灰、低饱和军旗红、饥饿黑影 |
| 欠饷营战后 | 更静、更冷，重点在跪下的人和账本 |
| 军门信使 | 雨灰、冷蓝、马影黑、信封米色 |
| 夜半磨刀 | 深夜黑灰、铁黑、火边火器刻印暗金 |
| Boss / 压案 | 破船冷蓝灰、火器箱暗金、军门案房米黑 |

---

## 5. 构图规范

### 5.1 战斗背景构图

战斗背景需要兼顾氛围与可读性：

- 画面尺寸默认 `1280x720`，`viewBox="0 0 1280 720"`。
- 主体结构应在中上部，避免遮挡角色和格位。
- 前景可有残木、旗杆、石块，但不得遮挡核心战斗区。
- 中景承担场景识别：村屋、营门、破船、押运车、海岸。
- 远景承担情绪：海雾、山影、黑潮、火光、阴云。

当前 7 张战斗背景已进入“正式分镜样张”阶段：

```text
battle_bg_black_tide.svg
battle_bg_coast_ambush.svg
battle_bg_fishing_village_embers.svg
battle_bg_transport_road.svg
battle_bg_mutiny_camp.svg
battle_bg_broken_ship.svg
battle_bg_training_ground.svg
```

### 5.2 剧情演出背景构图

剧情表演区比战斗背景更强调叙事痕迹：

- 遭遇节点：人物压迫 + 场景主体。
- aftermath 节点：物证特写 + 沉默空间。
- 线索节点：道具焦点，如军报、火器刻印、信封、名册。
- 师父相关节点：避免直说秘密，表现“手停了一下”“一直看着黑箭”“用袖口盖住刻印”。

---

## 6. SVG 资产规范

当前 Web 构建阶段优先使用 SVG。要求：

- 纯 SVG 基础图形、路径、渐变、滤镜。
- 不引用外部图片。
- 不使用外部字体。
- 不引入 font 文件。
- 不写远程资源 URL。
- 不在背景内写标题文字。
- 控制路径数量，避免过度复杂导致 Web 构建或运行性能不稳定。
- 不新增第二套战斗背景层。
- 背景路径只通过 manifest 或演出配置引用，不写死在 GDScript。

推荐文件命名：

```text
assets/pixel_battle/backgrounds/battle_bg_<scene_name>.svg
assets/narrative/backgrounds/bg_<node_id>.svg
assets/narrative/props/prop_<object_name>.svg
assets/narrative/silhouettes/sil_<role_or_action>.svg
```

---

## 7. 场景资产标准

### 7.1 战斗背景完成标准

一张正式战斗背景至少满足：

1. 不看文字能判断场景类型。
2. 有清晰近中远三层。
3. 有一个明确视觉记忆点。
4. 不遮挡战斗角色、格位和 UI。
5. 色调与项目主色板一致。
6. 不含内嵌标题文字。
7. 与对应 TSV node 的视觉意象一致。

当前 battle 背景状态：

| 背景 | 状态 | 备注 |
|---|---|---|
| `battle_bg_black_tide.svg` | `DONE_BASE` | 已有师父挡箭、箭线、远火村影 |
| `battle_bg_coast_ambush.svg` | `DONE_BASE` | 已有暗礁、倭影、斜向暗箭 |
| `battle_bg_fishing_village_embers.svg` | `DONE_BASE` | 已有残村、黑烟、村后火、孩子线索 |
| `battle_bg_transport_road.svg` | `DONE_BASE` | 已有空车、断封条、散落军械、车辙 |
| `battle_bg_mutiny_camp.svg` | `DONE_BASE` | 已有营门、低旗、空锅、饥饿士兵 |
| `battle_bg_broken_ship.svg` | `DONE_BASE` | 已有破船、火器箱、倭首、岸上暗箭 |
| `battle_bg_training_ground.svg` | `DONE_BASE` | 已有枪架、刀靶、校场木架 |

### 7.2 剧情演出完成标准

一段正式剧情演出至少满足：

1. 对应 TSV node，而不是只对应旧 JSON node。
2. 有专属 `timeline` track，不能长期只走 `node` fallback。
3. 有明确 focus：人物、物件、火光、雾、暗层之一。
4. 有一个可挂接的 prop 或 silhouette。
5. 与 TSV 文案痕迹一致。
6. 不直接揭示幕后真相。

当前需要优先补 track 的节点包括：

```text
beach_ambush_aftermath
fishing_village_embers
fishing_village_embers_aftermath
merchant_banquet
altered_military_report
transport_officer_aftermath
mutiny_camp
mutiny_camp_aftermath
military_messenger
night_knife_camp
```

---

## 8. 角色与道具资产规范

### 8.1 当前已有资源池

```text
assets/narrative/props/prop_casefile_missing_page.svg
assets/narrative/props/prop_firearm_crate.svg
assets/narrative/props/prop_unsealed_letter.svg
assets/narrative/silhouettes/sil_master_blocks_arrow.svg
assets/narrative/silhouettes/sil_wakou_ambusher.svg
assets/narrative/silhouettes/sil_transport_officer_shadow.svg
assets/narrative/silhouettes/sil_starving_soldier_shadow.svg
assets/narrative/silhouettes/sil_wakou_boss_shadow.svg
```

### 8.2 TSV 口径下的 P0 新增资源

```text
prop_mother_shoe_by_fire.svg
prop_wooden_training_blade.svg
prop_military_order_seal.svg
prop_coastal_patrol_map.svg
prop_official_mud_bootprint.svg
prop_burnt_bowl.svg
prop_wine_cup_key.svg
prop_firearm_seal_mark.svg
prop_altered_military_report.svg
prop_half_roster_wet.svg
prop_soaked_payroll_book.svg
prop_old_master_saber.svg
prop_empty_wooden_case.svg
sil_father_hiding_child.svg
sil_coughing_child_shadow.svg
sil_merchant_shadow.svg
sil_messenger_on_horse_shadow.svg
sil_grinding_saber_shadow.svg
```

---

## 9. UI 视觉规范

UI 不应是泛古风边框，而应围绕：

```text
军令牌
案卷纸
官印封泥
兵册名录
海防图
火器图纸
刀谱残页
```

UI 下一阶段应优先服务 TSV 中的三类变量：

```text
military_merit
clean_reputation
case_clues
```

不要再使用旧口径 `jun_gong / qing_wang / clues`。

---

## 10. 节点视觉一致性规则

每个美术资源必须回查 TSV node，而不是旧 JSON 文案。

| 节点 | 当前 TSV 视觉意象 |
|---|---|
| `military_order` | 军令压案、墨未干、旧案不得声张、师父没有抬头 |
| `beach_ambush` | 整齐脚印、像营里走出来、芦苇枪尖、官泥 |
| `beach_ambush_aftermath` | 尸体、脚印还在、割首/搜身/掩埋 |
| `fishing_village_embers` | 残村、孩子咳嗽、船未靠岸、村心先烧、烟里刀光 |
| `fishing_village_embers_aftermath` | 黑烟渐低、村后火痕、追人/救人/看火 |
| `merchant_banquet` | 雨夜海商宅、热酒冷兵、屏风后火器箱、酒盏旁钥匙 |
| `ming_firearm` | 倭船舱、木箱半开、官造火器、新封泥 |
| `altered_military_report` | 破庙、倒神像、香炉下军报、墨比血新、少的是人 |
| `transport_officer` | 山道空车、深车辙、不该翻箱、袖口半页名册 |
| `transport_officer_aftermath` | 空车、半页湿名册、押运官还活着、交给谁 |
| `mutiny_camp` | 营门、军旗、无粮、饷银没到、营头举枪不是为了海寇 |
| `mutiny_camp_aftermath` | 跪下的人、军粮仍无、写成反/饥/账 |
| `military_messenger` | 雨中信使、马先喘、无封泥信封、第二封信 |
| `night_knife_camp` | 深夜磨旧刀、火器刻印、师父手停、见过但不能再问 |
| `wakou_boss` | 破船、火器箱、倭首坐箱、看岸上、军门火漆 |
| `military_coverup` | 军门灯火、缺页案卷、朱批、木匣不见、师父站在门外 |

---

## 11. 禁止事项

1. 禁止把背景路径写死在 GDScript。
2. 禁止新增第二套战斗背景层。
3. 禁止在 SVG 中引用外链图片。
4. 禁止引入字体文件。
5. 禁止在背景图中内嵌标题文字。
6. 禁止把正式战斗背景做成小图标。
7. 禁止高饱和仙侠光效。
8. 禁止卡通化、Q版化。
9. 禁止直接画明阴谋真相。
10. 禁止为了单张图好看破坏整体色板。
11. 禁止将旧 JSON 文案误标为最新实装剧情。
12. 禁止继续使用旧变量名 `jun_gong / qing_wang / clues` 作为 UI 口径。

---

## 12. 阶段验收口径

### 阶段 A：统一风格样张

当前状态：基本完成。

- 第一幕所有战斗背景无占位文字。
- 每张战斗背景有明确视觉记忆点。
- 色板已统一到黑灰、米色、海雾灰蓝、土黄灰、暗朱红。

### 阶段 B：可展示原型

当前状态：进行中。

需完成：

```text
1. 补 aftermath 节点的剧情演出资源。
2. 把现有 props / silhouettes 挂入 performance_tracks 或演出配置。
3. 补 TSV 新增线索资源：火器刻印、半页湿名册、泡烂账本、母亲鞋、师父旧刀。
4. UI 变量口径改为 military_merit / clean_reputation / case_clues。
```

### 阶段 C：正式展示包

当前状态：未开始。

需完成：

```text
1. 主视觉 key art。
2. 标题字“沧海嘀鸣”。
3. 3-5 张对外截图。
4. 角色概念设定页。
5. 节点视觉矩阵无 P0 空缺。
```
