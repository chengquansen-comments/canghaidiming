# 《大明之沧海嘀鸣》美术风格基准文档

> 版本：v0.5
> 对齐分支：`main`
> 更新时间：按《美术规划.pdf》review 后，结合 narrative TSV / node_status / 编译产物重新校准
> 适用范围：战斗背景、剧情演出背景、叙事道具、角色剪影、UI 包装、主视觉方向。

---

## 0. 执行入口

美术文档总入口为：

```text
docs/ART_PIPELINE.md
```

本文件只定义“风格标准”。具体生产路线以：

```text
docs/ART_PRODUCTION_ROADMAP.md
```

为准。当前权威文档分工：

| 文档 | 作用 |
|---|---|
| `ART_PIPELINE.md` | 美术文档入口、TSV/JSON/运行资源规则 |
| `ART_DIRECTION_GUIDE.md` | 定义美术目标、风格边界、色彩、构图、禁止事项 |
| `NODE_VISUAL_MATRIX.md` | 定义每个 node / battle_id / visual_path / 资源状态 |
| `ART_PRODUCTION_ROADMAP.md` | 定义阶段计划、P0/P1/P2 交付包、验收路线 |
| `ART_REFERENCE_PROMPTS.md` | 参考图与概念图提示词；不作为运行资源清单 |

---

## 1. 当前口径声明：源头 / 实装 / 运行三层分开

当前美术规划必须同时理解三层文件：

```text
剧情内容源头：
- tables/narrative_mvp_prologue_steps.tsv
- tables/narrative_mvp_nodes.tsv

节点流程 / 实装 / 美术挂接源头：
- tables/narrative_mvp_node_status.tsv

编译产物 / 游戏运行读取：
- data/narrative_mvp_nodes.json
```

规则：

1. **文案、意象、叙事痕迹**以 `tables/narrative_mvp_prologue_steps.tsv` 和 `tables/narrative_mvp_nodes.tsv` 为源头。
2. **MVP 是否进入主流程、节点顺序、当前 visual_path 挂接**以 `tables/narrative_mvp_node_status.tsv` 为准。
3. **游戏实际运行**优先读取 `data/narrative_mvp_nodes.json`，美术验收必须确认最终编译产物已经包含目标节点。
4. 不再只按“全部 TSV 节点”平均推进，美术优先级必须先看 `flow_enabled=true`。
5. `reserved` 节点可以规划资源，但不应优先于 MVP 主流程节点。

---

## 2. 正式美术目标

《大明之沧海嘀鸣》的正式美术不是泛古风、泛武侠，而是：

> 明代海疆旧案感 + 军武压迫感 + 隐晦叙事痕迹。

玩家不读字，也应感受到：

- 这是明代。
- 这是海疆。
- 这是军武世界。
- 这里有旧案、压案、阴影和牺牲。

核心关键词：

```text
明代海疆
军门案卷
残火黑潮
卫所营门
倭寇暗袭
火器木匣
缺页名册
官泥封缄
忠义牺牲
风起沧海
```

美术服务隐晦叙事：

- 不直接画“有人通敌”，而画“火器箱、官造刻印、新封泥”。
- 不直接画“军门压案”，而画“案卷缺页、朱批、空木匣”。
- 不直接画“师父有秘密”，而画“师父旧刀、火器刻印、手停了一下”。

### 2.1 正式质量门槛

当前目标不再只是“运行时能显示”，而是让每张主流程画面达到正式展示质量。每个 P0 节点至少要过以下门槛：

| 门槛 | 要求 |
|---|---|
| 叙事焦点 | 画面里必须有一个可记忆物件或动作，能对应节点文本 |
| 历史可信 | 服饰、兵器、军械、营帐、船、案卷、官印都要属于明代海疆语境 |
| 空间层次 | 前景 / 中景 / 远景清楚，不是一张平面纹理 |
| 材质差异 | 湿沙、纸、木箱、金属、火光、雾要有不同质感 |
| 角色辨识 | 主角、师父、Boss、押运官不能只靠文字说明身份 |
| UI 安全 | 不遮挡字幕、选择按钮、debug 开关关闭后的主视觉区域 |
| 实机截图 | 在 NarrativeDemo / MainVisual 中看仍然成立，不只在单图预览里好看 |

正式美术允许先有高质量参考图或源画，但运行接入必须继续走 TSV / JSON / performance 管线。

### 2.2 人物武器硬约束

人物形象必须和战斗职业、招式动作绑定。不能先画一个泛用角色，再在战斗里临时解释武器。

| 角色 | 武器约束 | 战斗 / 招式视觉 |
|---|---|---|
| 主角枪版 | 明代军用长枪，木杆、铁枪头、短旧枪缨 | 中平枪、进步连环刺、拦拿、崩枪；强调中远距离、压势、打断 |
| 主角刀版 | 明代腰刀 / 单刀，朴素军用装具，有旧刀鞘 | 连珠斩、掠地反撩、拖刀杀、赶步进身；强调贴身、连压、爆发 |
| 师父 | 有缺口旧腰刀 | 挡眼、挡箭、磨刀、回身压刀；动作少但重量重 |
| 敌方枪手 | 长枪 | 芦苇枪尖、整齐脚步、军伍感中距离压迫 |
| 倭寇刀手 | 倭刀 / 海寇刀 | 烟里刀光、近身劈斩、村火压迫 |
| 押运官 | 腰刀 | 守车、退让、护住袖中半页名册 |
| 兵变营头 | 破损长枪 | 饥兵举枪、阵型松散但仍有军伍习惯 |
| 倭寇首领 | 倭刀 + 可见明制火器证据 | 倭刀近战；火器作为旧案证据，不画成现代枪战 |

主角双路线一致性：

```text
hero_officer_spear 和 hero_officer_saber 必须同脸、同年龄、同发带、同甲胄轮廓、同战袍色系。
两版只改变武器、站姿、手势、战斗距离感。
正式源画必须成对生成，避免枪线和刀线像两个不同主角。
```

当前运行层已完成第一轮双路线接入：

```text
hero_officer_spear_bust.png / performance_hero_spear.png
hero_officer_saber_bust.png / performance_hero_saber.png
```

后续替换更高精度源画时必须保持这四个运行用途和职业切换规则，不回退成单一泛用主角。

---

## 3. 当前 MVP 主流程

根据 `tables/narrative_mvp_node_status.tsv`，当前主流程节点为：

| flow_order | node_id | column | type | implementation_status | 当前 visual_path |
|---:|---|---|---|---|---|
| 10 | `military_order` | 军令 | 事件 | playable | `res://assets/pixel_battle/backgrounds/narrative_military_order.png` |
| 20 | `beach_ambush` | 初遇 | 普通战斗 | playable | `res://assets/pixel_battle/backgrounds/narrative_beach_ambush.png` |
| 30 | `beach_ambush_aftermath` | 初遇 | 战后处理 | playable | `res://assets/pixel_battle/backgrounds/narrative_beach_ambush.png` |
| 40 | `fishing_village_embers` | 初遇 | 普通战斗 | playable | `res://assets/pixel_battle/backgrounds/narrative_fishing_village_embers.png` |
| 50 | `fishing_village_embers_aftermath` | 初遇 | 战后处理 | playable | `res://assets/pixel_battle/backgrounds/narrative_fishing_village_embers.png` |
| 60 | `ming_firearm` | 疑点 | 旧物 | playable | `res://assets/pixel_battle/relics/relic_ming_firearm.png` |
| 70 | `altered_military_report` | 疑点 | 旧物 | playable | `res://assets/pixel_battle/relics/relic_altered_military_report.png` |
| 80 | `transport_officer` | 压迫 | 精英战斗 | playable | `res://assets/pixel_battle/portraits/transport_officer.png` |
| 90 | `transport_officer_aftermath` | 压迫 | 战后处理 | playable | `res://assets/pixel_battle/portraits/transport_officer.png` |
| 100 | `night_knife_camp` | 压迫 | 事件 | playable | `res://assets/pixel_battle/backgrounds/narrative_night_knife_camp.png` |
| 110 | `wakou_boss` | 破船 | Boss | playable | `res://assets/pixel_battle/portraits/wakou_leader.png` |
| 120 | `military_coverup` | 军门 | 结尾 | playable | `res://assets/pixel_battle/backgrounds/narrative_military_coverup.png` |

当前保留但不进入 MVP 主流程的节点：

```text
merchant_banquet
mutiny_camp
mutiny_camp_aftermath
military_messenger
```

---

## 4. 序章视觉基准：黑海潮生

序章源头：`tables/narrative_mvp_prologue_steps.tsv`

序章由四段组成：

| column | step_id | 美术主题 |
|---|---|---|
| 旧村 | `black_tide` / `father` / `door` / `dead` / `wooden_blade` / `fall` | 黑潮、柴堆、敲门、木刀无效、父母遇害、母亲鞋停火边 |
| 救场 | `master_arrives` / `three_cards` | 旧甲味、师父挡眼、换我、刀 / 步 / 断气 |
| 旧案 | `military_word` / `hidden_arrow` / `dont_look` | “军……”、黑箭、不是海上、不是倭人、师父一直看箭 |
| 出山 | `departure` | 十年、学刀学枪学活、师父还刀、该走了 |

序章美术原则：

- 不展示完整屠村过程，只展示柴堆、敲门、木刀、鞋、黑箭。
- 师父不是普通救援者，而是“旧甲味 + 一直看黑箭的人”。
- 主角动机不是升官，而是追问那支箭从哪来。

---

## 5. 遭遇节点与战后处理节点必须区分

`tables/narrative_mvp_nodes.tsv` 中多个节点被拆成“遭遇 / 战后处理”，但 `data/narrative_mvp_nodes.json` 当前运行编译产物可能将部分战后选择合并进战斗节点。因此美术规划要同时标注：

- TSV 源头节点是否独立存在；
- node_status 是否 `flow_enabled=true`；
- JSON 运行产物中是否仍独立存在；
- visual_path 当前是否复用前一节点资源。

美术语法：

| 类型 | 美术重心 | 示例 |
|---|---|---|
| 遭遇节点 | 动作、压迫、战斗触发 | 枪尖出来、烟里刀光、押运官阻拦 |
| 战后处理节点 | 证据、选择、后果 | 脚印还在、火痕在村后、半页湿名册、跪下的人 |
| 旧物节点 | 道具特写、证据焦点 | 明制火器、涂改军报、火器刻印 |
| 结尾节点 | 案卷、灯火、缺页、沉默 | 军门压案、木匣不见、师父站门外 |

---

## 6. 色彩规范

| 用途 | 色值 | 说明 |
|---|---:|---|
| 主墨色 | `#080909` / `#111312` | 剪影、残木、暗礁、军械 |
| 深夜黑灰 | `#151819` / `#202323` | 海雾、铁器、暗部 |
| 宣纸米色 | `#d8c9a5` / `#e0d0aa` | 天光、纸张、旧案卷 |
| 烟灰 | `#5f6665` / `#687274` | 雾气、烟、远景 |
| 海雾灰蓝 | `#3f565b` / `#31484c` | 海岸、潮水、远礁 |
| 军营土黄 | `#8b806a` / `#5f563e` | 营帐、土路、粮袋 |
| 暗朱红 | `#7e2e28` / `#8f2f27` | 火光、血线、军旗、封泥、箭线 |
| 暗金 | `#8a6a3a` | 官印、甲片边缘、火器铭痕 |

---

## 7. 资产规范

当前正式美术运行导出优先使用高质量 PNG。要求：

- 场景、剧情插图、角色半身、道具特写、剪影焦点默认导出 PNG。
- 源画 / 母版保存在 `art_reference/final/*.png`，运行导出保存在 `assets/**/*.png`。
- `art_reference/generated/*.png` 只能作为参考或概念草案，不能直接挂运行。
- SVG 只用于 UI 矢量件、FX、调试占位、临时回退或仍未转正的旧资源。
- PNG 必须本地化、清晰、无水印、无多余文字，不能引用远程资源。
- 不在背景内写标题文字。
- 控制分辨率和包体，避免 Web 构建或运行性能不稳定。
- 不新增第二套战斗背景层。
- 背景路径只通过 manifest、node_status 或 performance_tracks 体系挂接，不写死在 GDScript。

推荐命名：

```text
assets/pixel_battle/backgrounds/battle_bg_<scene_name>.png
assets/pixel_battle/backgrounds/narrative_<node_id>.png
assets/pixel_battle/relics/relic_<node_id>.png
assets/pixel_battle/portraits/<role_id>.png
assets/narrative/props/prop_<object_name>.png
assets/narrative/silhouettes/sil_<role_or_action>.png
art_reference/generated/ref_<asset_name>.png
art_reference/final/<asset_name>.png
```

参考 PNG 只作风格锚点；正式 PNG 运行导出必须进入 `assets` 后再挂接。

正式源画和运行导出分开管理：

```text
art_reference/generated/*.png  参考图 / 概念草案
art_reference/final/*.png      正式源画 / 精修母版
assets/**/*.png                正式运行导出
assets/**/*.svg                UI 矢量 / FX / 调试占位 / 旧资源回退
```

源画必须追求正式细节和材质，运行导出必须控制包体、分辨率和 Web 稳定性。

---

## 8. 当前战斗背景状态

当前 7 张战斗背景已进入“正式分镜样张”阶段：

| 资源 | 状态 | 视觉记忆点 |
|---|---|---|
| `battle_bg_black_tide.png` | `DONE_POLISH_PASS` | 师父挡箭、箭线、远火村影、黑潮 |
| `battle_bg_coast_ambush.png` | `DONE_POLISH_PASS` | 暗礁、倭影、斜向暗箭 |
| `battle_bg_fishing_village_embers.png` | `DONE_POLISH_PASS` | 残村、黑烟、村后火、孩子线索 |
| `narrative_fishing_village_embers.png` | `VISUAL_WIRED` | 渔村剧情节点专属背景，服务战前 / 战后处理 |
| `battle_bg_transport_road.png` | `DONE_POLISH_PASS` | 空车、断封条、散落军械、车辙 |
| `battle_bg_mutiny_camp.png` | `DONE_POLISH_PASS` | 营门、低旗、空锅、饥饿士兵 |
| `battle_bg_broken_ship.png` | `DONE_POLISH_PASS` | 破船、火器箱、倭首、岸上暗箭 |
| `battle_bg_training_ground.png` | `DONE_POLISH_PASS` | 枪架、刀靶、校场木架 |

但从主流程角度看，`mutiny_camp` 当前是 `reserved`，所以 `battle_bg_mutiny_camp.png` 属于“资源已备，非当前 MVP 主流程优先挂接”。

---

## 9. 当前 P0 美术闭环

按 `flow_enabled=true` 排序，当前 P0 主流程资源已完成接入：

```text
1. military_order：军令封印 / 海防图已接入双焦点
2. beach_ambush / aftermath：官泥脚印、倭伏兵剪影、搜身证据已接入
3. fishing_village_embers / aftermath：剧情背景、焦碗火痕、咳嗽孩子剪影已接入
4. ming_firearm：火器刻印、火器箱双焦点已接入
5. altered_military_report：relic 图、涂改军报 prop、倒神像剪影已接入
6. transport_officer / aftermath：半页湿名册、押运官剪影、空车战后背景已接入
7. night_knife_camp：专属背景、火器刻印、旧刀、磨刀剪影已接入
8. military_coverup：缺页案卷、空木匣、门外师父资源已接入
```

后续工作不再是补 P0 缺口，而是做游戏内截图验收、UI 包装接线和 reserved 节点 P2 规划。

---

## 10. UI 视觉规范

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

变量口径必须兼容实际运行产物。当前需要注意：

- TSV 中使用：`military_merit`、`clean_reputation`、`case_clues`
- JSON 编译产物中仍可能出现：`jun_gong`、`qing_wang`、`clues`

因此 UI 文档不要只写死其中一套命名，正式实现前需要确认编译脚本字段映射。

---

## 11. 禁止事项

1. 禁止把背景路径写死在 GDScript。
2. 禁止新增第二套战斗背景层。
3. 禁止把 `art_reference/generated` 的参考草图直接挂进运行 `visual_path`。
4. 禁止把 SVG 当作正式场景、角色、道具美术最终格式。
5. 禁止在背景图中内嵌标题文字。
6. 禁止把正式战斗背景做成小图标。
7. 禁止高饱和仙侠光效。
8. 禁止卡通化、Q版化。
9. 禁止直接画明阴谋真相。
10. 禁止为了单张图好看破坏整体色板。
11. 禁止只看 TSV 不看 `node_status.tsv` 和编译产物。
12. 禁止把 reserved 节点当成当前 MVP P0 主线优先级。
13. 禁止把低清、压缩过度、带水印或未验收的 PNG 当作正式资源。

---

## 12. 下一阶段验收口径

### 阶段 A：统一风格样张

状态：基本完成。

- 第一幕主要战斗背景无占位文字。
- 战斗背景已有明确视觉记忆点。
- 色板统一到黑灰、米色、海雾灰蓝、土黄灰、暗朱红。

### 阶段 B：MVP 主流程可展示

验收重点：

```text
1. 持续运行 `compile_tables.py` 与 `validate_performance_tracks.py`，保持 TSV / JSON / 资源一致。
2. 以 NarrativeDemo 截图验收 P0 多焦点演出是否遮挡字幕和操作区。
3. 角色半身与 UI 包装资源已进入 NarrativeDemo 可见层，后续按截图做精修。
4. reserved 节点保持 P2 规划；资源与 track 已预接线，不抢当前 MVP 主流程。
```

### 阶段 C：正式美术质量

当前状态：

```text
1. 主视觉 key art 需要正式 PNG 源画定稿，而不是只靠运行级 SVG。
2. 标题字“沧海嘀鸣”已有运行资源，后续需要做展示级字形精修。
3. 5 张对外截图需要按 `ART_PRODUCTION_ROADMAP.md` 的 F1 目标实机截取。
4. 主角 / 师父 / Boss 半身已接入 NarrativeDemo，但需要升级角色辨识和材质。
5. P0 节点视觉矩阵已无资源空缺，下一步是从 `RUNTIME_WIRED` 推进到 `IN_GAME_ACCEPTED`。
```
