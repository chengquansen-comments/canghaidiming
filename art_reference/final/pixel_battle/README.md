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
Keep clean character edges for one-click keying, but do not reject otherwise usable source only for minor model-edge instability.
Runtime exports under assets/pixel_battle/ must be transparent PNG after processing, with zero visible chroma-green residue.
Character sheets must be one 1536x1536 PNG, vertical 3-stack, 3 rows in one column, each frame exactly 1536x512.
Character sheets must have exactly 3 clearly different action frames: idle_guard, attack/thrust or strike, recover_guard.
For spear / polearm sheets, idle_guard means the spear is held horizontally across the chest to protect the centerline.
Do not force the foot anchor to the canvas center; keep the natural body stance and record the matching foot_anchor in actor meta.
Foot anchors are character-specific production settings: do not globally unify foot_anchor.x across heroes, enemies, spears, blades, or master veteran.
Only check the within-sheet foot Y baseline consistently across the 3 frames; avoid floating, sinking, cropped soles, or feet touching the frame bottom.
Source sheets face right by default; enemy left-facing is handled by runtime facing / flip_h, not by maintaining separate reversed source sheets.
Post-process validation is stricter than source acceptance: exported assets/**/*.png may not contain green screen, green fringe, dirty green translucent pixels, or non-transparent green background.
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
