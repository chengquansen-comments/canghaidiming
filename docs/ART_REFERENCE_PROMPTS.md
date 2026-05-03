# 《大明之沧海嘀鸣》参考图与提示词口径

> 本文件整合旧的角色、场景、主视觉提示词。它只用于生成参考图、概念图或精修方向，不是运行资源清单。

> 正式接图时，优先以 `tables/art_prompt_manifest.tsv` + `python3 tools/render_art_prompt.py <asset_id>` 输出结构化提示词；本文保留风格基准、长例子和旧参考口径。

## 1. 使用规则

1. 参考图输出到 `art_reference/generated/*.png`；正式源画 / 精修母版沉淀到 `art_reference/final/*.png`。
2. `art_reference/generated` 的参考 PNG 不写入 `visual_path`，不直接挂到剧情或战斗运行层。
3. 正式运行资源优先导出为 `assets/**/*.png`，再通过 TSV / performance track 接入。
4. 宣传图可以包含标题字；剧情背景、道具、剪影、运行 PNG 不写标题文字。
5. 若提示词与 `ART_PIPELINE.md` 冲突，以 `ART_PIPELINE.md` 为准。
6. 生成正式源画时，必须同时标注目标节点、运行用途、目标 `assets/**/*.png` 导出路径。

## 1.5 肖像与 Sheet 生成硬规则

肖像、半身像、角色 sheet 的正式源图提示词必须包含：

```text
solid bright green chroma key background, exact color #00FF00, single flat color background, no gradient, no shadow, no ground, no texture, no glow, no transparent checkerboard background, no scene background, do not use the same bright green color on the character, clean edges for one-click keying
```

中文口径：

```text
背景使用纯色亮绿色抠图底，颜色为 #00FF00。背景必须是单一纯色，不要渐变、不要阴影、不要地面、不要纹理、不要光晕、不要透明棋盘格。角色身上不要出现同样的绿色。边缘尽量干净，方便后期一键抠图。
```

运行层仍使用透明 PNG。亮绿色抠图底只用于源图阶段，后续由导出脚本抠图、透明化、归一尺寸后写入 `assets/`。

角色 sheet 提示词必须包含：

```text
three clearly different action frames: idle_guard, attack / thrust, recover_guard
```

中文口径：

```text
sheet 固定 3 帧：戒备、出招、收势。三帧动作要有大区分度，不能只是手臂微调，不能复制同一姿势。
```

长枪 / 长兵器的守势固定写成：

```text
idle_guard is a defensive guard with the spear held horizontally across the chest, both hands gripping the shaft, protecting the centerline. Do not use a diagonal spear-point-forward standing pose for idle_guard.
```

中文口径：

```text
idle_guard 是横枪胸前的守势：枪杆横在胸前或胸腹前方，双手持枪护住中线。不要写成枪尖斜指前方的普通站姿。
```

战斗动作 sheet 统一用 `1536x1536` 竖向三叠源图，上中下三帧一列；每帧严格 `1536x512`，不再使用横排 sheet 或多张单帧源图作为正式生产标准。

长武器构图不要强制脚点居中：

```text
Do not force the foot anchor to the exact canvas center. Keep the natural body stance, leave enough space for the spear or polearm, and record the matching foot_anchor in actor meta during runtime export.
```

中文口径：

```text
不要强制脚点在画面正中心。按人体自然站位和长兵器展开留白构图，运行导出时在 actor meta 里记录匹配的 foot_anchor。
```

## 2. 通用风格基准

```text
Chinese ink wash + realistic historical concept art, guofeng game key visual, Ming dynasty coastal military world, cinematic lighting, restrained color palette, black ink, parchment beige, muted gray, sea mist gray-blue, deep cinnabar red, subtle dark gold, heroic restraint, loyalty, sacrifice, tragic but dignified, 家国情怀, 风起沧海.
```

中文基准：

```text
中国水墨与写实历史概念设计结合，国风历史武侠游戏质感，明代海疆军务氛围，电影感光照，低饱和克制配色：黑墨、米黄宣纸、灰色海雾、深朱砂红、少量暗金。人物和场景强调家国情怀、忠诚、牺牲、旧案压迫、英雄克制、悲壮但体面。不要爽文浮夸，不要玄幻发光，不要现代装备。
```

## 3. 负向提示词

```text
modern clothing, modern weapons, rifle, pistol, cyberpunk, sci-fi, neon, European knight armor, fantasy armor, glowing weapon, magic effect, cute chibi, bright cartoon colors, over-saturated color, excessive background details, wrong Chinese characters, extra text, watermark, logo, blood gore, monster design, non-Ming dynasty costume
```

中文约束：

```text
不要现代服装，不要现代枪械，不要赛博朋克，不要科幻霓虹，不要欧式骑士甲，不要玄幻发光武器，不要仙侠飞剑，不要 Q 版，不要明亮卡通色，不要多余文字，不要水印，不要错误中文，不要血腥特写，不要妖魔化，不要脱离明代服饰。
```

## 4. 主视觉提示词

主视觉也必须按路线拆版，不生成“刀枪混合主角”。若需要双路线主视觉，应输出一组同构图成对图：

```text
Variant A: hero_officer_spear, young Ming dynasty military officer, heroic Chinese young officer, three-quarter portrait, standing in sea wind, determined restrained gaze, dark Ming-style lamellar armor, deep crimson robe and cape, holding a practical Ming military spear with wooden shaft and iron spearhead, disciplined spear stance.

Variant B: hero_officer_saber, same face, same armor, same robe, same age and gaze as Variant A, holding a practical Ming waist saber / single saber with plain military fittings, compact close-range saber stance.

Shared scene: parchment background, ink-wash coastline, distant cliffs, sea mist, faint city wall, a few small ships, smoke clouds, large empty space, strong silhouette, Chinese ink wash + realistic historical concept art, guofeng game key visual, cinematic lighting, black ink, parchment beige, muted gray, deep cinnabar red, subtle dark gold, loyalty, sacrifice, turbulent Ming era, tragic but dignified, 家国情怀, 风起沧海.
```

宣传封面可追加：

```text
large vertical Chinese brush calligraphy title: “沧海嘀鸣”, black ink, placed on the left side, small red seal below, no other text
```

运行背景和节点 PNG 不追加标题文字。

## 4.5 正式源画质量要求

用于正式源画或展示截图参考时，提示词必须额外强调：

```text
clear readable focal object, production-quality composition, strong foreground-midground-background depth, historically credible Ming dynasty coastal military details, readable material contrast, no UI-blocking focal point, cinematic but restrained, no decorative clutter
```

中文：

```text
焦点物件清楚可读，构图达到正式游戏美术质量，前中后景层次明确，明代海疆军务细节可信，材质区分清楚，不把关键人物或证据放在 UI 遮挡区域，电影感但克制，不堆装饰噪点。
```

## 5. 角色提示词

### 5.1 主角双路线一致性规则

主角必须同时准备两套正式形象：

```text
hero_officer_spear：戚家军枪手 / 长枪路线
hero_officer_saber：单刀快手 / 腰刀路线
```

两套图必须保证“同一个人”：

```text
same face, same age, same facial structure, same restrained gaze, same headband, same armor silhouette, same deep crimson robe family, same belt and cloth rhythm, same Ming coastal military identity, only weapon, stance, hand pose and combat posture change
```

中文约束：

```text
同一张脸，同一年龄，同一发带，同一套明制札甲轮廓，同一深绛红战袍体系，同一腰带和布料节奏。只改变主武器、站姿、手势、战斗重心。枪版不能像另一个角色，刀版不能换脸或换阵营。
```

生成建议：

```text
同一批次生成 hero_officer_spear 与 hero_officer_saber。
先定统一头像 / 半身母版，再分别扩展武器和战斗姿态。
角色正面、三分之四、半身、战斗站姿都要成对产出。
```

当前运行层已具备第一轮 PNG 导出；后续参考图 / 源画替换时应复用这些运行用途：

```text
hero_officer_spear_bust.png
hero_officer_saber_bust.png
performance_hero_spear.png
performance_hero_saber.png
```

### 5.2 主角枪版：戚家军枪手

武器硬约束：

```text
Primary weapon: practical Ming military spear, wooden shaft, iron spearhead, modest red-brown spear tassel, full spear length visible or clearly implied, held with both hands. No saber in hand. No fantasy polearm, no halberd, no glowing spear.
```

战斗招式绑定：

| 招式 / 卡牌 | 视觉动作 |
|---|---|
| `steady_step` / 寸步稳枪 | 枪尾稳、脚步小进、枪尖压住中线 |
| `retreat_half` / 退步半身 | 半身后撤，枪尖仍指向敌人 |
| `mid_spear` / 中平枪 | 中线直刺，枪杆平直，距离感明确 |
| `chain_thrust` / 进步连环刺 | 连续进步直刺，枪缨形成短促残影 |
| `pinning_hold` / 拦拿 | 枪杆横拦 / 下压，控制敌人武器 |
| `dragon_break` / 崩枪 | 重心下沉，整杆枪爆发前顶，强调破势 |

提示词：

```text
young Ming dynasty coastal military officer, spear route version, same face and armor as saber route, dark Ming-style lamellar armor, deep crimson robe, restrained determined gaze, practical Ming military spear with wooden shaft and iron spearhead, modest worn spear tassel, two-handed spear stance, strong centerline posture, disciplined Qi-family spear training feeling, medium-to-long range combat silhouette, parchment beige background, ink-wash coastline, sea mist, black ink, muted gray, deep cinnabar red, subtle dark gold, no saber in hand, no modern weapon, no fantasy glow.
```

#### 5.2.1 主角枪手独立帧提示词

```text
Create 3 separate 2D battle sprite frames for the player character spearman route in a Ming dynasty coastal military wuxia game.

Output format:
- Generate 3 separate PNG images, not one combined sprite sheet.
- Each image is one independent frame.
- Each frame canvas is 1024x512.
- Solid bright green chroma key background for source generation, exact color #00FF00; runtime export will be transparent.
- One character only per image.
- No sprite sheet layout, no panels, no frame dividers, no checkerboard background, no floor plane, no cast shadow, no gradient, no texture, no glow.
- Do not use #00FF00 or the same bright green on the character; keep clean edges for one-click keying.

Anchor requirements:
- Do not center the full silhouette including spear.
- Center and lock the human body anchor instead.
- In every 1024x512 frame, place the standing foot center near x=430, y=492.
- Torso center near x=430, y=300.
- Head near x=430, y=145, with only slight pose movement.
- The spear may extend far to the right, especially in the thrust frame, but the human body must stay locked to the same anchor position.

Frames:
- Image 1: idle spear guard, spear held horizontally across the chest, both hands gripping the shaft, protecting the centerline, full spear visible, calm readiness.
- Image 2: forward thrust / attack strike, full spear shaft and spear tip visible, strong horizontal silhouette.
- Image 3: recovery / guard return, spear retracts diagonally, full spear visible.
- The three frames must be strongly different in silhouette and body weight: guard, full attack extension, compact recovery.

Character:
Young Ming dynasty coastal military officer, same protagonist identity as saber route, practical dark cloth armor, muted military robe, tied hair or headwrap, restrained focused expression, Ming military long spear with wooden shaft, iron spearhead and short worn dark-red tassel.

Style:
Grounded Ming coastal military wuxia, painterly 2D game sprite, readable at gameplay size, clean silhouette, semi-realistic proportions, restrained ink-wash realism, muted dark navy cloth, weathered grey armor, wet sand beige accents, dark cinnabar tassel, aged iron spearhead.

Avoid:
No text, watermark, UI, background, checkerboard background, modern armor, fantasy glow, samurai armor, katana, gun, shield, cropped spear, cropped head or feet, inconsistent face between images. Do not create a combined sheet.
```

### 5.3 主角刀版：单刀快手

武器硬约束：

```text
Primary weapon: practical Ming waist saber / single saber, slightly curved blade, plain military fittings, worn scabbard at waist or one-handed saber grip. No spear, no katana fantasy silhouette, no oversized blade, no glowing edge.
```

战斗招式绑定：

| 招式 / 卡牌 | 视觉动作 |
|---|---|
| `rush_step` / 赶步进身 | 压低重心快速贴近，刀在身侧蓄势 |
| `sidestep` / 斜闪绕身 | 斜步避线，肩与刀形成侧身轮廓 |
| `swift_cut` / 连珠斩 | 短促连斩，刀光不发光，只用墨痕和衣摆表现速度 |
| `cross_slash` / 掠地反撩 | 低身反撩，刀从下线切回中线 |
| `dragonslash` / 拖刀杀 | 刀拖在身后，最后一步回身重斩 |
| `guard_frame` / 架势收锋 | 刀背护身，刀尖向下或斜前，准备反击 |

提示词：

```text
young Ming dynasty coastal military officer, saber route version, same face and armor as spear route, dark Ming-style lamellar armor, deep crimson robe, restrained determined gaze, practical Ming waist saber / single saber with plain military fittings, worn scabbard, close-range one-handed saber stance, fast footwork, compact aggressive silhouette, robe and belt following motion, parchment beige background, ink-wash coastline, sea mist, black ink, muted gray, deep cinnabar red, subtle dark gold, no spear, no oversized fantasy blade, no glowing weapon.
```

### 5.4 角色武器与战斗绑定表

| 角色 | 武器必须明确 | 招式 / 战斗视觉绑定 |
|---|---|---|
| 主角枪版 `hero_officer_spear` | 明代军用长枪 | `mid_spear`、`chain_thrust`、`pinning_hold`、`dragon_break`，强调 2-3 优势距离、压势、打断 |
| 主角刀版 `hero_officer_saber` | 明代腰刀 / 单刀 | `swift_cut`、`cross_slash`、`dragonslash`、`rush_step`，强调 1-2 贴身、连压、爆发 |
| 师父老兵 | 有缺口旧腰刀 | 挡眼、挡箭、旧刀架势、回身压刀；动作克制，像“迟到过的人” |
| 敌方枪手 | 长枪 | 中距离压迫、芦苇枪尖、整齐脚步，不能画成海盗杂兵 |
| 袭村 / 渔村倭寇刀手 | 倭刀 / 海寇刀 | 近身斩击、烟里刀光、压迫童年主角或村民 |
| 失械案押运官 | 腰刀 | 守车、后退、护袖中半页名册，恐惧多于凶狠 |
| 兵变营头 | 破损长枪 | 饥兵举枪、枪杆旧裂、阵型松散但仍有军伍习惯 |
| 小股倭寇首领 | 倭刀 + 可见明制火器证据 | 倭刀近战，明制火器只作为旧案证据露出，不画成现代枪战 |

### 5.5 师父 / 沉默老兵

```text
silent veteran of the Ming coastal army, old Chinese soldier, weathered face, gray stubble, tired but dangerous gaze, worn dark military robe, repaired Ming armor, old practical Ming waist saber with nicks and plain fittings, worn scabbard, hand resting near saber or grinding the old blade, sea wind, parchment background, ink-wash coastline, guilt, inheritance, loyalty, tragic dignity, restrained heroic mood, no fantasy glow, no modern weapon.
```

### 5.6 小股倭寇首领

```text
small wakou leader in Ming coastal crisis, sea raider armor mixed with looted Ming military elements, practical sea raider saber / wakou blade with rust and nicks, visible Ming firearm tucked at waist or resting near weapon crate as evidence, stranded broken ship and weapon crate nearby, dangerous but historically believable, not a monster, firearm is evidence not modern gun action, no rifle, no pistol, no fantasy glow.
```

### 5.7 押运官 / 军门人物

```text
Ming military transport officer, weary and fearful, wet robe and worn armor, practical Ming waist saber at side, one hand near sleeve hiding a half wet roster page, muddy mountain road and empty cart, restrained historical concept art, command pressure, guilt, military scandal, low saturation, no modern weapon.
```

## 6. 场景提示词

### 黑潮序章

```text
dark ink-wash coastline at night, low sea mist, distant burning fishing village reduced to faint smoke and cinnabar glow, empty wet beach, strong negative space, no explicit gore, tragic but dignified, Ming coastal military crisis, muted gray, black ink, deep cinnabar red.
```

### 军令巡海

```text
Ming coastal military gate before dawn, wet flags, sealed military order on a dark wooden table, faint city wall and sea mist in the background, young officer in strong silhouette, command pressure, duty, loyalty, tragic dignity, restrained ink-wash palette.
```

### 海边伏击

```text
wet beach, reeds, sea mist, orderly bootprints in official mud, spear shadows emerging from broken boat shadows, enemies with military discipline, not monsters, ambush mood, black ink, parchment beige, muted gray, deep cinnabar red.
```

### 明制火器 / 旧案证据

```text
dim broken ship cabin near the coast, half-open wooden weapon crate revealing well-maintained Ming firearms, official markings faintly visible, new seal mud, sea mist through broken planks, old case, state pressure, no modern guns.
```

### 夜半磨刀

```text
rain-wet late night Ming military camp, small campfire, silent old veteran grinding a nicked old saber, firearm official seal mark near firelight, young officer nearby but quiet, the old master's hand has just paused, damp ground, black gray, parchment beige, deep cinnabar, subtle dark gold.
```

### 军门压案

```text
Ming military office in deep shadow, sealed documents, missing casefile page, empty wooden case, cinnabar official mark, old master silhouette outside the door, young officer alone, loyalty tested, unresolved old case, tragic restraint.
```

## 7. 转运行 PNG 资源要求

正式源画转运行 PNG 时必须满足：

```text
本地 PNG
高质量、清晰、无水印、无多余文字
不直接使用 art_reference/generated 草图
不写远程资源
不在图中写标题文字
背景 / 剧情图优先 1280 × 720 或更高同宽高比；prop / silhouette 可按实际构图导出
不遮挡 NarrativeDemo 字幕和操作区
进入 assets 后再通过 TSV / performance track 挂接
```
