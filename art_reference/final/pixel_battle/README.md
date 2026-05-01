# Pixel Battle Source Mirror

This directory mirrors `assets/pixel_battle/`.

Source images live here before they are exported into runtime assets:

```text
art_reference/final/pixel_battle/backgrounds/
art_reference/final/pixel_battle/backgrounds/formal/prologue/
art_reference/final/pixel_battle/portraits/
art_reference/final/pixel_battle/sheets/
```

Runtime exports live under:

```text
assets/pixel_battle/backgrounds/
assets/pixel_battle/backgrounds/formal/prologue/
assets/pixel_battle/portraits/
assets/pixel_battle/sheets/
```

Generation rule for portraits and character sheets:

```text
Use solid bright green chroma key background in source prompts: exact color #00FF00.
The background must be one flat color: no gradient, shadow, ground, texture, glow, transparent checkerboard, or scene background.
Do not use #00FF00 or the same bright green on the character.
Keep clean character edges for one-click keying.
Runtime exports under assets/pixel_battle/ should be transparent PNG after processing.
Character sheets must have exactly 3 clearly different action frames: idle_guard, attack/thrust, recover_guard.
For spear / polearm sheets, idle_guard means the spear is held horizontally across the chest to protect the centerline.
Do not force the foot anchor to the canvas center; keep the natural body stance and record the matching foot_anchor in actor meta.
```

First battle source pack:

```text
art_reference/final/pixel_battle/backgrounds/battle_bg_coast_ambush.png
art_reference/final/pixel_battle/backgrounds/narrative_beach_ambush.png
art_reference/final/pixel_battle/sheets/enemy_spearman_frames/*.png
art_reference/final/pixel_battle/sheets/enemy_spearman_sheet_source.png
art_reference/final/pixel_battle/sheets/spearman_frames/*.png
```

Expected near-term master veteran sources:

```text
art_reference/final/pixel_battle/sheets/master_veteran_sheet_source.png
art_reference/final/pixel_battle/portraits/master_veteran_bust_source.png
art_reference/final/pixel_battle/portraits/performance_master_veteran_source.png
```

Do not reference files in this directory from TSV, JSON, GDScript, actor meta, or scenes. Export runtime-ready files into `assets/pixel_battle/` first.
