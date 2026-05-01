# Art Reference Source Area

`art_reference/` stores source and reference images only. It is intentionally hidden from Godot import through `.gdignore`.

- `generated/`: generated concepts, sketches, prompt outputs, and reference studies.
- `final/`: high-quality source images and player-imported masters used to create runtime exports.

Do not reference files here from TSV, JSON, GDScript, actor meta, or scenes. Export runtime-ready assets into `assets/` first.

