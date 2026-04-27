# 《大明之沧海嘀鸣》美术风格基准文档

> 版本：v0.5  
> 对齐分支：`main`  
> 更新时间：按《美术规划.pdf》review 后，结合 narrative TSV / node_status / 编译产物重新校准  
> 适用范围：战斗背景、剧情演出背景、叙事道具、角色剪影、UI 包装、主视觉方向。

---

## 0. 执行入口

本文件定义“风格标准”。具体生产路线以：

```text
docs/ART_PRODUCTION_ROADMAP.md
```

为准。

三份文档分工：

| 文档 | 作用 |
|---|---|
| `ART_DIRECTION_GUIDE.md` | 定义美术目标、风格边界、色彩、构图、禁止事项 |
| `NODE_VISUAL_MATRIX.md` | 定义每个 node / battle_id / visual_path / 资源状态 |
| `ART_PRODUCTION_ROADMAP.md` | 定义阶段计划、P0/P1/P2 交付包、验收路线 |

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

---

## 3. 当前 MVP 主流程

根据 `tables/narrative_mvp_node_status.tsv`，当前主流程节点为：

| flow_order | node_id | column | type | implementation_status | 当前 visual_path |
|---:|---|---|---|---|---|
| 10 | `military_order` | 军令 | 事件 | playable | `res://assets/pixel_battle/backgrounds/narrative_military_order.svg` |
| 20 | `beach_ambush` | 初遇 | 普通战斗 | playable | `res://assets/pixel_battle/backgrounds/narrative_beach_ambush.svg` |
| 30 | `beach_ambush_aftermath` | 初遇 | 战后处理 | playable | `res://assets/pixel_battle/backgrounds/narrative_beach_ambush.svg` |
| 40 | `fishing_village_embers` | 初遇 | 普通战斗 | playable | `res://assets/pixel_battle/backgrounds/narrative_fishing_village_embers.svg` |
| 50 | `fishing_village_embers_aftermath` | 初遇 | 战后处理 | playable | `res://assets/pixel_battle/backgrounds/narrative_fishing_village_embers.svg` |
| 60 | `ming_firearm` | 疑点 | 旧物 | playable | `res://assets/pixel_battle/relics/relic_ming_firearm.svg` |
| 70 | `altered_military_report` | 疑点 | 旧物 | playable | `res://assets/pixel_battle/relics/relic_altered_military_report.svg` |
| 80 | `transport_officer` | 压迫 | 精英战斗 | playable | `res://assets/pixel_battle/portraits/transport_officer.svg` |
| 90 | `transport_officer_aftermath` | 压迫 | 战后处理 | playable | `res://assets/pixel_battle/portraits/transport_officer.svg` |
| 100 | `night_knife_camp` | 压迫 | 事件 | playable | `res://assets/pixel_battle/backgrounds/prologue_departure.svg` |
| 110 | `wakou_boss` | 破船 | Boss | playable | `res://assets/pixel_battle/portraits/wakou_leader.svg` |
| 120 | `military_coverup` | 军门 | 结尾 | playable | `res://assets/pixel_battle/backgrounds/narrative_military_coverup.svg` |

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

当前 Web 构建阶段优先使用 SVG。要求：

- 纯 SVG 基础图形、路径、渐变、滤镜。
- 不引用外部图片。
- 不使用外部字体。
- 不引入 font 文件。
- 不写远程资源 URL。
- 不在背景内写标题文字。
- 控制路径数量，避免 Web 构建或运行性能不稳定。
- 不新增第二套战斗背景层。
- 背景路径只通过 manifest、node_status 或 performance_tracks 体系挂接，不写死在 GDScript。

推荐命名：

```text
assets/pixel_battle/backgrounds/battle_bg_<scene_name>.svg
assets/pixel_battle/backgrounds/narrative_<node_id>.svg
assets/pixel_battle/relics/relic_<node_id>.svg
assets/pixel_battle/portraits/<role_id>.svg
assets/narrative/props/prop_<object_name>.svg
assets/narrative/silhouettes/sil_<role_or_action>.svg
art_reference/generated/ref_<asset_name>.png
```

参考 PNG 只作风格锚点，不直接作为运行资源挂接。

---

## 8. 当前战斗背景状态

当前 7 张战斗背景已进入“正式分镜样张”阶段：

| 资源 | 状态 | 视觉记忆点 |
|---|---|---|
| `battle_bg_black_tide.svg` | `DONE_POLISH_PASS` | 师父挡箭、箭线、远火村影、黑潮 |
| `battle_bg_coast_ambush.svg` | `DONE_POLISH_PASS` | 暗礁、倭影、斜向暗箭 |
| `battle_bg_fishing_village_embers.svg` | `DONE_POLISH_PASS` | 残村、黑烟、村后火、孩子线索 |
| `battle_bg_transport_road.svg` | `DONE_POLISH_PASS` | 空车、断封条、散落军械、车辙 |
| `battle_bg_mutiny_camp.svg` | `DONE_POLISH_PASS` | 营门、低旗、空锅、饥饿士兵 |
| `battle_bg_broken_ship.svg` | `DONE_POLISH_PASS` | 破船、火器箱、倭首、岸上暗箭 |
| `battle_bg_training_ground.svg` | `DONE_POLISH_PASS` | 枪架、刀靶、校场木架 |

但从主流程角度看，`mutiny_camp` 当前是 `reserved`，所以 `battle_bg_mutiny_camp.svg` 属于“资源已备，非当前 MVP 主流程优先挂接”。

---

## 9. 当前 P0 美术缺口

按 `flow_enabled=true` 排序，当前 P0 缺口是：

```text
1. military_order：军令 / 海防图 / 未干官印资源
2. beach_ambush_aftermath：战后脚印、尸体、搜身证据资源
3. fishing_village_embers_aftermath：村后火痕、孩子线索、烧痕资源
4. ming_firearm：官造火器、新封泥、火器刻印资源
5. altered_military_report：涂改军报、倒神像、香炉压纸资源
6. transport_officer_aftermath：半页湿名册、空车战后资源
7. night_knife_camp：师父旧刀、火器刻印、磨刀剪影资源
8. military_coverup：缺页案卷、空木匣、门外师父资源
```

下一步执行包以 `docs/ART_PRODUCTION_ROADMAP.md` 的 P0 为准。

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
3. 禁止在 SVG 中引用外链图片。
4. 禁止引入字体文件。
5. 禁止在背景图中内嵌标题文字。
6. 禁止把正式战斗背景做成小图标。
7. 禁止高饱和仙侠光效。
8. 禁止卡通化、Q版化。
9. 禁止直接画明阴谋真相。
10. 禁止为了单张图好看破坏整体色板。
11. 禁止只看 TSV 不看 `node_status.tsv` 和编译产物。
12. 禁止把 reserved 节点当成当前 MVP P0 主线优先级。
13. 禁止把 AI 参考 PNG 直接挂进运行 visual_path。

---

## 12. 下一阶段验收口径

### 阶段 A：统一风格样张

状态：基本完成。

- 第一幕主要战斗背景无占位文字。
- 战斗背景已有明确视觉记忆点。
- 色板统一到黑灰、米色、海雾灰蓝、土黄灰、暗朱红。

### 阶段 B：MVP 主流程可展示

下一步重点：

```text
1. 按 node_status.tsv 的 flow_enabled=true 节点补齐 visual_path 对应资源。
2. 优先处理 aftermath 节点，避免战后处理继续复用战前图。
3. 补 military_order / ming_firearm / altered_military_report / night_knife_camp / military_coverup 的证据道具资源。
4. 检查 data/narrative_mvp_nodes.json 是否已包含相关节点，再做游戏内验收。
```

### 阶段 C：正式展示包

未开始：

```text
1. 主视觉 key art。
2. 标题字“沧海嘀鸣”。
3. 3-5 张对外截图。
4. 角色概念设定页。
5. 节点视觉矩阵无 P0 空缺。
```
