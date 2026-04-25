# 《沧海嘀鸣》美术资源尺寸与安全区规范

> 本文件是美术资源生产的硬约束。所有 AI 生成 PNG、手绘图、SVG 占位图都必须遵守。  
> 目标：保证 Godot 中“上方 2/3 表演区 + 下方 1/3 操作区”的剧情 UI 不裁关键人物、不遮核心信息、不挤压选项。

---

## 1. 剧情表演区背景图

### 1.1 标准尺寸

```text
推荐尺寸：1920 x 1280 px
最低尺寸：960 x 640 px
宽高比：3:2
用途：NarrativeDemo 上方 2/3 表演区背景
格式：PNG 优先，SVG 仅作占位
```

对应路径：

```text
assets/pixel_battle/backgrounds/*.png
assets/pixel_battle/backgrounds/*.svg
```

当前序章资源命名：

```text
prologue_black_tide.png / .svg
prologue_master_rescue.png / .svg
prologue_arrow_silence.png / .svg
prologue_departure.png / .svg
```

### 1.2 构图安全区

```text
画布比例：3:2
重要人物与关键动作：放在画面中部 70% 区域
左侧 8%：允许留白 / 题字 / 氛围，不放关键脸部
右侧 8%：允许留白 / 烟雾 / 远景，不放关键脸部
底部 18%：避免放关键文字、脸、武器尖端，因为下方操作区可能压近视觉边缘
顶部 8%：避免放关键脸部，防止浏览器或缩放裁切
```

可理解为：

```text
安全区：x = 8% ~ 92%，y = 8% ~ 82%
危险区：底部 18%、左右各 8%、顶部 8%
```

### 1.3 生成提示词必须包含

```text
3:2 aspect ratio, 1920x1280, important characters and key action inside central safe area, leave lower 18 percent free of critical details, large negative space, no important face or weapon tip near edges
```

中文约束：

```text
3:2 横向画幅，1920x1280，关键人物和关键动作放在画面中部安全区，底部18%不要放关键脸部、文字或武器尖端，边缘保留留白。
```

---

## 2. 剧情人物前景层

### 2.1 标准尺寸

```text
推荐尺寸：720 x 1040 px
最低尺寸：360 x 520 px
宽高比：约 9:13
用途：NarrativeDemo 表演区人物前景层
格式：透明 PNG 优先，SVG 仅作剪影占位
背景：必须透明
```

对应路径：

```text
assets/pixel_battle/portraits/performance_master_veteran.png / .svg
assets/pixel_battle/portraits/performance_hero_young.png / .svg
```

### 2.2 人物安全区

```text
人物从头到脚必须完整，不要裁头、裁刀、裁披风
头部位于画面上方 12% ~ 28%
躯干位于中部 30% ~ 70%
脚部或衣摆允许在底部 85% ~ 96%
武器可以外伸，但不能超过画布边缘
```

### 2.3 透明 PNG 要求

```text
必须是透明背景 PNG
不要自带场景背景
不要带文字
不要带白底
不要带投影大黑框
```

生成提示词必须包含：

```text
transparent background, full body character layer, no background, no text, clean silhouette, game sprite layer, 720x1040
```

---

## 3. 主视觉封面图

### 3.1 标准尺寸

```text
推荐尺寸：1440 x 2160 px
最低尺寸：960 x 1440 px
宽高比：2:3 竖版
用途：标题页、宣传图、封面、商店图草案
格式：PNG
```

对应路径：

```text
assets/pixel_battle/backgrounds/key_visual_canghai_diming.png / .svg
```

### 3.2 标题安全区

```text
左侧 15% ~ 28%：竖排标题“沧海嘀鸣”
标题下方可放小红印
主角建议放在右侧 55% ~ 82%
底部 15% 保持留白或低信息密度
不允许出现多余文字
```

---

## 4. 战斗背景图

### 4.1 标准尺寸

```text
推荐尺寸：1920 x 1080 px
最低尺寸：1280 x 720 px
宽高比：16:9
用途：MainVisual 战斗背景
格式：PNG 优先
```

对应规划路径：

```text
assets/pixel_battle/backgrounds/battle_bg_coast_ambush.png
assets/pixel_battle/backgrounds/battle_bg_transport_road.png
assets/pixel_battle/backgrounds/battle_bg_broken_ship.png
```

### 4.2 战斗 UI 安全区

```text
上方 12%：避免关键脸部与文字
下方 18%：避免关键动作，因为卡牌/按钮可能遮挡
左右 8%：避免关键目标，适配不同屏幕裁切
中部 70%：用于角色对峙与攻击动线
```

---

## 5. 文件命名规范

```text
剧情背景：scene_[chapter]_[node].png
序章背景：prologue_[stage].png
战斗背景：battle_bg_[encounter].png
人物表演层：performance_[character].png
人物战斗立绘：battle_[character].png
主视觉：key_visual_canghai_diming.png
```

当前兼容命名：

```text
prologue_black_tide.png
prologue_master_rescue.png
prologue_arrow_silence.png
prologue_departure.png
performance_master_veteran.png
performance_hero_young.png
```

---

## 6. Godot 接入规则

```text
1. PNG 优先，SVG fallback。
2. 如果存在同名 .png，系统自动优先加载 PNG。
3. SVG 只作为开发期占位，不作为最终美术。
4. 背景图使用 TextureRect.STRETCH_KEEP_ASPECT_COVERED。
5. 人物层使用 TextureRect.STRETCH_KEEP_ASPECT_CENTERED。
6. 所有关键视觉必须落在安全区内，避免 COVERED 裁切。
```

---

## 7. 首张高质量 PNG 生产目标

目标文件：

```text
assets/pixel_battle/backgrounds/prologue_master_rescue.png
```

规格：

```text
尺寸：1920 x 1280 px
比例：3:2
格式：PNG
关键内容：师父持旧腰刀救场，箭/刀/火光形成强动线，幼年主角在安全区内但非主焦点
安全区：关键脸部与刀箭交汇点放在 x=20%~80%、y=15%~70%
底部18%只放海雾、地面、烟尘，不放关键动作
```

提示词附加尺寸约束：

```text
1920x1280, 3:2 aspect ratio, cinematic key frame, key action inside central safe area, leave bottom 18 percent free of critical details, no important face near edges, no text
```
