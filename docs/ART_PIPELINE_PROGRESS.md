# 《沧海嘀鸣》美术表现推进看板

> 当前目标：从“纯文字 + 简单色块占位”推进到“明代海疆国风主视觉”的可见 MVP。
>
> 当前美术方向：青年明代武官、明制札甲、深绛红战袍、水墨海岸、宣纸背景、海雾、远崖、城墙、小船、低饱和、强剪影、家国情怀、风起沧海。

---

## 0. 剧情 UI 布局规范（新增）

```text
Narrative UI 采用明确上下分割：

上方 2/3：表演区（Performance Area）
- 承载场景主视觉（SVG / PNG / AI 图）
- 用于表现人物、环境、情绪、叙事氛围
- 不放交互按钮
- 可叠加轻度暗色遮罩（保证前景文字可读）

下方 1/3：操作区（Operation Area）
- 承载剧情文本（body）
- 承载选项按钮（choices）
- 承载状态提示（map / scene / hint）
- 必须保证滚动与点击优先级

设计原则：
- 表演区优先“沉浸感”，操作区优先“可用性”
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

### 2.2 军令巡海

```text
assets/pixel_battle/backgrounds/narrative_military_order.svg
```

视觉内容：

```text
宣纸背景、水墨远岸、军令案牍、朱砂印、青年武官剪影。
```

---

### 2.3 海边伏击

```text
assets/pixel_battle/backgrounds/narrative_beach_ambush.svg
```

视觉内容：

```text
水墨海岸、芦苇、敌影、伏兵剪影、海雾、低饱和朱砂提示语。
```

---

### 2.4 明制火器

```text
assets/pixel_battle/relics/relic_ming_firearm.svg
```

视觉内容：

```text
破船舱、官造火器、火器箱、官造印记、旧案证据感。
```

---

### 2.5 失械案押运官

```text
assets/pixel_battle/portraits/transport_officer.svg
```

视觉内容：

```text
雨后泥路、押运车、押运官剪影、腰刀、军务压迫。
```

---

### 2.6 破船 Boss

```text
assets/pixel_battle/portraits/wakou_leader.svg
```

视觉内容：

```text
破船、火器箱、海寇首领、倭刀、旧案线索、海雾。
```

---

### 2.7 军门压案

```text
assets/pixel_battle/backgrounds/narrative_military_coverup.svg
```

视觉内容：

```text
军门案牍、缺页案卷、朱砂印、阴影中的人物剪影、压案气氛。
```

---

## 3. 已完成：NarrativeDemo 美术显示增强

```text
scripts/narrative_demo_art_controller.gd
scenes/NarrativeDemo.tscn
```

当前行为：

```text
[x] 上方 2/3 作为表演区，场景图铺满
[x] 下方 1/3 作为操作区（文本 + 选项）
[x] 表演区使用半透明暗层保证可读性
[x] 旧“中间小图”结构已废弃
```

---

## 4. 当前仍需验收

```text
[ ] Web 构建稳定，无 Parser Error
[ ] NarrativeDemo 正常打开
[ ] 上方约 2/3 区域显示场景主视觉背景
[ ] 下方约 1/3 区域完整显示选项
[ ] 选项可滚动、可点击
[ ] 文字在背景上清晰可读
[ ] 剧情—战斗—剧情闭环不受影响
```

---

## 5. 下一批美术优先级

### P0：序章专用 SVG

```text
prologue_black_tide.svg
prologue_master_rescue.svg
prologue_arrow_silence.svg
prologue_departure.svg
```

目标：

```text
让开局 12 段不再使用纯文字视觉占位，而是根据段落切换图。
```

---

### P1：战斗背景统一

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

### P2：角色战斗立绘

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

## 6. 当前一句话结论

```text
剧情 UI 已从“中间插图”结构升级为“上方表演区 + 下方操作区”的标准叙事布局，场景图成为主体背景。
```
