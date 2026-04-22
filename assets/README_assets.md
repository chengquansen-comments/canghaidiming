# Formal pixel asset pack

This pack is prepared for the `feature/symmetry-gameplay` branch.

## Included
- `assets/pixel_battle/sheets/`: 4 formal sprite sheets (3 frames each: idle / attack / hurt)
- `assets/pixel_battle/portraits/`: 4 portraits
- `assets/pixel_battle/fx/`: slash arc, pierce streak, hit spark

## Suggested integration
1. Copy `sheets/*.png` into `assets/pixel_battle/sheets/` in the repo.
2. Copy `portraits/*.png` into `assets/pixel_battle/portraits/`.
3. Optionally update visual controller to load `fx/slash_arc.png`, `fx/pierce_streak.png`, `fx/hit_spark.png` instead of only ColorRect overlays.
4. Keep `TextureRect.texture_filter = NEAREST` for all sprite/fx nodes.

## Sizes
- sheets: 576x192
- portraits: 128x128
- fx: 256x128 / 256x64 / 128x128

## Note
- Binary PNG asset drop is staged after this note commit so later blob/tree commits can safely attach to the current branch head.
