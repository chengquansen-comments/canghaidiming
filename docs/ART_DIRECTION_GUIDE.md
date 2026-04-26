# 《大明之沧海嘀鸣》美术风格基准文档

> 版本：v0.2  
> 对齐分支：`main`  
> 对齐依据：`data/narrative_mvp_nodes.json` v2、`data/battle_scene_manifest.json`、`data/performance_tracks.json`  
> 适用范围：战斗背景、剧情演出背景、叙事道具、角色剪影、UI 包装、主视觉方向。

---

## 0. 当前实装状态摘要

当前实装剧情已经形成稳定的“序章十二拍 + 第一幕节点链 + 多结局变体”结构。

### 0.1 序章核心节拍

序章不是完整说明，而是一组压缩镜头：

```text
黑潮 → 父亲藏子 → 倭刀敲门 → 父母遇害 → 木刀无效 → 主角倒地 → 师父接敌 → 敌人口吐“军” → 岸上暗箭 → 十年后出山
```

序章视觉基准：

- 黑潮、柴堆、火光、母亲的鞋、木刀、师父挡眼、箭从岸上来。
- 不能提前解释“谁是内鬼”，只强调“不是海上，不是倭人”。

### 0.2 第一幕实装节点

当前第一幕节点：

```text
military_order
beach_ambush
fishing_village_embers
merchant_banquet
ming_firearm
altered_military_report
transport_officer
mutiny_camp
military_messenger
night_knife_camp
wakou_boss
military_coverup
```

其中已有正式战斗背景挂接的战斗节点：

```text
prologue_master_rescue
first_act_beach_ambush
first_act_fishing_village_embers
first_act_transport_officer
first_act_mutiny_camp
first_act_wakou_boss
```

当前 `performance_tracks.json` 已有演出 track 的节点 / 镜头：

```text
black_tide_0
black_tide_1
black_tide_2
black_tide_3
master_rescue
arrow_silence
departure
military_order
beach_ambush
ming_firearm
transport_officer
wakou_boss
military_coverup
node
```

仍需补专属演出 track 的重点节点：

```text
fishing_village_embers
merchant_banquet
altered_military_report
mutiny_camp
military_messenger
night_knife_camp
```

---

## 1. 项目美术定位

《大明之沧海嘀鸣》的美术不是泛古风、泛武侠，而是：

> 明代海疆军武世界中的旧案、压案、忠义与牺牲。

玩家第一眼应感受到：

- 海疆风浪压迫
- 明代军门秩序
- 卫所、军旗、军械、火器与案卷
- 倭寇暗袭与海商阴影
- 旧案未明、证据残缺、官泥未干
- 动作先于解释，情绪先于真相

当前实装叙事的核心视觉句：

```text
倭寇从海上来。
箭从岸上来。
```

这句话应成为第一幕所有美术资源的主控原则。

---

## 2. 视觉总原则

### 2.1 不直接解释阴谋，只呈现痕迹

美术不应直接画出“谁是幕后黑手”，而应画出：

- 官泥
- 官造二字
- 缺页案卷
- 未干封泥
- 火器箱
- 被涂改的军报
- 空粮袋
- 深车辙
- 暗箭
- 破船
- 低垂军旗
- 师父旧刀
- 木匣不见

### 2.2 动作先于说明

当前剧情已经明确要求“动作先于解释；不说真相，只说痕迹”。美术执行时必须优先给行动瞬间：

- 师父挡眼 / 挡箭
- 主角木刀打在甲片上
- 枪尖从芦苇里出来
- 烟里有人影，刀光很低
- 押运官说“你不该翻箱”
- 欠饷营头举枪，不是为了海寇
- 倭首坐在火器箱上，看岸，不看海
- 军门案卷正好少了一页

### 2.3 情绪克制，不做热血爽图

整体气质应为：

```text
冷、压、旧、沉、黑、湿、雾、火光很少但刺眼。
```

避免：

- 大面积高饱和红色
- 仙侠光效
- 过度华丽粒子
- 过亮的火焰
- 卡通化人物
- 日漫式二次元立绘感
- 把阴谋人物直接画成反派脸

---

## 3. 色彩规范

### 3.1 主色板

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

### 3.2 按节点的色彩分组

| 节点组 | 色彩策略 |
|---|---|
| 序章黑潮 | 黑灰、海雾灰蓝、少量暗朱红远火 |
| 海边伏击 / Boss | 冷灰蓝、黑礁、暗箭朱线 |
| 渔村残火 | 烟灰、米色、后场暗火 |
| 海商 / 火器 | 暗金、铁黑、热酒暗红、雨灰 |
| 军报 / 军门压案 | 宣纸米、墨黑、封泥暗红 |
| 押运官 / 欠饷营 | 土黄灰、黑灰、低饱和军旗红 |
| 夜半磨刀 | 深夜黑灰、铁黑、极少营火红 |

---

## 4. 构图规范

### 4.1 战斗背景构图

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

### 4.2 剧情演出背景构图

剧情表演区比战斗背景更强调叙事痕迹：

- 可增加局部特写，例如封泥、案卷、火器箱、旧刀。
- 人物多用剪影，不急于使用精绘立绘。
- 镜头可从物件推进到人物，而不是直接给完整解释。
- 同一节点至少保留一个“可记忆物件”。

当前已有资源池但尚未全部挂接：

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

下一步重点不是继续散做资源，而是把这些资源挂入 `performance_tracks.json` 或对应演出配置结构。

---

## 5. SVG 资产规范

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

## 6. 场景资产标准

### 6.1 战斗背景完成标准

一张正式战斗背景至少满足：

1. 不看文字能判断场景类型。
2. 有清晰近中远三层。
3. 有一个明确视觉记忆点。
4. 不遮挡战斗角色、格位和 UI。
5. 色调与项目主色板一致。
6. 不含内嵌标题文字。
7. 与对应 narrative node 的视觉意象一致。

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

### 6.2 剧情演出完成标准

一段正式剧情演出至少满足：

1. 有专属 `timeline` track，不能长期只走 `node` fallback。
2. 有明确 focus：人物、物件、火光、雾、暗层之一。
3. 有一个可挂接的 prop 或 silhouette。
4. 与 narrative node 的文案痕迹一致。
5. 不直接揭示幕后真相。

当前需要优先补 track 的节点：

```text
fishing_village_embers
merchant_banquet
altered_military_report
mutiny_camp
military_messenger
night_knife_camp
```

---

## 7. 角色资产规范

### 7.1 角色风格

角色方向应为：

```text
国风写实概念设定
明代甲胄与军服参考
半剪影式剧情表现
少表情，多姿态
人物像从案卷、海雾和火光里浮出来
```

第一阶段优先使用剪影，避免过早进入精绘立绘。

### 7.2 当前 P0 角色资产状态

| 角色 / 动作 | 当前资产 | 状态 | 下一步 |
|---|---|---|---|
| 师父挡箭 / 挡刀 | `sil_master_blocks_arrow.svg` | `DONE_BASE` | 挂入序章演出 |
| 倭寇伏击者 | `sil_wakou_ambusher.svg` | `DONE_BASE` | 挂入 beach_ambush 或演出资源池 |
| 押运官 | `sil_transport_officer_shadow.svg` | `DONE_BASE` | 挂入 transport_officer |
| 饥饿士兵 | `sil_starving_soldier_shadow.svg` | `DONE_BASE` | 挂入 mutiny_camp |
| 倭寇首领 | `sil_wakou_boss_shadow.svg` | `DONE_BASE` | 挂入 wakou_boss |
| 主角青年武官 | 暂无独立正式立绘 | `NEEDS_ASSET` | 半身、战斗站姿、头像 |
| 海商 | 暂无 | `NEEDS_ASSET` | 宴席剪影、半身剪影 |
| 军门信使 | 暂无骑马剪影 | `NEEDS_ASSET` | 雨中信使、马影 |
| 师父旧刀 | 暂无 prop | `NEEDS_ASSET` | 夜半磨刀节点优先 |

---

## 8. UI 视觉规范

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

### 8.1 关键 UI 组件方向

| UI 组件 | 美术方向 |
|---|---|
| 剧情文本框 | 案卷纸、淡墨边缘、缺页纹理 |
| 选项按钮 | 军令牌 / 木签 / 朱砂批注 |
| 战斗卡牌 | 武学招式谱 / 兵书残页 |
| 敌人意图 | 刀光、枪势、火器、暗箭图标 |
| 势 Posture | 墨痕 / 气势槽 |
| 血量 | 暗朱红封线 |
| 地图节点 | 海防图上的朱砂点 / 官印点 |

UI 下一阶段应优先服务三类信息：

```text
军功 jun_gong
清望 qing_wang
线索 clues
```

因为当前结局已经围绕这三类变量分化。

---

## 9. 节点视觉一致性规则

每个 narrative node 与 battle_id 应共享同一套视觉意象。

| 节点 | 当前实装视觉意象 |
|---|---|
| 序章 | 黑潮、柴堆、火光、木刀、师父、岸上暗箭 |
| 军令巡海 | 湿旗、军令、未干墨、旧案禁声 |
| 海边伏击 | 整齐脚印、官泥、芦苇枪尖、伏击倭影 |
| 渔村残火 | 残村、黑烟、孩子咳嗽、火从村后起 |
| 海商宴 | 雨夜海商宅、热酒、冷兵、屏风后火器箱 |
| 明制火器 | 倭船舱、官造火器、木箱半开 |
| 涂改军报 | 破庙、倒神像、香炉下军报、墨比血新 |
| 押运官 | 山道、空车、深车辙、押运名册 |
| 欠饷营 | 营门、军旗、无粮、欠饷、不是倭寇也挡路 |
| 军门信使 | 雨、喘马、无封泥信封、第二封信 |
| 夜半磨刀 | 深夜营地、雨停、旧刀、令迟了 |
| 倭寇首领 | 破船、火器箱、倭首坐箱、看岸不看海 |
| 军门压案 | 灯火、缺页案卷、朱批、木匣不见 |

如果剧情背景、战斗背景、文案和角色剪影的意象不一致，优先调整美术资源，不优先改叙事配置。

---

## 10. 禁止事项

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
11. 禁止将未挂接资源误标为已实装演出。

---

## 11. 阶段验收口径

### 阶段 A：统一风格样张

当前状态：基本完成。

- 第一幕所有战斗背景无占位文字。
- 每张战斗背景有明确视觉记忆点。
- 色板已统一到黑灰、米色、海雾灰蓝、土黄灰、暗朱红。

### 阶段 B：可展示原型

当前状态：进行中。

需完成：

```text
1. 把现有 props / silhouettes 挂入 performance_tracks 或演出配置。
2. 补 fishing_village_embers / merchant_banquet / altered_military_report / mutiny_camp / military_messenger / night_knife_camp 专属演出。
3. 补主角青年武官、海商、军门信使、师父旧刀等 P0 资源。
4. UI 形成案卷 / 军令风格。
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
