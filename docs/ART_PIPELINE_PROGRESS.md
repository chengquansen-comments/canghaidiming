# 《沧海嘀鸣》美术表现推进看板

> 当前目标：从“纯文字 + 简单色块占位”推进到“明代海疆国风主视觉 + 数据驱动剧情演出”的可见 MVP。
>
> 当前美术方向：青年明代武官、明制札甲、深绛红战袍、水墨海岸、宣纸背景、海雾、远崖、城墙、小船、低饱和、强剪影、家国情怀、风起沧海。

---

## 0. 剧情 UI 布局规范

```text
Narrative UI 采用明确上下分割：

上方：表演区（Performance Area）
- 承载场景主视觉（SVG / PNG / AI 图）
- 用于表现人物、环境、情绪、叙事氛围
- 不放交互按钮
- 可叠加暗层 / 雾层 / 火光 / 人物剪影

下方：操作区（Operation Area）
- 承载剧情文本（body）
- 承载选项按钮（choices）
- 承载状态提示（hint / vars）
- 必须保证滚动与点击优先级

实现约束：
- 理想比例：上方约 2/3 表演区，下方约 1/3 操作区
- 实际运行：操作区有最小高度保护，小屏幕时自动压缩表演区，优先保证选项可见
- 禁止再使用“中间一小块插图”的旧结构
- 所有剧情场景图默认作为表演区背景，而不是 UI 元素
```

---

## 1. 已完成：主视觉提示词规范

```text
docs/KEY_VISUAL_PROMPT_STANDARD.md
docs/CHARACTER_IMAGE_PROMPTS_KEY_VISUAL_OVERRIDE.md
docs/SCENE_IMAGE_PROMPTS_KEY_VISUAL_OVERRIDE.md
```

核心标准：

```text
Subject：young Ming dynasty military officer, hand on saber hilt, Ming-style lamellar armor, dark armor, deep crimson robe and cape
Scene：parchment background, ink-wash coastline, distant cliffs, sea mist, faint city wall, small ships, smoke clouds, large empty space
Mood：national spirit, loyalty, sacrifice, 家国情怀, 风起沧海
Style：Chinese ink wash + realistic historical concept art, guofeng game key visual
Typography：large vertical Chinese brush calligraphy title “沧海嘀鸣”, left side, red seal
```

---

## 2. 已完成：剧情资源 SVG 占位升级

### 2.1 主视觉封面

```text
assets/pixel_battle/backgrounds/key_visual_canghai_diming.svg
```

用途：

```text
后续标题页、序章首页、宣传页可直接接入。
```

---

### 2.2 序章专用表演图

```text
assets/pixel_battle/backgrounds/prologue_black_tide.svg
assets/pixel_battle/backgrounds/prologue_master_rescue.svg
assets/pixel_battle/backgrounds/prologue_arrow_silence.svg
assets/pixel_battle/backgrounds/prologue_departure.svg
```

用途：

```text
开局 12 段已具备独立表演背景，不再只依赖文字占位。
```

---

### 2.3 第一幕节点表演图

```text
assets/pixel_battle/backgrounds/narrative_military_order.svg
assets/pixel_battle/backgrounds/narrative_beach_ambush.svg
assets/pixel_battle/relics/relic_ming_firearm.svg
assets/pixel_battle/portraits/transport_officer.svg
assets/pixel_battle/portraits/wakou_leader.svg
assets/pixel_battle/backgrounds/narrative_military_coverup.svg
```

当前状态：

```text
[x] 军令巡海：庄重军令演出
[x] 海边伏击：强雾、快速推进、紧张感
[x] 明制火器：证物特写，火器箱成为主体
[x] 失械案押运官：雨雾对峙压迫感
[x] 破船 Boss：强雾、火光、主角入镜，高潮节点
[x] 军门压案：高暗度、低火光、压抑收束
```

---

## 3. 已完成：NarrativeDemo 单文件电影化演出

```text
scripts/narrative_demo_cinematic_controller.gd
scenes/NarrativeDemo.tscn
```

当前架构：

```text
NarrativeDemo.tscn
→ narrative_demo_cinematic_controller.gd
→ narrative_demo_formal_controller.gd
```

重要说明：

```text
之前 performance → art → formal 的多级继承链在 Web/Godot 解析中出现过 Could not resolve class。
当前已改为单文件 cinematic controller 直接继承 formal，稳定性优先。
```

当前行为：

```text
[x] 表演区主体背景铺满
[x] 下方操作区最小高度保护，选项不出屏
[x] 序章按 step_index 自动切换背景
[x] 第一幕按 node_id 自动切换背景
[x] 支持雾层移动
[x] 支持火光脉冲
[x] 支持暗层呼吸
[x] 支持师父 / 主角剪影入镜
[x] 支持镜头轻推、横移、局部节奏变化
```

---

## 4. 已完成：数据驱动演出重新挂回

```text
data/performance_tracks.json
```

当前状态：

```text
[x] 已重新挂回数据驱动
[x] 没有使用二级 data controller
[x] JSON 读取逻辑已内联到 narrative_demo_cinematic_controller.gd
[x] 读取成功时 source=json
[x] 读取失败时自动回退代码内置 NODE_PERFORMANCE
```

JSON 当前覆盖：

```text
序章：
- black_tide_0
- black_tide_1
- black_tide_2
- black_tide_3
- master_rescue
- arrow_silence
- departure

第一幕：
- military_order
- beach_ambush
- ming_firearm
- transport_officer
- wakou_boss
- military_coverup
```

当前可调字段：

```text
duration：阶段时长
zoom：镜头推进强度
pan_x / pan_y：镜头横移 / 纵移
dim：暗层强度
mist：雾层强度
fire：火光强度
hero / master：是否显示主角 / 师父剪影
hero_push / master_push：人物入镜位移
```

---

## 5. 最新调优：第一幕演出节奏

```text
提交目标：让第一幕节点差异更明确，而不是所有节点都只是轻微动背景。
```

当前调优方向：

```text
军令巡海：降低 zoom 和雾，突出庄重、稳定、领命
海边伏击：提高 zoom、pan、mist，突出危险接近
明制火器：大幅提高 zoom 和 fire，降低 dim / mist，明确证物特写
失械案押运官：提高 dim / mist / hero_push，突出雨雾对峙
破船 Boss：提高 zoom / pan / mist / fire，成为第一幕最强演出节点
军门压案：提高 dim、降低 fire，形成压抑收束
```

---

## 6. 当前验收状态

```text
[x] Web 构建稳定，无 Could not resolve class
[x] NarrativeDemo 正常打开
[x] 上方表演区显示场景主视觉背景
[x] 下方操作区完整显示选项
[x] 选项可滚动、可点击
[x] 剧情—战斗—剧情闭环不受影响
[x] data/performance_tracks.json 已生效
[x] 明制火器证物节点可见
```

继续验收建议：

```text
[ ] 检查第一幕 6 个节点的演出差异是否足够明显
[ ] 检查海边伏击 / 破船 Boss 是否有明显紧张升级
[ ] 检查军门压案是否形成压抑收束
[ ] 检查 source=json 是否稳定显示
```

---

## 7. 下一批美术优先级

### P0：战斗背景统一

```text
battle_bg_coast_ambush.svg
battle_bg_transport_road.svg
battle_bg_broken_ship.svg
```

目标：

```text
让 MainVisual 战斗场景也统一到水墨海疆，而不是沿用旧测试背景。
```

---

### P1：角色战斗立绘

```text
hero_spearman.svg
hero_blademaster.svg
master_veteran.svg
enemy_spearman.svg
transport_officer_battle.svg
wakou_leader_battle.svg
```

目标：

```text
让职业选择和战斗 UI 中的角色图，从色块占位升级成国风剪影立绘。
```

---

### P2：正式 PNG 替换

```text
prologue_black_tide.png
prologue_master_rescue.png
narrative_military_order.png
narrative_beach_ambush.png
relic_ming_firearm.png
```

目标：

```text
将 SVG 高级占位逐步替换为 AI 生成或正式绘制 PNG，提升观感上限。
```

---

## 8. 当前一句话结论

```text
剧情美术管线已进入“数据驱动电影化演出”阶段：序章与第一幕均已接入表演区背景、镜头、雾、火光、人物剪影与 JSON 参数调优；下一阶段应把战斗场景也统一到同一套水墨海疆视觉体系。
```
