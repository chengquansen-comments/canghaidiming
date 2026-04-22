# Battle UI architecture (phase refactor note)

## Current entry split

- `scenes/Main.tscn`
  - launcher entry
- `scenes/MainText.tscn`
  - pure text/debug battle entry
- `scenes/MainVisual.tscn`
  - visual/demo battle entry
- `scenes/battle_demo_visual.tscn`
  - visual/demo scene alias, now also routes through the visual entry

## Controller layering

- `scripts/battle_controller_core.gd`
  - shared battle rules, state transitions, card flow, combo flow, battle feedback utilities
  - should avoid owning a full text UI shell
- `scripts/battle_controller_text_ui.gd`
  - rich-text debug layout, detailed preview, full textual state panels
- `scripts/battle_controller_demo_visual.gd`
  - current visual implementation base; still contains most scene-building code
- `scripts/battle_controller_visual_ui.gd`
  - clean visual entry used by scene files; preferred place to route helper integrations first

## Visual helpers

- `scripts/visual/battle_skin.gd`
  - texture fallback loading, panel styles, button styles
- `scripts/visual/battle_stage_view.gd`
  - stage/grid geometry, slot math, preview path math
- `scripts/visual/battle_hud_view.gd`
  - HUD text helpers, compact card summaries, card detail text

## Refactor direction

1. Keep battle rules in `battle_controller_core.gd`.
2. Keep pure text layout only in `battle_controller_text_ui.gd`.
3. Continue shrinking `battle_controller_demo_visual.gd` by moving reusable parts into `scripts/visual/`.
4. Prefer updating `battle_controller_visual_ui.gd` and scene entries first, to reduce regression risk.
5. When helper routing is stable, remove duplicated helper-style methods from `battle_controller_demo_visual.gd`.

## Practical rule

If a change is about:

- battle rules or round resolution -> `battle_controller_core.gd`
- text panels / preview wording -> `battle_controller_text_ui.gd`
- stage layout / HUD / animation presentation -> visual controllers or `scripts/visual/*`
