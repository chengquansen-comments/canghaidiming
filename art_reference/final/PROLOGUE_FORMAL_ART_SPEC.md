# 序章正式美术规格

## 范围

本批次只认序章 12 拍为交付范围：

```text
black_tide
father
door
dead
wooden_blade
fall
master_arrives
three_cards
military_word
hidden_arrow
dont_look
departure
```

旧 SVG、程序生成 PNG、占位剪影和低细节道具均不作为正式素材依据。它们只能作为临时回退，不参与正式验收。

## 输出规格

| 类型 | 尺寸 | 路径 |
|---|---:|---|
| 正式母版 | 1536 x 864 或更高 16:9 PNG | `art_reference/final/prologue/*.png` |
| 运行导出 | 1280 x 720 PNG | `assets/pixel_battle/backgrounds/formal/prologue/*.png` |
| 提示词 | Markdown | `art_reference/final/PROLOGUE_FORMAL_PROMPTS.md` |

## 风格规格

- 写实历史概念设计 + 克制国风水墨，不要卡通、Q 版、仙侠光效。
- 明代海疆军务语境：旧甲、腰刀、木刀、海雾、黑潮、村火、官军暗线。
- 不直接表现血腥屠杀；用门、鞋、木刀、黑箭、旧甲味、潮声停顿表达。
- 背景不写标题字，不出现可读错误中文，不出现水印。
- 画面下 33% 预留剧情 UI 安全区，关键人物/证据放在上方表演区。
- 主焦点必须 3 秒内可读。

## 验收规则

1. 每个 step 有独立正式 PNG 母版。
2. runtime 只引用 `assets/pixel_battle/backgrounds/formal/prologue/*.png`。
3. 不再使用旧 `prologue_*.png`、`prop_*`、`sil_*` 作为正式序章主表现。
4. 通过 `compile_tables.py`、`validate_performance_tracks.py`、Godot headless。
5. 通过序章 12 拍 smoke。
6. 人工截图确认 UI 不遮挡主焦点后，才标记 `IN_GAME_ACCEPTED`。
