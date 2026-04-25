# 《沧海嘀鸣》主视觉提示词标准

> 用途：作为现有人物与场景提示词的统一视觉基准。后续 `CHARACTER_IMAGE_PROMPTS.md` 与 `SCENE_IMAGE_PROMPTS_STORY.md` 中的主角、出山、海岸、军令、Boss 等提示词，应优先继承本标准。

---

## 1. 主视觉完整提示词

```text
Subject:
young Ming dynasty military officer, heroic Chinese young officer, three-quarter portrait, standing proudly, hand on saber hilt, determined gaze, windswept hair and headband, Ming-style lamellar armor, dark armor, deep crimson robe and cape, pale decorated chest armor, ornate belt, traditional Chinese military costume

Scene:
clean vertical poster composition, parchment background, ink-wash coastline, distant cliffs, sea mist, faint city wall, a few small ships, smoke clouds, minimal background details, large empty space, strong silhouette

Mood:
national spirit, loyalty, sacrifice, turbulent Ming era, heroic restraint, tragic but dignified, 家国情怀, 风起沧海

Style:
Chinese ink wash + realistic historical concept art, guofeng game key visual, Ming dynasty atmosphere, cinematic lighting, restrained color palette, black ink, parchment beige, muted gray, deep cinnabar red, subtle dark gold

Typography:
large vertical Chinese brush calligraphy title: “沧海嘀鸣”, black ink, placed on the left side, small red seal below, no other text
```

---

## 2. 中文化项目标准

```text
年轻明代武官，英雄式中国青年军官，三分之四视角肖像，挺立于海疆风中，一手按住腰刀刀柄，眼神坚定克制，发带与碎发被海风吹起。身穿明制札甲与传统军服，深色甲胄，深绛红战袍与披风，胸前有浅色装饰护甲，腰间束精致革带，整体为可信的明代军伍装束。

画面采用竖版海报构图，米黄宣纸背景，水墨海岸线、远处峭壁、海雾、隐约城墙、几只小船、低垂烟云。背景细节克制，留有大面积空白，人物剪影清晰有力。

情绪为家国情怀、忠诚、牺牲、明代乱世、英雄克制、悲壮但体面、风起沧海。整体不能爽文浮夸，不能玄幻发光，要有国家危局与个人命运相撞的庄重感。

风格为中国水墨与写实历史概念设计结合，国风游戏主视觉，明代氛围，电影感光照，低饱和克制配色：黑墨、米黄宣纸、灰色海雾、深朱砂红、少量暗金。

左侧放置大号竖排中文毛笔书法标题：“沧海嘀鸣”，黑墨字，下方小红印章。画面中禁止出现其他文字。
```

---

## 3. 统一负向提示词

```text
modern clothing, modern weapons, gun, rifle, pistol, cyberpunk, sci-fi, neon, European knight armor, fantasy armor, glowing weapon, magic effect, Japanese anime school style, cute chibi, cartoon color, over-saturated color, excessive background details, messy composition, extra text, watermark, logo, wrong Chinese characters, duplicated title, horizontal title, blood gore, monster face, non-Ming dynasty costume
```

中文约束：

```text
不要现代服装，不要现代枪械，不要赛博朋克，不要科幻霓虹，不要欧式骑士甲，不要玄幻发光武器，不要仙侠飞剑，不要过度日漫，不要 Q 版，不要明亮卡通色，不要复杂背景，不要多余文字，不要水印，不要错误中文，不要重复标题，不要横排标题，不要血腥特写，不要妖魔化，不要脱离明代服饰。
```

---

## 4. 应用规则

```text
人物提示词：
- 主角、青年武官、出山形象、宣传图优先套用本标准。
- 若是战斗 Sprite，可保留透明背景和单帧要求，但人物服饰、色彩、气质仍继承本标准。
- 若是师父、敌人、押运官、倭寇首领，可不直接使用“年轻明代武官”，但要保留低饱和水墨、明代军务、海疆危局、克制悲壮的统一基调。

场景提示词：
- 海岸、军门、破船、出山、Boss、结尾场景均优先套用“宣纸背景 + 水墨海岸 + 海雾 + 远崖 + 城墙/船影 + 留白”的主视觉规则。
- 剧情插画可以不加标题；宣传图与封面必须加左侧竖排标题“沧海嘀鸣”。
- 所有场景避免过度细节堆叠，优先保证强剪影、大留白、低饱和、悲壮克制。
```
